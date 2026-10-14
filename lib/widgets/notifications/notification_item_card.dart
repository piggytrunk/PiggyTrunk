import 'package:flutter/material.dart';
import '../../models/admin_notification_model.dart';
import '../../providers/admin_notifications_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import 'hog_report_detail_modal.dart';

class NotificationItemCard extends StatelessWidget {
  final AdminNotification notif;
  final bool isDark;
  final Color surfaceColor;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const NotificationItemCard({
    super.key,
    required this.notif,
    required this.isDark,
    required this.surfaceColor,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 7) {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _resolveTargetRoute(AdminNotification notif) {
    final type = notif.type.toLowerCase();
    final meta = notif.metadata ?? <String, dynamic>{};
    final role = (meta['role'] ?? '').toString().toLowerCase();
    final message = notif.message.toLowerCase();
    final title = notif.title.toLowerCase();

    // 0. Investments & Partner Funding -> /investments (Prioritized before generic user checks)
    if (type == 'investment' ||
        type.contains('investment') ||
        type == 'transaction' ||
        title.contains('investment') ||
        message.contains('invested') ||
        message.contains('investment')) {
      return '/investments';
    }

    // Admin Profile & Security Notifications -> /settings
    if (type == 'admin_profile' ||
        type.contains('admin') ||
        type.contains('security') ||
        title.contains('admin email') ||
        title.contains('email updated') ||
        message.contains('login email') ||
        message.contains('admin email')) {
      return '/settings';
    }

    // Batch Milestone & Harvest Notifications -> /batches
    if (type == 'batch' ||
        type.contains('batch') ||
        title.contains('batch ready') ||
        title.contains('harvest') ||
        message.contains('final stage') ||
        message.contains('ready for harvest') ||
        message.contains('ready for selling')) {
      return '/batches';
    }

    // Stock Requests -> /inventory (Raiser Stock Requests Tab)
    if (type == 'stock_request' ||
        type.contains('stock') ||
        title.contains('stock request') ||
        title.contains('stock') ||
        message.contains('stock request') ||
        message.contains('requested new stock') ||
        message.contains('requested')) {
      return '/inventory';
    }

    // Hog Raiser Registrations & Hog Reports -> /raisers
    if (role == 'hog_raiser' ||
        role == 'raiser' ||
        message.contains('hog raiser') ||
        title.contains('hog raiser') ||
        type == 'hog_report' ||
        type.contains('hog')) {
      return '/raisers';
    }

    // Partner Investor Registrations & Account Approvals -> /users
    if (role == 'partner' ||
        role == 'investor' ||
        (message.contains('partner') && (type.contains('user') || title.contains('registration') || title.contains('account'))) ||
        (title.contains('partner') && (type.contains('user') || title.contains('registration') || title.contains('account')))) {
      return '/users';
    }

    // Cashier Registrations -> /users
    if (role == 'cashier' || message.contains('cashier') || title.contains('cashier')) {
      return '/users';
    }

    // Feeds & Supplies Inventory -> /inventory
    if (type == 'feed_restock' ||
        type.contains('feed') ||
        type.contains('inventory') ||
        message.contains('feed')) {
      return '/inventory';
    }

    // General User Approvals
    if (type == 'user_registration' || type.contains('user') || type.contains('approval')) {
      return '/users';
    }

    // Financial Transactions / POS
    if (type.contains('sales') || type.contains('pos')) {
      return '/investments';
    }

    return '/dashboard';
  }

  IconData _getCategoryIcon(String type, String message) {
    final lowerType = type.toLowerCase();
    final lowerMsg = message.toLowerCase();
    // Prioritize investment before batch / hog keywords in message
    if (lowerType.contains('invest') ||
        lowerType.contains('transaction') ||
        lowerMsg.contains('invested') ||
        lowerMsg.contains('investment') ||
        lowerMsg.contains('fund')) {
      return Icons.payments_rounded;
    }
    if (lowerType.contains('admin') ||
        lowerType.contains('security') ||
        lowerType.contains('profile') ||
        lowerMsg.contains('admin email') ||
        lowerMsg.contains('login email')) {
      return Icons.mark_email_read_rounded;
    }
    if (lowerType.contains('user') || lowerMsg.contains('register') || lowerMsg.contains('account')) {
      return Icons.person_add_rounded;
    }
    if (lowerType.contains('hog') || lowerMsg.contains('batch') || lowerMsg.contains('pig')) {
      return Icons.pets_rounded;
    }
    if (lowerType.contains('feed') || lowerType.contains('stock') || lowerType.contains('inventory')) {
      return Icons.inventory_2_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  Color _getCategoryColor(String type, String message, bool isDark) {
    final lowerType = type.toLowerCase();
    final lowerMsg = message.toLowerCase();
    if (lowerType.contains('invest') ||
        lowerType.contains('transaction') ||
        lowerMsg.contains('invested') ||
        lowerMsg.contains('investment') ||
        lowerMsg.contains('fund')) {
      return isDark ? const Color(0xFF43CB89) : const Color(0xFF2FB36F);
    }
    if (lowerType.contains('admin') ||
        lowerType.contains('security') ||
        lowerType.contains('profile') ||
        lowerMsg.contains('admin email') ||
        lowerMsg.contains('login email')) {
      return isDark ? const Color(0xFF60A5FA) : const Color(0xFF18314F);
    }
    if (lowerType.contains('user') || lowerMsg.contains('register')) {
      return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    }
    if (lowerType.contains('hog') || lowerMsg.contains('batch')) {
      return isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    }
    if (lowerType.contains('feed') || lowerType.contains('stock')) {
      return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    }
    return isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;
  }

  String _resolveUserRole(AdminNotification notif) {
    final meta = notif.metadata ?? <String, dynamic>{};
    final role = (meta['role'] ?? meta['user_role'] ?? '').toString().toLowerCase().trim();
    if (role.isNotEmpty) {
      if (role.contains('cashier')) return 'Cashier';
      if (role.contains('partner') || role.contains('investor')) return 'Partner Investor';
      if (role.contains('raiser') || role.contains('hog')) return 'Hog Raiser';
    }
    final msg = notif.message.toLowerCase();
    final title = notif.title.toLowerCase();
    if (msg.contains('cashier') || title.contains('cashier')) return 'Cashier';
    if (msg.contains('partner') || title.contains('partner') || msg.contains('investor') || title.contains('investor')) {
      return 'Partner Investor';
    }
    if (msg.contains('hog raiser') || title.contains('hog raiser') || msg.contains('raiser') || title.contains('raiser')) {
      return 'Hog Raiser';
    }
    return 'Hog Raiser'; // Default role in Piggy Trunk for general accounts
  }

  String _formatNotificationTitle(AdminNotification notif) {
    final cleaned = NotificationService.cleanText(notif.title);
    final lower = cleaned.toLowerCase();

    // If it's an account approved notification
    if (lower.contains('account approved') || notif.type == 'approval_email') {
      final roleDisplay = _resolveUserRole(notif);
      return 'Account Approved for $roleDisplay';
    }

    // If it's a registration notification
    if (lower.contains('registration') || notif.type == 'user_registration') {
      final roleDisplay = _resolveUserRole(notif);
      if (roleDisplay != 'User' && !lower.contains(roleDisplay.toLowerCase())) {
        return 'New $roleDisplay Registration';
      }
    }

    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final targetRoute = _resolveTargetRoute(notif);
    final meta = notif.metadata ?? <String, dynamic>{};
    final role = (meta['role'] ?? '').toString().toLowerCase();
    final message = notif.message.toLowerCase();
    final title = notif.title.toLowerCase();

    final dynamic routeArg;
    if (targetRoute == '/inventory') {
      routeArg = 'stock_request';
    } else if (targetRoute == '/investments') {
      routeArg = 'PARTNER';
    } else if (targetRoute == '/raisers') {
      routeArg = {
        'tab': 'pending_raiser',
        'name': meta['name'],
        'email': meta['email'],
        'raiser_id': meta['user_id'] ?? meta['raiser_id'],
      };
    } else if (targetRoute == '/users') {
      final isCashier = role == 'cashier' || message.contains('cashier') || title.contains('cashier');
      final isPending = notif.type == 'user_registration' || message.contains('pending') || title.contains('pending');

      final String tabName = isCashier
          ? (isPending ? 'pending_cashier' : 'active_cashier')
          : (isPending ? 'pending_partner' : 'active_partner');

      routeArg = {
        'tab': tabName,
        'email': (meta['email'] ?? '').toString(),
        'name': (meta['name'] ?? '').toString(),
      };
    } else {
      routeArg = (notif.type == 'user_registration' || message.contains('pending')) ? 'pending' : null;
    }

    final brandPrimary = isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;
    final catColor = _getCategoryColor(notif.type, notif.message, isDark);
    final catIcon = _getCategoryIcon(notif.type, notif.message);

    final cardBg = notif.isRead
        ? surfaceColor
        : (isDark ? const Color(0xFF172436) : const Color(0xFFF3F7FD));
    final cardBorder = notif.isRead
        ? borderColor
        : (isDark ? const Color(0xFF334E6F) : const Color(0xFFBFDBFE));

    final isHogReport = notif.type == 'hog_report' ||
        notif.title.toLowerCase().contains('hog health') ||
        (notif.metadata != null && notif.metadata!['report_id'] != null);

    return InkWell(
      onTap: () {
        if (!notif.isRead) {
          AdminNotificationService.markAsRead(notif.notificationId);
        }
        Navigator.of(context).pop(); // Close drawer
        if (isHogReport) {
          HogReportDetailModal.show(context, notif: notif);
        } else {
          Navigator.of(context).pushNamed(targetRoute, arguments: routeArg); // Navigate directly to screen
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardBorder,
            width: 1,
          ),
          boxShadow: !notif.isRead
              ? [
                  BoxShadow(
                    color: brandPrimary.withValues(alpha: isDark ? 0.1 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              // Card Main Body
              Padding(
                padding: EdgeInsets.fromLTRB(notif.isRead ? 12 : 14, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Icon Badge
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: isDark ? 0.18 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: catColor.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        catIcon,
                        size: 16,
                        color: catColor,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Notification Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Title + Time
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(
                                child: Text(
                                  _formatNotificationTitle(notif),
                                  style: AppTextStyles.jakarta(
                                    size: 13,
                                    weight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTimeAgo(notif.createdAt),
                                style: AppTextStyles.jakarta(
                                  size: 11,
                                  weight: FontWeight.w500,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Message Text
                          Text(
                            NotificationService.cleanText(notif.message),
                            style: AppTextStyles.jakarta(
                              size: 12,
                              weight: FontWeight.w400,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              height: 1.35,
                            ),
                          ),

                          // Badges for User Registrations & Approvals (Role Tag + Status Tag)
                          if (notif.type == 'user_registration' || notif.type == 'approval_email' || notif.title.toLowerCase().contains('registration') || notif.title.toLowerCase().contains('approved')) ...[
                            const SizedBox(height: 6),
                            _buildUserBadges(notif, isDark),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Left accent strip for unread notifications
              if (!notif.isRead)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3.5,
                    color: brandPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserBadges(AdminNotification notif, bool isDark) {
    final titleLower = notif.title.toLowerCase();
    final isApproved = titleLower.contains('approved') || notif.type == 'approval_email';
    final isRejected = titleLower.contains('rejected');

    final statusLabel = isApproved ? 'APPROVED' : (isRejected ? 'REJECTED' : 'PENDING REVIEW');
    final statusColor = isApproved
        ? const Color(0xFF10B981)
        : (isRejected ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

    final roleDisplay = _resolveUserRole(notif);

    Color roleColor;
    if (roleDisplay == 'Cashier') {
      roleColor = isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    } else if (roleDisplay == 'Partner Investor') {
      roleColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    } else {
      roleColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Role Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: isDark ? 0.2 : 0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: roleColor.withValues(alpha: 0.35), width: 0.8),
          ),
          child: Text(
            roleDisplay.toUpperCase(),
            style: AppTextStyles.jakarta(
              size: 9.5,
              weight: FontWeight.w700,
              color: roleColor,
            ),
          ),
        ),
        // Status Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: isDark ? 0.2 : 0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 0.8),
          ),
          child: Text(
            statusLabel,
            style: AppTextStyles.jakarta(
              size: 9.5,
              weight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}
