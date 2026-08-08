import 'package:flutter/material.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/main.dart';
import 'package:folds/widgets/shared/form_controls.dart';
import 'package:folds/widgets/shared/buttons.dart';
import 'package:folds/models/texture_pack_def.dart';
import 'package:folds/state/app_settings.dart';
import 'package:folds/services/audio_service.dart';
import 'package:folds/widgets/shared/misc.dart';
import 'package:folds/screens/onboarding/onboarding_screen.dart';
import 'package:folds/screens/settings/dev_screen.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  int _theme = 0;
  int _versionTapCount = 0;
  DateTime? lastVersionTap;
  bool _reducedMotion = false;
  bool _showTimer = AppStore.showTimer;
  bool _enableMs = AppStore.enableMs;
  int _movesDisplay = AppStore.movesDisplay;
  TimeOfDay _notifTime = AppStore.notifTime;
  bool _haptic = AppStore.haptic;
  double _sfx = 0.55;
  double _trackVolume = 0.4;
  bool _isPlaying = false;
  int _frameRate = 0;
  bool _staticBg = false;
  bool _dailyNotif = true;
  bool _newPacksNotif = true;
  int _handedMode = 0;
  bool _optOutData = false;
  bool _justDont = false;
  
  void _showBugReport(BuildContext ctx) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text('Report a Bug', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Describe what happened and how to reproduce it.',
            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'e.g. When I tap the 6x6 grid puzzle and...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: const Color(0xFFF5F5F5)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(dialogCtx);
              // Log to Supabase
              try {
                await Supabase.instance.client.from('bug_reports').insert({
                  'username': AppStore.displayUsername,
                  'user_id': AppStore.currentUser?.id,
                  'description': ctrl.text.trim(),
                  'created_at': DateTime.now().toIso8601String(),
                });
              } catch (_) {}
              // Grant achievement
              if (!AppStore.isUnlocked('exterminator')) {
                AppStore.unlockAchievement('exterminator');
              }
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text('Bug report sent! Thanks for helping 🐛',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                  backgroundColor: const Color(0xFF2C2C2C),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              }
            },
            child: Text('Send Report', style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _t(String text) {
    if (!_justDont) return text;
    return text.replaceAll('a', 'u').replaceAll('e', 'ee').replaceAll('o', 'aw').replaceAll('s', 'z')
               .replaceAll('A', 'U').replaceAll('E', 'EE').replaceAll('O', 'AW').replaceAll('S', 'Z');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              FoldsTopBar(title: 'SETTINGS', onBack: () => Navigator.pop(context)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16, bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader('VISUAL'),
                      SegmentedRow(
                        title: 'Theme',
                        hint: 'Based off of local time',
                        options: const ['LIGHT', 'DARK', 'AUTO'],
                        selected: _theme,
                        onChanged: (i) => setState(() => _theme = i),
                      ),
                      ToggleRow(
                        title: 'Reduced Motion',
                        subtitle: 'Disables aesthetic animations',
                        value: _reducedMotion,
                        onChanged: (v) => setState(() => _reducedMotion = v),
                      ),
                      OpenRow(
                        title: 'Texture Packs',
                        subtitle: 'Currently: ${texturePacks.firstWhere((t) => t.id.name == AppStore.activeTexturePack, orElse: () => texturePacks.first).name}',
                        onTap: () => pushFade(context, const TexturePacksScreen()),
                      ),

                      SectionHeader('GAMEPLAY'),
                      ToggleRow(
                        title: 'Show Timer',
                        value: _showTimer,
                        onChanged: (v) => setState(() {
                          _showTimer = v;
                          AppStore.showTimer = v;
                          if (!v) {
                            _enableMs = false;
                            AppSettings.enableMs = false;
                          }
                        }),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: ToggleRow(
                          title: 'Enable Milliseconds',
                          titleSize: 15,
                          enabled: _showTimer,
                          value: _enableMs,
                          onChanged: (v) => setState(() {
                            _enableMs = v;
                            AppStore.enableMs = v;
                          }),
                        ),
                      ),
                      SegmentedRow(
                        title: 'Moves Display',
                        options: const ['DOTS', 'NUMBERS'],
                        selected: _movesDisplay,
                        onChanged: (i) => setState(() {
                          _movesDisplay = i;
                          AppStore.movesDisplay = i;
                        }),
                      ),
                      ToggleRow(
                        title: 'Haptic Vibration',
                        value: _haptic,
                        onChanged: (v) => setState(() {
                          _haptic = v;
                          AppStore.haptic = v;
                          AppSettings.haptic = v;
                        }),
                      ),

                      SectionHeader('AUDIO'),
                      SliderRow(
                        title: 'SFX',
                        value: _sfx,
                        onChanged: (v) => setState(() {
                          _sfx = v;
                          AudioService.setSfxVolume(v);
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text('Current Track',
                        style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
                      const SizedBox(height: 10),
                      TrackPlayerCard(
                        isPlaying: _isPlaying,
                        onPlayToggle: () => setState(() {
                          _isPlaying = !_isPlaying;
                          if (_isPlaying) AudioService.resumeMusic(); else AudioService.pauseMusic();
                        }),
                        volume: _trackVolume,
                        onVolumeChanged: (v) => setState(() {
                          _trackVolume = v;
                          AudioService.setMusicVolume(v);
                        }),
                      ),

                      SectionHeader('ACCOUNT & DATA'),
                      ActionPill(label: 'Restore Purchases', onTap: () {}),
                      const SizedBox(height: 10),
                      ActionPill(
                        label: 'Reset Progress',
                        textColor: const Color(0xFFE6543A),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Reset Progress?',
                                style: GoogleFonts.dmSans(fontWeight: FontWeight.w800)),
                              content: Text('This wipes all XP, completed puzzles, and rank. This cannot be undone.',
                                style: GoogleFonts.dmSans()),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true),
                                  child: Text('Reset', style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w800, color: const Color(0xFFE6543A)))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await AppStore.resetProgress();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Progress reset successfully',
                                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                                backgroundColor: const Color(0xFF2C2C2C),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ));
                            }
                          }
                        },
                      ),
                      SectionHeader('PERFORMANCE'),
                      SegmentedRow(
                        title: 'Frame Rate Cap',
                        subtitle: 'Maximum frame rate. Affects smoothness & feel',
                        options: const ['30 FPS', '60 FPS', '120 FPS'],
                        selected: _frameRate,
                        onChanged: (i) => setState(() => _frameRate = i),
                      ),
                      ToggleRow(
                        title: 'Static Backgrounds',
                        value: _staticBg,
                        onChanged: (v) => setState(() => _staticBg = v),
                      ),

                      SectionHeader('NOTIFICATIONS'),
                      ToggleRow(
                        title: 'Daily Fold Notif',
                        subtitle: 'Sends a daily reminder to do your daily Folds!',
                        value: _dailyNotif,
                        onChanged: (v) => setState(() => _dailyNotif = v),
                      ),
                      if (_dailyNotif)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Set Time',
                                style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: _notifTime,
                                  );
                                  if (picked != null) {
                                    setState(() => _notifTime = picked);
                                    AppStore.setNotifTime(picked);
                                  }
                                },
                                child: TimeDisplay(
                                  hour: _notifTime.hour.toString().padLeft(2, '0'),
                                  minute: _notifTime.minute.toString().padLeft(2, '0'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ToggleRow(
                        title: 'New Packs Notif',
                        subtitle: 'Notifies you if any new packs come out!',
                        value: _newPacksNotif,
                        onChanged: (v) => setState(() => _newPacksNotif = v),
                      ),

                      SectionHeader('ADVANCED INPUT'),
                      SegmentedRow(
                        title: 'Handed Mode',
                        subtitle: 'Flips orientation for landscape puzzles',
                        options: const ['RIGHT', 'LEFT'],
                        selected: _handedMode,
                        onChanged: (i) => setState(() => _handedMode = i),
                      ),

                      SectionHeader('PRIVACY & SECURITY'),
                      ToggleRow(
                        title: 'Opt Out of Data Usage',
                        subtitle: 'Disables using your data for personal & general enhancement',
                        value: _optOutData,
                        onChanged: (v) => setState(() => _optOutData = v),
                      ),
                      OpenRow(title: 'ToS and Privacy Policy', onTap: () => launchCustomUrl('https://jaydev.games/privacy')),

                      SectionHeader(_t('ABOUT & VERSIONING')),
                      OpenRow(
                        title: 'Moderator Access',
                        subtitle: 'Exclusive content for trusted members',
                        onTap: () => pushFade(context, const ModeratorPanelScreen()),
                      ),
                      ActionPill(label: 'Report a Bug 🐛', onTap: () => _showBugReport(context)),
                      const SizedBox(height: 10),
                      ActionPill(
                        label: 'View Tutorial Again',
                        onTap: () {
                          AppStore.hasSeenOnboarding = false;
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => const OnboardingScreen(),
                              transitionsBuilder: (_, animation, __, child) =>
                                  FadeTransition(opacity: animation, child: child),
                              transitionDuration: const Duration(milliseconds: 400),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      ToggleRow(
                        title: _t('Just Dont...'),
                        subtitle: _t('Please dont toggle this on.'),
                        value: _justDont,
                        onChanged: (v) => setState(() => _justDont = v),
                      ),
                      OpenRow(title: _t('Credits'), onTap: () => pushFade(context, const CreditsScreen())),
                      OpenRow(title: _t('Folds Website'), onTap: () => launchCustomUrl('https://folds.jaydev.games')),
                      OpenRow(title: _t('Socials & YouTube'), onTap: () => launchCustomUrl('https://www.youtube.com/@JayDevGames1')),
                      const SizedBox(height: 16),
                      ActionPill(
                        label: 'Reset All Settings',
                        textColor: const Color(0xFFE6543A),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Reset All Settings?',
                                style: GoogleFonts.dmSans(fontWeight: FontWeight.w800)),
                              content: Text('All settings will return to their defaults. This cannot be undone.',
                                style: GoogleFonts.dmSans()),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true),
                                  child: Text('Reset', style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w800, color: const Color(0xFFE6543A)))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await AppStore.resetSettings();
                            setState(() {
                              _showTimer = true;
                              _enableMs = false;
                              _movesDisplay = 0;
                              _notifTime = const TimeOfDay(hour: 8, minute: 0);
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Settings reset to defaults',
                                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                                backgroundColor: const Color(0xFF2C2C2C),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ));
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            _versionTapCount++;
                            debugPrint('VERSION TAP: $_versionTapCount');
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              duration: const Duration(milliseconds: 400),
                              content: Text('Tap $_versionTapCount / 7'),
                            ));
                            if (_versionTapCount >= 7) {
                              // _versionTapCount = 0;
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const DevPanelScreen()));
                            }
                          },
                          child: Container(
                            color: Colors.transparent, // ensures the whole area is tappable, not just glyph pixels
                            padding: const EdgeInsets.all(12),
                            child: Text('version 1.0.0',
                              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text('Made with ❤️ by JayDev Games',
                          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54)),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '"If you have a dream, just go for it. Even though you\'ll never know where you\'ll end up, and even though you never know how exactly you\'ll get there; The real journey is not how you get there, but what you acheive and learn before you do."',
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text('–JayDev',
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
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

