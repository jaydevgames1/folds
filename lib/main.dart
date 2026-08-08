import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'models/xp_system.dart';
import 'models/achievement_def.dart';
import 'models/texture_pack_def.dart';
import 'state/app_store.dart';
import 'services/audio_service.dart';
import 'painters/icon_painters.dart';
import 'painters/texture_painters.dart';
import 'widgets/shared/folds_top_bar.dart';
import 'widgets/shared/misc.dart';
import 'widgets/recipient_picker.dart';
import 'widgets/badge_info_dialog.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/gameplay_screen.dart';
import 'screens/puzzles/puzzle_selector_screen.dart';
import 'screens/settings/dev_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await Supabase.initialize(
    url: 'https://kvihtmzgthznjtwqtbvg.supabase.co',
    publishableKey: 'sb_publishable_hznxJ0hZwXRvO-KHZuoYag_RXPDWfWI',
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

void pushFade(BuildContext context, Widget screen) {
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

Future<void> launchCustomUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint('Could not launch $url');
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
              FoldsTopBar(title: 'CREDITS', onBack: () => Navigator.pop(context)),
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
              FoldsTopBar(title: 'SOCIALS', onBack: () => Navigator.pop(context)),
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
                        onTap: () => launchCustomUrl('https://www.youtube.com/@JayDevGames1'),
                      ),
                      
                      _SocialCard(
                        icon: Icons.music_note_rounded,
                        iconColor: const Color(0xFF25F4EE),
                        title: 'TikTok',
                        subtitle: 'Get regular updates, limited but exclusive behind-the-scenes videos & more.',
                        onTap: () => launchCustomUrl('https://www.tiktok.com/@jaydevgames'),
                      ),
                      
                      _SocialCard(
                        icon: Icons.camera_alt_rounded,
                        iconColor: const Color(0xFFE1306C),
                        title: 'Instagram',
                        subtitle: 'Get regular updates, limited but exclusive behind-the-scenes videos & more.',
                        onTap: () => launchCustomUrl('https://www.instagram.com/jaydev_games'),
                      ),
                      
                      _SocialCard(
                        icon: Icons.public_rounded,
                        iconColor: const Color(0xFFFFD465),
                        title: 'Website',
                        subtitle: 'View guides, updates, register, articles, content and so much more on the Folds website.',
                        onTap: () => launchCustomUrl('https://folds.jaydev.games'),
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

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
  File? _avatarImage;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  void _loadAvatar() {
    final path = AppStore.avatarPath;
    if (path == null) return;
    if (path.startsWith('http')) {
      // cache-bust so a re-upload shows immediately instead of a stale CDN copy
      _avatarUrl = '$path?t=${DateTime.now().millisecondsSinceEpoch}';
    } else if (File(path).existsSync()) {
      _avatarImage = File(path);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _avatarImage = File(picked.path);
      _avatarUrl = null;
    });

    final user = AppStore.currentUser;
    if (user == null || user.isAnonymous) return; // guests get local-only preview
    try {
      final bytes = await File(picked.path).readAsBytes();
      final storagePath = '${user.id}/avatar.jpg';
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(storagePath, bytes,
              fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(storagePath);
      AppStore.avatarPath = publicUrl;
      setState(() {
        _avatarUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
        _avatarImage = null; // prefer the network copy going forward
      });
    } catch (e) {
      debugPrint('Avatar upload failed: $e');
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
                      : _avatarUrl != null
                          ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover)
                          : null,
                ),
                child: (_avatarImage == null && _avatarUrl == null)
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
                    painter: FirePainter(
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
                    onTap: () => showPublicProfile(context,
                      username: AppStore.displayUsername,
                      xp: AppStore.totalXP,
                      leaderboardRank: 0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('VIEW PROFILE', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
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
          ProgressBar(progress: xpProgress, color: const Color(0xFFFFD465),
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
            ProgressBar(
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

          
    
    

          GestureDetector(
            onTap: () async {
              final user = AppStore.currentUser;
              if (user == null || user.isAnonymous) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to manage your account.')));
              } else {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountManagementScreen()));
                setState(() {});
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text('Manage Account',
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


// ─────────────────────────────────────────────────────────────────────────────
// STATS & ACHIEVEMENTS UI
// ─────────────────────────────────────────────────────────────────────────────
class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

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

class AchievementsTab extends StatelessWidget {
  const AchievementsTab({super.key});

  static const _categories = [
    ('GETTING STARTED', ['first_fold', 'folding_frenzy']),
    ('PUZZLES COMPLETED', ['novice_folder', 'adept_folder', 'expert_folder', 'master_folder']),
    ('PAR MASTERY', ['par_10', 'par_50', 'par_150']),
    ('STREAKS', ['streak_7', 'streak_30', 'streak_100', 'streak_365']),
    ('GRID SIZE', ['grid_master']),
    ('FLIPS', ['flippin_crazy', 'flipaholic', 'addicted_to_flipping', 'flip_god']),
    ('SKILL', ['flawless', 'speed_demon']),
    ('SHADOW', ['exterminator', 'build', 'just_in_case', 'night_owl', 'early_bird',
                'one_more', 'comeback_kid', 'perfectionist', 'beta_tester', 'chosen_one']),
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

void showRedeemDialog(BuildContext outerContext) {
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
    } else if (rewardType == 'texture') {
      AppStore.unlockTexturePack(rewardValue);
      final def = texturePacks.firstWhere((t) => t.id.name == rewardValue, orElse: () => texturePacks.first);
      successMessage = '🎨 "${def.name}" texture pack unlocked! Equip it in Settings → Texture Packs.';
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






class ModsAndDevsScreen extends StatelessWidget {
  const ModsAndDevsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(children: [
            FoldsTopBar(title: 'MODS & DEVS', onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 20, bottom: 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.shield_rounded, color: Color(0xFFFFD465), size: 28),
                    const SizedBox(width: 10),
                    Text('Moderators', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    'Moderators help keep the Folds community friendly, respectful and spam-free. '
                    'They can send announcements to specific players or the whole community, and help '
                    'review reports submitted through public profiles.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),
                  const SizedBox(height: 14),
                  Text('How rare is it?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'Extremely. Moderators are hand-picked by the developer based on how they show up in the '
                    'community — helpfulness, patience, and good judgement. There is no application form and '
                    'no guaranteed path — most players will never be one.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),
                  
                  const SizedBox(height: 14),

                  Text('Can I request it?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'There is a request option in Settings → Moderator Access, but sending a request doesn\'t '
                    'guarantee approval — it just puts your name forward. Being visibly kind and helpful in the '
                    'community is worth far more than requesting.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),

                  const SizedBox(height: 14),

                  Text('Do Moderators have an unfair advantage in the game?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'No. Moderators do not have any special access to puzzles, answers, or game data. They are '
                    'simply trusted members of the community who help keep the game safe and enjoyable for'
                    'everyone, however they sometimes receive certain packs before everyone else as rewards '
                    'for their efforts in the community and bugfixing. This is a perk, not an advantage, '
                    'and XP is not rewarded for unreleased packs, or until everyone can play it.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),

                  const SizedBox(height: 14),

                Text('Do Moderators get paid?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'No. Being a moderator is a voluntary position. It is a badge of trust and respect, not '
                  'a paid job. They are not directly paid for being a Moderator, however they can receive '
                  'certain packs or in-game purchases for free using promo-codes. These aren\'t limited to '
                  'Moderators, but it would be more likely for a Moderator to receive these than a regular '
                  'player.',
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),

                const SizedBox(height: 14),

                Text('What if a Moderator breaks the rules?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'If you see a Moderator abuse their power, or break Folds Rules, you can report them just '
                  'like any other player. The developer will review the report and take necessary action. '
                  'Moderators are held to a higher standard than any other player, and if they break the rules '
                  'in any way they will be demoted and lose their Moderator status. Moderators are not above the '
                  'rules and expected to follow them at all times with no exceptions.',
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),

                const SizedBox(height: 14),

                Text('How can I improve my chances of becoming a Moderator?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'You can mainly interact with the community in the JayDev Games Discord server \(you can find '
                  'the invite link in the Socials Screen). Be helpful, patient, and kind to others. Consistently '
                  'being engaging and respectful dramatically increases your chances of being a Moderator more '
                  'than any request or waiting period. This doesn\'t guarantee Moderator roles, but improves chances '
                  'of them. If you believe you have what it takes, and have been a positive member of the community, '
                  'you can speak about it in the JayDev Games Discord server.',
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),
                
                const SizedBox(height: 14),

                Text('Can Moderators leak content in upcoming updates?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'No. Moderators can have access to upcoming unreleased content which is for the eyes for themselves '
                  'and other Moderators only. If a Moderator leaks content, please'
                  'the invite link in the Socials Screen). Be helpful, patient, and kind to others. Consistently '
                  'being engaging and respectful dramatically increases your chances of being a Moderator more '
                  'than any request or waiting period. This doesn\'t guarantee Moderator roles, but improves chances '
                  'of them. If you believe you have what it takes, and have been a positive member of the community, '
                  'you can speak about it in the JayDev Games Discord server.',
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),

                const SizedBox(height: 14),

                Text('Can Moderators ban or manage my game account?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'No. Moderators cannot ban, suspend, or manage your game account in any way. They can, however, report '
                  'your account to the developer if they believe you are breaking the Folds Rules, and their opinion will be '
                  'highly regarded. Only the Developer can take action on your account, and will review any reports made by '
                  'Moderators or any other player. If you believe a Moderator has unfairly reported you, you can appeal the ban '
                  'or restriction, or report by contacting the Developer at support@jaydev.games.',
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),



                  const SizedBox(height: 28),
                  Container(height: 1, color: const Color(0xFFEFEFEF)),
                  const SizedBox(height: 28),
                  Row(children: [
                    const Icon(Icons.code_rounded, color: Color(0xFF5865F2), size: 28),
                    const SizedBox(width: 10),
                    Text('Developer', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    'Folds is built and maintained by a single developer, JayDev. Every puzzle, every line '
                    'of code, and every update comes from one person. There is only ever one Developer badge, '
                    'and it isn\'t given out; it belongs to whoever made the game.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),

                    const SizedBox(height: 14),
                  Text('What if I see the Developer break the rules?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'The Developer is expected to follow the same rules but can take the necessary action to '
                    'any player upon their wishes. It is highly guaranteed the Developer\'s actions are always '
                    'in the best interest of the game and community, and are justified to fit the situation. If '
                    'you have a problem or issue with the Developer\'s actions, you can reach out to them directly '
                    'by mailing them at support@jaydev.games.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.6)),
                  
                  const SizedBox(height: 14),
                ]),
              ),
            ),
          ]),
        ),
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
              FoldsTopBar(title: 'MOD ACCESS', onBack: () => Navigator.pop(context)),
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
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ModeratorNotifyScreen())),
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Icon(Icons.campaign_rounded, color: Color(0xFFFFD465), size: 24),
                      const SizedBox(width: 12),
                      Text('SEND ANNOUNCEMENT', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                    ]),
                  ),
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
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});
  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  List<Map<String, dynamic>> _receipts = [];
  bool _loading = true;
  final Set<int> _expanded = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final username = AppStore.displayUsername;
      final isMod = AppStore.isModerator;
      final filters = ['recipient.eq.all', 'recipient.eq.$username'];
      if (isMod) filters.add('recipient.eq.@Moderators');
      final data = await Supabase.instance.client
          .from('notifications')
          .select()
          .or(filters.join(','))
          .order('created_at', ascending: false)
          .limit(100);
      setState(() { _receipts = List<Map<String, dynamic>>.from(data); _loading = false; });
      await AppStore.markReceiptsSeen();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Color _bgColor(String? key) {
    const map = {
      'Gold': Color(0xFFFFD465), 'Green': Color(0xFF7BD957),
      'Blue': Color(0xFF5865F2), 'Red': Color(0xFFE6543A),
    };
    return map[key] ?? const Color(0xFFEFEFEF);
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(dateOnly).inDays;
    if (diff == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff > 0 && diff < 7) {
      const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      return days[dt.weekday - 1];
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _resolveRecipientLabel(String recipient) {
    if (recipient == 'all') return 'Everyone';
    if (recipient == '@Moderators') return 'Moderators';
    return 'You specifically';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(children: [
            FoldsTopBar(title: 'RECEIPTS', onBack: () => Navigator.pop(context)),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2C2C2C)))
                  : _receipts.isEmpty
                      ? Center(child: Text('No notifications yet',
                          style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black38)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _receipts.length,
                            itemBuilder: (context, i) {
                              final r = _receipts[i];
                              final isExpanded = _expanded.contains(i);
                              DateTime? created;
                              try { created = DateTime.parse(r['created_at'].toString()); } catch (_) {}
                              final bg = _bgColor(r['background'] as String?);
                              final isColored = r['background'] != null;
                              return GestureDetector(
                                onTap: () => setState(() =>
                                  isExpanded ? _expanded.remove(i) : _expanded.add(i)),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      Expanded(child: Text(r['title']?.toString() ?? '',
                                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87))),
                                      if (created != null)
                                        Text(_formatDate(created), style: GoogleFonts.dmSans(
                                          fontSize: 11, fontWeight: FontWeight.w700,
                                          color: isColored ? Colors.black54 : Colors.black38)),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(r['body']?.toString() ?? '',
                                      maxLines: isExpanded ? null : 2,
                                      overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54)),
                                    if (isExpanded) ...[
                                      const SizedBox(height: 10),
                                      Row(children: [
                                        const Icon(Icons.person_rounded, size: 14, color: Colors.black38),
                                        const SizedBox(width: 4),
                                        Text('From: ${r['author']?.toString() ?? 'Folds Team'}',
                                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
                                      ]),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        const Icon(Icons.group_rounded, size: 14, color: Colors.black38),
                                        const SizedBox(width: 4),
                                        Text('To: ${_resolveRecipientLabel(r['recipient']?.toString() ?? 'all')}',
                                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
                                      ]),
                                    ],
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}

class ModeratorNotifyScreen extends StatefulWidget {
  const ModeratorNotifyScreen({super.key});
  @override
  State<ModeratorNotifyScreen> createState() => _ModeratorNotifyScreenState();
}

class _ModeratorNotifyScreenState extends State<ModeratorNotifyScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _recipient = 'all';
  bool _sending = false;

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    if (!await isValidRecipient(_recipient)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No profile found for "$_recipient"')));
        setState(() => _sending = false);
      }
      return;
    }
    try {
      await Supabase.instance.client.from('notifications').insert({
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'recipient': _recipient,
        'author': AppStore.displayUsername,
        'background': null, // moderators can't customize appearance
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sent to $_recipient', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF2C2C2C)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(children: [
            FoldsTopBar(title: 'ANNOUNCEMENT', onBack: () => Navigator.pop(context)),
            const SizedBox(height: 20),
            TextField(controller: _titleCtrl, decoration: InputDecoration(
              hintText: 'Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 12),
            TextField(controller: _bodyCtrl, maxLines: 4, decoration: InputDecoration(
              hintText: 'Message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text('RECIPIENT',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 1))),
            const SizedBox(height: 6),
            RecipientPicker(initial: 'all', onSelected: (v) => _recipient = v),
            const Spacer(),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(14)),
                child: Center(child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('SEND', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
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
          // Change from AppStore._p?.setString(...) to:
          await AppStore.setLocalJoinDate(joinStr);
          await AppStore.setLocalUsername(_usernameController.text.trim());

          // Auto sign-in immediately after creating account
          try {
            await Supabase.instance.client.auth.signInWithPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
            // Explicitly push the real join date to Supabase NOW — don't rely
            // on an incidental future sync to carry it up.
            final uid = Supabase.instance.client.auth.currentUser?.id;
            if (uid != null) {
              await Supabase.instance.client.from('profiles').update({
                'join_date': joinStr,
                'username': _usernameController.text.trim(),
              }).eq('id', uid);
            }
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
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))],
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

