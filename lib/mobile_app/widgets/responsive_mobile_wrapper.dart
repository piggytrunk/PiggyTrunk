import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'offline_banner.dart';

/// Wraps mobile screens on Web to ensure a clean, responsive presentation.
/// On native mobile devices (Android/iOS APK) or mobile web browsers (< 560px),
/// it renders the child full-screen.
/// On larger screens (laptops, desktop monitors, tablets), it centers the interface
/// within a sleek, modern mobile application frame so UI elements don't get stretched.
class ResponsiveMobileWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveMobileWrapper({
    super.key,
    required this.child,
    this.maxWidth = 480.0,
  });

  @override
  Widget build(BuildContext context) {
    // Offline banner pinned on top of every mobile screen with coordinated layout shift
    final child = ValueListenableBuilder<bool>(
      valueListenable: OfflineBanner.isVisible,
      builder: (context, isBannerVisible, _) {
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              top: isBannerVisible ? OfflineBanner.bannerHeight : 0.0,
              left: 0,
              right: 0,
              bottom: 0,
              child: this.child,
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: OfflineBanner(),
            ),
          ],
        );
      },
    );

    if (!kIsWeb) {
      return child;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Direct full-screen view for mobile phone browsers
    if (screenWidth <= maxWidth + 40) {
      return child;
    }

    // Centered modern device frame on desktop / laptop screens
    final ambientBg = isDark
        ? const Color(0xFF090D16)
        : const Color(0xFFE8EEF5);

    final borderColor = isDark
        ? PiggyTrunkTheme.ptBorderDark
        : const Color(0xFFCBD5E1);

    return Scaffold(
      backgroundColor: ambientBg,
      body: Center(
        child: Container(
          width: maxWidth,
          height: screenHeight > 840 ? (screenHeight * 0.94).clamp(700.0, 920.0) : screenHeight,
          margin: EdgeInsets.symmetric(
            vertical: screenHeight > 840 ? 20.0 : 0.0,
            horizontal: 16.0,
          ),
          decoration: BoxDecoration(
            color: isDark ? PiggyTrunkTheme.ptBgDark : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                blurRadius: 36,
                spreadRadius: 2,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: child,
          ),
        ),
      ),
    );
  }
}
