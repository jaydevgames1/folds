import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/widgets/recipient_picker.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ModeratorNotifyScreen extends StatefulWidget {
  const ModeratorNotifyScreen({super.key});
  @override
  State<ModeratorNotifyScreen> createState() => ModeratorNotifyScreenState();
}

class ModeratorNotifyScreenState extends State<ModeratorNotifyScreen> {
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
