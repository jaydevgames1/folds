// ===== FILE: lib/screens/settings/dev/dev_widgets.dart =====
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DevToolCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const DevToolCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  @override
  State<DevToolCard> createState() => DevToolCardState();
}

class DevToolCardState extends State<DevToolCard> {
  double _scale = 1;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale, duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [widget.color, widget.color.withValues(alpha: 0.75)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(widget.icon, color: Colors.white, size: 30),
            const Spacer(),
            Text(widget.title, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2),
            Text(widget.subtitle, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
          ]),
        ),
      ),
    );
  }
}

class DevSectionScaffold extends StatelessWidget {
  final String title;
  final Color accent;
  final IconData icon;
  final Widget child;
  const DevSectionScaffold({required this.title, required this.accent, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context)),
                const Spacer(),
              ]),
              Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: Colors.white, size: 22)),
                const SizedBox(width: 12),
                Text(title, style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ]),
          ),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

class DevCard extends StatelessWidget {
  final Widget child;
  const DevCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(18)),
    child: child,
  );
}

class DevPrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final IconData? icon;
  const DevPrimaryButton({required this.label, required this.onTap, this.color = const Color(0xFF2C2C2C), this.icon});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 8)],
          Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
        ])),
      ),
    ),
  );
}

class DevChipBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const DevChipBtn({required this.label, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: color ?? const Color(0xFFEAEAEA), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700,
        color: color != null ? Colors.white : Colors.black87)),
    ),
  );
}

void devToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
    backgroundColor: error ? Colors.red : const Color(0xFF2C2C2C),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ));
}