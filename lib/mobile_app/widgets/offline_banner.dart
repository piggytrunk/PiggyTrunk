import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../services/connectivity_service.dart';

/// Slim top banner (Facebook/YouTube style):
/// coral "No internet connection" while offline, green "Back online" briefly on reconnect.
class OfflineBanner extends StatefulWidget {
  static const double bannerHeight = 36.0;
  static final ValueNotifier<bool> isVisible = ValueNotifier<bool>(false);

  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _visible = false;
  bool _offline = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _offline = !ConnectivityService.isOnline.value;
    _visible = _offline;
    OfflineBanner.isVisible.value = _visible;
    ConnectivityService.isOnline.addListener(_onChange);
  }

  void _onChange() {
    final offline = !ConnectivityService.isOnline.value;
    if (offline == _offline) return;
    _hideTimer?.cancel();
    setState(() {
      _offline = offline;
      _visible = true;
      OfflineBanner.isVisible.value = true;
    });
    if (!offline) {
      _hideTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _visible = false;
            OfflineBanner.isVisible.value = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    ConnectivityService.isOnline.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _offline
        ? (isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent)
        : (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess);
    final topInset = MediaQuery.of(context).padding.top;

    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: topInset + OfflineBanner.bannerHeight,
          padding: EdgeInsets.fromLTRB(16, topInset, 16, 0),
          decoration: BoxDecoration(
            color: bg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              height: OfflineBanner.bannerHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _offline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _offline ? 'No internet connection' : 'Back online',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
