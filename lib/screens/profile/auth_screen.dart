import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/painters/icon_painters.dart';
import 'package:folds/widgets/shared/folds_dialog.dart';
import 'package:folds/screens/gameplay_screen.dart';

class AuthScreen extends StatefulWidget {
  final String? errorMessage;
  const AuthScreen({super.key, this.errorMessage});
  @override
  State<AuthScreen> createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.errorMessage!)));
        }
      });
    }
  }
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _keepProgress = true;

  bool get _wasAnonymous {
    final u = AppStore.currentUser;
    return u != null && u.isAnonymous;
  }

  // auth_screen.dart — replace the whole _isSignUp branch of _authenticate()

Future<void> _authenticate() async {
  setState(() => _isLoading = true);
  try {
    final anon = AppStore.currentUser;
    final wasAnonymous = anon != null && anon.isAnonymous;

    if (_isSignUp) {
      if (_usernameController.text.trim().isEmpty) {
        throw Exception('Please choose a username.');
      }
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();

      final available = await AppStore.isUsernameAvailable(username);
      if (!available) {
        throw Exception('That username is already taken. Please choose another.');
      }

      const months = ['','JANUARY','FEBRUARY','MARCH','APRIL','MAY','JUNE',
          'JULY','AUGUST','SEPTEMBER','OCTOBER','NOVEMBER','DECEMBER'];
      final d = DateTime.now();
      final joinStr = 'JOINED ${d.day} ${months[d.month]} ${d.year}';

      if (wasAnonymous && _keepProgress) {
        // Upgrade the existing anonymous account in place.
        final userResp = await Supabase.instance.client.auth.updateUser(UserAttributes(
          email: email,
          password: _passwordController.text,
          data: {'username': username},
        ));

        await Supabase.instance.client.from('profiles').update({
          'username': username,
          'join_date': joinStr,
        }).eq('id', anon.id);

        // If Supabase queued a confirmation for the new email, the account
        // isn't fully "theirs" yet — say so instead of claiming success.
        final needsConfirmation = userResp.user?.emailConfirmedAt == null;
        await AppStore.downloadCloudProfile();

        if (!mounted) return;
        if (needsConfirmation) {
          _showCheckEmailDialog(email);
        } else {
          Navigator.pop(context, true);
        }
        setState(() => _isLoading = false);
        return;
      }

      // Fresh account.
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _passwordController.text,
        data: {'username': username},
      );

      if (response.session == null) {
        // No session back = email confirmation is required. Nothing is
        // signed in yet — tell the user clearly instead of pretending.
        if (!mounted) return;
        _showCheckEmailDialog(email);
        setState(() => _isLoading = false);
        return;
      }

      // Confirmations are off for this project — we're actually signed in.
      final uid = response.user!.id;
      await Supabase.instance.client.from('profiles').update({
        'username': username,
        'join_date': joinStr,
      }).eq('id', uid);
      await AppStore.wipeLocalProfileData();
      await AppStore.downloadCloudProfile();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const GameplayScreen(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 350),
        ),
        (route) => false,
      );
      return;
    } else {
      // ── Sign-in branch stays exactly as you have it — it was already correct. ──
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final input = _emailController.text.trim();
      try {
        final email = input.contains('@') ? input : await AppStore.resolveUsernameToEmail(input);
        rootNavigator.pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthTransitionScreen(message: 'Signing In...'),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 200),
          ),
          (route) => false,
        );
        try { await Supabase.instance.client.auth.signOut(); } catch (_) {}
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: _passwordController.text);
        await AppStore.wipeLocalProfileData();
        await AppStore.downloadCloudProfile();
        rootNavigator.pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const GameplayScreen(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 350),
          ),
          (route) => false,
        );
      } catch (e) {
        rootNavigator.pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => AuthScreen(errorMessage: e.toString()),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 200),
          ),
          (route) => false,
        );
      }
      return;
    }
  } catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }
  if (mounted) setState(() => _isLoading = false);
}

void _showCheckEmailDialog(String email) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Text('Check Your Email', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 20)),
      content: Text(
        'We sent a confirmation link to $email. Tap it to finish setting up your account — '
        'your progress is safe and will be waiting when you come back.',
        style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54)),
      actions: [
        TextButton(
          onPressed: () async {
            try {
              await Supabase.instance.client.auth.resend(type: OtpType.signup, email: email);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Confirmation email resent.')));
              }
            } catch (_) {}
          },
          child: Text('Resend Email', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.black45)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            Navigator.pop(ctx);   // close dialog
            Navigator.pop(context); // back out of AuthScreen — nothing to refresh, they're still a guest
          },
          child: Text('Got It', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ],
    ),
  );
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
              Center(
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  child: ClipOval(child: CustomPaint(painter: HomeIconPainter())),
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
                decoration: InputDecoration(
                  labelText: _isSignUp ? 'Email' : 'Email or Username',
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

              if (_isSignUp && _wasAnonymous) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() => _keepProgress = !_keepProgress),
                  child: Row(children: [
                    Checkbox(
                      value: _keepProgress,
                      activeColor: const Color(0xFF2C2C2C),
                      onChanged: (v) => setState(() => _keepProgress = v ?? true),
                    ),
                    Expanded(
                      child: Text('Keep my current progress (XP, streak, completed puzzles)',
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 24),

              GestureDetector(
                onTap: _isLoading ? null : _authenticate,
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_isSignUp ? 'CREATE ACCOUNT & SIGN IN' : 'SIGN IN', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
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