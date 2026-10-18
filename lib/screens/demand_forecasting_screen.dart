import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/forecasting_model.dart';
import '../models/product_model.dart';
import '../services/forecasting_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_toast.dart';
import '../utils/responsive.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/common/shimmer_loading.dart';
import 'pos_screen.dart';
import 'sales_forecast_detail_screen.dart';

enum SalesForecastViewTab {
  topSelling,
  historicalSales,
  forecastSummary,
  financialPlanning,
}

class DemandForecastingScreen extends StatefulWidget {
  final bool isMobileEmbedded;

  const DemandForecastingScreen({
    super.key,
    this.isMobileEmbedded = false,
  });

  @override
  State<DemandForecastingScreen> createState() => _DemandForecastingScreenState();
}

class _DemandForecastingScreenState extends State<DemandForecastingScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ForecastingService _forecastingService;

  List<ProductForecast> _forecasts = [];
  List<Product> _allProducts = [];
  bool _isLoading = true;

  // Active View Tab (Top-Selling Items, Historical Sales, Forecast, Financial Planning)
  SalesForecastViewTab _activeTab = SalesForecastViewTab.topSelling;

  // Practical filters
  int _selectedHorizonDays = 7;
  String _salesFilter = 'All'; // 'All', 'Top Selling', 'Low Selling'
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<String> _salesFilterOptions = <String>[
    'All Products',
    'Top Selling',
    'Low Selling',
  ];

  // System Theme Helpers (identical to InventoryScreen)
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

  @override
  void initState() {
    super.initState();
    _forecastingService = ForecastingService(supabase: _supabase);
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch raw products for restock dialog usage
      final rawProds = await _supabase
          .from('inventory_products')
          .select()
          .eq('is_archived', false)
          .order('name', ascending: true);
      _allProducts = (rawProds as List).map((r) => Product.fromJson(r)).toList();

      // 2. Compute forecasts (uses optimal adaptive exponential smoothing)
      final forecasts = await _forecastingService.calculateForecasts(
        modelType: ForecastModelType.exponentialSmoothing,
        alpha: 0.30,
        horizonDays: _selectedHorizonDays,
      );

      if (!mounted) return;
      setState(() {
        _forecasts = forecasts;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to compute forecasts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Performance classification helpers
  double get _medianSoldUnits {
    if (_forecasts.isEmpty) return 0;
    final values = _forecasts.map((f) => f.calculatedTotalSold.toDouble()).toList()..sort();
    final mid = values.length ~/ 2;
    return values.length % 2 == 1 ? values[mid] : (values[mid - 1] + values[mid]) / 2.0;
  }

  bool _isTopSelling(ProductForecast f) {
    if (_forecasts.isEmpty) return false;
    if (f.calculatedTotalSold <= 0) return false;
    if (_forecasts.length <= 2) {
      final maxSold = _forecasts.map((p) => p.calculatedTotalSold).reduce(max);
      return f.calculatedTotalSold == maxSold && f.calculatedTotalSold > 0;
    }
    final median = _medianSoldUnits;
    return f.calculatedTotalSold > median || (f.calculatedTotalSold == median && f.averageDailySales >= 1.5);
  }

  bool _isLowSelling(ProductForecast f) {
    if (_forecasts.isEmpty) return false;
    if (_forecasts.length <= 2) {
      final minSold = _forecasts.map((p) => p.calculatedTotalSold).reduce(min);
      return f.calculatedTotalSold == minSold;
    }
    final median = _medianSoldUnits;
    return f.calculatedTotalSold < median || (f.calculatedTotalSold == 0);
  }

  List<ProductForecast> get _allRankedForecasts {
    final list = List<ProductForecast>.from(_forecasts);
    list.sort((a, b) {
      final cmp = b.calculatedTotalSold.compareTo(a.calculatedTotalSold);
      if (cmp != 0) return cmp;
      return b.calculatedTotalRevenue.compareTo(a.calculatedTotalRevenue);
    });
    return list;
  }

  int _getSalesRank(ProductForecast f) {
    final ranked = _allRankedForecasts;
    final index = ranked.indexWhere((p) => p.productId == f.productId);
    return index >= 0 ? index + 1 : 1;
  }

  List<String> get _activeTabHeaders {
    switch (_activeTab) {
      case SalesForecastViewTab.topSelling:
        return const [
          'RANK',
          'PRODUCT NAME',
          'CATEGORY',
          'UNITS SOLD',
          'TOTAL SALES / REVENUE',
        ];
      case SalesForecastViewTab.historicalSales:
        return const [
          'PRODUCT / ITEM',
          'DAILY SALES',
          'WEEKLY / MONTHLY',
          'UNITS SOLD',
          'REVENUE PER PRODUCT',
        ];
      case SalesForecastViewTab.forecastSummary:
        return const [
          'PRODUCT / ITEM',
          'FORECASTED DEMAND',
          'EXPECTED NEED',
          'SUGGESTED REORDER',
          'FORECAST PERIOD',
        ];
      case SalesForecastViewTab.financialPlanning:
        return const [
          'PRODUCT / ITEM',
          'HISTORICAL REVENUE',
          'EST. FUTURE SALES',
          'PURCHASING REQ.',
          'EXPECTED SPENDING',
        ];
    }
  }

  List<int> get _activeTabFlexes {
    switch (_activeTab) {
      case SalesForecastViewTab.topSelling:
        return const [1, 3, 3, 2, 2];
      case SalesForecastViewTab.historicalSales:
      case SalesForecastViewTab.forecastSummary:
      case SalesForecastViewTab.financialPlanning:
        return const [3, 2, 2, 2, 2];
    }
  }

  String get _activeTabTitle {
    switch (_activeTab) {
      case SalesForecastViewTab.topSelling:
        return 'Top-Selling Items';
      case SalesForecastViewTab.historicalSales:
        return 'Historical Sales Summary';
      case SalesForecastViewTab.forecastSummary:
        return 'Forecast Summary';
      case SalesForecastViewTab.financialPlanning:
        return 'Financial Planning Summary';
    }
  }

  String get _activeTabSubtitle {
    switch (_activeTab) {
      case SalesForecastViewTab.topSelling:
        return 'Product sales ranking, units sold, and total revenue performance';
      case SalesForecastViewTab.historicalSales:
        return 'Daily, weekly, and monthly sales volume and revenue per product';
      case SalesForecastViewTab.forecastSummary:
        return 'Demand projections, expected units needed, and suggested restock quantities';
      case SalesForecastViewTab.financialPlanning:
        return 'Historical revenue, estimated future sales, and purchasing capital requirements';
    }
  }

  List<ProductForecast> get _filteredForecasts {
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = _forecasts.where((f) {
      if (q.isNotEmpty &&
          !f.productName.toLowerCase().contains(q) &&
          !f.category.toLowerCase().contains(q)) {
        return false;
      }
      if (_salesFilter == 'Top Selling') {
        return _isTopSelling(f);
      } else if (_salesFilter == 'Low Selling') {
        return _isLowSelling(f);
      }
      return true;
    }).toList();

    // Sort based on active tab and filter
    if (_activeTab == SalesForecastViewTab.topSelling) {
      if (_salesFilter == 'Low Selling') {
        list.sort((a, b) => a.calculatedTotalSold.compareTo(b.calculatedTotalSold));
      } else {
        list.sort((a, b) => b.calculatedTotalSold.compareTo(a.calculatedTotalSold));
      }
    } else if (_activeTab == SalesForecastViewTab.historicalSales) {
      if (_salesFilter == 'Low Selling') {
        list.sort((a, b) => a.calculatedTotalRevenue.compareTo(b.calculatedTotalRevenue));
      } else {
        list.sort((a, b) => b.calculatedTotalRevenue.compareTo(a.calculatedTotalRevenue));
      }
    } else if (_activeTab == SalesForecastViewTab.forecastSummary) {
      if (_salesFilter == 'Low Selling') {
        list.sort((a, b) => a.predictedDemand.compareTo(b.predictedDemand));
      } else {
        list.sort((a, b) => b.predictedDemand.compareTo(a.predictedDemand));
      }
    } else if (_activeTab == SalesForecastViewTab.financialPlanning) {
      if (_salesFilter == 'Low Selling') {
        list.sort((a, b) => a.calculatedTotalRevenue.compareTo(b.calculatedTotalRevenue));
      } else {
        list.sort((a, b) => (b.predictedDemand * b.unitPrice).compareTo(a.predictedDemand * a.unitPrice));
      }
    }

    return list;
  }

  // Summary Metrics (2 KPI Cards)
  double get _totalMonthlySales =>
      _forecasts.fold(0.0, (sum, f) => sum + f.calculatedTotalRevenue);

  int get _totalMonthlyUnits =>
      _forecasts.fold(0, (sum, f) => sum + f.calculatedTotalSold);

  double get _estimatedPurchasingCapital {
    return _forecasts.fold(0.0, (sum, f) {
      final qty = f.recommendedReorderQty > 0
          ? f.recommendedReorderQty
          : f.predictedDemand.ceil();
      return sum + (qty * f.unitPrice);
    });
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₱$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMobileEmbedded) {
      return PopScope(
        canPop: true,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: _bgDark,
          body: SafeArea(
            child: _buildMobileLayout(),
          ),
        ),
      );
    }

    final isSmall = Responsive.isSmallScreen(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pushReplacementNamed('/pos');
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _bgDark,
        drawer: isSmall
            ? Drawer(
                child: AdminSidebar(
                  currentRoute: '/pos',
                  isDrawer: true,
                  onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
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
                  Expanded(child: isSmall ? _buildMobileLayout() : _buildMainContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final isMobile = Responsive.isMobile(context) || widget.isMobileEmbedded;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth > 1350
              ? 1350.0
              : double.infinity;
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
                horizontal: isMobile ? 14 : 26,
                vertical: isMobile ? 16 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Screen Header (System Aligned)
                  _buildHeader(isMobile),
                  const SizedBox(height: 24),

                  if (_isLoading) ...[
                    // 2 Practical KPI Summary Cards Skeleton
                    _buildKpiSkeletonSection(isMobile),
                    const SizedBox(height: 24),

                    // Horizon Selector & Filter Controls
                    _buildControlsCard(isMobile),
                    const SizedBox(height: 24),

                    // Sales Forecast Summary Table Skeleton
                    TableSkeletonLoader(
                      isDark: _isDark,
                      minWidth: 940,
                      cardBg: _cardBg,
                      cardBorder: _cardBorder,
                      headerBg: _isDark ? const Color(0xFF1B2E48) : const Color(0xFFEDF4FC),
                      headers: _activeTabHeaders,
                      columnFlexes: _activeTabFlexes,
                      rowCount: 6,
                      borderRadius: 16,
                    ),
                  ] else ...[
                    // 2 Practical KPI Summary Cards
                    _buildKPISection(isMobile),
                    const SizedBox(height: 24),

                    // Horizon Selector & Filter Controls
                    _buildControlsCard(isMobile),
                    const SizedBox(height: 24),

                    // Sales Forecast Summary Matrix Card
                    _buildForecastMatrixCard(isMobile),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Screen Header ---
  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              _buildBackButton(),
              SizedBox(width: isMobile ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Forecast Summary',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 18 : 26,
                        fontWeight: FontWeight.w800,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMobile
                          ? 'Predict product sales & financial planning'
                          : 'Predict product sales demand, top-selling items & financial planning based on POS history',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 11.5 : 13,
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
        const SizedBox(width: 8),
        IconButton(
          onPressed: _isLoading ? null : _loadData,
          icon: _isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                  ),
                )
              : Icon(Icons.refresh_rounded, color: _mutedColor),
          tooltip: 'Refresh Forecast',
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return InkWell(
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const POSScreen(),
              settings: const RouteSettings(name: '/pos'),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Tooltip(
        message: 'Back to POS',
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _fieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cardBorder, width: 1.2),
          ),
          child: Icon(Icons.arrow_back_rounded, size: 20, color: _titleColor),
        ),
      ),
    );
  }

  // --- 2 Practical KPI Summary Cards ---
  Widget _buildKPISection(bool isMobile) {
    final leftCard = _buildKPICard(
      title: 'Total Monthly Sales',
      value: _formatCurrency(_totalMonthlySales),
      subtitle: '$_totalMonthlyUnits total units sold this month',
      icon: Icons.payments_rounded,
      color: const Color(0xFF10B981),
      badgeText: 'MONTHLY TOTAL',
      isMobile: isMobile,
    );

    final rightCard = _buildKPICard(
      title: 'Estimated Purchasing Capital',
      value: _formatCurrency(_estimatedPurchasingCapital),
      subtitle: 'Estimated budget to replenish inventory based on demand',
      icon: Icons.account_balance_wallet_outlined,
      color: _isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
      badgeText: 'RESTOCK CAPITAL',
      isMobile: isMobile,
    );

    if (isMobile) {
      return Column(
        children: [
          leftCard,
          const SizedBox(height: 10),
          rightCard,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: leftCard),
        const SizedBox(width: 14),
        Expanded(child: rightCard),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badgeText,
    bool isMobile = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 18,
        vertical: isMobile ? 10 : 18,
      ),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: _cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 5 : 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: isMobile ? 15 : 20),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 5 : 6,
                    vertical: isMobile ? 2 : 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isMobile ? 7.5 : 10,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 14),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isMobile ? 16 : 22,
              fontWeight: FontWeight.w800,
              color: _titleColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isMobile ? 11 : 13,
              fontWeight: FontWeight.w700,
              color: _titleColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isMobile ? 9.5 : 11.5,
              color: _mutedColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- Horizon & Filter Controls ---
  Widget _buildControlsCard(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder, width: 1.2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isStacked = isMobile || constraints.maxWidth < 720;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Horizon Selector (Expands evenly across available width)
              Row(
                children: [
                  Text(
                    'Forecast Period:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _titleColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildHorizonPill(7, 'Next 7 Days (Weekly)')),
                        const SizedBox(width: 8),
                        Expanded(child: _buildHorizonPill(14, 'Next 14 Days (Bi-weekly)')),
                        const SizedBox(width: 8),
                        Expanded(child: _buildHorizonPill(30, 'Next 30 Days (Monthly)')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: _cardBorder, height: 1),
              const SizedBox(height: 16),

              // Row 2: Search & Performance Filters (All Products, Top Selling, Low Selling)
              if (!isStacked)
                Row(
                  children: [
                    // Search Input (Expands to fill remaining width)
                    Expanded(
                      child: _buildSearchTextField(),
                    ),
                    const SizedBox(width: 12),

                    // Sales Performance Chips
                    Row(
                      children: _salesFilterOptions
                          .map((f) => _buildSalesFilterChip(f))
                          .toList(),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Input
                    _buildSearchTextField(),
                    const SizedBox(height: 12),

                    // Sales Performance Chips in Horizontal Scroll
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _salesFilterOptions
                            .map((f) => _buildSalesFilterChip(f))
                            .toList(),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  IconData _getSalesFilterIcon(String label) {
    if (label == 'Top Selling') return Icons.trending_up_rounded;
    if (label == 'Low Selling') return Icons.trending_down_rounded;
    return Icons.apps_rounded;
  }

  Widget _buildSearchTextField() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.plusJakartaSans(color: _fieldText, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'Search products by name...',
        hintStyle: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 13.5),
        prefixIcon: Icon(Icons.search_rounded, color: _mutedColor, size: 20),
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
    );
  }

  Widget _buildHorizonPill(int days, String label) {
    final isSelected = _selectedHorizonDays == days;
    return InkWell(
      onTap: () {
        setState(() => _selectedHorizonDays = days);
        _loadData();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
              : (_isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.transparent : _cardBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (_isDark ? PiggyTrunkTheme.ptPrimary : Colors.white)
                : _mutedColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSalesFilterChip(String label) {
    final icon = _getSalesFilterIcon(label);
    final isSelected = (_salesFilter == label) ||
        (label == 'All Products' && _salesFilter == 'All');
    final Color activeColor = label == 'Top Selling'
        ? const Color(0xFF10B981)
        : (label == 'Low Selling'
            ? const Color(0xFFF59E0B)
            : (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary));

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() => _salesFilter = (label == 'All Products' ? 'All' : label));
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (_isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD))
                : (_isDark ? const Color(0xFF1A2B44) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : _cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? activeColor : _mutedColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: isSelected
                      ? (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
                      : _mutedColor,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesPerformanceBadge(ProductForecast f) {
    if (_isTopSelling(f)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_up_rounded, size: 12, color: Color(0xFF10B981)),
            const SizedBox(width: 4),
            Text(
              'TOP SELLER',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF10B981),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    } else if (_isLowSelling(f)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_down_rounded, size: 12, color: Color(0xFFF59E0B)),
            const SizedBox(width: 4),
            Text(
              'LOW SELLER',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFF59E0B),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFF60A5FA).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.remove_rounded, size: 12, color: Color(0xFF60A5FA)),
            const SizedBox(width: 4),
            Text(
              'STEADY',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF60A5FA),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTabBar(bool isMobile) {
    final tabs = [
      (
        tab: SalesForecastViewTab.topSelling,
        label: 'Top-Selling Items',
        icon: Icons.leaderboard_rounded,
      ),
      (
        tab: SalesForecastViewTab.historicalSales,
        label: 'Historical Sales Summary',
        icon: Icons.history_rounded,
      ),
      (
        tab: SalesForecastViewTab.forecastSummary,
        label: 'Forecast Summary',
        icon: Icons.insights_rounded,
      ),
      (
        tab: SalesForecastViewTab.financialPlanning,
        label: 'Financial Planning Summary',
        icon: Icons.account_balance_wallet_outlined,
      ),
    ];

    final buttonWidgets = tabs.map((item) {
      final isSelected = _activeTab == item.tab;
      final Color activeColor = _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () {
            setState(() {
              _activeTab = item.tab;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 9 : 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? (_isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD))
                  : (_isDark ? const Color(0xFF132034) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? activeColor : _cardBorder,
                width: isSelected ? 1.6 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: isMobile ? 16 : 18,
                  color: isSelected ? activeColor : _mutedColor,
                ),
                const SizedBox(width: 8),
                Text(
                  item.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 12.5 : 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
                        : _mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: buttonWidgets,
      ),
    );
  }

  Widget _buildRankBadge(int rank, {int unitsSold = 0}) {
    Color bg;
    Color border;
    Color text;

    final hasSales = unitsSold > 0;

    if (rank == 1 && hasSales) {
      bg = const Color(0xFFFEF3C7);
      border = const Color(0xFFF59E0B);
      text = const Color(0xFFB45309);
    } else if (rank == 2 && hasSales) {
      bg = const Color(0xFFE2E8F0);
      border = const Color(0xFF94A3B8);
      text = const Color(0xFF475569);
    } else if (rank == 3 && hasSales) {
      bg = const Color(0xFFFFEDD5);
      border = const Color(0xFFFB923C);
      text = const Color(0xFFC2410C);
    } else {
      bg = _isDark ? const Color(0xFF1E2F47) : const Color(0xFFF1F5F9);
      border = _cardBorder;
      text = _mutedColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank == 1 && hasSales)
            const Padding(
              padding: EdgeInsets.only(right: 3),
              child: Icon(Icons.emoji_events_rounded, size: 13, color: Color(0xFFB45309)),
            ),
          Text(
            '#$rank',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  // --- Forecast & Reorder Matrix Card ---
  Widget _buildForecastMatrixCard(bool isMobile) {
    final list = _filteredForecasts;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth > 940 ? constraints.maxWidth : 940.0;

        return Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activeTabTitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _activeTabSubtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: _mutedColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _fieldBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Text(
                        '${list.length} item(s)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Interactive 4 Buttons Tab Bar
              _buildTabBar(isMobile),

              Divider(color: _cardBorder, height: 1),

              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: _mutedColor.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No products match your current filters.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _titleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isMobile)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (ctx, i) => Divider(color: _cardBorder, height: 1),
                  itemBuilder: (ctx, idx) {
                    final f = list[idx];
                    return InkWell(
                      onTap: () => _showProductDeepDive(f),
                      hoverColor: _isDark ? const Color(0xFF1E2F48) : const Color(0xFFF8FAFC),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: _buildMobileRow(f),
                      ),
                    );
                  },
                )
              else
                Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: _isDark ? const Color(0xFF1B2E48) : const Color(0xFFEDF4FC),
                              border: Border(bottom: BorderSide(color: _cardBorder, width: 1.2)),
                            ),
                            child: Row(
                              children: [
                                for (int i = 0; i < _activeTabHeaders.length; i++)
                                  Expanded(
                                    flex: _activeTabFlexes[i],
                                    child: Text(_activeTabHeaders[i], style: _tableHeaderStyle),
                                  ),
                              ],
                            ),
                          ),
                          ...List.generate(
                            list.length,
                            (idx) {
                              final f = list[idx];
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: idx == list.length - 1
                                        ? BorderSide.none
                                        : BorderSide(color: _cardBorder.withValues(alpha: 0.5)),
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () => _showProductDeepDive(f),
                                  hoverColor: _isDark ? const Color(0xFF1E2F48) : const Color(0xFFF8FAFC),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    child: _buildDesktopRow(f),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  TextStyle get _tableHeaderStyle => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: _mutedColor,
        letterSpacing: 0.5,
      );

  Widget _buildProductThumbnail(String? imageUrl, {double size = 56, double radius = 10}) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final isAsset = imageUrl.startsWith('assets/');
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: _cardBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 1),
          child: isAsset
              ? Image.asset(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Center(
                    child: Icon(Icons.inventory_2_outlined, color: _mutedColor, size: size * 0.45),
                  ),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Center(
                    child: Icon(Icons.inventory_2_outlined, color: _mutedColor, size: size * 0.45),
                  ),
                ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _cardBorder),
      ),
      child: Center(
        child: Icon(Icons.inventory_2_outlined, color: _mutedColor, size: size * 0.45),
      ),
    );
  }

  Widget _buildDesktopRow(ProductForecast f) {
    switch (_activeTab) {
      case SalesForecastViewTab.topSelling:
        return _buildTopSellingDesktopRow(f);
      case SalesForecastViewTab.historicalSales:
        return _buildHistoricalSalesDesktopRow(f);
      case SalesForecastViewTab.forecastSummary:
        return _buildForecastSummaryDesktopRow(f);
      case SalesForecastViewTab.financialPlanning:
        return _buildFinancialPlanningDesktopRow(f);
    }
  }

  Widget _buildTopSellingDesktopRow(ProductForecast f) {
    final rank = _getSalesRank(f);
    return Row(
      children: [
        // Rank
        Expanded(
          flex: 1,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildRankBadge(rank, unitsSold: f.calculatedTotalSold),
          ),
        ),

        // Product Name
        Expanded(
          flex: 3,
          child: Row(
            children: [
              _buildProductThumbnail(f.imageUrl, size: 44, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.productName,
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
                      '₱${f.unitPrice.toStringAsFixed(2)} / unit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: _mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Category
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _fieldBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Text(
                      f.category,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildSalesPerformanceBadge(f),
              ],
            ),
          ),
        ),

        // Units Sold
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${f.calculatedTotalSold} units',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${f.averageDailySales.toStringAsFixed(1)} units/day avg',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Total Sales / Revenue
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatCurrency(f.calculatedTotalRevenue),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Total Revenue',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoricalSalesDesktopRow(ProductForecast f) {
    final dailyRevenue = f.averageDailySales * f.unitPrice;
    final monthlyRevenue = f.averageDailySales * 30 * f.unitPrice;

    return Row(
      children: [
        // Product / Item
        Expanded(
          flex: 3,
          child: Row(
            children: [
              _buildProductThumbnail(f.imageUrl, size: 44, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.productName,
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
                      '${f.category} • ₱${f.unitPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: _mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Daily Sales
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${f.averageDailySales.toStringAsFixed(1)} units / day',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatCurrency(dailyRevenue)} / day',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Weekly / Monthly
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${(f.averageDailySales * 7).round()} wk • ${(f.averageDailySales * 30).round()} mo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatCurrency(monthlyRevenue)} / mo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Units Sold per Product
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${f.calculatedTotalSold} units',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Recorded sales',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Revenue per Product
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatCurrency(f.calculatedTotalRevenue),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Total Revenue',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForecastSummaryDesktopRow(ProductForecast f) {
    final expectedNeeded = (f.predictedDemand + f.safetyStock).round();
    final periodLabel = f.horizonDays <= 7
        ? 'Next Week'
        : (f.horizonDays <= 14 ? 'Next 2 Weeks' : 'Next Month');

    return Row(
      children: [
        // Product / Item
        Expanded(
          flex: 3,
          child: Row(
            children: [
              _buildProductThumbnail(f.imageUrl, size: 44, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.productName,
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
                      '${f.category} • ₱${f.unitPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: _mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Forecasted Demand for Next Period
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${f.predictedDemand.round()} units',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Projected sales',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Expected Quantity Needed
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$expectedNeeded units',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Incl. ${f.safetyStock.round()} buffer',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Suggested Reorder Quantity
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${f.recommendedReorderQty} units',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: f.recommendedReorderQty > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                f.recommendedReorderQty > 0 ? 'Restock suggested' : 'Adequate stock',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Forecast Period
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    periodLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                    ),
                  ),
                  Text(
                    '${f.horizonDays} days',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: _mutedColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialPlanningDesktopRow(ProductForecast f) {
    final estFutureSales = f.predictedDemand * f.unitPrice;
    final purchasingUnits = f.recommendedReorderQty > 0
        ? f.recommendedReorderQty
        : f.predictedDemand.ceil();
    final expectedSpending = purchasingUnits * f.unitPrice;

    return Row(
      children: [
        // Product / Item
        Expanded(
          flex: 3,
          child: Row(
            children: [
              _buildProductThumbnail(f.imageUrl, size: 44, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.productName,
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
                      '${f.category} • ₱${f.unitPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: _mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Historical Sales Revenue
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatCurrency(f.calculatedTotalRevenue),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${f.calculatedTotalSold} units sold',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Estimated Future Sales
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatCurrency(estFutureSales),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Proj. ${f.predictedDemand.round()} units (${f.horizonDays}d)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Estimated Inventory Purchasing Requirement
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$purchasingUnits units',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Purchasing requirement',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Expected Inventory Spending
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatCurrency(expectedSpending),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Estimated spending',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileRow(ProductForecast f) {
    switch (_activeTab) {
      case SalesForecastViewTab.topSelling:
        return _buildTopSellingMobileRow(f);
      case SalesForecastViewTab.historicalSales:
        return _buildHistoricalSalesMobileRow(f);
      case SalesForecastViewTab.forecastSummary:
        return _buildForecastSummaryMobileRow(f);
      case SalesForecastViewTab.financialPlanning:
        return _buildFinancialPlanningMobileRow(f);
    }
  }

  Widget _buildTopSellingMobileRow(ProductForecast f) {
    final rank = _getSalesRank(f);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductThumbnail(f.imageUrl, size: 60, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      f.productName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildRankBadge(rank, unitsSold: f.calculatedTotalSold),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${f.category} • ₱${f.unitPrice.toStringAsFixed(2)} / unit',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _mutedColor,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    _formatCurrency(f.calculatedTotalRevenue),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const Text(' • '),
                  Text(
                    '${f.calculatedTotalSold} units sold',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _titleColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoricalSalesMobileRow(ProductForecast f) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductThumbnail(f.imageUrl, size: 60, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.productName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _titleColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                '${f.category} • ₱${f.unitPrice.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _mutedColor,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Velocity: ${f.averageDailySales.toStringAsFixed(1)}u/d',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _titleColor,
                    ),
                  ),
                  const Text(' • '),
                  Text(
                    '${(f.averageDailySales * 30).round()}u/mo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _mutedColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Sold: ${f.calculatedTotalSold} units',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _mutedColor,
                    ),
                  ),
                  const Text(' • '),
                  Text(
                    _formatCurrency(f.calculatedTotalRevenue),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForecastSummaryMobileRow(ProductForecast f) {
    final expectedNeeded = (f.predictedDemand + f.safetyStock).round();
    final periodLabel = f.horizonDays <= 7
        ? 'Next 7d'
        : (f.horizonDays <= 14 ? 'Next 14d' : 'Next 30d');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductThumbnail(f.imageUrl, size: 60, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      f.productName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: _isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3),
                      ),
                    ),
                    child: Text(
                      periodLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${f.category} • ₱${f.unitPrice.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _mutedColor,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Demand: ${f.predictedDemand.round()} units',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
                    ),
                  ),
                  const Text(' • '),
                  Text(
                    'Need: $expectedNeeded units',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _titleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Suggested Reorder: ${f.recommendedReorderQty} units',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: f.recommendedReorderQty > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialPlanningMobileRow(ProductForecast f) {
    final estFutureSales = f.predictedDemand * f.unitPrice;
    final purchasingUnits = f.recommendedReorderQty > 0
        ? f.recommendedReorderQty
        : f.predictedDemand.ceil();
    final expectedSpending = purchasingUnits * f.unitPrice;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductThumbnail(f.imageUrl, size: 60, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.productName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _titleColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                '${f.category} • ₱${f.unitPrice.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _mutedColor,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Hist. Rev: ${_formatCurrency(f.calculatedTotalRevenue)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Est. Sales: ${_formatCurrency(estFutureSales)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
                    ),
                  ),
                  const Text(' • '),
                  Text(
                    'Req: $purchasingUnits units',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _titleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Expected Spending: ${_formatCurrency(expectedSpending)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  // --- Product Deep Dive Screen Navigation with Dual Model Comparison & Enhanced Visuals ---
  void _showProductDeepDive(ProductForecast f) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => SalesForecastDetailScreen(
          forecast: f,
          allProducts: _allProducts,
          isMobileEmbedded: widget.isMobileEmbedded,
          onRestockSuccess: _loadData,
        ),
      ),
    );
  }

  Widget _buildKpiSkeletonSection(bool isMobile) {
    final card1 = _buildKpiCardSkeleton(isMobile);
    final card2 = _buildKpiCardSkeleton(isMobile);

    if (isMobile) {
      return Column(
        children: [
          card1,
          const SizedBox(height: 10),
          card2,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: card1),
        const SizedBox(width: 14),
        Expanded(child: card2),
      ],
    );
  }

  Widget _buildKpiCardSkeleton(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 34, height: 34, borderRadius: BorderRadius.circular(10), isDark: _isDark),
              ShimmerBox(width: 50, height: 18, borderRadius: BorderRadius.circular(9), isDark: _isDark),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 14),
          ShimmerBox(width: 80, height: 22, borderRadius: BorderRadius.circular(4), isDark: _isDark),
          const SizedBox(height: 6),
          ShimmerBox(width: 110, height: 13, borderRadius: BorderRadius.circular(3), isDark: _isDark),
          const SizedBox(height: 4),
          ShimmerBox(width: 90, height: 11, borderRadius: BorderRadius.circular(3), isDark: _isDark),
        ],
      ),
    );
  }

  // ===================== DEDICATED MOBILE-FIRST LAYOUT =====================
  Widget _buildMobileLayout() {
    final list = _filteredForecasts;

    return Column(
      children: [
        // 1. Mobile Top Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: _isDark ? PiggyTrunkTheme.ptBgDark : Colors.white,
            border: Border(bottom: BorderSide(color: _cardBorder, width: 0.8)),
          ),
          child: _buildHeader(true),
        ),

        // 2. Scrollable Body
        Expanded(
          child: _isLoading
              ? _buildMobileLoadingSkeleton()
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Top Metrics & Period Switcher (scrolls away naturally)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Compact 2-Column KPI Strip (~70px)
                            _buildMobileKpiStrip(),
                            const SizedBox(height: 10),

                            // Segmented Horizon Switcher (7D | 14D | 30D)
                            _buildMobilePeriodSegmentedControl(),
                          ],
                        ),
                      ),
                    ),

                    // Sticky Header: Tabs + Search & Filter (Pins neatly to the top!)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ForecastStickyHeaderDelegate(
                        height: 98,
                        backgroundColor: _bgDark,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildMobileTabBar(),
                              const SizedBox(height: 8),
                              _buildMobileSearchAndFilterRow(),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Product List Header Info
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _activeTabTitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: _titleColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: _fieldBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _cardBorder),
                              ),
                              child: Text(
                                '${list.length} items',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _mutedColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Products List
                    if (list.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildMobileEmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, idx) {
                              final f = list[idx];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _cardBorder),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.02),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _showProductDeepDive(f),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: _buildMobileRow(f),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: list.length,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMobileKpiStrip() {
    return Row(
      children: [
        // Monthly Sales Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.payments_rounded,
                        size: 14,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SALES',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatCurrency(_totalMonthlySales),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '$_totalMonthlyUnits units sold',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: _mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Restock Capital Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: (_isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 14,
                        color: _isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (_isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'RESTOCK',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: _isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatCurrency(_estimatedPurchasingCapital),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  'Estimated capital',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: _mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobilePeriodSegmentedControl() {
    final horizons = [7, 14, 30];
    final labels = ['7 Days', '14 Days', '30 Days'];

    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: List.generate(horizons.length, (i) {
          final h = horizons[i];
          final isSelected = _selectedHorizonDays == h;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedHorizonDays = h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (_isDark ? const Color(0xFF243B53) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: _isDark ? 0.25 : 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
                          : _mutedColor,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMobileTabBar() {
    final tabs = [
      (
        tab: SalesForecastViewTab.topSelling,
        label: 'Top Sellers',
        icon: Icons.leaderboard_rounded,
      ),
      (
        tab: SalesForecastViewTab.forecastSummary,
        label: 'Forecast',
        icon: Icons.insights_rounded,
      ),
      (
        tab: SalesForecastViewTab.historicalSales,
        label: 'History',
        icon: Icons.history_rounded,
      ),
      (
        tab: SalesForecastViewTab.financialPlanning,
        label: 'Planning',
        icon: Icons.account_balance_wallet_outlined,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: tabs.map((item) {
          final isSelected = _activeTab == item.tab;
          final Color activeColor = _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _activeTab = item.tab),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (_isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD))
                      : (_isDark ? const Color(0xFF132034) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? activeColor : _cardBorder,
                    width: isSelected ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 14,
                      color: isSelected ? activeColor : _mutedColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? activeColor : _mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileSearchAndFilterRow() {
    return Row(
      children: [
        // Slim Search Input
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cardBorder),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: _fieldText,
              ),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: _mutedColor,
                ),
                prefixIcon: Icon(Icons.search_rounded, size: 17, color: _mutedColor),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        color: _mutedColor,
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Quick Sales Performance Filter Menu
        PopupMenuButton<String>(
          initialValue: _salesFilter,
          onSelected: (val) => setState(() => _salesFilter = val),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: _isDark ? const Color(0xFF1A2940) : Colors.white,
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'All Products', child: Text('All Products')),
            const PopupMenuItem(value: 'Top Selling', child: Text('Top Selling')),
            const PopupMenuItem(value: 'Low Selling', child: Text('Low Selling')),
          ],
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _salesFilter != 'All Products' && _salesFilter != 'All'
                  ? (_isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD))
                  : _fieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _salesFilter != 'All Products' && _salesFilter != 'All'
                    ? PiggyTrunkTheme.ptPrimary
                    : _cardBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  size: 16,
                  color: _salesFilter != 'All Products' && _salesFilter != 'All'
                      ? PiggyTrunkTheme.ptPrimary
                      : _mutedColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _salesFilter == 'All Products' || _salesFilter == 'All' ? 'Filter' : _salesFilter.split(' ').first,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _salesFilter != 'All Products' && _salesFilter != 'All'
                        ? PiggyTrunkTheme.ptPrimary
                        : _titleColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cardBorder),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cardBorder),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorder),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: 5,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => Container(
                height: 80,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cardBorder),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: _mutedColor.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No products match your current filters.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _titleColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search or filter options.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _mutedColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final Color backgroundColor;

  _ForecastStickyHeaderDelegate({
    required this.child,
    required this.height,
    required this.backgroundColor,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: height,
      color: backgroundColor,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _ForecastStickyHeaderDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.child != child;
  }
}
