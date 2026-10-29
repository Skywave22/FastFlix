import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/download_settings.dart';
import '../../services/offline_download_service.dart';

/// Advanced limits apply to the whole Android download queue, including jobs
/// already running. They are persisted by the native service.
class DownloadSettingsSheet extends StatefulWidget {
  const DownloadSettingsSheet({
    super.key,
    this.load,
    this.save,
  });

  final Future<DownloadSettings> Function()? load;
  final Future<DownloadSettings> Function(DownloadSettings)? save;

  @override
  State<DownloadSettingsSheet> createState() => _DownloadSettingsSheetState();
}

class _DownloadSettingsSheetState extends State<DownloadSettingsSheet> {
  DownloadSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final settings = await (widget.load ??
          OfflineDownloadService.instance.getDownloadSettings)();
      if (mounted) setState(() => _settings = settings);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null || _saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await (widget.save ??
          OfflineDownloadService.instance.setDownloadSettings)(settings);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _slider({
    required String title,
    required String description,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    required Key key,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child:
                    Text(title, style: Theme.of(context).textTheme.titleSmall)),
            Text('$value', style: Theme.of(context).textTheme.titleSmall),
          ]),
          const SizedBox(height: 4),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          Slider(
            key: key,
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value',
            onChanged: _saving ? null : (value) => onChanged(value.round()),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('download_settings'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(tr('download_settings_description'),
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (settings == null) ...[
                Text(tr('download_settings_error')),
                TextButton(onPressed: _load, child: Text(tr('retry'))),
              ] else ...[
                _slider(
                  key: const Key('download_segments_slider'),
                  title: tr('download_segments'),
                  description: tr('download_segments_description'),
                  value: settings.segments,
                  min: 1,
                  max: 16,
                  onChanged: (value) => setState(
                      () => _settings = settings.copyWith(segments: value)),
                ),
                _slider(
                  key: const Key('download_parallel_slider'),
                  title: tr('download_parallel'),
                  description: tr('download_parallel_description'),
                  value: settings.parallelDownloads,
                  min: 1,
                  max: 4,
                  onChanged: (value) => setState(() =>
                      _settings = settings.copyWith(parallelDownloads: value)),
                ),
                _slider(
                  key: const Key('download_retries_slider'),
                  title: tr('download_retries'),
                  description: tr('download_retries_description'),
                  value: settings.retryCount,
                  min: 0,
                  max: 10,
                  onChanged: (value) => setState(
                      () => _settings = settings.copyWith(retryCount: value)),
                ),
                SwitchListTile.adaptive(
                  key: const Key('download_unmetered_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('download_unmetered')),
                  subtitle: Text(tr('download_unmetered_description')),
                  value: settings.unmeteredOnly,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                            () => _settings =
                                settings.copyWith(unmeteredOnly: value),
                          ),
                ),
                if (_failed) ...[
                  const SizedBox(height: 8),
                  Text(tr('download_settings_error'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('save_download_settings'),
                  onPressed: _saving ? null : _save,
                  child: Text(tr('save')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
