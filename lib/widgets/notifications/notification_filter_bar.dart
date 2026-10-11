import 'package:flutter/material.dart';
import '../../models/admin_notification_model.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';

class NotificationFilterBar extends StatelessWidget {
  final String selectedFilter;
  final List<AdminNotification> allNotifications;
  final int unreadCount;
  final bool isDark;
  final ValueChanged<String> onFilterChanged;

  const NotificationFilterBar({
    super.key,
    required this.selectedFilter,
    required this.allNotifications,
    required this.unreadCount,
    required this.isDark,
    required this.onFilterChanged,
  });

  Widget _buildFilterPill(String filterKey, String label) {
    final isSelected = selectedFilter == filterKey;
    final bg = isSelected
        ? (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
        : (isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD));
    final fg = isSelected
        ? (isDark ? PiggyTrunkTheme.ptPrimary : Colors.white)
        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569));
    final border = isSelected
        ? Colors.transparent
        : (isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3));

    return InkWell(
      onTap: () => onFilterChanged(filterKey),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.jakarta(
            size: 11.5,
            weight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  static bool isPartnerInvestment(AdminNotification n) {
    final type = n.type.toLowerCase();
    final title = n.title.toLowerCase();
    final msg = n.message.toLowerCase();
    return type == 'investment' ||
        type.contains('investment') ||
        title.contains('partner investment') ||
        (title.contains('investment') && (msg.contains('invested') || msg.contains('partner'))) ||
        (n.metadata != null &&
            (n.metadata!['partner_investor_id'] != null ||
                (n.metadata!['amount'] != null && n.metadata!['batch_id'] != null)));
  }

  @override
  Widget build(BuildContext context) {
    final investmentCount = allNotifications.where(isPartnerInvestment).length;
    final usersCount = allNotifications.where((n) => n.type == 'user_registration').length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterPill('unread', 'Active ($unreadCount)'),
          const SizedBox(width: 6),
          _buildFilterPill('investments', 'Investments ($investmentCount)'),
          const SizedBox(width: 6),
          _buildFilterPill('registrations', 'Users ($usersCount)'),
          const SizedBox(width: 6),
          _buildFilterPill('history', 'History (${allNotifications.length})'),
        ],
      ),
    );
  }
}
