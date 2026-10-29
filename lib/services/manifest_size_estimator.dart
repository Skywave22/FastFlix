import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

/// A bounded, best-effort estimate for sources without a scraper size token.
/// It never downloads media segments: HLS uses playlist duration and advertised
/// bitrate (or samples Content-Length using HEAD); DASH uses MPD bitrates.
/// Actual bytes can differ, especially after the user chooses an audio track.
class ManifestSizeEstimator {
  ManifestSizeEstimator({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  final Dio _dio;
  static const int _maxManifestBytes = 2 * 1024 * 1024;
  static const int _maxEstimateBytes = 1024 * 1024 * 1024 * 1024;

  Future<int?> estimate({
    required String url,
    required String format,
    required Map<String, String> headers,
    int? maxHeight,
  }) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        return null;
      }
      final manifest = await _readManifest(uri, headers);
      if (manifest == null) return null;
      if (format == 'dash' || manifest.trimLeft().startsWith('<')) {
        return estimateDash(manifest, maxHeight: maxHeight);
      }
      if (!manifest.trimLeft().startsWith('#EXTM3U')) return null;
      final variants = parseHlsVariants(manifest, uri);
      if (variants.isNotEmpty) {
        final selected = chooseHlsVariant(variants, maxHeight);
        final childHeaders = _headersFor(uri, selected.uri, headers);
        final playlist = await _readManifest(selected.uri, childHeaders);
        if (playlist == null) return null;
        final duration = hlsDuration(playlist);
        if (duration == null || selected.bitrate <= 0) return null;
        return _validBytes(duration * selected.bitrate / 8);
      }
      final duration = hlsDuration(manifest);
      if (duration == null) return null;
      final bitrate = RegExp(
        r'^#EXT-X-BITRATE:(\d+)',
        multiLine: true,
      ).firstMatch(manifest)?.group(1);
      if (bitrate != null) {
        return _validBytes(duration * int.parse(bitrate) * 1000 / 8);
      }
      final segments = parseHlsSegments(manifest, uri);
      if (segments.isEmpty) return null;
      if (segments.every((segment) => segment.byteRangeLength != null)) {
        return _validBytes(
          segments.fold<int>(
            0,
            (total, segment) => total + segment.byteRangeLength!,
          ),
        );
      }
      // Size varies by segment; sample the beginning, middle and end. A server
      // that refuses HEAD or withholds Content-Length remains "size unknown".
      final indices = <int>{0, segments.length ~/ 2, segments.length - 1};
      var sampleBytes = 0;
      var sampleSeconds = 0.0;
      for (final index in indices) {
        final segment = segments[index];
        final size = await _headLength(
          segment.uri,
          _headersFor(uri, segment.uri, headers),
        );
        if (size == null || segment.duration <= 0) continue;
        sampleBytes += size;
        sampleSeconds += segment.duration;
      }
      if (sampleSeconds <= 0) return null;
      return _validBytes(sampleBytes / sampleSeconds * duration);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readManifest(Uri uri, Map<String, String> headers) async {
    final token = CancelToken();
    final response = await _dio.get<ResponseBody>(
      uri.toString(),
      cancelToken: token,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    final body = response.data;
    if (body == null) return null;
    final bytes = <int>[];
    await for (final chunk in body.stream) {
      if (bytes.length + chunk.length > _maxManifestBytes) {
        token.cancel('Manifest too large');
        return null;
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<int?> _headLength(Uri uri, Map<String, String> headers) async {
    try {
      final response = await _dio.head<void>(
        uri.toString(),
        options: Options(
          headers: headers,
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final size = int.tryParse(response.headers.value('content-length') ?? '');
      return size != null && size > 0 ? size : null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _headersFor(
    Uri parent,
    Uri child,
    Map<String, String> headers,
  ) {
    if (parent.scheme == child.scheme &&
        parent.host == child.host &&
        parent.port == child.port) {
      return headers;
    }
    // Don't leak cookies or bearer tokens when a manifest names another host.
    const safe = {'user-agent', 'referer', 'origin', 'accept'};
    return Map.fromEntries(
      headers.entries.where((entry) => safe.contains(entry.key.toLowerCase())),
    );
  }

  static int? _validBytes(num bytes) =>
      bytes.isFinite && bytes > 0 && bytes <= _maxEstimateBytes
      ? bytes.round()
      : null;

  static double? hlsDuration(String playlist) {
    var seconds = 0.0;
    for (final match in RegExp(
      r'^#EXTINF:([0-9.]+)',
      multiLine: true,
    ).allMatches(playlist)) {
      seconds += double.tryParse(match.group(1)!) ?? 0;
    }
    // Live/event playlists are incomplete; avoid presenting their window as a
    // whole-file estimate.
    return seconds > 0 && playlist.contains('#EXT-X-ENDLIST') ? seconds : null;
  }

  static List<HlsVariant> parseHlsVariants(String playlist, Uri base) {
    final lines = const LineSplitter().convert(playlist);
    final variants = <HlsVariant>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
      final bitrate =
          int.tryParse(
            RegExp(
                  r'(?:^|,)AVERAGE-BANDWIDTH=(\d+)',
                ).firstMatch(line.split(':').last)?.group(1) ??
                '',
          ) ??
          int.tryParse(
            RegExp(
                  r'(?:^|,)BANDWIDTH=(\d+)',
                ).firstMatch(line.split(':').last)?.group(1) ??
                '',
          ) ??
          0;
      final height = int.tryParse(
        RegExp(
              r'RESOLUTION=\d+x(\d+)',
              caseSensitive: false,
            ).firstMatch(line)?.group(1) ??
            '',
      );
      for (var next = i + 1; next < lines.length; next++) {
        final candidate = lines[next].trim();
        if (candidate.isEmpty) continue;
        if (candidate.startsWith('#')) break;
        final uri = base.resolve(candidate);
        if (['http', 'https'].contains(uri.scheme))
          variants.add(HlsVariant(uri, bitrate, height));
        break;
      }
    }
    return variants;
  }

  static HlsVariant chooseHlsVariant(
    List<HlsVariant> variants,
    int? maxHeight,
  ) {
    final withinLimit = maxHeight == null
        ? variants
        : variants
              .where((v) => v.height == null || v.height! <= maxHeight)
              .toList();
    final choices = withinLimit.isNotEmpty ? withinLimit : variants;
    return choices.reduce((a, b) => b.bitrate > a.bitrate ? b : a);
  }

  static List<HlsSegment> parseHlsSegments(String playlist, Uri base) {
    final result = <HlsSegment>[];
    double? duration;
    int? byteRange;
    for (final raw in const LineSplitter().convert(playlist)) {
      final line = raw.trim();
      if (line.startsWith('#EXTINF:')) {
        duration = double.tryParse(line.substring(8).split(',').first);
      } else if (line.startsWith('#EXT-X-BYTERANGE:')) {
        byteRange = int.tryParse(line.substring(17).split('@').first);
      } else if (line.isNotEmpty && !line.startsWith('#') && duration != null) {
        final uri = base.resolve(line);
        if (['http', 'https'].contains(uri.scheme))
          result.add(HlsSegment(uri, duration, byteRange));
        duration = null;
        byteRange = null;
      }
    }
    return result;
  }

  static int? estimateDash(String manifest, {int? maxHeight}) {
    try {
      final doc = XmlDocument.parse(manifest);
      final mpd = doc.findAllElements('MPD').firstOrNull;
      if (mpd == null || mpd.getAttribute('type') == 'dynamic') return null;
      final duration = _isoDuration(
        mpd.getAttribute('mediaPresentationDuration'),
      );
      if (duration == null) return null;
      var video = 0;
      var audio = 0;
      for (final set in doc.findAllElements('AdaptationSet')) {
        final reps = set.findElements('Representation').toList();
        final mime =
            (set.getAttribute('mimeType') ??
                    (reps.isEmpty
                        ? null
                        : reps.first.getAttribute('mimeType')) ??
                    '')
                .toLowerCase();
        final type = (set.getAttribute('contentType') ?? '').toLowerCase();
        final isVideo = type == 'video' || mime.startsWith('video/');
        final isAudio = type == 'audio' || mime.startsWith('audio/');
        if (!isVideo && !isAudio) continue;
        final bitrates = <int>[];
        for (final rep in reps) {
          final bitrate =
              int.tryParse(rep.getAttribute('bandwidth') ?? '') ?? 0;
          final height = int.tryParse(
            rep.getAttribute('height') ?? set.getAttribute('height') ?? '',
          );
          if (bitrate > 0 &&
              (!isVideo ||
                  maxHeight == null ||
                  height == null ||
                  height <= maxHeight)) {
            bitrates.add(bitrate);
          }
        }
        if (bitrates.isNotEmpty) {
          final selected = bitrates.reduce((a, b) => a > b ? a : b);
          if (isVideo && selected > video) video = selected;
          // One audio track is downloaded, not every advertised language.
          if (isAudio && selected > audio) audio = selected;
        }
      }
      return video > 0 ? _validBytes(duration * (video + audio) / 8) : null;
    } catch (_) {
      return null;
    }
  }

  static double? _isoDuration(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^P(?:(\d+(?:\.\d+)?)D)?(?:T(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?)?$',
    ).firstMatch(value);
    if (match == null) return null;
    double part(int i) => double.tryParse(match.group(i) ?? '') ?? 0;
    final duration = part(1) * 86400 + part(2) * 3600 + part(3) * 60 + part(4);
    return duration > 0 ? duration : null;
  }
}

class HlsVariant {
  const HlsVariant(this.uri, this.bitrate, this.height);
  final Uri uri;
  final int bitrate;
  final int? height;
}

class HlsSegment {
  const HlsSegment(this.uri, this.duration, this.byteRangeLength);
  final Uri uri;
  final double duration;
  final int? byteRangeLength;
}
