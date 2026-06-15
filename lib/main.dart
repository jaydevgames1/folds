import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://kvihtmzgthznjtwqtbvg.supabase.co',
    anonKey: 'sb_publishable_hznxJ0hZwXRvO-KHZuoYag_RXPDWfWI',
  );
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
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 250),
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
  String _title = '';
  String _author = '';
  int _difficulty = 1;
  String _id = '';
  int _par = 5;
  int _moves = 0;
  bool _loaded = false;
  bool _loading = true;
  bool _notFound = false;
  bool _solved = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        final m = _stopwatch.elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
        final s = _stopwatch.elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
        _timeDisplay = '$m:$s';
      });
    });
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

  void _resetTimer() {
    _stopwatch.reset();
    _stopwatch.start();
    _timer.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        final m = _stopwatch.elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
        final s = _stopwatch.elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
        _timeDisplay = '$m:$s';
      });
    });
    setState(() => _timeDisplay = '00:00');
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
      setState(() {
        _cells = (response['cells'] as List).map((e) => e == 1).toList();
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
    const pairs = [
      [0, 3], [1, 2], [4, 7], [5, 6],
      [8, 11], [9, 10], [12, 15], [13, 14],
    ];
    return pairs.every((p) => _cells[p[0]] == _cells[p[1]]);
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
                  puzzleTitle: _title,
                  timeDisplay: _timeDisplay,
                  moves: _moves,
                  par: _par,
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
                        final cellSize = (constraints.maxWidth - 24) / 4;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(4, (row) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: row < 3 ? 8 : 0),
                              child: Row(
                                children: List.generate(4, (col) {
                                  final index = row * 4 + col;
                                  return Padding(
                                    padding: EdgeInsets.only(right: col < 3 ? 8 : 0),
                                    child: SizedBox(
                                      width: cellSize,
                                      height: cellSize,
                                      child: _FlipCell(
                                        isBlack: _cells[index],
                                        onTap: () {
                                          if (_paused) return; // Prevent tapping grid while paused
                                          setState(() {
                                            _cells[index] = !_cells[index];
                                            _moves++;
                                          });
                                          if (_isSymmetrical()) {
                                          _stopwatch.stop();
                                          _timer.cancel();
                                          setState(() => _solved = true);
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
                                _timer = Timer.periodic(const Duration(seconds: 1), (_) {
                                  setState(() {
                                    final m = _stopwatch.elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
                                    final s = _stopwatch.elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
                                    _timeDisplay = '$m:$s';
                                  });
                                });
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
                        Text(_timeDisplay, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black)),
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
                            Text('#${_id.replaceAll(RegExp(r'^[a-z]+'), '')} $_title', style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black)),
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
class PuzzlesMenuScreen extends StatelessWidget {
  const PuzzlesMenuScreen({super.key});

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
                  Container(
                    width: 76, height: 100,
                    decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)),
                    child: Center(child: CustomPaint(size: const Size(28, 24), painter: _ArchiveIconPainter())),
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
          completedPuzzles: 79,
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
          completedPuzzles: 0,
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
                        completed: 39,
                        total: 50,
                        gridSize: 4,
                        onPlay: () => Navigator.pop(context),
                        onHome: () => _pushFade(context, const PuzzleSelectorScreen(packName: '4x4', totalPuzzles: 50, idPrefix: 'p', idOffset: 0)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _PuzzleSizeCard(
                        label: '6x6',
                        puzzleCount: '30 PUZZLES',
                        completed: 0,
                        total: 30,
                        gridSize: 6,
                        onPlay: () {},
                        onHome: () => _pushFade(context, const PuzzleSelectorScreen(packName: '6x6', totalPuzzles: 30, idPrefix: 'p', idOffset: 50)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _PuzzleSizeCard(
                        label: '8x8',
                        puzzleCount: '20 PUZZLES',
                        completed: 0,
                        total: 20,
                        gridSize: 8,
                        onPlay: () {},
                        onHome: () => _pushFade(context, const PuzzleSelectorScreen(packName: '8x8', totalPuzzles: 20, idPrefix: 'p', idOffset: 80)),
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
    const completedPuzzles = {1, 2, 3, 4, 5};
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
                            transitionsBuilder: (_, animation, __, child) =>
                                FadeTransition(opacity: animation, child: child),
                            transitionDuration: const Duration(milliseconds: 250),
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
  final String puzzleTitle;
  final String timeDisplay;
  final int moves;
  final int par;
  final VoidCallback onRetry;
  final List<bool> cells;

  const FoldCompleteAnimator({
    super.key,
    required this.puzzleId,
    required this.puzzleTitle,
    required this.timeDisplay,
    required this.moves,
    required this.par,
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

    _foldCtrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _envelopeCtrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _flipCtrl = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _stampCtrl = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _statsCtrl = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);

    _foldAngle = Tween<double>(begin: 0, end: pi / 2).animate(
      CurvedAnimation(parent: _foldCtrl, curve: Curves.easeInOut));

    _envelopeSlide = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _envelopeCtrl, curve: Curves.easeOut));
    _flapClose = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _envelopeCtrl, curve: const Interval(0.5, 1.0, curve: Curves.easeInOut)));

    _flipAngle = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut));

    _stampScale = Tween<double>(begin: 3.0, end: 1.0).animate(
      CurvedAnimation(parent: _stampCtrl, curve: Curves.elasticOut));

    _statsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _statsCtrl, curve: Curves.easeOut));
    _statsSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _statsCtrl, curve: Curves.easeOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Stage 0: fold
    await Future.delayed(const Duration(milliseconds: 200));
    await _foldCtrl.forward();

    // Stage 1: envelope slides up
    setState(() => _stage = 1);
    await _envelopeCtrl.forward();

    // Stage 2: flip envelope
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _stage = 2);
    await _flipCtrl.forward();

    // Stage 3: stamp
    await Future.delayed(const Duration(milliseconds: 150));
    setState(() => _stage = 3);
    await _stampCtrl.forward();

    // Stage 4: stats
    await Future.delayed(const Duration(milliseconds: 300));
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
    final id = widget.puzzleId.replaceAll(RegExp(r'^[a-z]+'), '');
    return 'Folds\n#$id ${widget.puzzleTitle}\n${widget.timeDisplay} ⏳, 0 💡, ${widget.moves}/${widget.par} ➡️\nhttps://folds.jaydev.games/puzzles/pilot/${widget.puzzleId}';
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

  const _StatsCard({
    required this.timeDisplay,
    required this.moves,
    required this.par,
    required this.isUnderPar,
    required this.shareText,
    required this.onRetry,
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
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Share button
          GestureDetector(
            onTap: () {
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied!',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                  backgroundColor: const Color(0xFF2C2C2C),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
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
          ),
          const SizedBox(height: 8),

          // Copy + Retry row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    
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

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: _FoldsTopBar(title: 'STORE', onBack: () => Navigator.pop(context)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ── Full Fold Bundle ──────────────────────────
                    _BundleCard(),
                    const SizedBox(height: 8),

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

                    // ── 2x2 packs ─────────────────────────────────
                    Row(
                      children: [
                        Expanded(child: _PackStoreCard(
                          title: 'RECTANGLE\nPACK',
                          price: '\$2.99',
                          shape: _StoreShape.rectangle,
                          productId: 'games.jaydev.folds.rectangle_pack',
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _PackStoreCard(
                          title: 'RADIAL\nPACK',
                          price: '\$2.99',
                          shape: _StoreShape.circle,
                          productId: 'games.jaydev.folds.radial_pack',
                        )),
                        const SizedBox(width: 12),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _PackStoreCard(
                          title: 'HEXA\nPACK',
                          price: '\$2.99',
                          shape: _StoreShape.hexa,
                          productId: 'games.jaydev.folds.hexa_pack',
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _PackStoreCard(
                          title: 'NO ADS',
                          price: '\$2.99',
                          shape: _StoreShape.noAds,
                          productId: 'games.jaydev.folds.no_ads',
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Hints row ─────────────────────────────────
                    Row(
                      children: [
                        Expanded(child: _HintCard(label: '5 HINTS', price: '\$0.99', productId: 'games.jaydev.folds.hints_5')),
                        const SizedBox(width: 8),
                        Expanded(child: _HintCard(label: '25 HINTS', price: '\$3.99', productId: 'games.jaydev.folds.hints_25')),
                        const SizedBox(width: 8),
                        Expanded(child: _HintCard(label: '∞ HINTS', price: '\$7.99', productId: 'games.jaydev.folds.hints_unlimited')),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bundle card ───────────────────────────────────────────────────────────────
class _BundleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('The Full Fold',
                        style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 8),
                      _bundleItem('Rectangle Pack'),
                      _bundleItem('Radial Pack'),
                      _bundleItem('Hexa Pack'),
                      _bundleItem('Pilot Pack'),
                      _bundleItem('No Ads'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 2x2 icon grid
                Column(
                  children: [
                    Row(
                      children: [
                        _BundleIcon(shape: _StoreShape.rectangle),
                        const SizedBox(width: 6),
                        _BundleIcon(shape: _StoreShape.circle),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _BundleIcon(shape: _StoreShape.noAds),
                        const SizedBox(width: 6),
                        _BundleIcon(shape: _StoreShape.hexa),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            // Price badge
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD465),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('From \$9.99',
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bundleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(text,
        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70)),
    );
  }
}

class _BundleIcon extends StatelessWidget {
  final _StoreShape shape;
  const _BundleIcon({required this.shape});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFd9d9d9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: _ShapeWidget(shape: shape, size: 32)),
    );
  }
}

// ── Pack store card ───────────────────────────────────────────────────────────
enum _StoreShape { rectangle, circle, hexa, noAds }

class _PackStoreCard extends StatelessWidget {
  final String title;
  final String price;
  final _StoreShape shape;
  final String productId;

  const _PackStoreCard({
    required this.title, required this.price,
    required this.shape, required this.productId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(title,
                    style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                  const SizedBox(height: 6),
                  Text('100 PUZZLES',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
                  const SizedBox(height: 16),
                  Center(child: _ShapeWidget(shape: shape, size: 64)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
  bool _showTimer = true;
  bool _enableMs = false;
  int _movesDisplay = 0;
  bool _haptic = true;
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
                        onChanged: (v) => setState(() => _showTimer = v),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _ToggleRow(
                          title: 'Enable Milliseconds',
                          titleSize: 15,
                          value: _enableMs,
                          onChanged: (v) => setState(() => _enableMs = v),
                        ),
                      ),
                      _SegmentedRow(
                        title: 'Moves Display',
                        options: const ['DOTS', 'NUMBERS'],
                        selected: _movesDisplay,
                        onChanged: (i) => setState(() => _movesDisplay = i),
                      ),
                      _ToggleRow(
                        title: 'Haptic Vibration',
                        value: _haptic,
                        onChanged: (v) => setState(() => _haptic = v),
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
                      _ActionPill(label: 'Reset Progress', textColor: const Color(0xFFE6543A), onTap: () {}),

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
                              const _TimeDisplay(hour: '08', minute: '00'),
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
                      _ActionPill(label: 'Reset All Settings', textColor: const Color(0xFFE6543A), onTap: () {}),
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
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    this.subtitle,
    this.titleSize = 20,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF7BD957),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFBDBDBD),
          ),
        ],
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 20, bottom: 32),
                  child: Column(
                    children: [
                      _SocialCard(
                        icon: Icons.forum_rounded,
                        iconColor: const Color(0xFF5865F2),
                        title: 'Discord',
                        subtitle: 'Stay in touch with the community, preview exclusive sneak peeks and suggest ideas.',
                        onTap: () {},
                      ),
                      const SizedBox(height: 14),
                      _SocialCard(
                        icon: Icons.smart_display_rounded,
                        iconColor: const Color(0xFFFF3B30),
                        title: 'YouTube',
                        subtitle: 'View updates, new additions and fantastic content all online.',
                        onTap: () => _launchUrl('https://www.youtube.com/@JayDevGames1'),
                      ),
                      const SizedBox(height: 14),
                      _SocialCard(
                        icon: Icons.music_note_rounded,
                        iconColor: const Color(0xFF25F4EE),
                        title: 'TikTok',
                        subtitle: 'Get regular updates, limited but exclusive behind-the-scenes videos & more.',
                        onTap: () => _launchUrl('https://www.tiktok.com/@jaydevgames'),
                      ),
                      const SizedBox(height: 14),
                      _SocialCard(
                        icon: Icons.camera_alt_rounded,
                        iconColor: const Color(0xFFE1306C),
                        title: 'Instagram',
                        subtitle: 'Get regular updates, limited but exclusive behind-the-scenes videos & more.',
                        onTap: () => _launchUrl('https://www.instagram.com/jaydev_games'),
                      ),
                      const SizedBox(height: 14),
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
          padding: const EdgeInsets.all(16),
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

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Stack(
            children: [
              Container(
                width: 120, height: 120,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEFEFEF)),
                child: const Icon(Icons.person_rounded, color: Color(0xFFC4C4C4), size: 72),
              ),
              Positioned(
                right: 0, top: 4,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Puzzle Apprentice',
            style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 4),
          Text('JOINED 18 APRIL 2026',
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 20),
          Container(height: 1.5, color: const Color(0xFF2C2C2C)),
          const SizedBox(height: 20),

          _ProfileStatRow(
            label: 'Daily Streak',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text('207', style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black)),
                const SizedBox(width: 6),
                Text('days', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
              ],
            ),
          ),
          _divider(),

          _ProfileStatRow(
            label: 'Rank',
            trailing: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.shield_rounded, color: Color(0xFFC17A36), size: 38),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('5', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
          ),
          _divider(),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recently Played',
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(8)),
                child: Text('PILOT',
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBar(progress: 0.51, color: const Color(0xFF7BD957), label: '51%'),
          _divider(),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('XP',
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
              Row(
                children: [
                  Text('867 / 1000 XP',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black54)),
                  const SizedBox(width: 8),
                  Text('to',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
                  const SizedBox(width: 8),
                  Container(
                    width: 28, height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Color(0xFF2C2C2C), shape: BoxShape.circle),
                    child: Text('6', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBar(progress: 0.87, color: const Color(0xFFA8B0CC), label: '87%'),
          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Share Game',
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
              GestureDetector(
                onTap: () {},
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

class _ProfileStatRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  const _ProfileStatRow({required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
        trailing,
      ],
    );
  }
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