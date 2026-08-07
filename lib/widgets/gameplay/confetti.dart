import 'package:flutter/material.dart';
import 'dart:math' as math;

class ConfettiParticle {
  double x, y, vx, vy, size, rotation, rotSpeed;
  Color color;
  ConfettiParticle(this.x, this.y, this.vx, this.vy, this.size, this.rotation, this.rotSpeed, this.color);
}

class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({required this.onDone});
  final VoidCallback onDone;
  @override
  State<ConfettiOverlay> createState() => ConfettiOverlayState();
}

class ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<ConfettiParticle> _particles;
  final _rng = math.Random();

  static const _colors = [
    Color(0xFFFFD465), Color(0xFF7BD957), Color(0xFF5865F2),
    Color(0xFFFF6B35), Color(0xFF4CAF50), Color(0xFFE91E63),
  ];

  @override
  void initState() {
    super.initState();
    _particles = List.generate(80, (_) => ConfettiParticle(
      _rng.nextDouble(),
      -0.05 - _rng.nextDouble() * 0.15,
      (_rng.nextDouble() - 0.5) * 0.006,
      0.008 + _rng.nextDouble() * 0.012,
      6 + _rng.nextDouble() * 8,
      _rng.nextDouble() * math.pi * 2,
      (_rng.nextDouble() - 0.5) * 0.15,
      _colors[_rng.nextInt(_colors.length)],
    ));
    _ctrl = AnimationController(duration: const Duration(milliseconds: 2800), vsync: this)
      ..addListener(() => setState(() {
        for (final p in _particles) {
          p.x += p.vx;
          p.y += p.vy;
          p.vy += 0.0002;
          p.rotation += p.rotSpeed;
        }
        _particles.removeWhere((p) => p.y > 1.15);
        if (_particles.isEmpty) { _ctrl.stop(); widget.onDone(); }
      }))
      ..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: ConfettiPainter(_particles, size),
        ),
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final Size screen;
  ConfettiPainter(this.particles, this.screen);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.rotation);
      paint.color = p.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
          const Radius.circular(2)),
        paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => true;
}

