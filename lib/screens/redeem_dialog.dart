import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/models/texture_pack_def.dart';

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

Future<void> _processRedeemCode(BuildContext context, String code) async {
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
      .maybeSingle(); // literally me
    
    if (Navigator.canPop(context)) Navigator.pop(context);

    if (response == null) {
      _showRedeemFeedback(context, false, 'That\'s not a valid code! Try verifying the code from your source, or see if it exists.');
      return;
    }

    final bool isOneTime = response['is_one_time_use'] ?? false;
    final bool isClaimed = response['is_claimed'] ?? false;
    final String rewardType = response['reward_type'] ?? '';
    final String rewardValue = response['reward_value'] ?? '';

    if (isOneTime && isClaimed) {
      _showRedeemFeedback(context, false, 'This code is a one-time use, and has already been claimed.');
      return;
    }

    if (isOneTime) {
      await Supabase.instance.client
        .from('promo_codes')
        .update({'is_claimed': true})
        .eq('code', code);
    }

    String successMessage = 'Reward successfully redeemed!';
    if (rewardType == 'texture') {
      AppStore.unlockTexturePack(rewardValue);
      final def = texturePacks.firstWhere((t) => t.id.name == rewardValue, orElse: () => texturePacks.first);
      successMessage = '"${def.name}" texture pack unlocked! Equip it in Settings -> Texture Packs.';
     } else if (rewardType == 'skin') {
      successMessage = '💎 ${rewardValue.toUpperCase()} grid style skin unlocked!';
    } else if (rewardType == 'pack') {
      successMessage = '📦 Special level bundle "$rewardValue" unlocked!';
    } else if (rewardType == 'xp') {
      final int xpAmount = int.tryParse(rewardValue) ?? 0;
      await Supabase.instance.client.rpc('admin_add_xp',
        params: {'target_username': AppStore.displayUsername, 'amount': xpAmount});
      await AppStore.downloadCloudProfile();
      successMessage = '🎉 $xpAmount XP successfully credited to your profile!';
    }

    _showRedeemFeedback(context, true, successMessage);
  } catch (e) {
    if (Navigator.canPop(context)) Navigator.pop(context);
    _showRedeemFeedback(context, false, '⚠️ Network/Server error. Check connection.');
    debugPrint("Redeem failure: $e");
  }
}

void _showRedeemFeedback(BuildContext context, bool success, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: success ? const Color(0xFF2c2c2c) : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      content: Text(
        message,
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
      ),
    ),
  );
}