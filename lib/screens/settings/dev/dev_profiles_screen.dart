// ===== FILE: lib/screens/settings/dev/dev_profiles_screen.dart =====
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/models/xp_system.dart';
import 'package:folds/models/achievement_def.dart';
import 'package:folds/widgets/profile_search_field.dart';
import 'package:folds/widgets/moderation/leaderboard_ban_sheet.dart';
import 'package:folds/widgets/shared/folds_dialog.dart';
import 'dev_widgets.dart';

class DevProfilesScreen extends StatefulWidget {
  const DevProfilesScreen({super.key});
  @override
  State<DevProfilesScreen> createState() => DevProfilesScreenState();
}

class DevProfilesScreenState extends State<DevProfilesScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = false;

  Future<void> _load(String username) async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client.from('profiles').select().eq('username', username).maybeSingle();
      setState(() { _profile = data; _loading = false; });
      if (data == null && mounted) devToast(context, 'No profile found for "$username"', error: true);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) devToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DevSectionScaffold(
      title: 'Profiles', accent: const Color(0xFFE6543A), icon: Icons.badge_rounded,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        ProfileSearchField(hint: 'Search any username...', onSelected: _load),
        const SizedBox(height: 18),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        if (!_loading && _profile != null) _ProfileDetail(profile: _profile!, onChanged: () => _load(_profile!['username'])),
      ]),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onChanged;
  const _ProfileDetail({required this.profile, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final username = profile['username']?.toString() ?? '';
    final xp = (profile['total_xp'] as int?) ?? 0;
    final rank = XPSystem.rankFromXP(xp);
    final avatarPath = profile['avatar_path'] as String?;
    final isNetwork = avatarPath != null && avatarPath.startsWith('http');
    final isMod = (profile['is_moderator'] as bool?) ?? false;
    final isDev = (profile['is_dev_profile'] as bool?) ?? false;
    final isLbBanned = (profile['is_leaderboard_banned'] as bool?) ?? false;
    final isBanned = (profile['is_banned'] as bool?) ?? false;
    final unlocked = List<String>.from(profile['unlocked_achievements'] ?? []);
    final completed = List<String>.from(profile['completed_puzzles'] ?? []);

    return Column(children: [
      DevCard(child: Column(children: [
        Row(children: [
          Container(width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFEFEFEF),
              image: isNetwork ? DecorationImage(image: NetworkImage(avatarPath), fit: BoxFit.cover) : null),
            child: !isNetwork ? const Icon(Icons.person_rounded, color: Colors.black26, size: 32) : null),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(username, style: GoogleFonts.dmSans(fontSize: 19, fontWeight: FontWeight.w800))),
              if (isDev) _Badge('DEV', const Color(0xFF5865F2)),
              if (isMod && !isDev) _Badge('MOD', const Color(0xFFFFD465), dark: true),
              if (isLbBanned) _Badge('LB BAN', Colors.red),
              if (isBanned) _Badge('BANNED', Colors.black),
            ]),
            Text(profile['join_date']?.toString() ?? '—', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black45)),
          ])),
        ]),
      ])),
      DevCard(child: Row(children: [
        _StatBox(label: 'XP', value: '$xp'),
        _StatBox(label: 'Rank', value: '$rank'),
        _StatBox(label: 'Streak', value: '${profile['current_streak'] ?? 0}'),
        _StatBox(label: 'Flips', value: '${profile['total_flips'] ?? 0}'),
      ])),
      DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('COMPLETED PUZZLES · ${completed.length}', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text('ACHIEVEMENTS UNLOCKED · ${unlocked.length} / ${appAchievements.length}', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: unlocked.map((id) {
          final def = appAchievements.firstWhere((a) => a.id == id, orElse: () => AchievementDef(id, id, '', Icons.star));
          return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(10)),
            child: Text(def.title, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700)));
        }).toList()),
      ])),
      if ((profile['leaderboard_ban_reason'] ?? profile['banned_reason']) != null)
        DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BAN NOTES', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.red, letterSpacing: 1)),
          const SizedBox(height: 6),
          if (profile['leaderboard_ban_reason'] != null)
            Text('Leaderboard: ${profile['leaderboard_ban_reason']}', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54)),
          if (profile['banned_reason'] != null)
            Text('Full ban: ${profile['banned_reason']}', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54)),
        ])),
      DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ACTIONS', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DevPrimaryButton(
            label: isLbBanned ? 'Lift LB Ban' : 'Leaderboard Ban',
            color: isLbBanned ? const Color(0xFF4CAF50) : Colors.red.shade400,
            icon: Icons.leaderboard_rounded,
            onTap: () => showLeaderboardBanSheet(context, username: username, isCurrentlyBanned: isLbBanned, onDone: onChanged),
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: DevPrimaryButton(
            label: isBanned ? 'Unban from Game' : 'Ban from Game',
            color: isBanned ? const Color(0xFF4CAF50) : Colors.black,
            icon: Icons.gavel_rounded,
            onTap: () => _confirmGameBan(context, username, isBanned, onChanged),
          )),
        ]),
      ])),
    ]);
  }

  void _confirmGameBan(BuildContext context, String username, bool isBanned, VoidCallback onDone) {
    if (isBanned) {
      showFoldsDialog(context,
        title: 'Unban $username?',
        message: 'They will be able to sign in and play again immediately.',
        icon: Icons.gavel_rounded, iconColor: const Color(0xFF4CAF50),
        actions: [
          FoldsDialogAction(label: 'Cancel', onTap: () {}),
          FoldsDialogAction(label: 'Unban', isPrimary: true, color: const Color(0xFF4CAF50), onTap: () async {
            try {
              await Supabase.instance.client.rpc('unban_user_from_game', params: {'target_username': username});
              onDone();
            } catch (_) {}
          }),
        ],
      );
      return;
    }
    final reasonCtrl = TextEditingController();
    showFoldsDialog(context,
      title: 'Ban $username from the game?',
      content: TextField(controller: reasonCtrl, maxLines: 3, decoration: InputDecoration(
        hintText: 'Reason for the ban...', filled: true, fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      icon: Icons.gavel_rounded, iconColor: Colors.red,
      actions: [
        FoldsDialogAction(label: 'Cancel', onTap: () {}),
        FoldsDialogAction(label: 'Ban', isPrimary: true, color: Colors.red, onTap: () async {
          try {
            await Supabase.instance.client.rpc('ban_user_from_game',
              params: {'target_username': username, 'reason': reasonCtrl.text.trim()});
            onDone();
          } catch (_) {}
        }),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label; final Color color; final bool dark;
  const _Badge(this.label, this.color, {this.dark = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w800, color: dark ? Colors.black : Colors.white))),
  );
}

class _StatBox extends StatelessWidget {
  final String label, value;
  const _StatBox({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800)),
    Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.w600)),
  ]));
}