// Run with: flutter test test/generate_icon_test.dart
// Generates assets/icon/app_icon.png (1024×1024) matching the home screen logo.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generate app icon', () async {
    const double sz = 1024;
    const double pad = 96; // padding inside the square

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // ── Background (dark navy, rounded) ──────────────────────────────────────
    final bgPaint = Paint()..color = const Color(0xFF12203A);
    final rrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, sz, sz),
      const Radius.circular(sz * 0.18),
    );
    canvas.drawRRect(rrect, bgPaint);

    // ── Diamond painter (scaled into padded area) ─────────────────────────
    canvas.save();
    canvas.translate(pad, pad);
    _paintDiamond(canvas, const Size(sz - pad * 2, sz - pad * 2));
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(sz.toInt(), sz.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    Directory('assets/icon').createSync(recursive: true);
    File('assets/icon/app_icon.png').writeAsBytesSync(bytes);
    // ignore: avoid_print
    print('Saved assets/icon/app_icon.png');
  });
}

void _paintDiamond(Canvas canvas, Size size) {
  final cx = size.width / 2;
  final cy = size.height / 2;
  final r = size.width * 0.36;

  final home   = Offset(cx,      cy + r);
  final first  = Offset(cx + r,  cy);
  final second = Offset(cx,      cy - r);
  final third  = Offset(cx - r,  cy);

  // Outfield grass fan — symmetric arc centered on home plate, ±45° foul lines
  final grassPaint = Paint()
    ..color = const Color(0xFF1B5E20).withValues(alpha: 0.85)
    ..style = PaintingStyle.fill;
  final foulLen = size.width * 0.72;
  final grassPath = Path()
    ..moveTo(home.dx, home.dy)
    ..lineTo(home.dx + foulLen * cos(-3 * pi / 4),
             home.dy + foulLen * sin(-3 * pi / 4))
    ..arcTo(
      Rect.fromCircle(center: home, radius: foulLen),
      -3 * pi / 4, pi / 2, false,
    )
    ..close();
  canvas.drawPath(grassPath, grassPaint);

  // Infield dirt diamond
  final dirtPath = Path()
    ..moveTo(home.dx, home.dy)
    ..lineTo(first.dx, first.dy)
    ..lineTo(second.dx, second.dy)
    ..lineTo(third.dx, third.dy)
    ..close();
  canvas.drawPath(
    dirtPath,
    Paint()
      ..color = const Color(0xFF6B3A1F).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill,
  );

  // Inner infield grass
  final igr = r * 0.54;
  final igPath = Path()
    ..moveTo(cx,       cy + igr)
    ..lineTo(cx + igr, cy)
    ..lineTo(cx,       cy - igr)
    ..lineTo(cx - igr, cy)
    ..close();
  canvas.drawPath(
    igPath,
    Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill,
  );

  // Base paths
  final linePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = size.width * 0.013;
  canvas.drawLine(home, first, linePaint);
  canvas.drawLine(home, third, linePaint);
  canvas.drawLine(first, second, linePaint);
  canvas.drawLine(third, second, linePaint);

  // Base squares (rotated 45°)
  final basePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.92)
    ..style = PaintingStyle.fill;
  final bs = size.width * 0.055;
  for (final pos in [first, second, third]) {
    canvas.drawPath(
      Path()
        ..moveTo(pos.dx,      pos.dy - bs)
        ..lineTo(pos.dx + bs, pos.dy)
        ..lineTo(pos.dx,      pos.dy + bs)
        ..lineTo(pos.dx - bs, pos.dy)
        ..close(),
      basePaint,
    );
  }

  // Home plate: flat edge toward pitcher (top), point toward catcher (bottom)
  canvas.drawPath(
    Path()
      ..moveTo(home.dx - bs,       home.dy - bs * 0.5)  // top-left
      ..lineTo(home.dx + bs,       home.dy - bs * 0.5)  // top-right (flat, pitcher side)
      ..lineTo(home.dx + bs,       home.dy + bs * 0.2)  // right side
      ..lineTo(home.dx,            home.dy + bs)         // bottom point (catcher side)
      ..lineTo(home.dx - bs,       home.dy + bs * 0.2)  // left side
      ..close(),
    basePaint,
  );

  // Pitcher's mound
  final moundR = size.width * 0.045;
  canvas.drawCircle(
    Offset(cx, cy), moundR,
    Paint()..color = const Color(0xFF8B4513).withValues(alpha: 0.85),
  );
  canvas.drawCircle(
    Offset(cx, cy), moundR,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.008,
  );
}
