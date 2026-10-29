import 'package:flixquest/constants/api_constants.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/screens/common/connection_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final revision = dependencies.contentConfigurationRevision;
    await dependencies.saveClientConnection(
      tmdbKey: ' local_key ',
      scraperUrl: ' https://mine.test/api/v2/ ',
    );
    expect(TMDB_API_KEY, 'local_key');
    expect(dependencies.scraperApiCandidates, ['https://mine.test/api/v2']);
    expect(dependencies.flixquestAPIURL, 'https://mine.test/api/v2');
    expect(dependencies.contentConfigurationRevision, greaterThan(revision));
    final afterOverride = dependencies.contentConfigurationRevision;
    dependencies.setRemoteTmdbApiKey('new_remote_key');
    expect(TMDB_API_KEY, 'local_key');
    expect(dependencies.contentConfigurationRevision, afterOverride);

    final reloaded = AppDependencyProvider();
    addTearDown(reloaded.dispose);
    await reloaded.loadClientConnection();
    expect(reloaded.clientTmdbKey, 'local_key');
    expect(reloaded.clientScraperUrl, 'https://mine.test/api/v2');
    expect(TMDB_API_KEY, 'local_key');
    await reloaded.saveClientConnection(tmdbKey: '', scraperUrl: '');
    expect(TMDB_API_KEY, 'new_remote_key');
    expect(reloaded.clientScraperUrl, isEmpty);
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
