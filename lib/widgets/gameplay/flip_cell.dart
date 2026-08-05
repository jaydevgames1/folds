import 'package:flutter/material.dart';
import 'package:folds/painters/badge_painters.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/painters/texture_painters.dart';

class FlipCell extends StatefulWidget {
  final bool isBlack;
  final String? linkShape;
  final VoidCallback onTap;
  final bool isHoliday;
  const FlipCell({required this.isBlack, this.linkShape, required this.onTap, this.isHoliday = false});
  @override
  State<FlipCell> createState() => FlipCellState();
  
}


class FlipCellState extends State<FlipCell> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showingBlack = false;
  
  @override
  void initState() {
    super.initState();
    _showingBlack = widget.isBlack;
    _controller = AnimationController(duration: const Duration(milliseconds: 140), vsync: this);
  }

  @override
  void didUpdateWidget(FlipCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBlack != widget.isBlack && !_controller.isAnimating) {
      _controller.forward(from: 0).then((_) {
        if (mounted) {
          setState(() => _showingBlack = widget.isBlack);
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    widget.onTap();
    _controller.forward(from: 0).then((_) {
      setState(() => _showingBlack = !_showingBlack);
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * 3.1416 / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(angle),
            child: Stack(
                  children: [
                    TexturedTileFace(isBlack: _showingBlack, isHoliday: widget.isHoliday),
                if (widget.linkShape != null)
                  Positioned(
                    top: 3, right: 3,
                    child: LinkBadge(shape: widget.linkShape!, onBlack: _showingBlack),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}


class TexturedTileFace extends StatelessWidget {
  final bool isBlack;
  final bool isHoliday;
  const TexturedTileFace({required this.isBlack, required this.isHoliday});

  Color get _baseColor => isBlack
      ? (isHoliday ? const Color.fromARGB(255, 226, 10, 10) : const Color(0xFF2C2C2C))
      : (isHoliday ? const Color.fromARGB(255, 11, 235, 26) : Colors.white);

  @override
  Widget build(BuildContext context) {
    switch (AppStore.activeTexturePack) {
      case 'pixel8':
        return ClipRRect(borderRadius: BorderRadius.circular(10),
          child: CustomPaint(painter: PixelTexturePainter(color: _baseColor, retro: false), child: const SizedBox.expand()));
      case 'retroPixel':
        return ClipRRect(borderRadius: BorderRadius.circular(10),
          child: CustomPaint(painter: PixelTexturePainter(color: _baseColor, retro: true), child: const SizedBox.expand()));
      case 'neon':
        return Container(
          decoration: BoxDecoration(
            color: _baseColor, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isBlack ? const Color(0xFF00E5FF) : const Color(0xFFFF2FD6), width: 2),
            boxShadow: [BoxShadow(
              color: (isBlack ? const Color(0xFF00E5FF) : const Color(0xFFFF2FD6)).withValues(alpha: 0.55),
              blurRadius: 10, spreadRadius: 1)],
          ),
        );
      case 'wood':
        return ClipRRect(borderRadius: BorderRadius.circular(10),
          child: CustomPaint(painter: WoodTexturePainter(color: _baseColor), child: const SizedBox.expand()));
      default:
        return Container(decoration: BoxDecoration(color: _baseColor, borderRadius: BorderRadius.circular(10)));
    }
  }
}

