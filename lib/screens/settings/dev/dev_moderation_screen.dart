// ===== FILE: lib/screens/settings/dev/dev_moderation_screen.dart =====
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/widgets/profile_search_field.dart';
import 'package:folds/widgets/moderation/leaderboard_ban_sheet.dart';
import 'dev_widgets.dart';

class DevModerationScreen extends StatefulWidget {
  const DevModerationScreen({super.key});
  @override
  State<DevModerationScreen> createState() => DevModerationScreenState();
}

class DevModerationScreenState extends State<DevModerationScreen> {
  final _modCtrl = TextEditingController();
  List<Map<String, dynamic>> _recentActions = [];
  bool _loadingLog = true;

  @override
  void initState() { super.initState(); _loadLog(); }

  Future<void> _loadLog() async {
    setState(() => _loadingLog = true);
    try {
      final data = await Supabase.instance.client.from('mod_actions').select()
          .order('created_at', ascending: false).limit(25);
      setState(() { _recentActions = List<Map<String, dynamic>>.from(data); _loadingLog = false; });
    } catch (e) { setState(() => _loadingLog = false); }
  }

  IconData _iconFor(String type) => switch (type) {
    'leaderboard_ban' => Icons.leaderboard_rounded,
    'leaderboard_unban' => Icons.shield_rounded,
    'game_ban' => Icons.gavel_rounded,
    _ => Icons.shield_rounded,
  };
  Color _colorFor(String type) => type.contains('unban') ? const Color(0xFF4CAF50) : Colors.red;

  @override
  Widget build(BuildContext context) {
    return DevSectionScaffold(
      title: 'Moderation', accent: const Color(0xFF7BD957), icon: Icons.shield_rounded,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MOD ROLE', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 10),
          TextField(controller: _modCtrl, decoration: InputDecoration(hintText: 'Username',
            filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DevPrimaryButton(label: 'Approve', color: const Color(0xFF7BD957), icon: Icons.check_rounded, onTap: () async {
              final u = _modCtrl.text.trim();
              if (u.isEmpty) { devToast(context, 'Enter a username', error: true); return; }
              try { await Supabase.instance.client.rpc('approve_moderator', params: {'target_username': u});
                devToast(context, '$u approved as moderator'); } catch (e) { devToast(context, '$e', error: true); }
            })),
            const SizedBox(width: 8),
            Expanded(child: DevPrimaryButton(label: 'Revoke', color: Colors.red.shade400, icon: Icons.close_rounded, onTap: () async {
              final u = _modCtrl.text.trim();
              if (u.isEmpty) { devToast(context, 'Enter a username', error: true); return; }
              try { await Supabase.instance.client.rpc('revoke_moderator', params: {'target_username': u});
                devToast(context, '$u revoked'); } catch (e) { devToast(context, '$e', error: true); }
            })),
          ]),
        ])),
        DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LEADERBOARD BAN', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 10),
          ProfileSearchField(hint: 'Search a username to ban...',
            onSelected: (u) => showLeaderboardBanSheet(context, username: u, onDone: _loadLog)),
        ])),
        Text('RECENT ACTIONS', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
        const SizedBox(height: 10),
        if (_loadingLog) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
        if (!_loadingLog && _recentActions.isEmpty)
          Text('No moderation actions yet.', style: GoogleFonts.dmSans(color: Colors.black38)),
        ..._recentActions.map((a) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(_iconFor(a['action_type']), color: _colorFor(a['action_type']), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['action_type']} · ${a['target_username']}', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800)),
              if (a['reason'] != null) Text(a['reason'], style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black54)),
              Text('by ${a['performed_by']}', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.black38)),
            ])),
          ]),
        )),
      ]),
    );
  }
}