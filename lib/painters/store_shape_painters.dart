import 'package:flutter/material.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';

enum StoreShape { rectangle, circle, hexa, noAds }

// ── Shape widget ──────────────────────────────────────────────────────────────
class ShapeWidget extends StatelessWidget {
  final StoreShape shape;
  final double size;

  const ShapeWidget({required this.shape, required this.size});

  @override
  Widget build(BuildContext context) {
    switch (shape) {
      case StoreShape.rectangle:
        return CustomPaint(size: Size(size, size * 0.7), painter: _RectanglePainter());
      case StoreShape.circle:
        return CustomPaint(size: Size(size, size), painter: _CirclePainter());
      case StoreShape.hexa:
        return CustomPaint(size: Size(size, size), painter: _HexaPainter());
      case StoreShape.noAds:
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size, height: size,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
            ),
            Text('ADS',
              style: GoogleFonts.dmSans(fontSize: size * 0.25, fontWeight: FontWeight.w800, color: Colors.white)),
            CustomPaint(size: Size(size, size), painter: _NoBanPainter()),
          ],
        );
    }
  }
}

class _RectanglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width / 2, size.height), paint);
    canvas.drawRect(Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height),
      Paint()..color = const Color(0xFF2C2C2C));
  }
  @override bool shouldRepaint(_) => false;
}

class _CirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawPath(path, Paint()..color = const Color(0xFF2C2C2C));
    canvas.restore();
  }
  @override bool shouldRepaint(_) => false;
}

class _HexaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * 3.1416 / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    final clip = Path()..addPath(path, Offset.zero);
    canvas.save();
    canvas.clipPath(clip);
    final dark = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(dark, Paint()..color = const Color(0xFF2C2C2C));
    canvas.restore();
  }
  @override bool shouldRepaint(_) => false;
}

class _NoBanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - paint.strokeWidth / 2;
    canvas.drawCircle(c, r, paint);
    canvas.drawLine(
      Offset(c.dx + r * cos(2.356), c.dy + r * sin(2.356)),
      Offset(c.dx + r * cos(5.498), c.dy + r * sin(5.498)),
      paint,
    );
  }
  @override bool shouldRepaint(_) => false;
}
