import 'package:flixquest/models/download_settings.dart';
import 'package:flixquest/screens/common/download_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tv_localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeTvTranslations();
  const channel = MethodChannel('dev.beamlak.flixquest/stream_downloads');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  testWidgets('shows default location, lets the user choose and reset', (
    tester,
  ) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'getDownloadLocation' || 'resetDownloadLocation' => {
              'isDefault': true,
              'label': 'Downloads/FastFlix',
            },
            'chooseDownloadLocation' => {
              'isDefault': false,
              'label': 'My SD card',
            },
            _ => null,
          };
        });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadSettingsSheet(
            load: () async => const DownloadSettings(),
            save: (value) async => value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Downloads/FastFlix'), findsOneWidget);
    await tester.tap(find.byKey(const Key('choose_download_location')));
    await tester.pumpAndSettle();
    expect(find.text('My SD card'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset_download_location')));
    await tester.pumpAndSettle();
    expect(find.text('Downloads/FastFlix'), findsOneWidget);
    expect(calls, [
      'getDownloadLocation',
      'chooseDownloadLocation',
      'resetDownloadLocation',
    ]);
  });
}
