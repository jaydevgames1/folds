import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});
  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  List<Map<String, dynamic>> _receipts = [];
  bool _loading = true;
  final Set<int> _expanded = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final username = AppStore.displayUsername;
      final isMod = AppStore.isModerator;
      final filters = ['recipient.eq.all', 'recipient.eq.$username'];
      if (isMod) filters.add('recipient.eq.@Moderators');
      final data = await Supabase.instance.client
          .from('notifications')
          .select()
          .or(filters.join(','))
          .order('created_at', ascending: false)
          .limit(100);
      setState(() { _receipts = List<Map<String, dynamic>>.from(data); _loading = false; });
      await AppStore.markReceiptsSeen();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Color _bgColor(String? key) {
    const map = {
      'Gold': Color(0xFFFFD465), 'Green': Color(0xFF7BD957),
      'Blue': Color(0xFF5865F2), 'Red': Color(0xFFE6543A),
    };
    return map[key] ?? const Color(0xFFEFEFEF);
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(dateOnly).inDays;
    if (diff == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff > 0 && diff < 7) {
      const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      return days[dt.weekday - 1];
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _resolveRecipientLabel(String recipient) {
    if (recipient == 'all') return 'Everyone';
    if (recipient == '@Moderators') return 'Moderators';
    return 'You specifically';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(children: [
            FoldsTopBar(title: 'RECEIPTS', onBack: () => Navigator.pop(context)),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2C2C2C)))
                  : _receipts.isEmpty
                      ? Center(child: Text('No notifications yet',
                          style: GoogleFonts.dmSans(fontSize: 15, color: Colors.black38)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _receipts.length,
                            itemBuilder: (context, i) {
                              final r = _receipts[i];
                              final isExpanded = _expanded.contains(i);
                              DateTime? created;
                              try { created = DateTime.parse(r['created_at'].toString()); } catch (_) {}
                              final bg = _bgColor(r['background'] as String?);
                              final isColored = r['background'] != null;
                              return GestureDetector(
                                onTap: () => setState(() =>
                                  isExpanded ? _expanded.remove(i) : _expanded.add(i)),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      Expanded(child: Text(r['title']?.toString() ?? '',
                                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87))),
                                      if (created != null)
                                        Text(_formatDate(created), style: GoogleFonts.dmSans(
                                          fontSize: 11, fontWeight: FontWeight.w700,
                                          color: isColored ? Colors.black54 : Colors.black38)),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(r['body']?.toString() ?? '',
                                      maxLines: isExpanded ? null : 2,
                                      overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black54)),
                                    if (isExpanded) ...[
                                      const SizedBox(height: 10),
                                      Row(children: [
                                        const Icon(Icons.person_rounded, size: 14, color: Colors.black38),
                                        const SizedBox(width: 4),
                                        Text('From: ${r['author']?.toString() ?? 'Folds Team'}',
                                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
                                      ]),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        const Icon(Icons.group_rounded, size: 14, color: Colors.black38),
                                        const SizedBox(width: 4),
                                        Text('To: ${_resolveRecipientLabel(r['recipient']?.toString() ?? 'all')}',
                                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
                                      ]),
                                    ],
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}

