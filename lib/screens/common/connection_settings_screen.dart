import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/app_palette.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../provider/app_dependency_provider.dart';
import '../../tv/focus/tv_keymap.dart';

/// Optional public-client overrides for builds without a working bootstrap.
/// Empty fields restore the bundled or remotely supplied values.
class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key, this.television = false});

  final bool television;

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _tmdbKey;
  late final TextEditingController _scraperUrl;
  final _saveFocus = FocusNode(debugLabel: 'Connection Save');
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final dependencies = context.read<AppDependencyProvider>();
    _tmdbKey = TextEditingController(text: dependencies.clientTmdbKey);
    _scraperUrl = TextEditingController(text: dependencies.clientScraperUrl);
  }

  @override
  void dispose() {
    _tmdbKey.dispose();
    _scraperUrl.dispose();
    _saveFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AppDependencyProvider>().saveClientConnection(
            tmdbKey: _tmdbKey.text,
            scraperUrl: _scraperUrl.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = tr('connection_save_failed');
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final title = tr('connection_settings');
    final PreferredSizeWidget appBar = widget.television
        ? AppBar(title: Text(title))
        : PageAppBar(title: title, contentWidth: 760);
    final screen = Scaffold(
      backgroundColor: palette.page,
      appBar: appBar,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  Text(tr('connection_settings_description')),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const ValueKey<String>('connection-tmdb-key'),
                    controller: _tmdbKey,
                    decoration: InputDecoration(
                      labelText: tr('connection_tmdb_key'),
                      hintText: tr('connection_use_default'),
                    ),
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        AppDependencyProvider.validClientTmdbKey(value ?? '')
                            ? null
                            : tr('connection_invalid_key'),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const ValueKey<String>('connection-scraper-url'),
                    controller: _scraperUrl,
                    decoration: InputDecoration(
                      labelText: tr('connection_provider_url'),
                      hintText: tr('connection_use_default'),
                    ),
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                    validator: (value) =>
                        AppDependencyProvider.validClientScraperUrl(value ?? '')
                            ? null
                            : tr('connection_invalid_url'),
                  ),
                  const SizedBox(height: 18),
                  Text(tr('connection_public_settings_warning')),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      key: const ValueKey<String>('connection-save'),
                      focusNode: _saveFocus,
                      autofocus: widget.television,
                      onPressed: _saving ? null : _save,
                      child: Text(tr('save')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!widget.television) return screen;
    return TvKeymap(
      onBack: () async {
        await Navigator.of(context).maybePop();
      },
      child: screen,
    );
  }
}
