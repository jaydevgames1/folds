import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StarRating extends StatelessWidget {
  final int filled;
  final int total;
  const StarRating({required this.filled, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) => Icon(
        i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 26,
        color: i < filled ? Colors.black : Colors.black26,
      )),
    );
  }
}


class ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final String label;
  const ProgressBar({required this.progress, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toInt();
    return Stack(
      children: [
        Container(
          height: 26,
          decoration: BoxDecoration(color: const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(13)),
          child: Row(
            children: [
              Expanded(
                flex: pct,
                child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(13))),
              ),
              Expanded(flex: 100 - pct, child: const SizedBox()),
            ],
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(label,
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black54)),
            ),
          ),
        ),
      ],
    );
  }
}


class TrackPlayerCard extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayToggle;
  final double volume;
  final ValueChanged<double> onVolumeChanged;

  const TrackPlayerCard({
    required this.isPlaying,
    required this.onPlayToggle,
    required this.volume,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.music_note_rounded, color: Color(0xFF2C2C2C), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thrifty & Swifty',
                    style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
                  Text('Broke Making Bank',
                    style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black38)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onPlayToggle,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(isPlaying),
                  color: Colors.black,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.volume_down_rounded, color: Colors.black38, size: 18),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF2C2C2C),
                  inactiveTrackColor: const Color(0xFFBDBDBD),
                  thumbColor: const Color(0xFFE8E8E8),
                  overlayColor: Colors.black12,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  trackHeight: 4,
                ),
                child: Slider(value: volume, onChanged: onVolumeChanged),
              ),
            ),
            const Icon(Icons.volume_up_rounded, color: Colors.black38, size: 18),
          ],
        ),
      ],
    );
  }
}

