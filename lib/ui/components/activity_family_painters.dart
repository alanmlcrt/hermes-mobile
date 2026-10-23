import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/timeline.dart';
import '../tokens.dart';

/// Motifs vectoriels adaptés de simple-conversation ; seule une pièce bouge.
/// ActivityIllustration conserve le cycle de vie, la visibilité, la pause et la fin.
class FamilyActivityPainter extends CustomPainter {
  const FamilyActivityPainter({
    required this.kind,
    required this.color,
    required this.progress,
    required this.stationary,
  });
  final ActivityKind kind;
  final Color color;
  final double progress;
  final bool stationary;
  static CustomPainter fileCreate({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.fileCreate,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter webSearch({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.webSearch,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter fileRead({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.fileRead,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter command({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.command,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter webBrowse({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.webBrowse,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter fileEdit({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.fileEdit,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter fileSearch({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.fileSearch,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter imageCreate({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.imageCreate,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter memory({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.memory,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter delegate({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.delegate,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter organize({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.organize,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter imageAnalyze({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.imageAnalyze,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter skill({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.skill,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter schedule({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.schedule,
    color: color,
    progress: progress,
    stationary: stationary,
  );
  static CustomPainter preparation({
    required Color color,
    required double progress,
    required bool stationary,
  }) => FamilyActivityPainter(
    kind: ActivityKind.preparation,
    color: color,
    progress: progress,
    stationary: stationary,
  );

  ActivityFamilyDrawing get drawing =>
      ActivityTokens.familyDrawings[kind.name]!;
  double get phase => stationary ? 0 : math.sin(progress * math.pi * 2);
  Offset get movingOffset => drawing.travel * phase;
  double get movingAngle =>
      drawing.rotation * (stationary ? 0 : progress * math.pi * 2);
  double get revealedFraction =>
      stationary || !drawing.reveal ? 1 : Curves.easeOut.transform(progress);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / ActivityTokens.viewSize;
    canvas.save();
    canvas.translate(
      (size.width - ActivityTokens.viewSize * scale) / 2,
      (size.height - ActivityTokens.viewSize * scale) / 2,
    );
    canvas.scale(scale);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ActivityTokens.lineStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(drawing.fixed, pen);
    canvas.save();
    canvas.translate(movingOffset.dx, movingOffset.dy);
    canvas.translate(drawing.pivot.dx, drawing.pivot.dy);
    canvas.rotate(movingAngle);
    canvas.translate(-drawing.pivot.dx, -drawing.pivot.dy);
    if (drawing.filled) pen.style = PaintingStyle.fill;
    if (drawing.reveal && !stationary) {
      for (final metric in drawing.moving.computeMetrics()) {
        canvas.drawPath(
          metric.extractPath(0, metric.length * revealedFraction),
          pen,
        );
      }
    } else {
      canvas.drawPath(drawing.moving, pen);
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(FamilyActivityPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.stationary != stationary;
}
