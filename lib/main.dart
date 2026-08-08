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
