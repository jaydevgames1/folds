import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A single action button on a FoldsDialog.
class FoldsDialogAction {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? color;
  const FoldsDialogAction({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.color,
  });
}

/// Drop-in replacement for showDialog(builder: (_) => AlertDialog(...)).
/// Not a full-screen takeover, not a snackbar — a small, quiet centered card.
///
/// Usage:
///   showFoldsDialog(context,
///     title: 'Reset Progress?',
///     message: 'This wipes all XP, completed puzzles, and rank.',
///     icon: Icons.warning_amber_rounded,
///     iconColor: Colors.red,
///     actions: [
///       FoldsDialogAction(label: 'Cancel', onTap: () {}),
///       FoldsDialogAction(label: 'Reset', isPrimary: true, color: Colors.red,
///         onTap: () { /* do the reset */ }),
///     ],
///   );
Future<T?> showFoldsDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  required List<FoldsDialogAction> actions,
  IconData? icon,
  Color? iconColor,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: (iconColor ?? const Color(0xFF2C2C2C)).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor ?? const Color(0xFF2C2C2C), size: 26),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.black),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.4),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: 14),
              content,
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                for (final a in actions)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: a == actions.last ? 0 : 8),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          a.onTap();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: a.isPrimary ? (a.color ?? const Color(0xFF2C2C2C)) : const Color(0xFFEFEFEF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              a.label,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: a.isPrimary ? Colors.white : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// A tiny full-screen transition shown while auth state is switching
/// (signing in / signing out). Prevents the "flash of stale state" bug.
class AuthTransitionScreen extends StatelessWidget {
  final String message;
  const AuthTransitionScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2C2C2C)),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
