import '../functions/video_utils.dart';
import '../video_providers/scraper_api.dart';
import 'manifest_size_estimator.dart';

/// Estimates every listed quality without blocking the picker. Signed scraper
/// estimates are preferred; bounded manifest/HEAD inspection is a fallback.
/// All values are approximate and a source may not expose enough information.
abstract final class StreamSizeEstimator {
  static final Map<String, Future<StreamSizeEstimate?>> _inFlightByRequest = {};

  static Future<Map<String, int?>> load({
    required String scraperApiUrl,
    required Map<String, String> tokens,
    required Map<String, String> sources,
    required Map<String, String> formats,
    required Map<String, Map<String, String>> headers,
    required Map<String, int?> cacheByToken,
    void Function(String resolution, int? estimatedBytes)? onEstimate,
    ManifestSizeEstimator? manifestEstimator,
  }) async {
    final result = <String, int?>{};
    final pending = sources.entries.toList(growable: false);
    final manifest = manifestEstimator ?? ManifestSizeEstimator();
    var next = 0;

    Future<void> worker() async {
      while (next < pending.length) {
        final entry = pending[next++];
        final token = tokens[entry.key];
        int? bytes;
        if (token != null && token.trim().isNotEmpty) {
          if (cacheByToken.containsKey(token)) {
            bytes = cacheByToken[token];
          } else {
            final requestKey = '$scraperApiUrl\u0000$token';
            final request = _inFlightByRequest.putIfAbsent(
              requestKey,
              () async {
                try {
                  return await ScraperApi(
                    scraperApiUrl,
                  ).estimateStreamSize(token);
                } finally {
                  _inFlightByRequest.remove(requestKey);
                }
              },
            );
            bytes = (await request)?.estimatedBytes;
            // A failed estimate is not cached permanently; a later attempt may
            // work after a temporary network or backend failure.
            if (bytes != null && bytes > 0) cacheByToken[token] = bytes;
          }
        }
        if (bytes == null || bytes <= 0) {
          bytes = await manifest.estimate(
            url: entry.value,
            format: formats[entry.key] ?? 'hls',
            headers: headers[entry.key] ?? const {},
            maxHeight: VideoUtils.videoQualityHeight(entry.key),
          );
        }
        result[entry.key] = bytes;
        onEstimate?.call(entry.key, bytes);
      }
    }

    // A long quality list should not flood the provider or the user's network.
    await Future.wait(
      List.generate(pending.length.clamp(0, 3).toInt(), (_) => worker()),
    );
    return result;
  }
}
