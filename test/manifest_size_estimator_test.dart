import 'dart:io';

import 'package:flixquest/services/manifest_size_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HLS chooses the best variant within the selected quality', () {
    const master = '''#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=4500000,AVERAGE-BANDWIDTH=4000000,RESOLUTION=1920x1080
1080.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720
720.m3u8
''';
    final variants = ManifestSizeEstimator.parseHlsVariants(
      master,
      Uri.parse('https://example.test/a/master.m3u8'),
    );
    expect(variants, hasLength(2));
    expect(variants.first.bitrate, 4000000);
    expect(
      ManifestSizeEstimator.chooseHlsVariant(variants, 720).uri.path,
      '/a/720.m3u8',
    );
    expect(ManifestSizeEstimator.chooseHlsVariant(variants, null).height, 1080);
  });

  test('HLS only estimates complete VOD playlists and parses ranges', () {
    const media = '''#EXTM3U
#EXTINF:10,
#EXT-X-BYTERANGE:1200@0
video.mp4
#EXTINF:12.5,
#EXT-X-BYTERANGE:1500@1200
video.mp4
#EXT-X-ENDLIST
''';
    expect(ManifestSizeEstimator.hlsDuration(media), 22.5);
    expect(
      ManifestSizeEstimator.hlsDuration(media.replaceAll('#EXT-X-ENDLIST', '')),
      isNull,
    );
    final segments = ManifestSizeEstimator.parseHlsSegments(
      media,
      Uri.parse('https://example.test/playlist'),
    );
    expect(segments.map((s) => s.byteRangeLength), [1200, 1500]);
  });

  test('DASH adds one audio track to selected video bitrate', () {
    const mpd = '''<MPD mediaPresentationDuration="PT1H30M" type="static">
<Period><AdaptationSet contentType="video">
<Representation bandwidth="1000000" height="480"/>
<Representation bandwidth="3000000" height="1080"/>
</AdaptationSet><AdaptationSet contentType="audio">
<Representation bandwidth="128000"/>
</AdaptationSet></Period></MPD>''';
    expect(
      ManifestSizeEstimator.estimateDash(mpd, maxHeight: 720),
      (5400 * 1128000 / 8).round(),
    );
    expect(
      ManifestSizeEstimator.estimateDash(mpd.replaceAll('static', 'dynamic')),
      isNull,
    );
    expect(ManifestSizeEstimator.estimateDash('not xml'), isNull);
  });

  test(
    'falls back to bounded HEAD sampling without downloading segments',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests = <String>[];
      server.listen((request) async {
        requests.add('${request.method} ${request.uri.path}');
        if (request.uri.path == '/video.m3u8') {
          request.response.write(
            '#EXTM3U\n#EXTINF:10,\na.ts\n#EXTINF:10,\nb.ts\n#EXT-X-ENDLIST\n',
          );
        } else if (request.method == 'HEAD') {
          request.response.headers.contentLength = 1000;
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });
      final value = await ManifestSizeEstimator().estimate(
        url: 'http://127.0.0.1:${server.port}/video.m3u8',
        format: 'hls',
        headers: const {},
      );
      expect(value, 2000);
      expect(requests.where((r) => r.startsWith('HEAD ')), hasLength(2));
      expect(
        requests.where(
          (r) => r.startsWith('GET /a.ts') || r.startsWith('GET /b.ts'),
        ),
        isEmpty,
      );
    },
  );
}
