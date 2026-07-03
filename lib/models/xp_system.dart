
import 'package:flutter/material.dart';

class XPSystem {
  static final List<int> thresholds = _build();
  
  static List<int> _build() {
    final t = <int>[0];
    for (final s in [100,150,200,250,300,400,500,600,700,800,900,1000]) {
      t.add(t.last + s);
    }
    for (int i = 0; i < 5; i++) t.add(t.last + 200);   // R11-15
    for (int i = 0; i < 5; i++) t.add(t.last + 200);   // R16-20
    for (int i = 0; i < 5; i++) t.add(t.last + 250);   // R21-25
    for (int i = 0; i < 5; i++) t.add(t.last + 250);   // R26-30
    for (int i = 0; i < 10; i++) t.add(t.last + 500);  // R31-40
    while (t.last < 20000) t.add(t.last + 1000);
    return t;
  }

  static int rankFromXP(int xp) {
    int rank = 0;
    for (int i = 1; i < thresholds.length; i++) {
      if (xp >= thresholds[i]) rank = i; else break;
    }
    if (rank == thresholds.length - 1 && xp >= thresholds.last) {
      final overflowXP = xp - thresholds.last;
      rank += (overflowXP ~/ 1000); 
    }
    return rank;
    
  }

  static int xpForRank(int rank) {
    // If within the normal list, return the exact threshold
    if (rank < thresholds.length) return thresholds[rank];
    
    // THE FIX: Dynamically calculate the baseline for infinite ranks
    final overflowRanks = rank - (thresholds.length - 1);
    return thresholds.last + (overflowRanks * 1000);
  }
  


  static int xpForNextRank(int rank) {
    
    return xpForRank(rank + 1);
  }

  static double progressInRank(int xp) {
    final rank = rankFromXP(xp);
    final lo = xpForRank(rank).toDouble();
    final hi = xpForNextRank(rank).toDouble();
    if (hi <= lo) return 1.0;
    return ((xp - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  // XP table per difficulty (1-5 stars)
  static const _par      = [15, 25, 35, 50, 75];
  static const _overPar  = [10, 15, 20, 30, 40];
  static const _afterPar = [0,   0,  5, 10, 15];

  static int calculate({
    required int difficulty,
    required int moves,
    required int par,
    required bool hasFailed,
  }) {
    final d = (difficulty - 1).clamp(0, 4);
    if (moves <= par) {
      return hasFailed ? _afterPar[d] : _par[d];
    }
    if (moves <= par * 2) return _overPar[d];
    return 0;
  }

  static Color shieldColor(int rank) {
    if (rank >= 40) return const Color(0xFFE715AC);
    if (rank >= 30) return const Color(0xFFFFD465);
    if (rank >= 20) return const Color(0xFF7BD957);
    if (rank >= 10) return const Color(0xFF5865F2);
    return const Color(0xFFC17A36);
  }
}
