import 'package:flutter/material.dart';

class PixelTexturePainter extends CustomPainter {
  final Color color;
  final bool retro;
  PixelTexturePainter({required this.color, required this.retro});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = color);
    const blocks = 5;
    final blockSize = size.width / blocks;
    final hsl = HSLColor.fromColor(color);
    for (int r = 0; r < blocks; r++) {
      for (int c = 0; c < blocks; c++) {
        final shade = (r + c) % 2 == 0
            ? hsl.withLightness((hsl.lightness + 0.06).clamp(0.0, 1.0)).toColor()
            : hsl.withLightness((hsl.lightness - 0.06).clamp(0.0, 1.0)).toColor();
        canvas.drawRect(Rect.fromLTWH(c * blockSize, r * blockSize, blockSize, blockSize),
          Paint()..color = shade.withValues(alpha: retro ? 0.35 : 0.22));
      }
    }
    if (retro) {
      final scanline = Paint()..color = Colors.black.withValues(alpha: 0.10);
      for (double y = 0; y < size.height; y += 4) {
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.4), scanline);
      }
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.black.withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(covariant PixelTexturePainter old) => old.color != color || old.retro != retro;
}

class WoodTexturePainter extends CustomPainter {
  final Color color;
  WoodTexturePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = color);
    final grain = Paint()..color = Colors.black.withValues(alpha: 0.08)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (double y = 6; y < size.height; y += 7) {
      final path = Path()..moveTo(0, y);
      path.quadraticBezierTo(size.width / 2, y + 4, size.width, y);
      canvas.drawPath(path, grain);
    }
  }

  @override
  bool shouldRepaint(covariant WoodTexturePainter old) => old.color != color;
}