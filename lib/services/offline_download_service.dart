import 'dart:async';

import 'package:flutter/services.dart';

import '../models/offline_download.dart';
import '../models/download_settings.dart';
import '../models/download_location.dart';

abstract interface class OfflineDownloadGateway {
  Stream<List<OfflineDownload>> get downloadEvents;
  Future<List<OfflineDownload>> getDownloads();
  Future<void> enqueue(OfflineDownloadRequest request);
  Future<void> pause(String id);
  Future<void> resume(String id);
  Future<void> retry(String id);
  Future<void> retryPublicCopy(String id);
  Future<void> remove(String id);
  Future<OfflineExportProgress> getExportProgress(String id);
  Future<void> openExternal(String id);
  Future<bool> saveCopy(String id);
}

class OfflineExportProgress {
  const OfflineExportProgress({required this.state, this.progress});

  final String state;
  final int? progress;

  bool get isAvailable => progress != null;

  factory OfflineExportProgress.fromMap(Map<Object?, Object?> map) {
    final rawProgress = map['progress'];
    final progress =
        rawProgress is num ? rawProgress.toInt().clamp(0, 100).toInt() : null;
    return OfflineExportProgress(
      state: map['state'] as String? ?? 'starting',
      progress: progress,
    );
  }
}

/// Whether a failed [OfflineDownloadGateway.enqueue] means the title is
/// already saved, which is not an error from the user's point of view.
bool isAlreadyDownloaded(Object error) =>
    error is PlatformException && error.code == 'ALREADY_DOWNLOADED';

/// A user-facing message for a failed [OfflineDownloadGateway.enqueue] of
/// [title].
String offlineEnqueueErrorMessage(Object error, {required String title}) {
  if (isAlreadyDownloaded(error)) {
    return '$title is already downloaded. Watch it in Downloads.';
  }
  if (error is PlatformException && error.code == 'DOWNLOAD_AUDIO_CONFLICT') {
    return 'Remove the existing download in Downloads, then choose the new audio language.';
  }
  if (error is PlatformException && error.code == 'DOWNLOAD_SOURCE_CONFLICT') {
    return 'This title already has a download with a different source or quality. '
        'Manage it in Downloads.';
  }
  if (error is PlatformException && error.code == 'PREPARE_FAILED') {
    return 'Could not reach this stream to download it. '
        'Try another quality or provider.';
  }
  return 'Could not start the download. Please try again.';
}

class OfflineDownloadService implements OfflineDownloadGateway {
  OfflineDownloadService._();

  static final OfflineDownloadService instance = OfflineDownloadService._();

  static const MethodChannel _methods =
      MethodChannel('dev.beamlak.flixquest/stream_downloads');
  static const EventChannel _events =
      EventChannel('dev.beamlak.flixquest/stream_download_events');

  Stream<List<OfflineDownload>>? _downloadEvents;

  @override
  Stream<List<OfflineDownload>> get downloadEvents =>
      _downloadEvents ??= _events
          .receiveBroadcastStream()
          .map(_decodeDownloads)
          .asBroadcastStream();

  @override
  Future<List<OfflineDownload>> getDownloads() async {
    final raw = await _methods.invokeListMethod<Object?>('getDownloads');
    return _decodeDownloads(raw ?? const []);
  }

  @override
  Future<void> enqueue(OfflineDownloadRequest request) {
    return _methods.invokeMethod<void>('enqueue', request.toMap());
  }

  /// These settings are stored and applied by the Android download service,
  /// including while the app is in the background.
  Future<DownloadSettings> getDownloadSettings() async {
    final raw = await _methods.invokeMapMethod<Object?, Object?>('getDownloadSettings');
    return DownloadSettings.fromMap(raw ?? const {});
  }

  Future<DownloadSettings> setDownloadSettings(DownloadSettings settings) async {
    final raw = await _methods.invokeMapMethod<Object?, Object?>(
      'setDownloadSettings', settings.toMap(),
    );
    return DownloadSettings.fromMap(raw ?? settings.toMap());
  }

  Future<DownloadLocation> getDownloadLocation() async {
    final raw = await _methods.invokeMapMethod<Object?, Object?>(
      'getDownloadLocation',
    );
    return DownloadLocation.fromMap(raw ?? const {});
  }

  /// Null means the user dismissed the Android folder picker.
  Future<DownloadLocation?> chooseDownloadLocation() async {
    final raw = await _methods.invokeMapMethod<Object?, Object?>(
      'chooseDownloadLocation',
    );
    return raw == null ? null : DownloadLocation.fromMap(raw);
  }

  Future<DownloadLocation> resetDownloadLocation() async {
    final raw = await _methods.invokeMapMethod<Object?, Object?>(
      'resetDownloadLocation',
    );
    return DownloadLocation.fromMap(raw ?? const {});
  }

  Future<List<OfflineAudioTrack>> getAudioTracks({
    required String url,
    required String format,
    required Map<String, String> headers,
    int? maxVideoHeight,
  }) async {
    final raw = await _methods.invokeListMethod<Object?>('getAudioTracks', {
      'url': url,
      'format': format,
      'headers': headers,
      'maxVideoHeight': maxVideoHeight,
    });
    return (raw ?? const [])
        .whereType<Map>()
        .map((item) => OfflineAudioTrack.fromMap(item.cast<Object?, Object?>()))
        .toList(growable: false);
  }

  @override
  Future<void> pause(String id) =>
      _methods.invokeMethod<void>('pause', {'id': id});

  @override
  Future<void> resume(String id) =>
      _methods.invokeMethod<void>('resume', {'id': id});

  @override
  Future<void> retry(String id) =>
      _methods.invokeMethod<void>('retry', {'id': id});

  @override
  Future<void> retryPublicCopy(String id) =>
      _methods.invokeMethod<void>('retryPublicCopy', {'id': id});

  @override
  Future<void> remove(String id) =>
      _methods.invokeMethod<void>('remove', {'id': id});

  @override
  Future<OfflineExportProgress> getExportProgress(String id) async {
    final raw = await _methods.invokeMapMethod<Object?, Object?>(
      'getExportProgress',
      {'id': id},
    );
    return OfflineExportProgress.fromMap(raw ?? const {});
  }

  @override
  Future<void> openExternal(String id) =>
      _methods.invokeMethod<void>('openExternal', {'id': id});

  @override
  Future<bool> saveCopy(String id) async =>
      await _methods.invokeMethod<bool>('saveCopy', {'id': id}) ?? false;

  List<OfflineDownload> _decodeDownloads(Object? event) {
    if (event is! List) return const [];
    return event
        .whereType<Map>()
        .map((item) => OfflineDownload.fromMap(item.cast<Object?, Object?>()))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }
}
