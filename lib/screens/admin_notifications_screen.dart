import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/admin_notification_model.dart';
import '../providers/admin_notifications_provider.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/notifications/notification_filter_bar.dart';
import '../widgets/notifications/notification_item_card.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/slide_over_confirmation_drawer.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends ConsumerState<AdminNotificationsScreen> {
  String _selectedFilter = 'unread'; // 'unread', 'investments', 'registrations', 'history'

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgDark => _isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
  Color get _panelStart => _isDark ? const Color(0xFF1A2940) : Colors.white;
  Color get _panelEnd => _isDark ? const Color(0xFF0F1C2F) : Colors.white;
  Color get _panelBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);
  Color get _surfaceColor => _isDark ? const Color(0xFF132238) : Colors.white;
  Color get _innerBgColor => _isDark ? const Color(0xFF0F1A2A) : const Color(0xFFF8FAFC);
  Color get _borderColor => _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _mutedColor => _isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
  Color get _brandPrimary => _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;

  @override
  Widget build(BuildContext context) {
    final isSmall = Responsive.isSmallScreen(context);
    final isMobile = Responsive.isMobile(context);

    final asyncNotifications = ref.watch(adminNotificationsProvider);
    final allNotifications = asyncNotifications.value ?? <AdminNotification>[];
    final unreadCount = allNotifications.where((n) => !n.isRead).length;

    final filteredNotifications = allNotifications.where((n) {
      final t = n.title.toLowerCase();
      final m = n.message.toLowerCase();
      final ty = n.type.toLowerCase();
      if (t.contains('password reset') ||
          m.contains('reset their password') ||
          ty.contains('password_reset') ||
          ty == 'cashier_profile') {
        return false;
      }
      if (_selectedFilter == 'unread') return !n.isRead;
      if (_selectedFilter == 'investments') return NotificationFilterBar.isPartnerInvestment(n);
      if (_selectedFilter == 'registrations') return NotificationFilterBar.isUserRegistration(n);
      if (_selectedFilter == 'history') return true;
      return !n.isRead;
    }).toList();

    return Scaffold(
      backgroundColor: _bgDark,
      drawer: isSmall
          ? Drawer(
              backgroundColor: _panelStart,
              child: AdminSidebar(
                currentRoute: '/notifications',
                onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
                isDrawer: true,
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenTopBar(),
          Expanded(
            child: Row(
              children: [
                if (!isSmall)
                  AdminSidebar(
                    currentRoute: '/notifications',
                    onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isMobile ? 12 : 20),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_panelStart, _panelEnd],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        border: Border.all(color: _panelBorder, width: 1),
                        borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 14 : 34,
                        vertical: isMobile ? 16 : 32,
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                              color: _brandPrimary.withValues(alpha: _isDark ? 0.16 : 0.08),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: _brandPrimary.withValues(alpha: 0.25),
                                                width: 1,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.notifications_active_outlined,
                                              color: _brandPrimary,
                                              size: isMobile ? 20 : 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Notifications',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: _titleColor,
                                              fontSize: isMobile ? 22 : 28,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (unreadCount > 0) ...[
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _brandPrimary.withValues(alpha: _isDark ? 0.18 : 0.1),
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: _brandPrimary.withValues(alpha: 0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                '$unreadCount new',
                                                style: AppTextStyles.jakarta(
                                                  size: 11.5,
                                                  weight: FontWeight.w700,
                                                  color: _brandPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Review real-time system alerts, investment requests, and user registrations.',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: _mutedColor,
                                          fontSize: isMobile ? 12 : 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (unreadCount > 0) ...[
                                      OutlinedButton.icon(
                                        onPressed: () => AdminNotificationService.markAllAsRead(),
                                        icon: const Icon(Icons.done_all_rounded, size: 16),
                                        label: const Text('Mark all read'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _brandPrimary,
                                          side: BorderSide(color: _borderColor),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isMobile ? 10 : 16,
                                            vertical: isMobile ? 8 : 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    IconButton(
                                      onPressed: () => Navigator.of(context).maybePop(),
                                      icon: Icon(Icons.close_rounded, color: _titleColor, size: isMobile ? 24 : 28),
                                      tooltip: 'Back to previous page',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Filter Bar
                            NotificationFilterBar(
                              selectedFilter: _selectedFilter,
                              allNotifications: allNotifications,
                              unreadCount: unreadCount,
                              isDark: _isDark,
                              onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
                            ),
                            const SizedBox(height: 20),

                            // Notifications Card Container
                            Container(
                              decoration: BoxDecoration(
                                color: _surfaceColor,
                                borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                                border: Border.all(color: _borderColor),
                              ),
                              padding: EdgeInsets.all(isMobile ? 12 : 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (filteredNotifications.isEmpty)
                                    _buildEmptyState(
                                      _isDark,
                                      _mutedColor,
                                      _titleColor,
                                      _borderColor,
                                      allNotifications.isNotEmpty,
                                    )
                                  else
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: filteredNotifications.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final notif = filteredNotifications[index];
                                        return NotificationItemCard(
                                          notif: notif,
                                          isDark: _isDark,
                                          surfaceColor: _surfaceColor,
                                          bgColor: _innerBgColor,
                                          borderColor: _borderColor,
                                          textColor: _titleColor,
                                          mutedColor: _mutedColor,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Bottom Summary & Clear All Row
                            if (allNotifications.isNotEmpty)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _isDark ? const Color(0xFF1A2B44) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _borderColor),
                                    ),
                                    child: Text(
                                      filteredNotifications.length == allNotifications.length
                                          ? 'Total: ${allNotifications.length} notifications'
                                          : 'Showing ${filteredNotifications.length} of ${allNotifications.length}',
                                      style: AppTextStyles.jakarta(
                                        size: 12,
                                        weight: FontWeight.w600,
                                        color: _mutedColor,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final confirm = await SlideOverConfirmationDrawer.show(
                                        context: context,
                                        title: 'Clear All Notifications',
                                        message:
                                            'Are you sure you want to clear all ${allNotifications.length} notifications? This will permanently delete all notification logs.',
                                        actionType: SlideOverActionType.danger,
                                        confirmButtonText: 'Yes, Clear All',
                                        cancelButtonText: 'Cancel',
                                        customIcon: Icons.delete_sweep_outlined,
                                      );

                                      if (confirm == true) {
                                        await AdminNotificationService.clearAll();
                                      }
                                    },
                                    icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Color(0xFFFF758C)),
                                    label: const Text(
                                      'Clear all history',
                                      style: TextStyle(color: Color(0xFFFF758C), fontWeight: FontWeight.w700),
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
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color mutedColor, Color textColor, Color borderColor, bool hasHistory) {
    final brandPrimary = isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;
    final ringOuter = isDark ? const Color(0xFF1E2F47).withValues(alpha: 0.6) : const Color(0xFFEEF4FD);
    final ringInner = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF1F5F9);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ringOuter,
              ),
              child: Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ringInner,
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 30,
                    color: brandPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasHistory ? 'No Notifications in this Filter' : 'All Caught Up!',
              style: AppTextStyles.jakarta(
                size: 17,
                weight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasHistory
                  ? 'No notifications match the "$_selectedFilter" category.'
                  : 'You have no new alerts. Real-time updates will appear here automatically.',
              textAlign: TextAlign.center,
              style: AppTextStyles.jakarta(
                size: 13,
                weight: FontWeight.w400,
                color: mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
