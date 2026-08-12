// ===== FILE: lib/screens/settings/dev_screen.dart (HUB — rewritten) =====
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/core/constants.dart';
import 'package:folds/screens/settings/dev/dev_puzzles_screen.dart';
import 'package:folds/screens/settings/dev/dev_profiles_screen.dart';
import 'package:folds/screens/settings/dev/dev_streaks_screen.dart';
import 'package:folds/screens/settings/dev/dev_moderation_screen.dart';
import 'package:folds/screens/settings/dev/dev_notifications_screen.dart';
import 'package:folds/screens/settings/dev/dev_nuclear_screen.dart';
import 'package:folds/screens/settings/dev/dev_widgets.dart';

class DevPanelScreen extends StatefulWidget {
  const DevPanelScreen({super.key});
  @override
  State<DevPanelScreen> createState() => DevPanelScreenState();
}

class DevPanelScreenState extends State<DevPanelScreen> {
  bool _checking = true;
  bool _unlocked = false;
  int _profileCount = 0;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final result = await Supabase.instance.client.rpc('is_dev_user');
      final granted = result == true;
      AppStore.isDevProfile = granted;
      if (granted) {
        try {
          final count = await Supabase.instance.client.from('profiles').select('id');
          _profileCount = (count as List).length;
        } catch (_) {}
      }
      if (mounted) setState(() { _unlocked = granted; _checking = false; });
    } catch (e) {
      if (mounted) setState(() { _unlocked = false; _checking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2C2C2C))));
    }
    if (!_unlocked) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_rounded, size: 48, color: Color(0xFF2C2C2C)),
            const SizedBox(height: 16),
            Text('Developer access is restricted', textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Only the JayDev account can open this panel.', textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black45)),
            const SizedBox(height: 20),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
          ]),
        )),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black), onPressed: () => Navigator.pop(context)),
            ]),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2C2C2C), Color(0xFF1D1D1D)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('🛠️', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Text('DEV HQ', style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
                const SizedBox(height: 4),
                Text('Welcome back, ${AppStore.displayUsername}.',
                  style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(children: [
                  _StatPill(label: 'Day', value: '#${foldsDayNumberFor(DateTime.now())}'),
                  const SizedBox(width: 10),
                  _StatPill(label: 'Profiles', value: '$_profileCount'),
                  const SizedBox(width: 10),
                  _StatPill(label: 'XP', value: '${AppStore.totalXP}'),
                ]),
              ]),
            ),
            const SizedBox(height: 22),
            Text('TOOLS', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.15,
              children: [
                DevToolCard(icon: Icons.extension_rounded, title: 'Puzzles', subtitle: 'XP · completion · packs',
                  color: const Color(0xFF5865F2), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevPuzzlesScreen()))),
                DevToolCard(icon: Icons.badge_rounded, title: 'Profiles', subtitle: 'Search · view · ban',
                  color: const Color(0xFFE6543A), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevProfilesScreen()))),
                DevToolCard(icon: Icons.local_fire_department_rounded, title: 'Streaks', subtitle: 'Set · reset · daily',
                  color: const Color(0xFFFF8A3D), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevStreaksScreen()))),
                DevToolCard(icon: Icons.shield_rounded, title: 'Moderation', subtitle: 'Mods · bans · log',
                  color: const Color(0xFF7BD957), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevModerationScreen()))),
                DevToolCard(icon: Icons.campaign_rounded, title: 'Notifications', subtitle: 'Broadcast · targeted',
                  color: const Color(0xFFFFD465), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevNotificationsScreen()))),
                DevToolCard(icon: Icons.warning_amber_rounded, title: 'Nuclear', subtitle: 'Danger zone',
                  color: const Color(0xFFB71C1C), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevNuclearScreen()))),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  const _StatPill({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(value, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
      Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white38)),
    ]),
  );
}