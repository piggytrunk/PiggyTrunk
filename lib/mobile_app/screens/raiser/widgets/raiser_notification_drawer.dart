import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../../services/notification_service.dart';
import '../../../utils/app_strings.dart';
import '../../../widgets/piggy_toast.dart';
import 'raiser_empty_state.dart';

void showRaiserNotificationDrawer({
  required BuildContext context,
  required List<Map<String, dynamic>> notificationsList,
  required VoidCallback onRefreshNotifications,
  required Function(int notificationId) onMarkNotificationAsRead,
  required VoidCallback onMarkAllRead,
  Function(int index)? onNavigateToTab,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RaiserNotificationDrawerContent(
      notificationsList: notificationsList,
      onRefreshNotifications: onRefreshNotifications,
      onMarkNotificationAsRead: onMarkNotificationAsRead,
      onMarkAllRead: onMarkAllRead,
      onNavigateToTab: onNavigateToTab,
    ),
  );
}

class _RaiserNotificationDrawerContent extends StatefulWidget {
  final List<Map<String, dynamic>> notificationsList;
  final VoidCallback onRefreshNotifications;
  final Function(int notificationId) onMarkNotificationAsRead;
  final VoidCallback onMarkAllRead;
  final Function(int index)? onNavigateToTab;

  const _RaiserNotificationDrawerContent({
    required this.notificationsList,
    required this.onRefreshNotifications,
    required this.onMarkNotificationAsRead,
    required this.onMarkAllRead,
    this.onNavigateToTab,
  });

  @override
  State<_RaiserNotificationDrawerContent> createState() => _RaiserNotificationDrawerContentState();
}

class _RaiserNotificationDrawerContentState extends State<_RaiserNotificationDrawerContent> {
  static const Color _brandColor = Color(0xFF18314F);
  static const Color _brandBlue = Color(0xFF2563EB);

  String _selectedFilter = 'Active'; // 'Active', 'Requests', 'Approved', 'History'

  List<Map<String, dynamic>> get _deduplicatedNotifications {
    final hasApprovedStock = widget.notificationsList.any((n) {
      final t = (n['title'] ?? '').toString();
      return t.contains('Stock Request Approved') || t.contains('Kahilingan ng Stock');
    });

    final seenKeys = <String>{};
    final deduped = <Map<String, dynamic>>[];

    for (final n in widget.notificationsList) {
      final title = (n['title'] ?? '').toString().trim();
      final msg = (n['message'] ?? n['content'] ?? '').toString().trim();
      final type = (n['type'] ?? n['category'] ?? '').toString().trim().toLowerCase();

      final isTriggerDuplicate = (title == 'Stock Request Update') &&
          (msg.contains('Feeds has been') ||
              msg.contains('Medicines has been') ||
              msg.contains('Vitamins has been') ||
              msg.contains('supplies has been'));
      if (isTriggerDuplicate && hasApprovedStock) {
        continue;
      }

      final batchId = (n['metadata'] is Map ? (n['metadata']['batch_id'] ?? '') : '').toString().trim();
      final isBatchNotif = type == 'batch_assigned';

      final String dedupKey;
      if (isBatchNotif && batchId.isNotEmpty) {
        dedupKey = 'batch_$batchId';
      } else if (isBatchNotif) {
        final batchMatch = RegExp(r'(batch[\w\s\-]+)', caseSensitive: false).firstMatch(msg);
        final extractedBatch = batchMatch != null ? batchMatch.group(1)?.toLowerCase().trim() : '';
        dedupKey = extractedBatch != null && extractedBatch.isNotEmpty ? 'batch_$extractedBatch' : '$title|$msg';
      } else {
        dedupKey = '$title|$msg';
      }

      if (seenKeys.contains(dedupKey)) {
        continue;
      }
      seenKeys.add(dedupKey);
      deduped.add(n);
    }

    return deduped;
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    final sourceList = _deduplicatedNotifications;
    if (_selectedFilter == 'History') return sourceList;
    return sourceList.where((n) {
      final isRead = n['is_read'] == true;
      if (_selectedFilter == 'Active') return !isRead;

      final type = (n['type'] ?? n['category'] ?? '').toString().toLowerCase();
      final title = (n['title'] ?? '').toString().toLowerCase();
      final message = (n['message'] ?? n['content'] ?? '').toString().toLowerCase();

      if (_selectedFilter == 'Requests') {
        return type.contains('request') ||
            type.contains('stock') ||
            title.contains('request') ||
            title.contains('kahilingan') ||
            message.contains('request');
      } else if (_selectedFilter == 'Approved') {
        return type.contains('approved') ||
            title.contains('approved') ||
            title.contains('naaprubahan') ||
            message.contains('approved');
      }
      return !isRead;
    }).toList();
  }

  void _handleMarkAllAsRead() {
    widget.onMarkAllRead();
    setState(() {});
    final strings = AppStrings.of(context);
    PiggyToast.showSuccess(
      context,
      strings.isFilipino
          ? 'Lahat ng notification ay minarkahan nang nabasa.'
          : 'All notifications marked as read.',
    );
  }

  String _formatTime(dynamic dateValue, AppStrings strings) {
    if (dateValue == null) return '';
    return strings.formatRelativeTime(dateValue);
  }

  String _resolveCategoryLabel(String type, AppStrings strings) {
    final t = type.toLowerCase();
    if (t.contains('stock') || t.contains('request')) {
      return strings.isFilipino ? 'Kahilingan ng Stock' : 'Stock Request';
    } else if (t.contains('health') || t.contains('sick')) {
      return strings.isFilipino ? 'Ulat Pangkalusugan' : 'Health Alert';
    } else if (t.contains('batch')) {
      return strings.isFilipino ? 'Pagtatalaga ng Batch' : 'Batch Assignment';
    } else if (t.contains('invest')) {
      return strings.isFilipino ? 'Puhunan' : 'Investment';
    } else if (t.contains('stage')) {
      return strings.isFilipino ? 'Yugto ng Pakain' : 'Feeds Stage';
    }
    return strings.isFilipino ? 'Alerto' : 'Notice';
  }

  void _showNotificationDetail({
    required BuildContext context,
    required Map<String, dynamic> notif,
    required String title,
    required String message,
    required String timeStr,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String categoryLabel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : _brandColor;
    final mutedColor = isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted;
    final strings = AppStrings.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header with Icon & Category & Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: iconColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            categoryLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20, color: mutedColor),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),

                // Time
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: mutedColor),
                    const SizedBox(width: 5),
                    Text(
                      timeStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Message container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: SelectableText(
                    message.isNotEmpty ? message : title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      widget.onRefreshNotifications();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : _brandColor,
                      foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      strings.isFilipino ? 'Naiintindihan' : 'Close',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final sheetBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final textColor = isDark ? Colors.white : _brandColor;
    final mutedColor = isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted;

    final unreadCount = _deduplicatedNotifications.where((n) => n['is_read'] == false).length;
    final displayList = _filteredNotifications;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Drawer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : _brandColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_rounded,
                          size: 20,
                          color: isDark ? Colors.white : _brandColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.notificationsTitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          if (unreadCount > 0)
                            Text(
                              strings.isFilipino
                                  ? '$unreadCount bagong update'
                                  : '$unreadCount new update${unreadCount > 1 ? 's' : ''}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981),
                              ),
                            )
                          else
                            Text(
                              strings.isFilipino ? 'Lahat ay nabasa na' : 'All caught up',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: mutedColor,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (unreadCount > 0)
                        TextButton(
                          onPressed: _handleMarkAllAsRead,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            strings.markAllRead,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF38BDF8) : _brandColor,
                            ),
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                        onPressed: () => Navigator.pop(context),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Filter Tabs Bar (Active, Requests, Approved, History)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(child: _buildFilterTab('Active', '${strings.tabActive} (${_deduplicatedNotifications.where((n) => n['is_read'] != true).length})')),
                  const SizedBox(width: 6),
                  Expanded(child: _buildFilterTab('Requests', strings.request)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildFilterTab('Approved', strings.filterApproved)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildFilterTab('History', strings.tabHistory)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Notifications List
            Expanded(
              child: displayList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RaiserEmptyState(
                              icon: Icons.done_all_rounded,
                              message: _selectedFilter == 'History' ? strings.noHistoryRecorded : strings.allCaughtUp,
                              subtitle: _selectedFilter == 'History'
                                  ? strings.noHistorySubtitle
                                  : strings.allCaughtUpSubtitle,
                            ),
                            if (_selectedFilter != 'History' && widget.notificationsList.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => setState(() => _selectedFilter = 'History'),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark ? Colors.white54 : _brandColor,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.history_rounded,
                                          size: 18,
                                          color: isDark ? Colors.white : _brandColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          strings.viewNotificationHistory,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : _brandColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final notif = displayList[index];
                        final isRead = notif['is_read'] == true;
                        final notifId = (notif['notification_id'] ?? notif['id']) as int?;
                        final rawTitle = (notif['title'] ?? 'Notification').toString();
                        final rawMessage = (notif['message'] ?? notif['content'] ?? '').toString();
                        final title = NotificationService.localizeTitle(rawTitle, strings.isFilipino);
                        final message = NotificationService.localizeMessage(rawMessage, strings.isFilipino);
                        final timeStr = _formatTime(notif['created_at'], strings);
                        final type = (notif['type'] ?? notif['category'] ?? '').toString().toLowerCase();

                        IconData notifIcon = Icons.notifications_rounded;
                        Color iconColor = isDark ? const Color(0xFF38BDF8) : _brandBlue;
                        Color iconBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);

                        if (type.contains('stock') || type.contains('request')) {
                          notifIcon = Icons.inventory_2_rounded;
                          iconColor = const Color(0xFFF59E0B);
                          iconBg = isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB);
                        } else if (type.contains('health') || type.contains('sick')) {
                          notifIcon = Icons.health_and_safety_rounded;
                          iconColor = const Color(0xFFEF4444);
                          iconBg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
                        } else if (type.contains('invest')) {
                          notifIcon = Icons.account_balance_wallet_rounded;
                          iconColor = const Color(0xFF10B981);
                          iconBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
                        } else if (type.contains('batch') || type.contains('stage') || type.contains('hog')) {
                          notifIcon = Icons.pets_rounded;
                          iconColor = const Color(0xFF10B981);
                          iconBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
                        }

                        final itemBg = isRead
                            ? (isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC));
                        final itemBorder = isRead
                            ? sheetBorder
                            : (isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.4) : const Color(0xFFCBD5E1));

                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (!isRead && notifId != null) {
                                setState(() {
                                  notif['is_read'] = true;
                                });
                                widget.onMarkNotificationAsRead(notifId);
                              }

                              _showNotificationDetail(
                                context: context,
                                notif: notif,
                                title: title,
                                message: message,
                                timeStr: timeStr,
                                icon: notifIcon,
                                iconColor: iconColor,
                                iconBg: iconBg,
                                categoryLabel: _resolveCategoryLabel(type, strings),
                              );
                            },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: itemBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: itemBorder,
                                width: isRead ? 1 : 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: iconBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(notifIcon, color: iconColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13.5,
                                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                                color: textColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            timeStr,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: mutedColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (message.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          message,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: isRead ? mutedColor : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                            fontWeight: isRead ? FontWeight.w400 : FontWeight.w500,
                                          ),
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (!isRead) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF38BDF8) : _brandBlue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String key, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedFilter == key;
    final selectedBg = isDark ? Colors.white : _brandColor;
    final selectedText = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inactiveBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final inactiveText = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : inactiveBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? selectedText : inactiveText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
