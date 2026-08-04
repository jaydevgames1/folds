import 'package:flutter/material.dart';
import 'package:folds/core/constants.dart';

class HomeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final innerRadius = size.width * 0.30;
    final center = Offset(cx, cy);
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.clipPath(clipPath);
    canvas.drawCircle(center, innerRadius, Paint()..color = Colors.white);
    final blackPath = Path()
      ..moveTo(cx + innerRadius, cy - innerRadius)
      ..lineTo(cx + innerRadius, cy + innerRadius)
      ..lineTo(cx - innerRadius, cy + innerRadius)
      ..close();
    canvas.drawPath(blackPath, Paint()..color = const Color(0xFF2C2C2C));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ArchiveIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(4)), paint);
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.35), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.32, size.height * 0.52, size.width * 0.36, size.height * 0.16),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
class FirePainter extends CustomPainter {
  final bool isDoneToday;
  const FirePainter({required this.isDoneToday});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer flame
    final outerPath = Path()
      ..moveTo(w * 0.50, 0)
      ..cubicTo(w * 0.78, h * 0.18, w * 0.96, h * 0.38, w * 0.86, h * 0.60)
      ..cubicTo(w * 1.00, h * 0.42, w * 0.90, h * 0.18, w * 0.82, 0)
      ..cubicTo(w * 0.96, h * 0.48, w * 0.96, h * 0.80, w * 0.72, h)
      ..lineTo(w * 0.28, h)
      ..cubicTo(w * 0.04, h * 0.80, w * 0.04, h * 0.48, w * 0.18, 0)
      ..cubicTo(w * 0.10, h * 0.18, 0, h * 0.42, w * 0.14, h * 0.60)
      ..cubicTo(w * 0.04, h * 0.38, w * 0.22, h * 0.18, w * 0.50, 0)
      ..close();

    canvas.drawPath(
      outerPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = isDoneToday ? const Color(0xFFE53935) : Colors.grey.shade300,
    );

    if (isDoneToday) {
      // Inner yellow flame
      final innerPath = Path()
        ..moveTo(w * 0.50, h * 0.32)
        ..cubicTo(w * 0.66, h * 0.46, w * 0.72, h * 0.60, w * 0.67, h * 0.74)
        ..cubicTo(w * 0.74, h * 0.60, w * 0.68, h * 0.48, w * 0.74, h * 0.36)
        ..cubicTo(w * 0.80, h * 0.58, w * 0.78, h * 0.78, w * 0.62, h * 0.92)
        ..lineTo(w * 0.38, h * 0.92)
        ..cubicTo(w * 0.22, h * 0.78, w * 0.20, h * 0.58, w * 0.26, h * 0.36)
        ..cubicTo(w * 0.32, h * 0.48, w * 0.26, h * 0.60, w * 0.33, h * 0.74)
        ..cubicTo(w * 0.28, h * 0.60, w * 0.34, h * 0.46, w * 0.50, h * 0.32)
        ..close();

      canvas.drawPath(
        innerPath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFD465),
      );
    }
  }

  @override
  bool shouldRepaint(FirePainter old) => old.isDoneToday != isDoneToday;
}