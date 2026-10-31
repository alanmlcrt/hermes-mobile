import 'package:flutter/material.dart';

import '../../models/connection.dart';
import '../../models/connection_gateway.dart';
import '../../models/notifications.dart';
import '../../models/profile.dart';
import '../content.dart';
import '../tokens.dart';

/// Interrupteur de notifications d'un profil. Grisé lorsque le profil n'a pas
/// le plugin `hermes-mobile-notify` ou que les notifications sont indisponibles
/// sur l'appareil.
class NotificationSettings extends StatefulWidget {
  const NotificationSettings({
    super.key,
    required this.device,
    this.gateway,
    this.profile,
    this.hasPlugin = true,
  });
  final NotificationClient device;
  final ConnectionGateway? gateway;
  final ProfileKey? profile;
  final bool hasPlugin;

  /// Profils pour lesquels l'utilisateur a coupé le toggle sur cet appareil.
  static final Set<ProfileKey> disabledProfiles = <ProfileKey>{};

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings>
    with WidgetsBindingObserver {
  bool _busy = false;
  late bool _pluginPresent = widget.hasPlugin;
  bool _localEnabled = true;

  ProfileKey get _profileKey => widget.profile ?? const ProfileKey('default');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _localEnabled = !NotificationSettings.disabledProfiles.contains(_profileKey);
    _checkPlugin();
  }

  @override
  void didUpdateWidget(NotificationSettings old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile || old.hasPlugin != widget.hasPlugin) {
      _pluginPresent = widget.hasPlugin;
      _localEnabled = !NotificationSettings.disabledProfiles.contains(
        _profileKey,
      );
      _checkPlugin();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour des réglages Android : la permission a pu changer.
    if (state == AppLifecycleState.resumed && !_busy) _refresh();
  }

  Future<void> _checkPlugin() async {
    final gateway = widget.gateway;
    final profile = widget.profile;
    if (!widget.hasPlugin || gateway == null || profile == null) return;
    if (gateway.snapshot.link != LinkState.connected) return;
    try {
      final res = await gateway.call('config.get', {
        'key': 'plugins.enabled',
        'profile': profile.value,
      });
      if (!mounted || widget.profile != profile) return;
      if (res.containsKey('value')) {
        final v = res['value'];
        final enabled =
            (v is List && v.contains('hermes-mobile-notify')) ||
            (v is String && v.contains('hermes-mobile-notify'));
        setState(() => _pluginPresent = enabled);
      }
    } on RpcError catch (error) {
      if (!mounted || widget.profile != profile) return;
      if (error.code == 4018) setState(() => _pluginPresent = false);
    } catch (_) {
      /* Sans réponse explicite de config.get, garde l'état courant. */
    }
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

  Future<void> _toggle(bool next) async {
    if (_busy || !_pluginPresent) return;
    if (!next) {
      NotificationSettings.disabledProfiles.add(_profileKey);
      setState(() => _localEnabled = false);
      return;
    }
    NotificationSettings.disabledProfiles.remove(_profileKey);
    setState(() => _localEnabled = true);
    await _refresh(requestPermission: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availability = widget.device.availability;
    final canInteract =
        _pluginPresent &&
        !_busy &&
        availability != NotificationAvailability.unavailable;
    final active =
        _pluginPresent &&
        _localEnabled &&
        availability == NotificationAvailability.ready;
    return Card(
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xxs,
        ),
        secondary: const Icon(Icons.notifications_outlined),
        title: const Text(Content.notifications),
        value: active,
        onChanged: canInteract ? _toggle : null,
      ),
    );
  }
}
