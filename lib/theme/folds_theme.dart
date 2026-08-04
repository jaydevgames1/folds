import 'package:flutter/material.dart';


class FoldsTheme {
  static bool get isChristmasDay {
    final now = DateTime.now();
    return now.month == 12 && now.day == 25;
  }

  static bool get isHolidaySeason {
    final now = DateTime.now();
    return now.month == 12 && now.day >= 10 && now.day <= 30;
  }

  static bool isHolidayPuzzle(String id) =>
      isChristmasDay || (isHolidaySeason && id.startsWith('x'));

  // Tile colours
  static Color cellDark(String id) =>
      isHolidayPuzzle(id) ? const Color.fromARGB(255, 219, 14, 14) : const Color(0xFF2C2C2C);

  static Color cellLight(String id) =>
      isHolidayPuzzle(id) ? const Color.fromARGB(255, 21, 223, 35) : Colors.white;

  // Grid container background
  static Color gridBg(String id) =>
      isHolidayPuzzle(id) ? const Color(0xFF0D1A0D) : const Color(0xFFE8E8E8);

  // Scaffold background
  static Color scaffoldBg(String id) {
    if (isChristmasDay) return const Color(0xFFFFF5F5);
    if (isHolidaySeason && id.startsWith('x')) return const Color(0xFFF5FFF5);
    return Colors.white;
  }

  static bool hasWinterBg(String id) => isHolidayPuzzle(id);
}

