import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';
import '../theme/app_theme.dart';
import '../utils/app_toast.dart';
import '../utils/inventory_data_adapter.dart';
import '../utils/responsive.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/slide_over_confirmation_drawer.dart';
import '../widgets/inventory/product_logs_drawer.dart';
import '../widgets/inventory/product_edit_drawer.dart';
import '../widgets/inventory/product_restock_dialog.dart';
import '../widgets/inventory/product_add_form.dart';
import '../widgets/inventory/stock_requests_tab.dart';
import '../widgets/common/shimmer_loading.dart';
import '../main.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const String _table = 'inventory_products';
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Product> _products = [];
  bool _isArchiveMode = false;
  bool _isLoading = true;
  bool _showAddProductForm = false;
  int _activeTab = 0; // 0 = Inventory Products, 1 = Raiser Stock Requests
  bool _hasCheckedArgs = false;

  // Filter & Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';

  // Specific product filter for logs drawer
  String? _logsFilterProductId;
  String? _logsFilterProductName;

  // Theme Helpers
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgDark => _isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
  Color get _panelStart => _isDark ? const Color(0xFF1A2940) : Colors.white;
  Color get _panelEnd => _isDark ? const Color(0xFF0F1C2F) : Colors.white;
  Color get _panelBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);
  Color get _cardBg => _isDark ? const Color(0xFF132238) : Colors.white;
  Color get _cardBorder => _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _mutedColor => _isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
  Color get _fieldBg => _isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
  Color get _fieldText => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _fieldFocus => _isDark ? const Color(0xFF88A7CE) : const Color(0xFF315C8F);

  static const List<String> _categoryOptions = <String>[
    'All',
    'Feeds',
    'Vitamins',
    'Medicines',
    'Others',
  ];

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
    _loadProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedArgs) {
      _hasCheckedArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null) {
        _applyRouteArgs(args);
      }
    }
  }

  void _applyRouteArgs(dynamic args) {
    if (args is String) {
      if (args == 'stock_request' || args == 'stock_requests') {
        setState(() => _activeTab = 1);
      } else if (args == 'products' || args == 'product_catalog') {
        setState(() => _activeTab = 0);
      } else {
        setState(() {
          _activeTab = 0;
          _selectedCategory = 'All';
          _isArchiveMode = false;
        });
        _searchCtrl.text = args.trim();
      }
    } else if (args is Map) {
      final tabVal = args['tab'];
      final bool isStockReq = tabVal == 1 ||
          tabVal == 'stock_request' ||
          tabVal == 'stock_requests' ||
          args['tab_index'] == 1;

      final String? searchKeyword = (args['search'] ?? args['product_name'] ?? args['name'])?.toString();

      setState(() {
        _activeTab = isStockReq ? 1 : 0;
        if (!isStockReq) {
          _selectedCategory = 'All';
          _isArchiveMode = false;
        }
      });

      if (!isStockReq && searchKeyword != null && searchKeyword.trim().isNotEmpty) {
        _searchCtrl.text = searchKeyword.trim();
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _loadInventoryRows();
      final rows = response
          .map((row) => Product.fromJson(row))
          .toList();

      if (!mounted) return;
      setState(() => _products = rows);
    } catch (e) {
      if (!mounted) return;
      _showThemedSnackBar('Failed to load inventory: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadInventoryRows() async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('is_archived', _isArchiveMode)
          .order('created_at', ascending: false);

      final rows = response as List;
      return normalizeInventoryRows(rows, sourceTable: _table);
    } catch (_) {
      final fallbackResponse = await _supabase.from('products').select();
      final fallbackRows = fallbackResponse as List;
      return normalizeInventoryRows(fallbackRows, sourceTable: 'products');
    }
  }

  Future<String?> _uploadProductImage(Uint8List bytes, String fileName) async {
    const bucket = 'product-images';
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'inventory/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    try {
      await _supabase.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('Bucket not found')) {
        throw 'Supabase storage bucket "product-images" is missing. Please create a public storage bucket named "product-images" in your Supabase dashboard.';
      }
      rethrow;
    }
  }

  Future<void> _insertProductLog({
    required String? productId,
    required String productName,
    required String action,
    required double price,
    required int units,
    String? details,
  }) async {
    try {
      final userEmail = _supabase.auth.currentUser?.email ?? 'Unknown Admin';
      await _supabase.from('inventory_logs').insert({
        'product_id': productId,
        'product_name': productName,
        'action': action,
        'performed_by': userEmail,
        'price': price,
        'units': units,
        'details': details,
      });
    } catch (e) {
      debugPrint('Failed to insert product log to Supabase: $e');
    }
  }

  void _showThemedSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    final isError = backgroundColor == Colors.red ||
        backgroundColor == const Color(0xFFEF4444) ||
        backgroundColor == Colors.redAccent ||
        message.toLowerCase().contains('failed') ||
        message.toLowerCase().contains('error');
    final isWarning = backgroundColor == Colors.orange || backgroundColor == const Color(0xFFF59E0B);

    if (isError) {
      AppToast.error(context, message);
    } else if (isWarning) {
      AppToast.warning(context, message);
    } else {
      AppToast.success(context, message);
    }
  }


  void _openGeneralLogsDrawer() {
    setState(() {
      _logsFilterProductId = null;
      _logsFilterProductName = null;
    });
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _openProductLogsDrawer(Product product) {
    setState(() {
      _logsFilterProductId = product.id;
      _logsFilterProductName = product.name;
    });
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = Responsive.isSmallScreen(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bgDark,
      drawer: isSmall
          ? Drawer(
              backgroundColor: _panelStart,
              child: AdminSidebar(
                currentRoute: '/inventory',
                onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
                isDrawer: true,
              ),
            )
          : null,
      endDrawer: ProductLogsDrawer(
        filterProductId: _logsFilterProductId,
        filterProductName: _logsFilterProductName,
        onClearFilter: () {
          setState(() {
            _logsFilterProductId = null;
            _logsFilterProductName = null;
          });
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenTopBar(),
          Expanded(
            child: Row(
              children: [
                if (!isSmall)
                  AdminSidebar(
                    currentRoute: '/inventory',
                    onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
                  ),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final isMobile = Responsive.isMobile(context);

    if (_showAddProductForm) {
      return ProductAddForm(
        onCancel: () => setState(() => _showAddProductForm = false),
        onProductAdded: () {
          setState(() => _showAddProductForm = false);
          _loadProducts();
        },
        onUploadImage: _uploadProductImage,
        onInsertLog: _insertProductLog,
        onShowSnackBar: _showThemedSnackBar,
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth > 1350
              ? 1350.0
              : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: contentWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_panelStart, _panelEnd],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                border: Border.all(color: _panelBorder, width: 1),
                borderRadius: BorderRadius.circular(isMobile ? 16 : 34),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : (constraints.maxWidth < 1100 ? 20 : 30),
                vertical: isMobile ? 16 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Screen Header
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage products, stock supplies & raiser requests',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: _mutedColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildActionButtonsRow(isMobile: true),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inventory',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: _titleColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage products, stock supplies & raiser requests in real-time',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: _mutedColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        _buildActionButtonsRow(isMobile: false),
                      ],
                    ),
              const SizedBox(height: 20),

              // Tabs Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton(0, 'Products Catalog', _products.length, isMobile: isMobile),
                    const SizedBox(width: 8),
                    _buildTabButton(1, 'Raiser Stock Requests', null, isMobile: isMobile),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab Content
              if (_activeTab == 0)
                _buildProductsCatalogView()
              else
                StockRequestsTab(
                  products: _products,
                  onProductsReload: _loadProducts,
                  onShowSnackBar: _showThemedSnackBar,
                  onInsertLog: _insertProductLog,
                ),
            ],
          ),
        ),
      );
    },
  ),
);
  }

  Widget _buildActionButtonsRow({required bool isMobile}) {
    final buttons = [
      OutlinedButton.icon(
        onPressed: _openGeneralLogsDrawer,
        icon: Icon(
          Icons.history_rounded,
          size: 18,
          color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
        ),
        label: Text(
          'Activity Logs',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: _isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD),
          side: BorderSide(
            color: _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3),
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      const SizedBox(width: 10),
      ElevatedButton.icon(
        onPressed: () => setState(() => _showAddProductForm = true),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(
          'Add Product',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
          foregroundColor: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    ];

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: buttons),
      );
    }
    return Row(children: buttons);
  }

  Widget _buildTabButton(int index, String label, int? count, {bool isMobile = false}) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 18,
          vertical: isMobile ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
              : (_isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count != null ? '$label ($count)' : label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isMobile ? 12.5 : 13.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (_isDark ? PiggyTrunkTheme.ptPrimary : Colors.white)
                    : _mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsCatalogView() {
    final isMobile = Responsive.isMobile(context);

    final filteredProducts = _products.where((p) {
      if (_selectedCategory != 'All' && p.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final name = p.name.toLowerCase();
        final desc = p.description.toLowerCase();
        if (!name.contains(q) && !desc.contains(q)) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls Row
        isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.plusJakartaSans(color: _fieldText, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 13.5),
                      prefixIcon: Icon(Icons.search_rounded, color: _mutedColor, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: _mutedColor, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: _fieldBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _fieldFocus, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categoryOptions.map((c) => _buildCategoryFilterChip(c)).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildArchiveToggle(),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.plusJakartaSans(color: _fieldText, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search products by name or description...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: _mutedColor, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: _mutedColor, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: _fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _fieldFocus, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Row(
                    children: _categoryOptions.map((c) => _buildCategoryFilterChip(c)).toList(),
                  ),
                  const SizedBox(width: 14),
                  _buildArchiveToggle(),
                ],
              ),
        const SizedBox(height: 18),

        // Category Sections
        if (_isLoading)
          _buildCatalogSkeleton()
        else if (filteredProducts.isEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: _mutedColor),
                  const SizedBox(height: 12),
                  Text(
                    'No products found',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: _titleColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isArchiveMode ? 'No archived products in this view.' : 'Try adjusting your filters or click "+ Add Product".',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _mutedColor),
                  ),
                ],
              ),
            ),
          )
        else ...[
          for (final cat in _categoryOptions) ...[
            Builder(
              builder: (context) {
                final catProducts = filteredProducts.where((p) => p.category.toLowerCase() == cat.toLowerCase()).toList();
                if (catProducts.isEmpty) return const SizedBox.shrink();

                final screenWidth = MediaQuery.of(context).size.width;
                final isNarrow = screenWidth <= 700;
                final crossAxisCount = screenWidth > 1200 ? 2 : 1;
                final childAspectRatio = screenWidth > 1400 ? 2.6 : (screenWidth > 1100 ? 2.35 : 2.1);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            cat,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _titleColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${catProducts.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    isNarrow
                        ? ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: catProducts.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 14),
                            itemBuilder: (context, index) => _buildProductCard(catProducts[index]),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemCount: catProducts.length,
                            itemBuilder: (context, index) => _buildProductCard(catProducts[index]),
                          ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildCatalogSkeleton() {
    return ShimmerProvider(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int s = 0; s < 2; s++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 12),
              child: Row(
                children: [
                  ShimmerBox(
                    width: 4,
                    height: 24,
                    borderRadius: BorderRadius.circular(2),
                    isDark: _isDark,
                  ),
                  const SizedBox(width: 10),
                  ShimmerBox(
                    width: 140,
                    height: 20,
                    borderRadius: BorderRadius.circular(4),
                    isDark: _isDark,
                  ),
                  const SizedBox(width: 8),
                  ShimmerBox(
                    width: 36,
                    height: 16,
                    borderRadius: BorderRadius.circular(8),
                    isDark: _isDark,
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 600,
                mainAxisExtent: 145,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    border: Border.all(color: _cardBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ShimmerBox(
                        width: 100,
                        height: 110,
                        borderRadius: BorderRadius.circular(12),
                        isDark: _isDark,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ShimmerBox(
                              width: 140,
                              height: 16,
                              borderRadius: BorderRadius.circular(4),
                              isDark: _isDark,
                            ),
                            const SizedBox(height: 8),
                            ShimmerBox(
                              width: 90,
                              height: 14,
                              borderRadius: BorderRadius.circular(4),
                              isDark: _isDark,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ShimmerBox(
                                  width: 65,
                                  height: 22,
                                  borderRadius: BorderRadius.circular(11),
                                  isDark: _isDark,
                                ),
                                const Spacer(),
                                ShimmerBox(
                                  width: 70,
                                  height: 28,
                                  borderRadius: BorderRadius.circular(8),
                                  isDark: _isDark,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(String category) {
    final isSelected = _selectedCategory.toLowerCase() == category.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = category),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 38, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
                : (_isDark ? const Color(0xFF1A2B44) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.transparent : _cardBorder,
              width: 1,
            ),
          ),
          child: Text(
            category,
            style: GoogleFonts.plusJakartaSans(
              color: isSelected
                  ? (_isDark ? PiggyTrunkTheme.ptPrimary : Colors.white)
                  : _mutedColor,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArchiveToggle() {
    final Color bgColor;
    final Color contentColor;
    final Border? border;

    if (_isDark) {
      bgColor = Colors.white;
      contentColor = PiggyTrunkTheme.ptPrimary;
      border = null;
    } else {
      if (_isArchiveMode) {
        bgColor = PiggyTrunkTheme.ptPrimary;
        contentColor = Colors.white;
        border = null;
      } else {
        bgColor = const Color(0xFFF1F5F9);
        contentColor = _mutedColor;
        border = Border.all(color: _cardBorder, width: 1.0);
      }
    }

    return InkWell(
      onTap: () {
        setState(() {
          _isArchiveMode = !_isArchiveMode;
        });
        _loadProducts();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: border,
          boxShadow: _isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              _isArchiveMode ? Icons.arrow_back_rounded : Icons.archive_outlined,
              size: 16,
              color: contentColor,
            ),
            const SizedBox(width: 6),
            Text(
              _isArchiveMode ? 'Back to Inventory' : 'View Archived',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: contentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isMobile = Responsive.isMobile(context);
    final imageSize = isMobile ? 110.0 : 155.0;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _cardBorder, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorder.withAlpha(80)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: product.image != null && product.image!.isNotEmpty
                  ? Image.network(
                      product.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(Icons.broken_image_outlined, color: _mutedColor, size: 28),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.image_outlined, color: _mutedColor, size: 28),
                    ),
            ),
          ),
          SizedBox(width: isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.w800,
                          color: _isDark ? Colors.white : const Color(0xFF3B5B83),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildStockBadge(product, isMobile: isMobile),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  product.description.isEmpty ? 'No description' : product.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 11 : 12,
                    color: _mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: _fieldBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isMobile
                      ? Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PRICE:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _mutedColor,
                                  ),
                                ),
                                Text(
                                  '₱${product.price.toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _titleColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Stock:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _mutedColor,
                                  ),
                                ),
                                Text(
                                  '${product.units} units',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _titleColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'PRICE: ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _mutedColor,
                                  ),
                                ),
                                Text(
                                  '₱${product.price.toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _titleColor,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  'Stock: ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _mutedColor,
                                  ),
                                ),
                                Text(
                                  '${product.units} units',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _titleColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                SizedBox(height: isMobile ? 8 : 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => ProductEditDrawer.show(
                          context: context,
                          existing: product,
                          onUploadImage: _uploadProductImage,
                          onInsertLog: _insertProductLog,
                          onProductUpdated: _loadProducts,
                          onShowSnackBar: _showThemedSnackBar,
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _panelBorder, width: 1.2),
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12, horizontal: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_outlined, size: isMobile ? 13 : 15, color: _mutedColor),
                            const SizedBox(width: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Edit',
                                style: GoogleFonts.plusJakartaSans(
                                  color: _mutedColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: isMobile ? 11 : 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 6 : 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => ProductRestockDialog.show(
                          context: context,
                          products: _products,
                          initialProduct: product,
                          onInsertLog: _insertProductLog,
                          onProductsReload: _loadProducts,
                          onShowSnackBar: _showThemedSnackBar,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                          foregroundColor: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12, horizontal: 2),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_shopping_cart,
                              size: isMobile ? 13 : 15,
                              color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            ),
                            const SizedBox(width: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Restock',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isMobile ? 11 : 13,
                                  color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 6 : 8),
                    Container(
                      width: isMobile ? 36 : 42,
                      height: isMobile ? 36 : 42,
                      decoration: BoxDecoration(
                        border: Border.all(color: _panelBorder, width: 1.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.history_rounded,
                          size: isMobile ? 16 : 18,
                          color: _isDark ? const Color(0xFF9AB1CB) : PiggyTrunkTheme.ptPrimary,
                        ),
                        tooltip: 'View Product History',
                        onPressed: () => _openProductLogsDrawer(product),
                      ),
                    ),
                    SizedBox(width: isMobile ? 6 : 8),
                    Container(
                      width: isMobile ? 36 : 42,
                      height: isMobile ? 36 : 42,
                      decoration: BoxDecoration(
                        border: Border.all(color: _panelBorder, width: 1.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          _isArchiveMode ? Icons.unarchive_outlined : Icons.archive_outlined,
                          size: isMobile ? 16 : 18,
                          color: _isArchiveMode ? PiggyTrunkTheme.ptSuccess : const Color(0xFFFF758C),
                        ),
                        tooltip: _isArchiveMode ? 'Restore Product' : 'Archive Product',
                        onPressed: () => _toggleArchiveProduct(product),
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

  Widget _buildStockBadge(Product product, {bool isMobile = false}) {
    final isOutOfStock = product.units <= 0;
    final lowStock = product.units > 0 && product.units <= 10;
    final fg = isOutOfStock
        ? const Color(0xFFFFAA00)
        : (lowStock ? const Color(0xFFFF758C) : const Color(0xFF43CB89));
    final label = isOutOfStock
        ? 'OUT OF STOCK'
        : (lowStock ? 'LOW STOCK' : 'IN STOCK');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: isMobile ? 3 : 5),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: fg.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isMobile ? 5 : 6,
            height: isMobile ? 5 : 6,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: isMobile ? 4 : 6),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.plusJakartaSans(
              color: fg,
              fontSize: isMobile ? 9 : 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleArchiveProduct(Product product) async {
    final isRestore = _isArchiveMode;
    final confirmed = await SlideOverConfirmationDrawer.show(
      context: context,
      title: isRestore ? 'Restore Product' : 'Archive Product',
      message: isRestore
          ? 'Are you sure you want to restore "${product.name}" back to active inventory?'
          : 'Are you sure you want to archive "${product.name}"? It will be hidden from active inventory.',
      confirmButtonText: isRestore ? 'Restore Product' : 'Archive Product',
      actionType: isRestore ? SlideOverActionType.success : SlideOverActionType.danger,
      customIcon: isRestore ? Icons.unarchive_outlined : Icons.archive_outlined,
    );

    if (confirmed == true) {
      try {
        await _supabase
            .from(_table)
            .update({'is_archived': !isRestore})
            .eq('id', product.id);

        await _insertProductLog(
          productId: product.id,
          productName: product.name,
          action: isRestore ? 'RESTORE' : 'ARCHIVE',
          price: product.price,
          units: product.units,
          details: isRestore ? 'Restored product from archive.' : 'Archived product.',
        );

        _showThemedSnackBar(
          isRestore ? 'Product "${product.name}" restored successfully.' : 'Product "${product.name}" archived.',
          backgroundColor: isRestore ? PiggyTrunkTheme.ptSuccess : Colors.orange,
        );
        _loadProducts();
      } catch (e) {
        _showThemedSnackBar('Operation failed: $e', backgroundColor: Colors.red);
      }
    }
  }
}
