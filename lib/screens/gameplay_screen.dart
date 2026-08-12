import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:folds/main.dart';
import 'package:folds/core/constants.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/state/app_settings.dart';
import 'package:folds/services/audio_service.dart';
import 'package:folds/theme/folds_theme.dart';
import 'package:folds/models/xp_system.dart';
import 'package:folds/models/achievement_def.dart';
import 'package:folds/painters/icon_painters.dart';
import 'package:folds/widgets/shared/misc.dart';
import 'package:folds/widgets/gameplay/flip_cell.dart';
import 'package:folds/widgets/gameplay/fold_complete_animator.dart';
import 'package:folds/widgets/gameplay/achievement_toast.dart';
import 'package:folds/widgets/gameplay/confetti.dart';
import 'package:folds/screens/puzzles/pack_cards.dart';
import 'package:folds/screens/puzzles/puzzles_menu_screen.dart';
import 'package:folds/screens/store/store_screen.dart';
import 'package:folds/screens/settings/settings_screen.dart';
import 'package:folds/screens/profile/profile_screen.dart';
import 'package:folds/screens/social/credits_screen.dart';
import 'package:folds/screens/social/socials_screen.dart';
import 'leaderboard_screen.dart';
import 'package:folds/widgets/gameplay/game_over_crack.dart';
import 'package:folds/services/audio_service.dart';


// ─────────────────────────────────────────────────────────────────────────────
// GAMEPLAY SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class GameplayScreen extends StatefulWidget {
  final String? initialPuzzleId; // Null defaults to daily
  const GameplayScreen({super.key, this.initialPuzzleId});
  @override
  State<GameplayScreen> createState() => GameplayScreenState();
}

class GameplayScreenState extends State<GameplayScreen> {
  bool _menuOpen = false;
  bool _menuVisible = false;
  bool _paused = false;
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _timeDisplay = '00:00';
  List<bool> _cells = List.filled(16, false);
  int _gridSize = 4;
  int _gridRows = 4;
  int _gridCols = 4;
  String _title = '';
  String _author = '';
  int _difficulty = 1;
  String _id = '';
  int _par = 5;
  int _moves = 0;
  int _earnedXP = 0;
  bool _loaded = false;
  bool _loading = true;
  bool _notFound = false;
  bool _solved = false;
  bool _skipAnimation = false;
  bool _gameOver = false;
  bool _hideXPOnComplete = false;
  Map<String, dynamic>? _lastResponse; // cache so Retry never needs a network round-trip
  String _requestedId = 'p1'; // what was actually asked for — used by the Not Found screen's Retry

  List<List<int>> _linkGroups = []; // each group: list of cell indices that flip together
  Map<int, String> _linkShapeByIndex = {}; // index -> shape name, for rendering the badge

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _startTimer();
    AudioService.startMusic();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialPuzzleId != null) {
        _requestedId = widget.initialPuzzleId!;
        _loadPuzzle(widget.initialPuzzleId!);
        return;
      }
      // Try to load the latest daily puzzle
      // Day 1 = November 1, 2026. Calculate today's puzzle number.
      final dayNumber = foldsDayNumberFor(DateTime.now());

      if (dayNumber < 1) {
        // Pre-launch: show a preview puzzle
        _loadPuzzle('p1');
      } else {
        final dailyId = 'd$dayNumber';
        try {
          final exists = await Supabase.instance.client
              .from('puzzles')
              .select('id')
              .eq('id', dailyId)
              .maybeSingle();
          if (exists != null) {
            _requestedId = dailyId;
            _loadPuzzle(dailyId);
          } else {
            // Today's puzzle not uploaded yet — load most recent available daily
            final fallback = await Supabase.instance.client
                .from('puzzles')
                .select('id')
                .ilike('id', 'd%')
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();
            _requestedId = fallback?['id'] ?? 'p1';
            _loadPuzzle(_requestedId);
          }
        } catch (e) {
          _requestedId = 'p1';
          _loadPuzzle('p1');
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
    AudioService.stopMusic();
  }

  void _showConfetti() {
    if (!mounted) return;
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (_) => ConfettiOverlay(onDone: () => entry?.remove()),
    );
    Overlay.of(context).insert(entry);
  }

  final _toastQueue = <String>[];
  bool _toastShowing = false;

  void _showAchievementToast(String id) {
    _toastQueue.add(id);
    if (!_toastShowing) _processNextToast();
  }

  void _processNextToast() {
    if (_toastQueue.isEmpty || !mounted) { _toastShowing = false; return; }
    _toastShowing = true;
    final id = _toastQueue.removeAt(0);
    final def = appAchievements.firstWhere(
      (a) => a.id == id,
      orElse: () => const AchievementDef('', '', '', Icons.star));
    if (def.id.isEmpty) { _toastShowing = false; _processNextToast(); return; }
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (ctx) => AchievementToast(
        title: def.title,
        description: def.description,
        icon: def.icon,
        onDone: () {
          entry?.remove();
          _toastShowing = false;
          Future.delayed(const Duration(milliseconds: 280), _processNextToast);
        },
      ),
    );
    Overlay.of(context).insert(entry);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      setState(() {
        _timeDisplay = _formatTime(_stopwatch.elapsedMilliseconds);
      });
    });
  }

  String _formatTime(int ms) {
    final minutes = (ms ~/ 60000).remainder(60).toString().padLeft(2, '0');
    final seconds = (ms ~/ 1000).remainder(60).toString().padLeft(2, '0');
    if (AppSettings.enableMs) {
      final hundredths = (ms ~/ 10).remainder(100).toString().padLeft(2, '0');
      return '$minutes:$seconds.$hundredths';
    }
    return '$minutes:$seconds';
  }

  void _resetTimer() {
    _stopwatch.reset();
    _stopwatch.start();
    _timer.cancel();
    _startTimer();
    setState(() => _timeDisplay = AppSettings.enableMs ? '00:00.00' : '00:00');
  }

Future<void> _loadPuzzle(String id, {bool forcePlay = false}) async {
    // Retrying the SAME puzzle we already have — reset instantly, no network
    // round-trip and no window where a stale, already-failed board is tappable.
    if (forcePlay && _lastResponse != null && _id == id) {
      _applyPuzzleData(_lastResponse!, resetOnly: true);
      return;
    }
    setState(() {
      if (!forcePlay) {
        _loading = true;
        _loaded = false; // hide the grid until fresh data lands
      }
      _notFound = false;
    });
    try {
      final offlineHit = AppStore.getOfflinePuzzle(id);
      final response = offlineHit ?? await Supabase.instance.client
          .from('puzzles')
          .select()
          .eq('id', id)
          .single()
          .timeout(const Duration(seconds:10));
      _lastResponse = response;
      await _applyPuzzleData(response);
    } catch (e) {
      debugPrint('❌ Supabase error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notFound = true;
        _loaded = false;
      });
    }
  }

  Future<void> _applyPuzzleData(Map<String, dynamic> response, {bool resetOnly = false}) async {
    final rawCells = (response['cells'] as List).map((e) => e == 1).toList();
    final cellCount = rawCells.length;
    final gridRows = (response['rows'] as int?) ?? sqrt(cellCount.toDouble()).toInt();
    final gridCols = (response['cols'] as int?) ?? sqrt(cellCount.toDouble()).toInt();
    final linksRaw = (response['links'] as List?) ?? [];
    final groups = <List<int>>[];
    final shapeMap = <int, String>{};
    for (final link in linksRaw) {
      final members = List<int>.from(link['members']);
      groups.add(members);
      for (final m in members) shapeMap[m] = link['shape'] as String;
    }
    String rawId = response['id'].toString();
    String displayTitle = response['title'];
    if (rawId.startsWith('d')) {
      displayTitle = '#${rawId.replaceAll(RegExp(r'[^0-9]'), '')} $displayTitle';
    }

    if (!resetOnly) {
  if (gridCols > gridRows) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
    // Let the physical rotation animation finish before the grid renders —
    // otherwise it briefly lays out against the old (portrait) constraints
    // and throws an overflow error the user can see.
    await Future.delayed(const Duration(milliseconds: 350));
  } else {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
  }
}

    setState(() {
      _cells = List<bool>.from(rawCells); // fresh copy every time — never re-uses the failed board
      _gridSize = gridRows;
      _gridRows = gridRows;
      _gridCols = gridCols;
      _title = displayTitle;
      _author = response['author'];
      _difficulty = response['difficulty'] as int;
      _id = rawId;
      _par = (response['par'] ?? 5) as int;
      _moves = 0;
      _loaded = true;
      _loading = false;
      _notFound = false;
      _solved = false;
      _gameOver = false; // ← this line is the actual fix for "double board"
      _linkGroups = groups;
      _linkShapeByIndex = shapeMap;
    });
  }

  bool _isSymmetrical() {
    for (int row = 0; row < _gridRows; row++) {
      for (int col = 0; col < _gridCols ~/ 2; col++) {
        final left = row * _gridCols + col;
        final right = row * _gridCols + (_gridCols - 1 - col);
        if (_cells[left] != _cells[right]) return false;
      }
    }
    return true;
  }

  // Returns display title — never exposes internal IDs
  String get _puzzleDisplayTitle {
    if (_id.startsWith('d')) {
      // Daily puzzle: show title as-is
      return _title;
    } else if (_id.startsWith('p')) {
      // Pilot pack: "Pilot #N"
      final n = _id.replaceAll(RegExp(r'^[a-z]+'), '');
      return 'Pilot #$n';
    } else if (_id.startsWith('r')) {
      final n = _id.replaceAll(RegExp(r'^[a-z]+'), '');
      return 'Rectangle #$n';
    }
    final n = _id.replaceAll(RegExp(r'^[a-z]+'), '');
    return '#$n $_title';
  }

  // Next puzzle in the same pack
  double get _symmetryProgress {
    if (_cells.isEmpty || _gridCols < 2) return 0;
    int matched = 0, total = 0;
    for (int row = 0; row < _gridRows; row++) {
      for (int col = 0; col < _gridCols ~/ 2; col++) {
        final left = row * _gridCols + col;
        final right = row * _gridCols + (_gridCols - 1 - col);
        if (_cells[left] == _cells[right]) matched++;
        total++;
      }
    }
    return total > 0 ? matched / total : 0;
  }

  String? get _nextPuzzleId {
    if (_id.startsWith('d')) return null; // dailies have no "next"
    final prefix = _id.replaceAll(RegExp(r'[0-9]'), '');
    final num = int.tryParse(_id.replaceAll(RegExp(r'[^0-9]'), ''));
    if (num == null) return null;
    final maxes = {'p': 100, 'r': 100, 'x': 25};
    final max = maxes[prefix] ?? 0;
    if (num >= max) return null;
    return '$prefix${num + 1}';
  }

  // Pack label for sharing
  String get _packPath {
    if (_id.startsWith('d')) return 'daily';
    if (_id.startsWith('p')) return 'pilot';
    if (_id.startsWith('r')) return 'rectangle';
    return 'puzzles';
  }

  // Puzzle number for sharing (never raw ID)
  String get _puzzleShareNumber {
    return _id.replaceAll(RegExp(r'^[a-z]+'), '');
  }

  void _handleCellTap(int index) {
    if (_paused || _solved) return;

    final toFlip = <int>{index};
    for (final group in _linkGroups) {
      if (group.contains(index)) toFlip.addAll(group);
    }

    setState(() {
      for (final i in toFlip) _cells[i] = !_cells[i];
      _moves++;
      AppStore.totalFlips = AppStore.totalFlips + 1;
    });
    AudioService.flip();

    if (AppSettings.haptic) {
      if (_moves == 1) HapticFeedback.lightImpact();
      else if (_moves == _par) HapticFeedback.mediumImpact();
    }

    if (!_isSymmetrical() && _moves > _par * 2) {
      _stopwatch.stop();
      _timer.cancel();
      setState(() => _gameOver = true);
      return;
    }
    
    Future<void> _completePuzzle() async {
  _stopwatch.stop();
  _timer.cancel();
  if (AppSettings.haptic) HapticFeedback.heavyImpact();
  AudioService.solve();

  void tryUnlock(String id) {
    if (!AppStore.isUnlocked(id)) {
      AppStore.unlockAchievement(id); // instant local flag for the toast
      _showAchievementToast(id);
      Supabase.instance.client.rpc('unlock_achievement', params: {'p_id': id})
          .catchError((e) => debugPrint('achievement sync failed: $e'));
    }
  }

  final alreadyCompleted = AppStore.isCompleted(_id);
  final hasFailedBefore = AppStore.hasFailed(_id);

  int awardedXP = 0;
  try {
    final result = await Supabase.instance.client
        .rpc('complete_puzzle', params: {'p_puzzle_id': _id, 'p_moves': _moves});
    awardedXP = (result?['awarded_xp'] as int?) ?? 0;
    await AppStore.downloadCloudProfile(); // pulls the authoritative XP/streak back down
  } catch (e) {
    debugPrint('complete_puzzle RPC failed: $e');
    AppStore.markCompleted(_id);
    if (_moves <= _par) AppStore.markParCompleted(_id);
    if (_moves > _par * 2) AppStore.markFailed(_id);
  }

  tryUnlock('first_fold');
  if (_gridRows == 6 && _gridCols == 6) tryUnlock('grid_master');
  if (_moves == _par) tryUnlock('flawless');
  if (_moves == _par + 1) tryUnlock('one_more');
  if (_stopwatch.elapsedMilliseconds < 15000) tryUnlock('speed_demon');
  if (AppStore.totalFlips >= 100) tryUnlock('flippin_crazy');
  if (AppStore.totalFlips >= 250) tryUnlock('flipaholic');
  if (AppStore.totalFlips >= 500) tryUnlock('addicted_to_flipping');
  if (AppStore.totalFlips >= 1000) tryUnlock('flip_god');
  AppStore.incrementTodayCount();
  if (AppStore.todayCompletedCount >= 10) tryUnlock('folding_frenzy');

  final nowSolving = DateTime.now();
  if (nowSolving.hour >= 2 && nowSolving.hour < 4) tryUnlock('night_owl');
  if (_id.startsWith('d') && nowSolving.hour < 6) tryUnlock('early_bird');
  if (hasFailedBefore && _moves <= _par) tryUnlock('comeback_kid');
  if (foldsDayNumberFor(nowSolving) < 1) tryUnlock('beta_tester');

  if (_moves <= _par) {
    AppStore.parStreak = AppStore.parStreak + 1;
    if (AppStore.parStreak >= 10) tryUnlock('perfectionist');
  } else {
    AppStore.parStreak = 0;
  }

  final totalCompleted = AppStore.puzzlesCompleted + AppStore.dailiesCompleted;
  if (totalCompleted >= 10) tryUnlock('novice_folder');
  if (totalCompleted >= 50) tryUnlock('adept_folder');
  if (totalCompleted >= 150) tryUnlock('expert_folder');
  if (totalCompleted >= 300) tryUnlock('master_folder');

  final parCount = AppStore.parPuzzles.length;
  if (parCount >= 10) tryUnlock('par_10');
  if (parCount >= 50) tryUnlock('par_50');
  if (parCount >= 150) tryUnlock('par_150');

  final streak = AppStore.currentStreak;
  if (streak >= 7) tryUnlock('streak_7');
  if (streak >= 30) tryUnlock('streak_30');
  if (streak >= 100) tryUnlock('streak_100');
  if (streak >= 365) tryUnlock('streak_365');

  if (_id.startsWith('p')) AppStore.recentPack = 'PILOT';
  if (_id.startsWith('r')) AppStore.recentPack = 'RECTANGLE';
  _hideXPOnComplete = alreadyCompleted;

  if (_moves <= _par) _showConfetti();
  if (!mounted) return;
  setState(() { _solved = true; _earnedXP = awardedXP; });
}

    if (_isSymmetrical()) {
      _completePuzzle();
    }

    
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            // ── Left control panel ──────────────────────────────────
            SizedBox(
              width: MediaQuery.of(context).size.height * 0.55,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _openMenu,
                          child: Container(
                            width: 36, height: 36,
                            decoration: const BoxDecoration(color: Color(0xFFE8E8E8), shape: BoxShape.circle),
                            child: ClipOval(child: CustomPaint(painter: HomeIconPainter())),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Opacity(
                              opacity: AppSettings.showTimer ? 1.0 : 0.0,
                              child: Text(_timeDisplay,
                                style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black)),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() => _paused = true);
                            _stopwatch.stop();
                            _timer.cancel();
                          },
                          child: SizedBox(
                            width: 36, height: 36,
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 4, height: 18, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(2))),
                                  const SizedBox(width: 4),
                                  Container(width: 4, height: 18, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(2))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(_puzzleDisplayTitle,
                        style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    Text('$_author',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.black54)),
                    const Spacer(),
                    Text('Difficulty:', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 4),
                    StarRating(filled: _difficulty, total: 5),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Moves left:', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
                          const SizedBox(height: 8),
                          if (AppSettings.movesDisplay == 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_par, (i) {
                                final filled = i < _moves;
                                final overPar = _moves > _par;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: 13, height: 13,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: filled ? (overPar ? Colors.red.shade400 : Colors.black) : Colors.transparent,
                                    border: Border.all(
                                      color: filled ? (overPar ? Colors.red.shade400 : Colors.black) : Colors.black38,
                                      width: 2,
                                    ),
                                  ),
                                );
                              }),
                            )
                          else
                            Text('$_moves/$_par',
                              style: GoogleFonts.dmSans(
                                fontSize: 18, fontWeight: FontWeight.w800,
                                color: _moves > _par ? Colors.red.shade400 : Colors.black)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // ── Right grid panel ────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Container(
                    color: FoldsTheme.gridBg(_id),
                    padding: const EdgeInsets.all(10),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final nR = _gridRows;
                        final nC = _gridCols;
                        final maxDim = max(nR, nC);
                        final gap = maxDim <= 4 ? 8.0 : maxDim <= 6 ? 6.0 : 4.0;
                        final cellSizeW = ((constraints.maxWidth - gap * (nC - 1)) / nC).clamp(1.0, double.infinity);
final cellSizeH = ((constraints.maxHeight - gap * (nR - 1)) / nR).clamp(1.0, double.infinity);
final cellSize = min(cellSizeW, cellSizeH);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(nR, (row) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: row < nR - 1 ? gap : 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(nC, (col) {
                                  final index = row * nC + col;
                                  return Padding(
                                    padding: EdgeInsets.only(right: col < nC - 1 ? gap : 0),
                                    child: SizedBox(
                                      width: cellSize, height: cellSize,
                                      child: FlipCell(
                                        isBlack: _cells[index],
                                        linkShape: _linkShapeByIndex[index],
                                        isHoliday: FoldsTheme.isHolidayPuzzle(_id),
                                        onTap: () => _handleCellTap(index),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                      ),
                    ),
        // Pause overlay
        if (_paused)
  Positioned.fill(
    child: Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('PAUSED', style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 4)),
            const SizedBox(height: 6),
            Text(_puzzleDisplayTitle, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black38, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () { setState(() => _paused = false); _stopwatch.start(); _startTimer(); },
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text('RESUME', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1))),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () { setState(() => _paused = false); _loadPuzzle(_id, forcePlay: true); _resetTimer(); },
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text('Restart Puzzle', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black))),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () { _timer.cancel(); _stopwatch.stop(); pushFade(context, const PuzzlesMenuScreen()); },
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text('Exit to Puzzles', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black54))),
              ),
            ),
          ],
        ),
        ),
      ),
    ),
      ],
    ),
    ),
    ),
          ],
        ),
      ],
    );
  }

  void _openMenu() {
    setState(() => _menuOpen = true);
    Future.delayed(const Duration(milliseconds: 20), () {
      setState(() => _menuVisible = true);
    });
  }

  void _closeMenu() {
    setState(() => _menuVisible = false);
    Future.delayed(const Duration(milliseconds: 250), () {
      setState(() => _menuOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── Loading screen ────────────────────────────────────────────
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48, height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF2C2C2C),
                ),
              ),
              const SizedBox(height: 24),
              Text('Folding In Progress',
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
              const SizedBox(height: 6),
              Text('Your Fold is being processed...',
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black38)),
            ],
          ),
        ),
      );
    }

    // ── Not found screen ──────────────────────────────────────────
    if (_notFound) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
  'assets/404.png',
  width: 120, // Adjust these numbers to scale the box perfectly
  height: 120,
  fit: BoxFit.contain,
),
                const SizedBox(height: 8),
                Text('Puzzle Not Found',
                  style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black)),
                const SizedBox(height: 8),
                Text("This Fold isn't on our radar!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black38)),
                const SizedBox(height: 32),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => launchCustomUrl('https://folds.jaydev.games/support'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(14)),
                        child: Center(child: Text('Learn More',
                          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black54))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _loadPuzzle(_requestedId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(14)),
                        child: Center(child: Text('Retry',
                          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white))),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FoldsTheme.scaffoldBg(_id),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (FoldsTheme.hasWinterBg(_id))
            Image.asset(
              'assets/winter.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          SafeArea(
            child: Stack(
              children: [

            // ── Grid & Localized Pause Overlay ───────────────────
            if (_loaded && _solved)
            Positioned(
              top: 96, left: 0, right: 0, bottom: 0,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                key: ValueKey('complete_scroll_$_id'),
                child: FoldCompleteAnimator(
                  key: ValueKey('complete_$_id'),
                  maxWidth: constraints.maxWidth,
                  maxHeight: constraints.maxHeight,
                  puzzleId: _id,
                  puzzleTitle: _puzzleDisplayTitle,
                  puzzleShareNumber: _puzzleShareNumber,
                  packPath: _packPath,
                  timeDisplay: _timeDisplay,
                  moves: _moves,
                  par: _par,
                  earnedXP: _earnedXP,
                  hideXP: _hideXPOnComplete,
                  cells: _cells,
                  skipAnimation: _skipAnimation,
                  isHoliday: FoldsTheme.isHolidayPuzzle(_id),
                  gridRows: _gridRows,
                  gridCols: _gridCols,
                  
                  onRetry: () {
                    setState(() { _solved = false; _skipAnimation = false; });
                    _loadPuzzle(_id, forcePlay: true);
                    _resetTimer();
                  },
                  onNext: _nextPuzzleId != null ? () {
                    final next = _nextPuzzleId!;
                    setState(() { _solved = false; _skipAnimation = false; });
                    _loadPuzzle(next);
                    _resetTimer();
                  } : null,
                ),
              )),
            ),
            if (_loaded && !_solved && !_gameOver && _gridCols > _gridRows)
              _buildLandscapeLayout(context),
            if (_loaded && !_solved && !_gameOver && _gridCols <= _gridRows) Positioned(
              top: 0, left: 0, right: 0, bottom: 0,
              child: Center(
  child: Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: MediaQuery.of(context).size.width - 32,
        color: FoldsTheme.gridBg(_id),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final nR = _gridRows;
            final nC = _gridCols;
            final maxDim = max(nR, nC);
            final gap = maxDim <= 4 ? 8.0 : maxDim <= 6 ? 6.0 : 4.0;
            final cellSizeW = ((constraints.maxWidth - gap * (nC - 1)) / nC).clamp(1.0, double.infinity);
            final cellSizeH = constraints.maxHeight > 0
                ? ((constraints.maxHeight - gap * (nR - 1)) / nR).clamp(1.0, double.infinity)
                : double.infinity;
            final cellSize = min(cellSizeW, cellSizeH);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(nR, (row) {
                return Padding(
                  padding: EdgeInsets.only(bottom: row < nR - 1 ? gap : 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(nC, (col) {
                      final index = row * nC + col;
                      return Padding(
                        padding: EdgeInsets.only(right: col < nC - 1 ? gap : 0),
                        child: SizedBox(
                          width: cellSize,
                          height: cellSize,
                          child: FlipCell(
                            isBlack: _cells[index],
                            linkShape: _linkShapeByIndex[index],
                            isHoliday: FoldsTheme.isHolidayPuzzle(_id),
                            onTap: () => _handleCellTap(index),     ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                    
                  
                  // Symmetry progress bar
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        height: 4,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            Container(color: Colors.black12),
                            FractionallySizedBox(
                              widthFactor: _symmetryProgress,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                decoration: BoxDecoration(
                                  color: _symmetryProgress >= 1.0
                                      ? const Color(0xFF4CAF50)
                                      : _symmetryProgress > 0.8
                                          ? const Color(0xFFFFD465)
                                          : const Color(0xFF888888),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                      // Localized Whiteout Pause Overlay
                  if (_paused)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('PAUSED', style: GoogleFonts.dmSans(
                                fontSize: 32, fontWeight: FontWeight.w800,
                                color: Colors.black, letterSpacing: 4)),
                              const SizedBox(height: 8),
                              Text(_puzzleDisplayTitle, style: GoogleFonts.dmSans(
                                fontSize: 16, color: Colors.black38, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 32),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _paused = false);
                                  _stopwatch.start();
                                  _startTimer();
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C2C2C),
                                    borderRadius: BorderRadius.circular(14)),
                                  child: Center(child: Text('RESUME', style: GoogleFonts.dmSans(
                                    fontSize: 16, fontWeight: FontWeight.w800,
                                    color: Colors.white, letterSpacing: 1))),
                                ),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _paused = false);
                                  _loadPuzzle(_id, forcePlay: true);
                                  _resetTimer();
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFEFEF),
                                    borderRadius: BorderRadius.circular(14)),
                                  child: Center(child: Text('Restart Puzzle', style: GoogleFonts.dmSans(
                                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black))),
                                ),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () {
                                  _timer.cancel();
                                  _stopwatch.stop();
                                  pushFade(context, const PuzzlesMenuScreen());
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFEFEF),
                                    borderRadius: BorderRadius.circular(14)),
                                  child: Center(child: Text('Exit to Puzzles', style: GoogleFonts.dmSans(
                                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black54))),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
                ),
              ),
            ),

            if (_loaded && _gameOver)
                    Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).size.height * 0.09, // ~1/12–1/8 of screen
                      ),
                      child: GameOverCrack(
                        cells: _cells,
                        gridRows: _gridRows,
                        gridCols: _gridCols,
                        moves: _moves,
                        par: _par,
                        isHoliday: FoldsTheme.isHolidayPuzzle(_id),
                        onRetry: () {
                          setState(() => _gameOver = false);
                          _loadPuzzle(_id, forcePlay: true);
                          _resetTimer();
                        },
                        onExit: () => pushFade(context, const PuzzlesMenuScreen())
                      ),
                    ),


            // ── Top bar (portrait only) ──────────────────────────────────────────
            if (_gridCols <= _gridRows)
              Positioned(
              top: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _openMenu,
                          child: Container(
                            width: 40, height: 40,
                            decoration: const BoxDecoration(color: Color(0xFFE8E8E8), shape: BoxShape.circle),
                            child: ClipOval(child: CustomPaint(painter: HomeIconPainter())),
                          ),
                        ),
                        Opacity(
                          opacity: AppSettings.showTimer ? 1.0 : 0.0,
                          child: Text(_timeDisplay, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black)),
                        ),
                        if (_solved && !_gameOver)
                          const SizedBox(width: 40, height: 40)
                        else
                          GestureDetector(
                            onTap: () {
                              setState(() => _paused = true);
                              _stopwatch.stop();
                              _timer.cancel();
                            },
                            child: SizedBox(
                              width: 40, height: 40,
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 5, height: 22, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(width: 5),
                                    Container(width: 5, height: 22, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(2))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!_solved || _gameOver) ...[
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _puzzleDisplayTitle,
                                  style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black),
                                ),
                              ),
                              Text('$_author', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w400, color: Colors.black54)),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Difficulty:', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.black54)),
                              const SizedBox(height: 4),
                              StarRating(filled: _difficulty, total: 5),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Moves bar ────────────────────────────────────────
            // ── Moves bar ────────────────────────────────────────
            if (!_solved && _gridCols <= _gridRows ) Positioned(
              bottom: 24, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Moves left:', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black54)),
                    const SizedBox(height: 16),
                    if (AppSettings.movesDisplay == 0)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: List.generate(_par, (i) {
                          final filled = i < _moves;
                          final overPar = _moves > _par;
                          final dotSize = _par > 8 ? 14.0 : 18.0;
                          return Container(
                            width: dotSize, height: dotSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? (overPar ? Colors.red.shade400 : Colors.black) : Colors.transparent,
                              border: Border.all(
                                color: filled ? (overPar ? Colors.red.shade400 : Colors.black) : Colors.black38,
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      )
                    else
                      Text(
                        '$_moves/$_par',
                        style: GoogleFonts.dmSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _moves > _par ? Colors.red.shade400 : Colors.black,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── 6SM overlay ───────────────────────────────────────
            if (_menuOpen)
              AnimatedOpacity(
                opacity: _menuVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: GestureDetector(
                  onTap: _closeMenu,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.3),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                _closeMenu();
                                Future.delayed(const Duration(milliseconds: 260), () {
                                  pushFade(context, const LeaderboardScreen());
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C2C2C),
                                  borderRadius: BorderRadius.circular(20)),
                                child: Row(children: [
                                  const Icon(Icons.leaderboard_rounded,
                                    color: Color(0xFFFFD465), size: 20),
                                  const SizedBox(width: 12),
                                  Text('LEADERBOARD', style: GoogleFonts.dmSans(
                                    fontSize: 16, fontWeight: FontWeight.w800,
                                    color: Colors.white, letterSpacing: 0.5)),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right_rounded,
                                    color: Colors.white38, size: 20),
                                ]),
                              ),
                            ),
                            Row(
                              children: [
                                SixSMCard(
                                  label: 'Puzzles',
                                    icon: Icons.extension_rounded,
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        pushFade(context, const PuzzlesMenuScreen());
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  SixSMCard(
                                    label: 'Profile',
                                    icon: Icons.account_circle_rounded,
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        pushFade(context, const ProfileScreen());
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  SixSMCard(
                                    label: 'Store',
                                    icon: Icons.shopping_basket_rounded,
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        pushFade(context, const StoreScreen());
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  SixSMCard(
                                    label: 'Settings',
                                    icon: Icons.settings_rounded,
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        pushFade(context, const SettingsScreen());
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  SixSMCard(
                                    label: 'Socials',
                                    icon: Icons.favorite_rounded,
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        pushFade(context, const SocialsScreen());
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  SixSMCard(
                                    label: 'Credits',
                                    icon: Icons.handshake_rounded,
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        pushFade(context, const CreditsScreen());
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
            ),
          ),
        ],
      ),
    );
  }
}

