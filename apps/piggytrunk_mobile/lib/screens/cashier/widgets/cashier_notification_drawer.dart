import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/models/pos_model.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/app_strings.dart';

void showCashierNotificationDrawer({
  required BuildContext context,
  required List<Map<String, dynamic>> pendingRequests,
  required List<POSProduct> lowStockProducts,
  required List<Map<String, dynamic>> salesLogs,
  required Set<String> readNotificationIds,
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
  static const Color _brandBlue = Color(0xFF2563EB);

  String _selectedFilter = 'Active'; // 'Active', 'Requests', 'Stock', 'History'
  late Set<String> _localReadIds;

  @override
  void initState() {
    super.initState();
    _localReadIds = Set<String>.from(widget.readNotificationIds);
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return 'Recent';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recent';
    }
  }

  void _handleMarkAllAsRead() {
    setState(() {
      for (final req in widget.pendingRequests) {
        _localReadIds.add('req_${req['id'] ?? req['request_id']}');
      }
      for (final p in widget.lowStockProducts) {
        _localReadIds.add('stock_${p.id}');
      }
      for (final sale in widget.salesLogs) {
        _localReadIds.add('sale_${sale['id']}');
      }
    });
    widget.onMarkAllAsRead();
    final strings = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.done_all_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              strings.allNotificationsMarkedRead,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF047857),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
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
      final id = 'req_${req['id'] ?? req['request_id']}';
      if (!_localReadIds.contains(id)) unreadRequests++;
    }

    int unreadStock = 0;
    for (final p in widget.lowStockProducts) {
      final id = 'stock_${p.id}';
      if (!_localReadIds.contains(id)) unreadStock++;
    }

    int unreadSales = 0;
    for (final sale in widget.salesLogs.take(5)) {
      final id = 'sale_${sale['id']}';
      if (!_localReadIds.contains(id)) unreadSales++;
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
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Drawer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: _brandBlue, size: 20),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              strings.notificationsSubtitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                            ),
                            if (totalUnread > 0)
                              GestureDetector(
                                onTap: _handleMarkAllAsRead,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF2563EB) : const Color(0xFFDBEAFE),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.done_all_rounded, color: _brandBlue, size: 13),
                                      const SizedBox(width: 3),
                                      Text(
                                        strings.markAllRead,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFF93C5FD) : _brandBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subtitleColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Balanced & Centered Filter Pills Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(child: _buildFilterChip('Active', totalUnread, label: strings.tabActive, isDark: isDark)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildFilterChip('Requests', unreadRequests, label: strings.tabRequests, color: const Color(0xFFF59E0B), isDark: isDark)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildFilterChip('Stock', unreadStock, label: strings.tabStock, color: const Color(0xFFEF4444), isDark: isDark)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildFilterChip('History', 0, label: strings.tabHistory, color: const Color(0xFF64748B), isDark: isDark)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: cardBorder),

            // Notification Items List
            Expanded(
              child: _buildNotificationList(scrollController, activeRequests, strings: strings, isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter, int unreadCount, {String? label, Color color = _brandColor, required bool isDark}) {
    final isSelected = _selectedFilter == filter;
    final displayLabel = label ?? filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : _brandColor)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : _brandColor)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.4 : 1.1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? Colors.white : _brandColor).withValues(alpha: isDark ? 0.15 : 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                displayLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isSelected
                      ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                      : (isDark ? const Color(0xFFECF2FF) : const Color(0xFF1E293B)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.25))
                      : color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$unreadCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? (isDark ? const Color(0xFF0F172A) : Colors.white) : color,
                  ),
                ),
              ),
            ],
          ],
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
        final id = 'req_${req['id'] ?? req['request_id']}';
        final isRead = _localReadIds.contains(id);
        if (_selectedFilter != 'History' && isRead) continue;
        final raiser = req['hog_raisers'];
        final String raiserName = (raiser is Map ? (raiser['name'] ?? raiser['app_users']?['name']) : null)?.toString() ??
            req['raiser_name']?.toString() ??
            'Hog Raiser';
        final String itemsDesc = req['item_name']?.toString() ??
            req['product_name']?.toString() ??
            'Stock supply request';
        final String time = _formatTime(req['created_at'] ?? req['request_date']);

        items.add(
          _buildNotificationCard(
            id: id,
            isRead: isRead,
            icon: Icons.assignment_late_rounded,
            iconColor: const Color(0xFFD97706),
            bgColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
            title: strings.isFilipino ? 'Kahilingan sa Stock: $raiserName' : 'Stock Request: $raiserName',
            subtitle: '$itemsDesc • $time',
            badgeText: strings.isFilipino ? 'AKSYON KAILANGAN' : 'ACTION REQUIRED',
            badgeColor: const Color(0xFFD97706),
            actionLabel: strings.reviewRequest,
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
            iconColor: isCritical ? const Color(0xFFDC2626) : const Color(0xFFD97706),
            bgColor: isCritical
                ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2))
                : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
            title: strings.isFilipino ? 'Mababang Stock: ${p.name}' : '${p.name} is running low',
            subtitle: strings.isFilipino ? '${p.units} unit na lang ang natitira sa imbentaryo' : 'Only ${p.units} units remaining in inventory',
            badgeText: isCritical ? (strings.isFilipino ? 'KRITIKAL' : 'CRITICAL') : (strings.isFilipino ? 'MABABANG STOCK' : 'LOW STOCK'),
            badgeColor: isCritical ? const Color(0xFFDC2626) : const Color(0xFFD97706),
            actionLabel: strings.restockItem,
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
        final id = 'sale_${sale['id']}';
        final isRead = _localReadIds.contains(id);
        if (_selectedFilter != 'History' && isRead) continue;
        final invoice = (sale['invoice_number'] ?? sale['receipt_number'] ?? '#SALE-${sale['id']}').toString();
        final rawTotal = sale['total_amount'] ?? sale['total'] ?? 0;
        final double total = rawTotal is num ? rawTotal.toDouble() : double.tryParse(rawTotal.toString()) ?? 0.0;
        final time = _formatTime(sale['sale_date'] ?? sale['created_at']);

        items.add(
          _buildNotificationCard(
            id: id,
            isRead: isRead,
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF059669),
            bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
            title: strings.isFilipino ? 'Nakumpletong Benta: $invoice' : 'Sale Completed: $invoice',
            subtitle: '₱${total.toStringAsFixed(2)} • $time',
            badgeText: strings.isFilipino ? 'TAPOS NA' : 'COMPLETED',
            badgeColor: const Color(0xFF059669),
            actionLabel: strings.viewReceipt,
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
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB)).withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _selectedFilter == 'History' ? Icons.history_rounded : Icons.done_all_rounded,
                  size: 34,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1D4ED8),
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
              if (_selectedFilter != 'History') ...[
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
                          color: isDark ? const Color(0xFF38BDF8) : _brandColor,
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
                            color: isDark ? const Color(0xFF38BDF8) : _brandColor,
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
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final cardBg = isRead
        ? (isDark ? const Color(0xFF131E2D) : const Color(0xFFF8FAFC))
        : (isDark ? const Color(0xFF1B2638) : Colors.white);

    final cardBorder = isRead
        ? (isDark ? const Color(0xFF28354A) : const Color(0xFFE2E8F0))
        : (isDark ? const Color(0xFF334155) : PiggyTrunkTheme.ptBorder);

    final titleColor = isDark ? Colors.white : _brandColor;
    final descColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isRead ? 0.75 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cardBorder,
            width: isRead ? 1.0 : 1.2,
          ),
          boxShadow: [
            if (!isRead)
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
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
                  Container(
                    padding: const EdgeInsets.all(10),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isRead
                                    ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                                    : badgeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(4),
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
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: _brandBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                            color: isRead ? (isDark ? Colors.white70 : const Color(0xFF475569)) : titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: descColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              actionLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF38BDF8) : _brandBlue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: isDark ? const Color(0xFF38BDF8) : _brandBlue,
                              size: 14,
                            ),
                          ],
                        ),
                      ],
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
