import 'package:flutter/material.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:folds/models/xp_system.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/screens/profile/public_profile_sheet.dart';
import 'package:folds/widgets/badge_info_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
                                            showBadgeInfoDialog(context,
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
