import 'package:flutter/material.dart';

import '../../models/notifications.dart';
import '../content.dart';
import '../tokens.dart';

/// Réglages des notifications du téléphone. Le plugin Hermes du profil décide
/// d'envoyer ; l'app partage son jeton à chaque envoi, sans rien à configurer.
class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key, required this.device});
  final NotificationClient device;
  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour des réglages Android : la permission a pu changer.
    if (state == AppLifecycleState.resumed && !_busy) _refresh();
  }

  Future<void> _refresh({bool requestPermission = false}) async {
    if (requestPermission) setState(() => _busy = true);
    try {
      await widget.device.token(requestPermission: requestPermission);
    } catch (_) {
      /* État explicite du client. */
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Spacing.md),
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
          const SizedBox(height: Spacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              Content.notificationDevice(widget.device.availability.name),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: Spacing.sm),
          FilledButton(
            onPressed: _busy ? null : () => _refresh(requestPermission: true),
            child: const Text(Content.notificationEnable),
          ),
        ],
      ),
    ),
  );
}
