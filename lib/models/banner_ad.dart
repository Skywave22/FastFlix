// Legacy bootstrap banner metadata. Retained only for decoding cached settings;
// the application does not render or request advertisements.
class BannerDisplayConfig {
  const BannerDisplayConfig({
    required this.key,
    this.enabled = true,
    this.placements = const [],
    this.shape,
    this.width,
    this.height,
    this.aspectRatio,
  });

  final String key;
  final bool enabled;
  final List<String> placements;
  final String? shape;
  final double? width;
  final double? height;
  final double? aspectRatio;

  factory BannerDisplayConfig.fromJson(String key, Map<String, dynamic> json) {
    final rawPlacements = json['placements'];
    return BannerDisplayConfig(
      key: key,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      placements: rawPlacements is List
          ? rawPlacements.whereType<String>().toList(growable: false)
          : const [],
      shape: json['shape']?.toString(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
    );
  }

  bool appliesTo(String placement) =>
      placements.isEmpty || placements.contains(placement);
}
