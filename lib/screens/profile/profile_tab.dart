import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/state/app_store.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/models/xp_system.dart';
import 'package:folds/painters/icon_painters.dart';
import 'package:flutter/services.dart';
import 'package:folds/screens/gameplay_screen.dart';
import 'package:folds/widgets/shared/misc.dart';
import 'public_profile_sheet.dart';
import 'account_management_screen.dart';
import 'auth_screen.dart';


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
                          if (success == true) {
                            await AppStore.downloadCloudProfile();
                            if (mounted) {
                              _loadAvatar();
                              setState(() {});
                            }
                          }
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
                    // AFTER
onTap: () {
  String prefix = recentPack == 'PILOT' ? 'p' : 'r';
  int max = recentPack == 'PILOT' ? 100 : 100;
  String targetId = '${prefix}1';
  for (int i = 1; i <= max; i++) {
    if (!AppStore.isCompleted('$prefix$i')) { targetId = '$prefix$i'; break; }
  }
  Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
    pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: targetId),
    transitionsBuilder: (_, animation, __, child) {
      final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: slide, child: child);
    },
    transitionDuration: const Duration(milliseconds: 320),
  ), (route) => false);
};
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

