import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/screens/gameplay_screen.dart';

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

