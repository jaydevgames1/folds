/* import 'package:flutter/material.dart'; */


enum TexturePackId { classic, pixel8, retroPixel, neon, wood }

class TexturePackDef {
  final TexturePackId id;
  final String name;
  final String description;
  final bool isDefault;
  const TexturePackDef(this.id, this.name, this.description, {this.isDefault = false});
}

const texturePacks = [
  TexturePackDef(TexturePackId.classic, 'Classic', 'The original clean Folds look.', isDefault: true),
  TexturePackDef(TexturePackId.pixel8, '8-Bit', 'Chunky pixel-art tiles.'),
  TexturePackDef(TexturePackId.retroPixel, 'Retro 8-Bit', 'Warm dithered CRT-style tiles.'),
  TexturePackDef(TexturePackId.neon, 'Neon', 'Glowing edges for night mode.'),
  TexturePackDef(TexturePackId.wood, 'Wood', 'Grained wooden tile texture.'),
];
