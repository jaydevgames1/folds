import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSearchField extends StatefulWidget {
  final ValueChanged<String> onSelected;
  final String hint;
  const ProfileSearchField({super.key, required this.onSelected, this.hint = 'Search by username...'});
  @override
  State<ProfileSearchField> createState() => ProfileSearchFieldState();
}

class ProfileSearchFieldState extends State<ProfileSearchField> {
  final _ctrl = TextEditingController();
  List<String> _suggestions = [];
  Timer? _debounce;

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) { setState(() => _suggestions = []); return; }
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      try {
        final data = await Supabase.instance.client
          .from('profiles').select('username')
          .ilike('username', '%{q.trim()}%').limit(8);
        if (mounted) {
          setState(() => _suggestions = 
            List<Map<String, dynamic>>.from(data).map((e) => e['username'].toString()).toList());
        }
      } catch (_) {}
    });
  }

  void _pick(String u) {
    _ctrl.text = u;
    setState(() => _suggestions = []);
    FocusScope.of(context).unfocus();
    widget.onSelected(u);
  }

  @override
  void dispose() { _debounce?.cancel(); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _ctrl,
        onChanged: _onChanged,
        onSubmitted: (v) { if (v.trim().isNotEmpty) _pick(v.trim()); },
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.black38),
          filled: true, fillColor: const Color (0xFFF5F5F5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      if (_suggestions.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)),
          child: Column(children: _suggestions.map((s) => ListTile(
            dense: true,
            leading: const Icon(Icons.person_rounded, size: 18, color: Colors.black38),
            title: Text(s, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
            onTap: () => _pick(s),
          )).toList()),
        ),
    ]);
  }
}