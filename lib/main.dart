import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'core/constants.dart';
import 'models/xp_system.dart';
import 'models/achievement_def.dart';
import 'models/texture_pack_def.dart';
import 'state/app_settings.dart';
import 'state/app_store.dart';
import 'services/audio_service.dart';
import 'theme/folds_theme.dart';
import 'painters/icon_painters.dart';
import 'painters/texture_painters.dart';
import 'painters/store_shape_painters.dart';
import 'widgets/shared/folds_top_bar.dart';
import 'widgets/shared/buttons.dart';
import 'widgets/shared/form_controls.dart';
import 'widgets/shared/misc.dart';
import 'widgets/gameplay/flip_cell.dart';
import 'widgets/gameplay/fold_complete_animator.dart';
import 'widgets/gameplay/achievement_toast.dart';
import 'widgets/gameplay/confetti.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await Supabase.initialize(
    url: 'https://kvihtmzgthznjtwqtbvg.supabase.co',
    publishableKey: 'sb_publishable_hznxJ0hZwXRvO-KHZuoYag_RXPDWfWI',
  );
  await AppStore.init();
  await AudioService.init();
  runApp(const FoldsApp());
}

class FoldsApp extends StatelessWidget {
  const FoldsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Folds',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(),
      home: AppStore.hasSeenOnboarding ? const GameplayScreen() : const OnboardingScreen(),
    );
  }
}

void _pushFade(BuildContext context, Widget screen) {
  Navigator.push(context, PageRouteBuilder(
    pageBuilder: (_, __, ___) => screen,
    transitionsBuilder: (_, animation, __, child) {
      final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      final fade = Tween<double>(begin: 0.0, end: 1.0)
          .animate(CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.5)));
      return SlideTransition(position: slide, child: FadeTransition(opacity: fade, child: child));
    },
    transitionDuration: const Duration(milliseconds: 320),
  ));
}

Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint('Could not launch $url');
  }
}




// ─────────────────────────────────────────────────────────────────────────────
// GAMEPLAY SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class GameplayScreen extends StatefulWidget {
  final String? initialPuzzleId; // Null defaults to daily
  const GameplayScreen({super.key, this.initialPuzzleId});
  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
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
  
  List<List<int>> _linkGroups = []; // each group: list of cell indices that flip together
  Map<int, String> _linkShapeByIndex = {}; // index -> shape name, for rendering the badge

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _startTimer();
    // AudioService.startMusic();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialPuzzleId != null) {
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
            _loadPuzzle(fallback?['id'] ?? 'p1');
          }
        } catch (e) {
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
    setState(() {
      _loading = true;
      _notFound = false;
      _loaded = false;
    });
    try {
      final offlineHit = AppStore.getOfflinePuzzle(id);
      final response = offlineHit ?? await Supabase.instance.client
          .from('puzzles')
          .select()
          .eq('id', id)
          .single();
      final rawCells = (response['cells'] as List).map((e) => e == 1).toList();
      // Determine grid size from cell count
      final cellCount = rawCells.length;
      final int gridRows = (response['rows'] as int?) ?? (sqrt(cellCount.toDouble()).toInt());
      final int gridCols = (response['cols'] as int?) ?? (sqrt(cellCount.toDouble()).toInt());
      final gridSize = gridRows;
      final linksRaw = (response['links'] as List?) ?? [];
      final groups = <List<int>>[];
      final shapeMap = <int, String>{};
      for (final link in linksRaw) {
        final members = List<int>.from(link['members']);
        final shape = link['shape'] as String;
        groups.add(members);
        for (final m in members) {
          shapeMap[m] = shape;
        }
      }
      // Format Daily Titles to include #No.
      String rawId = response['id'].toString();
      String displayTitle = response['title'];
      if (rawId.startsWith('d')) {
        String dayNumber = rawId.replaceAll(RegExp(r'[^0-9]'), '');
        displayTitle = '#$dayNumber $displayTitle';
      }

      if (gridCols > gridRows) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }

      setState(() {
        _cells = rawCells;
        _gridSize = gridSize;
        _gridRows = gridRows;
        _gridCols = gridCols;
        _title = displayTitle;
        _author = response['author'];
        _difficulty = response['difficulty'] as int;
        _id = response['id'].toString();
        _par = (response['par'] ?? 5) as int;
        _moves = 0;
        _loaded = true;
        _loading = false;
        _notFound = false;
        _solved = false;
        _linkGroups = groups; 
        _linkShapeByIndex = shapeMap;
      });
    } catch (e) {
      debugPrint('❌ Supabase error: $e');
      setState(() {
        _loading = false;
        _notFound = true;
        _loaded = false;
      });
    }
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

    if (_isSymmetrical()) {
      _stopwatch.stop();
      _timer.cancel();
      final hasFailed = AppStore.hasFailed(_id);
      final xp = XPSystem.calculate(
        difficulty: _difficulty,
        moves: _moves,
        par: _par,
        hasFailed: hasFailed,
      );
      if (AppSettings.haptic) HapticFeedback.heavyImpact();
      AudioService.solve();

      void tryUnlock(String id) {
        if (!AppStore.isUnlocked(id)) {
          AppStore.unlockAchievement(id);
          _showAchievementToast(id);
        }
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
      if (hasFailed && _moves <= _par) tryUnlock('comeback_kid');
      if (foldsDayNumberFor(nowSolving) < 1) tryUnlock('beta_tester');

      if (_moves <= _par) {
        AppStore.parStreak = AppStore.parStreak + 1;
        if (AppStore.parStreak >= 10) tryUnlock('perfectionist');
      } else {
        AppStore.parStreak = 0;
      }

      final alreadyCompleted = AppStore.isCompleted(_id);
      if (!alreadyCompleted) {
        if (_moves > _par * 2) AppStore.markFailed(_id);
        AppStore.totalXP = AppStore.totalXP + xp;
      }
      if (_moves <= _par) AppStore.markParCompleted(_id);
      AppStore.markCompleted(_id);

      final totalCompleted = AppStore.puzzlesCompleted + AppStore.dailiesCompleted;
      if (totalCompleted >= 10) tryUnlock('novice_folder');
      if (totalCompleted >= 50) tryUnlock('adept_folder');
      if (totalCompleted >= 150) tryUnlock('expert_folder');
      if (totalCompleted >= 300) tryUnlock('master_folder');

      final parCount = AppStore.parPuzzles.length;
      if (parCount >= 10) tryUnlock('par_10');
      if (parCount >= 50) tryUnlock('par_50');
      if (parCount >= 150) tryUnlock('par_150');

      if (_id.startsWith('d')) {
        if (!alreadyCompleted) AppStore.updateStreak();
        final streak = AppStore.currentStreak;
        if (streak >= 7) tryUnlock('streak_7');
        if (streak >= 30) tryUnlock('streak_30');
        if (streak >= 100) tryUnlock('streak_100');
        if (streak >= 365) tryUnlock('streak_365');
      } else if (_id.startsWith('p')) {
        AppStore.recentPack = 'PILOT';
      } else if (_id.startsWith('r')) {
        AppStore.recentPack = 'RECTANGLE';
      }

      if (_moves <= _par) _showConfetti();
      setState(() {
        _solved = true;
        _earnedXP = xp;
      });
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
                    Text(_puzzleDisplayTitle,
                      style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text('by $_author',
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
                child: Center(
                  child: Container(
                    color: FoldsTheme.gridBg(_id),
                    padding: const EdgeInsets.all(10),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final nR = _gridRows;
                        final nC = _gridCols;
                        final maxDim = max(nR, nC);
                        final gap = maxDim <= 4 ? 8.0 : maxDim <= 6 ? 6.0 : 4.0;
                        final cellSizeW = (constraints.maxWidth - gap * (nC - 1)) / nC;
                        final cellSizeH = (constraints.maxHeight - gap * (nR - 1)) / nR;
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
              ),
            ),
          ],
        ),
        // Pause overlay
        if (_paused)
          Positioned.fill(
            child: Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('PAUSED', style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 4)),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      setState(() => _paused = false);
                      _stopwatch.start();
                      _startTimer();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
                      child: Text('RESUME', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
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
                GestureDetector(
                  onTap: () => _loadPuzzle('p1'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('Back to Home',
                      style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
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
              SingleChildScrollView(
                key: ValueKey('complete_scroll_$_id'),
                child: FoldCompleteAnimator(
                  key: ValueKey('complete_$_id'),
                  puzzleId: _id,
                  puzzleTitle: _puzzleDisplayTitle,
                  puzzleShareNumber: _puzzleShareNumber,
                  packPath: _packPath,
                  timeDisplay: _timeDisplay,
                  moves: _moves,
                  par: _par,
                  earnedXP: _earnedXP,
                  cells: _cells,
                  skipAnimation: _skipAnimation,
                  isHoliday: FoldsTheme.isHolidayPuzzle(_id),
                  gridRows: _gridRows,
                  gridCols: _gridCols,
                  onRetry: () {
                    setState(() {
                      _solved = false;
                      _skipAnimation = false;
                    });
                    _loadPuzzle(_id, forcePlay: true);
                    _resetTimer();
                  },
                  onNext: _nextPuzzleId != null ? () {
                    setState(() {
                      _solved = false;
                      _skipAnimation = false;
                      _moves = 0;
                      _earnedXP = 0;
                      _loaded = false; // prevents old grid flashing for one frame
                    });
                    _resetTimer();
                    _loadPuzzle(_nextPuzzleId!);
                  } : null,
                ),
              ),

            if (_loaded && !_solved && _gridCols > _gridRows)
              _buildLandscapeLayout(context),
            if (_loaded && !_solved && _gridCols <= _gridRows) Center(
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
            final cellSizeW = (constraints.maxWidth - gap * (nC - 1)) / nC;
            final cellSizeH = constraints.maxHeight > 0
                ? (constraints.maxHeight - gap * (nR - 1)) / nR
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
                                  _pushFade(context, const PuzzlesMenuScreen());
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
            

            // ── Top bar (portrait only) ──────────────────────────────────────────
            if (MediaQuery.of(context).orientation == Orientation.portrait)
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
                        if (_solved)
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
                    if (!_solved) ...[
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
            if (!_solved && MediaQuery.of(context).orientation == Orientation.portrait) Positioned(
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
                                  _pushFade(context, const LeaderboardScreen());
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
                                _SixSMCard(
                                  label: 'Puzzles',
                                    icon: Icons.extension_rounded,
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        _pushFade(context, const PuzzlesMenuScreen());
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  _SixSMCard(
                                    label: 'Profile',
                                    icon: Icons.account_circle_rounded,
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        _pushFade(context, const ProfileScreen());
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _SixSMCard(
                                    label: 'Store',
                                    icon: Icons.shopping_basket_rounded,
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        _pushFade(context, const StoreScreen());
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  _SixSMCard(
                                    label: 'Settings',
                                    icon: Icons.settings_rounded,
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        _pushFade(context, const SettingsScreen());
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _SixSMCard(
                                    label: 'Socials',
                                    icon: Icons.favorite_rounded,
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        _pushFade(context, const SocialsScreen());
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  _SixSMCard(
                                    label: 'Credits',
                                    icon: Icons.handshake_rounded,
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        _pushFade(context, const CreditsScreen());
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

// ─────────────────────────────────────────────────────────────────────────────
// PUZZLES MENU SCREEN

// ─────────────────────────────────────────────────────────────────────────────
// PUZZLES MENU SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PuzzlesMenuScreen extends StatefulWidget {
  const PuzzlesMenuScreen({super.key});
  @override
  State<PuzzlesMenuScreen> createState() => _PuzzlesMenuScreenState();
}

class _PuzzlesMenuScreenState extends State<PuzzlesMenuScreen> {
  bool _downloadBusy = false;
  String _countdown = '';
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_tick);
    });
  }

  void _tick() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final d = midnight.difference(now);
    _countdown = '${d.inHours.toString().padLeft(2,'0')}:${(d.inMinutes % 60).toString().padLeft(2,'0')}:${(d.inSeconds % 60).toString().padLeft(2,'0')}';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleDownloadTap() async {
    final has = AppStore.hasOfflinePuzzles;
    final count = AppStore.offlinePuzzleCount;

    if (has) {
      final remove = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Text('Offline Puzzles', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 20)),
          content: Text(
            '$count puzzles are cached locally (~${(count * 0.5).ceil()} KB). '
            'You can play without internet. Remove the offline data?',
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Remove', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.red)),
            ),
          ],
        ),
      );
      if (remove == true) {
        await AppStore.clearOfflinePuzzles();
        setState(() {});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Offline puzzles removed.',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF2C2C2C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
      return;
    }

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.download_rounded, color: Color(0xFF2C2C2C)),
            const SizedBox(width: 10),
            Text('Download Puzzles', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Download all puzzle data to your device so you can play offline — anytime, anywhere, no internet needed.',
              style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Colors.black38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Approx. size: ~150 KB. Progress still syncs when back online.',
                      style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Text('Cancel',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45)),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Download',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (go != true) return;
    setState(() => _downloadBusy = true);
    final result = await AppStore.downloadAllPuzzles();
    setState(() => _downloadBusy = false);
    if (!mounted) return;
   if (result != null) AppStore.unlockAchievement('just_in_case');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result != null
            ? '✅ ${result['count']} puzzles cached (${result['sizeKB']} KB) — play offline anytime!'
            : '❌ Download failed. Check your connection.',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
      backgroundColor: const Color(0xFF2C2C2C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  

  @override
  Widget build(BuildContext context) {
    final hasCached = AppStore.hasOfflinePuzzles;
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: GestureDetector(
        onTap: _downloadBusy ? null : _handleDownloadTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _downloadBusy
            ? const Center(
                child: SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                ),
              )
            : Icon(
                hasCached ? Icons.download_done_rounded : Icons.download_rounded,
                color: hasCached ? const Color(0xFF7BD957) : Colors.white,
                size: 26,
              ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              FoldsTopBar(title: 'PUZZLES', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      height: 120,
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('DAILY PUZZLE', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color.fromARGB(0, 66, 66, 68), borderRadius: BorderRadius.circular(6)),
                            child: Text('#${foldsDayNumberFor(DateTime.now())}',
                              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            foldsDayNumberFor(DateTime.now()) < 1
                              ? 'Launches in $_countdown'
                              : 'Next daily in $_countdown',
                            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white38)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _pushFade(context, const DailyArchiveScreen()),
                    child: Container(
                      width: 76, height: 120,
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
                      child: Center(child: CustomPaint(size: const Size(28, 24), painter: ArchiveIconPainter())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Replace the Expanded GridView.count with:
Expanded(
  child: SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    child: Column(
      children: [
        // Holiday pack at TOP when unlocked
        if (!DateTime.now().isBefore(DateTime(2026, 12, 10))) ...[
          const _HolidayPackBanner(),
          const SizedBox(height: 14),
        ],
        SizedBox(
          height: 190,
          child: _MenuPackCard(
            title: 'PILOT PACK',
            subtitle: '100 PUZZLES',
            completedPuzzles: AppStore.completedInRange('p', 0, 100),
            totalPuzzles: 100,
            shapeType: _PackShapeType.square,
            onPlay: () => Navigator.pop(context),
            onHome: () => _pushFade(context, const PilotPackDetailScreen()),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 230,
          child: _MenuPackCard(
            title: 'RECTANGLE PACK',
            subtitle: '100 PUZZLES',
            completedPuzzles: AppStore.completedInRange('r', 0, 100),
            totalPuzzles: 100,
            shapeType: _PackShapeType.rectangle,
            onPlay: () {},
            onHome: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => const PuzzleSelectorScreen(
                  packName: 'RECTANGLE', totalPuzzles: 100, idPrefix: 'r', idOffset: 0),
              ));
            },
          ),
        ),
        // Holiday pack at BOTTOM when not yet unlocked
        if (DateTime.now().isBefore(DateTime(2026, 12, 10))) ...[
          const SizedBox(height: 14),
          const _HolidayPackBanner(),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: Text('MORE PUZZLES COMING SOON!',
                      style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    ),
  ),
),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PILOT PACK DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PilotPackDetailScreen extends StatelessWidget {
  const PilotPackDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Read live from AppStore
    final done4x4 = AppStore.completedInRange('p', 0, 50);
    final done6x6 = AppStore.completedInRange('p', 50, 30);
    final done8x8 = AppStore.completedInRange('p', 80, 20);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              FoldsTopBar(title: 'PILOT PACK', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 24),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _PuzzleSizeCard(
                        label: '4x4',
                        puzzleCount: '50 PUZZLES',
                        completed: done4x4,
                        total: 50,
                        gridSize: 4,
                        onPlay: () {
                          String targetId = 'p1';
                          for (int i = 1; i <= 50; i++) {
                            if (!AppStore.isCompleted('p$i')) {
                              targetId = 'p$i';
                              break;
                            }
                          }
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: targetId),
                              transitionsBuilder: (_, animation, __, child) {
                                final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                                return SlideTransition(position: slide, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 320),
                            ),
                            (route) => false,
                          );
                        },
                        onHome: () => _pushFade(context, const PuzzleSelectorScreen(
                          packName: '4x4', totalPuzzles: 50, idPrefix: 'p', idOffset: 0)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _PuzzleSizeCard(
                        label: '6x6',
                        puzzleCount: '30 PUZZLES',
                        completed: done6x6,
                        total: 30,
                        gridSize: 6,
                        onPlay: () {
                          String targetId = 'p51';
                          for (int i = 51; i <= 80; i++) {
                            if (!AppStore.isCompleted('p$i')) {
                              targetId = 'p$i';
                              break;
                            }
                          }
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: targetId),
                              transitionsBuilder: (_, animation, __, child) {
                                final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                                return SlideTransition(position: slide, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 320),
                            ),
                            (route) => false,
                          );
                        },
                        onHome: () => _pushFade(context, const PuzzleSelectorScreen(
                          packName: '6x6', totalPuzzles: 30, idPrefix: 'p', idOffset: 50)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _PuzzleSizeCard(
                        label: '8x8',
                        puzzleCount: '20 PUZZLES',
                        completed: done8x8,
                        total: 20,
                        gridSize: 8,
                        onPlay: () {
                          String targetId = 'p81';
                          for (int i = 81; i <= 100; i++) {
                            if (!AppStore.isCompleted('p$i')) {
                              targetId = 'p$i';
                              break;
                            }
                          }
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: targetId),
                              transitionsBuilder: (_, animation, __, child) {
                                final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                                return SlideTransition(position: slide, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 320),
                            ),
                            (route) => false,
                          );
                        },
                        onHome: () => _pushFade(context, const PuzzleSelectorScreen(
                          packName: '8x8', totalPuzzles: 20, idPrefix: 'p', idOffset: 80)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CustomBackButton(label: 'BACK TO MORE PUZZLES', onTap: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUZZLE SELECTOR SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PuzzleSelectorScreen extends StatelessWidget {
  final String packName;
  final int totalPuzzles;
  final String idPrefix;
  final int idOffset;

  const PuzzleSelectorScreen({
    super.key,
    required this.packName,
    required this.totalPuzzles,
    required this.idPrefix,
    required this.idOffset,
  });

  @override
  Widget build(BuildContext context) {
    final completedPuzzles = Set<int>.from(
      List.generate(totalPuzzles, (i) => i + 1)
        .where((n) => AppStore.isCompleted('$idPrefix${idOffset + n}'))
    );
    final displayCount = totalPuzzles;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  FoldsTopBar(title: '$packName PACK', onBack: () => Navigator.pop(context)),
                  const SizedBox(height: 16),
                  // Progress bar
                  Container(
                    height: 28,
                    decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(8)),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: completedPuzzles.length / totalPuzzles,
                          child: Container(
                            decoration: BoxDecoration(color: const Color(0xFFFFD465), borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        Center(
                          child: Text(
                            '${((completedPuzzles.length / totalPuzzles) * 100).toInt()}%',
                            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Scrollable puzzle grid — fills all remaining space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: displayCount,
                  itemBuilder: (context, i) {
                    final puzzleNumber = i + 1;
                    final isCompleted = completedPuzzles.contains(puzzleNumber);
                    final puzzleId = '${idPrefix}${idOffset + puzzleNumber}';
                    return GestureDetector(
                      onTap: () {
                        // Paywall Check for Rectangle Pack
                        if (packName.contains('RECTANGLE') && puzzleNumber > 5) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              backgroundColor: Colors.white,
                              title: Text('Unlock Rectangle Pack', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 22)),
                              content: Text('You\'ve reached the end of the free preview! Unlock the remaining 95 Rectangle puzzles for endless folding fun.', style: GoogleFonts.dmSans(fontSize: 15)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Not Now', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => const _PaymentSheet(
                                        productName: 'Rectangle Pack',
                                        price: '\$2.99',
                                      ),
                                    );
                                  },
                                  child: Text('Buy for \$2.99', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        
                        Navigator.pushAndRemoveUntil(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: puzzleId),
                            transitionsBuilder: (_, animation, __, child) {
                              final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                              return SlideTransition(position: slide, child: child);
                            },
                            transitionDuration: const Duration(milliseconds: 320),
                          ),
                          (route) => false,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('#$puzzleNumber',
                                  style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                                if (isCompleted)
                              Icon(
                                Icons.check_rounded,
                                color: AppStore.isParCompleted(puzzleId)
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFFFD465),
                                size: 20,
                              ),
                              ],
                            ),
                            Icon(Icons.play_arrow_rounded,
                              color: isCompleted ? Colors.white54 : Colors.white, size: 28),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: CustomBackButton(label: 'BACK TO MORE PUZZLES', onTap: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// MOCK PAYMENT SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentSheet extends StatefulWidget {
  final String productName;
  final String price;
  const _PaymentSheet({required this.productName, required this.price});
  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvcCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _busy = false;
  bool _success = false;
  String? _error;

  String _formatCard(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  String _formatExpiry(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 2) return digits;
    return '${digits.substring(0, 2)}/${digits.substring(2, digits.length.clamp(0, 4))}';
  }

  bool get _valid =>
      _cardCtrl.text.replaceAll(' ', '').length == 16 &&
      _expiryCtrl.text.length == 5 &&
      _cvcCtrl.text.length >= 3 &&
      _nameCtrl.text.trim().isNotEmpty;

  Future<void> _pay() async {
    if (!_valid) { setState(() => _error = 'Please fill in all fields correctly.'); return; }
    setState(() { _busy = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 1800));
    setState(() { _busy = false; _success = true; });
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _cardCtrl.dispose(); _expiryCtrl.dispose();
    _cvcCtrl.dispose(); _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _success
            ? _SuccessState(productName: widget.productName)
            : Column(
                key: const ValueKey('form'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.productName, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('One-time purchase', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black45)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
                      child: Text(widget.price, style: GoogleFonts.dmSans(
                        fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _PayField(label: 'CARDHOLDER NAME', controller: _nameCtrl,
                    hint: 'Jay Dev', keyboard: TextInputType.name),
                  const SizedBox(height: 12),
                  _PayField(
                    label: 'CARD NUMBER', controller: _cardCtrl,
                    hint: '1234 5678 9012 3456',
                    keyboard: TextInputType.number, maxLen: 19,
                    onChanged: (v) {
                      final formatted = _formatCard(v);
                      if (formatted != v) {
                        _cardCtrl.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _PayField(
                      label: 'EXPIRY', controller: _expiryCtrl,
                      hint: 'MM/YY', keyboard: TextInputType.number, maxLen: 5,
                      onChanged: (v) {
                        final formatted = _formatExpiry(v);
                        if (formatted != v) {
                          _expiryCtrl.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length));
                        }
                      },
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _PayField(
                      label: 'CVC', controller: _cvcCtrl,
                      hint: '•••', keyboard: TextInputType.number, maxLen: 4,
                      obscure: true,
                    )),
                  ]),
                  if (_error != null) Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _busy ? null : _pay,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(16)),
                      child: Center(
                        child: _busy
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.lock_rounded, color: Colors.white54, size: 16),
                                const SizedBox(width: 8),
                                Text('Pay ${widget.price}', style: GoogleFonts.dmSans(
                                  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                              ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.security_rounded, size: 13, color: Colors.black26),
                    const SizedBox(width: 4),
                    Text('Secured with 256-bit encryption',
                      style: GoogleFonts.dmSans(fontSize: 11, color: Colors.black26)),
                  ])),
                ],
              ),
      ),
    );
  }
}

class _PayField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboard;
  final int? maxLen;
  final bool obscure;
  final ValueChanged<String>? onChanged;

  const _PayField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboard,
    this.maxLen,
    this.obscure = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
        color: Colors.black38, letterSpacing: 1.1)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        maxLength: maxLen,
        onChanged: onChanged,
        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: Colors.black26),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2C2C2C), width: 1.5)),
        ),
      ),
    ]);
  }
}

class _SuccessState extends StatelessWidget {
  final String productName;
  const _SuccessState({required this.productName});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 72),
        const SizedBox(height: 16),
        Text('Payment Successful!', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('$productName has been unlocked. Enjoy!', textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black54)),
        const SizedBox(height: 24),
      ],
    );
  }
}



class _PuzzleSizeCard extends StatelessWidget {
  final String label;
  final String puzzleCount;
  final int completed;
  final int total;
  final int gridSize;
  final VoidCallback onPlay;
  final VoidCallback onHome;

  const _PuzzleSizeCard({
    required this.label,
    required this.puzzleCount,
    required this.completed,
    required this.total,
    required this.gridSize,
    required this.onPlay,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    final pct = (progress * 100).toInt();

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelSize = constraints.maxHeight;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                          style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(puzzleCount,
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54)),
                      ],
                    ),
                    Stack(
                      children: [
                        Container(
                          height: 24,
                          decoration: BoxDecoration(color: const Color(0xFFd9d9d9), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              if (pct > 0)
                                Expanded(
                                  flex: pct,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD465),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              Expanded(flex: 100 - pct, child: const SizedBox()),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: Text('$pct%',
                              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54)),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onPlay,
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: onHome,
                          child: const Icon(Icons.home_rounded, color: Colors.white, size: 26),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _PreviewGridPanel(gridSize: gridSize, size: panelSize),
            ],
          );
        },
      ),
    );
  }
}

class _PreviewGridPanel extends StatelessWidget {
  final int gridSize;
  final double size;
  const _PreviewGridPanel({required this.gridSize, required this.size});

  @override
  Widget build(BuildContext context) {
    const gap = 4.0;
    final cellSize = (size - 16 - gap * (gridSize - 1)) / gridSize;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFd9d9d9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(gridSize, (row) => Padding(
          padding: EdgeInsets.only(bottom: row < gridSize - 1 ? gap : 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(gridSize, (col) => Padding(
              padding: EdgeInsets.only(right: col < gridSize - 1 ? gap : 0),
              child: Container(
                width: cellSize, height: cellSize,
                decoration: BoxDecoration(
                  color: (row + col) % 2 == 0 ? Colors.white : const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(cellSize * 0.22),
                ),
              ),
            )),
          ),
        )),
      ),
    );
  }
}
// ── Envelope front painter ────────────────────────────────────────────────────
class _EnvelopeFrontPainter extends CustomPainter {
  final double flapProgress;
  const _EnvelopeFrontPainter({required this.flapProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD0D0D0)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Bottom triangle lines (V shape from corners to centre bottom)
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, size.height * 0.55)
      ..lineTo(size.width, size.height);
    canvas.drawPath(path, paint);

    // Side lines
    canvas.drawLine(Offset(0, 0), Offset(size.width / 2, size.height * 0.45), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width / 2, size.height * 0.45), paint);

    // Flap (animates closed)
    if (flapProgress > 0) {
      final flapPaint = Paint()
        ..color = const Color(0xFFDDDDDD)
        ..style = PaintingStyle.fill;
      final flapPath = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height * 0.45 * flapProgress)
        ..close();
      canvas.drawPath(flapPath, flapPaint);
      canvas.drawPath(flapPath, paint);
    }
  }

  @override
  bool shouldRepaint(_EnvelopeFrontPainter old) => old.flapProgress != flapProgress;
}

class TexturePacksScreen extends StatefulWidget {
  const TexturePacksScreen({super.key});
  @override
  State<TexturePacksScreen> createState() => _TexturePacksScreenState();
}

class _TexturePacksScreenState extends State<TexturePacksScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(children: [
            FoldsTopBar(title: 'TEXTURE PACKS', onBack: () => Navigator.pop(context)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85),
                itemCount: texturePacks.length,
                itemBuilder: (context, i) {
                  final pack = texturePacks[i];
                  final owned = AppStore.isTexturePackUnlocked(pack.id.name);
                  final active = AppStore.activeTexturePack == pack.id.name;
                  return GestureDetector(
                    onTap: () {
                      if (!owned) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Locked — redeem a code to unlock ${pack.name}'),
                          backgroundColor: const Color(0xFF2C2C2C)));
                        return;
                      }
                      setState(() => AppStore.activeTexturePack = pack.id.name);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFEFEF),
                        borderRadius: BorderRadius.circular(18),
                        border: active ? Border.all(color: const Color(0xFF4CAF50), width: 2.5) : null,
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        Expanded(
                          child: Opacity(
                            opacity: owned ? 1.0 : 0.35,
                            child: Row(children: [
                              Expanded(child: _PreviewFor(packId: pack.id.name, isBlack: true)),
                              const SizedBox(width: 6),
                              Expanded(child: _PreviewFor(packId: pack.id.name, isBlack: false)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          if (!owned) const Padding(padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.lock_rounded, size: 14, color: Colors.black38)),
                          Text(pack.name, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800,
                            color: owned ? Colors.black : Colors.black38)),
                        ]),
                        if (active) Padding(padding: const EdgeInsets.only(top: 4),
                          child: Text('ACTIVE', style: GoogleFonts.dmSans(
                            fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF4CAF50), letterSpacing: 1))),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PreviewFor extends StatelessWidget {
  final String packId;
  final bool isBlack;
  const _PreviewFor({required this.packId, required this.isBlack});
  @override
  Widget build(BuildContext context) {
    final color = isBlack ? const Color(0xFF2C2C2C) : Colors.white;
    return AspectRatio(
      aspectRatio: 1,
      child: switch (packId) {
        'pixel8' => CustomPaint(painter: PixelTexturePainter(color: color, retro: false)),
        'retroPixel' => CustomPaint(painter: PixelTexturePainter(color: color, retro: true)),
        'neon' => Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isBlack ? const Color(0xFF00E5FF) : const Color(0xFFFF2FD6), width: 2))),
        'wood' => CustomPaint(painter: WoodTexturePainter(color: color)),
        _ => Container(color: color),
      },
    );
  }
}


class _SixSMCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SixSMCard({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 160,
          decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              Center(child: Icon(icon, size: 56, color: const Color(0xFF555555))),
            ],
          ),
        ),
      ),
    );
  }
}


enum _PackShapeType { square, rectangle, circle, hexagon }

class _MenuPackCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int completedPuzzles;
  final int totalPuzzles;
  final _PackShapeType shapeType;
  final VoidCallback onPlay;
  final VoidCallback onHome;

  const _MenuPackCard({
    required this.title,
    required this.subtitle,
    required this.completedPuzzles,
    required this.totalPuzzles,
    required this.shapeType,
    required this.onPlay,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalPuzzles > 0 ? completedPuzzles / totalPuzzles : 0.0;
    final pct = (progress * 100).toInt();

    // Grid preview config per shape type
    final int gridCols = shapeType == _PackShapeType.rectangle ? 2 : 2;
    final int gridRows = shapeType == _PackShapeType.rectangle ? 3 : 2;

    Widget gridPreview = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(gridRows, (row) => Padding(
          padding: EdgeInsets.only(bottom: row < gridRows - 1 ? 6 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(gridCols, (col) => Padding(
              padding: EdgeInsets.only(right: col < gridCols - 1 ? 6 : 0),
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: (row + col) % 2 == 0 ? Colors.white : const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            )),
          ),
        )),
      ),
    );

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Grid preview replaces the text box
                  gridPreview,
                  const SizedBox(width: 16),
                  // Title + subtitle centred vertically on right side
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                          style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Progress bar spanning full card width, above bottom bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Stack(
              children: [
                Container(
                  height: 28,
                  decoration: BoxDecoration(color: const Color(0xFF44444), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      if (pct > 0)
                        Expanded(
                          flex: pct,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD465),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      Expanded(flex: 100 - pct, child: const SizedBox()),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Text('$pct%',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
                  ),
                ),
              ],
            ),
          ),
          // Bottom action bar
          Container(
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFF222222),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(child: IconButton(icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28), onPressed: onPlay)),
                Container(width: 1, height: 24, color: const Color(0xFF333333)),
                Expanded(child: IconButton(icon: const Icon(Icons.home_rounded, color: Colors.white, size: 24), onPressed: onHome)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOLIDAY PACK BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _HolidayPackBanner extends StatelessWidget {
  const _HolidayPackBanner();

  @override
  Widget build(BuildContext context) {
    final unlockDate = DateTime(2026, 06, 10);
    final now = DateTime.now();
    final isUnlocked = !now.isBefore(unlockDate);
    final daysLeft = unlockDate.difference(now).inDays + 1;
    final done = AppStore.completedInRange('x', 0, 25);

    if (isUnlocked) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const PuzzleSelectorScreen(
            packName: 'Holiday', totalPuzzles: 25, idPrefix: 'x', idOffset: 0),
        )),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1a472a), Color(0xFF2d6a2f)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('🎄', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HOLIDAY PACK', style: GoogleFonts.dmSans(
                      fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('25 festive puzzles', style: GoogleFonts.dmSans(
                      fontSize: 13, color: Colors.white60)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: done / 25,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD465)),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$done / 25 completed', style: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Text('🎄', style: TextStyle(fontSize: 28, color: Colors.black.withValues(alpha: 0.25))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HOLIDAY PACK', style: GoogleFonts.dmSans(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black38)),
                Text('Unlocks December 10, 2026', style: GoogleFonts.dmSans(
                  fontSize: 13, color: Colors.black38)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$daysLeft', style: GoogleFonts.dmSans(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
              Text('days', style: GoogleFonts.dmSans(
                fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white54)),
            ]),
          ),
        ],
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// DAILY ARCHIVE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class DailyArchiveScreen extends StatefulWidget {
  const DailyArchiveScreen({super.key});
  @override
  State<DailyArchiveScreen> createState() => _DailyArchiveScreenState();
}

class _DailyArchiveScreenState extends State<DailyArchiveScreen> {
  List<Map<String, dynamic>> _dailies = [];
  bool _loading = true;
  int _filterDifficulty = 0; // 0 = all
  int _filterStatus = 0; // 0=all, 1=completed, 2=incomplete

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await Supabase.instance.client
          .from('puzzles')
          .select('id, title, difficulty')
          .ilike('id', 'd%')
          .order('created_at', ascending: false)
          .limit(200);
      setState(() {
        _dailies = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _dailies.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  FoldsTopBar(title: 'DAILY PUZZLES', onBack: () => Navigator.pop(context)),
                  const SizedBox(height: 16),
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Center(
                            child: Text(
                              '${AppStore.dailiesCompleted} / $total',
                              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black54),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Difficulty filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      CustomFilterChip(label: 'All', active: _filterDifficulty == 0,
                        onTap: () => setState(() => _filterDifficulty = 0)),
                      const SizedBox(width: 6),
                      ...List.generate(5, (i) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: CustomFilterChip(
                          label: '${'★' * (i + 1)}',
                          active: _filterDifficulty == i + 1,
                          onTap: () => setState(() => _filterDifficulty = _filterDifficulty == i+1 ? 0 : i+1)),
                      )),
                      CustomFilterChip(label: '✓ Done', active: _filterStatus == 1,
                        onTap: () => setState(() => _filterStatus = _filterStatus == 1 ? 0 : 1)),
                      const SizedBox(width: 6),
                      CustomFilterChip(label: '○ Todo', active: _filterStatus == 2,
                        onTap: () => setState(() => _filterStatus = _filterStatus == 2 ? 0 : 2)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF2C2C2C), strokeWidth: 3)))
            else if (_dailies.isEmpty)
              Expanded(
                child: Center(
                  child: Text('No daily puzzles found',
                    style: GoogleFonts.dmSans(fontSize: 16, color: Colors.black38)),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: (() {
                      return _dailies.where((p) {
                        final id = p['id'].toString();
                        final diff = (p['difficulty'] as int?) ?? 1;
                        final done = AppStore.isCompleted(id);
                        if (_filterDifficulty > 0 && diff != _filterDifficulty) return false;
                        if (_filterStatus == 1 && !done) return false;
                        if (_filterStatus == 2 && done) return false;
                        return true;
                      }).length;
                    })(),
                    itemBuilder: (context, i) {
                      final filtered = _dailies.where((p) {
                        final id = p['id'].toString();
                        final diff = (p['difficulty'] as int?) ?? 1;
                        final done = AppStore.isCompleted(id);
                        if (_filterDifficulty > 0 && diff != _filterDifficulty) return false;
                        if (_filterStatus == 1 && !done) return false;
                        if (_filterStatus == 2 && done) return false;
                        return true;
                      }).toList();
                      final puzzle = filtered[i];
                      final id = puzzle['id'].toString();
                      final title = puzzle['title']?.toString() ?? '';
                      final num = id.replaceAll(RegExp(r'^[a-z]+'), '');
                      final difficulty = (puzzle['difficulty'] as int?) ?? 1;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: id),
                              transitionsBuilder: (_, animation, __, child) {
                                final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                                return SlideTransition(position: slide, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 320),
                            ),
                            (route) => false,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('#$num',
                                    style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                                  Row(
                                    children: List.generate(difficulty, (_) =>
                                      const Icon(Icons.star_rounded, color: Color(0xFFFFD465), size: 10)),
                                  ),
                                ],
                              ),
                              Text(title,
                                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                                  if (AppStore.isCompleted(id))
                                    Icon(
                                      Icons.check_rounded,
                                      color: AppStore.isParCompleted(id)
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFFFD465),
                                      size: 18,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: CustomBackButton(label: 'BACK TO MORE PUZZLES', onTap: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              FoldsTopBar(title: 'STORE', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 16),

              // ── Expansion discount banner ─────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black),
                          children: const [
                            TextSpan(text: 'Buy now', style: TextStyle(fontWeight: FontWeight.w800)),
                            TextSpan(text: ' and you will be eligible for '),
                            TextSpan(text: 'Expansion Discounts', style: TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('LEARN MORE',
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              
              // ── Stacked full-width packs ──────────────────
              _FullWidthStoreCard(
                title: 'NO ADS',
                subtitle: 'REMOVE ALL ADS FOREVER',
                price: '\$2.99',
                shape: StoreShape.noAds,
                productId: 'games.jaydev.folds.no_ads',
              ),
              const SizedBox(height: 12),
              _FullWidthStoreCard(
                title: 'RECTANGLE PACK',
                subtitle: '100 PUZZLES',
                price: '\$2.99',
                shape: StoreShape.rectangle,
                productId: 'games.jaydev.folds.rectangle_pack',
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text('More Puzzles Coming Soon!',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black38)),
                ),
              ),
              const SizedBox(height: 16),

              // ── Hints row ──────────────────────────────────
              Row(
                children: [
                  Expanded(child: _HintCard(label: '5 HINTS', price: '\$0.99', productId: 'games.jaydev.folds.hints_5')),
                  const SizedBox(width: 8),
                  Expanded(child: _HintCard(label: '25 HINTS', price: '\$3.99', productId: 'games.jaydev.folds.hints_25')),
                  const SizedBox(width: 8),
                  Expanded(child: _HintCard(label: '∞ HINTS', price: '\$7.99', productId: 'games.jaydev.folds.hints_unlimited')),
                ],
              ),
              const SizedBox(height: 8),

              // ─────────────────────────────────────────────────────────────────────────────
// REDEEM CODE SECTION (Add to Store UI Column)
// ─────────────────────────────────────────────────────────────────────────────
Container(
  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: const Color(0xFFE8E8E8),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'HAVE A PROMO CODE?',
        style: GoogleFonts.dmSans(
          fontSize: 14, 
          fontWeight: FontWeight.w800, 
          color: Colors.black45,
          letterSpacing: 0.5
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Redeem custom 16-digit access tokens for texture packs, puzzle packs, or unique profile marks.',
        style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54, height: 1.4),
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => _showRedeemDialog(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'ENTER 16-CHARACTER CODE',
              style: GoogleFonts.dmSans(
                fontSize: 14, 
                fontWeight: FontWeight.w700, 
                color: Colors.white,
                letterSpacing: 0.5
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
        ),
      ),
    );
  }
}



class _FullWidthStoreCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final StoreShape shape;
  final String productId;

  const _FullWidthStoreCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.shape,
    required this.productId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity,
        height: 96,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  ShapeWidget(shape: shape, size: 64),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(title,
                          style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD465),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Text(price,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ── Hint card ─────────────────────────────────────────────────────────────────
class _HintCard extends StatelessWidget {
  final String label;
  final String price;
  final String? badge;
  final String productId;

  const _HintCard({
    required this.label, required this.price, required this.productId,
  }) : badge = null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                const SizedBox(height: 10),
                Text(label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 8),
                const Icon(Icons.lightbulb_outline_rounded, color: Colors.white54, size: 28),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD465),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(price,
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black)),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -4, right: -4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFD465),
                    shape: BoxShape.circle,
                  ),
                  child: Text(badge!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black, height: 1.1)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _theme = 0;
  int _versionTapCount = 0;
  DateTime? lastVersionTap;
  bool _reducedMotion = false;
  bool _showTimer = AppStore.showTimer;
  bool _enableMs = AppStore.enableMs;
  int _movesDisplay = AppStore.movesDisplay;
  TimeOfDay _notifTime = AppStore.notifTime;
  bool _haptic = AppStore.haptic;
  double _sfx = 0.55;
  double _trackVolume = 0.4;
  bool _isPlaying = false;
  int _frameRate = 0;
  bool _staticBg = false;
  bool _dailyNotif = true;
  bool _newPacksNotif = true;
  int _handedMode = 0;
  bool _optOutData = false;
  bool _justDont = false;
  
  void _showBugReport(BuildContext ctx) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text('Report a Bug', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Describe what happened and how to reproduce it.',
            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'e.g. When I tap the 6x6 grid puzzle and...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: const Color(0xFFF5F5F5)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(dialogCtx);
              // Log to Supabase
              try {
                await Supabase.instance.client.from('bug_reports').insert({
                  'username': AppStore.displayUsername,
                  'user_id': AppStore.currentUser?.id,
                  'description': ctrl.text.trim(),
                  'created_at': DateTime.now().toIso8601String(),
                });
              } catch (_) {}
              // Grant achievement
              if (!AppStore.isUnlocked('exterminator')) {
                AppStore.unlockAchievement('exterminator');
              }
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text('Bug report sent! Thanks for helping 🐛',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                  backgroundColor: const Color(0xFF2C2C2C),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              }
            },
            child: Text('Send Report', style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _t(String text) {
    if (!_justDont) return text;
    return text.replaceAll('a', 'u').replaceAll('e', 'ee').replaceAll('o', 'aw').replaceAll('s', 'z')
               .replaceAll('A', 'U').replaceAll('E', 'EE').replaceAll('O', 'AW').replaceAll('S', 'Z');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              FoldsTopBar(title: 'SETTINGS', onBack: () => Navigator.pop(context)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16, bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader('VISUAL'),
                      SegmentedRow(
                        title: 'Theme',
                        hint: 'Based off of local time',
                        options: const ['LIGHT', 'DARK', 'AUTO'],
                        selected: _theme,
                        onChanged: (i) => setState(() => _theme = i),
                      ),
                      ToggleRow(
                        title: 'Reduced Motion',
                        subtitle: 'Disables aesthetic animations',
                        value: _reducedMotion,
                        onChanged: (v) => setState(() => _reducedMotion = v),
                      ),
                      OpenRow(
                        title: 'Texture Packs',
                        subtitle: 'Currently: ${texturePacks.firstWhere((t) => t.id.name == AppStore.activeTexturePack, orElse: () => texturePacks.first).name}',
                        onTap: () => _pushFade(context, const TexturePacksScreen()),
                      ),

                      SectionHeader('GAMEPLAY'),
                      ToggleRow(
                        title: 'Show Timer',
                        value: _showTimer,
                        onChanged: (v) => setState(() {
                          _showTimer = v;
                          AppStore.showTimer = v;
                          if (!v) {
                            _enableMs = false;
                            AppSettings.enableMs = false;
                          }
                        }),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: ToggleRow(
                          title: 'Enable Milliseconds',
                          titleSize: 15,
                          enabled: _showTimer,
                          value: _enableMs,
                          onChanged: (v) => setState(() {
                            _enableMs = v;
                            AppStore.enableMs = v;
                          }),
                        ),
                      ),
                      SegmentedRow(
                        title: 'Moves Display',
                        options: const ['DOTS', 'NUMBERS'],
                        selected: _movesDisplay,
                        onChanged: (i) => setState(() {
                          _movesDisplay = i;
                          AppStore.movesDisplay = i;
                        }),
                      ),
                      ToggleRow(
                        title: 'Haptic Vibration',
                        value: _haptic,
                        onChanged: (v) => setState(() {
                          _haptic = v;
                          AppStore.haptic = v;
                          AppSettings.haptic = v;
                        }),
                      ),

                      SectionHeader('AUDIO'),
                      SliderRow(
                        title: 'SFX',
                        value: _sfx,
                        onChanged: (v) => setState(() {
                          _sfx = v;
                          AudioService.setSfxVolume(v);
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text('Current Track',
                        style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
                      const SizedBox(height: 10),
                      TrackPlayerCard(
                        isPlaying: _isPlaying,
                        onPlayToggle: () => setState(() {
                          _isPlaying = !_isPlaying;
                          if (_isPlaying) AudioService.resumeMusic(); else AudioService.pauseMusic();
                        }),
                        volume: _trackVolume,
                        onVolumeChanged: (v) => setState(() {
                          _trackVolume = v;
                          AudioService.setMusicVolume(v);
                        }),
                      ),

                      SectionHeader('ACCOUNT & DATA'),
                      ActionPill(label: 'Restore Purchases', onTap: () {}),
                      const SizedBox(height: 10),
                      ActionPill(
                        label: 'Reset Progress',
                        textColor: const Color(0xFFE6543A),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Reset Progress?',
                                style: GoogleFonts.dmSans(fontWeight: FontWeight.w800)),
                              content: Text('This wipes all XP, completed puzzles, and rank. This cannot be undone.',
                                style: GoogleFonts.dmSans()),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true),
                                  child: Text('Reset', style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w800, color: const Color(0xFFE6543A)))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await AppStore.resetProgress();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Progress reset successfully',
                                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                                backgroundColor: const Color(0xFF2C2C2C),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ));
                            }
                          }
                        },
                      ),
                      SectionHeader('PERFORMANCE'),
                      SegmentedRow(
                        title: 'Frame Rate Cap',
                        subtitle: 'Maximum frame rate. Affects smoothness & feel',
                        options: const ['30 FPS', '60 FPS', '120 FPS'],
                        selected: _frameRate,
                        onChanged: (i) => setState(() => _frameRate = i),
                      ),
                      ToggleRow(
                        title: 'Static Backgrounds',
                        value: _staticBg,
                        onChanged: (v) => setState(() => _staticBg = v),
                      ),

                      SectionHeader('NOTIFICATIONS'),
                      ToggleRow(
                        title: 'Daily Fold Notif',
                        subtitle: 'Sends a daily reminder to do your daily Folds!',
                        value: _dailyNotif,
                        onChanged: (v) => setState(() => _dailyNotif = v),
                      ),
                      if (_dailyNotif)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Set Time',
                                style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: _notifTime,
                                  );
                                  if (picked != null) {
                                    setState(() => _notifTime = picked);
                                    AppStore.setNotifTime(picked);
                                  }
                                },
                                child: TimeDisplay(
                                  hour: _notifTime.hour.toString().padLeft(2, '0'),
                                  minute: _notifTime.minute.toString().padLeft(2, '0'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ToggleRow(
                        title: 'New Packs Notif',
                        subtitle: 'Notifies you if any new packs come out!',
                        value: _newPacksNotif,
                        onChanged: (v) => setState(() => _newPacksNotif = v),
                      ),

                      SectionHeader('ADVANCED INPUT'),
                      SegmentedRow(
                        title: 'Handed Mode',
                        subtitle: 'Flips orientation for landscape puzzles',
                        options: const ['RIGHT', 'LEFT'],
                        selected: _handedMode,
                        onChanged: (i) => setState(() => _handedMode = i),
                      ),

                      SectionHeader('PRIVACY & SECURITY'),
                      ToggleRow(
                        title: 'Opt Out of Data Usage',
                        subtitle: 'Disables using your data for personal & general enhancement',
                        value: _optOutData,
                        onChanged: (v) => setState(() => _optOutData = v),
                      ),
                      OpenRow(title: 'ToS and Privacy Policy', onTap: () => _launchUrl('https://jaydev.games/privacy')),

                      SectionHeader(_t('ABOUT & VERSIONING')),
                      OpenRow(
                        title: 'Moderator Access',
                        subtitle: 'Exclusive content for trusted members',
                        onTap: () => _pushFade(context, const ModeratorPanelScreen()),
                      ),
                      ActionPill(label: 'Report a Bug 🐛', onTap: () => _showBugReport(context)),
                      const SizedBox(height: 10),
                      ActionPill(
                        label: 'View Tutorial Again',
                        onTap: () {
                          AppStore.hasSeenOnboarding = false;
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => const OnboardingScreen(),
                              transitionsBuilder: (_, animation, __, child) =>
                                  FadeTransition(opacity: animation, child: child),
                              transitionDuration: const Duration(milliseconds: 400),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      ToggleRow(
                        title: _t('Just Dont...'),
                        subtitle: _t('Please dont toggle this on.'),
                        value: _justDont,
                        onChanged: (v) => setState(() => _justDont = v),
                      ),
                      OpenRow(title: _t('Credits'), onTap: () => _pushFade(context, const CreditsScreen())),
                      OpenRow(title: _t('Folds Website'), onTap: () => _launchUrl('https://folds.jaydev.games')),
                      OpenRow(title: _t('Socials & YouTube'), onTap: () => _pushFade(context, const SocialsScreen())),
                      const SizedBox(height: 16),
                      ActionPill(
                        label: 'Reset All Settings',
                        textColor: const Color(0xFFE6543A),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Reset All Settings?',
                                style: GoogleFonts.dmSans(fontWeight: FontWeight.w800)),
                              content: Text('All settings will return to their defaults. This cannot be undone.',
                                style: GoogleFonts.dmSans()),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true),
                                  child: Text('Reset', style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w800, color: const Color(0xFFE6543A)))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await AppStore.resetSettings();
                            setState(() {
                              _showTimer = true;
                              _enableMs = false;
                              _movesDisplay = 0;
                              _notifTime = const TimeOfDay(hour: 8, minute: 0);
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Settings reset to defaults',
                                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                                backgroundColor: const Color(0xFF2C2C2C),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ));
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            _versionTapCount++;
                            debugPrint('VERSION TAP: $_versionTapCount');
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              duration: const Duration(milliseconds: 400),
                              content: Text('Tap $_versionTapCount / 7'),
                            ));
                            if (_versionTapCount >= 7) {
                              // _versionTapCount = 0;
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const DevPanelScreen()));
                            }
                          },
                          child: Container(
                            color: Colors.transparent, // ensures the whole area is tappable, not just glyph pixels
                            padding: const EdgeInsets.all(12),
                            child: Text('version 1.0.0',
                              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text('Made with ❤️ by JayDev Games',
                          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54)),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '"If you have a dream, just go for it. Even though you\'ll never know where you\'ll end up, and even though you never know how exactly you\'ll get there; The real journey is not how you get there, but what you acheive and learn before you do."',
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text('–JayDev',
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREDITS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              FoldsTopBar(title: 'CREDITS', onBack: () => Navigator.pop(context)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 20, bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CreditsCard(role: 'Design & Development', name: 'JayDev'),
                      const SizedBox(height: 12),
                      _CreditsCard(role: 'Music & Sound Design', name: 'Thrifty & Swifty'),
                      const SizedBox(height: 12),
                      _CreditsCard(role: 'Fonts', name: 'DM Sans — Google Fonts'),
                      const SizedBox(height: 12),
                      _CreditsCard(role: 'Backend', name: 'Supabase'),
                      const SizedBox(height: 12),
                      _CreditsCard(role: 'Special Thanks', name: 'Everyone who playtested Folds'),
                      const SizedBox(height: 28),
                      Center(
                        child: Text('Made with ❤️ by JayDev Games',
                          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditsCard extends StatelessWidget {
  final String role;
  final String name;
  const _CreditsCard({required this.role, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role.toUpperCase(),
            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(name,
            style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOCIALS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SocialsScreen extends StatelessWidget {
  const SocialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              FoldsTopBar(title: 'SOCIALS', onBack: () => Navigator.pop(context)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SocialCard(
                        icon: Icons.forum_rounded,
                        iconColor: const Color(0xFF5865F2),
                        title: 'Discord',
                        subtitle: 'Stay in touch with the community, preview exclusive sneak peeks and suggest ideas.',
                        onTap: () {},
                      ),
                      
                      _SocialCard(
                        icon: Icons.smart_display_rounded,
                        iconColor: const Color(0xFFFF3B30),
                        title: 'YouTube',
                        subtitle: 'View updates, new additions and fantastic content all online.',
                        onTap: () => _launchUrl('https://www.youtube.com/@JayDevGames1'),
                      ),
                      
                      _SocialCard(
                        icon: Icons.music_note_rounded,
                        iconColor: const Color(0xFF25F4EE),
                        title: 'TikTok',
                        subtitle: 'Get regular updates, limited but exclusive behind-the-scenes videos & more.',
                        onTap: () => _launchUrl('https://www.tiktok.com/@jaydevgames'),
                      ),
                      
                      _SocialCard(
                        icon: Icons.camera_alt_rounded,
                        iconColor: const Color(0xFFE1306C),
                        title: 'Instagram',
                        subtitle: 'Get regular updates, limited but exclusive behind-the-scenes videos & more.',
                        onTap: () => _launchUrl('https://www.instagram.com/jaydev_games'),
                      ),
                      
                      _SocialCard(
                        icon: Icons.public_rounded,
                        iconColor: const Color(0xFFFFD465),
                        title: 'Website',
                        subtitle: 'View guides, updates, register, articles, content and so much more on the Folds website.',
                        onTap: () => _launchUrl('https://folds.jaydev.games'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SocialCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_SocialCard> createState() => _SocialCardState();
}

class _SocialCardState extends State<_SocialCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                      style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(widget.subtitle,
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white54, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final username = AppStore.displayUsername;
      final isMod = AppStore.isModerator;
      final filters = ['recipient.eq.all', 'recipient.eq.$username'];
      if (isMod) filters.add('recipient.eq.@Moderators');
      dynamic query = Supabase.instance.client
          .from('notifications')
          .select('id')
          .or(filters.join(','));
      final lastSeen = AppStore.lastReceiptsSeen;
      if (lastSeen != null) {
        query = query.gt('created_at', lastSeen.toIso8601String());
      }
      final data = await query;
      if (mounted) setState(() => _unreadCount = (data as List).length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: Color(0xFFE8E8E8), shape: BoxShape.circle),
                      child: Center(
                        child: Transform.rotate(
                          angle: 3.1416 / 4,
                          child: Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Colors.black, width: 2.5),
                                bottom: BorderSide(color: Colors.black, width: 2.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProfileTabBar(
                      selected: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                  ),
                  
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (AppStore.isDevProfile)
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const DevPanelScreen())),
                      child: Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(color: Color(0xFFE8E8E8), shape: BoxShape.circle),
                        child: const Icon(Icons.build_rounded, color: Color(0xFF2C2C2C), size: 18),
                      ),
                    )
                  else
                    const SizedBox(width: 40, height: 40),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptsScreen()));
                      _loadUnreadCount();
                    },
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(color: Color(0xFFE8E8E8), shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_rounded, color: Color(0xFF2C2C2C), size: 20),
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          top: -4, right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: Center(child: Text(_unreadCount > 99 ? '99+' : '$_unreadCount',
                              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
                          ),
                        ),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _tab == 0
                      ? const _ProfileTab(key: ValueKey('profile'))
                      : _tab == 1
                          ? const _StatsTab(key: ValueKey('stats'))
                          : const _AchievementsTab(key: ValueKey('achievements')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _ProfileTabBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = ['PROFILE', 'STATS', 'ACHIEVEMENTS'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFD6D6D6) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(labels[i],
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.black : Colors.black38,
                      letterSpacing: 0.5,
                    )),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({super.key});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  File? _avatarImage;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  void _loadAvatar() {
    final path = AppStore.avatarPath;
    if (path == null) return;
    if (path.startsWith('http')) {
      // cache-bust so a re-upload shows immediately instead of a stale CDN copy
      _avatarUrl = '$path?t=${DateTime.now().millisecondsSinceEpoch}';
    } else if (File(path).existsSync()) {
      _avatarImage = File(path);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _avatarImage = File(picked.path);
      _avatarUrl = null;
    });

    final user = AppStore.currentUser;
    if (user == null || user.isAnonymous) return; // guests get local-only preview
    try {
      final bytes = await File(picked.path).readAsBytes();
      final storagePath = '${user.id}/avatar.jpg';
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(storagePath, bytes,
              fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(storagePath);
      AppStore.avatarPath = publicUrl;
      setState(() {
        _avatarUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
        _avatarImage = null; // prefer the network copy going forward
      });
    } catch (e) {
      debugPrint('Avatar upload failed: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    final xp = AppStore.totalXP;
    final rank = XPSystem.rankFromXP(xp);
    final nextRank = rank + 1;
    final xpInRank = xp - XPSystem.xpForRank(rank);
    final xpNeeded = XPSystem.xpForNextRank(rank) - XPSystem.xpForRank(rank);
    final xpProgress = XPSystem.progressInRank(xp);
    final shieldColor = XPSystem.shieldColor(rank);
    final nextShieldColor = XPSystem.shieldColor(nextRank);

    // Pack progress
    final pilot4x4Done = AppStore.completedInRange('p', 0, 50);
    final pilotTotal = AppStore.completedInRange('p', 0, 100);
    final recentPack = AppStore.recentPack;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Stack(
            children: [
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEFEFEF),
                  image: _avatarImage != null
                      ? DecorationImage(image: FileImage(_avatarImage!), fit: BoxFit.cover)
                      : _avatarUrl != null
                          ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover)
                          : null,
                ),
                child: (_avatarImage == null && _avatarUrl == null)
                    ? const Icon(Icons.person_rounded, color: Color(0xFFC4C4C4), size: 72) : null,
              ),
              Positioned(
                right: 0, top: 4,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C), shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  AppStore.displayUsername,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black),
                ),
              ),
              if (AppStore.isDevProfile) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5865F2), borderRadius: BorderRadius.circular(8)),
                  child: Text('DEV', style: GoogleFonts.dmSans(
                    fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                ),
              ] else if (AppStore.isModerator) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD465), borderRadius: BorderRadius.circular(8)),
                  child: Text('MOD', style: GoogleFonts.dmSans(
                    fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 1)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(AppStore.joinDate,
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700,
                color: Colors.black38, letterSpacing: 1)),
          ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 26,
                  child: CustomPaint(
                    painter: FirePainter(
                      isDoneToday: AppStore.isStreakDoneToday,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  AppStore.currentStreak > 0
                      ? '${AppStore.currentStreak} day streak'
                      : 'No streak yet',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppStore.isStreakDoneToday
                        ? const Color(0xFFE53935)
                        : Colors.black26,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // ── ACCOUNT MANAGEMENT ROW ──────────────────────────────────────
          Builder(
            builder: (context) {
              final user = AppStore.currentUser;
              final isGuest = user == null || user.isAnonymous;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isGuest)
                    GestureDetector(
                      onTap: () async {
                        final success = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
                        if (success == true) setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
                        child: Text('SIGN IN', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                      ),
                    ),
                  if (isGuest) const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => showPublicProfile(context,
                      username: AppStore.displayUsername,
                      xp: AppStore.totalXP,
                      leaderboardRank: 0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('VIEW PROFILE', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 16),
          Container(height: 1.5, color: const Color(0xFF2C2C2C)),
          const SizedBox(height: 20),

          
          _divider(),

          // XP row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('XP', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
              Row(children: [
                Text('$xpInRank / $xpNeeded XP',
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black54)),
                const SizedBox(width: 8),
                Text('to', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
                const SizedBox(width: 8),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.shield_rounded, color: nextShieldColor, size: 32),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text('$nextRank',
                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ],
                ),
              ]),
            ],
          ),
          const SizedBox(height: 10),
          ProgressBar(progress: xpProgress, color: const Color(0xFFFFD465),
              label: '$xp XP total'),
              
          // ── SECRET DEV PANEL ───────────────────────────────────────────
          if (AppStore.isDeveloperMode) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFAEC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD465), width: 1.5),
              ),
              child: Row(
                children: [
                  Text(
                    '🛠️ DEV PANEL:',
                    style: GoogleFonts.dmSans(
                      fontSize: 12, 
                      fontWeight: FontWeight.w800, 
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // ADD +5K
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        AppStore.totalXP = AppStore.totalXP + 5000;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+5K XP',
                        style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // MULTIPLY x2
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        AppStore.totalXP = AppStore.totalXP * 2;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '×2 MULTIPLY',
                        style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          _divider(),
          

          // Recently played pack

          // Recently played pack
          if (recentPack.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recently Played',
                  style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
                GestureDetector(
                  onTap: () {
                    // Navigate to first uncompleted puzzle in recent pack
                    if (recentPack == 'PILOT') {
                      // Find first uncompleted p-series puzzle
                      String targetId = 'p1';
                      for (int i = 1; i <= 100; i++) {
                        if (!AppStore.isCompleted('p$i')) {
                          targetId = 'p$i';
                          break;
                        }
                      }
                      Navigator.pushAndRemoveUntil(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: targetId),
                          transitionsBuilder: (_, animation, __, child) {
                            final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                            return SlideTransition(position: slide, child: child);
                          },
                          transitionDuration: const Duration(milliseconds: 320),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(8)),
                    child: Text(recentPack,
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ProgressBar(
              progress: recentPack == 'PILOT'
                  ? pilotTotal / 100
                  : AppStore.completedInRange('r', 0, 100) / 100,
              color: const Color(0xFF7BD957),
              label: recentPack == 'PILOT'
                  ? '$pilotTotal / 100'
                  : '${AppStore.completedInRange('r', 0, 100)} / 100',
            ),
            _divider(),
          ],

          // Puzzles completed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Puzzles Completed',
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
              Text('$pilot4x4Done / 50 in Pilot 4x4',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 10),
          _divider(),

          
    
    

          GestureDetector(
            onTap: () async {
              final user = AppStore.currentUser;
              if (user == null || user.isAnonymous) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to manage your account.')));
              } else {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountManagementScreen()));
                setState(() {});
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text('Manage Account',
                style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black54))),
            ),
          ),
          _divider(),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Share Game',
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(const ClipboardData(
                    text: "I'm playing Folds! Check it out: https://folds.jaydev.games",
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Link copied!', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFF2C2C2C),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(14)),
                  child: Text('SHARE THE FUN',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Container(height: 1, color: const Color(0xFFEFEFEF)),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// STATS & ACHIEVEMENTS UI
// ─────────────────────────────────────────────────────────────────────────────
class _StatsTab extends StatelessWidget {
  const _StatsTab({super.key});

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
          _StatSectionLabel('OVERVIEW'),
          _StatRowItem(label: 'Total Solved', value: '${AppStore.puzzlesCompleted + dailies}'),
          _StatRowItem(label: 'Solved at Par ★', value: '$totalPar'),
          _StatRowItem(label: 'Daily Folds', value: '$dailies'),
          _StatRowItem(label: 'Current Streak', value: '${AppStore.currentStreak} 🔥'),
          _StatRowItem(label: 'Total Cells Flipped', value: '${AppStore.totalFlips}'),
          const SizedBox(height: 8),
          _StatSectionLabel('PILOT PACK'),
          _StatPackRow(label: '4×4', done: p4, total: 50),
          _StatPackRow(label: '6×6', done: p6, total: 30),
          _StatPackRow(label: '8×8', done: p8, total: 20),
          const SizedBox(height: 8),
          _StatSectionLabel('RECTANGLE PACK'),
          _StatPackRow(label: 'Rectangle', done: rect, total: 100),
          if (!DateTime.now().isBefore(DateTime(2026, 12, 10))) ...[
            const SizedBox(height: 8),
            _StatSectionLabel('HOLIDAY PACK'),
            _StatPackRow(label: 'Holiday', done: holiday, total: 25),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatSectionLabel extends StatelessWidget {
  final String text;
  const _StatSectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(text, style: GoogleFonts.dmSans(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: Colors.black38, letterSpacing: 1.2)),
  );
}

class _StatPackRow extends StatelessWidget {
  final String label;
  final int done;
  final int total;
  const _StatPackRow({required this.label, required this.done, required this.total});

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

class _StatRowItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatRowItem({required this.label, required this.value});

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

class _AchievementsTab extends StatelessWidget {
  const _AchievementsTab({super.key});

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
          _AchievementSection(label: cat.$1, ids: cat.$2),
        ],
      ],
    );
  }
}

class _AchievementSection extends StatelessWidget {
  final String label;
  final List<String> ids;
  const _AchievementSection({required this.label, required this.ids});

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

// ─────────────────────────────────────────────────────────────────────────────
// REDEEM LOGIC & POPUP MANAGEMENT
// ─────────────────────────────────────────────────────────────────────────────

void _showRedeemDialog(BuildContext outerContext) {
  final TextEditingController controller = TextEditingController();

  showDialog(
    context: outerContext,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'REDEEM TOKEN',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your 16-character alphanumeric claim token below.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 1,
              maxLength: 19,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 1),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'XXXX-XXXX-XXXX-XXXX',
                hintStyle: GoogleFonts.dmSans(color: Colors.black26, letterSpacing: 1),
                filled: true,
                fillColor: const Color(0xFFEFEFEF),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) {
                String text = val.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
                if (text.length > 16) text = text.substring(0, 16);
                
                StringBuffer buffer = StringBuffer();
                for (int i = 0; i < text.length; i++) {
                  if (i > 0 && i % 4 == 0) buffer.write('-');
                  buffer.write(text[i]);
                }
                
                final dynamicText = buffer.toString();
                controller.value = TextEditingValue(
                  text: dynamicText,
                  selection: TextSelection.collapsed(offset: dynamicText.length),
                );
              },
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // FIX: Wrap inside a strict Row component to satisfy ParentData constraints
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black45),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  final pureCode = controller.text.replaceAll('-', '');
                  if (pureCode.length != 16) {
                    ScaffoldMessenger.of(outerContext).showSnackBar(
                      const SnackBar(content: Text('Invalid length. Code must be 16 characters long.')),
                    );
                    return;
                  }
                  
                  // Dismiss using the inner dialog context
                  Navigator.pop(dialogContext);
                  
                  // Run processing using the outer persistent screen context
                  _processRedeemCode(outerContext, pureCode);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'REDEEM',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURE SUPABASE REDEEM ENGINE
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// SECURE SUPABASE REDEEM ENGINE (FIXED NAV CONTEXT)
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _processRedeemCode(BuildContext context, String code) async {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  // Normalize checking state
  final cleanedCode = code.toUpperCase().replaceAll('-', '');
  // ───────────────────────────────────────────────────────────────────────────
  // SECRET DEV INTERCEPT OVERRIDE
  // ───────────────────────────────────────────────────────────────────────────
  if (cleanedCode == 'GIVEMEINFINITEXP') {
    AppStore.isDeveloperMode = true; 
    
    // Direct feedback bypass (No network delay simulator needed)
    _showRedeemFeedback(
      context, 
      true, 
      '🛠️ Developer Tools Unlocked! Check your Profile XP bar.'
    );
    return; // Exit method immediately so it doesn't query Supabase
  }
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => const Center(
      child: CircularProgressIndicator(color: Colors.black),
    ),
  );

  try {
    final response = await Supabase.instance.client
        .from('promo_codes')
        .select()
        .eq('code', code)
        .maybeSingle();

    if (navigator.canPop()) {
      navigator.pop();
    }

    if (response == null) {
      _showRedeemFeedback(context, false, '❌ Invalid code token. Please verify and try again.');
      return; 
    }

    final bool isOneTime = response['is_one_time_use'] ?? false;
    final bool isClaimed = response['is_claimed'] ?? false;
    final String rewardType = response['reward_type'] ?? '';
    final String rewardValue = response['reward_value'] ?? '';

    if (isOneTime && isClaimed) {
      _showRedeemFeedback(context, false, '❌ This limited-use code has already been claimed.');
      return;
    }

    if (isOneTime) {
      await Supabase.instance.client
          .from('promo_codes')
          .update({'is_claimed': true})
          .eq('code', code);
    }

    String successMessage = '🎉 Reward Successfully Redeemed!';
    if (rewardType == 'xp') {
      final int xpAmount = int.tryParse(rewardValue) ?? 0;
      AppStore.totalXP = AppStore.totalXP + xpAmount;
      successMessage = '🎉 $xpAmount XP successfully credited to your profile!';
    } else if (rewardType == 'texture') {
      AppStore.unlockTexturePack(rewardValue);
      final def = texturePacks.firstWhere((t) => t.id.name == rewardValue, orElse: () => texturePacks.first);
      successMessage = '🎨 "${def.name}" texture pack unlocked! Equip it in Settings → Texture Packs.';
    } else if (rewardType == 'skin') {
      successMessage = '💎 ${rewardValue.toUpperCase()} grid style skin unlocked!';
    } else if (rewardType == 'pack') {
      successMessage = '📦 Special level bundle "$rewardValue" unlocked!';
    }

    _showRedeemFeedback(context, true, successMessage);

  } catch (e) {
    if (navigator.canPop()) {
      navigator.pop();
    }
    _showRedeemFeedback(context, false, '⚠️ Network/Server error. Check connection.');
    debugPrint("Redeem failure: $e");
  }
}

void _showRedeemFeedback(BuildContext context, bool success, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: success ? const Color(0xFF2C2C2C) : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      content: Text(
        message,
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
      ),
    ),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE DEVELOPER CONTROL PANEL
// ─────────────────────────────────────────────────────────────────────────────
class DeveloperXPMultiplier extends StatefulWidget {
  const DeveloperXPMultiplier({super.key});

  @override
  State<DeveloperXPMultiplier> createState() => _DeveloperXPMultiplierState();
}

class _DeveloperXPMultiplierState extends State<DeveloperXPMultiplier> {
  @override
  Widget build(BuildContext context) {
    if (!AppStore.isDeveloperMode) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD465), width: 1.5),
      ),
      child: Row(
        children: [
          Text(
            '🛠️ DEV PANEL:',
            style: GoogleFonts.dmSans(
              fontSize: 12, 
              fontWeight: FontWeight.w800, 
              color: Colors.black,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                AppStore.totalXP = AppStore.totalXP + 5000;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('⚡ Added +5,000 Dev XP!')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+5K XP',
                style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                AppStore.totalXP = AppStore.totalXP * 2;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🚀 XP Multiplied by 2x!')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '×2 MULTIPLY',
                style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  switch (day % 10) {
    case 1: return '${day}st';
    case 2: return '${day}nd';
    case 3: return '${day}rd';
    default: return '${day}th';
  }
}

String _formatFullDate(DateTime dt) {
  const months = ['','January','February','March','April','May','June',
      'July','August','September','October','November','December'];
  return '${_ordinal(dt.day)} ${months[dt.month]}';
}
void _showBadgeInfoDialog(BuildContext context, {required String username, required bool isDev, DateTime? modSince}) {
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
          Text('Mod since ${_formatFullDate(modSince)}',
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

class ModsAndDevsScreen extends StatelessWidget {
  const ModsAndDevsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(children: [
            FoldsTopBar(title: 'MODS & DEVS', onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 20, bottom: 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.shield_rounded, color: Color(0xFFFFD465), size: 28),
                    const SizedBox(width: 10),
                    Text('Moderators', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    'Moderators help keep the Folds community friendly, respectful and spam-free. '
                    'They can send announcements to specific players or the whole community, and help '
                    'review reports submitted through public profiles.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),
                  const SizedBox(height: 14),
                  Text('How rare is it?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'Extremely. Moderators are hand-picked by the developer based on how they show up in the '
                    'community — helpfulness, patience, and good judgement. There is no application form and '
                    'no guaranteed path — most players will never be one.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),
                  
                  const SizedBox(height: 14),

                  Text('Can I request it?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'There is a request option in Settings → Moderator Access, but sending a request doesn\'t '
                    'guarantee approval — it just puts your name forward. Being visibly kind and helpful in the '
                    'community is worth far more than requesting.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),

                  const SizedBox(height: 14),

                  Text('Do Moderators have an unfair advantage in the game?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'No. Moderators do not have any special access to puzzles, answers, or game data. They are '
                    'simply trusted members of the community who help keep the game safe and enjoyable for'
                    'everyone, however they sometimes receive certain packs before everyone else as rewards '
                    'for their efforts in the community and bugfixing. This is a perk, not an advantage, '
                    'and XP is not rewarded for unreleased packs, or until everyone can play it.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),

                  const SizedBox(height: 14),

                Text('Do Moderators get paid?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'No. Being a moderator is a voluntary position. It is a badge of trust and respect, not '
                  'a paid job. They are not directly paid for being a Moderator, however they can receive '
                  'certain packs or in-game purchases for free using promo-codes. These aren\'t limited to '
                  'Moderators, but it would be more likely for a Moderator to receive these than a regular '
                  'player.',
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),

                const SizedBox(height: 14),

                Text('What if a Moderator breaks the rules?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'If you see a Moderator abuse their power, or break Folds Rules, you can report them just '
                  'like any other player. The developer will review the report and take necessary action. '
                  'Moderators are held to a higher standard than any other player, and if they break the rules '
                  'in any way they will be demoted and lose their Moderator status. Moderators are not above the '
                  'rules and expected to follow them at all times with no exceptions.',
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),

                const SizedBox(height: 14),

                Text('How can I improve my chances of becoming a Moderator?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'You can mainly interact with the community in the JayDev Games Discord server \(you can find '
                  'the invite link in the Socials Screen). Be helpful, patient, and kind to others. Consistently '
                  'being engaging and respectful dramatically increases your chances of being a Moderator more '
                  'than any request or waiting period. This doesn\'t guarantee Moderator roles, but improves chances '
                  'of them. If you believe you have what it takes, and have been a positive member of the community, '
                  'you can speak about it in the JayDev Games Discord server.',
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),
                
                const SizedBox(height: 14),

                Text('Can Moderators leak content in upcoming updates?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'No. Moderators can have access to upcoming unreleased content which is for the eyes for themselves '
                  'and other Moderators only. If a Moderator leaks content, please'
                  'the invite link in the Socials Screen). Be helpful, patient, and kind to others. Consistently '
                  'being engaging and respectful dramatically increases your chances of being a Moderator more '
                  'than any request or waiting period. This doesn\'t guarantee Moderator roles, but improves chances '
                  'of them. If you believe you have what it takes, and have been a positive member of the community, '
                  'you can speak about it in the JayDev Games Discord server.',
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),

                const SizedBox(height: 14),

                Text('Can Moderators ban or manage my game account?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'No. Moderators cannot ban, suspend, or manage your game account in any way. They can, however, report '
                  'your account to the developer if they believe you are breaking the Folds Rules, and their opinion will be '
                  'highly regarded. Only the Developer can take action on your account, and will review any reports made by '
                  'Moderators or any other player. If you believe a Moderator has unfairly reported you, you can appeal the ban '
                  'or restriction, or report by contacting the Developer at support@jaydev.games.',
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),



                  const SizedBox(height: 28),
                  Container(height: 1, color: const Color(0xFFEFEFEF)),
                  const SizedBox(height: 28),
                  Row(children: [
                    const Icon(Icons.code_rounded, color: Color(0xFF5865F2), size: 28),
                    const SizedBox(width: 10),
                    Text('Developer', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    'Folds is built and maintained by a single developer, JayDev. Every puzzle, every line '
                    'of code, and every update comes from one person. There is only ever one Developer badge, '
                    'and it isn\'t given out; it belongs to whoever made the game.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),

                    const SizedBox(height: 14),
                  Text('What if I see the Developer break the rules?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'The Developer is expected to follow the same rules but can take the necessary action to '
                    'any player upon their wishes. It is highly guaranteed the Developer\'s actions are always '
                    'in the best interest of the game and community, and are justified to fit the situation. If '
                    'you have a problem or issue with the Developer\'s actions, you can reach out to them directly '
                    'by mailing them at support@jaydev.games.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),
                  
                  const SizedBox(height: 14),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODERATOR PANEL
// ─────────────────────────────────────────────────────────────────────────────
class ModeratorPanelScreen extends StatefulWidget {
  const ModeratorPanelScreen({super.key});
  @override
  State<ModeratorPanelScreen> createState() => _ModeratorPanelScreenState();
}

class _ModeratorPanelScreenState extends State<ModeratorPanelScreen> {
  bool _requesting = false;
  String? _requestStatus; // null, 'approved', 'pending', 'error'
  String _approvedUsername = '';

  Future<void> _request() async {
    if (AppStore.currentUser == null) {
      _showResult('error');
      return;
    }
    setState(() => _requesting = true);
    try {
      final result = await Supabase.instance.client.rpc('request_moderator') as String;
      if (result.startsWith('approved:')) {
        final uname = result.split(':')[1];
        AppStore.isModerator = true;
        setState(() {
          _approvedUsername = uname;
          _requestStatus = 'approved';
        });
        _showResult('approved');
      } else {
        setState(() => _requestStatus = 'pending');
        _showResult('pending');
      }
    } catch (_) {
      _showResult('error');
    }
    setState(() => _requesting = false);
  }

  void _showResult(String status) {
    final msgs = {
      'approved': ('Request Successful! 🎉', '$_approvedUsername is now a Moderator.'),
      'pending': ('Request Received', 'You have not been approved for Moderator yet. Please check with the developer.'),
      'error': ('Request Failed', 'Could not process your request. Make sure you\'re signed in and try again.'),
    };
    final pair = msgs[status]!;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Text(pair.$1, style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 20)),
      content: Text(pair.$2, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54)),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(ctx),
          child: Text('OK', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isMod = AppStore.isModerator;
    final isSignedIn = AppStore.currentUser != null && !AppStore.currentUser!.isAnonymous;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              FoldsTopBar(title: 'MOD ACCESS', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 24),

              if (isMod) ...[
                // Mod active state
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2C2C2C), Color(0xFF444444)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD465).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.shield_rounded, color: Color(0xFFFFD465), size: 30)),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Moderator', style: GoogleFonts.dmSans(
                        fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('You have exclusive access', style: GoogleFonts.dmSans(
                        fontSize: 13, color: Colors.white54)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const PuzzleSelectorScreen(
                      packName: 'MOD Exclusive', totalPuzzles: 20, idPrefix: 'mod', idOffset: 0))),
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Icon(Icons.lock_open_rounded, color: Color(0xFFFFD465), size: 28),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('MOD EXCLUSIVE PACK', style: GoogleFonts.dmSans(
                          fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('20 exclusive puzzles', style: GoogleFonts.dmSans(
                          fontSize: 13, color: Colors.white54)),
                      ]),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    const Icon(Icons.preview_rounded, color: Colors.black38),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Early Access Previews', style: GoogleFonts.dmSans(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                      Text('Upcoming packs appear here before public release.',
                        style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ModeratorNotifyScreen())),
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Icon(Icons.campaign_rounded, color: Color(0xFFFFD465), size: 24),
                      const SizedBox(width: 12),
                      Text('SEND ANNOUNCEMENT', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                    ]),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () { AppStore.isModerator = false; setState(() {}); },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text('Sign Out of Mod Access',
                      style: GoogleFonts.dmSans(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black45))),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 40),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.shield_outlined, color: Colors.white38, size: 40)),
                const SizedBox(height: 20),
                Text('Moderator Access', style: GoogleFonts.dmSans(
                  fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  isSignedIn
                      ? 'Press REQ below. If your username has been pre-approved, you\'ll receive moderator status immediately.'
                      : 'You must be signed in to request moderator access.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.5)),
                const SizedBox(height: 48),
                if (isSignedIn)
                  GestureDetector(
                    onTap: _requesting ? null : _request,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C), shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20, offset: const Offset(0, 8))]),
                      child: Center(
                        child: _requesting
                            ? const SizedBox(width: 28, height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3, color: Colors.white))
                            : Text('REQ', style: GoogleFonts.dmSans(
                                fontSize: 20, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: 1)),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AuthScreen())),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(14)),
                      child: Center(child: Text('Sign In First',
                        style: GoogleFonts.dmSans(
                          fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEADERBOARD
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
  try {
    final data = await Supabase.instance.client
          .from('profiles')
          .select('username, total_xp, avatar_path, is_moderator, is_dev_profile, mod_since')
          .order('total_xp', ascending: false)
          .limit(50);
        
    // Convert the database paths into actual functional bucket URLs
    final parsedEntries = List<Map<String, dynamic>>.from(data).map((row) {
      final rawPath = row['avatar_path'] as String?;
      if (rawPath != null && rawPath.isNotEmpty && !rawPath.startsWith('http')) {
        row['avatar_path'] = Supabase.instance.client.storage.from('avatars').getPublicUrl(rawPath);
      }
      return row;
    }).toList();

    setState(() {
      _entries = parsedEntries;
      _loading = false;
    });
  } catch (e) {
    setState(() { _error = 'Could not load rankings.'; _loading = false; });
  }
}


  @override
  Widget build(BuildContext context) {
    final myId = AppStore.currentUser?.id;
    final myXP = AppStore.totalXP;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              FoldsTopBar(title: 'TOP FOLDERS', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 16),
              // My rank card
              if (AppStore.currentUser != null)
                Builder(builder: (context) {
                  final myPos = _entries.indexWhere(
                    (e) => e['total_xp'] == myXP && e['username'] == AppStore.displayUsername);
                  final rank = myPos >= 0 ? myPos + 1 : null;
                  final shieldColor = XPSystem.shieldColor(XPSystem.rankFromXP(myXP));
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      Stack(alignment: Alignment.center, children: [
                        Icon(Icons.shield_rounded, color: shieldColor, size: 36),
                        Text('${XPSystem.rankFromXP(myXP)}',
                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                      ]),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('You', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('$myXP XP', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white54)),
                      ])),
                      if (rank != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: rank <= 3 ? const Color(0xFFFFD465) : Colors.white12,
                            borderRadius: BorderRadius.circular(10)),
                          child: Text('#$rank',
                            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800,
                              color: rank <= 3 ? Colors.black : Colors.white)),
                        ),
                    ]),
                  );
                }),
              // List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2C2C2C), strokeWidth: 3))
                    : _error != null
                        ? Center(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black38)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: const Color(0xFF2C2C2C),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: _entries.length,
                              itemBuilder: (context, i) {
                                final e = _entries[i];
                                final rank = i + 1;
                                final xp = (e['total_xp'] as int?) ?? 0;
                                final username = e['username']?.toString() ?? 'Folder';
                                final xpRank = XPSystem.rankFromXP(xp);
                                final shieldColor = XPSystem.shieldColor(xpRank);
                                final isTop3 = rank <= 3;
                                final medals = ['🥇', '🥈', '🥉'];

                                return GestureDetector(
                                  onTap: () => showPublicProfile(context,
                                    username: username,
                                    xp: xp,
                                    leaderboardRank: rank,
                                  ),
                                  child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isTop3 ? const Color(0xFF2C2C2C) : const Color(0xFFEFEFEF),
                                    borderRadius: BorderRadius.circular(14),
                                    border: rank == 1 ? Border.all(color: const Color(0xFFFFD465), width: 1.5) : null,
                                  ),
                                  child: Row(children: [
                                    SizedBox(
                                      width: 36,
                                      child: isTop3
                                          ? Text(medals[i], style: const TextStyle(fontSize: 22))
                                          : Text('#$rank', style: GoogleFonts.dmSans(
                                              fontSize: 14, fontWeight: FontWeight.w700,
                                              color: Colors.black38)),
                                    ),
                                    const SizedBox(width: 10),
                                    Stack(alignment: Alignment.center, children: [
                                      Icon(Icons.shield_rounded, color: shieldColor, size: 30),
                                      Text('$xpRank',
                                        style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                                    ]),
                                    const SizedBox(width: 12),
                                    Expanded(child: Row(children: [
                                      Flexible(child: Text(username,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800,
                                          color: isTop3 ? Colors.white : Colors.black))),
                                      if ((e['is_dev_profile'] as bool?) == true || (e['is_moderator'] as bool?) == true) ...[
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () {
                                            DateTime? ms;
                                            final raw = e['mod_since'] as String?;
                                            if (raw != null) { try { ms = DateTime.parse(raw); } catch (_) {} }
                                            _showBadgeInfoDialog(context,
                                              username: username,
                                              isDev: (e['is_dev_profile'] as bool?) ?? false,
                                              modSince: ms);
                                          },
                                          child: Icon(
                                            (e['is_dev_profile'] as bool?) == true ? Icons.code_rounded : Icons.shield_rounded,
                                            size: 15,
                                            color: (e['is_dev_profile'] as bool?) == true
                                              ? const Color(0xFF5865F2) : const Color(0xFFFFD465)),
                                        ),
                                      ],
                                    ])),
                                    Text('$xp XP',
                                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700,
                                        color: isTop3 ? Colors.white54 : Colors.black38)),
                                  ]),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC PROFILE POPUP
// ─────────────────────────────────────────────────────────────────────────────
void showPublicProfile(BuildContext context, {
  required String username,
  required int xp,
  required int leaderboardRank,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PublicProfileSheet(
      username: username,
      xp: xp,
      leaderboardRank: leaderboardRank,
    ),
  );
}

class _PublicProfileSheet extends StatefulWidget {
  final String username;
  final int xp;
  final int leaderboardRank;
  const _PublicProfileSheet({required this.username, required this.xp, required this.leaderboardRank});
  @override
  State<_PublicProfileSheet> createState() => _PublicProfileSheetState();
}

class _PublicProfileSheetState extends State<_PublicProfileSheet> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
  try {
    final data = await Supabase.instance.client
        .from('profiles')
        .select('username, total_xp, join_date, completed_puzzles, is_moderator, is_dev_profile, avatar_path, mod_since')
        .eq('username', widget.username)
        .maybeSingle();
        
    if (data != null) {
      final rawPath = data['avatar_path'] as String?;
      if (rawPath != null && rawPath.isNotEmpty && !rawPath.startsWith('http')) {
        data['avatar_path'] = Supabase.instance.client.storage.from('avatars').getPublicUrl(rawPath);
      }
    }

    setState(() { _profile = data; _loading = false; });
  } catch (_) {
    setState(() => _loading = false);
  }
}


  void _showBlockConfirm() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text('Block ${widget.username}?', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text('They won\'t appear in your leaderboard or be able to interact with you.',
          style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${widget.username} blocked.',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                backgroundColor: const Color(0xFF2C2C2C),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
            child: Text('Block', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportConfirm() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text('Report ${widget.username}', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Tell us why you\'re reporting this user.',
            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. Inappropriate username...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: const Color(0xFFF5F5F5)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);
              try {
                await Supabase.instance.client.from('user_reports').insert({
                  'reporter_username': AppStore.displayUsername,
                  'reported_username': widget.username,
                  'reason': ctrl.text.trim(),
                  'created_at': DateTime.now().toIso8601String(),
                });
              } catch (_) {}
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Report submitted. Thank you.',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                  backgroundColor: const Color(0xFF2C2C2C),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              }
            },
            child: Text('Submit', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final xp = _profile != null ? ((_profile!['total_xp'] as int?) ?? 0) : widget.xp;
    final rank = XPSystem.rankFromXP(xp);
    final shieldColor = XPSystem.shieldColor(rank);
    final joinDate = (_profile?['join_date'] as String?) ?? '';
    final completed = ((_profile?['completed_puzzles'] as List?)?.length) ?? 0;
    final isMod = (_profile?['is_moderator'] as bool?) ?? false;
    final isDev = (_profile?['is_dev_profile'] as bool?) ?? false;
    DateTime? modSince;
    final modSinceRaw = _profile?['mod_since'] as String?;
    if (modSinceRaw != null) { try { modSince = DateTime.parse(modSinceRaw); } catch (_) {} }
    final avatarUrl = _profile?['avatar_path'] as String?;
    final isNetworkUrl = avatarUrl != null && avatarUrl.startsWith('http');
    final username = (_profile?['username'] as String?) ?? widget.username;
    final isOwnProfile = username == AppStore.displayUsername;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Color(0xFFF0F0F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(
                        color: Color(0xFF2C2C2C), strokeWidth: 3)))
                  : Column(children: [
                      // Avatar
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEFEFEF),
                          image: isNetworkUrl ? DecorationImage(
                            image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                        ),
                        child: !isNetworkUrl
                            ? const Icon(Icons.person_rounded, color: Color(0xFFC4C4C4), size: 48)
                            : null,
                      ),
                      const SizedBox(height: 14),
                      // Username + badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(username, textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black)),
                          ),
                          if (isDev) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showBadgeInfoDialog(context, username: username, isDev: true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5865F2), borderRadius: BorderRadius.circular(8)),
                                child: Text('DEV', style: GoogleFonts.dmSans(
                                  fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                            ),
                          ] else if (isMod) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showBadgeInfoDialog(context, username: username, isDev: false, modSince: modSince),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD465), borderRadius: BorderRadius.circular(8)),
                                child: Text('MOD', style: GoogleFonts.dmSans(
                                  fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (joinDate.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(joinDate, style: GoogleFonts.dmSans(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.black38, letterSpacing: 1)),
                      ],
                      const SizedBox(height: 20),
                      // Stats card
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: IntrinsicHeight(
                          child: Row(children: [
                            Expanded(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(xp.toString(), style: GoogleFonts.dmSans(
                                  fontSize: 28, fontWeight: FontWeight.w800)),
                                Text('XP', style: GoogleFonts.dmSans(
                                  fontSize: 13, color: Colors.black38, fontWeight: FontWeight.w600)),
                              ],
                            )),
                            Container(width: 1, color: const Color(0xFFEFEFEF)),
                            Expanded(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (widget.leaderboardRank > 0)
                                  Text('#${widget.leaderboardRank}', style: GoogleFonts.dmSans(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38)),
                                Stack(alignment: Alignment.center, children: [
                                  Icon(Icons.shield_rounded, color: shieldColor, size: 52),
                                  Text('$rank', style: GoogleFonts.dmSans(
                                    fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                                ]),
                              ],
                            )),
                            Container(width: 1, color: const Color(0xFFEFEFEF)),
                            Expanded(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$completed', style: GoogleFonts.dmSans(
                                  fontSize: 28, fontWeight: FontWeight.w800)),
                                Text('Folds\nCompleted', textAlign: TextAlign.center,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13, color: Colors.black38, fontWeight: FontWeight.w600)),
                              ],
                            )),
                          ]),
                        ),
                      ),
                      if (!isOwnProfile) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _showReportConfirm,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFEFEF),
                                  borderRadius: BorderRadius.circular(14)),
                                child: Center(child: Text('Report',
                                  style: GoogleFonts.dmSans(fontSize: 14,
                                    fontWeight: FontWeight.w700, color: Colors.black45))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: _showBlockConfirm,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(14)),
                                child: Center(child: Text('Block',
                                  style: GoogleFonts.dmSans(fontSize: 14,
                                    fontWeight: FontWeight.w700, color: Colors.red))),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ]),
            ),
          ),
        ],
      ),
    );
  }
}

class DevPanelScreen extends StatefulWidget {
  const DevPanelScreen({super.key});
  @override
  State<DevPanelScreen> createState() => _DevPanelScreenState();
}

class _DevPanelScreenState extends State<DevPanelScreen> {
  bool _unlocked = AppStore.isDevProfile;
  final _passCtrl = TextEditingController();

  void _confirm(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error ? Colors.redAccent : const Color(0xFF2C2C2C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white))),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build_rounded, size: 48, color: Color(0xFF2C2C2C)),
                const SizedBox(height: 16),
                Text('Developer Panel', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: const Color(0xFFF5F5F5),
                  ),
                  onSubmitted: (_) {
                    if (_passCtrl.text == kDevPassword) {
                      AppStore.isDevProfile = true;
                      setState(() => _unlocked = true);
                    } else {
                      _confirm('Wrong password', error: true);
                    }
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C)),
                  onPressed: () {
                    if (_passCtrl.text == kDevPassword) {
                      AppStore.isDevProfile = true;
                      setState(() => _unlocked = true);
                    } else {
                      _confirm('Wrong password', error: true);
                    }
                  },
                  child: Text('Unlock', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2C2C2C),
          title: Text('DEVELOPER PANEL', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
          leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: const Color(0xFFFFD465),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: const [
              Tab(text: 'XP & PUZZLES'), Tab(text: 'PACKS'), Tab(text: 'STREAKS'),
              Tab(text: 'MODERATORS'), Tab(text: 'NOTIFICATIONS'), Tab(text: 'NUCLEAR'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _buildXpTab(), _buildPacksTab(), _buildStreaksTab(),
          _buildModTab(), _buildNotifTab(), _buildNuclearTab(),
        ]),
      ),
    );
  }

  Widget _buildXpTab() {
    final xpCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DevLabel('XP — Current: ${AppStore.totalXP} (Rank ${XPSystem.rankFromXP(AppStore.totalXP)})'),
        Row(children: [
          Expanded(child: TextField(controller: xpCtrl, keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'XP to add', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C)),
            onPressed: () {
              final amt = int.tryParse(xpCtrl.text) ?? 0;
              AppStore.totalXP = AppStore.totalXP + amt;
              xpCtrl.clear();
              _confirm('Added $amt XP — total ${AppStore.totalXP}');
            },
            child: Text('Add', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ]),
        DevLabel('SPECIFIC PUZZLE'),
        TextField(controller: idCtrl, decoration: InputDecoration(
          hintText: 'e.g. p1, r5, d3, x12', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          DevChip(label: 'Complete ✓', onTap: () {
            final id = idCtrl.text.trim().toLowerCase();
            if (id.isEmpty) { _confirm('Enter a puzzle ID first', error: true); return; }
            AppStore.markCompleted(id); AppStore.markParCompleted(id);
            _confirm('$id marked complete');
          }),
          DevChip(label: 'Open Puzzle', onTap: () {
            final id = idCtrl.text.trim().toLowerCase();
            if (id.isEmpty) { _confirm('Enter a puzzle ID first', error: true); return; }
            Navigator.push(context, MaterialPageRoute(builder: (_) => GameplayScreen(initialPuzzleId: id)));
          }),
        ]),
      ]),
    );
  }

  Widget _buildPacksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          DevChip(label: 'All Pilot ✓', onTap: () {
            for (int i = 1; i <= 100; i++) { AppStore.markCompleted('p$i'); AppStore.markParCompleted('p$i'); }
            _confirm('Pilot pack completed');
          }),
          DevChip(label: 'All Rectangle ✓', onTap: () {
            for (int i = 1; i <= 100; i++) { AppStore.markCompleted('r$i'); AppStore.markParCompleted('r$i'); }
            _confirm('Rectangle pack completed');
          }),
          DevChip(label: 'All Holiday ✓', onTap: () {
            for (int i = 1; i <= 25; i++) { AppStore.markCompleted('x$i'); AppStore.markParCompleted('x$i'); }
            _confirm('Holiday pack completed');
          }),
        ]),
        DevLabel('TEXTURE PACKS'),
        Wrap(spacing: 8, runSpacing: 8, children: texturePacks.where((t) => !t.isDefault).map((t) =>
          DevChip(label: 'Unlock ${t.name}', onTap: () {
            AppStore.unlockTexturePack(t.id.name);
            _confirm('${t.name} unlocked');
          })).toList()),
      ]),
    );
  }

  Widget _buildStreaksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        DevChip(label: '🔥 Set 7', onTap: () { AppStore.devSetStreak(7); _confirm('Streak set to 7'); }),
        DevChip(label: '🔥 Set 30', onTap: () { AppStore.devSetStreak(30); _confirm('Streak set to 30'); }),
        DevChip(label: 'Reset Streak', onTap: () { AppStore.devResetStreak(); _confirm('Streak reset'); }),
        DevChip(label: 'Mark Daily Done', onTap: () {
          final dayNumber = foldsDayNumberFor(DateTime.now());
          if (dayNumber > 0) {
            AppStore.markCompleted('d$dayNumber');
            AppStore.updateStreak();
            _confirm('Day $dayNumber marked done, streak updated');
          } else {
            _confirm('Folds hasn\'t launched yet (day $dayNumber)', error: true);
          }
        }),
      ]),
    );
  }

  Widget _buildModTab() {
    final modCtrl = TextEditingController();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: modCtrl, decoration: InputDecoration(
          hintText: 'Username', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          DevChip(label: '✓ Approve Mod', onTap: () async {
            final u = modCtrl.text.trim();
            if (u.isEmpty) { _confirm('Enter a username', error: true); return; }
            try {
              await Supabase.instance.client.rpc('approve_moderator', params: {'target_username': u});
              _confirm('$u approved as moderator');
            } catch (e) { _confirm('$e', error: true); }
          }),
          DevChip(label: '✕ Revoke Mod', onTap: () async {
            final u = modCtrl.text.trim();
            if (u.isEmpty) { _confirm('Enter a username', error: true); return; }
            try {
              await Supabase.instance.client.rpc('revoke_moderator', params: {'target_username': u});
              _confirm('$u revoked');
            } catch (e) { _confirm('$e', error: true); }
          }),
        ]),
      ]),
    );
  }

  Widget _buildNotifTab() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String recipient = 'all';
    String? background;
    const bgOptions = <String, Color>{
      'Default': Color(0xFFEFEFEF),
      'Gold': Color(0xFFFFD465),
      'Green': Color(0xFF7BD957),
      'Blue': Color(0xFF5865F2),
      'Red': Color(0xFFE6543A),
    };
    return StatefulBuilder(
      builder: (context, setLocal) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DevLabel('SEND NOTIFICATION'),
            TextField(controller: titleCtrl, decoration: InputDecoration(
              hintText: 'Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 8),
            TextField(controller: bodyCtrl, maxLines: 3, decoration: InputDecoration(
              hintText: 'Message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 12),
            DevLabel('RECIPIENT'),
            _RecipientPicker(initial: 'all', onSelected: (v) => recipient = v),
            const SizedBox(height: 12),
            DevLabel('BACKGROUND'),
            Wrap(spacing: 8, runSpacing: 8, children: bgOptions.entries.map((e) {
              final isSelected = background == e.key || (background == null && e.key == 'Default');
              return GestureDetector(
                onTap: () => setLocal(() => background = e.key == 'Default' ? null : e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: e.value,
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                  ),
                  child: Text(e.key, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C)),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) { _confirm('Enter a title', error: true); return; }
                if (!await _isValidRecipient(recipient)) {
                  _confirm('No profile found for "$recipient"', error: true);
                  return;
                }
                try {
                  await Supabase.instance.client.from('notifications').insert({
                    'title': titleCtrl.text.trim(),
                    'body': bodyCtrl.text.trim(),
                    'recipient': recipient,
                    'author': AppStore.displayUsername,
                    'background': background,
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  _confirm('Notification sent to $recipient');
                  titleCtrl.clear(); bodyCtrl.clear();
                } catch (e) { _confirm('$e', error: true); }
              },
              child: Text('Send', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildNuclearTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        DevBtn(label: '⚠️ Reset ALL Progress', textColor: Colors.red, onTap: () async {
          final go = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
            title: const Text('Reset everything?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm')),
            ],
          ));
          if (go == true) { await AppStore.resetProgress(); _confirm('Progress wiped'); }
        }),
        DevBtn(label: '⚠️ Reset All Settings', textColor: Colors.orange, onTap: () async {
          await AppStore.resetSettings();
          _confirm('Settings reset');
        }),
      ]),
    );
  }
}

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});
  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  List<Map<String, dynamic>> _receipts = [];
  bool _loading = true;
  final Set<int> _expanded = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final username = AppStore.displayUsername;
      final isMod = AppStore.isModerator;
      final filters = ['recipient.eq.all', 'recipient.eq.$username'];
      if (isMod) filters.add('recipient.eq.@Moderators');
      final data = await Supabase.instance.client
          .from('notifications')
          .select()
          .or(filters.join(','))
          .order('created_at', ascending: false)
          .limit(100);
      setState(() { _receipts = List<Map<String, dynamic>>.from(data); _loading = false; });
      await AppStore.markReceiptsSeen();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Color _bgColor(String? key) {
    const map = {
      'Gold': Color(0xFFFFD465), 'Green': Color(0xFF7BD957),
      'Blue': Color(0xFF5865F2), 'Red': Color(0xFFE6543A),
    };
    return map[key] ?? const Color(0xFFEFEFEF);
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(dateOnly).inDays;
    if (diff == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff > 0 && diff < 7) {
      const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      return days[dt.weekday - 1];
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _resolveRecipientLabel(String recipient) {
    if (recipient == 'all') return 'Everyone';
    if (recipient == '@Moderators') return 'Moderators';
    return 'You specifically';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(children: [
            FoldsTopBar(title: 'RECEIPTS', onBack: () => Navigator.pop(context)),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2C2C2C)))
                  : _receipts.isEmpty
                      ? Center(child: Text('No notifications yet',
                          style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black38)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _receipts.length,
                            itemBuilder: (context, i) {
                              final r = _receipts[i];
                              final isExpanded = _expanded.contains(i);
                              DateTime? created;
                              try { created = DateTime.parse(r['created_at'].toString()); } catch (_) {}
                              final bg = _bgColor(r['background'] as String?);
                              final isColored = r['background'] != null;
                              return GestureDetector(
                                onTap: () => setState(() =>
                                  isExpanded ? _expanded.remove(i) : _expanded.add(i)),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      Expanded(child: Text(r['title']?.toString() ?? '',
                                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87))),
                                      if (created != null)
                                        Text(_formatDate(created), style: GoogleFonts.dmSans(
                                          fontSize: 11, fontWeight: FontWeight.w700,
                                          color: isColored ? Colors.black54 : Colors.black38)),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(r['body']?.toString() ?? '',
                                      maxLines: isExpanded ? null : 2,
                                      overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54)),
                                    if (isExpanded) ...[
                                      const SizedBox(height: 10),
                                      Row(children: [
                                        const Icon(Icons.person_rounded, size: 14, color: Colors.black38),
                                        const SizedBox(width: 4),
                                        Text('From: ${r['author']?.toString() ?? 'Folds Team'}',
                                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
                                      ]),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        const Icon(Icons.group_rounded, size: 14, color: Colors.black38),
                                        const SizedBox(width: 4),
                                        Text('To: ${_resolveRecipientLabel(r['recipient']?.toString() ?? 'all')}',
                                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
                                      ]),
                                    ],
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RecipientPicker extends StatefulWidget {
  final ValueChanged<String> onSelected;
  final String initial;
  const _RecipientPicker({required this.onSelected, this.initial = 'all'});
  @override
  State<_RecipientPicker> createState() => _RecipientPickerState();
}

class _RecipientPickerState extends State<_RecipientPicker> {
  late TextEditingController _ctrl;
  List<String> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  void _onChanged(String query) {
    widget.onSelected(query.trim().isEmpty ? 'all' : query.trim());
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('username')
            .ilike('username', '%${query.trim()}%')
            .limit(6);
        final names = List<Map<String, dynamic>>.from(data)
            .map((e) => e['username'].toString()).toList();
        final options = <String>['all', '@Moderators', ...names]
            .where((n) => n.toLowerCase().contains(query.trim().toLowerCase()))
            .toList();
        if (mounted) setState(() => _suggestions = options);
      } catch (_) {}
    });
  }

  @override
  void dispose() { _debounce?.cancel(); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _ctrl,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: '"all", "@Moderators" or a username',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      if (_suggestions.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: _suggestions.map((s) => ListTile(
              dense: true,
              title: Text(s, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              onTap: () {
                _ctrl.text = s;
                widget.onSelected(s);
                setState(() => _suggestions = []);
                FocusScope.of(context).unfocus();
              },
            )).toList(),
          ),
        ),
    ]);
  }
}

/// Confirms a typed recipient actually exists before you're allowed to send.
Future<bool> _isValidRecipient(String recipient) async {
  if (recipient == 'all' || recipient == '@Moderators') return true;
  final available = await AppStore.isUsernameAvailable(recipient);
  return !available; // "available" username == nobody has it == invalid
}

class ModeratorNotifyScreen extends StatefulWidget {
  const ModeratorNotifyScreen({super.key});
  @override
  State<ModeratorNotifyScreen> createState() => _ModeratorNotifyScreenState();
}

class _ModeratorNotifyScreenState extends State<ModeratorNotifyScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _recipient = 'all';
  bool _sending = false;

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    if (!await _isValidRecipient(_recipient)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No profile found for "$_recipient"')));
        setState(() => _sending = false);
      }
      return;
    }
    try {
      await Supabase.instance.client.from('notifications').insert({
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'recipient': _recipient,
        'author': AppStore.displayUsername,
        'background': null, // moderators can't customize appearance
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sent to $_recipient', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF2C2C2C)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(children: [
            FoldsTopBar(title: 'ANNOUNCEMENT', onBack: () => Navigator.pop(context)),
            const SizedBox(height: 20),
            TextField(controller: _titleCtrl, decoration: InputDecoration(
              hintText: 'Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 12),
            TextField(controller: _bodyCtrl, maxLines: 4, decoration: InputDecoration(
              hintText: 'Message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text('RECIPIENT',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 1))),
            const SizedBox(height: 6),
            _RecipientPicker(initial: 'all', onSelected: (v) => _recipient = v),
            const Spacer(),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(14)),
                child: Center(child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('SEND', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController(); // New Username Field
  bool _isLoading = false;
  bool _isSignUp = false;

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
          if (_usernameController.text.trim().isEmpty) {
            throw Exception('Please choose a username.');
          }
          final available = await AppStore.isUsernameAvailable(_usernameController.text.trim());
          if (!available) {
            throw Exception('That username is already taken. Please choose another.');
          }
        final signUpResponse = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {'username': _usernameController.text.trim()},
        );
        if (signUpResponse.user != null) {
          final d = DateTime.now();
          const months = ['','JANUARY','FEBRUARY','MARCH','APRIL','MAY','JUNE',
              'JULY','AUGUST','SEPTEMBER','OCTOBER','NOVEMBER','DECEMBER'];
          final joinStr = 'JOINED ${d.day} ${months[d.month]} ${d.year}';
          // Change from AppStore._p?.setString(...) to:
          await AppStore.setLocalJoinDate(joinStr);
          await AppStore.setLocalUsername(_usernameController.text.trim());

          // Auto sign-in immediately after creating account
          try {
            await Supabase.instance.client.auth.signInWithPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
            // Explicitly push the real join date to Supabase NOW — don't rely
            // on an incidental future sync to carry it up.
            final uid = Supabase.instance.client.auth.currentUser?.id;
            if (uid != null) {
              await Supabase.instance.client.from('profiles').update({
                'join_date': joinStr,
                'username': _usernameController.text.trim(),
              }).eq('id', uid);
            }
            await AppStore.downloadCloudProfile();
          } catch (_) {
            // Sign-in after signup can fail if email confirmation is required —
            // the account is still created, they just need to verify first
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Welcome to the Fold! You\'re signed in.')));
          Navigator.pop(context, true);
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Fun Graphic Logo Placeholder
              Center(
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 60),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                _isSignUp ? 'Join the Fold!' : 'Welcome Back!',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp 
                    ? 'Create an account to save your progress, unlock achievements, and climb the global leaderboards.' 
                    : 'Sign in to sync your progress and keep folding.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              
              if (_isSignUp) ...[
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: const Color(0xFFF5F5F5),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: const Color(0xFFF5F5F5),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: const Color(0xFFF5F5F5),
                ),
              ),
              const SizedBox(height: 32),
              
              GestureDetector(
                onTap: _isLoading ? null : _authenticate,
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp ? 'Already have an account? Sign in' : 'Don\'t have an account? Join now',
                  style: GoogleFonts.dmSans(color: Colors.black87, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('MANAGE ACCOUNT', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Signed in as:', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
              const SizedBox(height: 8),
              Text(user?.userMetadata?['username'] ?? 'Folder', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black)),
              Text(user?.email ?? '', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54)),
              const Spacer(),
              Image.asset(
                'assets/foldy.png',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  height: 50, decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('SIGN OUT', style: GoogleFonts.dmSans(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13))),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      backgroundColor: Colors.white,
                      title: Text('Delete Account?',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.red)),
                      content: Text(
                        'This permanently deletes your account, all XP, progress, and purchases. This cannot be undone.',
                        style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Delete Forever', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;

                  try {
                    final uid = Supabase.instance.client.auth.currentUser?.id;
                    if (uid != null) {
                      await Supabase.instance.client.from('profiles').delete().eq('id', uid);
                    }
                    await Supabase.instance.client.rpc('delete_user');
                  } catch (e) {
                    debugPrint('Account deletion error: $e');
                  }

                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const GameplayScreen(),
                        transitionsBuilder: (_, animation, __, child) =>
                            FadeTransition(opacity: animation, child: child),
                        transitionDuration: const Duration(milliseconds: 350),
                      ),
                      (route) => false,
                    );
                  }
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: Text('DELETE MY ACCOUNT',
                      style: GoogleFonts.dmSans(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  static const _totalPages = 7;

  void _next() {
    if (_page < _totalPages - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      _goToDaily();
    }
  }

  void _back() {
    if (_page > 0) {
      _controller.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  void _goToDaily() {
    AppStore.hasSeenOnboarding = true;
    final dayNumber = foldsDayNumberFor(DateTime.now());
    final dailyId = dayNumber > 0 ? 'd$dayNumber' : 'p1';
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: dailyId),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _totalPages - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _OnboardPage1(),         // 0: Welcome
                  _OnboardPageSixSM(),     // 1: The 6SM menu
                  _OnboardPage2(),         // 2: What is symmetry
                  _OnboardTutorial1(),     // 3: 1-move puzzle
                  _OnboardTutorial2(),     // 4: 2-move puzzle
                  _OnboardTutorial3(),     // 5: 3-move puzzle
                  _OnboardPageFinal(),     // 6: Par + XP + ready
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _page == i ? const Color(0xFF2C2C2C) : const Color(0xFFD6D6D6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Row(
                children: [
                  if (_page > 0) ...[
                    GestureDetector(
                      onTap: _back,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(16)),
                        child: Text('Back', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: GestureDetector(
                      onTap: _next,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: isLast ? const Color(0xFF4CAF50) : const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            isLast ? '🧩 Play Today\'s Daily!' : 'Next',
                            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
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
      ),
    );
  }
}

class _OnboardPageSixSM extends StatelessWidget {
  const _OnboardPageSixSM();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.extension_rounded, 'Puzzles', 'Browse all packs & daily'),
      (Icons.account_circle_rounded, 'Profile', 'XP, rank & achievements'),
      (Icons.shopping_basket_rounded, 'Store', 'Unlock more packs'),
      (Icons.settings_rounded, 'Settings', 'Timer, haptics & more'),
      (Icons.favorite_rounded, 'Socials', 'YouTube, Discord, TikTok'),
      (Icons.handshake_rounded, 'Credits', 'The team behind Folds'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: const Color(0xFFE8E8E8), shape: BoxShape.circle),
            child: ClipOval(child: CustomPaint(painter: HomeIconPainter())),
          ),
          const SizedBox(height: 16),
          Text('The Home Button', style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Tap the circle in the top-left corner of any puzzle to open the navigation menu.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.5)),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: items.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(item.$1, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.$2, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(item.$3, style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white38)),
                    ],
                  )),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// Shared interactive tutorial widget
class _TutorialGrid extends StatefulWidget {
  final List<bool> initialCells;
  final String hintText;
  final String successText;
  final VoidCallback? onSolved;

  const _TutorialGrid({
    required this.initialCells,
    required this.hintText,
    required this.successText,
  }) : onSolved = null;

  @override
  State<_TutorialGrid> createState() => _TutorialGridState();
}

class _TutorialGridState extends State<_TutorialGrid> {
  late List<bool> _cells;
  bool _solved = false;
  int _moves = 0;

  @override
  void initState() {
    super.initState();
    _cells = List.from(widget.initialCells);
  }

  bool _isSolved() {
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 2; col++) {
        if (_cells[row * 4 + col] != _cells[row * 4 + (3 - col)]) return false;
      }
    }
    return true;
  }

  // Count mismatched pairs for progress
  double get _progress {
    int matched = 0;
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 2; col++) {
        if (_cells[row * 4 + col] == _cells[row * 4 + (3 - col)]) matched++;
      }
    }
    return matched / 8;
  }

  void _tap(int index) {
    if (_solved) return;
    setState(() {
      _cells[index] = !_cells[index];
      _moves++;
      if (_isSolved()) {
        _solved = true;
        widget.onSolved?.call();
      }
    });
  }

  void _reset() => setState(() {
    _cells = List.from(widget.initialCells);
    _solved = false;
    _moves = 0;
  });

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    const cellSize = 56.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _solved ? const Color(0xFFE8F5E9) : const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(18),
            border: _solved ? Border.all(color: const Color(0xFF4CAF50), width: 2) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (row) => Padding(
              padding: EdgeInsets.only(bottom: row < 3 ? gap : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(4, (col) {
                  final i = row * 4 + col;
                  return Padding(
                    padding: EdgeInsets.only(right: col < 3 ? gap : 0),
                    child: GestureDetector(
                      onTap: () => _tap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: cellSize, height: cellSize,
                        decoration: BoxDecoration(
                          color: _cells[i] ? const Color(0xFF2C2C2C) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            )),
          ),
        ),
        const SizedBox(height: 12),
        // Symmetry progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: const Color(0xFFE8E8E8),
            valueColor: AlwaysStoppedAnimation<Color>(
              _solved ? const Color(0xFF4CAF50) : const Color(0xFFFFD465)),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _solved
              ? Column(key: const ValueKey('s'), children: [
                  Text(widget.successText, textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800,
                      color: const Color(0xFF4CAF50))),
                  const SizedBox(height: 4),
                  Text('$_moves move${_moves == 1 ? '' : 's'} used',
                    style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black38)),
                  const SizedBox(height: 8),
                  GestureDetector(onTap: _reset,
                    child: Text('Try again', style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38,
                      decoration: TextDecoration.underline))),
                ])
              : Column(key: const ValueKey('h'), children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFFFD465)),
                    const SizedBox(width: 6),
                    Flexible(child: Text(widget.hintText, textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54))),
                  ]),
                  const SizedBox(height: 4),
                  Text('Moves: $_moves', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black26)),
                ]),
        ),
      ],
    );
  }
}

// Tutorial page wrapper
class _TutorialPageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget grid;

  const _TutorialPageShell({
    required this.title,
    required this.subtitle,
    required this.grid,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(title, textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.5)),
          const SizedBox(height: 24),
          grid,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _OnboardTutorial1 extends StatelessWidget {
  const _OnboardTutorial1();

  @override
  Widget build(BuildContext context) {
    return _TutorialPageShell(
      title: 'Your First Fold',
      subtitle: 'Every row must mirror itself left to right. One cell is out of place — find it.',
      grid: _TutorialGrid(
        // Row 0: W W W B — col 0 (W) ≠ col 3 (B). Tap index 0 to fix.
        initialCells: const [
          false, false, false, true,
          false, false, false, false,
          false, false, false, false,
          false, false, false, false,
        ],
        hintText: 'Look at the top row — one corner doesn\'t match its pair. Tap the top-left cell.',
        successText: '✓ Perfectly symmetrical!',
      ),
    );
  }
}

class _OnboardTutorial2 extends StatelessWidget {
  const _OnboardTutorial2();

  @override
  Widget build(BuildContext context) {
    return _TutorialPageShell(
      title: 'Two to Fix',
      subtitle: 'Now two rows are unbalanced. Fix both to solve the puzzle.',
      grid: _TutorialGrid(
        // Row 0: B W W W (col 0 ≠ col 3). Row 3: W W W B (col 0 ≠ col 3).
        // Fix: tap index 3 (row 0 col 3) and index 12 (row 3 col 0).
        initialCells: const [
          true,  false, false, false,
          false, false, false, false,
          false, false, false, false,
          false, false, false, true,
        ],
        hintText: 'Top row and bottom row each have a mismatch. Tap the odd corner in each.',
        successText: '✓ Both rows balanced!',
      ),
    );
  }
}

class _OnboardTutorial3 extends StatelessWidget {
  const _OnboardTutorial3();

  @override
  Widget build(BuildContext context) {
    return _TutorialPageShell(
      title: 'Think it Through',
      subtitle: 'Three rows need balancing. Check each row left-to-right.',
      grid: _TutorialGrid(
        // Row 0: B W W W → tap index 3
        // Row 1: W W B W → tap index 5 (col 1)
        // Row 2: W W W B → tap index 8 (col 0)
        // Row 3: W W W W → already ok
        initialCells: const [
          true,  false, false, false,
          false, false, true,  false,
          false, false, false, true,
          false, false, false, false,
        ],
        hintText: 'Each of the first three rows has exactly one mismatched pair. Fix one row at a time.',
        successText: '✓ You\'re ready to Fold!',
      ),
    );
  }
}

class _OnboardPageFinal extends StatelessWidget {
  const _OnboardPageFinal();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🧩', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('You\'re Ready!', textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text('Every day a new daily puzzle drops. Hit par to earn maximum XP and a gold stamp.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black54, height: 1.6)),
          const SizedBox(height: 28),
          _OnboardResultRow(stamp: '★', stampColor: const Color(0xFFFFD465),
            label: 'At or under par', detail: 'Maximum XP — Gold stamp'),
          const SizedBox(height: 8),
          _OnboardResultRow(stamp: '✦', stampColor: Colors.black38,
            label: 'Over par', detail: 'Partial XP earned'),
          const SizedBox(height: 8),
          _OnboardResultRow(stamp: '—', stampColor: Colors.black12,
            label: 'Way over par', detail: 'No XP awarded'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFFFD465)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Some tiles are linked — flipping one flips all tiles with the same shape badge.',
                style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54, height: 1.4))),
            ]),
          ),
        ],
      ),
    );
  }
}
class _OnboardPage1 extends StatelessWidget {
  const _OnboardPage1();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFD3D3D3),
              borderRadius: BorderRadius.circular(28),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: CustomPaint(painter: HomeIconPainter()),
            ),
          ),
          const SizedBox(height: 36),
          Text('Welcome to Folds',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 16),
          Text(
            'A minimalist tile-switching puzzle game. Simple to learn, deeply satisfying to master.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 16, color: Colors.black54, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _OnboardPage2 extends StatelessWidget {
  const _OnboardPage2();

  static const _before = [
    true,  false, true,  true,
    false, true,  false, true,
    true,  true,  false, false,
    false, false, true,  false,
  ];
  static const _after = [
    true,  false, false, true,
    false, true,  true,  false,
    true,  false, false, true,
    false, true,  true,  false,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Make it Symmetrical',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 12),
          Text(
            'Tap tiles to flip them black or white. Your goal: every row must mirror itself left to right.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black54, height: 1.6),
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _OnboardMiniGrid(cells: _before, label: 'Unsolved'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('→',
                  style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black26)),
              ),
              _OnboardMiniGrid(cells: _after, label: 'Solved ✓', solved: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardMiniGrid extends StatelessWidget {
  final List<bool> cells;
  final String label;
  final bool solved;
  const _OnboardMiniGrid({required this.cells, required this.label, this.solved = false});

  @override
  Widget build(BuildContext context) {
    const n = 4;
    const cellSize = 18.0;
    const gap = 4.0;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(10),
            border: solved ? Border.all(color: const Color(0xFF4CAF50), width: 2) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(n, (row) => Padding(
              padding: EdgeInsets.only(bottom: row < n - 1 ? gap : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(n, (col) => Padding(
                  padding: EdgeInsets.only(right: col < n - 1 ? gap : 0),
                  child: Container(
                    width: cellSize, height: cellSize,
                    decoration: BoxDecoration(
                      color: cells[row * n + col] ? const Color(0xFF2C2C2C) : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )),
              ),
            )),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: solved ? const Color(0xFF4CAF50) : Colors.black38)),
      ],
    );
  }
}

class _OnboardPage3 extends StatelessWidget {
  const _OnboardPage3();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Par & XP',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 16),
          Text(
            'Every puzzle has a par — the ideal move count. Hit or beat it for max XP and a gold stamp.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black54, height: 1.6),
          ),
          const SizedBox(height: 36),
          _OnboardResultRow(
            stamp: '★', stampColor: Color(0xFFFFD465),
            label: 'At or under par', detail: 'Max XP — Gold stamp'),
          const SizedBox(height: 10),
          _OnboardResultRow(
            stamp: '✦', stampColor: Colors.black38,
            label: 'Over par', detail: 'Partial XP earned'),
          const SizedBox(height: 10),
          _OnboardResultRow(
            stamp: '—', stampColor: Colors.black12,
            label: 'Way over par', detail: 'No XP this time'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 18, color: Colors.black38),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hints are available if you get stuck — but using them affects your XP.',
                    style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54, height: 1.4),
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

class _OnboardPage4 extends StatefulWidget {
  const _OnboardPage4();
  @override
  State<_OnboardPage4> createState() => _OnboardPage4State();
}

class _OnboardPage4State extends State<_OnboardPage4> {
  // 2x2 grid. Pairs: (0,1) and (2,3). Cells 0 and 2 are linked (circle).
  // Initial [black, white, white, black] → tap 0 or 2 → [white,white,black,black] → SOLVED
  List<bool> _cells = [true, false, false, true];
  bool _solved = false;

  bool _isSolved(List<bool> c) => c[0] == c[1] && c[2] == c[3];

  void _tap(int index) {
    if (_solved || (index != 0 && index != 2)) return; // only linked cells tappable
    setState(() {
      _cells[0] = !_cells[0];
      _cells[2] = !_cells[2];
      if (_isSolved(_cells)) _solved = true;
    });
  }

  void _reset() => setState(() { _cells = [true, false, false, true]; _solved = false; });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Link Tiles',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 12),
          Text(
            'Some tiles share a badge — flip one and all linked tiles flip with it. Try it below.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black54, height: 1.6),
          ),
          const SizedBox(height: 32),
          // 2x2 interactive demo
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(18)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _demoCell(0), const SizedBox(width: 10), _demoCell(1),
                ]),
                const SizedBox(height: 10),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _demoCell(2), const SizedBox(width: 10), _demoCell(3),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _solved
                ? Column(key: const ValueKey('solved'), children: [
                    const Text('✓', style: TextStyle(fontSize: 32, color: Color(0xFF4CAF50))),
                    const SizedBox(height: 6),
                    Text('They flipped together!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF4CAF50))),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _reset,
                      child: Text('Try again', style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38,
                        decoration: TextDecoration.underline)),
                    ),
                  ])
                : Text(
                    key: const ValueKey('hint'),
                    'Tap either tile with the ○ badge.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black45),
                  ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Colors.black38),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Shapes can be circles ○, triangles △, squares □ or pentagons ⬠. Each shape is a different link group.',
                    style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _demoCell(int index) {
    final isBlack = _cells[index];
    final isLinked = index == 0 || index == 2;
    return GestureDetector(
      onTap: () => _tap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: isBlack ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: isLinked ? Stack(children: [
          Positioned(
            top: 6, right: 6,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isBlack ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ),
        ]) : Opacity(opacity: 0.45, child: const SizedBox()),
      ),
    );
  }
}

class _OnboardResultRow extends StatelessWidget {
  final String stamp;
  final Color stampColor;
  final String label;
  final String detail;
  const _OnboardResultRow({
    required this.stamp, required this.stampColor,
    required this.label, required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(stamp, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: stampColor)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black)),
              Text(detail, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black45)),
            ],
          ),
        ],
      ),
    );
  }
}