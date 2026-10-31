import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/intervention_repository.dart';
import 'package:hermes_mobile/features/profiles/approval_mode_section.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:hermes_mobile/features/profiles/profile_settings_view.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection_gateway.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/content.dart';

import 'support/connection_fakes.dart';

/// Mode d'autorisation (story 6.3) : lu et écrit sur Hermes profil par
/// profil, valeur affichée = valeur relue, aucun mode écrit d'office.
void main() {
  group('HermesApprovalModes', () {
    late Harness h;
    final modes = <String, String>{'alpha': 'smart', 'beta': 'smart'};
    late List<(String, Map<String, dynamic>)> calls;
    Object? Function(String, Map<String, dynamic>)? override;

    setUp(() async {
      h = Harness();
      await h.connect();
      calls = [];
      override = null;
      modes
        ..['alpha'] = 'smart'
        ..['beta'] = 'smart';
      h.transport.rpc = (method, params) {
        if (!method.startsWith('config.')) return null;
        calls.add((method, params));
        final scripted = override?.call(method, params);
        if (scripted != null) return scripted;
        final profile = params['profile'] as String;
        if (method == 'config.set') {
          modes[profile] = params['value'] as String;
          return {'ok': true};
        }
        return {'value': modes[profile]};
      };
    });
    tearDown(() => h.repository.dispose());

    test('lecture : config.get approvals.mode avec profile', () async {
      final repo = HermesApprovalModes(h.repository);
      expect(await repo.read(const ProfileKey('alpha')), 'smart');
      expect(calls.single.$1, 'config.get');
      expect(calls.single.$2, {'key': 'approvals.mode', 'profile': 'alpha'});
    });

    test(
      'deux profils : seul config.set du profil changé, puis relecture',
      () async {
        final repo = HermesApprovalModes(h.repository);
        final shown = await repo.write(const ProfileKey('alpha'), 'manual');
        expect(shown, 'manual');
        expect(calls.map((c) => c.$1), ['config.set', 'config.get']);
        expect(calls.first.$2, {
          'key': 'approvals.mode',
          'value': 'manual',
          'profile': 'alpha',
        });
        expect(calls.every((c) => c.$2['profile'] == 'alpha'), isTrue);
        expect(modes['beta'], 'smart');
      },
    );

    test('valeur affichée = valeur relue, pas celle demandée', () async {
      override = (method, params) =>
          method == 'config.get' ? {'value': 'smart'} : null;
      final repo = HermesApprovalModes(h.repository);
      expect(await repo.write(const ProfileKey('alpha'), 'manual'), 'smart');
    });

    test('lecture illisible : erreur, jamais de valeur supposée', () async {
      override = (method, params) => {'value': 42};
      final repo = HermesApprovalModes(h.repository);
      await expectLater(
        repo.read(const ProfileKey('alpha')),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            'approval_mode.unreadable',
          ),
        ),
      );
    });

    test(
      'refus de config.set : erreur, aucune relecture ni autre écriture',
      () async {
        override = (method, params) =>
            method == 'config.set' ? const RpcFail(-32000) : null;
        final repo = HermesApprovalModes(h.repository);
        await expectLater(
          repo.write(const ProfileKey('alpha'), 'manual'),
          throwsA(isA<RpcError>()),
        );
        expect(calls.map((c) => c.$1), ['config.set']);
        expect(modes['alpha'], 'smart');
      },
    );

    test('mode inconnu jamais écrit', () async {
      final repo = HermesApprovalModes(h.repository);
      await expectLater(
        repo.write(const ProfileKey('alpha'), 'always'),
        throwsA(isA<AppError>()),
      );
      expect(calls, isEmpty);
    });
  });

  group('ApprovalModeSection', () {
    Future<_Modes> pump(WidgetTester tester, _Modes modes) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ApprovalModeSection(
                modes: modes,
                profile: const ProfileKey('alpha'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return modes;
    }

    Finder tile(String mode) =>
        find.widgetWithText(ListTile, Content.approvalModeName(mode));
    bool selected(WidgetTester tester, String mode) =>
        tester.widget<ListTile>(tile(mode)).selected;

    testWidgets('mode lu : « Hermes juge » sélectionné, aucune écriture', (
      tester,
    ) async {
      final modes = await pump(tester, _Modes('smart'));
      expect(selected(tester, 'smart'), isTrue);
      expect(selected(tester, 'manual'), isFalse);
      expect(modes.writes, isEmpty);
      // Les options restent courtes ; l'avertissement vient au choix de yolo.
      expect(find.text(Content.approvalModeOffWarning), findsNothing);
      expect(find.text(Content.approvalModesHint), findsNothing);
      expect(find.text('Auto'), findsOne);
      expect(find.text('yolo'), findsOne);
      expect(tester.getSize(tile('manual')).height, greaterThanOrEqualTo(48));
    });

    testWidgets('mode changé : valeur relue affichée', (tester) async {
      final modes = await pump(tester, _Modes('smart'));
      await tester.tap(tile('manual'));
      await tester.pumpAndSettle();
      expect(modes.writes, ['manual']);
      expect(selected(tester, 'manual'), isTrue);
      expect(selected(tester, 'smart'), isFalse);
    });

    testWidgets('refus de config.set : relu, ancienne valeur et « inchangé »', (
      tester,
    ) async {
      final modes = await pump(
        tester,
        _Modes('smart', writeError: const RpcError(-32000)),
      );
      final reads = modes.reads;
      await tester.tap(tile('manual'));
      await tester.pumpAndSettle();
      expect(modes.writes, ['manual']);
      expect(modes.reads, reads + 1);
      expect(selected(tester, 'smart'), isTrue);
      expect(selected(tester, 'manual'), isFalse);
      expect(find.text(Content.approvalModeRefused), findsOne);
    });

    testWidgets('écriture faite mais relecture perdue : mode relu affiché, '
        '« non confirmé »', (tester) async {
      final modes = await pump(
        tester,
        _Modes(
          'smart',
          writeError: const AppError('rpc.uncertain'),
          applyBeforeError: true,
        ),
      );
      await tester.tap(tile('manual'));
      await tester.pumpAndSettle();
      expect(modes.writes, ['manual']);
      // Hermes a changé le mode : c'est sa valeur qui s'affiche.
      expect(selected(tester, 'manual'), isTrue);
      expect(selected(tester, 'smart'), isFalse);
      expect(find.text(Content.approvalModeUnconfirmed), findsOne);
      expect(find.text(Content.approvalModeRefused), findsNothing);
    });

    testWidgets('échec puis relecture impossible : « Mode illisible » et '
        '« non confirmé »', (tester) async {
      final modes = await pump(
        tester,
        _Modes('smart', writeError: const AppError('rpc.uncertain')),
      );
      modes.failReads = true;
      await tester.tap(tile('manual'));
      await tester.pumpAndSettle();
      expect(find.text(Content.approvalModeUnreadable), findsOne);
      expect(find.text(Content.approvalModeUnconfirmed), findsOne);
      for (final mode in ApprovalMode.values) {
        expect(selected(tester, mode), isFalse);
      }
    });

    testWidgets('option courante annoncée cochée au lecteur d’écran', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, _Modes('smart'));
      expect(
        tester.getSemantics(tile('smart')),
        isSemantics(isChecked: true, isSelected: true),
      );
      expect(
        tester.getSemantics(tile('manual')),
        isSemantics(isChecked: false),
      );
      semantics.dispose();
    });

    testWidgets('réglages du profil : section « Autorisations » affichée, '
        'lue pour ce profil', (tester) async {
      final h = Harness();
      final modes = _Modes('manual');
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSettingsView(
            gateway: h.repository,
            accents: ProfileAccents(h.repository),
            profile: const ProfileKey('beta'),
            onChangeServer: () {},
            onAllProfiles: () {},
            approvalModes: modes,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ApprovalModeSection), findsOne);
      expect(find.text(Content.approvalModes), findsOne);
      expect(modes.profiles, [const ProfileKey('beta')]);
      expect(selected(tester, 'manual'), isTrue);
    });

    testWidgets('lecture impossible : « Mode illisible », changement '
        'désactivé', (tester) async {
      final modes = await pump(tester, _Modes(null));
      expect(find.text(Content.approvalModeUnreadable), findsOne);
      for (final mode in ApprovalMode.values) {
        expect(tester.widget<ListTile>(tile(mode)).enabled, isFalse);
        expect(selected(tester, mode), isFalse);
      }
      await tester.tap(tile('manual'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(modes.writes, isEmpty);
    });

    testWidgets('passage en off : dialogue ; annuler ne change rien, '
        'confirmer écrit', (tester) async {
      final modes = await pump(tester, _Modes('smart'));
      await tester.tap(tile('off'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOne);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(Content.approvalModeOffWarning),
        ),
        findsOne,
      );
      await tester.tap(find.text(Content.approvalModeCancel));
      await tester.pumpAndSettle();
      expect(modes.writes, isEmpty);
      expect(selected(tester, 'smart'), isTrue);
      await tester.tap(tile('off'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Content.approvalModeOffConfirm));
      await tester.pumpAndSettle();
      expect(modes.writes, ['off']);
      expect(selected(tester, 'off'), isTrue);
    });
  });
}

/// Modes fictifs : [mode] `null` ou [failReads] = lecture impossible ;
/// [applyBeforeError] : l'écriture a eu lieu avant l'erreur.
class _Modes implements ApprovalModes {
  _Modes(this.mode, {this.writeError, this.applyBeforeError = false});
  String? mode;
  final Object? writeError;
  final bool applyBeforeError;
  bool failReads = false;
  final writes = <String>[];
  final profiles = <ProfileKey>[];
  int reads = 0;
  @override
  Future<String> read(ProfileKey profile) async {
    reads++;
    profiles.add(profile);
    if (failReads) throw const AppError('approval_mode.unreadable');
    return mode ?? (throw const AppError('approval_mode.unreadable'));
  }

  @override
  Future<String> write(ProfileKey profile, String value) async {
    writes.add(value);
    if (applyBeforeError) mode = value;
    if (writeError != null) throw writeError!;
    mode = value;
    return read(profile);
  }
}
