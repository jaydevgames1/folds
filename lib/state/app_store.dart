import 'package:flutter/material.dart';
import 'package:folds/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/state/app_settings.dart';
import 'dart:convert';
import 'package:folds/core/constants.dart';

class AppStore {
  static Future<void> setLocalJoinDate(String date) async {
  await _p?.setString('joinDate', date);
}

static Future<void> setLocalUsername(String name) async {
  await _p?.setString('username', name);
}

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

      
await _p?.setString('username', data['username'] ?? 'Puzzle Apprentice');

if (data['avatar_path'] != null) {
  String cachedPath = data['avatar_path'];
  // If the database returned a relative path, convert it to a full URL before caching locally
  if (!cachedPath.startsWith('http')) {
    cachedPath = Supabase.instance.client.storage.from('avatars').getPublicUrl(cachedPath);
  }
  await _p?.setString('avatarPath', cachedPath);
} else {
  await _p?.remove('avatarPath');
}

      final cloudJoinDate = data['join_date']?.toString() ?? '';
      if (cloudJoinDate.startsWith('JOINED ')) {
        // Cloud has the real join date — always trust it.
        await _p?.setString('joinDate', cloudJoinDate);
      } else {
        // Cloud is missing one (never got pushed after signup). If we already
        // have a valid local value, repair the cloud row with it — never let
        // "today" get generated here.
        final localJoinDate = _p?.getString('joinDate');
        if (localJoinDate != null && localJoinDate.startsWith('JOINED ')) {
          _syncToCloud({'join_date': localJoinDate});
        }
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
      await _p?.setBool('isDevProfile', data['is_dev_profile'] ?? false);
      if (data['unlocked_texture_packs'] != null) {
        final List<String> list = List<String>.from(data['unlocked_texture_packs']);
        await _p?.setStringList('unlockedTexturePacks', list);
      }
      await _p?.setString('activeTexturePack', data['active_texture_pack'] ?? 'classic');
    } catch (e) {
      debugPrint("Error bringing down cloud profile values: $e");
    }
  }
  static int get parStreak => _p?.getInt('parStreak') ?? 0;
  static set parStreak(int v) => _p?.setInt('parStreak', v);
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
  // ── Texture Packs
  static Set<String> get unlockedTexturePacks =>
      (_p?.getStringList('unlockedTexturePacks') ?? <String>['classic']).toSet();
  static void unlockTexturePack(String id) {
    final s = unlockedTexturePacks..add(id);
    final list = s.toList();
    _p?.setStringList('unlockedTexturePacks', list);
    _syncToCloud({'unlocked_texture_packs': list});
  }
  static bool isTexturePackUnlocked(String id) => id == 'classic' || unlockedTexturePacks.contains(id);

  static String get activeTexturePack => _p?.getString('activeTexturePack') ?? 'classic';
  static set activeTexturePack(String v) {
    _p?.setString('activeTexturePack', v);
    _syncToCloud({'active_texture_pack': v});
  }
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

  static String get joinDate => _p?.getString('joinDate') ?? _initJoinDateLocalOnly();
  static String _initJoinDateLocalOnly() {
    final d = DateTime.now();
    final months = ['','JANUARY','FEBRUARY','MARCH','APRIL','MAY','JUNE',
        'JULY','AUGUST','SEPTEMBER','OCTOBER','NOVEMBER','DECEMBER'];
    final s = 'JOINED ${d.day} ${months[d.month]} ${d.year}';
    _p?.setString('joinDate', s);
    // Deliberately local-only — this getter can fire incidentally from any
    // UI read and must never silently overwrite a real join date in Supabase.
    // Cloud sync for join date only happens in downloadCloudProfile() below
    // and explicitly right after sign-up.
    return s;
  }

  static bool get haptic => _p?.getBool('haptic') ?? true;
  static set haptic(bool v) {
    _p?.setBool('haptic', v);
    _syncToCloud({'haptic': v});
  }

  static DateTime? get lastReceiptsSeen {
    final s = _p?.getString('lastReceiptsSeen');
    return s != null ? DateTime.tryParse(s) : null;
  }
  static Future<void> markReceiptsSeen() async {
    await _p?.setString('lastReceiptsSeen', DateTime.now().toIso8601String());
  }

  // ── Onboarding
  static bool get hasSeenOnboarding => _p?.getBool('hasSeenOnboarding') ?? false;
  static set hasSeenOnboarding(bool v) => _p?.setBool('hasSeenOnboarding', v);

  // ── Moderator
  static bool get isModerator => _p?.getBool('isModerator') ?? false;
  static set isModerator(bool v) => _p?.setBool('isModerator', v);

  // ── Dev profile badge (set via dev panel, persists)
  static bool get isDevProfile => _p?.getBool('isDevProfile') ?? false;
  static set isDevProfile(bool v) {
    _p?.setBool('isDevProfile', v);
    _syncToCloud({'is_dev_profile': v});
  }

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
    final dayNumber = foldsDayNumberFor(DateTime.now());
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