import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../functions/language_names.dart';
import 'player_sheet_ui.dart';

/// Some HLS/DASH manifests omit language or label. The native player needs a
/// non-null name and index; preserve the manifest's index and supply a safe
/// label rather than silently treating the track as "default".
BetterPlayerAsmsAudioTrack selectableAudioTrack(
  BetterPlayerAsmsAudioTrack track,
  int index,
) {
  final label = track.label?.trim();
  final language = track.language?.trim();
  return BetterPlayerAsmsAudioTrack(
    id: track.id ?? index,
    label: label?.isNotEmpty == true
        ? label
        : language?.isNotEmpty == true
        ? language
        : 'Audio ${index + 1}',
    language: language?.isNotEmpty == true ? language : 'und',
    segmentAlignment: track.segmentAlignment,
    url: track.url,
    mimeType: track.mimeType,
    isDefault: track.isDefault,
  );
}

/// Better Player's DASH IDs enumerate manifest adaptation sets, but Android's
/// native selector enumerates every representation. When the language is
/// unique, a second, language-based selection avoids choosing a representation
/// from the wrong adaptation set. Ambiguous or missing languages keep the
/// player's normal index-based behavior.
String? uniqueDashAudioLanguage(
  List<BetterPlayerAsmsAudioTrack> tracks,
  BetterPlayerAsmsAudioTrack selected,
) {
  final language = selected.language?.trim();
  if (language == null || language.isEmpty || language.toLowerCase() == 'und') {
    return null;
  }
  // Treat aliases and regional variants as the same language. A manifest can
  // describe, for example, "en" and "eng" as separate audio choices even
  // though Media3 normalizes both to the same native language.
  String family(String? value) {
    final code = (value ?? '').trim().toLowerCase().replaceAll('_', '-');
    final base = code.split('-').first;
    for (final entry in appLanguages) {
      if (entry.code == base || entry.aliases.contains(base)) return entry.code;
    }
    return base;
  }

  final selectedFamily = family(language);
  final matches = tracks.where(
    (track) => family(track.language) == selectedFamily,
  );
  return matches.length == 1 ? language.replaceAll('_', '-') : null;
}

/// A section in the phone player's existing subtitle sheet, retaining its
/// timing, online search and upload actions.
class PlayerAudioChoices extends StatelessWidget {
  const PlayerAudioChoices({
    required this.tracks,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<BetterPlayerAsmsAudioTrack> tracks;
  final BetterPlayerAsmsAudioTrack? selected;
  final ValueChanged<BetterPlayerAsmsAudioTrack> onSelected;

  @override
  Widget build(BuildContext context) {
    if (tracks.length < 2) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Text(
            tr('player_audio'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (var index = 0; index < tracks.length; index++)
          Builder(
            builder: (context) {
              final original = tracks[index];
              final track = selectableAudioTrack(original, index);
              final isSelected = selected == null
                  ? original.isDefault
                  : identical(selected, original) ||
                        (selected!.id != null && selected!.id == track.id);
              return PlayerChoiceCard(
                key: ValueKey('player_audio_track_$index'),
                title: languageDisplayName(track.label ?? track.language ?? ''),
                selected: isSelected,
                onTap: () => onSelected(track),
              );
            },
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
          child: Text(
            tr('player_subtitles'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}
