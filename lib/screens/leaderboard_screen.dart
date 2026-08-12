import 'package:flutter/material.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:folds/models/xp_system.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/screens/profile/public_profile_sheet.dart';
import 'package:folds/widgets/badge_info_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/widgets/moderation/leaderboard_ban_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LEADERBOARD — v2: podium + gradient header + staggered list entrance
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => LeaderboardScreenState();
}

class LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;
  late final AnimationController _entrance =
      AnimationController(duration: const Duration(milliseconds: 700), vsync: this);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _entrance.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username, total_xp, avatar_path, is_moderator, is_dev_profile, mod_since, is_leaderboard_banned')
          .or('is_leaderboard_banned.eq.false,is_leaderboard_banned.is.null')
          .order('total_xp', ascending: false)
          .limit(50);

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
      _entrance.forward(from: 0);
    } catch (e) {
      setState(() { _error = 'Could not load rankings.'; _loading = false; });
    }
  }
  void _showModActions(BuildContext context, String username, bool isBanned) {
  if (!(AppStore.isModerator || AppStore.isDevProfile)) return;
  if (username == AppStore.displayUsername) return;
  showModalBottomSheet(
    context: context, backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(isBanned ? Icons.shield_rounded : Icons.leaderboard_rounded,
              color: isBanned ? const Color(0xFF4CAF50) : Colors.red),
            title: Text(isBanned ? 'Lift Leaderboard Ban' : 'Leaderboard Ban',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w800)),
            onTap: () {
              Navigator.pop(ctx);
              showLeaderboardBanSheet(context, username: username, isCurrentlyBanned: isBanned, onDone: _load);
            },
          ),
        ]),
      ),
    ),
  );
} 
  @override
  Widget build(BuildContext context) {
    final myXP = AppStore.totalXP;
    final top3 = _entries.take(3).toList();
    final rest = _entries.length > 3 ? _entries.sublist(3) : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: FoldsTopBar(title: 'TOP FOLDERS', onBack: () => Navigator.pop(context)),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2C2C2C), strokeWidth: 3))
                  : _error != null
                      ? Center(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black38)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: const Color(0xFF2C2C2C),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              if (top3.isNotEmpty) _PodiumHeader(top3: top3, entrance: _entrance),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(children: [
                                  if (AppStore.currentUser != null) _MyRankCard(myXP: myXP, entries: _entries),
                                  for (int i = 0; i < rest.length; i++)
                                    _AnimatedRow(
                                      index: i,
                                      entrance: _entrance,
                                      child: _LeaderboardRow(entry: rest[i], rank: i + 4),
                                    ),
                                  const SizedBox(height: 20),
                                ]),
                              ),
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

class _AnimatedRow extends StatelessWidget {
  final int index;
  final Animation<double> entrance;
  final Widget child;
  const _AnimatedRow({required this.index, required this.entrance, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.03).clamp(0.0, 0.7);
    final anim = CurvedAnimation(parent: entrance, curve: Interval(start, (start + 0.3).clamp(0.0, 1.0), curve: Curves.easeOut));
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(offset: Offset(0, 14 * (1 - anim.value)), child: c),
      ),
      child: child,
    );
  }
}

class _MyRankCard extends StatelessWidget {
  final int myXP;
  final List<Map<String, dynamic>> entries;
  const _MyRankCard({required this.myXP, required this.entries});

  @override
  Widget build(BuildContext context) {
    final myPos = entries.indexWhere(
      (e) => e['total_xp'] == myXP && e['username'] == AppStore.displayUsername);
    final rank = myPos >= 0 ? myPos + 1 : null;
    final shieldColor = XPSystem.shieldColor(XPSystem.rankFromXP(myXP));
    return Container(
      margin: const EdgeInsets.only(bottom: 14, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2C2C2C), Color(0xFF1D1D1D)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
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
  }
}

// ── Podium for #1 / #2 / #3, in a gradient hero header ─────────────────────
class _PodiumHeader extends StatelessWidget {
  final List<Map<String, dynamic>> top3;
  final Animation<double> entrance;
  const _PodiumHeader({required this.top3, required this.entrance});

  Map<String, dynamic>? _at(int i) => i < top3.length ? top3[i] : null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C2C2C), Color(0xFF3A3A50)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PodiumSlot(entry: _at(1), rank: 2, height: 108, entrance: entrance, delay: 0.06),
          const SizedBox(width: 10),
          _PodiumSlot(entry: _at(0), rank: 1, height: 138, entrance: entrance, delay: 0.0),
          const SizedBox(width: 10),
          _PodiumSlot(entry: _at(2), rank: 3, height: 86, entrance: entrance, delay: 0.12),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final Map<String, dynamic>? entry;
  final int rank;
  final double height;
  final Animation<double> entrance;
  final double delay;
  const _PodiumSlot({required this.entry, required this.rank, required this.height, required this.entrance, required this.delay});

  static const _colors = {1: Color(0xFFFFD465), 2: Color(0xFFD8D8D8), 3: Color(0xFFCF8A4E)};

  @override
  Widget build(BuildContext context) {
    if (entry == null) return const SizedBox(width: 84);
    final username = entry!['username']?.toString() ?? 'Folder';
    final xp = (entry!['total_xp'] as int?) ?? 0;
    final color = _colors[rank]!;
    final anim = CurvedAnimation(parent: entrance, curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutBack));

    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 24 * (1 - anim.value.clamp(0.0, 1.0))),
        child: Opacity(opacity: anim.value.clamp(0.0, 1.0), child: child),
      ),
      child: GestureDetector(
        onTap: () => showPublicProfile(context, username: username, xp: xp, leaderboardRank: rank),
        child: SizedBox(
          width: 84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded, color: color, size: rank == 1 ? 30 : 22),
              const SizedBox(height: 6),
              Container(
                width: rank == 1 ? 60 : 48, height: rank == 1 ? 60 : 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white10,
                  border: Border.all(color: color, width: 2.5),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white38),
              ),
              const SizedBox(height: 8),
              Text(username, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('$xp XP', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white54)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: height,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Center(child: Text('$rank', style: GoogleFonts.dmSans(
                  fontSize: 26, fontWeight: FontWeight.w800, color: color))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int rank;
  const _LeaderboardRow({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    final xp = (entry['total_xp'] as int?) ?? 0;
    final username = entry['username']?.toString() ?? 'Folder';
    final xpRank = XPSystem.rankFromXP(xp);
    final shieldColor = XPSystem.shieldColor(xpRank);

    return GestureDetector(
      onTap: () => showPublicProfile(context, username: username, xp: xp, leaderboardRank: rank),
      onLongPress: () {
        final state = context.findAncestorStateOfType<LeaderboardScreenState>();
        state?._showModActions(context, username, (entry['is_leaderboard_banned'] as bool?) ?? false);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          SizedBox(
            width: 36,
            child: Text('#$rank', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black38)),
          ),
          const SizedBox(width: 10),
          Stack(alignment: Alignment.center, children: [
            Icon(Icons.shield_rounded, color: shieldColor, size: 30),
            Text('$xpRank', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Row(children: [
            Flexible(child: Text(username, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black))),
            if ((entry['is_dev_profile'] as bool?) == true || (entry['is_moderator'] as bool?) == true) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  DateTime? ms;
                  final raw = entry['mod_since'] as String?;
                  if (raw != null) { try { ms = DateTime.parse(raw); } catch (_) {} }
                  showBadgeInfoDialog(context,
                    username: username,
                    isDev: (entry['is_dev_profile'] as bool?) ?? false,
                    modSince: ms);
                },
                child: Icon(
                  (entry['is_dev_profile'] as bool?) == true ? Icons.code_rounded : Icons.shield_rounded,
                  size: 15,
                  color: (entry['is_dev_profile'] as bool?) == true
                    ? const Color(0xFF5865F2) : const Color(0xFFFFD465)),
              ),
            ],
          ])),
          Text('$xp XP', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38)),
        ]),
      ),
    );
  }
}
