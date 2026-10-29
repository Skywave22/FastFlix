import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xml/xml.dart';

import '../models/fastflix_logo.dart';
import '../provider/settings_provider.dart';

/// Kept for compatibility with existing remote-logo validation callers.
@visibleForTesting
bool isValidRemoteLogoSvg(String source) {
  if (source.isEmpty) return false;
  try {
    final document = XmlDocument.parse(source);
    return document.rootElement.name.local.toLowerCase() == 'svg';
  } catch (_) {
    return false;
  }
}

/// Shows the user's selected FastFlix artwork, rather than replacing it with
/// an upstream branding URL. Compact placements use the matching symbol.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fallbackAsset = 'assets/images/logo.png',
    this.fallbackColor,
  });

  final double? width;
  final double? height;
  final BoxFit fit;

  /// Existing compact callers pass the old mark asset; keep their layout.
  final String fallbackAsset;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final selected =
        context.watch<SettingsProvider?>()?.fastFlixLogo ?? FastFlixLogo.play;
    final compact = fallbackAsset.endsWith('fq_mark.svg');
    return Image.asset(
      compact ? selected.markAsset : selected.logoAsset,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: 'FastFlix',
    );
  }
}
