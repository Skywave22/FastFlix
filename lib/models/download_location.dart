/// The destination for automatic playable copies of new downloads.
/// Media3's offline cache remains app-private on Android.
class DownloadLocation {
  const DownloadLocation({required this.isDefault, required this.label});

  final bool isDefault;
  final String label;

  factory DownloadLocation.fromMap(Map<Object?, Object?> map) =>
      DownloadLocation(
        isDefault: map['isDefault'] != false,
        label: map['label'] as String? ?? 'Downloads/FlixQuest',
      );
}
