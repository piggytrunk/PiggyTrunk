import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/models/pos_model.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/app_strings.dart';
import '../widgets/cashier_empty_state.dart';
import '../widgets/cashier_notification_bell.dart';
import '../widgets/cashier_notification_drawer.dart';

class CashierHomeTab extends StatelessWidget {
  final String cashierName;
  final List<POSProduct> allProducts;
  final List<POSProduct> lowStockProducts;
  final List<Map<String, dynamic>> pendingRequests;
  final List<Map<String, dynamic>> salesLogs;
  final Set<String> readNotificationIds;
  final VoidCallback onNavigateToPOS;
  final VoidCallback onNavigateToInventory;
  final VoidCallback onNavigateToRequests;
  final VoidCallback onShowRequestsDialog;
  final VoidCallback onShowSalesHistory;
  final VoidCallback onMarkAllAsRead;
  final Function(String) onMarkAsRead;
  final Function(POSProduct) onAddToCart;
  final Future<void> Function() onRefresh;

  static const Color _brandColor = Color(0xFF18314F);

  const CashierHomeTab({
    super.key,
    required this.cashierName,
    required this.allProducts,
    required this.lowStockProducts,
    required this.pendingRequests,
    required this.salesLogs,
    required this.readNotificationIds,
    required this.onNavigateToPOS,
    required this.onNavigateToInventory,
    required this.onNavigateToRequests,
    required this.onShowRequestsDialog,
    required this.onShowSalesHistory,
    required this.onMarkAllAsRead,
    required this.onMarkAsRead,
    required this.onAddToCart,
    required this.onRefresh,
  });

  String _formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  double _calculateTodaySales() {
    final now = DateTime.now();
    double total = 0.0;
    for (final sale in salesLogs) {
      final dateStr = sale['sale_date'] ?? sale['created_at'];
      if (dateStr != null) {
        try {
          final dt = DateTime.parse(dateStr.toString()).toLocal();
          if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
            final rawTotal = sale['total_amount'] ?? sale['total'] ?? 0;
            total += (rawTotal is num ? rawTotal.toDouble() : double.tryParse(rawTotal.toString()) ?? 0.0);
          }
        } catch (_) {}
      }
    }
    return total;
  }

  int _calculateTodayTransactions() {
    final now = DateTime.now();
    int count = 0;
    for (final sale in salesLogs) {
      final dateStr = sale['sale_date'] ?? sale['created_at'];
      if (dateStr != null) {
        try {
          final dt = DateTime.parse(dateStr.toString()).toLocal();
          if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
            count++;
          }
        } catch (_) {}
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    final titleColor = isDark ? Colors.white : _brandColor;
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final cardColor = isDark ? const Color(0xFF1B2638) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28354A) : PiggyTrunkTheme.ptBorder;

    final double todaySales = _calculateTodaySales();
    final int todayTx = _calculateTodayTransactions();
    final int inStockCount = allProducts.where((p) => p.units > 0 && !p.isArchived).length;
    final int lowStockCount = lowStockProducts.length;
    final int pendingReqCount = pendingRequests.where((r) {
      final st = (r['status'] ?? '').toString().toLowerCase();
      return st == 'pending' || st == 'for_approval';
    }).length;

    // Calculate unread count for bell badge
    int totalUnread = 0;
    for (final req in pendingRequests) {
      final st = (req['status'] ?? '').toString().toLowerCase();
      if (st == 'pending' || st == 'for_approval' || st.isEmpty) {
        final id = 'req_${req['id'] ?? req['request_id']}';
        if (!readNotificationIds.contains(id)) totalUnread++;
      }
    }
    for (final p in lowStockProducts) {
      final id = 'stock_${p.id}';
      if (!readNotificationIds.contains(id)) totalUnread++;
    }
    for (final sale in salesLogs.take(5)) {
      final id = 'sale_${sale['id']}';
      if (!readNotificationIds.contains(id)) totalUnread++;
    }

    final List<POSProduct> fastMoving = allProducts
        .where((p) => !p.isArchived)
        .toList()
      ..sort((a, b) => b.sold.compareTo(a.sold));
    final List<POSProduct> featuredProducts = fastMoving.take(6).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: isDark ? Colors.white : _brandColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== TOP GREETING & NOTIFICATION ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.cashierGreeting,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cashierName.trim().isNotEmpty ? cashierName : strings.cashierRole,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                CashierNotificationBell(
                  unreadCount: totalUnread,
                  onOpenNotifications: () {
                    showCashierNotificationDrawer(
                      context: context,
                      pendingRequests: pendingRequests,
                      lowStockProducts: lowStockProducts,
                      salesLogs: salesLogs,
                      readNotificationIds: readNotificationIds,
                      onNavigateToRequests: onNavigateToRequests,
                      onNavigateToInventory: onNavigateToInventory,
                      onShowSalesHistory: onShowSalesHistory,
                      onMarkAllAsRead: onMarkAllAsRead,
                      onMarkAsRead: onMarkAsRead,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ==================== 4 METRIC STATS OVERVIEW ====================
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: strings.todaySales,
                    value: _formatCurrency(todaySales),
                    subtitle: '$todayTx receipts',
                    icon: Icons.payments_rounded,
                    accentColor: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981),
                    bgColor: isDark ? const Color(0xFF10B981).withValues(alpha: 0.14) : const Color(0xFFECFDF5),
                    cardColor: cardColor,
                    cardBorder: cardBorder,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: strings.inStockItems,
                    value: '$inStockCount Items',
                    subtitle: '${allProducts.length} total',
                    icon: Icons.inventory_2_rounded,
                    accentColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                    bgColor: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.14) : const Color(0xFFEFF6FF),
                    cardColor: cardColor,
                    cardBorder: cardBorder,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    onTap: onNavigateToInventory,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: strings.lowStockAlerts,
                    value: '$lowStockCount Items',
                    subtitle: lowStockCount > 0 ? 'Action required' : 'Stocked',
                    icon: Icons.warning_amber_rounded,
                    accentColor: lowStockCount > 0
                        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFEF4444))
                        : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981)),
                    bgColor: lowStockCount > 0
                        ? (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.14) : const Color(0xFFFEF2F2))
                        : (isDark ? const Color(0xFF10B981).withValues(alpha: 0.14) : const Color(0xFFECFDF5)),
                    cardColor: cardColor,
                    cardBorder: cardBorder,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    onTap: onNavigateToInventory,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: strings.pendingHogRequests,
                    value: '$pendingReqCount Pending',
                    subtitle: 'From Raisers',
                    icon: Icons.assignment_rounded,
                    accentColor: isDark ? const Color(0xFFFDE68A) : const Color(0xFFF59E0B),
                    bgColor: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.14) : const Color(0xFFFFFBEB),
                    cardColor: cardColor,
                    cardBorder: cardBorder,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    onTap: onNavigateToRequests,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ==================== QUICK ACTIONS GRID ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  strings.quickActions,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                _buildQuickActionTile(
                  icon: Icons.point_of_sale_rounded,
                  label: strings.openPOS,
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                  cardColor: cardColor,
                  cardBorder: cardBorder,
                  textColor: isDark ? const Color(0xFFE2E8F0) : _brandColor,
                  onTap: onNavigateToPOS,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _buildQuickActionTile(
                  icon: Icons.add_box_rounded,
                  label: strings.manageInventory,
                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981),
                  cardColor: cardColor,
                  cardBorder: cardBorder,
                  textColor: isDark ? const Color(0xFFE2E8F0) : _brandColor,
                  onTap: onNavigateToInventory,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _buildQuickActionTile(
                  icon: Icons.post_add_rounded,
                  label: strings.stockAllocation,
                  color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFF59E0B),
                  cardColor: cardColor,
                  cardBorder: cardBorder,
                  textColor: isDark ? const Color(0xFFE2E8F0) : _brandColor,
                  onTap: onShowRequestsDialog,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _buildQuickActionTile(
                  icon: Icons.receipt_long_rounded,
                  label: strings.recentSalesActivity,
                  color: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF8B5CF6),
                  cardColor: cardColor,
                  cardBorder: cardBorder,
                  textColor: isDark ? const Color(0xFFE2E8F0) : _brandColor,
                  onTap: onShowSalesHistory,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ==================== REAL-TIME STOCK HEALTH ALERTS ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      strings.lowStockAlerts,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: lowStockCount > 0
                            ? (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.25) : const Color(0xFFEF4444))
                            : (isDark ? const Color(0xFF10B981).withValues(alpha: 0.25) : const Color(0xFF10B981)),
                        borderRadius: BorderRadius.circular(12),
                        border: isDark
                            ? Border.all(
                                color: lowStockCount > 0
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                    : const Color(0xFF10B981).withValues(alpha: 0.4),
                              )
                            : null,
                      ),
                      child: Text(
                        '$lowStockCount',
                        style: TextStyle(
                          color: isDark
                              ? (lowStockCount > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7))
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onNavigateToInventory,
                  child: Text(
                    '${strings.manageInventory} →',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (lowStockProducts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF10B981).withValues(alpha: 0.14) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All Stocks Healthy',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'No items are critically low or below threshold.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lowStockProducts.take(3).length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final p = lowStockProducts[index];
                  final isCritical = p.units <= 5;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCritical
                            ? (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFFFECACA))
                            : cardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCritical
                                ? (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.14) : const Color(0xFFFEE2E2))
                                : (isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.14) : const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isCritical ? Icons.error_rounded : Icons.warning_amber_rounded,
                            color: isCritical
                                ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                                : (isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706)),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${p.units} units left • ${p.category}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: isCritical
                                      ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                                      : subtitleColor,
                                  fontWeight: isCritical ? FontWeight.w700 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: onNavigateToInventory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            foregroundColor: titleColor,
                            elevation: 0,
                            side: isDark ? const BorderSide(color: Color(0xFF334155)) : null,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Restock',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),

            // ==================== FAST MOVING PRODUCTS ====================
            if (featuredProducts.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.fastMovingProducts,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: onNavigateToPOS,
                    child: Text(
                      '${strings.posRegister} →',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 195,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: featuredProducts.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = featuredProducts[index];
                    return Container(
                      width: 155,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image container
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF151F2E) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: item.image != null && item.image!.isNotEmpty
                                    ? Image.network(
                                        item.image!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, st) => const Icon(
                                          Icons.inventory_2_outlined,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.inventory_2_outlined,
                                        color: Color(0xFF94A3B8),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatCurrency(item.price),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${item.units} in stock',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => onAddToCart(item),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : _brandColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
                                  ),
                                  child: const Icon(
                                    Icons.add_shopping_cart_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],

            // ==================== RECENT SALES TRANSACTIONS ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  strings.recentSalesActivity,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                GestureDetector(
                  onTap: onShowSalesHistory,
                  child: Text(
                    '${strings.viewAllSales} →',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (salesLogs.isEmpty)
              const CashierEmptyState(
                message: 'No transactions recorded yet today',
                icon: Icons.receipt_long_outlined,
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: salesLogs.length.clamp(0, 3),
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final sale = salesLogs[index];
                  final invoice = (sale['invoice_number'] ?? sale['receipt_number'] ?? '#SALE-${sale['id'] ?? index + 1001}').toString();
                  final rawTotal = sale['total_amount'] ?? sale['total'] ?? 0;
                  final double total = rawTotal is num ? rawTotal.toDouble() : double.tryParse(rawTotal.toString()) ?? 0.0;
                  final String paymentMethod = (sale['payment_method'] ?? 'Cash').toString();
                  final dateStr = sale['sale_date'] ?? sale['created_at'];

                  String timeDisplay = 'Today';
                  if (dateStr != null) {
                    try {
                      final dt = DateTime.parse(dateStr.toString()).toLocal();
                      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
                      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                      final minute = dt.minute.toString().padLeft(2, '0');
                      timeDisplay = '$hour:$minute $ampm';
                    } catch (_) {}
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_rounded,
                            color: isDark ? const Color(0xFF93C5FD) : _brandColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invoice,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$paymentMethod • $timeDisplay',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatCurrency(total),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color cardColor,
    required Color cardBorder,
    required Color titleColor,
    required Color subtitleColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios_rounded, color: subtitleColor.withValues(alpha: 0.6), size: 12),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required Color cardColor,
    required Color cardBorder,
    required Color textColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.14 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
