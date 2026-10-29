import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/app_palette.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../provider/app_dependency_provider.dart';
import '../../services/connection_diagnostics.dart';
import '../../tv/focus/tv_keymap.dart';

/// Optional public-client overrides for builds without a working bootstrap.
/// Empty fields restore the bundled or remotely supplied values.
class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({
    super.key,
    this.television = false,
    this.diagnostics,
  });

  final bool television;
  final ConnectionDiagnostics? diagnostics;

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _resultAnchor = GlobalKey();
  late final TextEditingController _tmdbKey;
  late final TextEditingController _scraperUrl;
  late final TextEditingController _tmdbProxy;
  final _saveFocus = FocusNode(debugLabel: 'Connection Save');
  bool _saving = false;
  bool _checking = false;
  int _checkGeneration = 0;
  TmdbConnectionStatus? _tmdbStatus;
  ProviderConnectionStatus? _providerStatus;
  String? _error;

  @override
  void initState() {
    super.initState();
    final dependencies = context.read<AppDependencyProvider>();
    _tmdbKey = TextEditingController(text: dependencies.clientTmdbKey);
    _scraperUrl = TextEditingController(text: dependencies.clientScraperUrl);
    _tmdbProxy = TextEditingController(text: dependencies.clientTmdbProxy);
  }

  @override
  void dispose() {
    _checkGeneration++;
    _tmdbKey.dispose();
    _scraperUrl.dispose();
    _tmdbProxy.dispose();
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
        tmdbProxy: _tmdbProxy.text,
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

  void _inputsChanged(String _) {
    if (!_checking && _tmdbStatus == null && _providerStatus == null) return;
    setState(() {
      _checkGeneration++;
      _checking = false;
      _tmdbStatus = null;
      _providerStatus = null;
    });
  }

  Future<void> _testConnections() async {
    if (_checking || !_form.currentState!.validate()) return;
    final dependencies = context.read<AppDependencyProvider>();
    final diagnostics = widget.diagnostics ?? ConnectionDiagnostics();
    final key = _tmdbKey.text.trim().isEmpty
        ? dependencies.fallbackClientTmdbKey
        : _tmdbKey.text.trim();
    final proxy = _tmdbProxy.text.trim().isEmpty
        ? dependencies.fallbackTmdbProxy
        : _tmdbProxy.text.trim();
    final urls = _scraperUrl.text.trim().isEmpty
        ? dependencies.fallbackScraperApiCandidates
        : <String>[_scraperUrl.text.trim()];
    final generation = ++_checkGeneration;
    setState(() {
      _checking = true;
      _tmdbStatus = null;
      _providerStatus = null;
      _error = null;
    });
    bool current() => mounted && generation == _checkGeneration;
    void revealResults() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final resultContext = _resultAnchor.currentContext;
        if (current() && resultContext != null) {
          Scrollable.ensureVisible(
            resultContext,
            duration: const Duration(milliseconds: 180),
            alignment: 0.8,
          );
        }
      });
    }

    Future<void> checkTmdb() async {
      final result = await diagnostics.checkTmdb(key: key, proxyUrl: proxy);
      if (current()) {
        setState(() => _tmdbStatus = result);
        revealResults();
      }
    }

    Future<void> checkProviders() async {
      final result = await diagnostics.checkProviders(urls);
      if (current()) {
        setState(() => _providerStatus = result);
        revealResults();
      }
    }

    await Future.wait([checkTmdb(), checkProviders()]);
    if (current()) setState(() => _checking = false);
  }

  String _tmdbMessage(TmdbConnectionStatus status) => tr(switch (status) {
    TmdbConnectionStatus.missingKey => 'connection_tmdb_missing',
    TmdbConnectionStatus.connectedDirect => 'connection_tmdb_connected',
    TmdbConnectionStatus.connectedProxy => 'connection_tmdb_proxy_connected',
    TmdbConnectionStatus.rejectedKey => 'connection_tmdb_rejected',
    TmdbConnectionStatus.blocked => 'connection_tmdb_blocked',
    TmdbConnectionStatus.unavailable => 'connection_tmdb_unavailable',
    TmdbConnectionStatus.rateLimited => 'connection_tmdb_rate_limited',
    TmdbConnectionStatus.unexpectedResponse => 'connection_tmdb_unexpected',
  });

  String _providerMessage(ProviderConnectionStatus status) => tr(
    switch (status) {
      ProviderConnectionStatus.notConfigured => 'connection_provider_missing',
      ProviderConnectionStatus.connected => 'connection_provider_connected',
      ProviderConnectionStatus.empty => 'connection_provider_empty',
      ProviderConnectionStatus.unavailable => 'connection_provider_unavailable',
    },
  );

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      onChanged: _inputsChanged,
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
                      textInputAction: TextInputAction.next,
                      onChanged: _inputsChanged,
                      validator: (value) =>
                          AppDependencyProvider.validClientScraperUrl(
                            value ?? '',
                          )
                          ? null
                          : tr('connection_invalid_url'),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const ValueKey<String>('connection-tmdb-proxy'),
                      controller: _tmdbProxy,
                      decoration: InputDecoration(
                        labelText: tr('connection_tmdb_proxy_label'),
                        hintText: tr('connection_use_default'),
                      ),
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      onChanged: _inputsChanged,
                      onFieldSubmitted: (_) => _save(),
                      validator: (value) =>
                          AppDependencyProvider.validClientTmdbProxy(
                            value ?? '',
                          )
                          ? null
                          : tr('connection_invalid_proxy'),
                    ),
                    const SizedBox(height: 12),
                    Text(tr('connection_proxy_warning')),
                    const SizedBox(height: 18),
                    Text(tr('connection_public_settings_warning')),
                    if (_tmdbStatus != null || _providerStatus != null)
                      Semantics(
                        key: _resultAnchor,
                        liveRegion: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (_tmdbStatus != null) ...<Widget>[
                              const SizedBox(height: 12),
                              Text(
                                _tmdbMessage(_tmdbStatus!),
                                key: const ValueKey<String>(
                                  'connection-tmdb-result',
                                ),
                              ),
                            ],
                            if (_providerStatus != null) ...<Widget>[
                              const SizedBox(height: 12),
                              Text(
                                _providerMessage(_providerStatus!),
                                key: const ValueKey<String>(
                                  'connection-provider-result',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton(
                    key: const ValueKey<String>('connection-test'),
                    onPressed: _checking ? null : _testConnections,
                    child: Text(
                      tr(_checking ? 'connection_checking' : 'connection_test'),
                    ),
                  ),
                  FilledButton(
                    key: const ValueKey<String>('connection-save'),
                    focusNode: _saveFocus,
                    autofocus: widget.television,
                    onPressed: _saving ? null : _save,
                    child: Text(tr('save')),
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
