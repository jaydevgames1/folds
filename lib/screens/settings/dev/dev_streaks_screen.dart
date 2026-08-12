// ===== FILE: lib/screens/settings/dev/dev_streaks_screen.dart =====
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/core/constants.dart';
import 'dev_widgets.dart';

class DevStreaksScreen extends StatelessWidget {
  const DevStreaksScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DevSectionScaffold(
      title: 'Streaks', accent: const Color(0xFFFF8A3D), icon: Icons.local_fire_department_rounded,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Current streak: ${AppStore.currentStreak} 🔥', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            DevChipBtn(label: 'Set to 7', onTap: () { AppStore.devSetStreak(7); devToast(context, 'Streak set to 7'); }),
            DevChipBtn(label: 'Set to 30', onTap: () { AppStore.devSetStreak(30); devToast(context, 'Streak set to 30'); }),
            DevChipBtn(label: 'Set to 100', onTap: () { AppStore.devSetStreak(100); devToast(context, 'Streak set to 100'); }),
            DevChipBtn(label: 'Reset', color: Colors.red.shade400, onTap: () { AppStore.devResetStreak(); devToast(context, 'Streak reset'); }),
          ]),
        ])),
        DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today\'s daily puzzle', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          DevPrimaryButton(label: 'Mark Today Done', color: const Color(0xFFFF8A3D), icon: Icons.check_rounded, onTap: () {
            final dayNumber = foldsDayNumberFor(DateTime.now());
            if (dayNumber > 0) {
              AppStore.markCompleted('d$dayNumber');
              AppStore.updateStreak();
              devToast(context, 'Day $dayNumber marked done, streak updated');
            } else {
              devToast(context, 'Folds hasn\'t launched yet (day $dayNumber)', error: true);
            }
          }),
        ])),
      ]),
    );
  }
}