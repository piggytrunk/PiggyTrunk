import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/models/pos_model.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/app_strings.dart';
import '../../../widgets/piggy_toast.dart';

void showCashierNotificationDrawer({
  required BuildContext context,
  required List<Map<String, dynamic>> pendingRequests,
  required List<POSProduct> lowStockProducts,
  required List<Map<String, dynamic>> salesLogs,
  required Set<String> readNotificationIds,
  DateTime? lastMarkAllReadTime,
  required VoidCallback onNavigateToRequests,
  required VoidCallback onNavigateToInventory,
  required VoidCallback onShowSalesHistory,
  required VoidCallback onMarkAllAsRead,
  required Function(String) onMarkAsRead,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CashierNotificationDrawerContent(
      pendingRequests: pendingRequests,
      lowStockProducts: lowStockProducts,
      salesLogs: salesLogs,
      readNotificationIds: readNotificationIds,
      lastMarkAllReadTime: lastMarkAllReadTime,
      onNavigateToRequests: onNavigateToRequests,
      onNavigateToInventory: onNavigateToInventory,
      onShowSalesHistory: onShowSalesHistory,
      onMarkAllAsRead: onMarkAllAsRead,
      onMarkAsRead: onMarkAsRead,
    ),
  );
}

class _CashierNotificationDrawerContent extends StatefulWidget {
  final List<Map<String, dynamic>> pendingRequests;
  final List<POSProduct> lowStockProducts;
  final List<Map<String, dynamic>> salesLogs;
  final Set<String> readNotificationIds;
  final DateTime? lastMarkAllReadTime;
  final VoidCallback onNavigateToRequests;
  final VoidCallback onNavigateToInventory;
  final VoidCallback onShowSalesHistory;
  final VoidCallback onMarkAllAsRead;
  final Function(String) onMarkAsRead;

  const _CashierNotificationDrawerContent({
    required this.pendingRequests,
    required this.lowStockProducts,
    required this.salesLogs,
    required this.readNotificationIds,
    this.lastMarkAllReadTime,
    required this.onNavigateToRequests,
    required this.onNavigateToInventory,
    required this.onShowSalesHistory,
    required this.onMarkAllAsRead,
    required this.onMarkAsRead,
  });

  @override
  State<_CashierNotificationDrawerContent> createState() => _CashierNotificationDrawerContentState();
}

class _CashierNotificationDrawerContentState extends State<_CashierNotificationDrawerContent> {
  static const Color _brandColor = Color(0xFF18314F);

  String _selectedFilter = 'Active'; // 'Active', 'Requests', 'Stock', 'History'
  late Set<String> _localReadIds;
  DateTime? _localLastMarkAllReadTime;

  @override
  void initState() {
    super.initState();
    _localReadIds = Set<String>.from(widget.readNotificationIds);
    _localLastMarkAllReadTime = widget.lastMarkAllReadTime;
  }

  bool _isItemRead(String id, dynamic dateValue) {
    if (_localReadIds.contains(id)) return true;
    if (_localLastMarkAllReadTime != null && dateValue != null) {
      try {
        final dt = DateTime.parse(dateValue.toString()).toLocal();
        if (!dt.isAfter(_localLastMarkAllReadTime!)) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  String _formatTime(dynamic dateValue) {
    if (dateValue == null) return 'Recent';
    try {
      final dt = DateTime.parse(dateValue.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return 'Recent';
    }
  }

  void _handleMarkAllAsRead() {
    final now = DateTime.now();
    setState(() {
      _localLastMarkAllReadTime = now;
      for (final req in widget.pendingRequests) {
        final raw = req['request_id'] ?? req['id'];
        if (raw != null) _localReadIds.add('req_$raw');
      }
      for (final p in widget.lowStockProducts) {
        _localReadIds.add('stock_${p.id}');
      }
      for (final sale in widget.salesLogs) {
        final raw = sale['id'] ?? sale['sale_id'];
        if (raw != null) _localReadIds.add('sale_$raw');
      }
    });
    widget.onMarkAllAsRead();
    final strings = AppStrings.of(context);
    PiggyToast.showSuccess(
      context,
      strings.allNotificationsMarkedRead,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    final drawerBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final titleColor = isDark ? Colors.white : _brandColor;
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final cardBorder = isDark ? const Color(0xFF28354A) : PiggyTrunkTheme.ptBorder;

    final activeRequests = widget.pendingRequests.where((r) {
      final st = (r['status'] ?? '').toString().toLowerCase();
      return st == 'pending' || st == 'for_approval' || st.isEmpty;
    }).toList();

    // Calculate unread counts
    int unreadRequests = 0;
    for (final req in activeRequests) {
      final raw = req['request_id'] ?? req['id'];
      final id = 'req_${raw ?? ''}';
      final date = req['created_at'] ?? req['request_date'];
      if (!_isItemRead(id, date)) unreadRequests++;
    }

    int unreadStock = 0;
    for (final p in widget.lowStockProducts) {
      final id = 'stock_${p.id}';
      if (!_localReadIds.contains(id)) unreadStock++;
    }

    int unreadSales = 0;
    for (final sale in widget.salesLogs.take(5)) {
      final raw = sale['id'] ?? sale['sale_id'];
      final id = 'sale_${raw ?? ''}';
      final date = sale['sale_date'] ?? sale['created_at'];
      if (!_isItemRead(id, date)) unreadSales++;
    }

    final totalUnread = unreadRequests + unreadStock + unreadSales;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: drawerBg,
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
            // Drag handle pill
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Drawer Header - Clean & Aligned with Hog Raiser & PI
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.notifications_active_rounded,
                      color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              strings.notificationsTitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (totalUnread > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$totalUnread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          strings.notificationsSubtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (totalUnread > 0)
                    GestureDetector(
                      onTap: _handleMarkAllAsRead,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.done_all_rounded,
                              color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              strings.markAllRead,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subtitleColor, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Balanced Filter Tabs Bar (Active, Requests, Stock, History) - Matches Hog Raiser & PI
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterTab(
                      'Active',
                      '${strings.tabActive} ($totalUnread)',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildFilterTab(
                      'Requests',
                      unreadRequests > 0 ? '${strings.tabRequests} ($unreadRequests)' : strings.tabRequests,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildFilterTab(
                      'Stock',
                      unreadStock > 0 ? '${strings.tabStock} ($unreadStock)' : strings.tabStock,
                    ),
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                    child: _buildFilterTab(
                      'History',
                      strings.tabHistory,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: cardBorder),

            // Notification Items List
            Expanded(
              child: _buildNotificationList(
                scrollController,
                activeRequests,
                strings: strings,
                isDark: isDark,
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

  Widget _buildNotificationList(
    ScrollController scrollController,
    List<Map<String, dynamic>> activeRequests, {
    required AppStrings strings,
    required bool isDark,
  }) {
    final List<Widget> items = [];

    // 1. Pending Stock Requests
    if (_selectedFilter == 'Active' || _selectedFilter == 'Requests' || _selectedFilter == 'History') {
      for (final req in activeRequests) {
        final rawId = req['request_id'] ?? req['id'];
        final id = 'req_${rawId ?? ''}';
        final date = req['created_at'] ?? req['request_date'];
        final isRead = _isItemRead(id, date);
        if (_selectedFilter != 'History' && isRead) continue;

        final raiser = req['hog_raisers'];
        final String raiserName = (raiser is Map ? (raiser['name'] ?? raiser['app_users']?['name']) : null)?.toString() ??
            req['raiser_name']?.toString() ??
            'Hog Raiser';
        final String itemsDesc = req['item_name']?.toString() ??
            req['product_name']?.toString() ??
            'Stock supply request';
        final String time = _formatTime(date);

        items.add(
          _buildNotificationCard(
            id: id,
            isRead: isRead,
            icon: Icons.inventory_2_rounded,
            iconColor: const Color(0xFFF59E0B),
            bgColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB),
            title: strings.isFilipino ? 'Kahilingan sa Stock: $raiserName' : 'Stock Request: $raiserName',
            subtitle: '$itemsDesc • $time',
            badgeText: strings.isFilipino ? 'AKSYON KAILANGAN' : 'ACTION REQUIRED',
            badgeColor: const Color(0xFFD97706),
            actionLabel: strings.reviewRequest,
            timeStr: time,
            isDark: isDark,
            onTap: () {
              setState(() => _localReadIds.add(id));
              widget.onMarkAsRead(id);
              Navigator.pop(context);
              widget.onNavigateToRequests();
            },
          ),
        );
      }
    }

    // 2. Low Stock Alerts
    if (_selectedFilter == 'Active' || _selectedFilter == 'Stock' || _selectedFilter == 'History') {
      for (final p in widget.lowStockProducts) {
        final id = 'stock_${p.id}';
        final isRead = _localReadIds.contains(id);
        if (_selectedFilter != 'History' && isRead) continue;

        final isCritical = p.units <= 5;
        items.add(
          _buildNotificationCard(
            id: id,
            isRead: isRead,
            icon: Icons.warning_amber_rounded,
            iconColor: isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
            bgColor: isCritical
                ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2))
                : (isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB)),
            title: strings.isFilipino ? 'Mababang Stock: ${p.name}' : '${p.name} is running low',
            subtitle: strings.isFilipino
                ? '${p.units} unit na lang ang natitira sa imbentaryo'
                : 'Only ${p.units} units remaining in inventory',
            badgeText: isCritical
                ? (strings.isFilipino ? 'KRITIKAL' : 'CRITICAL')
                : (strings.isFilipino ? 'MABABANG STOCK' : 'LOW STOCK'),
            badgeColor: isCritical ? const Color(0xFFDC2626) : const Color(0xFFD97706),
            actionLabel: strings.restockItem,
            timeStr: strings.tabStock,
            isDark: isDark,
            onTap: () {
              setState(() => _localReadIds.add(id));
              widget.onMarkAsRead(id);
              Navigator.pop(context);
              widget.onNavigateToInventory();
            },
          ),
        );
      }
    }

    // 3. Completed Sales
    if (_selectedFilter == 'Active' || _selectedFilter == 'History') {
      for (final sale in widget.salesLogs.take(10)) {
        final rawId = sale['id'] ?? sale['sale_id'];
        final id = 'sale_${rawId ?? ''}';
        final date = sale['sale_date'] ?? sale['created_at'];
        final isRead = _isItemRead(id, date);
        if (_selectedFilter != 'History' && isRead) continue;

        final invoice = (sale['invoice_number'] ?? sale['receipt_number'] ?? '#SALE-${rawId ?? ''}').toString();
        final rawTotal = sale['total_amount'] ?? sale['total'] ?? 0;
        final double total = rawTotal is num ? rawTotal.toDouble() : double.tryParse(rawTotal.toString()) ?? 0.0;
        final time = _formatTime(date);

        items.add(
          _buildNotificationCard(
            id: id,
            isRead: isRead,
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF10B981),
            bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
            title: strings.isFilipino ? 'Nakumpletong Benta: $invoice' : 'Sale Completed: $invoice',
            subtitle: '₱${total.toStringAsFixed(2)} • $time',
            badgeText: strings.isFilipino ? 'TAPOS NA' : 'COMPLETED',
            badgeColor: const Color(0xFF059669),
            actionLabel: strings.viewReceipt,
            timeStr: time,
            isDark: isDark,
            onTap: () {
              setState(() => _localReadIds.add(id));
              widget.onMarkAsRead(id);
              Navigator.pop(context);
              widget.onShowSalesHistory();
            },
          ),
        );
      }
    }

    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _selectedFilter == 'History' ? Icons.history_rounded : Icons.done_all_rounded,
                  size: 34,
                  color: isDark ? Colors.white70 : PiggyTrunkTheme.ptPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedFilter == 'History' ? strings.noHistoryRecorded : strings.allCaughtUp,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : _brandColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedFilter == 'History'
                    ? strings.noHistorySubtitle
                    : strings.allCaughtUpSubtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  height: 1.45,
                ),
              ),
              if (_selectedFilter != 'History' &&
                  (activeRequests.isNotEmpty || widget.lowStockProducts.isNotEmpty || widget.salesLogs.isNotEmpty)) ...[
                const SizedBox(height: 20),
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
      );
    }

    return ListView.separated(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => items[index],
    );
  }

  Widget _buildNotificationCard({
    required String id,
    required bool isRead,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required String actionLabel,
    required String timeStr,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final itemBg = isRead
        ? (isDark ? PiggyTrunkTheme.ptSurfaceDark : const Color(0xFFF8FAFC))
        : (isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : Colors.white);

    final itemBorder = isRead
        ? (isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder)
        : (isDark ? Colors.white.withValues(alpha: 0.18) : PiggyTrunkTheme.ptBorder);

    final titleColor = isDark ? Colors.white : _brandColor;
    final descColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: itemBorder,
          width: isRead ? 1 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isRead ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)) : bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isRead ? (isDark ? Colors.white54 : const Color(0xFF94A3B8)) : iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Content Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Title + Time (Aligned with Hog Raiser & PI)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                color: titleColor,
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
                              color: descColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Subtitle / message
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isRead ? descColor : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          fontWeight: isRead ? FontWeight.w400 : FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Bottom Action & Tag Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Subtle Badge Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                                  : badgeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isRead ? (isDark ? Colors.white70 : const Color(0xFF64748B)) : badgeColor,
                              ),
                            ),
                          ),

                          // Action Link with Arrow
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                actionLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                size: 13,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Unread Indicator Dot on the far right
                if (!isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
