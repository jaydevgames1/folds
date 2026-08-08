import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/xp_system.dart';
import 'models/texture_pack_def.dart';
import 'state/app_store.dart';
import 'services/audio_service.dart';
import 'widgets/shared/folds_top_bar.dart';
import 'widgets/recipient_picker.dart';
import 'widgets/badge_info_dialog.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/gameplay_screen.dart';
import 'screens/puzzles/puzzle_selector_screen.dart';
import 'screens/profile/public_profile_sheet.dart';
import 'screens/profile/auth_screen.dart';

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
