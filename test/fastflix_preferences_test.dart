import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/functions/video_utils.dart';
import 'package:flixquest/models/fastflix_logo.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/video_providers/common.dart';
import 'package:flixquest/video_providers/language_priority.dart';
import 'package:flixquest/video_providers/names.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('io.github.skywave22.fastflix/branding');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'third logo is default and changes survive restart and notify Android',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      final settings = SettingsProvider();
      addTearDown(settings.dispose);
      await settings.getFastFlixLogo();
      expect(settings.fastFlixLogo, FastFlixLogo.play);
      expect(await settings.setFastFlixLogo(FastFlixLogo.wing), isTrue);
      expect(calls.single.arguments, {'logo': 'wing'});
      final restored = SettingsProvider();
      addTearDown(restored.dispose);
      await restored.getFastFlixLogo();
      expect(restored.fastFlixLogo, FastFlixLogo.wing);
      await sharedPrefsSingleton.setString('fastflix_logo', 'invalid');
      await restored.getFastFlixLogo();
      expect(restored.fastFlixLogo, FastFlixLogo.play);
    },
  );

  test('launcher failure does not hide the in-app choice', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'NO_ICON');
        });
    final settings = SettingsProvider();
    addTearDown(settings.dispose);
    expect(await settings.setFastFlixLogo(FastFlixLogo.f), isFalse);
    expect(settings.fastFlixLogo, FastFlixLogo.f);
  });

  test('screen fit and Hindi preference persist', () async {
    final settings = SettingsProvider();
    addTearDown(settings.dispose);
    expect(settings.screenFill, isFalse);
    expect(settings.preferHindiSources, isTrue);
    settings.screenFill = true;
    settings.preferHindiSources = false;
    final restored = SettingsProvider();
    addTearDown(restored.dispose);
    await restored.getScreenFill();
    await restored.getPreferHindiSources();
    expect(restored.screenFill, isTrue);
    expect(restored.preferHindiSources, isFalse);
  });

  test(
    'only explicitly Hindi providers are stably prioritized at playback',
    () {
      final settings = SettingsProvider();
      addTearDown(settings.dispose);
      final a = VideoProvider.scraper(id: 'a', name: 'Alpha');
      final b = VideoProvider.scraper(
        id: 'b',
        name: 'Beta',
        content: 'Hindi and English',
      );
      final c = VideoProvider.scraper(id: 'c', name: 'Cinema');
      final d = VideoProvider.scraper(id: 'd', name: 'हिन्दी');
      expect(settings.orderStreamProviders([a, b, c, d]), [a, b, c, d]);
      expect(settings.orderStreamProviders([a, b, c, d], forPlayback: true), [
        b,
        d,
        a,
        c,
      ]);
      expect(LanguagePriority.isHindi('high definition'), isFalse);
      settings.preferHindiSources = false;
      expect(settings.orderStreamProviders([a, b, c, d], forPlayback: true), [
        a,
        b,
        c,
        d,
      ]);
    },
  );

  test(
    'explicit Hindi server or language beats a higher non-Hindi quality',
    () {
      final links = [
        RegularVideoLinks(
          url: 'https://example.test/en',
          quality: '1080p',
          server: 'English',
        ),
        RegularVideoLinks(
          url: 'https://example.test/hi',
          quality: '480p',
          language: 'hi',
        ),
      ];
      final sources = VideoUtils.convertVideoLinksToMap(links);
      expect(
        VideoUtils.preferredVideoSource(
          sources,
          1080,
          preferHindi: true,
        )?.value,
        links[1].url,
      );
      expect(
        VideoUtils.preferredVideoSource(
          sources,
          1080,
          preferHindi: false,
        )?.value,
        links[0].url,
      );
    },
  );
}
