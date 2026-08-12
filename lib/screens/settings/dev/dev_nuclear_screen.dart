// ===== FILE: lib/screens/settings/dev/dev_nuclear_screen.dart =====
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/widgets/shared/folds_dialog.dart';
import 'dev_widgets.dart';

class DevNuclearScreen extends StatelessWidget {
  const DevNuclearScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DevSectionScaffold(
      title: 'Nuclear', accent: const Color(0xFFB71C1C), icon: Icons.warning_amber_rounded,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('These reset YOUR account only, immediately, no undo.',
            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.red.shade400, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          DevPrimaryButton(label: 'Reset ALL Progress', color: Colors.red, icon: Icons.delete_forever_rounded, onTap: () {
            showFoldsDialog(context, title: 'Reset everything?',
              message: 'XP, completed puzzles, achievements — all gone.',
              icon: Icons.warning_amber_rounded, iconColor: Colors.red,
              actions: [
                FoldsDialogAction(label: 'Cancel', onTap: () {}),
                FoldsDialogAction(label: 'Confirm', isPrimary: true, color: Colors.red, onTap: () async {
                  await AppStore.resetProgress();
                  devToast(context, 'Progress wiped');
                }),
              ]);
          }),
          const SizedBox(height: 10),
          DevPrimaryButton(label: 'Reset All Settings', color: Colors.orange.shade700, icon: Icons.settings_backup_restore_rounded, onTap: () {
            showFoldsDialog(context, title: 'Reset settings?',
              message: 'All app settings return to defaults.',
              icon: Icons.warning_amber_rounded, iconColor: Colors.orange,
              actions: [
                FoldsDialogAction(label: 'Cancel', onTap: () {}),
                FoldsDialogAction(label: 'Confirm', isPrimary: true, color: Colors.orange.shade700, onTap: () async {
                  await AppStore.resetSettings();
                  devToast(context, 'Settings reset');
                }),
              ]);
          }),
        ])),
      ]),
    );
  }
}