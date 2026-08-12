// ===== FILE: lib/widgets/moderation/leaderboard_ban_sheet.dart =====
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/widgets/shared/folds_dialog.dart';

const List<String> kBanReasons = [
  'Suspicious / impossible XP',
  'Inappropriate username',
  'Inappropriate avatar',
  'Harassment or abuse',
  'Other',
];

Future<void> showLeaderboardBanSheet(
  BuildContext context, {
  required String username,
  bool isCurrentlyBanned = false,
  VoidCallback? onDone,
}) async {
  if (isCurrentlyBanned) {
    await showFoldsDialog(context,
      title: 'Lift Leaderboard Ban?',
      message: '$username will reappear on public leaderboards and their profile sheet will be visible again.',
      icon: Icons.shield_rounded,
      iconColor: const Color(0xFF4CAF50),
      actions: [
        FoldsDialogAction(label: 'Cancel', onTap: () {}),
        FoldsDialogAction(label: 'Lift Ban', isPrimary: true, color: const Color(0xFF4CAF50), onTap: () async {
          try {
            await Supabase.instance.client.rpc('leaderboard_unban_user', params: {'target_username': username});
          } catch (_) {}
          onDone?.call();
        }),
      ],
    );
    return;
  }

  String? selectedReason;
  final detailsCtrl = TextEditingController();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: StatefulBuilder(builder: (context, setSheetState) {
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.leaderboard_rounded, color: Colors.red)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Leaderboard Ban', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(username, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w700)),
              ])),
            ]),
            const SizedBox(height: 8),
            Text('This hides their profile from public leaderboards and profile sheets. It does NOT affect their ability to play.',
              style: GoogleFonts.dmSans(fontSize: 12.5, color: Colors.black45, height: 1.4)),
            const SizedBox(height: 18),
            Text('REASON', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: kBanReasons.map((r) {
              final selected = selectedReason == r;
              return GestureDetector(
                onTap: () => setSheetState(() => selectedReason = r),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(r, style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.black54)),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),
            TextField(
              controller: detailsCtrl,
              maxLines: 3,
              style: GoogleFonts.dmSans(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Add details (optional but recommended)...',
                filled: true, fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: selectedReason == null ? null : () async {
                final reason = detailsCtrl.text.trim().isEmpty
                    ? selectedReason!
                    : '$selectedReason: ${detailsCtrl.text.trim()}';
                Navigator.pop(sheetCtx);
                try {
                  await Supabase.instance.client.rpc('leaderboard_ban_user',
                    params: {'target_username': username, 'reason': reason});
                  onDone?.call();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('$username has been leaderboard banned.', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFF2C2C2C), behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                  }
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              },
              child: Opacity(
                opacity: selectedReason == null ? 0.4 : 1,
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text('CONFIRM BAN', style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5))),
                ),
              ),
            ),
          ]);
        }),
      ),
    ),
  );
}