import 'package:flixquest/models/download_settings.dart';
import 'package:flixquest/models/offline_download.dart';
import 'package:flixquest/screens/common/download_settings_sheet.dart';
import 'package:flixquest/services/offline_download_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tv_localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeTvTranslations();
  const channel = MethodChannel('dev.beamlak.flixquest/stream_downloads');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('defaults, bounds, and platform serialization agree', () {
    final defaults = DownloadSettings.fromMap(const {});
    expect(defaults.toMap(), {
      'segments': 8,
      'parallelDownloads': 2,
      'retryCount': 6,
      'unmeteredOnly': false,
    });
    final settings = DownloadSettings.fromMap({
      'segments': 100,
      'parallelDownloads': -1,
      'retryCount': 15,
      'unmeteredOnly': true,
    });
    expect(settings.toMap(), {
      'segments': 16,
      'parallelDownloads': 1,
      'retryCount': 10,
      'unmeteredOnly': true,
    });
    expect(settings.copyWith(segments: 0).segments, 1);
  });

  test('the bridge reads and writes effective native settings', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getDownloadSettings') {
        return {
          'segments': 12,
          'parallelDownloads': 3,
          'retryCount': 8,
          'unmeteredOnly': true
        };
      }
      if (call.method == 'setDownloadSettings') return call.arguments;
      throw MissingPluginException();
    });

    final service = OfflineDownloadService.instance;
    final loaded = await service.getDownloadSettings();
    expect(loaded.segments, 12);
    expect(loaded.unmeteredOnly, isTrue);
    final saved = await service.setDownloadSettings(
        loaded.copyWith(segments: 9, unmeteredOnly: false));
    expect(saved.segments, 9);
    expect(calls.last.arguments, {
      'segments': 9,
      'parallelDownloads': 3,
      'retryCount': 8,
      'unmeteredOnly': false,
    });
  });

  test('ETA is available only for active jobs with a useful rate and total',
      () {
    OfflineDownload download({
      String state = 'downloading',
      int downloaded = 1000000,
      int length = 7000000,
      double rate = 100000,
      double progress = 0,
    }) =>
        OfflineDownload.fromMap({
          'id': '1',
          'state': state,
          'bytesDownloaded': downloaded,
          'contentLength': length,
          'networkRateBytesPerSecond': rate,
          'progress': progress,
        });

    expect(download().estimatedTimeRemaining, const Duration(seconds: 60));
    expect(download(length: -1, progress: 25).estimatedTimeRemaining, isNull);
    expect(download(state: 'queued').estimatedTimeRemaining, isNull);
    expect(download(rate: 0).estimatedTimeRemaining, isNull);
    expect(download(rate: double.nan).estimatedTimeRemaining, isNull);
    expect(download(length: -1, progress: 0).estimatedTimeRemaining, isNull);
    expect(download(length: 1000000).estimatedTimeRemaining, isNull);
  });

  testWidgets('advanced settings can be changed and saved', (tester) async {
    DownloadSettings? saved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: Builder(
          builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => DownloadSettingsSheet(
                    load: () async => const DownloadSettings(),
                    save: (settings) async {
                      saved = settings;
                      return settings;
                    },
                  ),
                ),
                child: const Text('Open'),
              )),
    )));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    tester
        .widget<Slider>(find.byKey(const Key('download_segments_slider')))
        .onChanged!(12);
    await tester.pump();
    tester
        .widget<Slider>(find.byKey(const Key('download_parallel_slider')))
        .onChanged!(4);
    await tester.pump();
    tester
        .widget<Slider>(find.byKey(const Key('download_retries_slider')))
        .onChanged!(3);
    await tester.pump();
    tester
        .widget<SwitchListTile>(
            find.byKey(const Key('download_unmetered_switch')))
        .onChanged!(true);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save_download_settings')));
    await tester.tap(find.byKey(const Key('save_download_settings')));
    await tester.pumpAndSettle();
    expect(saved?.toMap(), {
      'segments': 12,
      'parallelDownloads': 4,
      'retryCount': 3,
      'unmeteredOnly': true,
    });
  });

  testWidgets('a failed load can be retried without losing the sheet',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: DownloadSettingsSheet(load: () async {
        if (++attempts == 1) throw StateError('unavailable');
        return const DownloadSettings();
      }),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Could not update download settings. Please try again.'),
        findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byKey(const Key('download_segments_slider')), findsOneWidget);
  });
}
