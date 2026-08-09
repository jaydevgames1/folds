import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/screens/moderation/moderator_notify_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:folds/screens/puzzles/puzzle_selector_screen.dart';
import 'package:folds/screens/profile/auth_screen.dart';

class ModeratorPanelScreen extends StatefulWidget {
  const ModeratorPanelScreen({super.key});
  @override
  State<ModeratorPanelScreen> createState() => ModeratorPanelScreenState();
}

class ModeratorPanelScreenState extends State<ModeratorPanelScreen> {
  bool _requesting = false;
  String? requestStatus; // null, 'approved', 'pending', 'error'
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
          requestStatus = 'approved';
        });
        _showResult('approved');
      } else {
        setState(() => requestStatus = 'pending');
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

