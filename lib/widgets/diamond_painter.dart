import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';

/// Draws a traditional scorebook diamond cell for a single plate appearance.
class DiamondCell extends StatelessWidget {
  final PlateAppearance? pa;
  final bool isCurrent; // highlight if this is the next batter
  final VoidCallback? onTap;
  final double size;

  const DiamondCell({
    super.key,
    this.pa,
    this.isCurrent = false,
    this.onTap,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(
            color: isCurrent
                ? Colors.amber.shade400
                : Colors.white.withValues(alpha: 0.15),
            width: isCurrent ? 2 : 1,
          ),
          color: isCurrent
              ? Colors.amber.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: CustomPaint(
          painter: _DiamondPainter(pa: pa),
        ),
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  final PlateAppearance? pa;

  _DiamondPainter({this.pa});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.32;

    // Diamond corners: home=bottom, first=right, second=top, third=left
    final home = Offset(cx, cy + r);
    final first = Offset(cx + r, cy);
    final second = Offset(cx, cy - r);
    final third = Offset(cx - r, cy);

    // --- Draw diamond outline ---
    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final diamondPath = Path()
      ..moveTo(home.dx, home.dy)
      ..lineTo(first.dx, first.dy)
      ..lineTo(second.dx, second.dy)
      ..lineTo(third.dx, third.dy)
      ..close();

    canvas.drawPath(diamondPath, outlinePaint);

    if (pa == null) return;

    // --- Color by result type ---
    Color pathColor;
    if (pa!.isHit) {
      pathColor = const Color(0xFF66BB6A); // green
    } else if (const {
      PlayResult.walk,
      PlayResult.intentionalWalk,
      PlayResult.hitByPitch,
    }.contains(pa!.result)) {
      pathColor = const Color(0xFF42A5F5); // blue
    } else if (pa!.result == PlayResult.error) {
      pathColor = const Color(0xFFFF7043); // orange
    } else if (pa!.result == PlayResult.fieldersChoice) {
      pathColor = const Color(0xFFFFCA28); // yellow
    } else {
      pathColor = const Color(0xFFEF5350); // red for outs
    }

    final linePaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // --- Draw base paths based on advancement ---
    if (pa!.reachedFirst) {
      canvas.drawLine(home, first, linePaint);
    }
    if (pa!.reachedSecond) {
      canvas.drawLine(first, second, linePaint);
    }
    if (pa!.reachedThird) {
      canvas.drawLine(second, third, linePaint);
    }
    if (pa!.scored) {
      canvas.drawLine(third, home, linePaint);
      // Shade the inside of the diamond to indicate a run scored
      final fillPaint = Paint()
        ..color = pathColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawPath(diamondPath, fillPaint);
    }

    // --- Result text ---
    final hasFielders = pa!.fielderNotation.isNotEmpty;
    // Skip the second notation line when displayText already contains the
    // fielder info (flyOut "F7", lineOut "L7", groundOut/DP/TP "6-3" etc.)
    final showFielderLine = hasFielders &&
        pa!.displayText != pa!.fielderNotation &&
        pa!.result != PlayResult.flyOut &&
        pa!.result != PlayResult.lineOut;
    final fontSize = size.width * 0.17;
    final textColor = pa!.isOut ? pathColor.withValues(alpha: 0.9) : pathColor;
    // If there's a separate fielder notation line, shift main text up slightly
    final textOffset = showFielderLine
        ? Offset(cx, cy - size.height * 0.08)
        : Offset(cx, cy);
    if (pa!.result == PlayResult.strikeoutLooking) {
      _drawBackwardsK(canvas, textOffset, fontSize, textColor);
    } else {
      _drawText(canvas, pa!.displayText, textOffset, fontSize, textColor,
          bold: true);
    }
    // Fielder notation below main text (e.g. "6-3", "E6", "6-4-3")
    if (showFielderLine) {
      _drawText(
        canvas,
        pa!.fielderNotation,
        Offset(cx, cy + size.height * 0.1),
        size.width * 0.13,
        textColor.withValues(alpha: 0.8),
      );
    }

    // --- Hit direction arrow ---
    if (pa!.hitDirection != null) {
      final isBunt = pa!.result == PlayResult.sacrificeBunt;
      _drawHitDirection(canvas, size, pa!.hitDirection!, home, short: isBunt);
    }

    // --- Ball-Strike count — upper right corner ---
    if (pa!.pitchBalls > 0 || pa!.pitchStrikes > 0) {
      final countText = '${pa!.pitchBalls}-${pa!.pitchStrikes}';
      final tp = TextPainter(
        text: TextSpan(
          text: countText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: size.width * 0.13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(size.width - tp.width - 3, 3),
      );
    }

    // --- Base event notations (SB3, WP, PB, etc.) top-left corner ---
    if (pa!.baseEvents.isNotEmpty) {
      _drawText(
        canvas,
        pa!.baseEvents.join(' '),
        Offset(size.width * 0.22, size.height * 0.13),
        size.width * 0.13,
        Colors.cyanAccent.withValues(alpha: 0.9),
      );
    }

    // --- RBI dots below center ---
    if (pa!.rbis > 0) {
      final dotPaint = Paint()
        ..color = Colors.yellow.shade300
        ..style = PaintingStyle.fill;
      final totalWidth = (pa!.rbis - 1) * 7.0;
      for (int i = 0; i < pa!.rbis && i < 4; i++) {
        canvas.drawCircle(
          Offset(cx - totalWidth / 2 + i * 7.0, home.dy - 6),
          2.5,
          dotPaint,
        );
      }
    }
  }

  void _drawBackwardsK(Canvas canvas, Offset center, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'K',
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    // Flip horizontally around the center point
    canvas.translate(center.dx * 2, 0);
    canvas.scale(-1.0, 1.0);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
    canvas.restore();
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawHitDirection(Canvas canvas, Size size, HitDirection dir, Offset home, {bool short = false}) {
    // Angle from vertical: negative = left, positive = right
    const angles = {
      HitDirection.line3B:      -0.70,
      HitDirection.leftField:   -0.60,
      HitDirection.leftCenter:  -0.28,
      HitDirection.center:       0.0,
      HitDirection.rightCenter:  0.28,
      HitDirection.rightField:   0.60,
      HitDirection.line1B:       0.70,
    };
    final angle = angles[dir]!;
    final length = size.height * (short ? 0.26 : 0.52);
    final ex = home.dx + length * sin(angle);
    final ey = home.dy - length * cos(angle);

    final paint = Paint()
      ..color = Colors.yellow.shade300.withValues(alpha: 0.85)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(home, Offset(ex, ey), paint);

    // Arrowhead
    const headLen = 3.5;
    const headAngle = 0.45;
    final norm = atan2(ex - home.dx, home.dy - ey);
    canvas.drawLine(
      Offset(ex, ey),
      Offset(ex - headLen * sin(norm + headAngle), ey + headLen * cos(norm + headAngle)),
      paint,
    );
    canvas.drawLine(
      Offset(ex, ey),
      Offset(ex - headLen * sin(norm - headAngle), ey + headLen * cos(norm - headAngle)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DiamondPainter old) => old.pa != pa;
}
