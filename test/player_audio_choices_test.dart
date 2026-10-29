import 'package:better_player_plus/better_player_plus.dart';
import 'package:flixquest/screens/common/player/player_audio_choices.dart';
import 'package:flixquest/screens/common/player/player_sheet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tv_localization.dart';

void main() {
  initializeTvTranslations();

  test('missing metadata gets a usable index and native-safe label', () {
    final original = BetterPlayerAsmsAudioTrack();
    final choice = selectableAudioTrack(original, 2);
    expect(choice.id, 2);
    expect(choice.label, 'Audio 3');
    expect(choice.language, 'und');

    final named = BetterPlayerAsmsAudioTrack(
      id: 5,
      label: ' Commentary ',
      language: ' en ',
      isDefault: true,
    );
    final normalized = selectableAudioTrack(named, 0);
    expect(normalized.id, 5);
    expect(normalized.label, 'Commentary');
    expect(normalized.language, 'en');
    expect(normalized.isDefault, isTrue);
  });

  test('DASH language fallback is used only for an unambiguous language', () {
    final english = BetterPlayerAsmsAudioTrack(id: 0, language: 'en');
    final japanese = BetterPlayerAsmsAudioTrack(id: 1, language: ' Ja ');
    expect(uniqueDashAudioLanguage([english, japanese], japanese), 'Ja');
    expect(
      uniqueDashAudioLanguage([
        english,
        japanese,
        BetterPlayerAsmsAudioTrack(id: 2, language: 'ja'),
      ], japanese),
      isNull,
    );
    expect(
      uniqueDashAudioLanguage([
        english,
        japanese,
        BetterPlayerAsmsAudioTrack(id: 2, language: 'eng'),
      ], english),
      isNull,
    );
    final regional = BetterPlayerAsmsAudioTrack(id: 1, language: 'ja_JP');
    expect(uniqueDashAudioLanguage([english, regional], regional), 'ja-JP');
    expect(
      uniqueDashAudioLanguage([
        english,
        regional,
        BetterPlayerAsmsAudioTrack(id: 2, language: 'ja-US'),
      ], regional),
      isNull,
    );
    expect(
      uniqueDashAudioLanguage([
        english,
        BetterPlayerAsmsAudioTrack(id: 1),
      ], BetterPlayerAsmsAudioTrack(id: 1, language: 'und')),
      isNull,
    );
  });

  testWidgets('multiple audio tracks can be selected and retain selection', (
    tester,
  ) async {
    final tracks = [
      BetterPlayerAsmsAudioTrack(
        id: 0,
        label: 'en',
        language: 'en',
        isDefault: true,
      ),
      BetterPlayerAsmsAudioTrack(id: 1, label: 'ja', language: 'ja'),
    ];
    BetterPlayerAsmsAudioTrack? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PlayerAudioChoices(
              tracks: tracks,
              selected: selected,
              onSelected: (track) => setState(() => selected = track),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Subtitles'), findsOneWidget);
    expect(
      tester
          .widget<PlayerChoiceCard>(
            find.byKey(const ValueKey('player_audio_track_0')),
          )
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('player_audio_track_1')));
    await tester.pumpAndSettle();
    expect(selected?.id, 1);
    expect(selected?.language, 'ja');
    expect(
      tester
          .widget<PlayerChoiceCard>(
            find.byKey(const ValueKey('player_audio_track_1')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<PlayerChoiceCard>(
            find.byKey(const ValueKey('player_audio_track_0')),
          )
          .selected,
      isFalse,
    );
  });

  testWidgets('one audio track does not add an empty section', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerAudioChoices(
            tracks: [BetterPlayerAsmsAudioTrack(id: 0)],
            selected: null,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(PlayerChoiceCard), findsNothing);
    expect(find.text('Audio'), findsNothing);
  });
}
