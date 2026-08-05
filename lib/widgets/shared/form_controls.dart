
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SectionHeader extends StatelessWidget {
  final String label;
  const SectionHeader(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(label,
        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 1.2)),
    );
  }
}

class ToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double titleSize;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const ToggleRow({
    required this.title,
    this.subtitle,
    this.titleSize = 20,
    this.enabled = true,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.dmSans(fontSize: titleSize, fontWeight: FontWeight.w800, color: Colors.black)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                        style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black38)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF7BD957),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFBDBDBD),
            ),
          ],
        ),
      ),
    );
  }
}

class SegmentedRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? hint;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const SegmentedRow({
    required this.title,
    this.subtitle,
    this.hint,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!,
                          style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black38)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SegmentedControl(options: options, selected: selected, onChanged: onChanged),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(hint!,
                  style: GoogleFonts.dmSans(fontSize: 11, color: Colors.black26)),
              ),
            ),
        ],
      ),
    );
  }
}

class SegmentedControl extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const SegmentedControl({required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final isSelected = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD6D6D6) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(options[i],
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.black : Colors.black38,
                  letterSpacing: 0.5,
                )),
            ),
          );
        }),
      ),
    );
  }
}

class SliderRow extends StatelessWidget {
  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  const SliderRow({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(title,
              style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF2C2C2C),
                inactiveTrackColor: const Color(0xFFBDBDBD),
                thumbColor: const Color(0xFFE8E8E8),
                overlayColor: Colors.black12,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
                trackHeight: 6,
              ),
              child: Slider(value: value, onChanged: onChanged),
            ),
          ),
        ],
      ),
    );
  }
}

class TimeDisplay extends StatelessWidget {
  final String hour;
  final String minute;
  const TimeDisplay({required this.hour, required this.minute});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _digitBox(hour[0]),
        const SizedBox(width: 4),
        _digitBox(hour[1]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(':', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
        ),
        _digitBox(minute[0]),
        const SizedBox(width: 4),
        _digitBox(minute[1]),
      ],
    );
  }

  Widget _digitBox(String d) {
    return Container(
      width: 28, height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(d, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}
