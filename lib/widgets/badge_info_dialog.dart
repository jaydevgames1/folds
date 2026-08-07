import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/main.dart';

void showBadgeInfoDialog(BuildContext context, {required String username, required bool isDev, DateTime? modSince}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Row(children: [
        Icon(isDev ? Icons.code_rounded : Icons.shield_rounded,
          color: isDev ? const Color(0xFF5865F2) : const Color(0xFFFFD465)),
        const SizedBox(width: 10),
        Expanded(child: Text('$username is a ${isDev ? 'Developer' : 'Moderator'}',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 17))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          isDev
            ? 'Developers built Folds from the ground up. There\'s only one.'
            : 'Moderators are trusted community members hand-picked to help keep Folds friendly and fair.',
          style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54)),
        if (!isDev && modSince != null) ...[
          const SizedBox(height: 10),
          Text('Mod since ${formatFullDate(modSince)}',
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Close', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ModsAndDevsScreen()));
          },
          child: Text('Learn More', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ],
    ),
  );
}


String formatFullDate(DateTime dt) {
  const months = ['','January','February','March','April','May','June',
      'July','August','September','October','November','December'];
  return '${ordinal(dt.day)} ${months[dt.month]}';
}

String ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  switch (day % 10) {
    case 1: return '${day}st';
    case 2: return '${day}nd';
    case 3: return '${day}rd';
    default: return '${day}th';
  }
}