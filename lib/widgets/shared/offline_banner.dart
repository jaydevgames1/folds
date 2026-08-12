import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folds/services/connectivity_service.dart';

class OfflineBannerListener extends StatefulWidget {
  final Widget child;
  const OfflineBannerListener({super.key, required this.child});
  @override
  State<OfflineBannerListener> createState() => OfflineBannerListenerState();
}

class OfflineBannerListenerState extends State<OfflineBannerListener> {
  bool _offline = false;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    ConnectivityService.isOnline.then((online) {
      if (mounted) setState(() => _offline = !online);
    });
    _sub = ConnectivityService.onStatuschange.listen((online) {
      if (mounted) setState(() => _offline = !online);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                offset: _offline ? Offset.zero : const Offset(0, -1.4),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _offline ? 1 : 0,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6543A),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                  child: Row(children: [
                    const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('No connection. Playing offline. Progress will sync once back online.',
                        style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ]),
                  ),
                ),
              ),
            ),
          ),
        ],
    ),
    );
  }
                    
}