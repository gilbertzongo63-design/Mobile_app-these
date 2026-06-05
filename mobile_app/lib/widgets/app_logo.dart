import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final Color color;

  const AppLogo({
    super.key,
    this.size = 32,
    this.color = const Color(0xFF35CF72),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AppLogoPainter(color),
      ),
    );
  }
}

class AppBrand extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;

  const AppBrand({
    super.key,
    this.logoSize = 34,
    this.fontSize = 30,
    this.fontWeight = FontWeight.w800,
    this.color = const Color(0xFF0A8A52),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: logoSize),
        const SizedBox(width: 12),
        Text(
          'EcoSort',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  final Color color;

  _AppLogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.12;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    final hexPath = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        hexPath.moveTo(point.dx, point.dy);
      } else {
        hexPath.lineTo(point.dx, point.dy);
      }
    }
    hexPath.close();

    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(hexPath, outlinePaint);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final leafPath = Path()
      ..moveTo(size.width * 0.30, size.height * 0.44)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.26,
        size.width * 0.70,
        size.height * 0.44,
      )
      ..quadraticBezierTo(
        size.width * 0.57,
        size.height * 0.60,
        size.width * 0.44,
        size.height * 0.56,
      )
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height * 0.54,
        size.width * 0.30,
        size.height * 0.44,
      )
      ..close();
    canvas.drawPath(leafPath, fillPaint);

    final stemPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.54),
      Offset(size.width * 0.50, size.height * 0.78),
      stemPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AppLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
