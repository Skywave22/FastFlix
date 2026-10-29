import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../core/cache/cache_policy.dart';
import '../core/network/network_runtime.dart';
import '../video_providers/provider_discovery.dart';
import 'tmdb_connectivity.dart';

enum TmdbConnectionStatus {
  missingKey,
  connectedDirect,
  connectedProxy,
  rejectedKey,
  blocked,
  unavailable,
  rateLimited,
  unexpectedResponse,
}

enum ProviderConnectionStatus { notConfigured, connected, empty, unavailable }

typedef ProviderDiscoveryCheck =
    Future<DiscoveredProviders> Function(Iterable<String> candidates);

/// Tests the values currently in the form, including unsaved changes. Requests
/// bypass the cache and never log keys, server responses, or exception text.
class ConnectionDiagnostics {
  ConnectionDiagnostics({
    Dio? dio,
    ProviderDiscoveryCheck? discover,
    this.timeout = const Duration(seconds: 8),
  }) : _dio = dio ?? NetworkRuntime.publicDio,
       _discover = discover ?? ProviderDiscovery.load;

  final Dio _dio;
  final ProviderDiscoveryCheck _discover;
  final Duration timeout;

  Future<TmdbConnectionStatus> checkTmdb({
    required String key,
    required String proxyUrl,
  }) async {
    key = key.trim();
    if (key.isEmpty) return TmdbConnectionStatus.missingKey;
    final direct = await _checkRoute(key, '');
    if (direct != TmdbConnectionStatus.blocked &&
        direct != TmdbConnectionStatus.unavailable &&
        direct != TmdbConnectionStatus.unexpectedResponse) {
      return direct;
    }
    final uri = Uri.tryParse(proxyUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return direct;
    }
    // The proxy is trusted to see the key. Its certificate must be checked,
    // even before an unsaved URL has been registered with the app runtime.
    final overrides = HttpOverrides.current;
    if (overrides is MyHttpOverrides) overrides.protectUrlHost(proxyUrl);
    final proxy = await _checkRoute(key, proxyUrl);
    return proxy == TmdbConnectionStatus.connectedDirect
        ? TmdbConnectionStatus.connectedProxy
        : proxy;
  }

  Future<TmdbConnectionStatus> _checkRoute(String key, String proxyUrl) async {
    final uri = Uri.parse(
      '$TMDB_API_BASE_URL/configuration',
    ).replace(queryParameters: {'api_key': key});
    final cancel = CancelToken();
    try {
      final response = await _dio
          .get<String>(
            uri.toString(),
            cancelToken: cancel,
            options: Options(
              responseType: ResponseType.plain,
              receiveTimeout: timeout,
              validateStatus: (_) => true,
              extra: {
                'cachePolicy': CachePolicy.noStore,
                'retryLimit': 0,
                'tmdbProxyEnabled': proxyUrl.isNotEmpty,
                'tmdbProxyUrl': proxyUrl,
              },
            ),
          )
          .timeout(
            timeout,
            onTimeout: () {
              cancel.cancel('Connection check timed out');
              throw TimeoutException('Connection check timed out');
            },
          );
      final status = response.statusCode ?? 0;
      final raw = response.data ?? '';
      Object? body;
      try {
        body = jsonDecode(raw);
      } on FormatException {
        body = null;
      }
      if (status == 200 && body is Map && body['images'] is Map) {
        return TmdbConnectionStatus.connectedDirect;
      }
      if ((status == 401 || status == 403) &&
          body is Map &&
          body['success'] == false &&
          body['status_code'] is num) {
        return TmdbConnectionStatus.rejectedKey;
      }
      if (status == 429) return TmdbConnectionStatus.rateLimited;
      if (TmdbConnectivity.looksBlocked(status, raw)) {
        return TmdbConnectionStatus.blocked;
      }
      if (status >= 500 || status == 0) {
        return TmdbConnectionStatus.unavailable;
      }
      return TmdbConnectionStatus.unexpectedResponse;
    } catch (_) {
      return TmdbConnectionStatus.unavailable;
    }
  }

  Future<ProviderConnectionStatus> checkProviders(
    Iterable<String> candidates,
  ) async {
    final urls = candidates.where((url) => url.trim().isNotEmpty).toList();
    if (urls.isEmpty) return ProviderConnectionStatus.notConfigured;
    try {
      final result = await _discover(urls);
      return result.providers.isEmpty
          ? ProviderConnectionStatus.empty
          : ProviderConnectionStatus.connected;
    } catch (_) {
      return ProviderConnectionStatus.unavailable;
    }
  }
}
