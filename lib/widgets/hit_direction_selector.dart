import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';

/// A top-down baseball field the user taps to pick where the ball was hit.
class HitDirectionSelector extends StatelessWidget {
  final HitDirection? selected;
  final ValueChanged<HitDirection?> onChanged;
  /// When true the arrow stops inside the infield diamond (for GO to infielders).
  final bool isInfield;

  const HitDirectionSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.isInfield = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              const h = 140.0;
              final cx = w / 2;
              const cy = h * 0.90;
              const scale = h * 0.92;

              return CustomPaint(
                painter: _FieldPainter(selected: selected, canvasWidth: w, isInfield: isInfield),
                child: Stack(
                  children: HitDirection.values.map((dir) {
                    final angle = _dirAngle(dir);
                    // Place tap zones at ~60% of the outfield arc
                    final r = scale * 0.58;
                    final dx = cx + r * sin(angle);
                    final dy = cy - r * cos(angle);
                    return Positioned(
                      left: dx - 22,
                      top: dy - 22,
                      child: GestureDetector(
                        onTap: () => onChanged(selected == dir ? null : dir),
                        child: Container(
                          width: 44,
                          height: 44,
                          color: Colors.transparent,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        // Labels row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: HitDirection.values.map((dir) {
            final isSel = selected == dir;
            return GestureDetector(
              onTap: () => onChanged(selected == dir ? null : dir),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isSel
                      ? Colors.yellow.shade700
                      : const Color(0xFF152030),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: isSel
                          ? Colors.yellow.shade500
                          : Colors.white12),
                ),
                child: Text(
                  hitDirectionLabel(dir),
                  style: TextStyle(
                    color: isSel ? Colors.black : Colors.white54,
                    fontSize: 10,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Angle in radians from vertical (north = 0), positive = right (toward 1B side)
double _dirAngle(HitDirection dir) {
  switch (dir) {
    case HitDirection.line3B:      return -0.68;
    case HitDirection.leftField:   return -0.46;
    case HitDirection.leftCenter:  return -0.22;
    case HitDirection.center:      return 0.0;
    case HitDirection.rightCenter: return 0.22;
    case HitDirection.rightField:  return 0.46;
    case HitDirection.line1B:      return 0.68;
  }
}

class _FieldPainter extends CustomPainter {
  final HitDirection? selected;
  final double canvasWidth;
  final bool isInfield;
  _FieldPainter({this.selected, required this.canvasWidth, this.isInfield = false});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.90;
    final scale = size.height * 0.92; // outfield wall radius

    // Base diamond geometry
    final d = size.height * 0.27; // home-to-corner distance
    final home = Offset(cx, cy);
    final first = Offset(cx + d, cy - d);
    final second = Offset(cx, cy - d * 2);
    final third = Offset(cx - d, cy - d);

    // ── Direction sectors (background, drawn first) ──────────────────────────
    const sectorHalf = 0.23;
    for (final dir in HitDirection.values) {
      final angle = _dirAngle(dir);
      final isSel = selected == dir;

      final sectorPaint = Paint()
        ..color = isSel
            ? Colors.yellow.withValues(alpha: 0.18)
            : Colors.green.withValues(alpha: 0.07)
        ..style = PaintingStyle.fill;

      final leftAngle = angle - sectorHalf;
      final rightAngle = angle + sectorHalf;

      // Build sector path: home → left edge → arc → close
      // Canvas arc convention: 0 = east (right), clockwise positive
      // Our angle: 0 = north (up), clockwise positive
      // Conversion: canvasAngle = ourAngle - π/2
      final path = Path()..moveTo(cx, cy);
      path.lineTo(cx + scale * sin(leftAngle), cy - scale * cos(leftAngle));
      path.arcTo(
        Rect.fromCircle(center: home, radius: scale),
        leftAngle - pi / 2,
        sectorHalf * 2,
        false,
      );
      path.close();
      canvas.drawPath(path, sectorPaint);

      // Sector divider line
      final linePaint = Paint()
        ..color = isSel
            ? Colors.yellow.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? 1.5 : 0.7;
      // Draw center line of this sector
      canvas.drawLine(
        home,
        Offset(cx + scale * sin(angle), cy - scale * cos(angle)),
        linePaint,
      );
      // Draw right edge of last sector to complete all borders
      if (dir == HitDirection.line1B) {
        canvas.drawLine(
          home,
          Offset(cx + scale * sin(rightAngle), cy - scale * cos(rightAngle)),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.08)
            ..strokeWidth = 0.7,
        );
      }
    }

    // ── Foul lines ────────────────────────────────────────────────────────────
    final foulAngle3B = _dirAngle(HitDirection.line3B) - sectorHalf;
    final foulAngle1B = _dirAngle(HitDirection.line1B) + sectorHalf;
    final foulPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      home,
      Offset(cx + scale * sin(foulAngle3B), cy - scale * cos(foulAngle3B)),
      foulPaint,
    );
    canvas.drawLine(
      home,
      Offset(cx + scale * sin(foulAngle1B), cy - scale * cos(foulAngle1B)),
      foulPaint,
    );

    // ── Outfield warning track arc ────────────────────────────────────────────
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawArc(
      Rect.fromCircle(center: home, radius: scale * 0.88),
      foulAngle3B - pi / 2,
      foulAngle1B - foulAngle3B,
      false,
      arcPaint,
    );

    // ── Infield dirt circle ───────────────────────────────────────────────────
    final dirtPaint = Paint()
      ..color = const Color(0xFFB8834A).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy - d * 0.85), d * 0.90, dirtPaint);

    // ── Base paths (diamond) ──────────────────────────────────────────────────
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final diamond = Path()
      ..moveTo(home.dx, home.dy)
      ..lineTo(first.dx, first.dy)
      ..lineTo(second.dx, second.dy)
      ..lineTo(third.dx, third.dy)
      ..close();
    canvas.drawPath(diamond, basePaint);

    // ── Base squares ──────────────────────────────────────────────────────────
    void drawBase(Offset pos) {
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: 6, height: 6),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
    drawBase(first);
    drawBase(second);
    drawBase(third);

    // ── Base labels ───────────────────────────────────────────────────────────
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void drawLabel(String text, Offset pos, double ox, double oy) {
      tp.text = TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(canvas, pos.translate(ox - tp.width / 2, oy - tp.height / 2));
    }
    drawLabel('1B', first, 14, -2);
    drawLabel('2B', second, 0, -11);
    drawLabel('3B', third, -14, -2);

    // ── Home plate ───────────────────────────────────────────────────────────
    canvas.drawCircle(
      home,
      4,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );

    // ── Selected direction arrow ──────────────────────────────────────────────
    if (selected != null) {
      final angle = _dirAngle(selected!);
      final arrowPaint = Paint()
        ..color = Colors.yellow.shade400
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      // Infield plays: arrow stays inside the diamond (~80% of d from home)
      final arrowLen = isInfield ? d * 0.80 : scale * 0.68;
      final ex = cx + arrowLen * sin(angle);
      final ey = cy - arrowLen * cos(angle);
      canvas.drawLine(home, Offset(ex, ey), arrowPaint);
      // Arrowhead
      final norm = atan2(ex - cx, cy - ey);
      const headLen = 8.0;
      const headA = 0.4;
      canvas.drawLine(
        Offset(ex, ey),
        Offset(ex - headLen * sin(norm + headA), ey + headLen * cos(norm + headA)),
        arrowPaint,
      );
      canvas.drawLine(
        Offset(ex, ey),
        Offset(ex - headLen * sin(norm - headA), ey + headLen * cos(norm - headA)),
        arrowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_FieldPainter old) =>
      old.selected != selected || old.canvasWidth != canvasWidth || old.isInfield != isInfield;
}
