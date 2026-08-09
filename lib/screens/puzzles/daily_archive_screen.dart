import 'package:flutter/material.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:folds/screens/gameplay_screen.dart';
import 'package:folds/widgets/shared/buttons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class DailyArchiveScreen extends StatefulWidget {
  const DailyArchiveScreen({super.key});
  @override
  State<DailyArchiveScreen> createState() => DailyArchiveScreenState();
}

class DailyArchiveScreenState extends State<DailyArchiveScreen> {
  List<Map<String, dynamic>> _dailies = [];
  bool _loading = true;
  int _filterDifficulty = 0; // 0 = all
  int _filterStatus = 0; // 0=all, 1=completed, 2=incomplete

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await Supabase.instance.client
          .from('puzzles')
          .select('id, title, difficulty')
          .ilike('id', 'd%')
          .order('created_at', ascending: false)
          .limit(200);
      setState(() {
        _dailies = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _dailies.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  FoldsTopBar(title: 'DAILY PUZZLES', onBack: () => Navigator.pop(context)),
                  const SizedBox(height: 16),
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Center(
                            child: Text(
                              '${AppStore.dailiesCompleted} / $total',
                              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black54),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Difficulty filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      CustomFilterChip(label: 'All', active: _filterDifficulty == 0,
                        onTap: () => setState(() => _filterDifficulty = 0)),
                      const SizedBox(width: 6),
                      ...List.generate(5, (i) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: CustomFilterChip(
                          label: '${'★' * (i + 1)}',
                          active: _filterDifficulty == i + 1,
                          onTap: () => setState(() => _filterDifficulty = _filterDifficulty == i+1 ? 0 : i+1)),
                      )),
                      CustomFilterChip(label: '✓ Done', active: _filterStatus == 1,
                        onTap: () => setState(() => _filterStatus = _filterStatus == 1 ? 0 : 1)),
                      const SizedBox(width: 6),
                      CustomFilterChip(label: '○ Todo', active: _filterStatus == 2,
                        onTap: () => setState(() => _filterStatus = _filterStatus == 2 ? 0 : 2)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF2C2C2C), strokeWidth: 3)))
            else if (_dailies.isEmpty)
              Expanded(
                child: Center(
                  child: Text('No daily puzzles found',
                    style: GoogleFonts.dmSans(fontSize: 16, color: Colors.black38)),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: (() {
                      return _dailies.where((p) {
                        final id = p['id'].toString();
                        final diff = (p['difficulty'] as int?) ?? 1;
                        final done = AppStore.isCompleted(id);
                        if (_filterDifficulty > 0 && diff != _filterDifficulty) return false;
                        if (_filterStatus == 1 && !done) return false;
                        if (_filterStatus == 2 && done) return false;
                        return true;
                      }).length;
                    })(),
                    itemBuilder: (context, i) {
                      final filtered = _dailies.where((p) {
                        final id = p['id'].toString();
                        final diff = (p['difficulty'] as int?) ?? 1;
                        final done = AppStore.isCompleted(id);
                        if (_filterDifficulty > 0 && diff != _filterDifficulty) return false;
                        if (_filterStatus == 1 && !done) return false;
                        if (_filterStatus == 2 && done) return false;
                        return true;
                      }).toList();
                      final puzzle = filtered[i];
                      final id = puzzle['id'].toString();
                      final title = puzzle['title']?.toString() ?? '';
                      final num = id.replaceAll(RegExp(r'^[a-z]+'), '');
                      final difficulty = (puzzle['difficulty'] as int?) ?? 1;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => GameplayScreen(initialPuzzleId: id),
                              transitionsBuilder: (_, animation, __, child) {
                                final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                                return SlideTransition(position: slide, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 320),
                            ),
                            (route) => false,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('#$num',
                                    style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                                  Row(
                                    children: List.generate(difficulty, (_) =>
                                      const Icon(Icons.star_rounded, color: Color(0xFFFFD465), size: 10)),
                                  ),
                                ],
                              ),
                              Text(title,
                                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                                  if (AppStore.isCompleted(id))
                                    Icon(
                                      Icons.check_rounded,
                                      color: AppStore.isParCompleted(id)
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFFFD465),
                                      size: 18,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: CustomBackButton(label: 'BACK TO MORE PUZZLES', onTap: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }
}

