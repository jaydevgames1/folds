import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';

// ── Set this to your own private password before building ─────────────────
const String _kDevPassword = 'ilovefoldy';
const String _kModPassword = 'foldsmoderator245!';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await Supabase.initialize(
    url: 'https://kvihtmzgthznjtwqtbvg.supabase.co',
    anonKey: 'sb_publishable_hznxJ0hZwXRvO-KHZuoYag_RXPDWfWI',
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

class AppSettings {
  static bool showTimer = true;
  static bool enableMs = false;
  static int movesDisplay = 0;
  static bool haptic = true;
  static bool musicEnabled = true;
  static double musicVolume = 0.4;
  static bool sfxEnabled = true;
  static double sfxVolume = 0.55;
}

// ─────────────────────────────────────────────────────────────────────────────
// PERSISTENT STORE
// ─────────────────────────────────────────────────────────────────────────────
class AppStore {
  static bool isDeveloperMode = false;
  static SharedPreferences? _p;
  
  // Supabase integration shortcut helper
  static User? get currentUser => Supabase.instance.client.auth.currentUser;

  // Helper function to safely run background cloud updates
  static void _syncToCloud(Map<String, dynamic> data) {
    if (currentUser == null || currentUser!.isAnonymous) return;
    final localJoinDate = _p?.getString('joinDate') ?? '';
    final safeData = <String, dynamic>{
      if (localJoinDate.startsWith('JOINED ')) 'join_date': localJoinDate,
      ...data,
    };
    // UPDATE only — the Supabase trigger creates the row on signup.
    // UPSERT would attempt an INSERT which is blocked by RLS.
    Supabase.instance.client
        .from('profiles')
        .update(safeData)
        .eq('id', currentUser!.id)
        .then((_) => debugPrint("Cloud synced: ${data.keys.join(', ')}"))
        .catchError((err) => debugPrint("Cloud sync failed: $err"));
  }

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    
    // IF logged in, sync down latest server cloud values before pulling into settings objects
    if (currentUser != null) {
      await downloadCloudProfile();
    }

    // Push saved settings into AppSettings on load
    AppSettings.showTimer = _p?.getBool('showTimer') ?? true;
    AppSettings.enableMs = _p?.getBool('enableMs') ?? false;
    AppSettings.movesDisplay = _p?.getInt('movesDisplay') ?? 0;
    AppSettings.haptic = _p?.getBool('haptic') ?? true;
  }

  // Method to download everything from Supabase and cache it locally on startup or login
  static Future<void> downloadCloudProfile() async {
    if (currentUser == null) return;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();

      // Write everything down straight into your local SharedPreferences cache
      await _p?.setString('username', data['username'] ?? 'Puzzle Apprentice');
      if (data['avatar_path'] != null) {
        await _p?.setString('avatarPath', data['avatar_path']);
      } else {
        await _p?.remove('avatarPath');
      }
      final cloudJoinDate = data['join_date']?.toString() ?? '';
      if (cloudJoinDate.startsWith('JOINED ')) {
        await _p?.setString('joinDate', cloudJoinDate);
      }
      // If cloud value is missing or badly formatted, keep local value intact
      await _p?.setInt('totalXP', data['total_xp'] ?? 0);
      await _p?.setInt('totalFlips', data['total_flips'] ?? 0);
      await _p?.setBool('showTimer', data['show_timer'] ?? true);
      await _p?.setBool('enableMs', data['enable_ms'] ?? false);
      await _p?.setInt('movesDisplay', data['moves_display'] ?? 0);
      await _p?.setBool('haptic', data['haptic'] ?? true);
      await _p?.setInt('notifHour', data['notif_hour'] ?? 8);
      await _p?.setInt('notifMinute', data['notif_minute'] ?? 0);
      await _p?.setString('recentPack', data['recent_pack'] ?? '');

      // Convert dynamic database text arrays back cleanly into local Lists
      if (data['unlocked_achievements'] != null) {
        final List<String> list = List<String>.from(data['unlocked_achievements']);
        await _p?.setStringList('unlockedAchievements', list);
      }
      if (data['completed_puzzles'] != null) {
        final List<String> list = List<String>.from(data['completed_puzzles']);
        await _p?.setStringList('completedPuzzles', list);
      }
      if (data['failed_puzzles'] != null) {
        final List<String> list = List<String>.from(data['failed_puzzles']);
        await _p?.setStringList('failedPuzzles', list);
      }
      if (data['par_puzzles'] != null) {
        final List<String> list = List<String>.from(data['par_puzzles']);
        await _p?.setStringList('parPuzzles', list);
      }
      await _p?.setInt('currentStreak', data['current_streak'] ?? 0);
      if (data['last_daily_date'] != null) {
        await _p?.setString('lastDailyDate', data['last_daily_date']);
      }
      await _p?.setBool('isModerator', data['is_moderator'] ?? false);
    } catch (e) {
      debugPrint("Error bringing down cloud profile values: $e");
    }
  }

  // ── Stats
  static int get totalFlips => _p?.getInt('totalFlips') ?? 0;
  static set totalFlips(int v) {
    _p?.setInt('totalFlips', v);
    _syncToCloud({'total_flips': v});
  }

  // ── Achievements
  static Set<String> get unlockedAchievements =>
      (_p?.getStringList('unlockedAchievements') ?? []).toSet();
  static void unlockAchievement(String id) {
    final s = unlockedAchievements..add(id);
    final list = s.toList();
    _p?.setStringList('unlockedAchievements', list);
    _syncToCloud({'unlocked_achievements': list});
  }
  static bool isUnlocked(String id) => unlockedAchievements.contains(id);

  // ── Profile
  // ── Profile
  static String get username => _p?.getString('username') ?? 'Puzzle Apprentice';
  static set username(String v) {
    _p?.setString('username', v);
    _syncToCloud({'username': v});
  }

  // Prefers the signed-in account's username (set at sign up) over the
  // local guest username, so Profile always shows who's actually logged in.
  static Future<bool> isUsernameAvailable(String username) async {
    try {
      final result = await Supabase.instance.client
          .rpc('check_username_available', params: {'check_username': username});
      return result == true;
    } catch (_) {
      return true; // fail open — trigger constraint catches duplicates
    }
  }

  static String get displayUsername {
    final metaName = currentUser?.userMetadata?['username'];
    if (metaName is String && metaName.trim().isNotEmpty) return metaName;
    return username;
  }

  static String? get avatarPath => _p?.getString('avatarPath');
  static set avatarPath(String? v) {
    v == null ? _p?.remove('avatarPath') : _p?.setString('avatarPath', v);
    _syncToCloud({'avatar_path': v});
  }

  static String get joinDate => _p?.getString('joinDate') ?? _initJoinDate();
  static String _initJoinDate() {
    final d = DateTime.now();
    final months = ['','JANUARY','FEBRUARY','MARCH','APRIL','MAY','JUNE',
        'JULY','AUGUST','SEPTEMBER','OCTOBER','NOVEMBER','DECEMBER'];
    final s = 'JOINED ${d.day} ${months[d.month]} ${d.year}';
    _p?.setString('joinDate', s);
    _syncToCloud({'join_date': s});
    return s;
  }

  static bool get haptic => _p?.getBool('haptic') ?? true;
  static set haptic(bool v) {
    _p?.setBool('haptic', v);
    _syncToCloud({'haptic': v});
  }

  // ── Onboarding
  static bool get hasSeenOnboarding => _p?.getBool('hasSeenOnboarding') ?? false;
  static set hasSeenOnboarding(bool v) => _p?.setBool('hasSeenOnboarding', v);

  // ── Moderator
  static bool get isModerator => _p?.getBool('isModerator') ?? false;
  static set isModerator(bool v) => _p?.setBool('isModerator', v);

  // ── Dev profile badge (set via dev panel, persists)
  static bool get isDevProfile => _p?.getBool('isDevProfile') ?? false;
  static set isDevProfile(bool v) => _p?.setBool('isDevProfile', v);

  // ── Streak
  static int get currentStreak => _p?.getInt('currentStreak') ?? 0;
  static String get _lastDailyDate => _p?.getString('lastDailyDate') ?? '';

  static void updateStreak() {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
    if (_lastDailyDate == todayStr) return;
    final yesterday = today.subtract(const Duration(days: 1));
    final yStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2,'0')}-${yesterday.day.toString().padLeft(2,'0')}';
    final newStreak = _lastDailyDate == yStr ? currentStreak + 1 : 1;
    _p?.setInt('currentStreak', newStreak);
    _p?.setString('lastDailyDate', todayStr);
    _syncToCloud({'current_streak': newStreak, 'last_daily_date': todayStr});
  }

  // Dev helpers
  static void devSetStreak(int v) { _p?.setInt('currentStreak', v); _p?.setString('lastDailyDate', ''); }
  static void devResetStreak() { _p?.setInt('currentStreak', 0); _p?.remove('lastDailyDate'); }

  // Whether today's daily has been completed (drives fire colour)
  static bool get isStreakDoneToday {
    final launchDate = DateTime(2026, 06, 1);
    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    final dayNumber = todayClean.difference(launchDate).inDays + 1;
    if (dayNumber < 1) return false;
    return isCompleted('d$dayNumber');
  }

  // ── XP
  static int get totalXP => _p?.getInt('totalXP') ?? 0;
  static set totalXP(int v) {
    _p?.setInt('totalXP', v);
    _syncToCloud({'total_xp': v});
  }

  // ── Completed puzzles
  static Set<String> get completedPuzzles =>
      (_p?.getStringList('completedPuzzles') ?? []).toSet();
  static void markCompleted(String id) {
    final s = completedPuzzles..add(id);
    final list = s.toList();
    _p?.setStringList('completedPuzzles', list);
    _syncToCloud({'completed_puzzles': list});
  }
  static bool isCompleted(String id) => completedPuzzles.contains(id);

  // ── Failed puzzles (for "after par" detection)
  // ── Par puzzles: completed at or under par → green tick (only ever grows)
  static Set<String> get parPuzzles =>
      (_p?.getStringList('parPuzzles') ?? []).toSet();
  static void markParCompleted(String id) {
    if (isParCompleted(id)) return;
    final s = parPuzzles..add(id);
    final list = s.toList();
    _p?.setStringList('parPuzzles', list);
    _syncToCloud({'par_puzzles': list});
  }
  static bool isParCompleted(String id) => parPuzzles.contains(id);

  // ── Failed puzzles (for "after par" detection)
  static Set<String> get failedPuzzles =>
      (_p?.getStringList('failedPuzzles') ?? []).toSet();
  static void markFailed(String id) {
    final s = failedPuzzles..add(id);
    final list = s.toList();
    _p?.setStringList('failedPuzzles', list);
    _syncToCloud({'failed_puzzles': list});
  }
  static bool hasFailed(String id) => failedPuzzles.contains(id);

  // ── Recently played pack
  static String get recentPack => _p?.getString('recentPack') ?? '';
  static set recentPack(String v) {
    _p?.setString('recentPack', v);
    _syncToCloud({'recent_pack': v});
  }

  // ── Settings
  static bool get showTimer => _p?.getBool('showTimer') ?? true;
  static set showTimer(bool v) {
    _p?.setBool('showTimer', v);
    AppSettings.showTimer = v;
    _syncToCloud({'show_timer': v});
  }

  static bool get enableMs => _p?.getBool('enableMs') ?? false;
  static set enableMs(bool v) {
    _p?.setBool('enableMs', v);
    AppSettings.enableMs = v;
    _syncToCloud({'enable_ms': v});
  }

  static int get movesDisplay => _p?.getInt('movesDisplay') ?? 0;
  static set movesDisplay(int v) {
    _p?.setInt('movesDisplay', v);
    AppSettings.movesDisplay = v;
    _syncToCloud({'moves_display': v});
  }

  static int get notifHour => _p?.getInt('notifHour') ?? 8;
  static int get notifMinute => _p?.getInt('notifMinute') ?? 0;
  
  static void setNotifTime(TimeOfDay t) {
    _p?.setInt('notifHour', t.hour);
    _p?.setInt('notifMinute', t.minute);
    _syncToCloud({
      'notif_hour': t.hour,
      'notif_minute': t.minute,
    });
  }
  
  static TimeOfDay get notifTime =>
      TimeOfDay(hour: notifHour, minute: notifMinute);

  // ── Progress stats
  static int get puzzlesCompleted =>
      completedPuzzles.where((id) => !id.startsWith('d')).length;

  static int get todayCompletedCount {
    final today = DateTime.now();
    final key = 'dailyCount_${today.year}_${today.month}_${today.day}';
    return _p?.getInt(key) ?? 0;
  }
  static void incrementTodayCount() {
    final today = DateTime.now();
    final key = 'dailyCount_${today.year}_${today.month}_${today.day}';
    _p?.setInt(key, todayCompletedCount + 1);
  }
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
    final fields = ['totalXP','completedPuzzles','failedPuzzles','parPuzzles','recentPack', 'totalFlips', 'unlockedAchievements'];
    for (final k in fields) {
      await _p?.remove(k);
    }
    _syncToCloud({
      'total_xp': 0,
      'total_flips': 0,
      'recent_pack': '',
      'unlocked_achievements': <String>[],
      'completed_puzzles': <String>[],
      'failed_puzzles': <String>[],
      'par_puzzles': <String>[],
    });
  }

  // ── Offline puzzle cache
  static bool get hasOfflinePuzzles => (_p?.getString('offlinePuzzles') ?? '').isNotEmpty;
  static int get offlinePuzzleCount => _p?.getInt('offlinePuzzleCount') ?? 0;

  static Future<Map<String, dynamic>?> downloadAllPuzzles() async {
    try {
      final response = await Supabase.instance.client
          .from('puzzles').select().order('id') as List;
      final Map<String, dynamic> puzzleMap = {
        for (final p in response) p['id'].toString(): p
      };
      final jsonStr = jsonEncode(puzzleMap);
      await _p?.setString('offlinePuzzles', jsonStr);
      await _p?.setInt('offlinePuzzleCount', response.length);
      return {'count': response.length, 'sizeKB': (jsonStr.length / 1024).ceil()};
    } catch (e) {
      debugPrint('Offline download failed: $e');
      return null;
    }
  }

  static Map<String, dynamic>? getOfflinePuzzle(String id) {
    final jsonStr = _p?.getString('offlinePuzzles');
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map[id] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearOfflinePuzzles() async {
    await _p?.remove('offlinePuzzles');
    await _p?.remove('offlinePuzzleCount');
  }

  static Future<void> resetSettings() async {
    final fields = ['showTimer','enableMs','movesDisplay','notifHour','notifMinute'];
    for (final k in fields) {
      await _p?.remove(k);
    }
    AppSettings.showTimer = true;
    AppSettings.enableMs = false;
    AppSettings.movesDisplay = 0;

    _syncToCloud({
      'show_timer': true,
      'enable_ms': false,
      'moves_display': 0,
      'notif_hour': 8,
      'notif_minute': 0,
    });
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
// ─────────────────────────────────────────────────────────────────────────────
// FOLDS THEME
// ─────────────────────────────────────────────────────────────────────────────
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


// ─────────────────────────────────────────────────────────────────────────────
// AUDIO SERVICE
// ─────────────────────────────────────────────────────────────────────────────


class AudioService {
  static final AudioPlayer _music = AudioPlayer();
  static final AudioPlayer _sfx = AudioPlayer();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(AppSettings.musicVolume);
    await _sfx.setVolume(AppSettings.sfxVolume);
  }

  // static Future<void> startMusic() async {
  //   if (!AppSettings.musicEnabled) return;
  //   await _music.play(AssetSource('sounds/bgm.mp3'));
  // }

  static Future<void> stopMusic() async => await _music.stop();
  static Future<void> pauseMusic() async => await _music.pause();
  static Future<void> resumeMusic() async {
    if (AppSettings.musicEnabled) await _music.resume();
  }

  static Future<void> flip() async {
    if (!AppSettings.sfxEnabled) return;
    // Create a new short-lived player each time so overlapping flips all fire
    final p = AudioPlayer();
    await p.setVolume(AppSettings.sfxVolume);
    await p.play(AssetSource('sounds/flip.mp3'));
    p.onPlayerComplete.listen((_) => p.dispose());
  }

  static Future<void> solve() async {
    if (!AppSettings.sfxEnabled) return;
    await _sfx.play(AssetSource('sounds/solve.mp3'));
  }

  static void setMusicVolume(double v) {
    AppSettings.musicVolume = v;
    _music.setVolume(v);
  }

  static void setSfxVolume(double v) {
    AppSettings.sfxVolume = v;
    _sfx.setVolume(v);
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
      final launchDate = DateTime(2026, 11, 1);
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final dayNumber = today.difference(launchDate).inDays + 1;

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
    super.dispose();
    AudioService.stopMusic();
  }

  void _showConfetti() {
    if (!mounted) return;
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (_) => _ConfettiOverlay(onDone: () => entry?.remove()),
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
      builder: (ctx) => _AchievementToast(
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
      if (_stopwatch.elapsedMilliseconds < 15000) tryUnlock('speed_demon');
      if (AppStore.totalFlips >= 100) tryUnlock('flippin_crazy');
                                if (AppStore.totalFlips >= 250) tryUnlock('flipaholic');
                                if (AppStore.totalFlips >= 500) tryUnlock('addicted_to_flipping');
                                AppStore.incrementTodayCount();
                                if (AppStore.todayCompletedCount >= 10) tryUnlock('folding_frenzy');

      final alreadyCompleted = AppStore.isCompleted(_id);
      if (!alreadyCompleted) {
        if (_moves > _par * 2) AppStore.markFailed(_id);
        AppStore.totalXP = AppStore.totalXP + xp;
      }
      if (_moves <= _par) AppStore.markParCompleted(_id);
      AppStore.markCompleted(_id);

      if (_id.startsWith('d')) {
        if (!alreadyCompleted) AppStore.updateStreak();
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
                            child: ClipOval(child: CustomPaint(painter: _HomeIconPainter())),
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
                    _StarRating(filled: _difficulty, total: 5),
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
                                      child: _FlipCell(
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
                          child: _FlipCell(
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
                            child: ClipOval(child: CustomPaint(painter: _HomeIconPainter())),
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
                              _StarRating(filled: _difficulty, total: 5),
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

  void _showDevPanel(BuildContext outerContext) {
    final passCtrl = TextEditingController();
    final xpCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final modCtrl = TextEditingController();
    bool unlocked = false;
    String status = '';

    showDialog(
      context: outerContext,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void msg(String m) => setS(() => status = m);

          if (!unlocked) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                const Icon(Icons.build_rounded, size: 18),
                const SizedBox(width: 8),
                Text('Dev Panel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 20)),
              ]),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Enter dev password', style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: const Color(0xFFF5F5F5),
                  ),
                  onSubmitted: (_) {
                    if (passCtrl.text == _kDevPassword) setS(() => unlocked = true);
                    else { passCtrl.clear(); msg('Wrong password'); }
                  },
                ),
                if (status.isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(status, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.red)),
                ),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () {
                    if (passCtrl.text == _kDevPassword) {
                      AppStore.isDevProfile = true;
                      setS(() => unlocked = true);
                    } else { passCtrl.clear(); msg('Wrong password'); }
                  },
                  child: Text('Unlock', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            );
          }

          final screenSize = MediaQuery.of(ctx).size;
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: EdgeInsets.symmetric(
              horizontal: screenSize.width * 0.03,
              vertical: screenSize.height * 0.03,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: SizedBox(
              width: double.maxFinite,
              height: screenSize.height * 0.92,
              child: Column(children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.build_rounded, size: 18, color: Color(0xFFFFD465)),
                    const SizedBox(width: 10),
                    Text('Developer Panel', style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD465), borderRadius: BorderRadius.circular(6)),
                      child: Text('UNLOCKED', style: GoogleFonts.dmSans(
                        fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black)),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close_rounded, color: Colors.white54, size: 22)),
                  ]),
                ),
                // Body
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status banner
                    if (status.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: status.startsWith('✅') ? const Color(0xFFDCFCE7) : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(status, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
                          color: status.startsWith('✅') ? const Color(0xFF166534) : Colors.red)),
                      ),

                    _DevLabel('XP'),
                    Text('Current: ${AppStore.totalXP} XP  •  Rank ${XPSystem.rankFromXP(AppStore.totalXP)}',
                      style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black45)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: xpCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'XP to add', isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true, fillColor: const Color(0xFFF5F5F5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () {
                          final amt = int.tryParse(xpCtrl.text) ?? 0;
                          AppStore.totalXP = AppStore.totalXP + amt;
                          xpCtrl.clear();
                          msg('✅ Added $amt XP. Total: ${AppStore.totalXP}');
                        },
                        child: Text('Add XP', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ]),

                    _DevLabel('SPECIFIC PUZZLE'),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: idCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. p1, r5, d3, x12', isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true, fillColor: const Color(0xFFF5F5F5),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _DevChip(label: 'Complete ✓', onTap: () {
                        final id = idCtrl.text.trim().toLowerCase();
                        if (id.isEmpty) { msg('Enter a puzzle ID first'); return; }
                        AppStore.markCompleted(id); AppStore.markParCompleted(id);
                        msg('✅ $id marked complete (par)');
                      }),
                      _DevChip(label: 'Uncomplete', onTap: () {
                        final id = idCtrl.text.trim().toLowerCase();
                        if (id.isEmpty) { msg('Enter a puzzle ID first'); return; }
                        final comp = AppStore.completedPuzzles..remove(id);
                        AppStore._p?.setStringList('completedPuzzles', comp.toList());
                        final par = AppStore.parPuzzles..remove(id);
                        AppStore._p?.setStringList('parPuzzles', par.toList());
                        msg('✅ $id uncompleted');
                      }),
                      _DevChip(label: 'Open Puzzle', onTap: () {
                        final id = idCtrl.text.trim().toLowerCase();
                        if (id.isEmpty) { msg('Enter a puzzle ID first'); return; }
                        Navigator.pop(ctx);
                        Navigator.pushAndRemoveUntil(outerContext, PageRouteBuilder(
                          pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: id),
                          transitionsBuilder: (_, a, __, child) => SlideTransition(
                            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                            child: child),
                          transitionDuration: const Duration(milliseconds: 320),
                        ), (r) => false);
                      }),
                    ]),

                    _DevLabel('COMPLETE PACKS'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _DevChip(label: 'All Pilot ✓', onTap: () {
                        for (int i = 1; i <= 100; i++) { AppStore.markCompleted('p$i'); AppStore.markParCompleted('p$i'); }
                        msg('✅ All 100 Pilot puzzles completed');
                      }),
                      _DevChip(label: 'Uncomplete Pilot', onTap: () {
                        final comp = AppStore.completedPuzzles;
                        for (int i = 1; i <= 100; i++) { comp.remove('p$i'); }
                        AppStore._p?.setStringList('completedPuzzles', comp.toList());
                        final par = AppStore.parPuzzles;
                        for (int i = 1; i <= 100; i++) { par.remove('p$i'); }
                        AppStore._p?.setStringList('parPuzzles', par.toList());
                        msg('✅ Pilot pack uncompleted');
                      }),
                      _DevChip(label: 'All Rectangle ✓', onTap: () {
                        for (int i = 1; i <= 100; i++) { AppStore.markCompleted('r$i'); AppStore.markParCompleted('r$i'); }
                        msg('✅ All 100 Rectangle puzzles completed');
                      }),
                      _DevChip(label: 'Uncomplete Rectangle', onTap: () {
                        final comp = AppStore.completedPuzzles;
                        for (int i = 1; i <= 100; i++) { comp.remove('r$i'); }
                        AppStore._p?.setStringList('completedPuzzles', comp.toList());
                        final par = AppStore.parPuzzles;
                        for (int i = 1; i <= 100; i++) { par.remove('r$i'); }
                        AppStore._p?.setStringList('parPuzzles', par.toList());
                        msg('✅ Rectangle pack uncompleted');
                      }),
                      _DevChip(label: 'All Holiday ✓', onTap: () {
                        for (int i = 1; i <= 25; i++) { AppStore.markCompleted('x$i'); AppStore.markParCompleted('x$i'); }
                        msg('✅ All 25 Holiday puzzles completed');
                      }),
                      _DevChip(label: 'Uncomplete Holiday', onTap: () {
                        final comp = AppStore.completedPuzzles;
                        for (int i = 1; i <= 25; i++) { comp.remove('x$i'); }
                        AppStore._p?.setStringList('completedPuzzles', comp.toList());
                        final par = AppStore.parPuzzles;
                        for (int i = 1; i <= 25; i++) { par.remove('x$i'); }
                        AppStore._p?.setStringList('parPuzzles', par.toList());
                        msg('✅ Holiday pack uncompleted');
                      }),
                    ]),

                    _DevLabel('STREAKS'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _DevChip(label: '🔥 Set 7', onTap: () { AppStore.devSetStreak(7); msg('✅ Streak set to 7'); }),
                      _DevChip(label: '🔥 Set 30', onTap: () { AppStore.devSetStreak(30); msg('✅ Streak set to 30'); }),
                      _DevChip(label: 'Reset Streak', onTap: () { AppStore.devResetStreak(); msg('✅ Streak reset'); }),
                      _DevChip(label: 'Mark Daily Done', onTap: () {
                        final launchDate = DateTime(2026, 11, 1);
                        final today = DateTime.now();
                        final todayClean = DateTime(today.year, today.month, today.day);
                        final dayNumber = todayClean.difference(launchDate).inDays + 1;
                        if (dayNumber > 0) {
                          AppStore.markCompleted('d$dayNumber');
                          AppStore.updateStreak();
                          msg('✅ Today\'s daily marked done, streak updated');
                        }
                      }),
                    ]),

                    _DevLabel('MODERATOR MANAGEMENT'),
                    TextField(
                      controller: modCtrl,
                      decoration: InputDecoration(
                        hintText: 'Username to approve/revoke', isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true, fillColor: const Color(0xFFF5F5F5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _DevChip(label: '✓ Approve Mod', onTap: () async {
                        final u = modCtrl.text.trim();
                        if (u.isEmpty) { msg('Enter a username'); return; }
                        try {
                          await Supabase.instance.client.rpc('approve_moderator', params: {'target_username': u});
                          msg('✅ $u approved as moderator');
                        } catch (e) { msg('❌ $e'); }
                      }),
                      _DevChip(label: '✕ Revoke Mod', onTap: () async {
                        final u = modCtrl.text.trim();
                        if (u.isEmpty) { msg('Enter a username'); return; }
                        try {
                          await Supabase.instance.client.rpc('revoke_moderator', params: {'target_username': u});
                          msg('✅ $u mod revoked');
                        } catch (e) { msg('❌ $e'); }
                      }),
                    ]),

                    _DevLabel('SHADOW ACHIEVEMENTS'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _DevChip(label: '🐛 Grant Exterminator', onTap: () {
                        AppStore.unlockAchievement('exterminator');
                        msg('✅ Exterminator granted');
                      }),
                      _DevChip(label: '🏛 Grant Architect', onTap: () {
                        AppStore.unlockAchievement('build');
                        msg('✅ Architect granted');
                      }),
                    ]),

                    _DevLabel('NUCLEAR'),
                    _DevBtn(label: '⚠️ Reset ALL Progress', textColor: Colors.red, onTap: () async {
                      final go = await showDialog<bool>(context: outerContext, builder: (c) => AlertDialog(
                        title: Text('Reset everything?', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(c, true),
                            child: Text('Confirm', style: GoogleFonts.dmSans(color: Colors.red, fontWeight: FontWeight.w800))),
                        ],
                      ));
                      if (go == true) { await AppStore.resetProgress(); msg('✅ Progress wiped'); }
                    }),
                    const SizedBox(height: 4),
                    _DevBtn(label: '⚠️ Reset All Settings', textColor: Colors.orange, onTap: () async {
                      await AppStore.resetSettings();
                      msg('✅ Settings reset to defaults');
                    }),
                  ],
                ),
              ),
            ),
            
          ])));
        },
      ),
    );
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
                            decoration: BoxDecoration(color: const Color.fromARGB(0, 66, 66, 68), borderRadius: BorderRadius.circular(6)),
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
            GestureDetector(
              onTap: () => _showDevPanel(context),
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.build_rounded,
                    color: Colors.white38, size: 22),
              ),
            ),
            const SizedBox(width: 10),
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
              child: _BackButton(label: 'BACK TO MORE PUZZLES', onTap: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFETTI
// ─────────────────────────────────────────────────────────────────────────────
class _ConfettiParticle {
  double x, y, vx, vy, size, rotation, rotSpeed;
  Color color;
  _ConfettiParticle(this.x, this.y, this.vx, this.vy, this.size, this.rotation, this.rotSpeed, this.color);
}

class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay({required this.onDone});
  final VoidCallback onDone;
  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_ConfettiParticle> _particles;
  final _rng = math.Random();

  static const _colors = [
    Color(0xFFFFD465), Color(0xFF7BD957), Color(0xFF5865F2),
    Color(0xFFFF6B35), Color(0xFF4CAF50), Color(0xFFE91E63),
  ];

  @override
  void initState() {
    super.initState();
    _particles = List.generate(80, (_) => _ConfettiParticle(
      _rng.nextDouble(),
      -0.05 - _rng.nextDouble() * 0.15,
      (_rng.nextDouble() - 0.5) * 0.006,
      0.008 + _rng.nextDouble() * 0.012,
      6 + _rng.nextDouble() * 8,
      _rng.nextDouble() * math.pi * 2,
      (_rng.nextDouble() - 0.5) * 0.15,
      _colors[_rng.nextInt(_colors.length)],
    ));
    _ctrl = AnimationController(duration: const Duration(milliseconds: 2800), vsync: this)
      ..addListener(() => setState(() {
        for (final p in _particles) {
          p.x += p.vx;
          p.y += p.vy;
          p.vy += 0.0002;
          p.rotation += p.rotSpeed;
        }
        _particles.removeWhere((p) => p.y > 1.15);
        if (_particles.isEmpty) { _ctrl.stop(); widget.onDone(); }
      }))
      ..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _ConfettiPainter(_particles, size),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final Size screen;
  _ConfettiPainter(this.particles, this.screen);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.rotation);
      paint.color = p.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
          const Radius.circular(2)),
        paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
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
  final VoidCallback? onNext;
  final List<bool> cells;
  final bool skipAnimation;
  final bool isHoliday;
  final int gridRows;
  final int gridCols;

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
    this.onNext,
    required this.cells,
    this.skipAnimation = false,
    this.isHoliday = false,
    this.gridRows = 4,
    this.gridCols = 4,
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

    if (widget.skipAnimation) {
      _foldCtrl.value = 1;
      _envelopeCtrl.value = 1;
      _flipCtrl.value = 1;
      _stampCtrl.value = 1;
      _stage = 4;
    }

    _runSequence();
  }

  Future<void> _runSequence() async {
    if (widget.skipAnimation) {
      await _statsCtrl.forward();
      return;
    }
    await Future.delayed(const Duration(milliseconds: 350));
    await _foldCtrl.forward();
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
                      Positioned(
                        left: half, top: 0,
                        width: half, height: gridWidth,
                        child: _GridHalf(
                          cells: widget.cells,
                          isLeft: false,
                          gridRows: widget.gridRows,
                          gridCols: widget.gridCols,
                          isHoliday: widget.isHoliday,
                        ),
                      ),
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
                            gridRows: widget.gridRows,
                            gridCols: widget.gridCols,
                            isHoliday: widget.isHoliday,
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
                        onNext: widget.onNext,
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
  final int gridRows;
  final int gridCols;
  final bool isHoliday;

  const _GridHalf({
    required this.cells,
    required this.isLeft,
    required this.gridRows,
    required this.gridCols,
    this.isHoliday = false,
  });

  @override
  Widget build(BuildContext context) {
    final halfCols = gridCols ~/ 2;
    final startCol = isLeft ? 0 : halfCols;
    const gap = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = (constraints.maxWidth - gap * (halfCols - 1) - 16) / halfCols;
        final cellH = constraints.maxHeight > 0
            ? (constraints.maxHeight - gap * (gridRows - 1) - 16) / gridRows
            : cellW;
        final cellSize = min(cellW, cellH);

        return Container(
          color: isHoliday ? const Color(0xFF0D1A0D) : const Color(0xFFE8E8E8),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(gridRows, (row) {
              return Padding(
                padding: EdgeInsets.only(bottom: row < gridRows - 1 ? gap : 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(halfCols, (colIdx) {
                    final col = startCol + colIdx;
                    final index = row * gridCols + col;
                    final isBlack = index < cells.length && cells[index];
                    return Padding(
                      padding: EdgeInsets.only(right: colIdx < halfCols - 1 ? gap : 0),
                      child: Container(
                        width: cellSize, height: cellSize,
                        decoration: BoxDecoration(
                          color: isBlack
                              ? (isHoliday ? const Color(0xFF8B0000) : const Color(0xFF2C2C2C))
                              : (isHoliday ? const Color(0xFF1B5E20) : Colors.white),
                          borderRadius: BorderRadius.circular(cellSize * 0.22),
                        ),
                      ),
                    );
                  }),
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
  final VoidCallback? onNext;
  final int earnedXP;

  const _StatsCard({
    required this.timeDisplay,
    required this.moves,
    required this.par,
    required this.isUnderPar,
    required this.shareText,
    required this.onRetry,
    this.onNext,
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
                _XPCountUp(target: earnedXP),
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Copied to clipboard',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFF2C2C2C),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text('Copy',
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
              if (onNext != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: onNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text('Next →',
                          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
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

class _XPCountUp extends StatefulWidget {
  final int target;
  const _XPCountUp({required this.target});
  @override
  State<_XPCountUp> createState() => _XPCountUpState();
}

class _XPCountUpState extends State<_XPCountUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<int> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: Duration(milliseconds: (widget.target * 18).clamp(600, 1800)),
      vsync: this,
    );
    _anim = IntTween(begin: 0, end: widget.target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    // Delay to let the stats card finish sliding in
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text('+${_anim.value} XP',
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
        ],
      ),
    );
  }
}

//end of fold animation only 500 liens i guess it wasnt that bad
// ─────────────────────────────────────────────────────────────────────────────
// ACHIEVEMENT TOAST
// ─────────────────────────────────────────────────────────────────────────────
class _AchievementToast extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onDone;

  const _AchievementToast({
    required this.title,
    required this.description,
    required this.icon,
    required this.onDone,
  });

  @override
  State<_AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<_AchievementToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 420), vsync: this);
    _slide = Tween<double>(begin: -60, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.4)));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Positioned(
        top: topPad + 12 + _slide.value,
        left: 20, right: 20,
        child: Opacity(
          opacity: _fade.value,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD465).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12)),
                    child: Icon(widget.icon, color: const Color(0xFFFFD465), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Achievement Unlocked!', style: GoogleFonts.dmSans(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFD465), letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text(widget.title, style: GoogleFonts.dmSans(
                        fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(widget.description, style: GoogleFonts.dmSans(
                        fontSize: 12, color: Colors.white54)),
                    ],
                  )),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _FlipCell extends StatefulWidget {
  final bool isBlack;
  final String? linkShape;
  final VoidCallback onTap;
  final bool isHoliday;
  const _FlipCell({required this.isBlack, this.linkShape, required this.onTap, this.isHoliday = false});
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
      _controller.forward(from: 0).then((_) {
        if (mounted) {
          setState(() => _showingBlack = widget.isBlack);
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    widget.onTap();
    _controller.forward(from: 0).then((_) {
      setState(() => _showingBlack = !_showingBlack);
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
            child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _showingBlack
                            ? (widget.isHoliday ? const Color.fromARGB(255, 226, 10, 10) : const Color(0xFF2C2C2C))
                            : (widget.isHoliday ? const Color.fromARGB(255, 11, 235, 26) : Colors.white),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                if (widget.linkShape != null)
                  Positioned(
                    top: 3, right: 3,
                    child: _LinkBadge(shape: widget.linkShape!, onBlack: _showingBlack),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LinkBadge extends StatelessWidget {
  final String shape;
  final bool onBlack;
  const _LinkBadge({required this.shape, required this.onBlack});

  @override
  Widget build(BuildContext context) {
    final color = onBlack ? Colors.white70 : Colors.black38;
    const size = 9.0;
    switch (shape) {
      case 'triangle':
        return CustomPaint(size: const Size(size, size), painter: _TriBadgePainter(color));
      case 'square':
        return Container(width: size, height: size, color: color);
      case 'pentagon':
        return CustomPaint(size: const Size(size, size), painter: _PentaBadgePainter(color));
      case 'circle':
      default:
        return Container(width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color));
    }
  }
}

class _TriBadgePainter extends CustomPainter {
  final Color color;
  _TriBadgePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }
  @override bool shouldRepaint(_) => false;
}

class _PentaBadgePainter extends CustomPainter {
  final Color color;
  _PentaBadgePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72 - 90) * pi / 180;
      final x = size.width / 2 + size.width / 2 * cos(angle);
      final y = size.height / 2 + size.height / 2 * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }
  @override bool shouldRepaint(_) => false;
}


// ─────────────────────────────────────────────────────────────────────────────
// STREAK CALENDAR
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// FIRE ICON PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _FirePainter extends CustomPainter {
  final bool isDoneToday;
  const _FirePainter({required this.isDoneToday});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer flame
    final outerPath = Path()
      ..moveTo(w * 0.50, 0)
      ..cubicTo(w * 0.78, h * 0.18, w * 0.96, h * 0.38, w * 0.86, h * 0.60)
      ..cubicTo(w * 1.00, h * 0.42, w * 0.90, h * 0.18, w * 0.82, 0)
      ..cubicTo(w * 0.96, h * 0.48, w * 0.96, h * 0.80, w * 0.72, h)
      ..lineTo(w * 0.28, h)
      ..cubicTo(w * 0.04, h * 0.80, w * 0.04, h * 0.48, w * 0.18, 0)
      ..cubicTo(w * 0.10, h * 0.18, 0, h * 0.42, w * 0.14, h * 0.60)
      ..cubicTo(w * 0.04, h * 0.38, w * 0.22, h * 0.18, w * 0.50, 0)
      ..close();

    canvas.drawPath(
      outerPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = isDoneToday ? const Color(0xFFE53935) : Colors.grey.shade300,
    );

    if (isDoneToday) {
      // Inner yellow flame
      final innerPath = Path()
        ..moveTo(w * 0.50, h * 0.32)
        ..cubicTo(w * 0.66, h * 0.46, w * 0.72, h * 0.60, w * 0.67, h * 0.74)
        ..cubicTo(w * 0.74, h * 0.60, w * 0.68, h * 0.48, w * 0.74, h * 0.36)
        ..cubicTo(w * 0.80, h * 0.58, w * 0.78, h * 0.78, w * 0.62, h * 0.92)
        ..lineTo(w * 0.38, h * 0.92)
        ..cubicTo(w * 0.22, h * 0.78, w * 0.20, h * 0.58, w * 0.26, h * 0.36)
        ..cubicTo(w * 0.32, h * 0.48, w * 0.26, h * 0.60, w * 0.33, h * 0.74)
        ..cubicTo(w * 0.28, h * 0.60, w * 0.34, h * 0.46, w * 0.50, h * 0.32)
        ..close();

      canvas.drawPath(
        innerPath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFD465),
      );
    }
  }

  @override
  bool shouldRepaint(_FirePainter old) => old.isDoneToday != isDoneToday;
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
                  const SizedBox(height: 12),
                  // Difficulty filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _FilterChip(label: 'All', active: _filterDifficulty == 0,
                        onTap: () => setState(() => _filterDifficulty = 0)),
                      const SizedBox(width: 6),
                      ...List.generate(5, (i) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _FilterChip(
                          label: '${'★' * (i + 1)}',
                          active: _filterDifficulty == i + 1,
                          onTap: () => setState(() => _filterDifficulty = _filterDifficulty == i+1 ? 0 : i+1)),
                      )),
                      _FilterChip(label: '✓ Done', active: _filterStatus == 1,
                        onTap: () => setState(() => _filterStatus = _filterStatus == 1 ? 0 : 1)),
                      const SizedBox(width: 6),
                      _FilterChip(label: '○ Todo', active: _filterStatus == 2,
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
        'Redeem custom 16-digit access tokens for grid custom packs, cosmetics, or unique profile marks.',
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
                        onChanged: (v) => setState(() {
                          _sfx = v;
                          AudioService.setSfxVolume(v);
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text('Current Track',
                        style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
                      const SizedBox(height: 10),
                      _TrackPlayerCard(
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

                      _SectionHeader('ACCOUNT & DATA'),
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

                      _SectionHeader(_t('ABOUT & VERSIONING')),
                      _OpenRow(
                        title: 'Moderator Access',
                        subtitle: 'Exclusive content for trusted members',
                        onTap: () => _pushFade(context, const ModeratorPanelScreen()),
                      ),
                      _ActionPill(label: 'Report a Bug 🐛', onTap: () => _showBugReport(context)),
                      const SizedBox(height: 10),
                      _ActionPill(
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
                      _ToggleRow(
                        title: _t('Just Dont...'),
                        subtitle: _t('Please dont toggle this on.'),
                        value: _justDont,
                        onChanged: (v) => setState(() => _justDont = v),
                      ),
                      _OpenRow(title: _t('Credits'), onTap: () => _pushFade(context, const CreditsScreen())),
                      _OpenRow(title: _t('Folds Website'), onTap: () => _launchUrl('https://folds.jaydev.games')),
                      _OpenRow(title: _t('Socials & YouTube'), onTap: () => _pushFade(context, const SocialsScreen())),
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

class _DevLabel extends StatelessWidget {
  final String text;
  const _DevLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 1.2)),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF2C2C2C) : const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.dmSans(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: active ? Colors.white : Colors.black45)),
    ),
  );
}

class _DevChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DevChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black)),
    ),
  );
}

class _DevBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? textColor;
  const _DevBtn({required this.label, required this.onTap, this.textColor});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: textColor ?? Colors.black)),
    ),
  );
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

  @override
  void initState() {
    super.initState();
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
                    painter: _FirePainter(
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
                    onTap: () async {
                      if (isGuest) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to manage your account.')));
                      } else {
                        await Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountManagementScreen()));
                        setState(() {});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: isGuest ? const Color(0xFFEFEFEF) : const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('MANAGE ACCOUNT', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: isGuest ? Colors.black45 : Colors.white, letterSpacing: 0.5)),
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
          _ProgressBar(progress: xpProgress, color: const Color(0xFFFFD465),
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

          // Drop this right here! It will stay completely hidden 
    // until "GIVE-MEIN-FINI-TEXP" is typed into your redeem dialog.
    

          GestureDetector(
            onTap: () => showPublicProfile(context,
              username: AppStore.displayUsername,
              xp: AppStore.totalXP,
              leaderboardRank: 0,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text('View Public Profile',
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



// ─────────────────────────────────────────────────────────────────────────────
// ACHIEVEMENTS DATA
// ─────────────────────────────────────────────────────────────────────────────
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

  // ── IN A DAY
  AchievementDef('folding_frenzy', 'Folding Frenzy', 'Complete 10 puzzles in a single day.', Icons.flash_on_rounded),

  // ── GRID SIZE
  AchievementDef('grid_master', 'Grid Master', 'Complete a 6×6 puzzle.', Icons.grid_on_rounded),

  // ── FLIPS
  AchievementDef('flippin_crazy', "Flippin' Crazy", 'Flip a total of 100 cells.', Icons.touch_app_rounded),
  AchievementDef('flipaholic', 'Flipaholic', 'Flip a total of 250 cells.', Icons.touch_app_rounded),
  AchievementDef('addicted_to_flipping', 'Addicted to Flipping', 'Flip a total of 500 cells.', Icons.touch_app_rounded),

  // ── SKILL
  AchievementDef('flawless', 'Flawless Logic', 'Solve a puzzle in the exact par amount of moves.', Icons.lightbulb_outline_rounded),
  AchievementDef('speed_demon', 'Speed Demon', 'Solve a puzzle in under 15 seconds.', Icons.timer_rounded),

  // ── SHADOW
  AchievementDef('exterminator', 'Exterminator', 'Report a bug to the Folds team.', Icons.bug_report_rounded),
  AchievementDef('build', 'Architect', 'Get a puzzle featured in the game.', Icons.architecture_rounded),
  AchievementDef('just_in_case', 'Just In Case', 'Download all puzzles for offline play.', Icons.cloud_download_rounded),
];



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
    ('GRID SIZE', ['grid_master']),
    ('FLIPS', ['flippin_crazy', 'flipaholic', 'addicted_to_flipping']),
    ('SKILL', ['flawless', 'speed_demon']),
    ('SHADOW', ['exterminator', 'build', 'just_in_case']),
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
              _FoldsTopBar(title: 'MOD ACCESS', onBack: () => Navigator.pop(context)),
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
          .select('username, total_xp, avatar_path')
          .order('total_xp', ascending: false)
          .limit(50);
      setState(() {
        _entries = List<Map<String, dynamic>>.from(data);
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
              _FoldsTopBar(title: 'TOP FOLDERS', onBack: () => Navigator.pop(context)),
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
                                    Expanded(child: Text(username,
                                      style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800,
                                        color: isTop3 ? Colors.white : Colors.black))),
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
          .select('username, total_xp, join_date, completed_puzzles, is_moderator, avatar_path')
          .eq('username', widget.username)
          .maybeSingle();
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
                            image: NetworkImage(avatarUrl!), fit: BoxFit.cover) : null,
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
                          if (isMod) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD465), borderRadius: BorderRadius.circular(8)),
                              child: Text('MOD', style: GoogleFonts.dmSans(
                                fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
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
          await AppStore._p?.setString('joinDate', joinStr);
          await AppStore._p?.setString('username', _usernameController.text.trim());
          // Auto sign-in immediately after creating account
          try {
            await Supabase.instance.client.auth.signInWithPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
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
    final launchDate = DateTime(2026, 11, 1);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final dayNumber = today.difference(launchDate).inDays + 1;
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
            child: ClipOval(child: CustomPaint(painter: _HomeIconPainter())),
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
    this.onSolved,
  });

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
              child: CustomPaint(painter: _HomeIconPainter()),
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