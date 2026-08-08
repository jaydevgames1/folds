import 'package:flutter/material.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:google_fonts/google_fonts.dart';




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
