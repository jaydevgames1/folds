import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/core/constants.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/models/xp_system.dart';
import 'package:folds/screens/gameplay_screen.dart';
import 'package:folds/widgets/shared/buttons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folds/widgets/recipient_picker.dart';
import 'package:folds/models/texture_pack_def.dart';


class DevPanelScreen extends StatefulWidget {
  const DevPanelScreen({super.key});
  @override
  State<DevPanelScreen> createState() => DevPanelScreenState();
}

// AFTER
// AFTER
class DevPanelScreenState extends State<DevPanelScreen> {
  bool _checking = true;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final result = await Supabase.instance.client.rpc('is_dev_user');
      final granted = result == true;
      AppStore.isDevProfile = granted; // mirrors the server's verdict locally
      if (mounted) setState(() { _unlocked = granted; _checking = false; });
    } catch (e) {
      if (mounted) setState(() { _unlocked = false; _checking = false; });
    }
  }

  void _confirm(String message, {bool error = false}) { /* unchanged */ }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2C2C2C))),
      );
    }
    if (!_unlocked) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, size: 48, color: Color(0xFF2C2C2C)),
                const SizedBox(height: 16),
                Text('Developer access is restricted',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Only the JayDev account can open this panel.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black45)),
                const SizedBox(height: 20),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
              ],
            ),
          ),
        ),
      );
    }
    // ... rest of the panel (tabs) unchanged
    // ... rest of the panel (tabs) unchanged

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2C2C2C),
          title: Text('DEVELOPER PANEL', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.white)),
          leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: const Color(0xFFFFD465),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: const [
              Tab(text: 'XP & PUZZLES'), Tab(text: 'PACKS'), Tab(text: 'STREAKS'),
              Tab(text: 'MODERATORS'), Tab(text: 'NOTIFICATIONS'), Tab(text: 'NUCLEAR'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _buildXpTab(), _buildPacksTab(), _buildStreaksTab(),
          _buildModTab(), _buildNotifTab(), _buildNuclearTab(),
        ]),
      ),
    );
  }

  Widget _buildXpTab() {
    final xpCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DevLabel('XP — Current: ${AppStore.totalXP} (Rank ${XPSystem.rankFromXP(AppStore.totalXP)})'),
        Row(children: [
          Expanded(child: TextField(controller: xpCtrl, keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'XP to add', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C)),
            onPressed: () async {
              final amt = int.tryParse(xpCtrl.text) ?? 0;
              try {
                await Supabase.instance.client.rpc('admin_add_xp',
                  params: {'target_username': AppStore.displayUsername, 'amount': amt});
                await AppStore.downloadCloudProfile();
                xpCtrl.clear();
                if (mounted) setState(() {});
                _confirm('Added $amt XP, total ${AppStore.totalXP}');
              } catch (e) {
                _confirm('$e', error:true);
              }
},
            child: Text('Add', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ]),
        DevLabel('SPECIFIC PUZZLE'),
        TextField(controller: idCtrl, decoration: InputDecoration(
          hintText: 'e.g. p1, r5, d3, x12', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          DevChip(label: 'Complete ✓', onTap: () {
            final id = idCtrl.text.trim().toLowerCase();
            if (id.isEmpty) { _confirm('Enter a puzzle ID first', error: true); return; }
            AppStore.markCompleted(id); AppStore.markParCompleted(id);
            _confirm('$id marked complete');
          }),
          DevChip(label: 'Open Puzzle', onTap: () {
            final id = idCtrl.text.trim().toLowerCase();
            if (id.isEmpty) { _confirm('Enter a puzzle ID first', error: true); return; }
            Navigator.push(context, MaterialPageRoute(builder: (_) => GameplayScreen(initialPuzzleId: id)));
          }),
        ]),
      ]),
    );
  }

  Widget _buildPacksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          DevChip(label: 'All Pilot ✓', onTap: () {
            for (int i = 1; i <= 100; i++) { AppStore.markCompleted('p$i'); AppStore.markParCompleted('p$i'); }
            _confirm('Pilot pack completed');
          }),
          DevChip(label: 'All Rectangle ✓', onTap: () {
            for (int i = 1; i <= 100; i++) { AppStore.markCompleted('r$i'); AppStore.markParCompleted('r$i'); }
            _confirm('Rectangle pack completed');
          }),
          DevChip(label: 'All Holiday ✓', onTap: () {
            for (int i = 1; i <= 25; i++) { AppStore.markCompleted('x$i'); AppStore.markParCompleted('x$i'); }
            _confirm('Holiday pack completed');
          }),
        ]),
        DevLabel('TEXTURE PACKS'),
        Wrap(spacing: 8, runSpacing: 8, children: texturePacks.where((t) => !t.isDefault).map((t) =>
          DevChip(label: 'Unlock ${t.name}', onTap: () {
            AppStore.unlockTexturePack(t.id.name);
            _confirm('${t.name} unlocked');
          })).toList()),
      ]),
    );
  }

  Widget _buildStreaksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        DevChip(label: '🔥 Set 7', onTap: () { AppStore.devSetStreak(7); _confirm('Streak set to 7'); }),
        DevChip(label: '🔥 Set 30', onTap: () { AppStore.devSetStreak(30); _confirm('Streak set to 30'); }),
        DevChip(label: 'Reset Streak', onTap: () { AppStore.devResetStreak(); _confirm('Streak reset'); }),
        DevChip(label: 'Mark Daily Done', onTap: () {
          final dayNumber = foldsDayNumberFor(DateTime.now());
          if (dayNumber > 0) {
            AppStore.markCompleted('d$dayNumber');
            AppStore.updateStreak();
            _confirm('Day $dayNumber marked done, streak updated');
          } else {
            _confirm('Folds hasn\'t launched yet (day $dayNumber)', error: true);
          }
        }),
      ]),
    );
  }

  Widget _buildModTab() {
    final modCtrl = TextEditingController();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: modCtrl, decoration: InputDecoration(
          hintText: 'Username', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          DevChip(label: '✓ Approve Mod', onTap: () async {
            final u = modCtrl.text.trim();
            if (u.isEmpty) { _confirm('Enter a username', error: true); return; }
            try {
              await Supabase.instance.client.rpc('approve_moderator', params: {'target_username': u});
              _confirm('$u approved as moderator');
            } catch (e) { _confirm('$e', error: true); }
          }),
          DevChip(label: '✕ Revoke Mod', onTap: () async {
            final u = modCtrl.text.trim();
            if (u.isEmpty) { _confirm('Enter a username', error: true); return; }
            try {
              await Supabase.instance.client.rpc('revoke_moderator', params: {'target_username': u});
              _confirm('$u revoked');
            } catch (e) { _confirm('$e', error: true); }
          }),
        ]),
      ]),
    );
  }

  Widget _buildNotifTab() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String recipient = 'all';
    String? background;
    const bgOptions = <String, Color>{
      'Default': Color(0xFFEFEFEF),
      'Gold': Color(0xFFFFD465),
      'Green': Color(0xFF7BD957),
      'Blue': Color(0xFF5865F2),
      'Red': Color(0xFFE6543A),
    };
    return StatefulBuilder(
      builder: (context, setLocal) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DevLabel('SEND NOTIFICATION'),
            TextField(controller: titleCtrl, decoration: InputDecoration(
              hintText: 'Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 8),
            TextField(controller: bodyCtrl, maxLines: 3, decoration: InputDecoration(
              hintText: 'Message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 12),
            DevLabel('RECIPIENT'),
            RecipientPicker(initial: 'all', onSelected: (v) => recipient = v),
            const SizedBox(height: 12),
            DevLabel('BACKGROUND'),
            Wrap(spacing: 8, runSpacing: 8, children: bgOptions.entries.map((e) {
              final isSelected = background == e.key || (background == null && e.key == 'Default');
              return GestureDetector(
                onTap: () => setLocal(() => background = e.key == 'Default' ? null : e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: e.value,
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                  ),
                  child: Text(e.key, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C)),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) { _confirm('Enter a title', error: true); return; }
                if (!await isValidRecipient(recipient)) {
                  _confirm('No profile found for "$recipient"', error: true);
                  return;
                }
                try {
                  await Supabase.instance.client.from('notifications').insert({
                    'title': titleCtrl.text.trim(),
                    'body': bodyCtrl.text.trim(),
                    'recipient': recipient,
                    'author': AppStore.displayUsername,
                    'background': background,
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  _confirm('Notification sent to $recipient');
                  titleCtrl.clear(); bodyCtrl.clear();
                } catch (e) { _confirm('$e', error: true); }
              },
              child: Text('Send', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildNuclearTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        DevBtn(label: '⚠️ Reset ALL Progress', textColor: Colors.red, onTap: () async {
          final go = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
            title: const Text('Reset everything?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm')),
            ],
          ));
          if (go == true) { await AppStore.resetProgress(); _confirm('Progress wiped'); }
        }),
        DevBtn(label: '⚠️ Reset All Settings', textColor: Colors.orange, onTap: () async {
          await AppStore.resetSettings();
          _confirm('Settings reset');
        }),
      ]),
    );
  }
}

