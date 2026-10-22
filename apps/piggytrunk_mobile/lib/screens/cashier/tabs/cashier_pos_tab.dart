import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/models/pos_model.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:piggytrunk/screens/best_sellers_screen.dart';
import 'package:piggytrunk/screens/demand_forecasting_screen.dart';
import '../../../utils/app_strings.dart';
import '../../../utils/capitalization_formatters.dart';
import '../widgets/cashier_empty_state.dart';
import '../widgets/cashier_sales_history_view.dart';
import '../widgets/cashier_checkout_modal.dart';
import '../widgets/cashier_receipt_modal.dart';

class CashierPOSTab extends StatefulWidget {
  final List<POSProduct> allProducts;
  final List<String> categories;
  final String selectedCategory;
  final Order currentOrder;
  final bool showSalesHistory;
  final List<Map<String, dynamic>> salesLogs;
  final bool isLoadingSales;
  final String cashierName;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<POSProduct> onAddToCart;
  final VoidCallback onShowCartSummary;
  final Function(OrderItem item, int newQuantity) onUpdateItemQuantity;
  final Function(OrderItem item) onRemoveItem;
  final VoidCallback onClearCart;
  final Future<void> Function({
    required String customerName,
    required String customerType,
    required String paymentMethod,
    required double tenderedAmount,
    required double changeAmount,
    required Order order,
  }) onCompleteSale;
  final Future<void> Function() onRefresh;

  const CashierPOSTab({
    super.key,
    required this.allProducts,
    required this.categories,
    required this.selectedCategory,
    required this.currentOrder,
    required this.showSalesHistory,
    required this.salesLogs,
    required this.isLoadingSales,
    required this.cashierName,
    required this.onCategorySelected,
    required this.onAddToCart,
    required this.onShowCartSummary,
    required this.onUpdateItemQuantity,
    required this.onRemoveItem,
    required this.onClearCart,
    required this.onCompleteSale,
    required this.onRefresh,
  });

  @override
  State<CashierPOSTab> createState() => _CashierPOSTabState();
}

class _CashierPOSTabState extends State<CashierPOSTab> {
  static const Color _brandNavy = Color(0xFF18314F);
  static const Color _cardBorder = Color(0xFFE2E8F0);

  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, int> _productQuantities = {};
  bool _viewSalesHistory = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  int _getQuantity(String productId) {
    return _productQuantities[productId] ?? 1;
  }

  void _incrementProductQuantity(POSProduct product) {
    if (product.units <= 0) return;
    final current = _getQuantity(product.id);
    final inCart = widget.currentOrder.quantityFor(product.id);
    final available = product.units - inCart;
    if (current < available && current < product.units) {
      setState(() {
        _productQuantities[product.id] = current + 1;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot exceed available stock (${product.units} units).'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }
  }

  void _decrementProductQuantity(String productId) {
    final current = _getQuantity(productId);
    if (current > 1) {
      setState(() {
        _productQuantities[productId] = current - 1;
      });
    }
  }

  bool _isProductTopSeller(POSProduct product) {
    if (product.sold <= 0) return false;
    final sorted = List<POSProduct>.from(widget.allProducts.where((p) => !p.isArchived))
      ..sort((a, b) => b.sold.compareTo(a.sold));
    final topRank = sorted.indexWhere((p) => p.id == product.id);
    return topRank >= 0 && topRank < 3;
  }

  void _openCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCartModal(),
    );
  }

  void _openCheckoutModal() {
    if (widget.currentOrder.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty. Please add items to proceed.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CashierCheckoutModal(
        currentOrder: widget.currentOrder,
        cashierName: widget.cashierName,
        onConfirmCheckout: ({
          required customerName,
          required customerType,
          required paymentMethod,
          required tenderedAmount,
          required changeAmount,
          required order,
        }) async {
          await widget.onCompleteSale(
            customerName: customerName,
            customerType: customerType,
            paymentMethod: paymentMethod,
            tenderedAmount: tenderedAmount,
            changeAmount: changeAmount,
            order: order,
          );

          if (!mounted) return;
          final orderSnapshot = List<OrderItem>.from(order.items);
          final totalSnapshot = order.total;
          widget.onClearCart();

          // Show Digital Receipt Modal
          showDialog(
            context: this.context,
            barrierDismissible: false,
            builder: (ctx) => CashierReceiptModal(
              receiptNumber: DateTime.now().millisecondsSinceEpoch.toString().substring(5),
              customerName: customerName,
              cashierName: widget.cashierName,
              timestamp: DateTime.now(),
              items: orderSnapshot,
              totalAmount: totalSnapshot,
              paymentMethod: paymentMethod,
              tenderedAmount: tenderedAmount,
              changeAmount: changeAmount,
              onDone: () {
                Navigator.pop(ctx);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    final modalBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final titleColor = isDark ? Colors.white : _brandNavy;
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final cardBorder = isDark ? const Color(0xFF28354A) : _cardBorder;
    final itemBg = isDark ? const Color(0xFF1B2638) : const Color(0xFFF8FAFC);
    final stepperBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return StatefulBuilder(
      builder: (context, setModalState) {
        final order = widget.currentOrder;

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: modalBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Modal Header (Matching Admin POS Current Order)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Current order',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : _brandNavy).withValues(alpha: isDark ? 0.12 : 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${order.totalItems} ITEMS',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isDark ? const Color(0xFF93C5FD) : _brandNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (order.items.isNotEmpty) ...[
                        TextButton.icon(
                          onPressed: () {
                            widget.onClearCart();
                            setModalState(() {});
                            setState(() {});
                          },
                          icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.red),
                          label: Text(
                            strings.clearCart,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: cardBorder),

                // Cart Items List
                Expanded(
                  child: order.items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'No products added yet.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: subtitleColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          itemCount: order.items.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = order.items[index];

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: itemBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Row(
                                children: [
                                  // Thumbnail
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: item.image != null && item.image!.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(item.image!, fit: BoxFit.cover),
                                          )
                                        : Icon(Icons.inventory_2_rounded, color: titleColor, size: 22),
                                  ),
                                  const SizedBox(width: 12),

                                  // Title & Unit Price
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: titleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_formatCurrency(item.price)} each',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            color: subtitleColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Stepper Controls (- Qty +)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: stepperBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            if (item.quantity > 1) {
                                              widget.onUpdateItemQuantity(item, item.quantity - 1);
                                            } else {
                                              widget.onRemoveItem(item);
                                            }
                                            setModalState(() {});
                                            setState(() {});
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            child: Icon(Icons.remove, size: 14, color: titleColor),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Text(
                                            '${item.quantity}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: titleColor,
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            widget.onUpdateItemQuantity(item, item.quantity + 1);
                                            setModalState(() {});
                                            setState(() {});
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            child: Icon(Icons.add, size: 14, color: titleColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Item Total
                                  SizedBox(
                                    width: 78,
                                    child: Text(
                                      _formatCurrency(item.total),
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Checkout Action Bar
                if (order.items.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    decoration: BoxDecoration(
                      color: modalBg,
                      border: Border(top: BorderSide(color: cardBorder)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Grand Total',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: subtitleColor,
                              ),
                            ),
                            Text(
                              _formatCurrency(order.total),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _openCheckoutModal();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : _brandNavy,
                              foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text(
                              '${strings.checkout} (${_formatCurrency(order.total)})',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    final titleColor = isDark ? Colors.white : _brandNavy;
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final cardBorder = isDark ? const Color(0xFF28354A) : _cardBorder;
    final cardBg = isDark ? const Color(0xFF1B2638) : Colors.white;
    final topBarBg = isDark ? const Color(0xFF151F2E) : Colors.white;

    if (_viewSalesHistory) {
      return Column(
        children: [
          // Header Bar to return to POS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: topBarBg,
              border: Border(bottom: BorderSide(color: cardBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _viewSalesHistory = false),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: titleColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      strings.recentSalesActivity,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.salesLogs.length} Receipts',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: CashierSalesHistoryView(
              salesLogs: widget.salesLogs,
              isLoadingSales: widget.isLoadingSales,
              cashierName: widget.cashierName,
              onBackToPOS: () => setState(() => _viewSalesHistory = false),
            ),
          ),
        ],
      );
    }

    final query = _searchCtrl.text.trim().toLowerCase();
    final activeProducts = widget.allProducts.where((p) => !p.isArchived).toList();

    final filtered = activeProducts.where((p) {
      // Category filter
      if (widget.selectedCategory != 'All' &&
          p.category.toLowerCase() != widget.selectedCategory.toLowerCase()) {
        return false;
      }

      // Search filter
      if (query.isNotEmpty) {
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesDesc = p.description.toLowerCase().contains(query);
        final matchesCat = p.category.toLowerCase().contains(query);
        return matchesName || matchesDesc || matchesCat;
      }
      return true;
    }).toList();

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RefreshIndicator(
            onRefresh: widget.onRefresh,
            color: isDark ? Colors.white : _brandNavy,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16.0,
                14.0,
                16.0,
                widget.currentOrder.items.isNotEmpty ? 110.0 : 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Search Bar & Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (_) => setState(() {}),
                            textCapitalization: TextCapitalization.words,
                            inputFormatters: const [CapitalizeWordsInputFormatter()],
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: titleColor),
                            decoration: InputDecoration(
                              hintText: strings.searchProducts,
                              hintStyle: GoogleFonts.plusJakartaSans(color: subtitleColor, fontSize: 12),
                              prefixIcon: Icon(Icons.search, color: subtitleColor, size: 20),
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Sales History / Receipts Button
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorder),
                        ),
                        child: IconButton(
                          onPressed: () => setState(() => _viewSalesHistory = true),
                          icon: Icon(Icons.receipt_long_rounded, color: titleColor, size: 22),
                          tooltip: 'Sales History',
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Cart Icon Button with Live Counter Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 46,
                            width: 46,
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: widget.currentOrder.items.isNotEmpty
                                    ? (isDark ? Colors.white : _brandNavy.withValues(alpha: 0.4))
                                    : cardBorder,
                              ),
                            ),
                            child: IconButton(
                              onPressed: _openCartBottomSheet,
                              icon: Icon(Icons.shopping_cart_outlined, color: titleColor, size: 22),
                              tooltip: 'View Cart & Checkout',
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          if (widget.currentOrder.totalItems > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? const Color(0xFF151F2E) : Colors.white, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${widget.currentOrder.totalItems}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Dual Intelligence Action Bar (Matching Admin POS: Demand Forecasting + Best Sellers)
                  Row(
                    children: [
                      // Demand Forecast Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DemandForecastingScreen(isMobileEmbedded: true),
                              ),
                            );
                            widget.onRefresh();
                          },
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2F48) : const Color(0xFFEEF4FD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.insights_rounded,
                                  size: 16,
                                  color: isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Demand Forecast',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Best Sellers Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BestSellersScreen(
                                  initialProducts: widget.allProducts,
                                  isMobileEmbedded: true,
                                ),
                              ),
                            );
                            widget.onRefresh();
                          },
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2F48) : const Color(0xFFEEF4FD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 16,
                                  color: Color(0xFFFF758C),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Best Sellers',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Categories Selector - Balanced full width Row
                  Row(
                    children: widget.categories.map((cat) {
                      final isSelected = widget.selectedCategory.toLowerCase() == cat.toLowerCase();
                      final count = cat == 'All'
                          ? activeProducts.length
                          : activeProducts.where((p) => p.category.toLowerCase() == cat.toLowerCase()).length;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: GestureDetector(
                            onTap: () => widget.onCategorySelected(cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? Colors.white : _brandNavy)
                                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : _brandNavy)
                                      : cardBorder,
                                  width: 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: (isDark ? Colors.white : _brandNavy).withValues(alpha: isDark ? 0.12 : 0.18),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                '$cat ($count)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                      : (isDark ? PiggyTrunkTheme.ptTextDark : const Color(0xFF475569)),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Product Catalog Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filtered.length} Products Available',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      if (widget.currentOrder.totalItems > 0) ...[
                        Text(
                          '${widget.currentOrder.totalItems} in Cart',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Products List - Matching Admin POS Layout
                  filtered.isEmpty
                      ? const CashierEmptyState(
                          message: 'No available products in this category.',
                          icon: Icons.storefront_outlined,
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            final isOutOfStock = product.units <= 0;
                            final isTopSeller = _isProductTopSeller(product);
                            final selectedQty = _getQuantity(product.id);
                            final inCartQty = widget.currentOrder.quantityFor(product.id);

                            return _buildPOSProductCard(
                              product: product,
                              isOutOfStock: isOutOfStock,
                              isTopSeller: isTopSeller,
                              selectedQty: selectedQty,
                              inCartQty: inCartQty,
                              isDark: isDark,
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              titleColor: titleColor,
                              subtitleColor: subtitleColor,
                            );
                          },
                        ),
                ],
              ),
            ),
          ),

          // Bottom Cart & Checkout Bar (Docked flush at the bottom of the screen)
          if (widget.currentOrder.items.isNotEmpty) ...[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : _brandNavy,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: _openCartBottomSheet,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${widget.currentOrder.totalItems} Items Selected',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _formatCurrency(widget.currentOrder.total),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF34D399),
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _openCheckoutModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _brandNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          strings.checkout,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: _brandNavy,
                          ),
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
    );
  }

  // ==================== PRODUCT CARD MATCHING ADMIN POS ====================
  Widget _buildPOSProductCard({
    required POSProduct product,
    required bool isOutOfStock,
    required bool isTopSeller,
    required int selectedQty,
    required int inCartQty,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    final pillBg = isDark ? const Color(0xFF131E2D) : const Color(0xFFF8FAFC);
    final stepperBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: inCartQty > 0
              ? (isDark ? const Color(0xFF60A5FA) : _brandNavy)
              : cardBorder,
          width: inCartQty > 0 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Square Image (1:1 Ratio) with optional TOP badge
          Stack(
            children: [
              Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151F2E) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: product.image != null && product.image!.isNotEmpty
                      ? Image.network(
                          product.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => Center(
                            child: Icon(Icons.inventory_2_rounded, color: subtitleColor, size: 28),
                          ),
                        )
                      : Center(
                          child: Icon(Icons.inventory_2_rounded, color: subtitleColor, size: 28),
                        ),
                ),
              ),
              if (isTopSeller)
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : const Color(0xFF18314F),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      'TOP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Right: Product Details & Actions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title + Stock Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? (isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.16) : const Color(0xFFFEF3C7))
                            : (product.units <= 10
                                ? (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.16) : const Color(0xFFFEE2E2))
                                : (isDark ? const Color(0xFF10B981).withValues(alpha: 0.16) : const Color(0xFFECFDF5))),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOutOfStock
                            ? 'OUT OF STOCK'
                            : (product.units <= 10 ? 'LOW STOCK' : 'IN STOCK'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isOutOfStock
                              ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706))
                              : (product.units <= 10
                                  ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                                  : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Category & Description
                Text(
                  product.description.isEmpty ? '${product.category} • Warehouse stock' : product.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 6),

                // Price & Stock Info Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'PRICE: ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: subtitleColor,
                            ),
                          ),
                          Text(
                            '₱${product.price.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Stock: ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: subtitleColor,
                            ),
                          ),
                          Text(
                            '${product.units} units',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isOutOfStock
                                  ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706))
                                  : (product.units <= 10
                                      ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                                      : titleColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Quantity Stepper & Add to Order Action Row
                Row(
                  children: [
                    // Stepper (- Qty +)
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: stepperBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: isOutOfStock || selectedQty <= 1
                                ? null
                                : () => _decrementProductQuantity(product.id),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Icon(
                                Icons.remove_rounded,
                                size: 14,
                                color: (isOutOfStock || selectedQty <= 1) ? subtitleColor.withValues(alpha: 0.4) : titleColor,
                              ),
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 24),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              '$selectedQty',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isOutOfStock ? subtitleColor : titleColor,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: isOutOfStock || selectedQty >= product.units
                                ? null
                                : () => _incrementProductQuantity(product),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: (isOutOfStock || selectedQty >= product.units) ? subtitleColor.withValues(alpha: 0.4) : titleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Add to Order Button
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: isOutOfStock
                              ? null
                              : () {
                                  final qtyToAdd = _getQuantity(product.id);
                                  final currentQtyInCart = widget.currentOrder.quantityFor(product.id);
                                  if (currentQtyInCart + qtyToAdd > product.units) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Cannot add $qtyToAdd item(s). Only ${product.units - currentQtyInCart} remaining in stock.',
                                        ),
                                        backgroundColor: const Color(0xFFEF4444),
                                        duration: const Duration(milliseconds: 1200),
                                      ),
                                    );
                                    return;
                                  }

                                  for (int i = 0; i < qtyToAdd; i++) {
                                    widget.onAddToCart(product);
                                  }
                                  setState(() {
                                    _productQuantities[product.id] = 1;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${qtyToAdd}x ${product.name} added to order'),
                                      backgroundColor: isDark ? const Color(0xFF1E3A8A) : const Color(0xFF315C8F),
                                      duration: const Duration(milliseconds: 800),
                                    ),
                                  );
                                },
                          icon: Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 14,
                            color: isOutOfStock
                                ? subtitleColor
                                : (isDark ? const Color(0xFF0F172A) : Colors.white),
                          ),
                          label: Text(
                            isOutOfStock ? 'Out of Stock' : '+ Add to Order',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isOutOfStock
                                  ? subtitleColor
                                  : (isDark ? const Color(0xFF0F172A) : Colors.white),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isOutOfStock
                                ? (isDark ? const Color(0xFF1E293B) : Colors.grey[300])
                                : (isDark ? Colors.white : _brandNavy),
                            foregroundColor: isOutOfStock
                                ? subtitleColor
                                : (isDark ? const Color(0xFF0F172A) : Colors.white),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
