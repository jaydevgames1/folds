import 'package:flutter/material.dart';
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

  static int get themeMode => _p?.getInt('themeMode') ?? 2;
  static set themeMode(int v) { _p?.setInt('themeMode', v); syncToCloud({'theme_mode': v}); }

  static bool get reducedMotion => _p?.getBool('reducedMotion') ?? false;
  static set reducedMotion(bool v) { _p?.setBool('reducedMotion', v); syncToCloud({'reduced_motion': v}); }

  static int get frameRateCap => _p?.getInt('frameRateCap') ?? 1;
  static set frameRateCap(int v) { _p?.setInt('frameRateCap', v); syncToCloud({'frame_rate_cap': v}); }

  static bool get staticBackgrounds => _p?.getBool('staticBackgrounds') ?? false;
  static set staticBackgrounds(bool v) { _p?.setBool('staticBackgrounds', v); syncToCloud({'static_backgrounds': v}); }

  static bool get dailyNotifEnabled => _p?.getBool('dailyNotifEnabled') ?? true;
  static set dailyNotifEnabled(bool v) { _p?.setBool('dailyNotifEnabled', v); syncToCloud({'daily_notif_enabled': v}); }

  static bool get newPacksNotifEnabled => _p?.getBool('newPacksNotifEnabled') ?? true;
  static set newPacksNotifEnabled(bool v) { _p?.setBool('newPacksNotifEnabled', v); syncToCloud({'new_packs_notif_enabled': v}); }

  static int get handedMode => _p?.getInt('handedMode') ?? 0;
  static set handedMode(int v) { _p?.setInt('handedMode', v); syncToCloud({'handed_mode': v}); }

  static bool get optOutData => _p?.getBool('optOutData') ?? false;
  static set optOutData(bool v) { _p?.setBool('optOutData', v); syncToCloud({'opt_out_data': v}); }

  static double get sfxVolume => _p?.getDouble('sfxVolume') ?? 0.55;
  static set sfxVolume(double v) => _p?.setDouble('sfxVolume', v);

  static double get musicVolume => _p?.getDouble('musicVolume') ?? 0.4;
  static set musicVolume(double v) => _p?.setDouble('musicVolume', v);

  // Supabase integration shortcut helper
  static User? get currentUser => Supabase.instance.client.auth.currentUser;

  // Helper function to safely run background cloud updates
  static void syncToCloud(Map<String, dynamic> data) {
    if (currentUser == null || currentUser!.isAnonymous) return;
    final localJoinDate = _p?.getString('joinDate') ?? '';
    final safeData = <String, dynamic>{
      if (localJoinDate.startsWith('JOINED ')) 'join_date': localJoinDate,
      ...data,
    };
    Supabase.instance.client
        .from('profiles')
        .update(safeData)
        .eq('id', currentUser!.id)
        .then((_) => debugPrint("Cloud synced: ${data.keys.join(', ')}"))
        .catchError((err) => debugPrint("Cloud sync failed: $err"));
  }

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();

    // Every fresh device starts as a real anonymous Supabase user — this is
    // what makes sign-out/sign-in and "keep my progress" actually work,
    // instead of guest data just living in local prefs with nothing to link.
    if (currentUser == null) {
      try {
        await Supabase.instance.client.auth.signInAnonymously();
      } catch (e) {
        debugPrint('Anonymous sign-in failed: $e');
      }
    }

    if (currentUser != null) {
      await downloadCloudProfile();
    }

    AppSettings.showTimer = _p?.getBool('showTimer') ?? true;
    AppSettings.enableMs = _p?.getBool('enableMs') ?? false;
    AppSettings.movesDisplay = _p?.getInt('movesDisplay') ?? 0;
    AppSettings.haptic = _p?.getBool('haptic') ?? true;
  }

  static Future<void> signOutToGuest() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
    // Anonymous auth may be disabled on the backend (it currently is) — don't
    // depend on it succeeding. Either way, wipe every local trace of the
    // signed-out account so the app genuinely starts blank.
    try {
      await Supabase.instance.client.auth.signInAnonymously();
      if (currentUser != null) await downloadCloudProfile();
    } catch (e) {
      debugPrint('Anonymous sign-in unavailable — continuing as local-only guest: $e');
    }
    await wipeLocalProfileData();
  }

  /// Clears every locally-cached account field (username, XP, completed
  /// puzzles, achievements, streak, mod/dev flags, avatar, etc.) without
  /// touching device-only settings like theme or haptics.
  static Future<void> wipeLocalProfileData() async {
    const fields = [
      'username', 'avatarPath', 'joinDate',
      'totalXP', 'totalFlips', 'parStreak',
      'completedPuzzles', 'failedPuzzles', 'parPuzzles', 'unlockedAchievements',
      'unlockedTexturePacks', 'activeTexturePack',
      'currentStreak', 'lastDailyDate',
      'isModerator', 'isDevProfile', 'recentPack',
      'notifHour', 'notifMinute',
    ];
    for (final k in fields) {
      await _p?.remove(k);
    }
  }

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
        if (!cachedPath.startsWith('http')) {
          cachedPath = Supabase.instance.client.storage.from('avatars').getPublicUrl(cachedPath);
        }
        await _p?.setString('avatarPath', cachedPath);
      } else {
        await _p?.remove('avatarPath');
      }

      final cloudJoinDate = data['join_date']?.toString() ?? '';
      if (cloudJoinDate.startsWith('JOINED ')) {
        await _p?.setString('joinDate', cloudJoinDate);
      } else {
        final localJoinDate = _p?.getString('joinDate');
        if (localJoinDate != null && localJoinDate.startsWith('JOINED ')) {
          syncToCloud({'join_date': localJoinDate});
        }
      }

      await _p?.setInt('totalXP', data['total_xp'] ?? 0);
      await _p?.setInt('totalFlips', data['total_flips'] ?? 0);
      await _p?.setBool('showTimer', data['show_timer'] ?? true);
      await _p?.setBool('enableMs', data['enable_ms'] ?? false);
      await _p?.setInt('movesDisplay', data['moves_display'] ?? 0);
      await _p?.setBool('haptic', data['haptic'] ?? true);
      await _p?.setInt('notifHour', data['notif_hour'] ?? 8);
      await _p?.setInt('notifMinute', data['notif_minute'] ?? 0);
      await _p?.setString('recentPack', data['recent_pack'] ?? '');

      if (data['unlocked_achievements'] != null) {
        await _p?.setStringList('unlockedAchievements', List<String>.from(data['unlocked_achievements']));
      }
      if (data['completed_puzzles'] != null) {
        await _p?.setStringList('completedPuzzles', List<String>.from(data['completed_puzzles']));
      }
      if (data['failed_puzzles'] != null) {
        await _p?.setStringList('failedPuzzles', List<String>.from(data['failed_puzzles']));
      }
      if (data['par_puzzles'] != null) {
        await _p?.setStringList('parPuzzles', List<String>.from(data['par_puzzles']));
      }
      await _p?.setInt('currentStreak', data['current_streak'] ?? 0);
      if (data['last_daily_date'] != null) {
        await _p?.setString('lastDailyDate', data['last_daily_date']);
      }
      await _p?.setBool('isModerator', data['is_moderator'] ?? false);
      await _p?.setBool('isDevProfile', data['is_dev_profile'] ?? false);
      if (data['unlocked_texture_packs'] != null) {
        await _p?.setStringList('unlockedTexturePacks', List<String>.from(data['unlocked_texture_packs']));
      }
      await _p?.setString('activeTexturePack', data['active_texture_pack'] ?? 'classic');
    } catch (e) {
      debugPrint("Error bringing down cloud profile values: $e");
    }
  }

  static int get parStreak => _p?.getInt('parStreak') ?? 0;
  static set parStreak(int v) => _p?.setInt('parStreak', v);

  static int get totalFlips => _p?.getInt('totalFlips') ?? 0;
  static set totalFlips(int v) { _p?.setInt('totalFlips', v); syncToCloud({'total_flips': v}); }

  static Set<String> get unlockedAchievements => (_p?.getStringList('unlockedAchievements') ?? []).toSet();
  static void unlockAchievement(String id) {
    final list = (unlockedAchievements..add(id)).toList();
    _p?.setStringList('unlockedAchievements', list);
    syncToCloud({'unlocked_achievements': list});
  }
  static bool isUnlocked(String id) => unlockedAchievements.contains(id);

  static Set<String> get unlockedTexturePacks => (_p?.getStringList('unlockedTexturePacks') ?? <String>['classic']).toSet();
  static void unlockTexturePack(String id) {
    final list = (unlockedTexturePacks..add(id)).toList();
    _p?.setStringList('unlockedTexturePacks', list);
    syncToCloud({'unlocked_texture_packs': list});
  }
  static bool isTexturePackUnlocked(String id) => id == 'classic' || unlockedTexturePacks.contains(id);

  static String get activeTexturePack => _p?.getString('activeTexturePack') ?? 'classic';
  static set activeTexturePack(String v) { _p?.setString('activeTexturePack', v); syncToCloud({'active_texture_pack': v}); }

  static String get username => _p?.getString('username') ?? 'Puzzle Apprentice';
  static set username(String v) { _p?.setString('username', v); syncToCloud({'username': v}); }

  static Future<bool> isUsernameAvailable(String username) async {
    try {
      final result = await Supabase.instance.client
          .rpc('check_username_available', params: {'check_username': username});
      return result == true;
    } catch (_) {
      return true;
    }
  }

  // Resolves "email or username" login input to an actual email via RPC.
  // Requires this SQL function on Supabase:
  //
  // create or replace function resolve_username_email(check_username text)
  // returns text language sql security definer as $$
  //   select email from auth.users u join profiles p on p.id = u.id
  //   where p.username = check_username limit 1;
  // $$;
  static Future<String> resolveUsernameToEmail(String username) async {
    final email = await Supabase.instance.client
        .rpc('resolve_username_email', params: {'check_username': username});
    if (email == null) throw Exception('No account found for "$username"');
    return email as String;
  }

  static String get displayUsername {
    final metaName = currentUser?.userMetadata?['username'];
    if (metaName is String && metaName.trim().isNotEmpty) return metaName;
    return username;
  }

  static String? get avatarPath => _p?.getString('avatarPath');
  static set avatarPath(String? v) {
    v == null ? _p?.remove('avatarPath') : _p?.setString('avatarPath', v);
    syncToCloud({'avatar_path': v});
  }

  static String get joinDate => _p?.getString('joinDate') ?? _initJoinDateLocalOnly();
  static String _initJoinDateLocalOnly() {
    final d = DateTime.now();
    final months = ['','JANUARY','FEBRUARY','MARCH','APRIL','MAY','JUNE',
        'JULY','AUGUST','SEPTEMBER','OCTOBER','NOVEMBER','DECEMBER'];
    final s = 'JOINED ${d.day} ${months[d.month]} ${d.year}';
    _p?.setString('joinDate', s);
    return s;
  }

  static bool get haptic => _p?.getBool('haptic') ?? true;
  static set haptic(bool v) { _p?.setBool('haptic', v); syncToCloud({'haptic': v}); }

  static DateTime? get lastReceiptsSeen {
    final s = _p?.getString('lastReceiptsSeen');
    return s != null ? DateTime.tryParse(s) : null;
  }
  static Future<void> markReceiptsSeen() async {
    await _p?.setString('lastReceiptsSeen', DateTime.now().toIso8601String());
  }

  static bool get hasSeenOnboarding => _p?.getBool('hasSeenOnboarding') ?? false;
  static set hasSeenOnboarding(bool v) => _p?.setBool('hasSeenOnboarding', v);

  static bool get isModerator => _p?.getBool('isModerator') ?? false;
  static set isModerator(bool v) => _p?.setBool('isModerator', v);

  static bool get isDevProfile => _p?.getBool('isDevProfile') ?? false;
  static set isDevProfile(bool v) { _p?.setBool('isDevProfile', v); syncToCloud({'is_dev_profile': v}); }

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
    syncToCloud({'current_streak': newStreak, 'last_daily_date': todayStr});
  }

  static void devSetStreak(int v) { _p?.setInt('currentStreak', v); _p?.setString('lastDailyDate', ''); }
  static void devResetStreak() { _p?.setInt('currentStreak', 0); _p?.remove('lastDailyDate'); }

  static bool get isStreakDoneToday {
    final dayNumber = foldsDayNumberFor(DateTime.now());
    if (dayNumber < 1) return false;
    return isCompleted('d$dayNumber');
  }

  static int get totalXP => _p?.getInt('totalXP') ?? 0;
  static set totalXP(int v) { _p?.setInt('totalXP', v); syncToCloud({'total_xp': v}); }

  static Set<String> get completedPuzzles => (_p?.getStringList('completedPuzzles') ?? []).toSet();
  static void markCompleted(String id) {
    final list = (completedPuzzles..add(id)).toList();
    _p?.setStringList('completedPuzzles', list);
    syncToCloud({'completed_puzzles': list});
  }
  static bool isCompleted(String id) => completedPuzzles.contains(id);

  static Set<String> get parPuzzles => (_p?.getStringList('parPuzzles') ?? []).toSet();
  static void markParCompleted(String id) {
    if (isParCompleted(id)) return;
    final list = (parPuzzles..add(id)).toList();
    _p?.setStringList('parPuzzles', list);
    syncToCloud({'par_puzzles': list});
  }
  static bool isParCompleted(String id) => parPuzzles.contains(id);

  static Set<String> get failedPuzzles => (_p?.getStringList('failedPuzzles') ?? []).toSet();
  static void markFailed(String id) {
    final list = (failedPuzzles..add(id)).toList();
    _p?.setStringList('failedPuzzles', list);
    syncToCloud({'failed_puzzles': list});
  }
  static bool hasFailed(String id) => failedPuzzles.contains(id);

  static String get recentPack => _p?.getString('recentPack') ?? '';
  static set recentPack(String v) { _p?.setString('recentPack', v); syncToCloud({'recent_pack': v}); }

  static bool get showTimer => _p?.getBool('showTimer') ?? true;
  static set showTimer(bool v) { _p?.setBool('showTimer', v); AppSettings.showTimer = v; syncToCloud({'show_timer': v}); }

  static bool get enableMs => _p?.getBool('enableMs') ?? false;
  static set enableMs(bool v) { _p?.setBool('enableMs', v); AppSettings.enableMs = v; syncToCloud({'enable_ms': v}); }

  static int get movesDisplay => _p?.getInt('movesDisplay') ?? 0;
  static set movesDisplay(int v) { _p?.setInt('movesDisplay', v); AppSettings.movesDisplay = v; syncToCloud({'moves_display': v}); }

  static int get notifHour => _p?.getInt('notifHour') ?? 8;
  static int get notifMinute => _p?.getInt('notifMinute') ?? 0;

  static void setNotifTime(TimeOfDay t) {
    _p?.setInt('notifHour', t.hour);
    _p?.setInt('notifMinute', t.minute);
    syncToCloud({'notif_hour': t.hour, 'notif_minute': t.minute});
  }

  static TimeOfDay get notifTime => TimeOfDay(hour: notifHour, minute: notifMinute);

  static int get puzzlesCompleted => completedPuzzles.where((id) => !id.startsWith('d')).length;

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
  static int get dailiesCompleted => completedPuzzles.where((id) => id.startsWith('d')).length;

  static int completedInRange(String prefix, int start, int count) {
    int done = 0;
    for (int i = start + 1; i <= start + count; i++) {
      if (isCompleted('$prefix$i')) done++;
    }
    return done;
  }

  static Future<void> resetProgress() async {
    final fields = ['totalXP','completedPuzzles','failedPuzzles','parPuzzles','recentPack', 'totalFlips', 'unlockedAchievements'];
    for (final k in fields) {
      await _p?.remove(k);
    }
    syncToCloud({
      'total_xp': 0,
      'total_flips': 0,
      'recent_pack': '',
      'unlocked_achievements': <String>[],
      'completed_puzzles': <String>[],
      'failed_puzzles': <String>[],
      'par_puzzles': <String>[],
    });
  }

  static bool get hasOfflinePuzzles => (_p?.getString('offlinePuzzles') ?? '').isNotEmpty;
  static int get offlinePuzzleCount => _p?.getInt('offlinePuzzleCount') ?? 0;

  static Future<Map<String, dynamic>?> downloadAllPuzzles() async {
    try {
      final response = await Supabase.instance.client.from('puzzles').select().order('id') as List;
      final Map<String, dynamic> puzzleMap = { for (final p in response) p['id'].toString(): p };
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
    syncToCloud({
      'show_timer': true, 'enable_ms': false, 'moves_display': 0,
      'notif_hour': 8, 'notif_minute': 0,
    });
  }
}