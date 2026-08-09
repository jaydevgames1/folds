import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/models/achievement_def.dart';

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p4 = AppStore.completedInRange('p', 0, 50);
    final p6 = AppStore.completedInRange('p', 50, 30);
    final p8 = AppStore.completedInRange('p', 80, 20);
    final rect = AppStore.completedInRange('r', 0, 100);
    final holiday = AppStore.completedInRange('x', 0, 25);
    final dailies = AppStore.dailiesCompleted;
    final totalPar = AppStore.parPuzzles.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          StatSectionLabel('OVERVIEW'),
          StatRowItem(label: 'Total Solved', value: '${AppStore.puzzlesCompleted + dailies}'),
          StatRowItem(label: 'Solved at Par ★', value: '$totalPar'),
          StatRowItem(label: 'Daily Folds', value: '$dailies'),
          StatRowItem(label: 'Current Streak', value: '${AppStore.currentStreak} 🔥'),
          StatRowItem(label: 'Total Cells Flipped', value: '${AppStore.totalFlips}'),
          const SizedBox(height: 8),
          StatSectionLabel('PILOT PACK'),
          StatPackRow(label: '4×4', done: p4, total: 50),
          StatPackRow(label: '6×6', done: p6, total: 30),
          StatPackRow(label: '8×8', done: p8, total: 20),
          const SizedBox(height: 8),
          StatSectionLabel('RECTANGLE PACK'),
          StatPackRow(label: 'Rectangle', done: rect, total: 100),
          if (!DateTime.now().isBefore(DateTime(2026, 12, 10))) ...[
            const SizedBox(height: 8),
            StatSectionLabel('HOLIDAY PACK'),
            StatPackRow(label: 'Holiday', done: holiday, total: 25),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class StatSectionLabel extends StatelessWidget {
  final String text;
  const StatSectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(text, style: GoogleFonts.dmSans(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: Colors.black38, letterSpacing: 1.2)),
  );
}

class StatPackRow extends StatelessWidget {
  final String label;
  final int done;
  final int total;
  const StatPackRow({required this.label, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? done / total : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700)),
              Text('$done / $total', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1.0 ? const Color(0xFF4CAF50) : const Color(0xFFFFD465)),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

class StatRowItem extends StatelessWidget {
  final String label;
  final String value;
  const StatRowItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
          Text(value, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black)),
        ],
      ),
    );
  }
}

class AchievementsTab extends StatelessWidget {
  const AchievementsTab({super.key});

  static const _categories = [
    ('GETTING STARTED', ['first_fold', 'folding_frenzy']),
    ('PUZZLES COMPLETED', ['novice_folder', 'adept_folder', 'expert_folder', 'master_folder']),
    ('PAR MASTERY', ['par_10', 'par_50', 'par_150']),
    ('STREAKS', ['streak_7', 'streak_30', 'streak_100', 'streak_365']),
    ('GRID SIZE', ['grid_master']),
    ('FLIPS', ['flippin_crazy', 'flipaholic', 'addicted_to_flipping', 'flip_god']),
    ('SKILL', ['flawless', 'speed_demon']),
    ('SHADOW', ['exterminator', 'build', 'just_in_case', 'night_owl', 'early_bird',
                'one_more', 'comeback_kid', 'perfectionist', 'beta_tester', 'chosen_one']),
  ];

  @override
  Widget build(BuildContext context) {
    final unlocked = appAchievements.where((a) => AppStore.isUnlocked(a.id)).length;
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        // Progress header
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Text('$unlocked / ${appAchievements.length} Unlocked',
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(width: 80, child: LinearProgressIndicator(
                value: appAchievements.isEmpty ? 0 : unlocked / appAchievements.length,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD465)),
                minHeight: 6,
              )),
            ),
          ]),
        ),
        for (final cat in _categories) ...[
          AchievementSection(label: cat.$1, ids: cat.$2),
        ],
      ],
    );
  }
}

class AchievementSection extends StatelessWidget {
  final String label;
  final List<String> ids;
  const AchievementSection({required this.label, required this.ids});

  @override
  Widget build(BuildContext context) {
    final defs = ids.map((id) => appAchievements.firstWhere(
      (a) => a.id == id, orElse: () => AchievementDef(id, id, '', Icons.star))).toList();
    final isShadow = label == 'SHADOW';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(children: [
          Text(label, style: GoogleFonts.dmSans(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: isShadow ? const Color(0xFF5865F2) : Colors.black38, letterSpacing: 1.2)),
          if (isShadow) ...[
            const SizedBox(width: 6),
            const Icon(Icons.lock_rounded, size: 10, color: Color(0xFF5865F2)),
          ],
        ]),
      ),
      ...defs.map((def) {
        final isUnlocked = AppStore.isUnlocked(def.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUnlocked
                ? (isShadow ? const Color(0xFF3C3F8F) : const Color(0xFF2C2C2C))
                : const Color(0xFFEFEFEF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? (isShadow
                        ? const Color(0xFF5865F2).withValues(alpha: 0.2)
                        : const Color(0xFFFFD465).withValues(alpha: 0.15))
                    : Colors.black12,
                borderRadius: BorderRadius.circular(12)),
              child: Icon(def.icon,
                color: isUnlocked
                    ? (isShadow ? const Color(0xFF99AAFF) : const Color(0xFFFFD465))
                    : Colors.black26,
                size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(def.title, style: GoogleFonts.dmSans(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: isUnlocked ? Colors.white : Colors.black45)),
              const SizedBox(height: 2),
              Text(def.description, style: GoogleFonts.dmSans(
                fontSize: 12, color: isUnlocked ? Colors.white54 : Colors.black38)),
            ])),
            if (isUnlocked)
              const Icon(Icons.check_rounded, color: Color(0xFF4CAF50), size: 18),
          ]),
        );
      }),
      const SizedBox(height: 6),
    ]);
  }
}

