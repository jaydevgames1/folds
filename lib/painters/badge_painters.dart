import 'package:flutter/material.dart';
import 'dart:math';

class LinkBadge extends StatelessWidget {
  final String shape;
  final bool onBlack;
  const LinkBadge({required this.shape, required this.onBlack});

  @override
  Widget build(BuildContext context) {
    final color = onBlack ? Colors.white70 : Colors.black38;
    const size = 9.0;
    switch (shape) {
      case 'triangle':
        return CustomPaint(size: const Size(size, size), painter: TriBadgePainter(color));
      case 'square':
        return Container(width: size, height: size, color: color);
      case 'pentagon':
        return CustomPaint(size: const Size(size, size), painter: PentaBadgePainter(color));
      case 'circle':
      default:
        return Container(width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color));
    }
  }
}

class TriBadgePainter extends CustomPainter {
  final Color color;
  TriBadgePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }
  @override bool shouldRepaint(_) => false;
}

class PentaBadgePainter extends CustomPainter {
  final Color color;
  PentaBadgePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72 - 90) * pi / 180;
      final x = size.width / 2 + size.width / 2 * cos(angle);
      final y = size.height / 2 + size.height / 2 * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }
  @override bool shouldRepaint(_) => false;
}

