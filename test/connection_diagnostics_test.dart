import 'package:dio/dio.dart';
import 'package:flixquest/services/connection_diagnostics.dart';
import 'package:flixquest/video_providers/names.dart';
import 'package:flixquest/video_providers/provider_discovery.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/callback_dio.dart';

void main() {
  test('checks the unsaved TMDB key without using a cache', () async {
    var calls = 0;
    final dio = scriptedDio((request) async {
      calls++;
      expect(request.uri.queryParameters['api_key'], 'new_key');
      expect(request.extra['retryLimit'], 0);
      return jsonResponse('{"images":{"base_url":"https://images.test"}}', 200);
    });
    addTearDown(dio.close);
    final diagnostic = ConnectionDiagnostics(dio: dio);
    expect(
      await diagnostic.checkTmdb(key: '', proxyUrl: ''),
      TmdbConnectionStatus.missingKey,
    );
    expect(
      await diagnostic.checkTmdb(key: 'new_key', proxyUrl: ''),
      TmdbConnectionStatus.connectedDirect,
    );
    expect(calls, 1);
  });

  test(
    'distinguishes an authentic TMDB rejection from an HTML block',
    () async {
      var calls = 0;
      final dio = scriptedDio((_) async {
        calls++;
        return calls == 1
            ? jsonResponse('{"success":false,"status_code":7}', 401)
            : ResponseBody.fromString('<html>blocked</html>', 403);
      });
      addTearDown(dio.close);
      final diagnostic = ConnectionDiagnostics(dio: dio);
      expect(
        await diagnostic.checkTmdb(key: 'bad_key', proxyUrl: ''),
        TmdbConnectionStatus.rejectedKey,
      );
      expect(
        await diagnostic.checkTmdb(key: 'new_key', proxyUrl: ''),
        TmdbConnectionStatus.blocked,
      );
    },
  );

  test(
    'tries a trusted HTTPS proxy only after the direct route fails',
    () async {
      final requests = <RequestOptions>[];
      final dio = scriptedDio((request) async {
        requests.add(request);
        return request.uri.host == 'api.themoviedb.org'
            ? ResponseBody.fromString('<html>blocked</html>', 403)
            : jsonResponse('{"images":{}}', 200);
      });
      addTearDown(dio.close);
      final diagnostic = ConnectionDiagnostics(dio: dio);
      expect(
        await diagnostic.checkTmdb(
          key: 'new_key',
          proxyUrl: 'https://proxy.example/tmdb',
        ),
        TmdbConnectionStatus.connectedProxy,
      );
      expect(requests, hasLength(2));
      expect(requests.last.uri.host, 'proxy.example');
      final destination = requests.last.uri.queryParameters['destination'];
      expect(Uri.parse(destination!).queryParameters['api_key'], 'new_key');
    },
  );

  test('does not send a key through an insecure proxy', () async {
    var calls = 0;
    final dio = scriptedDio((_) async {
      calls++;
      return ResponseBody.fromString('<html>blocked</html>', 403);
    });
    addTearDown(dio.close);
    final diagnostic = ConnectionDiagnostics(dio: dio);
    expect(
      await diagnostic.checkTmdb(key: 'key', proxyUrl: 'http://proxy.test'),
      TmdbConnectionStatus.blocked,
    );
    expect(calls, 1);
  });

  test(
    'classifies rate limits and network failures without exposing errors',
    () async {
      var calls = 0;
      final dio = scriptedDio((request) async {
        calls++;
        if (calls == 1) return jsonResponse('{}', 429);
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'no network',
        );
      });
      addTearDown(dio.close);
      final diagnostic = ConnectionDiagnostics(dio: dio);
      expect(
        await diagnostic.checkTmdb(key: 'key', proxyUrl: ''),
        TmdbConnectionStatus.rateLimited,
      );
      expect(
        await diagnostic.checkTmdb(key: 'key', proxyUrl: ''),
        TmdbConnectionStatus.unavailable,
      );
    },
  );

  test(
    'reports missing, enabled, empty and unavailable provider services',
    () async {
      var calls = 0;
      final dio = scriptedDio((_) async => jsonResponse('{}', 200));
      addTearDown(dio.close);
      final diagnostic = ConnectionDiagnostics(
        dio: dio,
        discover: (urls) async {
          calls++;
          if (calls == 3) throw StateError('service failed');
          return DiscoveredProviders(
            urls.first,
            calls == 1
                ? <VideoProvider>[VideoProvider.scraper(id: 'one', name: 'One')]
                : <VideoProvider>[],
          );
        },
      );
      expect(
        await diagnostic.checkProviders([]),
        ProviderConnectionStatus.notConfigured,
      );
      expect(
        await diagnostic.checkProviders(['https://one.test']),
        ProviderConnectionStatus.connected,
      );
      expect(
        await diagnostic.checkProviders(['https://one.test']),
        ProviderConnectionStatus.empty,
      );
      expect(
        await diagnostic.checkProviders(['https://one.test']),
        ProviderConnectionStatus.unavailable,
      );
    },
  );
}
