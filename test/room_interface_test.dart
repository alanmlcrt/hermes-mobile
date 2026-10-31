import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:hermes_mobile/features/rooms/room_view.dart';
import 'package:hermes_mobile/features/rooms/room_view_model.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/ui/components/composer.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';
import 'package:hermes_mobile/ui/tokens.dart';

import 'support/room_harness.dart';

void main() {
  late RoomHarness r;
  Map<String, dynamic> legacyRoom() => {
    ...roomData(),
    'members': [
      {
        'member_id': 'finance',
        'profile': 'finance',
        'display_name': 'Finance',
        'handle': 'agent1',
      },
      {
        'member_id': 'recherche',
        'profile': 'recherche',
        'display_name': 'Recherche',
        'handle': 'agent2',
      },
    ],
  };
  setUp(() async {
    r = RoomHarness();
    await r.open();
    r.h.transport.rpc = (m, p) => m == 'groups.state'
        ? {'room': legacyRoom(), 'driver_status': r.driver}
        : r.rpc(m, p);
  });
  tearDown(() => r.close());

  test('8.4 anciens salons : nom humain affiché, destinataire exact et texte transmis persisté avant la trame', () async {
    final room = await r.rooms.find(r.key);
    final mentions = r.rooms.mentions(room);
    expect(
      mentions.map((m) => m.token),
      containsAll(['finance', 'recherche', 'all', 'hermes']),
    );
    expect(mentions.map((m) => m.label), containsAll(['Finance', 'Recherche']));
    expect(mentions.map((m) => m.token), isNot(contains('agent1')));
    expect(
      r.rooms.displayText(room, '@agent1 puis @agent2'),
      '@finance puis @recherche',
    );
    const protected = '`@agent1` https://example.com/@agent1 mail@agent1';
    expect(r.rooms.displayText(room, protected), protected);
    expect(
      HermesRpc.roomOutgoingText(room, '@Finance et @recherche, @all'),
      '@agent1 et @agent2, @all',
    );
    const text = '@finance regarde ce point';
    await r.outbox.saveRoomText(r.key, text);
    Future<List<Map<String, Object?>>>? persisted;
    r.h.transport.rpc = (m, p) {
      if (m == 'groups.state') {
        return {'room': legacyRoom(), 'driver_status': r.driver};
      }
      if (m != 'groups.send') return r.rpc(m, p);
      persisted = r.db.query('outbox_room_operations');
      expect((p['payload'] as Map)['text'], '@agent1 regarde ce point');
      final event = r.event(
        1,
        id: p['event_id'] as String,
        text: '@agent1 regarde ce point',
        kind: 'message.user',
      );
      return {
        'accepted': true,
        'client_event_id': p['event_id'],
        'event': event,
      };
    };
    await r.outbox.sendRoom(r.key, text);
    final row = (await persisted!).single;
    expect(row['text'], '@agent1 regarde ce point');
    expect(row['state'], 'sending');
    expect(await r.outbox.roomText(r.key), '');
    expect((await r.outbox.roomSends(r.key)).single.state, 'confirmed');
  });

  test(
    '8.3 nouveaux salons : handles nommés, identifiants et casse conservés',
    () {
      final payload = HermesRpc.roomCreate(
        'Équipe',
        {const ProfileKey('Finance'), const ProfileKey('recherche')},
        displayNames: {const ProfileKey('Finance'): 'Finance PEA'},
      );
      final members = payload['members'] as List;
      expect(members.first['member_id'], 'Finance');
      expect(members.first['profile'], 'Finance');
      expect(members.first['handle'], 'Finance');
      expect(members.first['display_name'], 'Finance PEA');
      expect(members.last['handle'], 'recherche');
      final primary = HermesRpc.roomCreate('Équipe', {
        const ProfileKey('default'),
        const ProfileKey('finance'),
      });
      expect((primary['members'] as List).first['handle'], 'hermes');
    },
  );

  Future<({RoomViewModel vm, ProfileAccents accents, GlobalKey boundary})>
  mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    double keyboard = 0,
  }) async {
    await tester.runAsync(() async {
      final config = File('.dart_tool/package_config.json');
      final packages =
          (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
      final flutter = packages.cast<Map>().singleWhere(
        (p) => p['name'] == 'flutter',
      );
      final sdk = Directory.fromUri(
        config.absolute.uri.resolve(flutter['rootUri'] as String),
      ).parent.parent;
      for (final entry in {
        Fonts.family: 'assets/fonts/inter-400.ttf',
        'MaterialIcons':
            '${sdk.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(entry.key)..addFont(
              Future.value(
                ByteData.sublistView(File(entry.value).readAsBytesSync()),
              ),
            ))
            .load();
      }
    });
    r.events.addAll([
      r.event(
        1,
        text: '@agent1 peux-tu regarder ce point ?',
        kind: 'message.user',
      ),
      r.event(
        2,
        text: 'Je prépare une **synthèse** des éléments demandés.',
        actor: 'finance',
      ),
    ]);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final vm = RoomViewModel(r.rooms, r.outbox, r.key)..foreground(false);
    await tester.runAsync(vm.open);
    final accents = ProfileAccents(r.h.repository);
    final boundary = GlobalKey();
    await tester.runAsync(
      () => tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(null, Brightness.light),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: keyboard),
              ),
              child: RoomView(create: () => vm, accents: accents),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
    return (vm: vm, accents: accents, boundary: boundary);
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      final render =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('_bmad-output/implementation-artifacts/epic-8-ui');
      await dir.create(recursive: true);
      await File('${dir.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('8.4 formulaire compact ancré en bas, aides à la demande', (
    tester,
  ) async {
    final page = await mount(tester);
    expect(find.text(Content.roomMentionHelp), findsNothing);
    expect(find.text(Content.roomNotificationsPending), findsNothing);
    final rect = tester.getRect(find.byType(Composer));
    expect(rect.height, lessThan(150));
    expect(rect.bottom, closeTo(844 - Spacing.sm, 2));
    expect(tester.takeException(), isNull);
    await capture(tester, page.boundary, 'compact');
    await tester.tap(find.byTooltip(Content.roomMentionsTitle));
    await tester.pumpAndSettle();
    expect(find.text(Content.roomMentionHelp), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    page.accents.dispose();
  });

  testWidgets(
    '8.4 suggestions nommées, remplacement au curseur et disparition après une mention',
    (tester) async {
      final page = await mount(tester, keyboard: 300);
      final field = find.descendant(
        of: find.byType(Composer),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'Bonjour @fi suite');
      final controller = tester.widget<TextField>(field).controller!;
      controller.selection = const TextSelection.collapsed(offset: 11);
      await tester.pump();
      expect(find.text('@Finance'), findsOneWidget);
      expect(find.text('@agent1'), findsNothing);
      expect(find.text('@Recherche'), findsNothing);
      await capture(tester, page.boundary, 'mentions-clavier');
      await tester.tap(find.text('@Finance'));
      await tester.pump();
      expect(controller.text, 'Bonjour @finance suite');
      expect(controller.selection.baseOffset, 'Bonjour @finance '.length);
      expect(find.byType(ActionChip), findsNothing);
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      await tester.pump();
      expect(find.byType(ActionChip), findsNothing);
      final rect = tester.getRect(find.byType(Composer));
      expect(rect.bottom, closeTo(844 - 300 - Spacing.sm, 2));
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpWidget(const SizedBox());
      page.accents.dispose();
    },
  );

  for (final scenario in [
    (name: 'texte-200-clavier', size: const Size(390, 844), keyboard: 300.0),
    (name: 'paysage-200-clavier', size: const Size(844, 390), keyboard: 120.0),
  ]) {
    testWidgets(
      '8.4 ${scenario.name} : saisie longue accessible sans débordement',
      (tester) async {
        final page = await mount(
          tester,
          size: scenario.size,
          keyboard: scenario.keyboard,
          scale: 2,
        );
        final field = find.descendant(
          of: find.byType(Composer),
          matching: find.byType(TextField),
        );
        await tester.enterText(
          field,
          'Première ligne\nDeuxième ligne\nTroisième ligne\nQuatrième ligne\nCinquième ligne',
        );
        await tester.pump();
        await tester.ensureVisible(find.byTooltip(Content.send));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byTooltip(Content.send), findsOneWidget);
        await capture(tester, page.boundary, scenario.name);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpWidget(const SizedBox());
        page.accents.dispose();
      },
    );
  }
}
