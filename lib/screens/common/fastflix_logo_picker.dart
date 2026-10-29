import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/fastflix_logo.dart';

/// Previews each supplied design before changing the app and launcher mark.
class FastFlixLogoPicker extends StatelessWidget {
  const FastFlixLogoPicker({super.key, required this.selected});

  final FastFlixLogo selected;

  @override
  Widget build(BuildContext context) {
    final labels = <FastFlixLogo, String>{
      FastFlixLogo.play: tr('logo_play'),
      FastFlixLogo.wing: tr('logo_wing'),
      FastFlixLogo.f: tr('logo_f'),
    };
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('choose_app_logo'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              tr('choose_app_logo_description'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final logo in FastFlixLogo.values)
                  Semantics(
                    button: true,
                    selected: logo == selected,
                    label: labels[logo],
                    child: InkWell(
                      key: ValueKey('logo-${logo.id}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(logo),
                      child: Container(
                        width: 104,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xff0a0a0d),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: logo == selected
                                ? scheme.primary
                                : Colors.white24,
                            width: logo == selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 70,
                              height: 60,
                              child: Image.asset(
                                logo.markAsset,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              labels[logo]!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
