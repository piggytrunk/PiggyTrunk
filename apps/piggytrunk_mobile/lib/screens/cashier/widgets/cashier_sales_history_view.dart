import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/models/pos_model.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'cashier_receipt_modal.dart';
import '../../../utils/capitalization_formatters.dart';

class CashierSalesHistoryView extends StatefulWidget {
  final List<Map<String, dynamic>> salesLogs;
  final bool isLoadingSales;
  final String cashierName;
  final VoidCallback? onBackToPOS;

  const CashierSalesHistoryView({
    super.key,
    required this.salesLogs,
    required this.isLoadingSales,
    this.cashierName = 'Cashier Staff',
    this.onBackToPOS,
  });

  @override
  State<CashierSalesHistoryView> createState() => _CashierSalesHistoryViewState();
}

class _CashierSalesHistoryViewState extends State<CashierSalesHistoryView> {
  int _selectedFilterIndex = 0; // 0 = All, 1 = Today, 2 = Feeds, 3 = Meds
  final TextEditingController _searchCtrl = TextEditingController();

  static const Color _brandNavy = Color(0xFF18314F);
  static const Color _emeraldGreen = Color(0xFF10B981);
  static const Color _cardBorder = Color(0xFFE2E8F0);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'Recent';
    try {
      final dt = DateTime.parse(dateVal.toString());
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inMinutes < 60) {
        return difference.inMinutes <= 1 ? 'Just now' : '${difference.inMinutes}m ago';
      }

      final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');

      if (isToday) {
        return 'Today • $hour:$min $ampm';
      }

      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$min $ampm';
    } catch (_) {
      return dateVal.toString();
    }
  }

  void _showReceiptModal(Map<String, dynamic> sale) {
    final product = sale['product'] as Map<String, dynamic>?;
    final String productName = product != null ? (product['name'] as String) : (sale['product_name'] ?? 'IMMUNOBOOSTER');
    final double totalAmount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    final int quantity = sale['quantity'] as int? ?? 1;
    final double unitPrice = quantity > 0 ? totalAmount / quantity : totalAmount;
    final String dateStr = sale['sale_date'] ?? sale['created_at'] ?? DateTime.now().toIso8601String();
    final DateTime dt = DateTime.tryParse(dateStr) ?? DateTime.now();
    final String receiptNumber = sale['id'] != null
        ? sale['id'].toString().padLeft(6, '0')
        : dt.millisecondsSinceEpoch.toString().substring(6);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CashierReceiptModal(
        receiptNumber: receiptNumber,
        customerName: sale['customer_name'] ?? 'Walk-in Customer',
        cashierName: sale['cashier_name'] ?? widget.cashierName,
        timestamp: dt,
        items: [
          OrderItem(
            id: sale['id'] is int ? sale['id'] as int : 1,
            productId: (sale['product_id'] ?? '0').toString(),
            productName: productName,
            price: unitPrice,
            quantity: quantity,
            image: product != null ? product['image'] : null,
          ),
        ],
        totalAmount: totalAmount,
        paymentMethod: sale['payment_method'] ?? 'Cash',
        tenderedAmount: totalAmount,
        changeAmount: 0.0,
        onDone: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleColor = isDark ? Colors.white : _brandNavy;
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final cardBorder = isDark ? const Color(0xFF28354A) : _cardBorder;
    final cardBg = isDark ? const Color(0xFF1B2638) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF1B2638) : Colors.white;

    final query = _searchCtrl.text.trim().toLowerCase();
    final now = DateTime.now();

    // Summary calculations
    double totalRevenue = 0.0;
    double todayRevenue = 0.0;

    for (final sale in widget.salesLogs) {
      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
      totalRevenue += amount;

      final dateStr = sale['sale_date'] ?? sale['created_at'];
      if (dateStr != null) {
        final dt = DateTime.tryParse(dateStr.toString());
        if (dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          todayRevenue += amount;
        }
      }
    }

    // Filter list
    final filteredLogs = widget.salesLogs.where((sale) {
      final product = sale['product'] as Map<String, dynamic>?;
      final pName = (product != null ? product['name'] : sale['product_name'])?.toString().toLowerCase() ?? '';
      final category = (product != null ? product['category'] : sale['category'])?.toString().toLowerCase() ?? '';
      final customer = (sale['customer_name'] ?? '').toString().toLowerCase();
      final idStr = (sale['id'] ?? '').toString().toLowerCase();

      // Quick filter pill
      if (_selectedFilterIndex == 1) {
        // Today only
        final dateStr = sale['sale_date'] ?? sale['created_at'];
        if (dateStr != null) {
          final dt = DateTime.tryParse(dateStr.toString());
          if (dt == null || dt.year != now.year || dt.month != now.month || dt.day != now.day) {
            return false;
          }
        } else {
          return false;
        }
      } else if (_selectedFilterIndex == 2) {
        // Feeds
        if (!category.contains('feed') && !pName.contains('feed') && !pName.contains('grower') && !pName.contains('booster')) {
          return false;
        }
      } else if (_selectedFilterIndex == 3) {
        // Meds & Vits
        if (!category.contains('med') && !category.contains('vit') && !pName.contains('vit') && !pName.contains('iron')) {
          return false;
        }
      }

      // Search query filter
      if (query.isNotEmpty) {
        return pName.contains(query) || idStr.contains(query) || customer.contains(query) || category.contains(query);
      }

      return true;
    }).toList();

    return Column(
      children: [
        // Top KPI Stats Bar
        Container(
          margin: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E3A8A), const Color(0xFF1E293B)]
                  : [_brandNavy, const Color(0xFF1E3A5F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black38 : _brandNavy.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL SALES LOGS',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(totalRevenue),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 36,
                width: 1,
                color: Colors.white24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY\'S VOLUME',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(todayRevenue),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF34D399),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Search Field & Quick Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              inputFormatters: const [CapitalizeWordsInputFormatter()],
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: titleColor),
              decoration: InputDecoration(
                hintText: 'Search receipts by product, customer, or ID...',
                hintStyle: GoogleFonts.plusJakartaSans(color: subtitleColor, fontSize: 11.5),
                prefixIcon: Icon(Icons.search_rounded, color: subtitleColor, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 16, color: subtitleColor),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Modern Segmented Filter Pills
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildFilterPill(0, 'All Logs (${widget.salesLogs.length})', isDark: isDark),
              const SizedBox(width: 8),
              _buildFilterPill(1, 'Today', isDark: isDark),
              const SizedBox(width: 8),
              _buildFilterPill(2, 'Feeds', isDark: isDark),
              const SizedBox(width: 8),
              _buildFilterPill(3, 'Meds & Vits', isDark: isDark),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Logs List or Lively Empty State
        Expanded(
          child: widget.isLoadingSales
              ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : _brandNavy))
              : (filteredLogs.isEmpty
                  ? _buildEmptyState(isDark: isDark, titleColor: titleColor, subtitleColor: subtitleColor)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      itemCount: filteredLogs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildReceiptCard(
                          filteredLogs[index],
                          isDark: isDark,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                        );
                      },
                    )),
        ),
      ],
    );
  }

  Widget _buildFilterPill(int index, String title, {required bool isDark}) {
    final isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : _brandNavy)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.white : _brandNavy)
                  : (isDark ? const Color(0xFF334155) : _cardBorder),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isDark ? Colors.white : _brandNavy).withValues(alpha: isDark ? 0.12 : 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                    : (isDark ? PiggyTrunkTheme.ptTextDark : const Color(0xFF475569)),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptCard(
    Map<String, dynamic> sale, {
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    final product = sale['product'] as Map<String, dynamic>?;
    final String productName = product != null ? (product['name'] as String) : (sale['product_name'] ?? 'ImmunoBooster 1L');
    final String categoryName = product != null ? (product['category'] as String) : (sale['category'] ?? 'Medicines');
    final String imageUrl = (product != null && product['image'] != null) ? product['image'] as String : '';
    final double totalAmount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    final int quantity = sale['quantity'] as int? ?? 1;
    final String quantityLabel = sale['unit_type'] != null ? '$quantity ${sale['unit_type']}' : '$quantity units';
    final String customerName = sale['customer_name'] ?? 'Walk-in Customer';
    final String paymentMethod = sale['payment_method'] ?? 'Cash';
    final String dateFormatted = _formatDate(sale['sale_date'] ?? sale['created_at']);
    
    // Shorten UUIDs to clean receipt badges e.g. #SALE-XXXX or #50197623
    final rawId = (sale['invoice_number'] ?? sale['receipt_number'] ?? sale['id'] ?? 'TX').toString();
    final String saleId = rawId.length > 10 ? '#${rawId.substring(0, 8).toUpperCase()}' : (rawId.startsWith('#') ? rawId : '#$rawId');

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReceiptModal(sale),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Sale ID, Customer & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              saleId,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customerName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF10B981).withValues(alpha: 0.16)
                                : _emeraldGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            paymentMethod,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF6EE7B7) : _emeraldGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dateFormatted,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF28354A) : const Color(0xFFF1F5F9)),
                ),

                // Middle Row: Thumbnail, Product Name & Quantity
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(imageUrl, fit: BoxFit.cover),
                            )
                          : Icon(Icons.receipt_long_rounded, color: titleColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  categoryName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: subtitleColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '•  Qty: $quantityLabel',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(totalAmount),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 12, color: _emeraldGreen),
                            const SizedBox(width: 3),
                            Text(
                              'Paid',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _emeraldGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : _brandNavy).withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(color: (isDark ? Colors.white : _brandNavy).withValues(alpha: 0.1), width: 2),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 38,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Sales Records Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Completed POS orders and customer digital receipts will automatically appear here with full transaction records.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: subtitleColor,
                height: 1.4,
              ),
            ),
            if (widget.onBackToPOS != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: widget.onBackToPOS,
                icon: const Icon(Icons.point_of_sale_rounded, size: 18, color: Colors.white),
                label: Text(
                  'Open POS Terminal',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2563EB) : _brandNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
