import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';

/// A fan-shaped field diagram the user taps to pick where the ball was hit.
class HitDirectionSelector extends StatelessWidget {
  final HitDirection? selected;
  final ValueChanged<HitDirection?> onChanged;

  const HitDirectionSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: CustomPaint(
            painter: _FieldPainter(selected: selected),
            child: Stack(
              children: HitDirection.values.map((dir) {
                final angle = _dirAngle(dir); // radians from top (north)
                // Place tap zones along an arc
                const r = 52.0;
                const cx = 0.5;
                const cy = 0.82; // home plate near bottom
                final dx = cx + r / 200 * sin(angle);
                final dy = cy - r / 130 * cos(angle);
                return Positioned(
                  left: dx * 200 - 22,
                  top: dy * 130 - 22,
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

/// Angle in radians from vertical (north = 0), positive = right
double _dirAngle(HitDirection dir) {
  switch (dir) {
    case HitDirection.line3B:     return -0.70;
    case HitDirection.leftField:  return -0.60;
    case HitDirection.leftCenter: return -0.28;
    case HitDirection.center:     return 0.0;
    case HitDirection.rightCenter:return 0.28;
    case HitDirection.rightField: return 0.60;
    case HitDirection.line1B:     return 0.70;
  }
}

class _FieldPainter extends CustomPainter {
  final HitDirection? selected;
  _FieldPainter({this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.88; // home plate position
    final maxR = size.height * 0.90;

    // Draw field sectors
    for (final dir in HitDirection.values) {
      final angle = _dirAngle(dir);
      final sectorWidth = 0.22; // radians half-width per sector
      final isSel = selected == dir;

      final paint = Paint()
        ..color = isSel
            ? Colors.yellow.withValues(alpha: 0.25)
            : Colors.green.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;

      final path = Path()..moveTo(cx, cy);
      // Arc from left edge to right edge of sector
      final startAngle = (pi / 2) + angle - sectorWidth;
      path.arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: maxR),
        -startAngle - pi,
        -(sectorWidth * 2),
        false,
      );
      path.close();

      // Flip the arc so it fans upward
      final matrix = Matrix4.identity()
        ..translate(cx, cy)
        ..rotateZ(pi)
        ..translate(-cx, -cy);
      final flipped = path.transform(matrix.storage);
      canvas.drawPath(flipped, paint);

      // Sector border line
      final linePaint = Paint()
        ..color = isSel
            ? Colors.yellow.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? 2.0 : 0.8;

      // Direction line from home plate
      final lineAngle = angle;
      final ex = cx + maxR * sin(lineAngle);
      final ey = cy - maxR * cos(lineAngle);
      canvas.drawLine(Offset(cx, cy), Offset(ex, ey), linePaint);
    }

    // Foul lines — drawn outside the outermost hit zone sectors (±1.25 rad)
    final foulPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    canvas.drawLine(
        Offset(cx, cy), Offset(cx - maxR * sin(1.25), cy - maxR * cos(1.25)),
        foulPaint);
    canvas.drawLine(
        Offset(cx, cy), Offset(cx + maxR * sin(1.25), cy - maxR * cos(1.25)),
        foulPaint);

    // Outfield arc
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: maxR * 0.75),
      pi + 0.35,
      pi - 0.7,
      false,
      arcPaint,
    );

    // Home plate dot
    canvas.drawCircle(
        Offset(cx, cy), 5,
        Paint()..color = Colors.white.withValues(alpha: 0.6));

    // Selected direction arrow
    if (selected != null) {
      final angle = _dirAngle(selected!);
      final arrowPaint = Paint()
        ..color = Colors.yellow.shade400
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final ex = cx + maxR * 0.72 * sin(angle);
      final ey = cy - maxR * 0.72 * cos(angle);
      canvas.drawLine(Offset(cx, cy), Offset(ex, ey), arrowPaint);
      // Arrowhead
      final headLen = 8.0;
      final headAngle = 0.4;
      final norm = atan2(ex - cx, cy - ey);
      canvas.drawLine(
        Offset(ex, ey),
        Offset(ex - headLen * sin(norm + headAngle),
            ey + headLen * cos(norm + headAngle)),
        arrowPaint,
      );
      canvas.drawLine(
        Offset(ex, ey),
        Offset(ex - headLen * sin(norm - headAngle),
            ey + headLen * cos(norm - headAngle)),
        arrowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_FieldPainter old) => old.selected != selected;
}
