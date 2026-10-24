import 'package:flutter/material.dart';

import '../../ui/content.dart';
import '../../ui/tokens.dart';
import '../../ui/components/section_card.dart';
import 'connection_view_model.dart';

class ConnectionView extends StatefulWidget {
  const ConnectionView({
    super.key,
    required this.viewModel,
    required this.onAuthenticated,
    this.incomingLink,
  });
  final ConnectionViewModel viewModel;
  final VoidCallback onAuthenticated;
  final String? incomingLink;
  @override
  State<ConnectionView> createState() => _ConnectionViewState();
}

class _ConnectionViewState extends State<ConnectionView> {
  final _origin = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _originEdited = false;
  void _syncRestoredOrigin() {
    if (!_originEdited && widget.incomingLink == null) {
      final restored = widget.viewModel.snapshot.connection?.origin;
      if (restored != null && _origin.text != restored.toString()) {
        _origin.text = restored.toString();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_syncRestoredOrigin);
    _origin.text =
        widget.incomingLink ??
        widget.viewModel.snapshot.connection?.origin.toString() ??
        '';
    if (widget.incomingLink != null) {
      widget.viewModel.preview(widget.incomingLink!, notify: false);
    }
  }

  @override
  void didUpdateWidget(ConnectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_syncRestoredOrigin);
      widget.viewModel.addListener(_syncRestoredOrigin);
    }
    if (oldWidget.incomingLink != widget.incomingLink &&
        widget.incomingLink != null) {
      _password.clear();
      _origin.text = widget.incomingLink!;
      widget.viewModel.preview(widget.incomingLink!, notify: false);
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_syncRestoredOrigin);
    _origin.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final password = _password.text;
    _password.clear();
    await widget.viewModel.login(password);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (widget.viewModel.snapshot.authenticated) widget.onAuthenticated();
  }

  Future<void> _reconnect() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await widget.viewModel.reconnect();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (widget.viewModel.snapshot.authenticated) widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      final busy = vm.snapshot.busy || _submitting;
      return Scaffold(
        appBar: AppBar(title: const Text(Content.connectTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.md),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: Spacing.lg),
                  ExcludeSemantics(
                    child: Text(
                      Content.wordmark,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  Text(
                    Content.originHelp,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  TextField(
                    controller: _origin,
                    enabled: !busy,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: Content.originLabel,
                      hintText: Content.originHint,
                    ),
                    onChanged: (_) {
                      _originEdited = true;
                      _password.clear();
                      vm.edit();
                    },
                    onSubmitted: (_) => vm.preview(_origin.text),
                  ),
                  if (widget.incomingLink == null &&
                      vm.matchesSavedOrigin(_origin.text))
                    OutlinedButton(
                      onPressed: busy ? null : _reconnect,
                      child: const Text(Content.retry),
                    ),
                  const SizedBox(height: Spacing.md),
                  OutlinedButton(
                    onPressed: busy ? null : () => vm.preview(_origin.text),
                    child: const Text(Content.reviewOrigin),
                  ),
                  if (vm.candidate != null && !vm.confirmed) ...[
                    const SizedBox(height: Spacing.md),
                    SectionCard(
                      title: Content.confirmationHelp,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(vm.candidate.toString()),
                          const SizedBox(height: Spacing.md),
                          FilledButton(
                            onPressed: busy ? null : vm.confirm,
                            child: const Text(Content.confirmOrigin),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (vm.confirmed) ...[
                    const SizedBox(height: Spacing.lg),
                    Text(vm.candidate.toString()),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      controller: _password,
                      enabled: !busy,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: Content.passwordLabel,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: Spacing.md),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: Text(busy ? Content.working : Content.signIn),
                    ),
                  ],
                  if (vm.error != null) ...[
                    const SizedBox(height: Spacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(Content.error(vm.error!.code)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
