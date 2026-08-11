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

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);
    try {
      final anon = AppStore.currentUser;
      final wasAnonymous = anon != null && anon.isAnonymous;

      if (_isSignUp) {
        if (_usernameController.text.trim().isEmpty) {
          throw Exception('Please choose a username.');
        }
        final available = await AppStore.isUsernameAvailable(_usernameController.text.trim());
        if (!available) {
          throw Exception('That username is already taken. Please choose another.');
        }

        if (wasAnonymous && _keepProgress) {
          // Upgrade the existing anonymous user in place — same id, same
          // profile row, same XP. Nothing to re-download or restart.
          await Supabase.instance.client.auth.updateUser(UserAttributes(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            data: {'username': _usernameController.text.trim()},
          ));
          final uid = anon.id;
          final d = DateTime.now();
          const months = ['','JANUARY','FEBRUARY','MARCH','APRIL','MAY','JUNE',
              'JULY','AUGUST','SEPTEMBER','OCTOBER','NOVEMBER','DECEMBER'];
          final joinStr = 'JOINED ${d.day} ${months[d.month]} ${d.year}';
          await Supabase.instance.client.from('profiles').update({
            'username': _usernameController.text.trim(),
            'join_date': joinStr,
          }).eq('id', uid);
        } else {
          // Fresh account, "Create Account & Sign In" in one step.
          await Supabase.instance.client.auth.signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            data: {'username': _usernameController.text.trim()},
          );
          try {
            await Supabase.instance.client.auth.signInWithPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
            final uid = Supabase.instance.client.auth.currentUser?.id;
            if (uid != null) {
              final d = DateTime.now();
              const months = ['','JANUARY','FEBRUARY','MARCH','APRIL','MAY','JUNE',
                  'JULY','AUGUST','SEPTEMBER','OCTOBER','NOVEMBER','DECEMBER'];
              final joinStr = 'JOINED ${d.day} ${months[d.month]} ${d.year}';
              await Supabase.instance.client.from('profiles').update({
                'join_date': joinStr,
                'username': _usernameController.text.trim(),
              }).eq('id', uid);
            }
          } catch (_) {
            // Email confirmation required — account exists, they'll verify first.
          }
        }
        await AppStore.downloadCloudProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Welcome to the Fold! You\'re signed in.')));
          Navigator.pop(context, true);
        }
      // _authenticate()'s sign-in (else) branch — replace entirely with:
} else {
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
    await AppStore.wipeLocalProfileData();

    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: _passwordController.text,
    );
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
    // The old AuthScreen context is gone by now, so we can't snackbar on it —
    // bounce to a fresh AuthScreen that shows the error instead of hanging.
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