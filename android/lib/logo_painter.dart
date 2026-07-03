import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter to draw the OpenRelay radio antenna/tower logo exactly as shown in screenshots.
class AntennaLogoPainter extends CustomPainter {
  final Color color;

  AntennaLogoPainter({this.color = const Color(0xFFE50012)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Dimensions
    final double w = size.width;
    final double h = size.height;

    // Center of the top node
    final double topNodeX = w / 2;
    final double topNodeY = h * 0.40;
    final double nodeRadius = w * 0.07;

    // Tower base coordinates
    final double towerLeftX = w * 0.35;
    final double towerRightX = w * 0.65;
    final double towerBottomY = h * 0.90;

    // 1. Draw the A-Frame Tower legs
    final Path towerPath = Path();
    // Left leg
    towerPath.moveTo(topNodeX, topNodeY);
    towerPath.lineTo(towerLeftX, towerBottomY);
    // Right leg
    towerPath.moveTo(topNodeX, topNodeY);
    towerPath.lineTo(towerRightX, towerBottomY);
    // Crossbar
    final double crossbarY = topNodeY + (towerBottomY - topNodeY) * 0.45;
    final double crossbarLeftX = topNodeX - (topNodeX - towerLeftX) * 0.45;
    final double crossbarRightX = topNodeX + (towerRightX - topNodeX) * 0.45;
    towerPath.moveTo(crossbarLeftX, crossbarY);
    towerPath.lineTo(crossbarRightX, crossbarY);

    canvas.drawPath(towerPath, paint);

    // 2. Draw the peak circle node (solid fill)
    canvas.drawCircle(Offset(topNodeX, topNodeY), nodeRadius, fillPaint);

    // 3. Draw the waves
    // Waves are concentric arcs centered at (topNodeX, topNodeY)
    final double waveCenterY = topNodeY;

    // Wave parameters
    final double r1 = w * 0.22; // inner wave radius
    final double r2 = w * 0.38; // outer wave radius
    final double sweepAngle = 75 * math.pi / 180; // sweep of arc (75 degrees)

    // Left waves (centered at 180 degrees)
    // Draw inner left wave
    canvas.drawArc(
      Rect.fromCircle(center: Offset(topNodeX, waveCenterY), radius: r1),
      math.pi - sweepAngle / 2,
      sweepAngle,
      false,
      paint,
    );
    // Draw outer left wave
    canvas.drawArc(
      Rect.fromCircle(center: Offset(topNodeX, waveCenterY), radius: r2),
      math.pi - sweepAngle / 2,
      sweepAngle,
      false,
      paint,
    );

    // Right waves (centered at 0 degrees)
    // Draw inner right wave
    canvas.drawArc(
      Rect.fromCircle(center: Offset(topNodeX, waveCenterY), radius: r1),
      -sweepAngle / 2,
      sweepAngle,
      false,
      paint,
    );
    // Draw outer right wave
    canvas.drawArc(
      Rect.fromCircle(center: Offset(topNodeX, waveCenterY), radius: r2),
      -sweepAngle / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
