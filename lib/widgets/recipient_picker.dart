import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/state/app_store.dart';


class RecipientPicker extends StatefulWidget {
  final ValueChanged<String> onSelected;
  final String initial;
  const RecipientPicker({required this.onSelected, this.initial = 'all'});
  @override
  State<RecipientPicker> createState() => RecipientPickerState();
}

class RecipientPickerState extends State<RecipientPicker> {
  late TextEditingController _ctrl;
  List<String> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  void _onChanged(String query) {
    widget.onSelected(query.trim().isEmpty ? 'all' : query.trim());
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('username')
            .ilike('username', '%${query.trim()}%')
            .limit(6);
        final names = List<Map<String, dynamic>>.from(data)
            .map((e) => e['username'].toString()).toList();
        final options = <String>['all', '@Moderators', ...names]
            .where((n) => n.toLowerCase().contains(query.trim().toLowerCase()))
            .toList();
        if (mounted) setState(() => _suggestions = options);
      } catch (_) {}
    });
  }

  @override
  void dispose() { _debounce?.cancel(); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _ctrl,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: '"all", "@Moderators" or a username',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      if (_suggestions.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: _suggestions.map((s) => ListTile(
              dense: true,
              title: Text(s, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              onTap: () {
                _ctrl.text = s;
                widget.onSelected(s);
                setState(() => _suggestions = []);
                FocusScope.of(context).unfocus();
              },
            )).toList(),
          ),
        ),
    ]);
  }
}

/// Confirms a typed recipient actually exists before you're allowed to send.
Future<bool> isValidRecipient(String recipient) async {
  if (recipient == 'all' || recipient == '@Moderators') return true;
  final available = await AppStore.isUsernameAvailable(recipient);
  return !available; // "available" username == nobody has it == invalid
}
