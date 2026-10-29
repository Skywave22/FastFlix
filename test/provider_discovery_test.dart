import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import 'package:flixquest/core/network/network_runtime.dart';
import 'package:flixquest/video_providers/names.dart';
import 'package:flixquest/video_providers/provider_discovery.dart';
import 'package:flixquest/video_providers/scraper_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_dio.dart';

void main() {
  final provider = VideoProvider.scraper(id: 'hindi', name: 'Hindi source');

  test('tries another server and returns its URL with the provider list', () async {
    final calls = <String>[];
    final result = await ProviderDiscovery.load(
      ['https://first.test/', 'https://first.test', 'https://second.test'],
      fetch: (url, _) async {
        calls.add(url);
        if (url.contains('first')) throw StateError('offline');
        return [provider];
      },
    );
    expect(calls, ['https://first.test', 'https://second.test']);
    expect(result.baseUrl, 'https://second.test');
    expect(result.providers.single.apiId, 'hindi');
  });

  test('tries past an empty catalog, retaining an empty success if needed', () async {
    final calls = <String>[];
    final result = await ProviderDiscovery.load(
      ['https://empty.test', 'https://down.test'],
      fetch: (url, _) async {
        calls.add(url);
        if (url.contains('down')) throw StateError('offline');
        return [];
      },
    );
    expect(calls, hasLength(2));
    expect(result.baseUrl, 'https://empty.test');
    expect(result.providers, isEmpty);
  });

  test('cancels a hanging request before moving to the next instance', () async {
    CancelToken? firstToken;
    final result = await ProviderDiscovery.load(
      ['https://slow.test', 'https://healthy.test'],
      perHostTimeout: const Duration(milliseconds: 20),
      fetch: (url, token) {
        if (url.contains('slow')) {
          firstToken = token;
          return Completer<List<VideoProvider>>().future;
        }
        return Future.value([provider]);
      },
    );
    expect(firstToken?.isCancelled, isTrue);
    expect(result.baseUrl, 'https://healthy.test');
  });

  test('ignores invalid URLs and limits attempts to four instances', () async {
    final calls = <String>[];
    await expectLater(
      ProviderDiscovery.load(
        [
          'not a url',
          'https://user:password@invalid.test',
          for (var i = 0; i < 7; i++) 'https://server$i.test',
        ],
        fetch: (url, _) async {
          calls.add(url);
          throw StateError('offline');
        },
      ),
      throwsA(isA<ScraperApiException>()),
    );
    expect(calls, [for (var i = 0; i < 4; i++) 'https://server$i.test']);
  });

  test('discovery bypasses cached catalogs so a dead host can fail over', () async {
    final cache = HttpCache(MemCacheStore());
    final adapter = FakeDioAdapter();
    final dio = createPublicDio(AppEnvironment.resolve(isDebug: true),
        httpCache: cache, debugLogging: false, retryDelay: (_) async {});
    dio.httpClientAdapter = adapter;
    NetworkRuntime.configure(publicDio: dio, httpCache: cache);
    addTearDown(dio.close);
    addTearDown(cache.close);
    Map<String, dynamic> catalog(String id) => {
          'success': true,
          'providers': [
            {'id': id, 'name': id, 'enabled': true}
          ]
        };
    adapter.enqueueJson(catalog('old'));
    expect((await ScraperApi('https://first.test').getProviders()).single.apiId,
        'old');
    adapter.enqueueError(type: DioExceptionType.connectionError);
    adapter.enqueueJson(catalog('new'));
    final result = await ProviderDiscovery.load(
        ['https://first.test', 'https://second.test']);
    expect(result.baseUrl, 'https://second.test');
    expect(result.providers.single.apiId, 'new');
    expect(adapter.requests.map((r) => r.uri.host),
        ['first.test', 'first.test', 'second.test']);
    expect(adapter.requests[1].extra['retryLimit'], 0);
  });
}
