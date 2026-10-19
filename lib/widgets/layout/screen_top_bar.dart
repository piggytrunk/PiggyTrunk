import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_text_styles.dart';
import '../../providers/admin_profile_provider.dart';
import '../../providers/admin_notifications_provider.dart';
import '../../models/admin_notification_model.dart';
import '../notifications/admin_notification_drawer.dart';
import '../../utils/responsive.dart';
import '../../screens/settings_screen.dart';
import 'admin_sidebar.dart';

/// Reusable Top Bar Widget with Notification & Admin Profile (No Title)
class ScreenTopBar extends ConsumerWidget {
  final int notificationCount;
  final bool showDivider;
  final bool? showHamburger;

  const ScreenTopBar({
    super.key,
    this.notificationCount = 1,
    this.showDivider = true,
    this.showHamburger,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminProfile = ref.watch(adminProfileProvider);
    final asyncNotifications = ref.watch(adminNotificationsProvider);
    final notifications = asyncNotifications.value ?? <AdminNotification>[];
    final unreadCount = notifications.where((n) => !n.isRead).length;
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final metadataName = (metadata['admin_name'] ?? '').toString().trim();
    final metadataRole = (metadata['role'] ?? '').toString().trim();
    final metadataPhoto = (metadata['profile_picture_url'] ?? '').toString().trim();

    final resolvedName = adminProfile.isHydrated
        ? adminProfile.adminName
        : (metadataName.isNotEmpty ? metadataName : 'Admin');
    final resolvedRole = adminProfile.isHydrated
        ? adminProfile.role
        : (metadataRole.isNotEmpty ? metadataRole : 'System Administrator');
    final resolvedPhoto = adminProfile.isHydrated
        ? (adminProfile.profilePictureUrl ?? '')
        : (metadataPhoto.isNotEmpty ? metadataPhoto : '');

    final shouldHydrateFromMetadata =
        !adminProfile.isHydrated &&
        (metadataName.isNotEmpty || metadataRole.isNotEmpty || metadataPhoto.isNotEmpty);
    if (shouldHydrateFromMetadata) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(adminProfileProvider.notifier).updateProfile(
              adminName: metadataName.isNotEmpty ? metadataName : 'Admin',
              role: metadataRole.isNotEmpty ? metadataRole : 'System Administrator',
              profilePictureUrl: metadataPhoto.isNotEmpty ? metadataPhoto : null,
              email: user?.email ?? adminProfile.email,
              isHydrated: true,
            );
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xff151f2e) : PiggyTrunkTheme.ptSurface;
    final borderColor = isDark ? const Color(0xff28354a) : PiggyTrunkTheme.ptBorder;
    final textColor = isDark ? const Color(0xffecf2ff) : PiggyTrunkTheme.ptText;
    final mutedColor = isDark ? const Color(0xff9cb0c9) : PiggyTrunkTheme.ptMuted;
    final screenHeight = MediaQuery.of(context).size.height;
    final isUltraCompact = screenHeight < 640;
    final isCompactHeight = screenHeight < 840;
    final headerHeight = isUltraCompact
        ? 56.0
        : (isCompactHeight ? 66.0 : 70.0);
    final logoSize = isUltraCompact ? 36.0 : (isCompactHeight ? 40.0 : 44.0);
    final isSmall = showHamburger ?? Responsive.isSmallScreen(context);
    final isMobile = Responsive.isMobile(context);
    final isExpanded = ref.watch(sidebarExpandedProvider);

    return Container(
      height: headerHeight,
      padding: EdgeInsets.only(
        left: isMobile ? 12 : 8,
        right: isMobile ? 12 : 32,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: borderColor,
                  width: 1,
                ),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isSmall) ...[
            Builder(
              builder: (innerContext) => MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Scaffold.of(innerContext).openDrawer();
                  },
                  child: Container(
                    width: isCompactHeight ? 36 : 40,
                    height: isCompactHeight ? 36 : 40,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.menu_rounded,
                      color: textColor,
                      size: isCompactHeight ? 22 : 24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ] else ...[
            /// SIDEBAR EXPAND/COLLAPSE TOGGLE (Leftmost, aligned with sidebar menu icons below)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  ref.read(sidebarExpandedProvider.notifier).state = !isExpanded;
                },
                child: Tooltip(
                  message: isExpanded ? 'Collapse sidebar' : 'Expand sidebar',
                  child: Container(
                    width: isCompactHeight ? 36 : 40,
                    height: isCompactHeight ? 36 : 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.transparent,
                    ),
                    child: Icon(
                      isExpanded ? Icons.menu_open_outlined : Icons.menu_outlined,
                      color: textColor,
                      size: isCompactHeight ? 20 : 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          /// PIGGY TRUNK LOGO
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: logoSize,
              height: logoSize,
              child: Image.asset(
                'assets/piggytrunk_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),

          /// SYSTEM TITLE
          Text(
            'Piggy Trunk',
            style: AppTextStyles.sidebarBrand(textColor).copyWith(
              fontSize: isCompactHeight ? 18.5 : 20.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /// NOTIFICATION BELL WITH BADGE & SLIDE-OVER RIGHT DRAWER
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    AdminNotificationDrawer.show(context);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      border: Border.all(
                        color: borderColor,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 22,
                          color: textColor,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: surfaceColor,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  style: AppTextStyles.jakarta(
                                    size: 10,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              /// ADMIN PROFILE (CLICKABLE)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    final currentRoute = ModalRoute.of(context)?.settings.name;
                    if (currentRoute == '/settings') return;
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    messenger?.hideCurrentSnackBar();
                    messenger?.removeCurrentSnackBar();

                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
                        settings: const RouteSettings(name: '/settings'),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                  child: Container(
                    height: 48,
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: borderColor,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// PROFILE PICTURE OR DEFAULT PIGGYTRUNK LOGO
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? textColor.withValues(alpha: 0.75) : const Color(0xFF2F4A6A),
                              width: 1.6,
                            ),
                          ),
                          child: resolvedPhoto.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    resolvedPhoto,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return ClipOval(
                                        child: Image.asset(
                                          'assets/piggytrunk_logo.png',
                                          fit: BoxFit.contain,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : ClipOval(
                                  child: Image.asset(
                                    'assets/piggytrunk_logo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),

                        /// ADMIN INFO
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              resolvedName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.jakarta(
                                size: 13,
                                weight: FontWeight.w700,
                                color: textColor,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMobile
                                  ? (resolvedRole.toLowerCase().contains('admin') ? 'ADMIN' : resolvedRole.toUpperCase())
                                  : resolvedRole.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.jakarta(
                                size: 10,
                                weight: FontWeight.w600,
                                color: mutedColor,
                                height: 1.1,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
