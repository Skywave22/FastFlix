/// Bundled logo designs supplied for FastFlix. The play mark is the default.
enum FastFlixLogo {
  play(
    'play',
    'assets/images/fastflix/mark_play.png',
    'assets/images/fastflix/logo_play.png',
  ),
  wing(
    'wing',
    'assets/images/fastflix/mark_wing.png',
    'assets/images/fastflix/logo_wing.png',
  ),
  f(
    'f',
    'assets/images/fastflix/mark_f.png',
    'assets/images/fastflix/logo_f.png',
  );

  const FastFlixLogo(this.id, this.markAsset, this.logoAsset);

  final String id;
  final String markAsset;
  final String logoAsset;

  static FastFlixLogo fromId(String? id) => FastFlixLogo.values.firstWhere(
    (logo) => logo.id == id,
    orElse: () => FastFlixLogo.play,
  );
}
