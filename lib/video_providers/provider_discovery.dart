import 'dart:async';

import 'package:dio/dio.dart';

import 'names.dart';
import 'scraper_api.dart';

typedef ProviderCatalogFetcher = Future<List<VideoProvider>> Function(
    String baseUrl, CancelToken cancelToken);

/// The selected server must travel with its catalog: stream and size tokens
/// issued by one server need to be sent back to that same server.
class DiscoveredProviders {
  const DiscoveredProviders(this.baseUrl, this.providers);

  final String baseUrl;
  final List<VideoProvider> providers;
}

/// Tries the configured scraper instances in order, rather than choosing a
/// random down server and hiding all other providers. Discovery has a short,
/// bounded deadline per host; a direct provider remains available to callers
/// if no scraper can be reached.
abstract final class ProviderDiscovery {
  static Future<DiscoveredProviders> load(
    Iterable<String> candidates, {
    Duration perHostTimeout = const Duration(seconds: 8),
    ProviderCatalogFetcher? fetch,
  }) async {
    final seen = <String>{};
    DiscoveredProviders? emptyResponse;
    var attempted = 0;
    for (final candidate in candidates) {
      final url = candidate.trim().replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          !seen.add(url)) {
        continue;
      }
      if (attempted == 4) break;
      attempted++;
      final token = CancelToken();
      try {
        final providers = await (fetch?.call(url, token) ??
                ScraperApi(url).getProviders(
                  cancelToken: token,
                  timeout: perHostTimeout,
                  // A fresh or stale cached catalog cannot prove that this
                  // host can actually serve the resulting stream tokens.
                  useCache: false,
                ))
            .timeout(perHostTimeout, onTimeout: () {
          token.cancel('Provider discovery timed out');
          throw TimeoutException('Provider discovery timed out');
        });
        final result = DiscoveredProviders(url, providers);
        if (providers.isNotEmpty) return result;
        // A healthy server may have all providers disabled. Check the other
        // instances before concluding that only the direct provider remains.
        emptyResponse ??= result;
      } catch (_) {
        // One unavailable instance must not prevent trying the others.
      }
    }
    if (emptyResponse != null) return emptyResponse;
    throw const ScraperApiException('No provider service could be reached');
  }
}
