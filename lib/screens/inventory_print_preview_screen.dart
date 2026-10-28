import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';
import '../services/inventory_export_service.dart';
import '../theme/app_theme.dart';
import '../utils/inventory_data_adapter.dart';
import '../utils/responsive.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/screen_top_bar.dart';

class InventoryPrintPreviewScreen extends StatefulWidget {
  final List<Product>? products;
  final String? adminEmail;

  const InventoryPrintPreviewScreen({
    super.key,
    this.products,
    this.adminEmail,
  });

  @override
  State<InventoryPrintPreviewScreen> createState() => _InventoryPrintPreviewScreenState();
}

class _InventoryPrintPreviewScreenState extends State<InventoryPrintPreviewScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Product> _products = [];
  String? _adminEmail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _adminEmail = widget.adminEmail ?? _supabase.auth.currentUser?.email;
    if (widget.products != null && widget.products!.isNotEmpty) {
      _products = widget.products!;
      _isLoading = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_products.isEmpty && _isLoading) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        if (args['products'] is List<Product>) {
          setState(() {
            _products = args['products'] as List<Product>;
            _adminEmail = (args['adminEmail'] as String?) ?? _adminEmail;
            _isLoading = false;
          });
          return;
        }
      }
      _fetchProducts();
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase
          .from('inventory_products')
          .select()
          .order('name', ascending: true);

      final normalizedRows = normalizeInventoryRows(
        response as List,
        sourceTable: 'inventory_products',
      );
      final List<Product> loaded = normalizedRows.map((r) => Product.fromJson(r)).toList();

      setState(() {
        _products = loaded;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load inventory: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDirectPrint() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No inventory items to print'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async =>
            InventoryExportService.generateInventoryPdfBytes(
          _products,
          adminEmail: _adminEmail,
        ),
        name: 'Piggy_Trunk_Inventory_${DateTime.now().millisecondsSinceEpoch}',
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger print: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
    final subBarBg = isDark ? const Color(0xFF131D2B) : Colors.white;
    final borderColor = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final textColor = isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText;
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final isSmall = Responsive.isMobile(context) || Responsive.isTablet(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bg,
      drawer: isSmall
          ? Drawer(
              backgroundColor: isDark ? const Color(0xFF1A2940) : Colors.white,
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
          // Standard Global Admin Top Bar across full width
          const ScreenTopBar(),

          // Body beneath Top Bar: Sidebar + Content
          Expanded(
            child: Row(
              children: [
                if (!isSmall)
                  AdminSidebar(
                    currentRoute: '/inventory',
                    onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
                  ),

                // Main Content Area
                Expanded(
                  child: Column(
                    children: [
                      // Sub Header with Back Button and Print Action
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: subBarBg,
                          border: Border(bottom: BorderSide(color: borderColor, width: 1.2)),
                        ),
                        child: Row(
                          children: [
                            if (isSmall)
                              IconButton(
                                icon: Icon(Icons.menu_rounded, color: textColor),
                                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                                tooltip: 'Open Menu',
                              ),

                            // Back to Inventory
                            OutlinedButton.icon(
                              onPressed: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  Navigator.of(context).pushReplacementNamed('/inventory');
                                }
                              },
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                size: 16,
                                color: textColor,
                              ),
                              label: Text(
                                'Back to Inventory',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderColor),
                                backgroundColor: isDark
                                    ? const Color(0xFF1E2F47)
                                    : const Color(0xFFF1F5F9),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),

                            const SizedBox(width: 14),
                            Container(width: 1, height: 24, color: borderColor),
                            const SizedBox(width: 14),

                            // Title & Products count badge
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    'Inventory Print Preview',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      '${_products.length} Products',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? const Color(0xFF90CDF4)
                                            : PiggyTrunkTheme.ptPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Print Button
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _handleDirectPrint,
                              icon: const Icon(Icons.print_rounded, size: 16),
                              label: Text(
                                'Print Document',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PiggyTrunkTheme.ptPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Document Preview
                      Expanded(
                        child: _isLoading
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(strokeWidth: 3),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Compiling full inventory preview...',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color: mutedColor,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _errorMessage != null
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.error_outline_rounded,
                                            size: 48, color: Colors.red[300]),
                                        const SizedBox(height: 12),
                                        Text(
                                          _errorMessage!,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                          onPressed: _fetchProducts,
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  )
                                : PdfPreview(
                                    initialPageFormat: PdfPageFormat.a4,
                                    allowPrinting: false,
                                    allowSharing: false,
                                    canChangePageFormat: false,
                                    canChangeOrientation: false,
                                    canDebug: false,
                                    pdfFileName:
                                        'inventory_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
                                    build: (format) =>
                                        InventoryExportService.generateInventoryPdfBytes(
                                      _products,
                                      adminEmail: _adminEmail,
                                    ),
                                  ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
