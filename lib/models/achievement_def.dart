import 'package:flutter/material.dart';

class AchievementDef {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  const AchievementDef(this.id, this.title, this.description, this.icon);
}

const appAchievements = [
  // ── GETTING STARTED
  AchievementDef('first_fold', 'First Fold', 'Complete your very first puzzle.', Icons.check_circle_outline_rounded),

  // ── PUZZLES COMPLETED (tiered)
  AchievementDef('novice_folder', 'Novice Folder', 'Complete 10 puzzles.', Icons.check_circle_outline_rounded),
  AchievementDef('adept_folder', 'Adept Folder', 'Complete 50 puzzles.', Icons.check_circle_outline_rounded),
  AchievementDef('expert_folder', 'Expert Folder', 'Complete 150 puzzles.', Icons.check_circle_outline_rounded),
  AchievementDef('master_folder', 'Master Folder', 'Complete 300 puzzles.', Icons.check_circle_outline_rounded),

  // ── PAR MASTERY (tiered)
  AchievementDef('par_10', 'Sharp Mind', 'Solve 10 puzzles at or under par.', Icons.star_rounded),
  AchievementDef('par_50', 'Precision Folder', 'Solve 50 puzzles at or under par.', Icons.star_rounded),
  AchievementDef('par_150', 'Par Legend', 'Solve 150 puzzles at or under par.', Icons.star_rounded),

  // ── STREAKS (tiered)
  AchievementDef('streak_7', 'Week Warrior', 'Reach a 7-day streak.', Icons.local_fire_department_rounded),
  AchievementDef('streak_30', 'Monthly Master', 'Reach a 30-day streak.', Icons.local_fire_department_rounded),
  AchievementDef('streak_100', 'Centurion', 'Reach a 100-day streak.', Icons.local_fire_department_rounded),
  AchievementDef('streak_365', 'Year of Folds', 'Reach a 365-day streak.', Icons.local_fire_department_rounded),

  // ── IN A DAY
  AchievementDef('folding_frenzy', 'Folding Frenzy', 'Complete 10 puzzles in a single day.', Icons.flash_on_rounded),

  // ── GRID SIZE
  AchievementDef('grid_master', 'Grid Master', 'Complete a 6×6 puzzle.', Icons.grid_on_rounded),

  // ── FLIPS (tiered)
  AchievementDef('flippin_crazy', "Flippin' Crazy", 'Flip a total of 100 cells.', Icons.touch_app_rounded),
  AchievementDef('flipaholic', 'Flipaholic', 'Flip a total of 250 cells.', Icons.touch_app_rounded),
  AchievementDef('addicted_to_flipping', 'Addicted to Flipping', 'Flip a total of 500 cells.', Icons.touch_app_rounded),
  AchievementDef('flip_god', 'Flip God', 'Flip a total of 1,000 cells.', Icons.touch_app_rounded),

  // ── SKILL
  AchievementDef('flawless', 'Flawless Logic', 'Solve a puzzle in the exact par amount of moves.', Icons.lightbulb_outline_rounded),
  AchievementDef('speed_demon', 'Speed Demon', 'Solve a puzzle in under 15 seconds.', Icons.timer_rounded),

  // ── SHADOW
  AchievementDef('exterminator', 'Exterminator', 'Report a bug to the Folds team.', Icons.bug_report_rounded),
  AchievementDef('build', 'Architect', 'Get a puzzle featured in the game.', Icons.architecture_rounded),
  AchievementDef('just_in_case', 'Just In Case', 'Download all puzzles for offline play.', Icons.cloud_download_rounded),
  AchievementDef('night_owl', 'Night Owl', 'Solve a puzzle between 2AM and 4AM.', Icons.nightlight_round),
  AchievementDef('early_bird', 'Early Bird', 'Complete the daily puzzle before 6AM.', Icons.wb_twilight_rounded),
  AchievementDef('one_more', 'So Close', 'Solve a puzzle in exactly one move over par.', Icons.exposure_plus_1_rounded),
  AchievementDef('comeback_kid', 'Comeback Kid', 'Solve at par a puzzle you\'d previously failed.', Icons.replay_circle_filled_rounded),
  AchievementDef('perfectionist', 'Perfectionist', 'Solve 10 puzzles in a row at or under par.', Icons.diamond_rounded),
  AchievementDef('beta_tester', 'Beta Tester', 'Played Folds before its official launch.', Icons.science_rounded),
  AchievementDef('chosen_one', 'The Chosen One', 'Hand-picked by the developer. Extremely rare.', Icons.auto_awesome_rounded),
];

