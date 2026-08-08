import 'package:flutter/material.dart';
import 'package:folds/models/texture_pack_def.dart';
import 'package:folds/widgets/shared/folds_top_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/state/app_store.dart';
import 'package:folds/painters/texture_painters.dart';

class TexturePacksScreen extends StatefulWidget {
  const TexturePacksScreen({super.key});
  @override
  State<TexturePacksScreen> createState() => TexturePacksScreenState();
}

class TexturePacksScreenState extends State<TexturePacksScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(children: [
            FoldsTopBar(title: 'TEXTURE PACKS', onBack: () => Navigator.pop(context)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85),
                itemCount: texturePacks.length,
                itemBuilder: (context, i) {
                  final pack = texturePacks[i];
                  final owned = AppStore.isTexturePackUnlocked(pack.id.name);
                  final active = AppStore.activeTexturePack == pack.id.name;
                  return GestureDetector(
                    onTap: () {
                      if (!owned) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Locked — redeem a code to unlock ${pack.name}'),
                          backgroundColor: const Color(0xFF2C2C2C)));
                        return;
                      }
                      setState(() => AppStore.activeTexturePack = pack.id.name);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFEFEF),
                        borderRadius: BorderRadius.circular(18),
                        border: active ? Border.all(color: const Color(0xFF4CAF50), width: 2.5) : null,
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        Expanded(
                          child: Opacity(
                            opacity: owned ? 1.0 : 0.35,
                            child: Row(children: [
                              Expanded(child: PreviewFor(packId: pack.id.name, isBlack: true)),
                              const SizedBox(width: 6),
                              Expanded(child: PreviewFor(packId: pack.id.name, isBlack: false)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          if (!owned) const Padding(padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.lock_rounded, size: 14, color: Colors.black38)),
                          Text(pack.name, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800,
                            color: owned ? Colors.black : Colors.black38)),
                        ]),
                        if (active) Padding(padding: const EdgeInsets.only(top: 4),
                          child: Text('ACTIVE', style: GoogleFonts.dmSans(
                            fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF4CAF50), letterSpacing: 1))),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class PreviewFor extends StatelessWidget {
  final String packId;
  final bool isBlack;
  const PreviewFor({required this.packId, required this.isBlack});
  @override
  Widget build(BuildContext context) {
    final color = isBlack ? const Color(0xFF2C2C2C) : Colors.white;
    return AspectRatio(
      aspectRatio: 1,
      child: switch (packId) {
        'pixel8' => CustomPaint(painter: PixelTexturePainter(color: color, retro: false)),
        'retroPixel' => CustomPaint(painter: PixelTexturePainter(color: color, retro: true)),
        'neon' => Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isBlack ? const Color(0xFF00E5FF) : const Color(0xFFFF2FD6), width: 2))),
        'wood' => CustomPaint(painter: WoodTexturePainter(color: color)),
        _ => Container(color: color),
      },
    );
  }
}
