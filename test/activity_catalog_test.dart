import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/activity_catalog.dart';
import 'package:hermes_mobile/ui/components/activity_family_painters.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/tokens.dart';

Future<List<int>> pixels(CustomPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(24, 24));
  final picture = recorder.endRecording();
  final image = await picture.toImage(24, 24);
  final bytes = await image.toByteData();
  final result = bytes!.buffer.asUint8List().toList();
  image.dispose();
  picture.dispose();
  return result;
}

// Enregistre les chemins après transformation, sans modifier les peintres.
class _PaintedPath {
  _PaintedPath(this.source, this.transformed, this.halfStroke);
  final Path source;
  final Path transformed;
  final double halfStroke;
  Rect get envelope => transformed.getBounds().inflate(halfStroke);
}

class _RecordingCanvas implements Canvas {
  Matrix4 _matrix = Matrix4.identity();
  final _stack = <Matrix4>[];
  final paths = <_PaintedPath>[];

  @override
  void save() => _stack.add(_matrix.clone());
  @override
  void restore() => _matrix = _stack.removeLast();
  @override
  void translate(double dx, double dy) =>
      _matrix.translateByDouble(dx, dy, 0, 1);
  @override
  void scale(double sx, [double? sy]) =>
      _matrix.scaleByDouble(sx, sy ?? sx, 1, 1);
  @override
  void rotate(double radians) => _matrix.rotateZ(radians);
  @override
  void drawPath(Path path, Paint paint) => paths.add(
    _PaintedPath(
      path,
      path.transform(_matrix.storage),
      paint.style == PaintingStyle.stroke ? paint.strokeWidth / 2 : 0,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('17 familles dédiées, repli, décodage et JSON compatible', () {
    expect(ActivityKind.values, hasLength(18));
    final labels = <String>{};
    for (final kind in ActivityKind.values) {
      expect(ActivityKind.decode(kind.name), kind);
      final item = ActivityItem(
        3,
        kind,
        toolId: 'opaque',
        completed: true,
        details: const {'result': 'reçu'},
      );
      expect(ActivityItem.fromJson(item.toJson()).toJson(), item.toJson());
      expect(labels.add(Content.activityLabel(kind)), isTrue);
      final entry = ActivityCatalog.standard.resolve(kind);
      if (kind != ActivityKind.unknown) {
        expect(identical(entry, ActivityCatalog.unknownEntry), isFalse);
      }
      expect(
        ActivityCatalog(entries: const {}).resolve(kind),
        ActivityCatalog.unknownEntry,
      );
    }
    expect(
      ActivityItem.fromJson({'turn': 1, 'kind': 'code'}).kind,
      ActivityKind.unknown,
    );
    expect(
      ActivityItem.fromJson({'turn': 1, 'activityVersion': 1, 'kind': 'future'})
          .kind,
      ActivityKind.unknown,
    );
    expect(
      Content.activityLabel(ActivityKind.preparation),
      isNot(Content.activityUnknown),
    );
  });

  test('chaque motif dessine une pose stable et un mouvement local visible à 24 px', () async {
    for (final kind in ActivityKind.values) {
      final entry = ActivityCatalog.standard.resolve(kind);
      CustomPainter painter(double phase, bool stationary) => entry.painter(
        color: Colors.black,
        progress: phase,
        stationary: stationary,
      );
      final still = await pixels(painter(0, true));
      expect(still.any((byte) => byte != 0), isTrue, reason: kind.name);
      List<int>? previous;
      for (final phase in [.125, .25, .625, .75]) {
        expect(await pixels(painter(phase, true)), still, reason: kind.name);
        final animated = await pixels(painter(phase, false));
        expect(animated, isNot(still), reason: '${kind.name} phase $phase');
        if (previous != null) {
          expect(
            animated,
            isNot(previous),
            reason: '${kind.name} change dans le temps à $phase',
          );
        }
        previous = animated;
      }
      final p = painter(.25, false);
      if (p is FamilyActivityPainter) {
        expect(p.drawing, same(ActivityTokens.familyDrawings[kind.name]));
      }
    }
  });

  test('les nouveaux motifs restent dans le slot et leurs contours ne suivent jamais les pièces mobiles', () {
    for (final kind in ActivityKind.values) {
      final entry = ActivityCatalog.standard.resolve(kind);
      final initial = entry.painter(
        color: Colors.black,
        progress: 0,
        stationary: true,
      );
      if (initial is! FamilyActivityPainter) continue;
      final fixed = initial.drawing.fixed;
      for (var step = 0; step <= 32; step++) {
        final phase = step / 32;
        for (final stationary in [false, true]) {
          final canvas = _RecordingCanvas();
          entry
              .painter(
                color: Colors.black,
                progress: phase,
                stationary: stationary,
              )
              .paint(canvas, const Size(32, 32));
          expect(canvas._stack, isEmpty);
          // Le contour est peint avant toute transformation locale. Cette
          // assertion échoue s’il reçoit la translation/rotation de la pièce.
          expect(canvas.paths.first.source, same(fixed));
          expect(
            canvas.paths.first.transformed.getBounds(),
            fixed.getBounds(),
            reason: '${kind.name} contour fixe à $phase',
          );
          for (final painted in canvas.paths) {
            if (painted.source.computeMetrics().isEmpty) continue;
            final bounds = painted.envelope;
            expect(
              bounds.left,
              greaterThanOrEqualTo(-.000001),
              reason: '${kind.name} gauche à $phase',
            );
            expect(
              bounds.top,
              greaterThanOrEqualTo(-.000001),
              reason: '${kind.name} haut à $phase',
            );
            expect(
              bounds.right,
              lessThanOrEqualTo(32.000001),
              reason: '${kind.name} droite à $phase',
            );
            expect(
              bounds.bottom,
              lessThanOrEqualTo(32.000001),
              reason: '${kind.name} bas à $phase',
            );
          }
        }
      }
    }
  });
}
