import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://kvihtmzgthznjtwqtbvg.supabase.co',
    anonKey: 'sb_publishable_hznxJ0hZwXRvO-KHZuoYag_RXPDWfWI',
  );
  await AppStore.init();
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
      home: const GameplayScreen(),
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

class AppSettings {
  static bool showTimer = true;
  static bool enableMs = false;
  static int movesDisplay = 0;
  static bool haptic = true;
}

// ─────────────────────────────────────────────────────────────────────────────
// PERSISTENT STORE
// ─────────────────────────────────────────────────────────────────────────────
class AppStore {
  static SharedPreferences? _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    // Push saved settings into AppSettings on load
    AppSettings.showTimer = _p?.getBool('showTimer') ?? true;
    AppSettings.enableMs = _p?.getBool('enableMs') ?? false;
    AppSettings.movesDisplay = _p?.getInt('movesDisplay') ?? 0;
    AppSettings.haptic = _p?.getBool('haptic') ?? true;
  }

  // ── Profile
  static String get username => _p?.getString('username') ?? 'Puzzle Apprentice';
  static set username(String v) => _p?.setString('username', v);

  static String? get avatarPath => _p?.getString('avatarPath');
  static set avatarPath(String? v) {
    v == null ? _p?.remove('avatarPath') : _p?.setString('avatarPath', v);
  }

  static String get joinDate => _p?.getString('joinDate') ?? _initJoinDate();
  static String _initJoinDate() {
    final d = DateTime.now();
    final months = ['','JANUARY','FEBRUARY','MARCH','APRIL','MAY','JUNE',
        'JULY','AUGUST','SEPTEMBER','OCTOBER','NOVEMBER','DECEMBER'];
    final s = 'JOINED ${d.day} ${months[d.month]} ${d.year}';
    _p?.setString('joinDate', s);
    return s;
  }

  static bool get haptic => _p?.getBool('haptic') ?? true;
  static set haptic(bool v) => _p?.setBool('haptic', v);
  

  // ── XP
  static int get totalXP => _p?.getInt('totalXP') ?? 0;
  static set totalXP(int v) => _p?.setInt('totalXP', v);

  // ── Completed puzzles
  static Set<String> get completedPuzzles =>
      (_p?.getStringList('completedPuzzles') ?? []).toSet();
  static void markCompleted(String id) {
    final s = completedPuzzles..add(id);
    _p?.setStringList('completedPuzzles', s.toList());
  }
  static bool isCompleted(String id) => completedPuzzles.contains(id);

  // ── Failed puzzles (for "after par" detection)
  static Set<String> get failedPuzzles =>
      (_p?.getStringList('failedPuzzles') ?? []).toSet();
  static void markFailed(String id) {
    final s = failedPuzzles..add(id);
    _p?.setStringList('failedPuzzles', s.toList());
  }
  static bool hasFailed(String id) => failedPuzzles.contains(id);

  // ── Recently played pack
  static String get recentPack => _p?.getString('recentPack') ?? '';
  static set recentPack(String v) => _p?.setString('recentPack', v);

  // ── Settings
  static bool get showTimer => _p?.getBool('showTimer') ?? true;
  static set showTimer(bool v) {
    _p?.setBool('showTimer', v);
    AppSettings.showTimer = v;
  }

  static bool get enableMs => _p?.getBool('enableMs') ?? false;
  static set enableMs(bool v) {
    _p?.setBool('enableMs', v);
    AppSettings.enableMs = v;
  }

  static int get movesDisplay => _p?.getInt('movesDisplay') ?? 0;
  static set movesDisplay(int v) {
    _p?.setInt('movesDisplay', v);
    AppSettings.movesDisplay = v;
  }

  static int get notifHour => _p?.getInt('notifHour') ?? 8;
  static int get notifMinute => _p?.getInt('notifMinute') ?? 0;
  static void setNotifTime(TimeOfDay t) {
    _p?.setInt('notifHour', t.hour);
    _p?.setInt('notifMinute', t.minute);
  }
  static TimeOfDay get notifTime =>
      TimeOfDay(hour: notifHour, minute: notifMinute);

  // ── Progress stats
  static int get puzzlesCompleted =>
      completedPuzzles.where((id) => !id.startsWith('d')).length;
  static int get dailiesCompleted =>
      completedPuzzles.where((id) => id.startsWith('d')).length;

  // ── Pack progress helpers
  static int completedInRange(String prefix, int start, int count) {
    int done = 0;
    for (int i = start + 1; i <= start + count; i++) {
      if (isCompleted('$prefix$i')) done++;
    }
    return done;
  }

  // ── Reset
  static Future<void> resetProgress() async {
    for (final k in ['totalXP','completedPuzzles','failedPuzzles','recentPack']) {
      await _p?.remove(k);
    }
  }

  static Future<void> resetSettings() async {
    for (final k in ['showTimer','enableMs','movesDisplay','notifHour','notifMinute']) {
      await _p?.remove(k);
    }
    AppSettings.showTimer = true;
    AppSettings.enableMs = false;
    AppSettings.movesDisplay = 0;
    
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// XP SYSTEM
// ─────────────────────────────────────────────────────────────────────────────
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
    return rank;
  }

  static int xpForRank(int rank) =>
      rank < thresholds.length ? thresholds[rank] : thresholds.last;

  static int xpForNextRank(int rank) {
    final next = rank + 1;
    return next < thresholds.length ? thresholds[next] : thresholds.last + 1000;
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
    if (rank >= 30) return const Color(0xFFFFD465);
    if (rank >= 20) return const Color(0xFF7BD957);
    if (rank >= 10) return const Color(0xFF5865F2);
    return const Color(0xFFC17A36);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GAMEPLAY SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class GameplayScreen extends StatefulWidget {
  final String initialPuzzleId;
  const GameplayScreen({super.key, this.initialPuzzleId = 'p1'});
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

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialPuzzleId != 'p1') {
        _loadPuzzle(widget.initialPuzzleId);
        return;
      }
      // Try to load the latest daily puzzle
      try {
        final response = await Supabase.instance.client
            .from('puzzles')
            .select('id')
            .ilike('id', 'd%')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (response != null) {
          _loadPuzzle(response['id']);
        } else {
          _loadPuzzle('p1');
        }
      } catch (e) {
        _loadPuzzle('p1');
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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

  Future<void> _loadPuzzle(String id) async {
    setState(() {
      _loading = true;
      _notFound = false;
      _loaded = false;
    });
    try {
      final response = await Supabase.instance.client
          .from('puzzles')
          .select()
          .eq('id', id)
          .single();
      final rawCells = (response['cells'] as List).map((e) => e == 1).toList();
      // Determine grid size from cell count
      final cellCount = rawCells.length;
      final gridSize = cellCount == 36 ? 6 : cellCount == 64 ? 8 : 4;
      setState(() {
        _cells = rawCells;
        _gridSize = gridSize;
        _title = response['title'];
        _author = response['author'];
        _difficulty = response['difficulty'] as int;
        _id = response['id'].toString();
        _par = (response['par'] ?? 5) as int;
        _moves = 0;
        _loaded = true;
        _loading = false;
        _notFound = false;
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
    // For any NxN grid, left-right symmetry means cell[r][c] == cell[r][N-1-c]
    final n = _gridSize;
    for (int row = 0; row < n; row++) {
      for (int col = 0; col < n ~/ 2; col++) {
        final left = row * n + col;
        final right = row * n + (n - 1 - col);
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [

            // ── Grid & Localized Pause Overlay ───────────────────
            if (_loaded && _solved)
              SingleChildScrollView(
                child: FoldCompleteAnimator(
                  puzzleId: _id,
                  puzzleTitle: _puzzleDisplayTitle,
                  puzzleShareNumber: _puzzleShareNumber,
                  packPath: _packPath,
                  timeDisplay: _timeDisplay,
                  moves: _moves,
                  par: _par,
                  earnedXP: _earnedXP,
                  cells: _cells,
                  onRetry: () {
                    setState(() => _solved = false);
                    _loadPuzzle(_id);
                    _resetTimer();
                    setState(() => _moves = 0);
                  },
                ),
              ),

            if (_loaded && !_solved) Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    color: const Color(0xFFE8E8E8),
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final n = _gridSize;
                        final gap = n == 4 ? 8.0 : n == 6 ? 6.0 : 4.0;
                        final cellSize = (constraints.maxWidth - gap * (n - 1) - 32) / n;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(n, (row) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: row < n - 1 ? gap : 0),
                              child: Row(
                                children: List.generate(n, (col) {
                                  final index = row * n + col;
                                  return Padding(
                                    padding: EdgeInsets.only(right: col < n - 1 ? gap : 0),
                                    child: SizedBox(
                                      width: cellSize,
                                      height: cellSize,
                                      child: _FlipCell(
                                        isBlack: _cells[index],
                                        onTap: () {
                                          if (_paused) return;
                                          setState(() {
                                            _cells[index] = !_cells[index];
                                            _moves++;
                                          });
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
                                            if (AppSettings.haptic) {
                                              HapticFeedback.heavyImpact();
                                            }
                                            // Only award XP once per puzzle
                                            final alreadyCompleted = AppStore.isCompleted(_id);
                                            if (!alreadyCompleted) {
                                              if (_moves > _par * 2) AppStore.markFailed(_id);
                                              AppStore.totalXP = AppStore.totalXP + xp;
                                            }
                                            // Always mark completed (idempotent)
                                            AppStore.markCompleted(_id);
                                            // Track recent pack (dailies count separately)
                                            if (_id.startsWith('d')) {
                                              // daily — still mark completed, no recent pack change
                                            } else if (_id.startsWith('p')) {
                                              AppStore.recentPack = 'PILOT';
                                            } else if (_id.startsWith('r')) {
                                              AppStore.recentPack = 'RECTANGLE';
                                            }
                                            setState(() {
                                              _solved = true;
                                              _earnedXP = xp;
                                            });
                                          }
                                        },
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
                    
                  
                  // Localized Whiteout Pause Overlay
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
                ),
              ),
            

            // ── Top bar ──────────────────────────────────────────
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
                            child: ClipOval(child: CustomPaint(painter: _HomeIconPainter())),
                          ),
                        ),
                        Opacity(
                          opacity: AppSettings.showTimer ? 1.0 : 0.0,
                          child: Text(_timeDisplay, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black)),
                        ),
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
                            Text('by $_author', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w400, color: Colors.black54)),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Difficulty:', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.black54)),
                            const SizedBox(height: 4),
                            _StarRating(filled: _difficulty, total: 5),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Moves bar ────────────────────────────────────────
            Positioned(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_par, (i) {
                          final filled = i < _moves;
                          final overPar = _moves > _par;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 18, height: 18,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUZZLES MENU SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PuzzlesMenuScreen extends StatefulWidget {
  const PuzzlesMenuScreen({super.key});
  @override
  State<PuzzlesMenuScreen> createState() => _PuzzlesMenuScreenState();
}

class _PuzzlesMenuScreenState extends State<PuzzlesMenuScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              _FoldsTopBar(title: 'PUZZLES', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      height: 100,
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('DAILY PUZZLE', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFd9d9d9), borderRadius: BorderRadius.circular(6)),
                            child: Text('#551', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _pushFade(context, const DailyArchiveScreen()),
                    child: Container(
                      width: 76, height: 100,
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
                      child: Center(child: CustomPaint(size: const Size(28, 24), painter: _ArchiveIconPainter())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Replace the Expanded GridView.count with:
Expanded(
  child: Column(
    children: [
      Expanded(
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
      Expanded(
        child: _MenuPackCard(
          title: 'RECTANGLE PACK',
          subtitle: '100 PUZZLES',
          completedPuzzles: AppStore.completedInRange('r', 0, 100),
          totalPuzzles: 100,
          shapeType: _PackShapeType.rectangle,
          onPlay: () {},
          onHome: () {},
        ),
      ),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'MORE PUZZLES COMING SOON!',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
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
              _FoldsTopBar(title: 'PILOT PACK', onBack: () => Navigator.pop(context)),
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
                        onPlay: () => Navigator.pop(context),
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
                        onPlay: () {},
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
                        onPlay: () {},
                        onHome: () => _pushFade(context, const PuzzleSelectorScreen(
                          packName: '8x8', totalPuzzles: 20, idPrefix: 'p', idOffset: 80)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _BackButton(label: 'BACK TO MORE PUZZLES', onTap: () => Navigator.pop(context)),
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
    const displayCount = 20;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  _FoldsTopBar(title: '$packName PACK', onBack: () => Navigator.pop(context)),
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
                                  const Icon(Icons.check_rounded, color: Color(0xFF4CAF50), size: 20),
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
              child: _BackButton(label: 'BACK TO MORE PUZZLES', onTap: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _FoldsTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _FoldsTopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: onBack,
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
        Text(title, style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Colors.black)),
        const SizedBox(width: 40),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BackButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(16)),
        child: Center(
          child: Text(label, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
        ),
      ),
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
// THE FOLD ANIMATION i dont think this will optimise very well but tis okay
// ─────────────────────────────────────────────────────────────────────────────
// FOLD COMPLETION ANIMATOR
// ─────────────────────────────────────────────────────────────────────────────
class FoldCompleteAnimator extends StatefulWidget {
  final String puzzleId;
  final String puzzleTitle;      // display title (e.g. "Pilot #1" or daily name)
  final String puzzleShareNumber; // just the number
  final String packPath;          // "pilot", "daily", "rectangle"
  final String timeDisplay;
  final int moves;
  final int par;
  final int earnedXP;
  final VoidCallback onRetry;
  final List<bool> cells;

  const FoldCompleteAnimator({
    super.key,
    required this.puzzleId,
    required this.puzzleTitle,
    required this.puzzleShareNumber,
    required this.packPath,
    required this.timeDisplay,
    required this.moves,
    required this.par,
    required this.earnedXP,
    required this.onRetry,
    required this.cells,
  });
  @override
  State<FoldCompleteAnimator> createState() => _FoldCompleteAnimatorState();
}

class _FoldCompleteAnimatorState extends State<FoldCompleteAnimator>
    with TickerProviderStateMixin {

  // Stage controllers
  late AnimationController _foldCtrl;
  late AnimationController _envelopeCtrl;
  late AnimationController _flipCtrl;
  late AnimationController _stampCtrl;
  late AnimationController _statsCtrl;

  // Fold: left half rotates over right
  late Animation<double> _foldAngle;

  // Envelope slides up
  late Animation<double> _envelopeSlide;
  late Animation<double> _flapClose;

  // Envelope flip
  late Animation<double> _flipAngle;

  // Stamp scale
  late Animation<double> _stampScale;

  // Stats fade
  late Animation<double> _statsFade;
  late Animation<double> _statsSlide;

  int _stage = 0; // 0=folding 1=envelope 2=flip 3=stamp 4=stats

  bool get _isUnderPar => widget.moves <= widget.par;

  @override
  void initState() {
    super.initState();

    _foldCtrl = AnimationController(duration: const Duration(milliseconds: 750), vsync: this);
    _envelopeCtrl = AnimationController(duration: const Duration(milliseconds: 650), vsync: this);
    _flipCtrl = AnimationController(duration: const Duration(milliseconds: 550), vsync: this);
    _stampCtrl = AnimationController(duration: const Duration(milliseconds: 900), vsync: this);
    _statsCtrl = AnimationController(duration: const Duration(milliseconds: 450), vsync: this);

    // Fold: ease in slow, accelerate at end (paper has momentum)
    _foldAngle = Tween<double>(begin: 0, end: pi / 2).animate(
      CurvedAnimation(parent: _foldCtrl, curve: Curves.easeInCubic));

    // Envelope: slide up from below the fold position
    _envelopeSlide = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _envelopeCtrl, curve: Curves.easeOutCubic));
    _flapClose = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _envelopeCtrl,
          curve: const Interval(0.4, 1.0, curve: Curves.easeInOutCubic)));

    // Flip: slow in middle (physical weight)
    _flipAngle = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOutSine));

    // Stamp: elastic drop
    _stampScale = Tween<double>(begin: 2.5, end: 1.0).animate(
      CurvedAnimation(parent: _stampCtrl, curve: Curves.elasticOut));

    _statsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _statsCtrl, curve: Curves.easeOut));
    _statsSlide = Tween<double>(begin: 28, end: 0).animate(
      CurvedAnimation(parent: _statsCtrl, curve: Curves.easeOutCubic));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 350));
    await _foldCtrl.forward();
    // Small pause — paper has just landed
    await Future.delayed(const Duration(milliseconds: 120));
    setState(() => _stage = 1);
    await _envelopeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 350));
    setState(() => _stage = 2);
    await _flipCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() => _stage = 3);
    await _stampCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 220));
    setState(() => _stage = 4);
    await _statsCtrl.forward();
  }
  @override
  void dispose() {
    _foldCtrl.dispose();
    _envelopeCtrl.dispose();
    _flipCtrl.dispose();
    _stampCtrl.dispose();
    _statsCtrl.dispose();
    super.dispose();
  }

  String get _shareText {
    final cleanTime = widget.timeDisplay.split('.').first;
    return 'Folds\n#${widget.puzzleShareNumber} ${widget.puzzleTitle}\n$cleanTime ⏳, 0 💡, ${widget.moves}/${widget.par} ➡️\nhttps://folds.jaydev.games/puzzles/${widget.packPath}/${widget.puzzleShareNumber}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final gridWidth = size.width - 32;
    final gridHeight = gridWidth;

    return SizedBox(
      width: size.width,
      height: gridHeight + 280,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [

          // ── Stage 0: Folding grid ─────────────────────────────
          if (_stage == 0)
            AnimatedBuilder(
              animation: _foldCtrl,
              builder: (context, child) {
                final half = gridWidth / 2;
                return Container(
                  width: gridWidth,
                  height: gridWidth,
                  color: const Color(0xFFE8E8E8),
                  child: Stack(
                    children: [
                      // Right half — static, shows actual cell colours
                      Positioned(
                        left: half, top: 0,
                        width: half, height: gridWidth,
                        child: _GridHalf(
                          cells: widget.cells,
                          isLeft: false,
                          cellCount: 4,
                        ),
                      ),
                      // Left half — folds over right
                      Positioned(
                        left: 0, top: 0,
                        width: half, height: gridWidth,
                        child: Transform(
                          alignment: Alignment.centerRight,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(_foldAngle.value),
                          child: _GridHalf(
                            cells: widget.cells,
                            isLeft: true,
                            cellCount: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // ── Stage 1+: Envelope ───────────────────────────────
          if (_stage >= 1)
            Positioned(
              top: gridHeight * 0.1,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: Listenable.merge([_envelopeCtrl, _flipCtrl, _stampCtrl]),
                builder: (context, child) {
                  final flipVal = _stage >= 2 ? _flipAngle.value : 0.0;
                  final isFrontVisible = flipVal < pi / 2;

                  return Transform.translate(
                    offset: Offset(0, _stage == 1 ? _envelopeSlide.value : 0),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX(flipVal),
                    child: SizedBox(
                      width: gridWidth * 0.85,
                      height: gridWidth * 0.55,
                      child: Stack(
                        children: [
                          // Envelope body
                          Container(
                            decoration: BoxDecoration(
                              color: isFrontVisible
                                  ? const Color(0xFFE8E8E8)
                                  : const Color(0xFF1a1a1a),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),

                          // Front face details
                          if (isFrontVisible) ...[
                            // Envelope V flap lines
                            CustomPaint(
                              size: Size(gridWidth * 0.85, gridWidth * 0.55),
                              painter: _EnvelopeFrontPainter(flapProgress: _flapClose.value),
                            ),
                          ],

                          // Back face — black with stamp
                          if (!isFrontVisible) ...[
                            // Stamp
                            if (_stage >= 3)
                              Center(
                                child: Transform.scale(
                                  scale: _stampScale.value.clamp(0.0, 10.0),
                                  child: _StampWidget(isGold: _isUnderPar),
                                ),
                              ),
                      
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            ),

          // ── Stage 4: Stats ───────────────────────────────────
          if (_stage >= 4)
            Positioned(
              top: gridHeight * 0.65,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _statsCtrl,
                builder: (context, child) {
                  return Opacity(
                    opacity: _statsFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _statsSlide.value),
                      child: _StatsCard(
                        timeDisplay: widget.timeDisplay,
                        moves: widget.moves,
                        par: widget.par,
                        earnedXP: widget.earnedXP,
                        isUnderPar: _isUnderPar,
                        shareText: _shareText,
                        onRetry: widget.onRetry,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _GridHalf extends StatelessWidget {
  final List<bool> cells;
  final bool isLeft;
  final int cellCount;

  const _GridHalf({required this.cells, required this.isLeft, required this.cellCount});

  @override
  Widget build(BuildContext context) {
    final cols = isLeft ? [0, 1] : [2, 3];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = (constraints.maxWidth - (8 * (cols.length - 1)) - 16) / cols.length;
        return Container(
          color: const Color(0xFFE8E8E8),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(cellCount, (row) {
              return Padding(
                padding: EdgeInsets.only(bottom: row < cellCount - 1 ? 8 : 0),
                child: Row(
                  children: cols.map((col) {
                    final index = row * cellCount + col;
                    return Padding(
                      padding: EdgeInsets.only(right: col < cols.last ? 8 : 0),
                      child: Container(
                        width: cellSize,
                        height: cellSize,
                        decoration: BoxDecoration(
                          color: cells[index] ? const Color(0xFF2C2C2C) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          ),
        );
      },
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

// ── Stamp widget ──────────────────────────────────────────────────────────────
class _StampWidget extends StatelessWidget {
  final bool isGold;
  const _StampWidget({required this.isGold});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isGold ? const Color(0xFFFFD465) : const Color(0xFFBBBBBB),
        boxShadow: [
          BoxShadow(
            color: (isGold ? const Color(0xFFFFD465) : const Color(0xFFBBBBBB)).withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isGold ? '★' : '✦',
              style: TextStyle(
                fontSize: 28,
                color: isGold ? Colors.black : Colors.white,
              ),
            ),
            Text(
              isGold ? 'PAR' : 'SOLVED',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isGold ? Colors.black : Colors.white,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats card ────────────────────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  final String timeDisplay;
  final int moves;
  final int par;
  final bool isUnderPar;
  final String shareText;
  final VoidCallback onRetry;
  final int earnedXP;

  const _StatsCard({
    required this.timeDisplay,
    required this.moves,
    required this.par,
    required this.isUnderPar,
    required this.shareText,
    required this.onRetry,
    required this.earnedXP,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(emoji: '⏳', value: timeDisplay),
                _StatItem(emoji: '💡', value: '0'),
                _StatItem(emoji: '➡️', value: '$moves/$par'),
                _StatItem(emoji: '⭐', value: '+$earnedXP XP'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Share button
          
                    // Share button
          Builder(
            builder: (context) {
              return GestureDetector(
                onTap: () {
                  // Find the visual render boundary of this button
                  final RenderBox? box = context.findRenderObject() as RenderBox?;
                  
                  // Construct a non-zero origin box for iOS share sheet popovers
                  final Rect? sharePositionOrigin = box != null 
                      ? box.localToGlobal(Offset.zero) & box.size 
                      : null;

                  Share.share(
                    shareText, 
                    subject: 'Folds',
                    sharePositionOrigin: sharePositionOrigin,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text('Share Fold',
                      style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Copy + Retry row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: shareText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied to clipboard',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                        backgroundColor: const Color(0xFF2C2C2C),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text('Copy Fold',
                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text('Retry',
                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String emoji;
  final String value;
  const _StatItem({required this.emoji, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
      ],
    );
  }
}

//end of fold animation only 500 liens i guess it wasnt that bad

class _FlipCell extends StatefulWidget {
  final bool isBlack;
  final VoidCallback onTap;
  const _FlipCell({required this.isBlack, required this.onTap});
  @override
  State<_FlipCell> createState() => _FlipCellState();
}

class _FlipCellState extends State<_FlipCell> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showingBlack = false;

  @override
  void initState() {
    super.initState();
    _showingBlack = widget.isBlack;
    _controller = AnimationController(duration: const Duration(milliseconds: 140), vsync: this);
  }

  @override
  void didUpdateWidget(_FlipCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBlack != widget.isBlack && !_controller.isAnimating) {
      setState(() => _showingBlack = widget.isBlack);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    _controller.forward(from: 0).then((_) {
      setState(() => _showingBlack = !_showingBlack);
      widget.onTap();
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * 3.1416 / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(angle),
            child: Container(
              decoration: BoxDecoration(
                color: _showingBlack ? const Color(0xFF2C2C2C) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
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

class _StarRating extends StatelessWidget {
  final int filled;
  final int total;
  const _StarRating({required this.filled, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) => Icon(
        i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 26,
        color: i < filled ? Colors.black : Colors.black26,
      )),
    );
  }
}

class _HomeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final innerRadius = size.width * 0.30;
    final center = Offset(cx, cy);
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.clipPath(clipPath);
    canvas.drawCircle(center, innerRadius, Paint()..color = Colors.white);
    final blackPath = Path()
      ..moveTo(cx + innerRadius, cy - innerRadius)
      ..lineTo(cx + innerRadius, cy + innerRadius)
      ..lineTo(cx - innerRadius, cy + innerRadius)
      ..close();
    canvas.drawPath(blackPath, Paint()..color = const Color(0xFF2C2C2C));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

class _ArchiveIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(4)), paint);
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.35), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.32, size.height * 0.52, size.width * 0.36, size.height * 0.16),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
                  _FoldsTopBar(title: 'DAILY PUZZLES', onBack: () => Navigator.pop(context)),
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
                  const SizedBox(height: 16),
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
                    itemCount: _dailies.length,
                    itemBuilder: (context, i) {
                      final puzzle = _dailies[i];
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
                              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
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
              child: _BackButton(label: 'BACK TO MORE PUZZLES', onTap: () => Navigator.pop(context)),
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
              _FoldsTopBar(title: 'STORE', onBack: () => Navigator.pop(context)),
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
              // ── Stacked full-width packs ──────────────────
              _FullWidthStoreCard(
                title: 'NO ADS',
                subtitle: 'REMOVE ALL ADS FOREVER',
                price: '\$2.99',
                shape: _StoreShape.noAds,
                productId: 'games.jaydev.folds.no_ads',
              ),
              const SizedBox(height: 12),
              _FullWidthStoreCard(
                title: 'RECTANGLE PACK',
                subtitle: '100 PUZZLES',
                price: '\$2.99',
                shape: _StoreShape.rectangle,
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
            ],
          ),
        ),
      ),
    );
  }
}

enum _StoreShape { rectangle, circle, hexa, noAds }

class _FullWidthStoreCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final _StoreShape shape;
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
                  _ShapeWidget(shape: shape, size: 64),
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
    required this.label, required this.price,
    this.badge, required this.productId,
  });

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

// ── Shape widget ──────────────────────────────────────────────────────────────
class _ShapeWidget extends StatelessWidget {
  final _StoreShape shape;
  final double size;

  const _ShapeWidget({required this.shape, required this.size});

  @override
  Widget build(BuildContext context) {
    switch (shape) {
      case _StoreShape.rectangle:
        return CustomPaint(size: Size(size, size * 0.7), painter: _RectanglePainter());
      case _StoreShape.circle:
        return CustomPaint(size: Size(size, size), painter: _CirclePainter());
      case _StoreShape.hexa:
        return CustomPaint(size: Size(size, size), painter: _HexaPainter());
      case _StoreShape.noAds:
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size, height: size,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
            ),
            Text('ADS',
              style: GoogleFonts.dmSans(fontSize: size * 0.25, fontWeight: FontWeight.w800, color: Colors.white)),
            CustomPaint(size: Size(size, size), painter: _NoBanPainter()),
          ],
        );
    }
  }
}

class _RectanglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width / 2, size.height), paint);
    canvas.drawRect(Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height),
      Paint()..color = const Color(0xFF2C2C2C));
  }
  @override bool shouldRepaint(_) => false;
}

class _CirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawPath(path, Paint()..color = const Color(0xFF2C2C2C));
    canvas.restore();
  }
  @override bool shouldRepaint(_) => false;
}

class _HexaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * 3.1416 / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    final clip = Path()..addPath(path, Offset.zero);
    canvas.save();
    canvas.clipPath(clip);
    final dark = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(dark, Paint()..color = const Color(0xFF2C2C2C));
    canvas.restore();
  }
  @override bool shouldRepaint(_) => false;
}

class _NoBanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - paint.strokeWidth / 2;
    canvas.drawCircle(c, r, paint);
    canvas.drawLine(
      Offset(c.dx + r * cos(2.356), c.dy + r * sin(2.356)),
      Offset(c.dx + r * cos(5.498), c.dy + r * sin(5.498)),
      paint,
    );
  }
  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _theme = 0;
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              _FoldsTopBar(title: 'SETTINGS', onBack: () => Navigator.pop(context)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16, bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader('VISUAL'),
                      _SegmentedRow(
                        title: 'Theme',
                        hint: 'Based off of local time',
                        options: const ['LIGHT', 'DARK', 'AUTO'],
                        selected: _theme,
                        onChanged: (i) => setState(() => _theme = i),
                      ),
                      _ToggleRow(
                        title: 'Reduced Motion',
                        subtitle: 'Disables aesthetic animations',
                        value: _reducedMotion,
                        onChanged: (v) => setState(() => _reducedMotion = v),
                      ),

                      _SectionHeader('GAMEPLAY'),
                      _ToggleRow(
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
                        child: _ToggleRow(
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
                      _SegmentedRow(
                        title: 'Moves Display',
                        options: const ['DOTS', 'NUMBERS'],
                        selected: _movesDisplay,
                        onChanged: (i) => setState(() {
                          _movesDisplay = i;
                          AppStore.movesDisplay = i;
                        }),
                      ),
                      _ToggleRow(
                        title: 'Haptic Vibration',
                        value: _haptic,
                        onChanged: (v) => setState(() {
                          _haptic = v;
                          AppStore.haptic = v;
                          AppSettings.haptic = v;
                        }),
                      ),

                      _SectionHeader('AUDIO'),
                      _SliderRow(
                        title: 'SFX',
                        value: _sfx,
                        onChanged: (v) => setState(() => _sfx = v),
                      ),
                      const SizedBox(height: 12),
                      Text('Current Track',
                        style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
                      const SizedBox(height: 10),
                      _TrackPlayerCard(
                        isPlaying: _isPlaying,
                        onPlayToggle: () => setState(() => _isPlaying = !_isPlaying),
                        volume: _trackVolume,
                        onVolumeChanged: (v) => setState(() => _trackVolume = v),
                      ),

                      _SectionHeader('ACCOUNT & DATA'),
                      _ActionPill(label: 'Sync Progress', onTap: () {}),
                      const SizedBox(height: 10),
                      _ActionPill(label: 'Restore Purchases', onTap: () {}),
                      const SizedBox(height: 10),
                      _ActionPill(
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
                      _SectionHeader('PERFORMANCE'),
                      _SegmentedRow(
                        title: 'Frame Rate Cap',
                        subtitle: 'Maximum frame rate. Affects smoothness & feel',
                        options: const ['30 FPS', '60 FPS', '120 FPS'],
                        selected: _frameRate,
                        onChanged: (i) => setState(() => _frameRate = i),
                      ),
                      _ToggleRow(
                        title: 'Static Backgrounds',
                        value: _staticBg,
                        onChanged: (v) => setState(() => _staticBg = v),
                      ),

                      _SectionHeader('NOTIFICATIONS'),
                      _ToggleRow(
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
                                child: _TimeDisplay(
                                  hour: _notifTime.hour.toString().padLeft(2, '0'),
                                  minute: _notifTime.minute.toString().padLeft(2, '0'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _ToggleRow(
                        title: 'New Packs Notif',
                        subtitle: 'Notifies you if any new packs come out!',
                        value: _newPacksNotif,
                        onChanged: (v) => setState(() => _newPacksNotif = v),
                      ),

                      _SectionHeader('ADVANCED INPUT'),
                      _SegmentedRow(
                        title: 'Handed Mode',
                        subtitle: 'Flips orientation for landscape puzzles',
                        options: const ['RIGHT', 'LEFT'],
                        selected: _handedMode,
                        onChanged: (i) => setState(() => _handedMode = i),
                      ),

                      _SectionHeader('PRIVACY & SECURITY'),
                      _ToggleRow(
                        title: 'Opt Out of Data Usage',
                        subtitle: 'Disables using your data for personal & general enhancement',
                        value: _optOutData,
                        onChanged: (v) => setState(() => _optOutData = v),
                      ),
                      _OpenRow(title: 'ToS and Privacy Policy', onTap: () => _launchUrl('https://jaydev.games/privacy')),

                      _SectionHeader('ABOUT & VERSIONING'),
                      _OpenRow(title: 'Credits', onTap: () => _pushFade(context, const CreditsScreen())),
                      _OpenRow(title: 'Folds Website', onTap: () => _launchUrl('https://folds.jaydev.games')),
                      _OpenRow(title: 'Socials & YouTube', onTap: () => _pushFade(context, const SocialsScreen())),
                      const SizedBox(height: 16),
                      _ActionPill(
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
                        child: Text('version 1.0.0',
                          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
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

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(label,
        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 1.2)),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double titleSize;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    this.subtitle,
    this.titleSize = 20,
    this.enabled = true,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.dmSans(fontSize: titleSize, fontWeight: FontWeight.w800, color: Colors.black)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                        style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black38)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF7BD957),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFBDBDBD),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? hint;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const _SegmentedRow({
    required this.title,
    this.subtitle,
    this.hint,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!,
                          style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black38)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _SegmentedControl(options: options, selected: selected, onChanged: onChanged),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(hint!,
                  style: GoogleFonts.dmSans(fontSize: 11, color: Colors.black26)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const _SegmentedControl({required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final isSelected = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD6D6D6) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(options[i],
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.black : Colors.black38,
                  letterSpacing: 0.5,
                )),
            ),
          );
        }),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderRow({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(title,
              style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF2C2C2C),
                inactiveTrackColor: const Color(0xFFBDBDBD),
                thumbColor: const Color(0xFFE8E8E8),
                overlayColor: Colors.black12,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
                trackHeight: 6,
              ),
              child: Slider(value: value, onChanged: onChanged),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackPlayerCard extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayToggle;
  final double volume;
  final ValueChanged<double> onVolumeChanged;

  const _TrackPlayerCard({
    required this.isPlaying,
    required this.onPlayToggle,
    required this.volume,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.music_note_rounded, color: Color(0xFF2C2C2C), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thrifty & Swifty',
                    style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
                  Text('Broke Making Bank',
                    style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black38)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onPlayToggle,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(isPlaying),
                  color: Colors.black,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.volume_down_rounded, color: Colors.black38, size: 18),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF2C2C2C),
                  inactiveTrackColor: const Color(0xFFBDBDBD),
                  thumbColor: const Color(0xFFE8E8E8),
                  overlayColor: Colors.black12,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  trackHeight: 4,
                ),
                child: Slider(value: volume, onChanged: onVolumeChanged),
              ),
            ),
            const Icon(Icons.volume_up_rounded, color: Colors.black38, size: 18),
          ],
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final Color? textColor;
  final VoidCallback onTap;

  const _ActionPill({required this.label, this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: textColor ?? Colors.black26)),
        ),
      ),
    );
  }
}

class _OpenRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _OpenRow({required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                      style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black38)),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('OPEN',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  final String hour;
  final String minute;
  const _TimeDisplay({required this.hour, required this.minute});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _digitBox(hour[0]),
        const SizedBox(width: 4),
        _digitBox(hour[1]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(':', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
        ),
        _digitBox(minute[0]),
        const SizedBox(width: 4),
        _digitBox(minute[1]),
      ],
    );
  }

  Widget _digitBox(String d) {
    return Container(
      width: 28, height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(d, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
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
              _FoldsTopBar(title: 'CREDITS', onBack: () => Navigator.pop(context)),
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
              _FoldsTopBar(title: 'SOCIALS', onBack: () => Navigator.pop(context)),
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
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _tab == 0
                      ? const _ProfileTab(key: ValueKey('profile'))
                      : Center(
                          key: ValueKey('placeholder$_tab'),
                          child: Text(
                            _tab == 1 ? 'Stats coming soon!' : 'Achievements coming soon!',
                            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black38),
                          ),
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
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: AppStore.username);
    final path = AppStore.avatarPath;
    if (path != null && File(path).existsSync()) {
      _avatarImage = File(path);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _avatarImage = File(picked.path));
      AppStore.avatarPath = picked.path;
    }
  }

  void _saveName(String v) {
    AppStore.username = v;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
                      : null,
                ),
                child: _avatarImage == null
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
          TextField(
            controller: _nameController,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black),
            decoration: const InputDecoration(
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
            onChanged: _saveName,
          ),
          const SizedBox(height: 4),
          Text(AppStore.joinDate,
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700,
                color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 20),
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
          _ProgressBar(progress: xpProgress, color: const Color(0xFFFFD465),
              label: '$xp XP total'),
          _divider(),

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
            _ProgressBar(
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

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final String label;
  const _ProgressBar({required this.progress, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toInt();
    return Stack(
      children: [
        Container(
          height: 26,
          decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(13)),
          child: Row(
            children: [
              Expanded(
                flex: pct,
                child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(13))),
              ),
              Expanded(flex: 100 - pct, child: const SizedBox()),
            ],
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(label,
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black54)),
            ),
          ),
        ),
      ],
    );
  }
}