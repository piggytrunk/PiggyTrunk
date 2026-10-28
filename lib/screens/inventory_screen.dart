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
import '../widgets/common/in_page_confirmation_view.dart';
import '../widgets/inventory/product_logs_drawer.dart';
import '../widgets/inventory/product_edit_form.dart';
import '../widgets/inventory/product_restock_form.dart';
import '../widgets/inventory/product_add_form.dart';
import '../widgets/inventory/stock_requests_tab.dart';
import '../widgets/common/shimmer_loading.dart';
import '../widgets/inventory/product_qr_modal.dart';
import '../services/inventory_export_service.dart';
import '../widgets/inventory/inventory_qr_scanner_dialog.dart';
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
  Product? _editingProduct;
  Product? _restockingProduct;
  Widget? _inPageConfirmation;
  bool _showLogsPage = false;
  String? _logsProductId;
  String? _logsProductName;
  int _activeTab = 0; // 0 = Inventory Products, 1 = Raiser Stock Requests
  bool _hasCheckedArgs = false;

  // Filter & Search
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _tableHorizontalScrollCtrl = ScrollController();
  String _selectedCategory = 'All';
  final OverlayPortalController _exportMenuController = OverlayPortalController();
  final LayerLink _exportButtonLink = LayerLink();



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
    _tableHorizontalScrollCtrl.dispose();
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
      _logsProductId = null;
      _logsProductName = null;
      _showLogsPage = true;
    });
  }

  void _openProductLogsDrawer(Product product) {
    setState(() {
      _logsProductId = product.id;
      _logsProductName = product.name;
      _showLogsPage = true;
    });
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

    // 1. In-page Confirmation View (Archive/Restore)
    if (_inPageConfirmation != null) {
      return Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: _inPageConfirmation!,
      );
    }

    // 2. In-page Add Product Form
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

    // 3. In-page Edit Product Form
    if (_editingProduct != null) {
      return ProductEditForm(
        product: _editingProduct!,
        onCancel: () => setState(() => _editingProduct = null),
        onProductUpdated: () {
          setState(() => _editingProduct = null);
          _loadProducts();
        },
        onUploadImage: _uploadProductImage,
        onInsertLog: _insertProductLog,
        onShowSnackBar: _showThemedSnackBar,
        onViewHistory: () {
          final prod = _editingProduct!;
          setState(() {
            _editingProduct = null;
            _logsProductId = prod.id;
            _logsProductName = prod.name;
            _showLogsPage = true;
          });
        },
      );
    }

    // 4. In-page Restock Form
    if (_restockingProduct != null) {
      return ProductRestockForm(
        product: _restockingProduct!,
        onCancel: () => setState(() => _restockingProduct = null),
        onRestocked: () {
          setState(() => _restockingProduct = null);
          _loadProducts();
        },
        onInsertLog: _insertProductLog,
        onShowSnackBar: _showThemedSnackBar,
        onViewHistory: () {
          final prod = _restockingProduct!;
          setState(() {
            _restockingProduct = null;
            _logsProductId = prod.id;
            _logsProductName = prod.name;
            _showLogsPage = true;
          });
        },
      );
    }

    // 5. In-page Activity Logs
    if (_showLogsPage) {
      return Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: ProductLogsDrawer(
          key: ValueKey(_logsProductId ?? 'all'),
          filterProductId: _logsProductId,
          filterProductName: _logsProductName,
          onClearFilter: () => setState(() {
            _logsProductId = null;
            _logsProductName = null;
          }),
          onClose: () => setState(() => _showLogsPage = false),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_panelStart, _panelEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: _panelBorder, width: 1),
          borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 24,
          vertical: isMobile ? 16 : 26,
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
  }

  List<Product> get _filteredProducts {
    return _products.where((p) {
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
  }

  void _handlePrintPreview() {
    if (_products.isEmpty) {
      _showThemedSnackBar('No inventory items to preview');
      return;
    }

    final userEmail = _supabase.auth.currentUser?.email;
    final exportList = _filteredProducts.isNotEmpty ? _filteredProducts : _products;

    Navigator.of(context).pushNamed(
      '/inventory/print-preview',
      arguments: {
        'products': exportList,
        'adminEmail': userEmail,
      },
    );
  }

  Future<void> _handleExport({required bool isPdf}) async {
    if (_products.isEmpty) {
      _showThemedSnackBar('No inventory items to export');
      return;
    }

    _showThemedSnackBar(
      isPdf ? 'Preparing inventory PDF report...' : 'Generating CSV export...',
    );

    try {
      final userEmail = _supabase.auth.currentUser?.email;
      if (isPdf) {
        await InventoryExportService.exportToPdf(
          _products,
          adminEmail: userEmail,
        );
      } else {
        await InventoryExportService.exportToCsv(_products);
      }
    } catch (e) {
      _showThemedSnackBar('Failed to export inventory: $e', backgroundColor: Colors.red);
    }
  }

  Widget _buildExportDropdownItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        _exportMenuController.hide();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      hoverColor: _isDark ? const Color(0xFF1E2F47) : const Color(0xFFF1F5F9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: _mutedColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return CompositedTransformTarget(
      link: _exportButtonLink,
      child: OverlayPortal(
        controller: _exportMenuController,
        overlayChildBuilder: (context) {
          return CompositedTransformFollower(
            link: _exportButtonLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 6),
            child: Align(
              alignment: Alignment.topRight,
              child: TapRegion(
                onTapOutside: (_) => _exportMenuController.hide(),
                child: SizedBox(
                  width: 260,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    builder: (context, animVal, child) {
                      return Opacity(
                        opacity: animVal,
                        child: Transform.translate(
                          offset: Offset(0, (1.0 - animVal) * -6),
                          child: child,
                        ),
                      );
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: _isDark ? 0.35 : 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildExportDropdownItem(
                              icon: Icons.preview_rounded,
                              iconColor: PiggyTrunkTheme.ptPrimary,
                              title: 'Print Preview',
                              subtitle: 'Interactive formatted preview',
                              onTap: _handlePrintPreview,
                            ),
                            Divider(height: 8, thickness: 1, color: _cardBorder),
                            _buildExportDropdownItem(
                              icon: Icons.table_chart_rounded,
                              iconColor: PiggyTrunkTheme.ptSuccess,
                              title: 'Export as CSV',
                              subtitle: 'Excel / Google Sheets (.csv)',
                              onTap: () => _handleExport(isPdf: false),
                            ),
                            Divider(height: 8, thickness: 1, color: _cardBorder),
                            _buildExportDropdownItem(
                              icon: Icons.picture_as_pdf_rounded,
                              iconColor: PiggyTrunkTheme.ptAccent,
                              title: 'Export as PDF',
                              subtitle: 'Formatted report document (.pdf)',
                              onTap: () => _handleExport(isPdf: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },

        child: InkWell(
          onTap: () {
            if (_exportMenuController.isShowing) {
              _exportMenuController.hide();
            } else {
              _exportMenuController.show();
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD),
              border: Border.all(
                color: _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3),
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.file_download_outlined,
                  size: 18,
                  color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Export',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _isDark ? Colors.white70 : PiggyTrunkTheme.ptPrimary,
                ),
              ],
            ),
          ),
        ),
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
      _buildExportButton(),
        OutlinedButton.icon(
          onPressed: () {
            InventoryQrScannerDialog.show(
              context,
              products: _products,
              onProductScanned: (scannedProd) {
                setState(() {
                  _showLogsPage = false;
                  _showAddProductForm = false;
                  _editingProduct = null;
                  _restockingProduct = scannedProd;
                });
              },
            );
          },
          icon: Icon(
            Icons.qr_code_scanner_rounded,
            size: 18,
            color: _isDark ? PiggyTrunkTheme.ptSuccess : const Color(0xFF16A34A),
          ),
          label: Text(
            'Scan Barcode',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _isDark ? Colors.white : PiggyTrunkTheme.ptText,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: _isDark ? const Color(0xFF16253B) : const Color(0xFFF0FDF4),
            side: BorderSide(
              color: _isDark ? const Color(0xFF1E3A5F) : const Color(0xFFBBF7D0),
              width: 1.2,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 10),
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
        // Summary KPI Metric Cards
        _buildInventoryMetricCards(),
        const SizedBox(height: 20),

        // Controls Row (Search, Category Filters, Archive Toggle)
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
        const SizedBox(height: 20),

        // Horizontal Inventory Table
        if (_isLoading)
          _buildTableSkeleton()
        else if (filteredProducts.isEmpty)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 450),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 54, color: _mutedColor),
                const SizedBox(height: 14),
                Text(
                  'No products found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isArchiveMode
                      ? 'No archived products found in this category.'
                      : 'Try adjusting your search filters or click "+ Add Product".',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    color: _mutedColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          _buildHorizontalInventoryTable(filteredProducts),
      ],
    );
  }

  Widget _buildInventoryMetricCards() {
    final totalProducts = _products.length;
    final inStockCount = _products.where((p) => p.units > 10).length;
    final lowStockCount = _products.where((p) => p.units > 0 && p.units <= 10).length;
    final outOfStockCount = _products.where((p) => p.units <= 0).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;

        final items = [
          _buildMetricCard(
            title: 'TOTAL PRODUCTS',
            value: '$totalProducts',
            subtitle: _isArchiveMode ? 'Archived items' : 'Registered catalog items',
            icon: Icons.inventory_2_outlined,
            accentColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
          ),
          _buildMetricCard(
            title: 'IN STOCK',
            value: '$inStockCount',
            subtitle: 'Healthy inventory (>10)',
            icon: Icons.check_circle_outline_rounded,
            accentColor: PiggyTrunkTheme.ptSuccess,
          ),
          _buildMetricCard(
            title: 'LOW STOCK ALERT',
            value: '$lowStockCount',
            subtitle: 'Needs replenishment (≤10)',
            icon: Icons.warning_amber_rounded,
            accentColor: PiggyTrunkTheme.ptInProgress,
          ),
          _buildMetricCard(
            title: 'OUT OF STOCK',
            value: '$outOfStockCount',
            subtitle: 'Immediate reorder required',
            icon: Icons.error_outline_rounded,
            accentColor: PiggyTrunkTheme.ptAccent,
          ),
        ];

        if (isNarrow) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items
                  .map(
                    (card) => Container(
                      width: 220,
                      margin: const EdgeInsets.only(right: 12),
                      child: card,
                    ),
                  )
                  .toList(),
            ),
          );
        }

        return Row(
          children: items
              .map(
                (card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: card,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: _mutedColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: _mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalInventoryTable(List<Product> products) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minTableWidth = 1180.0;
          final tableWidth = constraints.maxWidth > minTableWidth
              ? constraints.maxWidth
              : minTableWidth;

          return Scrollbar(
            controller: _tableHorizontalScrollCtrl,
            thumbVisibility: constraints.maxWidth < minTableWidth,
            child: SingleChildScrollView(
              controller: _tableHorizontalScrollCtrl,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.6), // Product & Description
                    1: FlexColumnWidth(1.1), // Category
                    2: FlexColumnWidth(1.1), // Price
                    3: FlexColumnWidth(1.1), // Stock Units
                    4: FlexColumnWidth(1.2), // Status Badge
                    5: FlexColumnWidth(0.9), // Total Sold
                    6: FixedColumnWidth(360), // Action Buttons
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // Header Row
                    TableRow(
                      decoration: BoxDecoration(
                        color: _isDark
                            ? const Color(0xFF1B2E48)
                            : const Color(0xFFEDF4FC),
                        border: Border(
                          bottom: BorderSide(color: _cardBorder, width: 1.2),
                        ),
                      ),
                      children: [
                        _tableHeaderCell('PRODUCT & DETAILS'),
                        _tableHeaderCell('CATEGORY'),
                        _tableHeaderCell('UNIT PRICE'),
                        _tableHeaderCell('CURRENT STOCK'),
                        _tableHeaderCell('STATUS', isCenter: true),
                        _tableHeaderCell('TOTAL SOLD', isCenter: true),
                        _tableHeaderCell('ACTIONS', isCenter: true),
                      ],
                    ),
                    // Product Rows
                    for (int i = 0; i < products.length; i++)
                      _buildInventoryTableRow(products[i], i),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tableHeaderCell(String label, {bool isCenter = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Align(
        alignment: isCenter ? Alignment.center : Alignment.centerLeft,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: _isDark ? const Color(0xFFBACCE4) : const Color(0xFF4A6585),
          ),
        ),
      ),
    );
  }

  TableRow _buildInventoryTableRow(Product product, int index) {
    final isEven = index % 2 == 0;
    final rowBg = isEven
        ? _cardBg
        : (_isDark ? const Color(0xFF16253B) : const Color(0xFFF9FBFE));

    return TableRow(
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          bottom: BorderSide(color: _cardBorder.withValues(alpha: 0.6), width: 1),
        ),
      ),
      children: [
        // 1. Product Thumbnail & Name & Description
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _fieldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _cardBorder.withAlpha(90)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: product.image != null && product.image!.isNotEmpty
                      ? Image.network(
                          product.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(Icons.broken_image_outlined, color: _mutedColor, size: 20),
                          ),
                        )
                      : Center(
                          child: Icon(Icons.image_outlined, color: _mutedColor, size: 20),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.description.isEmpty ? 'No description available' : product.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Category Pill
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF1E324F) : const Color(0xFFE8F1FC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isDark ? const Color(0xFF2E4669) : const Color(0xFFCFE1F7),
                ),
              ),
              child: Text(
                product.category,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                ),
              ),
            ),
          ),
        ),

        // 3. Price
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            '₱${product.price.toStringAsFixed(2)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _titleColor,
            ),
          ),
        ),

        // 4. Current Stock Units
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${product.units}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: product.units <= 0
                      ? PiggyTrunkTheme.ptAccent
                      : (product.units <= 10 ? PiggyTrunkTheme.ptInProgress : _titleColor),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'units',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _mutedColor,
                ),
              ),
            ],
          ),
        ),

        // 5. Status Badge (Centered)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: _buildStockBadge(product),
          ),
        ),

        // 6. Total Sold
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: Text(
              '${product.sold}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _mutedColor,
              ),
            ),
          ),
        ),

        // 7. Actions Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: _buildRowActions(product),
        ),
      ],
    );
  }

  Widget _buildRowActions(Product product) {
    const double h = 36;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    final labelStyle = GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700);

    Widget iconBtn({
      required IconData icon,
      required Color color,
      required String tooltip,
      required VoidCallback onPressed,
    }) {
      return SizedBox(
        width: h,
        height: h,
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: h, height: h),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            shape: shape,
            side: BorderSide(color: _panelBorder),
          ),
          icon: Icon(icon, size: 18, color: color),
        ),
      );
    }

    return Row(
      children: [
        // Restock Button (flex: 6 for comfortable text fit)
        Expanded(
          flex: 6,
          child: Tooltip(
            message: 'Restock product',
            child: SizedBox(
              height: h,
              child: ElevatedButton(
                onPressed: () => setState(() {
                  _showLogsPage = false;
                  _showAddProductForm = false;
                  _editingProduct = null;
                  _restockingProduct = product;
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                  foregroundColor: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  elevation: 0,
                  shape: shape,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_shopping_cart, size: 15),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Restock',
                        style: labelStyle,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Edit Button (flex: 5)
        Expanded(
          flex: 5,
          child: Tooltip(
            message: 'Edit product',
            child: SizedBox(
              height: h,
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _showLogsPage = false;
                  _showAddProductForm = false;
                  _restockingProduct = null;
                  _editingProduct = product;
                }),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _panelBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: shape,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 15, color: _titleColor),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Edit',
                        style: labelStyle.copyWith(color: _titleColor),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        iconBtn(
          icon: Icons.qr_code_2_rounded,
          color: _isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
          tooltip: 'View & Print Barcode Label',
          onPressed: () => ProductQrModal.show(context, product),
        ),
        const SizedBox(width: 8),
        iconBtn(
          icon: Icons.history_rounded,
          color: _isDark ? const Color(0xFF9AB1CB) : PiggyTrunkTheme.ptPrimary,
          tooltip: 'Activity Logs',
          onPressed: () => _openProductLogsDrawer(product),
        ),
        const SizedBox(width: 8),
        iconBtn(
          icon: _isArchiveMode ? Icons.unarchive_outlined : Icons.archive_outlined,
          color: _isArchiveMode ? PiggyTrunkTheme.ptSuccess : PiggyTrunkTheme.ptAccent,
          tooltip: _isArchiveMode ? 'Restore Product' : 'Archive Product',
          onPressed: () => _toggleArchiveProduct(product),
        ),
      ],
    );
  }

  Widget _buildTableSkeleton() {
    return ShimmerProvider(
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (int i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    ShimmerBox(width: 44, height: 44, borderRadius: BorderRadius.circular(10), isDark: _isDark),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 160, height: 14, borderRadius: BorderRadius.circular(4), isDark: _isDark),
                          const SizedBox(height: 6),
                          ShimmerBox(width: 100, height: 12, borderRadius: BorderRadius.circular(4), isDark: _isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ShimmerBox(width: 70, height: 24, borderRadius: BorderRadius.circular(8), isDark: _isDark),
                    const SizedBox(width: 24),
                    ShimmerBox(width: 60, height: 16, borderRadius: BorderRadius.circular(4), isDark: _isDark),
                    const SizedBox(width: 24),
                    ShimmerBox(width: 50, height: 16, borderRadius: BorderRadius.circular(4), isDark: _isDark),
                    const SizedBox(width: 24),
                    ShimmerBox(width: 80, height: 22, borderRadius: BorderRadius.circular(11), isDark: _isDark),
                    const SizedBox(width: 24),
                    ShimmerBox(width: 140, height: 30, borderRadius: BorderRadius.circular(8), isDark: _isDark),
                  ],
                ),
              ),
          ],
        ),
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

  void _toggleArchiveProduct(Product product) {
    final isRestore = _isArchiveMode;

    setState(() {
      _inPageConfirmation = InPageConfirmationView(
        title: isRestore ? 'Restore Product' : 'Archive Product',
        message: isRestore
            ? 'Are you sure you want to restore "${product.name}" back to active inventory?'
            : 'Are you sure you want to archive "${product.name}"? It will be hidden from active inventory.',
        actionType: isRestore ? InPageActionType.success : InPageActionType.danger,
        customIcon: isRestore ? Icons.unarchive_outlined : Icons.archive_outlined,
        confirmButtonText: isRestore ? 'Restore Product' : 'Archive Product',
        cancelButtonText: 'Cancel',
        itemTitle: product.name,
        itemSubtitle: '${product.category} • ₱${product.price.toStringAsFixed(2)} • ${product.units} in stock',
        itemImageUrl: product.image,
        showHeader: false,
        onCancel: () => setState(() => _inPageConfirmation = null),
        onConfirm: () async {
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

            if (mounted) {
              setState(() => _inPageConfirmation = null);
              _showThemedSnackBar(
                isRestore ? 'Product "${product.name}" restored successfully.' : 'Product "${product.name}" archived.',
                backgroundColor: isRestore ? PiggyTrunkTheme.ptSuccess : Colors.orange,
              );
              _loadProducts();
            }
          } catch (e) {
            if (mounted) {
              setState(() => _inPageConfirmation = null);
              _showThemedSnackBar('Operation failed: $e', backgroundColor: Colors.red);
            }
          }
        },
      );
    });
  }
}
