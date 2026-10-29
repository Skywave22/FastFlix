import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../provider/app_dependency_provider.dart';
import 'app_update_service.dart';
import 'remote_config_refresh_controller.dart';

class AppRemoteConfig {
  const AppRemoteConfig._();

  static const occasionalThemeKey = 'occasional_theme';
  static const appLogoKey = 'app_logo_url';
  static const legacyAppLogoKey = 'cinemax_logo';
  static const flixquestApiInstancesKey = 'flixquest_api_instances';
  static const flixquestApiUrlKey = 'flixquest_api_url_v2';
  static const laravelApiUrlKey = 'laravel_api_url';
  static const tmdbApiKey = 'tmdb_api_key';
  static const enableWatchNowKey = 'enable_stream';
  static const enableDownloadKey = 'enable_download';
  static const enableLiveTvKey = 'enable_live_tv';
  static const telegramChannelUrlKey = 'telegram_channel_url';
  static const appDownloadUrlKey = 'app_download_url';

  /// Per-ABI APK links, e.g. `app_download_url_arm64_v8a`. An empty one sends
  /// that ABI to the universal [appDownloadUrlKey] build.
  static String abiDownloadUrlKey(String abi) =>
      '${appDownloadUrlKey}_${abi.replaceAll('-', '_')}';

  /// Live TV used to ride on the OTT flag before it got a dedicated key.
  static const legacyEnableLiveTvKey = 'enable_ott';

  static Future<void> configure(FirebaseRemoteConfig remoteConfig) async {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : RemoteConfigRefreshController.minimumFetchInterval,
      ),
    );
    await remoteConfig.setDefaults(defaults);
  }

  static Map<String, Object> get defaults => <String, Object>{
        occasionalThemeKey: '{"enabled":false}',
        appLogoKey: '',
        legacyAppLogoKey: 'default',
        'forced_update': false,
        'latest_version': '',
        'latest_build_number': 0,
        'min_build_number': 0,
        appDownloadUrlKey: '',
        for (final abi in AppUpdateService.splitApkAbis)
          abiDownloadUrlKey(abi): '',
        'change_log': '',
        flixquestApiInstancesKey: '',
        flixquestApiUrlKey: '',
        // Backend routing is applied independently of the feature config source.
        laravelApiUrlKey: '',
        tmdbApiKey: '',
        // Feature toggles ship enabled so a failed or offline fetch never hides
        // playback, downloads or Live TV.
        enableWatchNowKey: true,
        enableDownloadKey: true,
        enableLiveTvKey: true,
        legacyEnableLiveTvKey: true,
        // Empty keeps the Home prompt to join the channel off.
        telegramChannelUrlKey: '',
      };

  static List<String> parseApiInstances(String rawJson) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> && decoded['instances'] is List) {
        return (decoded['instances'] as List)
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      } else if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      // Malformed JSON falls back gracefully.
    }
    return const [];
  }

  static void apply(
    FirebaseRemoteConfig remoteConfig,
    AppDependencyProvider provider,
  ) =>
      _apply(_ConfigValues(remoteConfig.getValue), provider);

  /// Apply the selected backend's snapshot through the same runtime mapping.
  static void applySnapshot(
    Map<String, dynamic> settings,
    AppDependencyProvider provider,
  ) {
    final fallback = defaults;
    _apply(_ConfigValues((key) {
      final published = settings.containsKey(key) && settings[key] != null;
      final value = published ? settings[key] : fallback[key];
      final text = value is String
          ? value
          : value == null
              ? ''
              : value is Map || value is List
                  ? jsonEncode(value)
                  : value.toString();
      return RemoteConfigValue(Uint8List.fromList(utf8.encode(text)),
          published ? ValueSource.valueRemote : ValueSource.valueDefault);
    }), provider);
  }

  static void _apply(
      _ConfigValues remoteConfig, AppDependencyProvider provider) {
    final preferredLogoValue = remoteConfig.getValue(appLogoKey);
    final legacyLogoValue = remoteConfig.getValue(legacyAppLogoKey);
    final preferredLogo = preferredLogoValue.asString().trim();
    final legacyLogo = legacyLogoValue.asString().trim();
    if (preferredLogoValue.source == ValueSource.valueRemote &&
        preferredLogo.isNotEmpty) {
      provider.flixQuestLogo = preferredLogo;
    } else if (legacyLogoValue.source == ValueSource.valueRemote) {
      provider.flixQuestLogo = legacyLogo;
    } else if (preferredLogoValue.source == ValueSource.valueRemote) {
      provider.flixQuestLogo = 'default';
    }

    final occasionalThemeValue = remoteConfig.getValue(occasionalThemeKey);
    if (occasionalThemeValue.source == ValueSource.valueRemote) {
      provider.applyRemoteOccasionalTheme(occasionalThemeValue.asString());
    }
    provider.displayWatchNowButton = remoteConfig.getBool(enableWatchNowKey);
    provider.displayDownloadButton = remoteConfig.getBool(enableDownloadKey);
    provider.displayLiveTV = _resolveLiveTv(remoteConfig);
    final instancesRaw = remoteConfig.getString(flixquestApiInstancesKey);
    final parsedInstances = parseApiInstances(instancesRaw);
    final legacyUrl = remoteConfig.getString(flixquestApiUrlKey).trim();
    provider.setFlixquestApiConfig(
      instances: parsedInstances,
      url: legacyUrl.isNotEmpty ? legacyUrl : null,
    );

    provider.setUpdateConfiguration(
      forced: remoteConfig.getBool('forced_update'),
      latestVersion: remoteConfig.getString('latest_version'),
      latestBuild: remoteConfig.getInt('latest_build_number'),
      minimumBuild: remoteConfig.getInt('min_build_number'),
      downloadUrl: remoteConfig.getString(appDownloadUrlKey),
      abiDownloadUrls: {
        for (final abi in AppUpdateService.splitApkAbis)
          abi: remoteConfig.getString(abiDownloadUrlKey(abi)),
      },
      changeLog: remoteConfig.getString('change_log'),
    );
    provider.tmdbProxy = remoteConfig.getString('tmdb_proxy');
    provider
        .setTelegramChannelUrl(remoteConfig.getString(telegramChannelUrlKey));
    final remoteTmdbKey = remoteConfig.getString(tmdbApiKey).trim();
    if (remoteTmdbKey.isNotEmpty) {
      TMDB_API_KEY = remoteTmdbKey;
    }
  }

  /// Resolves the Live TV toggle, preferring [enableLiveTvKey] and falling back
  /// to [legacyEnableLiveTvKey] for consoles that have not migrated yet. Only
  /// values actually published remotely win; otherwise the feature stays on.
  static bool _resolveLiveTv(_ConfigValues remoteConfig) {
    final value = remoteConfig.getValue(enableLiveTvKey);
    if (value.source == ValueSource.valueRemote) return value.asBool();
    final legacy = remoteConfig.getValue(legacyEnableLiveTvKey);
    if (legacy.source == ValueSource.valueRemote) return legacy.asBool();
    return true;
  }
}

class _ConfigValues {
  const _ConfigValues(this.getValue);
  final RemoteConfigValue Function(String) getValue;
  String getString(String key) => getValue(key).asString();
  bool getBool(String key) => getValue(key).asBool();
  int getInt(String key) => getValue(key).asInt();
}
