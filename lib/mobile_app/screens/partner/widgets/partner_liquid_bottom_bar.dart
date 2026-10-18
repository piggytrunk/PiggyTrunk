import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/app_strings.dart';

/// Modern Liquid Glassmorphic Bottom Navigation Bar for Partner / Investor App
/// Featuring translucent frosted backdrop blur, specular highlight borders,
/// and smooth animated highlight selection pills for White and Dark modes.
class PartnerLiquidBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadNotificationsCount;

  static const Color _brandNavy = Color(0xFF18314F);

  const PartnerLiquidBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadNotificationsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    // Liquid Glass surface colors:
    final glassBg = isDark
        ? const Color(0xFF151F2E).withValues(alpha: 0.76)
        : Colors.white.withValues(alpha: 0.75);

    final glassBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.88);

    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.50)
        : _brandNavy.withValues(alpha: 0.15);

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        height: 66,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomPadding > 0 ? 4 : 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: (isDark ? Colors.black : _brandNavy).withValues(
                alpha: isDark ? 0.25 : 0.05,
              ),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: glassBg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: glassBorderColor, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildNavItem(
                    index: 0,
                    label: strings.navHome,
                    icon: Icons.grid_view_outlined,
                    activeIcon: Icons.grid_view_rounded,
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    index: 1,
                    label: strings.navInvestment,
                    icon: Icons.account_balance_wallet_outlined,
                    activeIcon: Icons.account_balance_wallet_rounded,
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    index: 2,
                    label: strings.navLifecycle,
                    icon: Icons.timeline_outlined,
                    activeIcon: Icons.timeline_rounded,
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    index: 3,
                    label: strings.navActivities,
                    icon: Icons.article_outlined,
                    activeIcon: Icons.article_rounded,
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    index: 4,
                    label: strings.navProfile,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    int badgeCount = 0,
    Color badgeColor = Colors.red,
    required bool isDark,
  }) {
    final isSelected = currentIndex == index;

    // Highlight Pill Styling:
    final activePillBg = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : _brandNavy;

    final activePillBorder = isDark
        ? Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1)
        : null;

    final activeTextColor = Colors.white;
    final activeIconColor = Colors.white;

    final inactiveColor = isDark
        ? PiggyTrunkTheme.ptMutedDark
        : const Color(0xFF909BB0);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 10 : 4,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isSelected ? activePillBg : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: isSelected ? activePillBorder : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (isDark ? Colors.black : _brandNavy).withValues(
                          alpha: isDark ? 0.35 : 0.22,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isSelected ? activeIcon : icon,
                        size: 21,
                        color: isSelected ? activeIconColor : inactiveColor,
                      ),
                      if (badgeCount > 0)
                        Positioned(
                          right: -6,
                          top: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF151F2E) : _brandNavy)
                                    : (isDark ? const Color(0xFF151F2E) : Colors.white),
                                width: 1.2,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 15,
                              minHeight: 15,
                            ),
                            child: Center(
                              child: Text(
                                badgeCount > 99 ? '99+' : '$badgeCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? activeTextColor : inactiveColor,
                    letterSpacing: isSelected ? 0.3 : 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
