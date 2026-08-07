import'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AchievementToast extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onDone;

  const AchievementToast({
    required this.title,
    required this.description,
    required this.icon,
    required this.onDone,
  });

  @override
  State<AchievementToast> createState() => AchievementToastState();
}

class AchievementToastState extends State<AchievementToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 420), vsync: this);
    _slide = Tween<double>(begin: -60, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.4)));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Positioned(
        top: topPad + 12 + _slide.value,
        left: 20, right: 20,
        child: Opacity(
          opacity: _fade.value,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD465).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12)),
                    child: Icon(widget.icon, color: const Color(0xFFFFD465), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Achievement Unlocked!', style: GoogleFonts.dmSans(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFD465), letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text(widget.title, style: GoogleFonts.dmSans(
                        fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(widget.description, style: GoogleFonts.dmSans(
                        fontSize: 12, color: Colors.white54)),
                    ],
                  )),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

