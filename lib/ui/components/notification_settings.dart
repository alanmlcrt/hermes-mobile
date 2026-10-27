import 'package:flutter/material.dart';

import '../../models/notifications.dart';
import '../../models/connection.dart';
import '../content.dart';
import '../tokens.dart';

class NotificationSettings extends StatefulWidget {
  const NotificationSettings({
    super.key,
    required this.repository,
    required this.connection,
  });
  final NotificationGateway repository;
  final ConnectionKey connection;
  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings>
    with WidgetsBindingObserver {
  final _origin = TextEditingController();
  final _bearer = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = true;
  bool _enabled = false;
  String? _error;
  String _health = 'unconfigured';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await widget.repository.settings(widget.connection);
      if (!mounted) return;
      _origin.text = settings?.origin.toString() ?? '';
      _enabled = settings?.enabled ?? false;
      _health = settings == null ? 'unconfigured' : 'unchecked';
    } catch (_) {
      _error = Content.notificationConfigError;
    }
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (_) {
      _error = Content.notificationConfigError;
    }
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    try {
      await widget.repository.device.token();
    } catch (_) {
      /* État explicite du client. */
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _origin.dispose();
    _bearer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                Content.notifications,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            const Text(Content.notificationPrerequisites),
            const Text(Content.notificationRevocationHint),
            const SizedBox(height: Spacing.sm),
            Text(
              Content.notificationDevice(
                widget.repository.device.availability.name,
              ),
            ),
            Text(Content.observerHealth(_health)),
            Text(
              _enabled
                  ? Content.notificationEnabled
                  : Content.notificationDisabled,
            ),
            const SizedBox(height: Spacing.sm),
            TextFormField(
              controller: _origin,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: Content.observerOrigin,
              ),
              validator: (value) {
                final uri = Uri.tryParse(value ?? '');
                return uri?.scheme == 'https' && uri!.host.isNotEmpty
                    ? null
                    : Content.notificationConfigError;
              },
            ),
            const SizedBox(height: Spacing.sm),
            TextFormField(
              controller: _bearer,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: Content.observerBearer,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? Content.notificationConfigError
                  : null,
            ),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: Spacing.sm),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_form.currentState!.validate()) {
                        _run(() async {
                          await widget.repository.configure(
                            widget.connection,
                            Uri.parse(_origin.text.trim()),
                            _bearer.text,
                          );
                          _bearer.clear();
                          _enabled = false;
                          _health = 'unchecked';
                        });
                      }
                    },
              child: const Text(Content.notificationSave),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      if (_enabled) {
                        await widget.repository.disable(widget.connection);
                        _enabled = false;
                      } else {
                        _enabled = await widget.repository.enable(
                          widget.connection,
                        );
                      }
                    }),
              child: Text(
                _enabled
                    ? Content.notificationDisable
                    : Content.notificationEnable,
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      _health = await widget.repository.health(
                        widget.connection,
                      );
                    }),
              child: const Text(Content.notificationHealth),
            ),
          ],
        ),
      ),
    ),
  );
}
