import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flixquest/constants/api_constants.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/screens/common/connection_settings_screen.dart';
import 'package:flixquest/services/connection_diagnostics.dart';
import 'package:flixquest/video_providers/names.dart';
import 'package:flixquest/video_providers/provider_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/callback_dio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    dotenv.testLoad(fileInput:
        'TMDB_API_KEY=bundled_key\nFLIXQUEST_API_URL=https://bundled.test');
    TMDB_API_KEY = '';
    setClientTmdbApiKey('');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });
  tearDown(() {
    TMDB_API_KEY = '';
    setClientTmdbApiKey('');
  });

  test('local public settings persist, override remote, and can be cleared',
      () async {
    final dependencies = AppDependencyProvider();
    addTearDown(dependencies.dispose);
    await dependencies.loadClientConnection();
    dependencies.setFlixquestApiConfig(
      instances: ['https://one.test/', 'https://two.test', 'https://one.test'],
      url: 'https://legacy.test',
    );
    expect(dependencies.scraperApiCandidates, [
      'https://one.test',
      'https://two.test',
      'https://legacy.test',
      'https://bundled.test',
    ]);
    dependencies.setRemoteTmdbApiKey('remote_key');
    dependencies.tmdbProxy = 'https://remote-proxy.test';
    final revision = dependencies.contentConfigurationRevision;
    await dependencies.saveClientConnection(
      tmdbKey: ' local_key ',
      scraperUrl: ' https://mine.test/api/v2/ ',
      tmdbProxy: ' https://my-proxy.test/tmdb/ ',
    );
    expect(TMDB_API_KEY, 'local_key');
    expect(dependencies.tmdbProxy, 'https://my-proxy.test/tmdb');
    expect(dependencies.fallbackTmdbProxy, 'https://remote-proxy.test');
    expect(dependencies.scraperApiCandidates, ['https://mine.test/api/v2']);
    expect(dependencies.flixquestAPIURL, 'https://mine.test/api/v2');
    expect(dependencies.contentConfigurationRevision, greaterThan(revision));
    final afterOverride = dependencies.contentConfigurationRevision;
    dependencies.setRemoteTmdbApiKey('new_remote_key');
    dependencies.tmdbProxy = 'https://new-remote-proxy.test';
    expect(TMDB_API_KEY, 'local_key');
    expect(dependencies.tmdbProxy, 'https://my-proxy.test/tmdb');
    expect(dependencies.contentConfigurationRevision, afterOverride);

    final reloaded = AppDependencyProvider();
    addTearDown(reloaded.dispose);
    await reloaded.loadClientConnection();
    await reloaded.getTmdbProxy();
    expect(reloaded.clientTmdbKey, 'local_key');
    expect(reloaded.clientScraperUrl, 'https://mine.test/api/v2');
    expect(reloaded.clientTmdbProxy, 'https://my-proxy.test/tmdb');
    expect(TMDB_API_KEY, 'local_key');
    await reloaded.saveClientConnection(tmdbKey: '', scraperUrl: '');
    expect(TMDB_API_KEY, 'new_remote_key');
    expect(reloaded.clientScraperUrl, isEmpty);
    expect(reloaded.tmdbProxy, 'https://new-remote-proxy.test');
  });

  test('bundled provider remains in the bounded discovery attempts', () {
    final dependencies = AppDependencyProvider();
    addTearDown(dependencies.dispose);
    dependencies.setFlixquestApiConfig(
      instances: [for (var i = 0; i < 6; i++) 'https://server$i.test'],
      url: 'https://legacy.test',
    );
    expect(dependencies.scraperApiCandidates.take(4), [
      'https://server0.test',
      'https://server1.test',
      'https://legacy.test',
      'https://bundled.test',
    ]);
  });

  test('rejects sensitive or malformed connection values', () {
    expect(AppDependencyProvider.validClientTmdbKey('abc123'), isTrue);
    expect(AppDependencyProvider.validClientTmdbKey('Bearer token'), isFalse);
    expect(AppDependencyProvider.validClientScraperUrl('https://x.test/api/v2'),
        isTrue);
    expect(AppDependencyProvider.validClientScraperUrl('ftp://x.test'), isFalse);
    expect(AppDependencyProvider.validClientScraperUrl('https://user:pass@x.test'),
        isFalse);
    expect(AppDependencyProvider.validClientScraperUrl('https://x.test/?key=secret'),
        isFalse);
    expect(AppDependencyProvider.validClientTmdbProxy('https://x.test/tmdb'), isTrue);
    expect(AppDependencyProvider.validClientTmdbProxy('http://x.test'), isFalse);
    expect(AppDependencyProvider.validClientTmdbProxy('https://x.test/?token=secret'),
        isFalse);
  });

  testWidgets('connection checks use unsaved values and display both results',
      (tester) async {
    final dependencies = AppDependencyProvider();
    addTearDown(dependencies.dispose);
    final requests = <RequestOptions>[];
    final dio = scriptedDio((request) async {
      requests.add(request);
      return jsonResponse('{"images":{}}', 200);
    });
    addTearDown(dio.close);
    final diagnostics = ConnectionDiagnostics(dio: dio, discover: (urls) async {
      expect(urls, ['https://typed.test']);
      return DiscoveredProviders(urls.first, <VideoProvider>[
        VideoProvider.scraper(id: 'one', name: 'One'),
      ]);
    });
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: dependencies,
      child: MaterialApp(home: ConnectionSettingsScreen(diagnostics: diagnostics)),
    ));
    await tester.enterText(find.byKey(const ValueKey('connection-tmdb-key')),
        'unsaved_key');
    await tester.enterText(find.byKey(const ValueKey('connection-scraper-url')),
        'https://typed.test');
    await tester.tap(find.byKey(const ValueKey('connection-test')));
    await tester.pumpAndSettle();
    expect(requests.single.uri.queryParameters['api_key'], 'unsaved_key');
    expect(find.text('connection_tmdb_connected'), findsOneWidget);
    expect(find.text('connection_provider_connected'), findsOneWidget);
    expect(dependencies.clientTmdbKey, isEmpty);
    expect(dependencies.clientScraperUrl, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('connection-tmdb-key')),
        'another_key');
    await tester.pump();
    expect(find.byKey(const ValueKey('connection-tmdb-result')), findsNothing);
  });

  testWidgets('editing a field discards an older running check', (tester) async {
    final dependencies = AppDependencyProvider();
    addTearDown(dependencies.dispose);
    final response = Completer<ResponseBody>();
    final dio = scriptedDio((_) => response.future);
    addTearDown(dio.close);
    final diagnostics = ConnectionDiagnostics(dio: dio, discover: (urls) async =>
        DiscoveredProviders(urls.first, <VideoProvider>[]));
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: dependencies,
      child: MaterialApp(home: ConnectionSettingsScreen(diagnostics: diagnostics)),
    ));
    await tester.enterText(find.byKey(const ValueKey('connection-tmdb-key')),
        'old_key');
    await tester.tap(find.byKey(const ValueKey('connection-test')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('connection-tmdb-key')),
        'new_key');
    response.complete(jsonResponse('{"images":{}}', 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('connection-tmdb-result')), findsNothing);
    expect(find.byKey(const ValueKey('connection-provider-result')), findsNothing);
  });

  testWidgets('TV remote can activate the setup save button', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dependencies = AppDependencyProvider();
    addTearDown(dependencies.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: dependencies,
      child: MaterialApp(
        home: Builder(builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const ConnectionSettingsScreen(television: true),
            )),
            child: const Text('Open TV setup'),
          ),
        )),
      ),
    ));
    await tester.tap(find.text('Open TV setup'));
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Connection Save');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Open TV setup'), findsOneWidget);
  });

  testWidgets('setup validates values and saves them on this device',
      (tester) async {
    final dependencies = AppDependencyProvider();
    addTearDown(dependencies.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: dependencies,
      child: MaterialApp(
        home: Builder(builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const ConnectionSettingsScreen(),
            )),
            child: const Text('Open setup'),
          ),
        )),
      ),
    ));
    await tester.tap(find.text('Open setup'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('connection-tmdb-key')),
        'not a v3 key');
    await tester.enterText(find.byKey(const ValueKey('connection-scraper-url')),
        'https://example.test/?token=secret');
    await tester.ensureVisible(find.byKey(const ValueKey('connection-save')));
    await tester.tap(find.byKey(const ValueKey('connection-save')));
    await tester.pumpAndSettle();
    expect(find.text('connection_invalid_key'), findsOneWidget);
    expect(find.text('connection_invalid_url'), findsOneWidget);
    expect(dependencies.clientTmdbKey, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('connection-tmdb-key')),
        'my_public_v3_key');
    await tester.enterText(find.byKey(const ValueKey('connection-scraper-url')),
        'https://providers.test/api/v2');
    await tester.ensureVisible(find.byKey(const ValueKey('connection-save')));
    await tester.tap(find.byKey(const ValueKey('connection-save')));
    await tester.pumpAndSettle();
    expect(dependencies.clientTmdbKey, 'my_public_v3_key');
    expect(dependencies.clientScraperUrl, 'https://providers.test/api/v2');
    expect(find.text('Open setup'), findsOneWidget);
  });
}
