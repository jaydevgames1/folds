import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/state/app_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/models/xp_system.dart';
import 'package:folds/widgets/badge_info_dialog.dart';

void showPublicProfile(BuildContext context, {
  required String username,
  required int xp,
  required int leaderboardRank,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PublicProfileSheet(
      username: username,
      xp: xp,
      leaderboardRank: leaderboardRank,
    ),
  );
}

class PublicProfileSheet extends StatefulWidget {
  final String username;
  final int xp;
  final int leaderboardRank;
  const PublicProfileSheet({required this.username, required this.xp, required this.leaderboardRank});
  @override
  State<PublicProfileSheet> createState() => PublicProfileSheetState();
}

class PublicProfileSheetState extends State<PublicProfileSheet> {
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

  void showReportConfirm() {
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
                              onTap: () => showBadgeInfoDialog(context, username: username, isDev: true),
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
                              onTap: () => showBadgeInfoDialog(context, username: username, isDev: false, modSince: modSince),
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
                              onTap: showReportConfirm,
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


