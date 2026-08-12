// ===== FILE: lib/screens/settings/dev/dev_notifications_screen.dart =====
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/widgets/recipient_picker.dart';
import 'dev_widgets.dart';

class DevNotificationsScreen extends StatefulWidget {
  const DevNotificationsScreen({super.key});
  @override
  State<DevNotificationsScreen> createState() => DevNotificationsScreenState();
}

class DevNotificationsScreenState extends State<DevNotificationsScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _recipient = 'all';
  String? _background;
  static const _bgOptions = {'Default': Color(0xFFEFEFEF), 'Gold': Color(0xFFFFD465),
    'Green': Color(0xFF7BD957), 'Blue': Color(0xFF5865F2), 'Red': Color(0xFFE6543A)};

  @override
  Widget build(BuildContext context) {
    return DevSectionScaffold(
      title: 'Notifications', accent: const Color(0xFFFFD465), icon: Icons.campaign_rounded,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _titleCtrl, decoration: InputDecoration(hintText: 'Title',
            filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 10),
          TextField(controller: _bodyCtrl, maxLines: 3, decoration: InputDecoration(hintText: 'Message',
            filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 14),
          Text('RECIPIENT', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 6),
          RecipientPicker(initial: 'all', onSelected: (v) => _recipient = v),
          const SizedBox(height: 14),
          Text('BACKGROUND', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _bgOptions.entries.map((e) {
            final selected = _background == e.key || (_background == null && e.key == 'Default');
            return GestureDetector(
              onTap: () => setState(() => _background = e.key == 'Default' ? null : e.key),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: e.value, borderRadius: BorderRadius.circular(10),
                  border: selected ? Border.all(color: Colors.black, width: 2) : null),
                child: Text(e.key, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700))),
            );
          }).toList()),
          const SizedBox(height: 16),
          DevPrimaryButton(label: 'SEND', color: const Color(0xFF2C2C2C), icon: Icons.send_rounded, onTap: () async {
            if (_titleCtrl.text.trim().isEmpty) { devToast(context, 'Enter a title', error: true); return; }
            if (!await isValidRecipient(_recipient)) { devToast(context, 'No profile found for "$_recipient"', error: true); return; }
            try {
              await Supabase.instance.client.from('notifications').insert({
                'title': _titleCtrl.text.trim(), 'body': _bodyCtrl.text.trim(),
                'recipient': _recipient, 'author': AppStore.displayUsername,
                'background': _background, 'created_at': DateTime.now().toIso8601String(),
              });
              devToast(context, 'Notification sent to $_recipient');
              _titleCtrl.clear(); _bodyCtrl.clear();
            } catch (e) { devToast(context, '$e', error: true); }
          }),
        ])),
      ]),
    );
  }
}