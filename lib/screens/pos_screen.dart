import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pos_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_toast.dart';
import '../utils/inventory_data_adapter.dart';
import '../utils/responsive.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/screen_top_bar.dart';
import '../main.dart';
import '../widgets/common/shimmer_loading.dart';
import 'best_sellers_screen.dart';
import 'demand_forecasting_screen.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Order currentOrder = Order(items: []);

  List<POSProduct> _products = [];
  final Map<String, int> _productQuantities = {};
  final Map<String, String> _productUnits = {}; // productId -> 'sack' or 'kg'
  bool _isLoading = true;
  int _orderItemCounter = 0;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? PiggyTrunkTheme.ptBgDark : const Color(0xFFF4F7FB);
  Color get _surface => _isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
  Color get _surfaceSoft => _isDark ? PiggyTrunkTheme.ptSurfaceDark.withValues(alpha: 0.5) : const Color(0xFFF8FBFF);
  Color get _border => _isDark ? PiggyTrunkTheme.ptBorderDark : const Color(0xFFD7E3F3);
  Color get _text => _isDark ? PiggyTrunkTheme.ptTextDark : const Color(0xFF18314F);
  Color get _muted => _isDark ? PiggyTrunkTheme.ptMutedDark : const Color(0xFF6F8096);

  String _getSelectedUnit(POSProduct product) {
    if (!product.isFeed) return 'unit';
    return _productUnits[product.id] ?? 'sack';
  }

  void _setSelectedUnit(POSProduct product, String unit) {
    if (_productUnits[product.id] == unit) return;
    setState(() {
      _productUnits[product.id] = unit;
      _productQuantities[product.id] = 1;
    });
  }

  int _getQuantity(String productId) {
    return _productQuantities[productId] ?? 1;
  }

  int _getMaxAvailable(POSProduct product, String unit) {
    if (unit == 'kg') {
      final totalKg = product.units * 50;
      final inCartKg = currentOrder.quantityFor(product.id, 'kg');
      final inCartSack = currentOrder.quantityFor(product.id, 'sack');
      final availableKg = totalKg - inCartKg - (inCartSack * 50);
      return availableKg.clamp(0, 999999);
    } else {
      final inCartSack = currentOrder.quantityFor(product.id, 'sack');
      final inCartKg = currentOrder.quantityFor(product.id, 'kg');
      final usedSacks = inCartSack + (inCartKg / 50.0).ceil();
      final availableSacks = product.units - usedSacks;
      return availableSacks.clamp(0, product.units);
    }
  }

  void _incrementProductQuantity(POSProduct product) {
    if (product.units <= 0) return;
    final unit = _getSelectedUnit(product);
    final current = _getQuantity(product.id);
    final maxAvail = _getMaxAvailable(product, unit);

    if (current < maxAvail) {
      setState(() {
        _productQuantities[product.id] = current + 1;
      });
    } else {
      _showThemedSnackBar(
        unit == 'kg'
            ? 'Cannot exceed remaining stock ($maxAvail kg).'
            : 'Cannot exceed remaining stock ($maxAvail sacks).',
        backgroundColor: const Color(0xFFE53E3E),
        duration: const Duration(milliseconds: 900),
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

  @override
  void initState() {
    super.initState();
    final session = _supabase.auth.currentSession;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return;
    }
    if (isInitialLaunch) {
      isInitialLaunch = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      });
      return;
    }
    _loadProductsFromInventory();
  }

  void _showThemedSnackBar(String message, {Color? backgroundColor, Duration? duration, String? title}) {
    if (!mounted) return;
    final isError = backgroundColor == Colors.red || backgroundColor == const Color(0xFFE53E3E);
    final isWarning = backgroundColor == Colors.orange || backgroundColor == const Color(0xFFF59E0B);
    final isSuccess = backgroundColor == Colors.green ||
        backgroundColor == const Color(0xFF10B981) ||
        message.toLowerCase().contains('added') ||
        message.toLowerCase().contains('success') ||
        message.toLowerCase().contains('completed');

    if (isError) {
      AppToast.error(context, message, title: title, duration: duration);
    } else if (isWarning) {
      AppToast.warning(context, message, title: title, duration: duration);
    } else if (isSuccess) {
      AppToast.success(context, message, title: title, duration: duration);
    } else {
      AppToast.info(context, message, title: title, duration: duration);
    }
  }

  Future<void> _loadProductsFromInventory() async {
    setState(() => _isLoading = true);
    try {
      final response = await _loadInventoryRows();
      final rows = response
          .map((row) => POSProduct.fromJson(row))
          .toList();

      if (!mounted) return;
      setState(() => _products = rows);
    } catch (e) {
      if (!mounted) return;
      _showThemedSnackBar('Failed to load POS products: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadInventoryRows() async {
    try {
      final response = await _supabase
          .from('inventory_products')
          .select()
          .order('created_at', ascending: false);

      final rows = (response as List).where((row) {
        final isArchived = row['is_archived'] == true;
        return !isArchived;
      }).toList();
      return normalizeInventoryRows(rows, sourceTable: 'inventory_products');
    } catch (e) {
      final fallbackResponse = await _supabase.from('products').select();
      final fallbackRows = (fallbackResponse as List).where((row) {
        final isArchived = row['is_archived'] == true;
        return !isArchived;
      }).toList();
      return normalizeInventoryRows(fallbackRows, sourceTable: 'products');
    }
  }

  int _categoryWeight(String category) {
    final cat = category.trim().toLowerCase();
    if (cat == 'feeds' || cat == 'feed') return 0;
    if (cat == 'medicines' || cat == 'medicine') return 1;
    if (cat == 'vitamins' || cat == 'vitamin') return 2;
    if (cat == 'others' || cat == 'other') return 3;
    return 4;
  }

  List<String> get _categories {
    final categorySet = _products.map((p) => p.category.trim()).where((c) => c.isNotEmpty).toSet();
    final sorted = categorySet.toList()..sort((a, b) {
      final weightA = _categoryWeight(a);
      final weightB = _categoryWeight(b);
      if (weightA != weightB) {
        return weightA.compareTo(weightB);
      }
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return sorted;
  }

  List<POSProduct> _productsByCategory(String category) {
    final list = _products.where((p) => p.category.toLowerCase() == category.toLowerCase()).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  bool _isProductTopSeller(POSProduct product) {
    if (product.sold <= 0) return false;
    final sorted = List<POSProduct>.from(_products)..sort((a, b) => b.sold.compareTo(a.sold));
    final topRank = sorted.indexWhere((p) => p.id == product.id);
    return topRank >= 0 && topRank < 3;
  }

  void _clearOrder() {
    if (currentOrder.items.isEmpty) return;
    setState(() {
      currentOrder.clearOrder();
      _orderItemCounter = 0;
    });
    _showThemedSnackBar('Order cleared.', backgroundColor: Colors.orange);
  }

  Future<void> _completeTransaction() async {
    if (currentOrder.items.isEmpty) {
      _showThemedSnackBar('No items in the order yet.', backgroundColor: Colors.red);
      return;
    }

    final itemCount = currentOrder.totalItems;
    final total = currentOrder.total;
    final itemsToDeduct = List<OrderItem>.from(currentOrder.items);
    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    final cashierEmail = _supabase.auth.currentUser?.email ?? 'Cashier Admin';
    final nowIso = DateTime.now().toIso8601String();

    setState(() {
      _isLoading = true;
    });

    try {
      for (final item in itemsToDeduct) {
        final product = _products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => POSProduct(
            id: item.productId,
            name: item.productName,
            categoryId: '',
            category: '',
            description: '',
            price: item.price,
            units: 0,
            sold: 0,
          ),
        );

        // Calculate inventory sack deduction (for 'kg', 50 kg = 1 sack)
        final int sacksDeducted = item.unit == 'kg'
            ? (item.quantity / 50.0).ceil().clamp(1, product.units)
            : item.quantity;
        final newUnits = (product.units - sacksDeducted).clamp(0, 999999);
        final newSold = product.sold + sacksDeducted;

        // 1. Insert historical sale record into pos_sales table for demand forecasting
        try {
          await _supabase.from('pos_sales').insert({
            'order_id': orderId,
            'product_id': product.id,
            'product_name': product.name,
            'category': product.category.isNotEmpty ? product.category : 'Feeds',
            'quantity': item.quantity,
            'unit_price': item.price,
            'total_amount': item.subtotal,
            'sale_date': nowIso,
            'customer_name': 'Walk-in Customer',
            'customer_type': 'Walk-in',
            'payment_method': 'Cash',
            'cashier_name': cashierEmail,
            'created_at': nowIso,
          });
        } catch (e) {
          debugPrint('pos_sales insert error: $e');
        }

        // 2. Deduct inventory stock units
        try {
          await _supabase.from('inventory_products').update({
            'units': newUnits,
            'sold': newSold,
          }).eq('id', product.id);
        } catch (_) {
          await _supabase.from('products').update({
            'units': newUnits,
            'sold': newSold,
          }).eq('id', product.id);
        }

        // 3. Log into inventory_logs
        try {
          await _supabase.from('inventory_logs').insert({
            'product_id': product.id,
            'product_name': product.name,
            'action': 'SALE',
            'performed_by': cashierEmail,
            'price': item.price,
            'units': sacksDeducted,
            'details': item.unit == 'kg'
                ? 'POS Retail Sale: Sold ${item.quantity} kg ($sacksDeducted sack(s) opened/deducted). Remaining: $newUnits sacks.'
                : 'POS Wholesale Sale: Sold ${item.quantity} sack(s). Remaining: $newUnits sacks.',
          });
        } catch (_) {}
      }

      setState(() {
        currentOrder.clearOrder();
        _orderItemCounter = 0;
      });

      await _loadProductsFromInventory();

      if (!mounted) return;
      _showThemedSnackBar(
        'Transaction completed! Deducted stock for $itemCount item(s). Total: PHP ${total.toStringAsFixed(2)}',
        backgroundColor: PiggyTrunkTheme.ptSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      _showThemedSnackBar('Error completing transaction: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = Responsive.isSmallScreen(context);

    return Scaffold(
      backgroundColor: _bg,
      drawer: isSmall
          ? Drawer(
              backgroundColor: _surface,
              child: AdminSidebar(
                currentRoute: '/pos',
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
                    currentRoute: '/pos',
                    onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 800;
                      final rightPanelWidth = constraints.maxWidth > 1300
                          ? 380.0
                          : (constraints.maxWidth > 1050 ? 340.0 : 310.0);

                      if (_isLoading) {
                        return _buildPosSkeleton(isMobile, rightPanelWidth);
                      }

                      if (isMobile) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(Responsive.isMobile(context) ? 10 : 16),
                          child: Column(
                            children: [
                              _buildProductsPanel(EdgeInsets.zero),
                              const SizedBox(height: 16),
                              Container(
                                constraints: const BoxConstraints(minHeight: 480),
                                child: _buildCurrentOrderPanel(context, stacked: true),
                              ),
                            ],
                          ),
                        );
                      }

                      // Laptop & Desktop layout (14-inch laptops, 1366x768, 1080p, etc.)
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Column: Always scrollable product catalog - prevents any bottom overflow
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              child: _buildProductsPanel(EdgeInsets.zero),
                            ),
                          ),
                          Container(width: 1, color: _border),
                          // Right Column: Current Order panel always docked on the side
                          SizedBox(
                            width: rightPanelWidth,
                            child: _buildCurrentOrderPanel(context),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsPanel(EdgeInsets padding) {
    final isMobile = Responsive.isMobile(context);
    return Padding(
      padding: padding,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _surfaceSoft,
          border: Border.all(
            color: _border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
        ),
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'POS',
                  style: AppTextStyles.sectionTitle(_text),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                const DemandForecastingScreen(),
                            settings: const RouteSettings(name: '/forecasting'),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                        _loadProductsFromInventory();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                        decoration: BoxDecoration(
                          color: _isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.insights_rounded,
                              size: 16,
                              color: _isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Sales Forecast Summary',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                BestSellersScreen(initialProducts: _products),
                            settings: const RouteSettings(name: '/best-sellers'),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                        _loadProductsFromInventory();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                        decoration: BoxDecoration(
                          color: _isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 16,
                              color: _isDark ? const Color(0xFFFFAA00) : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Best Sellers',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
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
            const SizedBox(height: 20),
            _buildAllCategoryProducts(),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCategoryProducts() {
    final categories = _categories;

    if (categories.isEmpty) {
      return Text(
        'No available products from Inventory yet.',
        style: AppTextStyles.body(_muted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(categories.length, (index) {
        final category = categories[index];
        final products = _productsByCategory(category);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  category,
                  style: AppTextStyles.jakarta(
                    size: 18,
                    weight: FontWeight.w800,
                    letterSpacing: -0.02,
                    color: _text,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${products.length})',
                  style: AppTextStyles.jakarta(
                    size: 14,
                    weight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (products.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No available products.',
                  style: AppTextStyles.body(_muted),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  int crossAxisCount;
                  double childAspectRatio;

                  if (width > 1200) {
                    crossAxisCount = 3;
                    childAspectRatio = 1.48;
                  } else if (width > 850) {
                    crossAxisCount = 2;
                    childAspectRatio = 1.78;
                  } else if (width > 550) {
                    crossAxisCount = 2;
                    childAspectRatio = 1.55;
                  } else {
                    crossAxisCount = 1;
                    childAspectRatio = 1.70;
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, idx) => _buildPOSProductCard(products[idx]),
                  );
                },
              ),
            if (index != categories.length - 1) const SizedBox(height: 32),
          ],
        );
      }),
    );
  }

  Widget _buildPOSProductCard(POSProduct product) {
    final isOutOfStock = product.units <= 0;
    final isTopSeller = _isProductTopSeller(product);
    final Color stockColor = isOutOfStock
        ? const Color(0xFFFFAA00)
        : (product.units <= 10 ? const Color(0xFFFF758C) : const Color(0xFF43CB89));
    final isMobile = Responsive.isMobile(context);
    final double imgSize = isMobile ? 76.0 : 88.0;
    final selectedUnit = _getSelectedUnit(product);
    final isKilo = selectedUnit == 'kg';
    final hasKiloPrice = product.hasKiloPrice;
    final selectedQty = _getQuantity(product.id);
    final double unitPrice = isKilo ? product.effectiveKiloPrice : product.price;
    final int maxAvailable = _getMaxAvailable(product, selectedUnit);
    final bool canAddToCart = !isOutOfStock && maxAvailable > 0 && (!isKilo || hasKiloPrice);

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border, width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Section: Image + Title + Status + Description
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image (Square 1:1)
              Stack(
                children: [
                  Container(
                    width: imgSize,
                    height: imgSize,
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border.withValues(alpha: 0.8)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: product.image != null && product.image!.isNotEmpty
                          ? Image.network(
                              product.image!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Icon(Icons.broken_image_outlined, color: _muted, size: 26),
                              ),
                            )
                          : Center(
                              child: Icon(Icons.image_outlined, color: _muted, size: 26),
                            ),
                    ),
                  ),
                  if (isTopSeller)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                          borderRadius: BorderRadius.circular(5),
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
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: isMobile ? 10 : 12),
              // Product Title & Subtitles
              Expanded(
                child: SizedBox(
                  height: imgSize,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Title & Stock Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: AppTextStyles.jakarta(
                                size: isMobile ? 12 : 13,
                                weight: FontWeight.w800,
                                color: _text,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 5 : 7,
                              vertical: isMobile ? 2 : 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: stockColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: stockColor.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: stockColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOutOfStock
                                      ? 'OUT'
                                      : (product.units <= 10 ? 'LOW' : 'IN STOCK'),
                                  style: AppTextStyles.jakarta(
                                    size: isMobile ? 8 : 8.5,
                                    weight: FontWeight.w800,
                                    color: stockColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Subtitle / Description
                      Text(
                        product.description.isEmpty ? 'No description' : product.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.jakarta(
                          size: isMobile ? 10.5 : 11,
                          weight: FontWeight.w500,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Unit Selector (Only for Feeds category, pure text without icons)
          if (product.isFeed) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border.withValues(alpha: 0.7)),
              ),
              padding: const EdgeInsets.all(2.5),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _setSelectedUnit(product, 'sack'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !isKilo
                              ? (_isDark ? PiggyTrunkTheme.ptPrimary : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: !isKilo
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          'Whole Sack',
                          style: AppTextStyles.jakarta(
                            size: isMobile ? 10.5 : 11.5,
                            weight: !isKilo ? FontWeight.w800 : FontWeight.w600,
                            color: !isKilo
                                ? (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
                                : _muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => _setSelectedUnit(product, 'kg'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isKilo
                              ? (_isDark ? PiggyTrunkTheme.ptPrimary : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: isKilo
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          'Per Kilo',
                          style: AppTextStyles.jakarta(
                            size: isMobile ? 10.5 : 11.5,
                            weight: isKilo ? FontWeight.w800 : FontWeight.w600,
                            color: isKilo
                                ? (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
                                : _muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Price & Stock Row
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: isMobile ? 4 : 5),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'PRICE: ',
                          style: AppTextStyles.jakarta(size: 10.5, weight: FontWeight.w700, color: _muted),
                        ),
                        Text(
                          isKilo && !hasKiloPrice
                              ? 'Not set for per kilo'
                              : '₱${unitPrice.toStringAsFixed(2)}${isKilo ? '/kg' : ''}',
                          style: AppTextStyles.jakarta(
                            size: isKilo && !hasKiloPrice ? 11 : 12.5,
                            weight: FontWeight.w800,
                            color: isKilo && !hasKiloPrice ? const Color(0xFFFFAA00) : _text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Stock: ',
                          style: AppTextStyles.jakarta(size: 10.5, weight: FontWeight.w700, color: _muted),
                        ),
                        Text(
                          isKilo ? '${product.units * 50} kg' : '${product.units} units',
                          style: AppTextStyles.jakarta(
                            size: 11.5,
                            weight: FontWeight.w700,
                            color: isOutOfStock
                                ? const Color(0xFFFFAA00)
                                : (product.units <= 10 ? const Color(0xFFFF758C) : _text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Quantity Stepper Row
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: isMobile ? 3 : 4),
            decoration: BoxDecoration(
              color: _bg,
              border: Border.all(color: _border.withValues(alpha: 0.7), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    isKilo ? 'Qty (kg):' : 'Qty:',
                    style: AppTextStyles.jakarta(
                      size: isMobile ? 10.5 : 11.5,
                      weight: FontWeight.w700,
                      color: _muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _border, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: isOutOfStock || selectedQty <= 1 || (isKilo && !hasKiloPrice)
                            ? null
                            : () => _decrementProductQuantity(product.id),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 14,
                            color: (isOutOfStock || selectedQty <= 1 || (isKilo && !hasKiloPrice))
                                ? (_isDark ? Colors.white24 : Colors.black26)
                                : (_isDark ? Colors.white : const Color(0xFF18314F)),
                          ),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 24),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '$selectedQty',
                          style: AppTextStyles.jakarta(
                            size: 12,
                            weight: FontWeight.w800,
                            color: (isOutOfStock || (isKilo && !hasKiloPrice)) ? _muted : _text,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: isOutOfStock || selectedQty >= maxAvailable || (isKilo && !hasKiloPrice)
                            ? null
                            : () => _incrementProductQuantity(product),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          child: Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: (isOutOfStock || selectedQty >= maxAvailable || (isKilo && !hasKiloPrice))
                                ? (_isDark ? Colors.white24 : Colors.black26)
                                : (_isDark ? Colors.white : const Color(0xFF18314F)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Action Button: Add to Cart
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isOutOfStock
                  ? null
                  : (isKilo && !hasKiloPrice)
                      ? () {
                          _showThemedSnackBar(
                            'Please set the per-kilo price for this product in Inventory Management.',
                            backgroundColor: const Color(0xFFF59E0B),
                            duration: const Duration(milliseconds: 2500),
                          );
                        }
                      : (maxAvailable <= 0
                          ? null
                          : () {
                              final qtyToAdd = _getQuantity(product.id);
                              if (qtyToAdd > maxAvailable) {
                                _showThemedSnackBar(
                                  'Cannot add $qtyToAdd ${isKilo ? 'kg' : 'item(s)'}. Only $maxAvailable remaining in stock.',
                                  backgroundColor: const Color(0xFFE53E3E),
                                  duration: const Duration(milliseconds: 1200),
                                );
                                return;
                              }
                              setState(() {
                                _orderItemCounter++;
                                currentOrder.addItem(
                                  OrderItem(
                                    id: _orderItemCounter,
                                    productId: product.id,
                                    productName: isKilo ? '${product.name} (Per Kilo)' : product.name,
                                    price: unitPrice,
                                    quantity: qtyToAdd,
                                    unit: selectedUnit,
                                  ),
                                );
                                _productQuantities[product.id] = 1;
                              });
                              _showThemedSnackBar(
                                '$qtyToAdd${isKilo ? 'kg' : 'x'} ${product.name} added to order',
                                backgroundColor: const Color(0xFF315C8F),
                                duration: const Duration(milliseconds: 800),
                              );
                            }),
              icon: Icon(
                Icons.add_shopping_cart,
                size: 14,
                color: (!canAddToCart && !(isKilo && !hasKiloPrice))
                    ? (_isDark ? Colors.white54 : Colors.white70)
                    : (_isDark ? const Color(0xFF0F1C2F) : Colors.white),
              ),
              label: Text(
                isOutOfStock
                    ? 'Out of Stock'
                    : (isKilo && !hasKiloPrice ? 'Kilo Price Not Set' : '+ Add to Order'),
                style: AppTextStyles.jakarta(
                  size: 11.5,
                  weight: FontWeight.w700,
                  color: (!canAddToCart && !(isKilo && !hasKiloPrice))
                      ? (_isDark ? Colors.white54 : Colors.white70)
                      : (_isDark ? const Color(0xFF0F1C2F) : Colors.white),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOutOfStock
                    ? (_isDark ? const Color(0xFF334155) : Colors.grey)
                    : (isKilo && !hasKiloPrice
                        ? (_isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8))
                        : (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)),
                foregroundColor: (!canAddToCart && !(isKilo && !hasKiloPrice))
                    ? (_isDark ? Colors.white54 : Colors.white70)
                    : (_isDark ? const Color(0xFF0F1C2F) : Colors.white),
                padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 9),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentOrderPanel(BuildContext context, {bool stacked = false}) {
    final isMobile = Responsive.isMobile(context);

    Widget orderItemsContent;
    if (currentOrder.items.isEmpty) {
      orderItemsContent = Padding(
        padding: EdgeInsets.symmetric(vertical: stacked ? 32 : 60, horizontal: 16),
        child: Center(
          child: Text(
            'No products added yet.',
            style: AppTextStyles.caption(PiggyTrunkTheme.ptMutedDark),
          ),
        ),
      );
    } else {
      orderItemsContent = Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Column(
          children: List.generate(
            currentOrder.items.length,
            (index) => _buildOrderItemRow(currentOrder.items[index], index),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: stacked
            ? Border(top: BorderSide(color: _border, width: 1))
            : Border(left: BorderSide(color: _border, width: 1)),
      ),
      child: Column(
        mainAxisSize: stacked ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _border, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current order',
                  style: AppTextStyles.cardTitle(_text),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${currentOrder.totalItems} ITEMS',
                    style: AppTextStyles.jakarta(
                      size: 11,
                      weight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: _muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (stacked)
            orderItemsContent
          else
            Expanded(
              child: SingleChildScrollView(
                child: orderItemsContent,
              ),
            ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _border, width: 1)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: AppTextStyles.bodyStrong(_text),
                    ),
                    Text(
                      'PHP ${currentOrder.total.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyStrong(_text),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isTight = constraints.maxWidth < 360;

                    if (isTight) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _completeTransaction,
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: Text(
                              'Complete Transaction',
                              style: AppTextStyles.jakarta(
                                size: 14,
                                weight: FontWeight.w700,
                                color: _isDark ? const Color(0xFF0F1C2F) : Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              foregroundColor: _isDark ? const Color(0xFF0F1C2F) : Colors.white,
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _clearOrder,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              side: BorderSide(
                                color: _isDark ? const Color(0xFF7F94B2) : PiggyTrunkTheme.ptPrimary,
                                width: 1,
                              ),
                              foregroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Clear Order',
                              style: AppTextStyles.jakarta(
                                size: 14,
                                weight: FontWeight.w700,
                                color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _completeTransaction,
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: Text(
                              'Complete Transaction',
                              style: AppTextStyles.jakarta(
                                size: 14,
                                weight: FontWeight.w700,
                                color: _isDark ? const Color(0xFF0F1C2F) : Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              foregroundColor: _isDark ? const Color(0xFF0F1C2F) : Colors.white,
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _clearOrder,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              side: BorderSide(
                                color: _isDark ? const Color(0xFF7F94B2) : PiggyTrunkTheme.ptPrimary,
                                width: 1,
                              ),
                              foregroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Clear Order',
                              style: AppTextStyles.jakarta(
                                size: 14,
                                weight: FontWeight.w700,
                                color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(OrderItem item, int index) {
    return Padding(
      padding: EdgeInsets.only(bottom: index == currentOrder.items.length - 1 ? 0 : 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _border, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: AppTextStyles.jakarta(size: 13, weight: FontWeight.w600, color: _text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: _muted),
                  tooltip: 'Remove item',
                  onPressed: () {
                    setState(() {
                      currentOrder.removeItem(item.productId, item.unit);
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'PHP ${item.price.toStringAsFixed(2)}${item.unit == 'kg' ? '/kg' : ''}',
                  style: AppTextStyles.jakarta(size: 13, weight: FontWeight.w600, color: _muted),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF4FC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _border, width: 1),
                  ),
                  child: Text(
                    item.unit == 'kg' ? '${item.quantity} kg' : '${item.quantity} ${item.unit == 'sack' ? 'sacks' : 'units'}',
                    style: AppTextStyles.jakarta(
                      size: 12.5,
                      weight: FontWeight.w800,
                      color: _isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosSkeleton(bool isMobile, double rightPanelWidth) {
    return ShimmerProvider(
      child: isMobile
          ? SingleChildScrollView(
              padding: EdgeInsets.all(Responsive.isMobile(context) ? 10 : 16),
              child: Column(
                children: [
                  _buildProductsPanelSkeleton(isMobile),
                  const SizedBox(height: 16),
                  Container(
                    constraints: const BoxConstraints(minHeight: 440),
                    decoration: BoxDecoration(
                      color: _surfaceSoft,
                      border: Border.all(color: _border, width: 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _buildOrderPanelSkeleton(true),
                  ),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildProductsPanelSkeleton(false),
                  ),
                ),
                Container(width: 1, color: _border),
                SizedBox(
                  width: rightPanelWidth,
                  child: _buildOrderPanelSkeleton(false),
                ),
              ],
            ),
    );
  }

  Widget _buildProductsPanelSkeleton(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceSoft,
        border: Border.all(color: _border, width: 1),
        borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('POS', style: AppTextStyles.sectionTitle(_text)),
              Row(
                children: [
                  ShimmerBox(width: 130, height: 34, borderRadius: BorderRadius.circular(10), isDark: _isDark),
                  const SizedBox(width: 8),
                  ShimmerBox(width: 100, height: 34, borderRadius: BorderRadius.circular(10), isDark: _isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 120, height: 18, borderRadius: BorderRadius.circular(4), isDark: _isDark),
              ShimmerBox(width: 60, height: 14, borderRadius: BorderRadius.circular(4), isDark: _isDark),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ShimmerBox(
                              width: double.infinity,
                              height: double.infinity,
                              borderRadius: BorderRadius.circular(10),
                              isDark: _isDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ShimmerBox(width: 110, height: 14, borderRadius: BorderRadius.circular(4), isDark: _isDark),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ShimmerBox(width: 65, height: 15, borderRadius: BorderRadius.circular(4), isDark: _isDark),
                            ShimmerBox(width: 30, height: 30, borderRadius: BorderRadius.circular(8), isDark: _isDark),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPanelSkeleton(bool stacked) {
    return Container(
      color: _surfaceSoft,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 120, height: 20, borderRadius: BorderRadius.circular(4), isDark: _isDark),
              ShimmerBox(width: 26, height: 26, shape: BoxShape.circle, isDark: _isDark),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(3, (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                ShimmerBox(width: 40, height: 40, borderRadius: BorderRadius.circular(8), isDark: _isDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 90, height: 12, borderRadius: BorderRadius.circular(3), isDark: _isDark),
                      const SizedBox(height: 6),
                      ShimmerBox(width: 55, height: 11, borderRadius: BorderRadius.circular(3), isDark: _isDark),
                    ],
                  ),
                ),
                ShimmerBox(width: 45, height: 22, borderRadius: BorderRadius.circular(6), isDark: _isDark),
              ],
            ),
          )),
          const SizedBox(height: 24),
          if (!stacked) const Spacer(),
          Divider(color: _border),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 60, height: 13, borderRadius: BorderRadius.circular(3), isDark: _isDark),
              ShimmerBox(width: 70, height: 13, borderRadius: BorderRadius.circular(3), isDark: _isDark),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 45, height: 16, borderRadius: BorderRadius.circular(4), isDark: _isDark),
              ShimmerBox(width: 90, height: 18, borderRadius: BorderRadius.circular(4), isDark: _isDark),
            ],
          ),
          const SizedBox(height: 16),
          ShimmerBox(width: double.infinity, height: 46, borderRadius: BorderRadius.circular(12), isDark: _isDark),
        ],
      ),
    );
  }
}
