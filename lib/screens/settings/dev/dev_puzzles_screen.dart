// ===== FILE: lib/screens/settings/dev/dev_puzzles_screen.dart =====
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/models/xp_system.dart';
import 'package:folds/models/texture_pack_def.dart';
import 'package:folds/screens/gameplay_screen.dart';
import 'dev_widgets.dart';

class DevPuzzlesScreen extends StatefulWidget {
  const DevPuzzlesScreen({super.key});
  @override
  State<DevPuzzlesScreen> createState() => DevPuzzlesScreenState();
}

class DevPuzzlesScreenState extends State<DevPuzzlesScreen> {
  final _xpCtrl = TextEditingController();
  final _idCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DevSectionScaffold(
      title: 'Puzzles', accent: const Color(0xFF5865F2), icon: Icons.extension_rounded,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('YOUR XP', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('${AppStore.totalXP} XP · Rank ${XPSystem.rankFromXP(AppStore.totalXP)}',
            style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _xpCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'Amount', filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
            const SizedBox(width: 10),
            DevPrimaryButton(label: 'ADD', color: const Color(0xFF5865F2), onTap: () async {
              final amt = int.tryParse(_xpCtrl.text) ?? 0;
              try {
                await Supabase.instance.client.rpc('admin_add_xp',
                  params: {'target_username': AppStore.displayUsername, 'amount': amt});
                await AppStore.downloadCloudProfile();
                _xpCtrl.clear();
                setState(() {});
                if (mounted) devToast(context, 'Added $amt XP · total ${AppStore.totalXP}');
              } catch (e) { if (mounted) devToast(context, '$e', error: true); }
            }),
          ]),
        ])),
        DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SPECIFIC PUZZLE', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 10),
          TextField(controller: _idCtrl, decoration: InputDecoration(
            hintText: 'e.g. p1, r5, d3, x12', filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DevChipBtn(label: '✓ Mark Complete', onTap: () {
              final id = _idCtrl.text.trim().toLowerCase();
              if (id.isEmpty) { devToast(context, 'Enter a puzzle ID first', error: true); return; }
              AppStore.markCompleted(id); AppStore.markParCompleted(id);
              devToast(context, '$id marked complete');
            })),
            const SizedBox(width: 8),
            Expanded(child: DevChipBtn(label: 'Open', color: const Color(0xFF2C2C2C), onTap: () {
              final id = _idCtrl.text.trim().toLowerCase();
              if (id.isEmpty) { devToast(context, 'Enter a puzzle ID first', error: true); return; }
              Navigator.push(context, MaterialPageRoute(builder: (_) => GameplayScreen(initialPuzzleId: id)));
            })),
          ]),
        ])),
        DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('FULL PACK COMPLETE', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            DevChipBtn(label: 'All Pilot ✓', onTap: () {
              for (int i = 1; i <= 100; i++) { AppStore.markCompleted('p$i'); AppStore.markParCompleted('p$i'); }
              devToast(context, 'Pilot pack completed');
            }),
            DevChipBtn(label: 'All Rectangle ✓', onTap: () {
              for (int i = 1; i <= 100; i++) { AppStore.markCompleted('r$i'); AppStore.markParCompleted('r$i'); }
              devToast(context, 'Rectangle pack completed');
            }),
            DevChipBtn(label: 'All Holiday ✓', onTap: () {
              for (int i = 1; i <= 25; i++) { AppStore.markCompleted('x$i'); AppStore.markParCompleted('x$i'); }
              devToast(context, 'Holiday pack completed');
            }),
          ]),
        ])),
        DevCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TEXTURE PACKS', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: texturePacks.where((t) => !t.isDefault).map((t) =>
            DevChipBtn(label: 'Unlock ${t.name}', onTap: () {
              AppStore.unlockTexturePack(t.id.name);
              devToast(context, '${t.name} unlocked');
            })).toList()),
        ])),
      ]),
    );
  }
}