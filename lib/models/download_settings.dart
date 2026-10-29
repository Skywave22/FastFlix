/// Android download limits, shared by all offline jobs and saved natively.
class DownloadSettings {
  const DownloadSettings({
    this.segments = 8,
    this.parallelDownloads = 2,
    this.retryCount = 6,
    this.unmeteredOnly = false,
  });

  /// Total simultaneous HLS/DASH segment requests, shared across downloads.
  final int segments;
  final int parallelDownloads;
  final int retryCount;
  final bool unmeteredOnly;

  factory DownloadSettings.fromMap(Map<Object?, Object?> map) {
    int bounded(String key, int fallback, int min, int max) {
      final value = map[key];
      return (value is num ? value.toInt() : fallback).clamp(min, max);
    }

    return DownloadSettings(
      segments: bounded('segments', 8, 1, 16),
      parallelDownloads: bounded('parallelDownloads', 2, 1, 4),
      retryCount: bounded('retryCount', 6, 0, 10),
      unmeteredOnly: map['unmeteredOnly'] == true,
    );
  }

  DownloadSettings copyWith({
    int? segments,
    int? parallelDownloads,
    int? retryCount,
    bool? unmeteredOnly,
  }) =>
      DownloadSettings(
        segments: (segments ?? this.segments).clamp(1, 16),
        parallelDownloads:
            (parallelDownloads ?? this.parallelDownloads).clamp(1, 4),
        retryCount: (retryCount ?? this.retryCount).clamp(0, 10),
        unmeteredOnly: unmeteredOnly ?? this.unmeteredOnly,
      );

  Map<String, Object> toMap() => {
        'segments': segments.clamp(1, 16),
        'parallelDownloads': parallelDownloads.clamp(1, 4),
        'retryCount': retryCount.clamp(0, 10),
        'unmeteredOnly': unmeteredOnly,
      };
}
