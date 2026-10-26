import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/investment_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../common/shimmer_loading.dart';
import 'investment_detail_modal.dart';

class InvestmentTableView extends StatefulWidget {
  final List<Investment> investments;
  final List<Map<String, dynamic>> partnerInvestments;
  final String? initialViewMode;
  final VoidCallback onAddInvestment;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final void Function(Investment item) onEditInvestment;
  final void Function(Investment item) onArchiveInvestment;
  final void Function(Investment item)? onRestoreInvestment;
  final void Function(Investment item) onDeleteInvestment;
  final void Function(Investment item)? onCompleteInvestment;
  final void Function(Investment item)? onAddAllocation;
  final void Function(int investmentId)? onApprovePartnerInvestment;
  final void Function(int investmentId)? onRejectPartnerInvestment;

  const InvestmentTableView({
    super.key,
    required this.investments,
    this.partnerInvestments = const [],
    this.initialViewMode,
    this.onRefresh,
    this.isRefreshing = false,
    required this.onAddInvestment,
    required this.onEditInvestment,
    required this.onArchiveInvestment,
    this.onRestoreInvestment,
    required this.onDeleteInvestment,
    this.onCompleteInvestment,
    this.onAddAllocation,
    this.onApprovePartnerInvestment,
    this.onRejectPartnerInvestment,
  });

  @override
  State<InvestmentTableView> createState() => _InvestmentTableViewState();
}

class _InvestmentTableViewState extends State<InvestmentTableView> {
  final TextEditingController _searchCtrl = TextEditingController();
  late String _viewMode;
  String _selectedStageFilter = 'ALL';
  final String _selectedTypeFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode ??
        (widget.partnerInvestments.any((p) => (p['status'] ?? '').toString().toLowerCase() == 'pending')
            ? 'PARTNER'
            : 'DIRECT');
    if (_viewMode == 'PARTNER') {
      _selectedStageFilter = 'ALL';
    }
  }

  @override
  void didUpdateWidget(covariant InvestmentTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialViewMode != null && widget.initialViewMode != oldWidget.initialViewMode) {
      _viewMode = widget.initialViewMode!;
      if (_viewMode == 'PARTNER') {
        _selectedStageFilter = 'ALL';
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(0);
    final formatted = parts.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₱$formatted';
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = months[date.month - 1];
    return '$monthName ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);

    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final headerText = isDark ? const Color(0xFF9EC0E8) : const Color(0xFF4B6281);
    final fieldBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
    final fieldBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFC9D8EC);
    final fieldFocus = isDark ? const Color(0xFF88A7CE) : const Color(0xFF315C8F);
    final fieldText = isDark ? Colors.white : const Color(0xFF18314F);
    final hintText = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);

    final activeInvestments = widget.investments.where((i) => i.stage.toLowerCase() != 'archived').toList();
    final totalCapital = activeInvestments.fold<double>(0.0, (sum, i) => sum + i.initialCapital);
    final totalStocksSpend = activeInvestments.fold<double>(0.0, (sum, i) => sum + i.stocksValue);
    final totalHogs = activeInvestments.fold<int>(0, (sum, i) => sum + i.totalHog);
    final activeCount = activeInvestments.where((i) => i.stage.toLowerCase() != 'completed').length;
    final pendingPartnerCount = widget.partnerInvestments.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'pending').length;

    // Filter Direct Investments
    final filteredDirect = widget.investments.where((inv) {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final name = inv.raiserName.toLowerCase();
        final type = inv.hogType.toLowerCase();
        final batch = (inv.batchName ?? '').toLowerCase();
        if (!name.contains(q) && !type.contains(q) && !batch.contains(q)) return false;
      }
      if (_selectedStageFilter == 'ALL') {
        if (inv.stage.toLowerCase() == 'archived') return false;
      } else {
        if (inv.stage.toUpperCase() != _selectedStageFilter) return false;
      }
      if (_selectedTypeFilter != 'ALL') {
        if (!inv.hogType.toLowerCase().contains(_selectedTypeFilter.toLowerCase())) return false;
      }
      return true;
    }).toList();

    // Sort Direct Investments newest-first (latest date / id on top, older at bottom)
    filteredDirect.sort((a, b) {
      final dateCmp = b.investmentDate.compareTo(a.investmentDate);
      if (dateCmp != 0) return dateCmp;
      return b.id.compareTo(a.id);
    });

    // Filter Partner Investments
    final filteredPartner = widget.partnerInvestments.where((p) {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final pName = (p['partner_name'] ?? '').toString().toLowerCase();
        final bName = (p['batch_name'] ?? '').toString().toLowerCase();
        if (!pName.contains(q) && !bName.contains(q)) return false;
      }
      if (_selectedStageFilter == 'ALL') {
        final st = (p['status'] ?? 'pending').toString().toLowerCase();
        if (st == 'archived') return false;
      } else {
        final st = (p['status'] ?? 'pending').toString().toUpperCase();
        if (st != _selectedStageFilter) return false;
      }
      return true;
    }).toList();

    // Sort Partner Investments newest-first (latest date / id on top, older at bottom)
    filteredPartner.sort((a, b) {
      final dateA = DateTime.tryParse((a['date_invested'] ?? a['created_at'] ?? '').toString()) ?? DateTime(1970);
      final dateB = DateTime.tryParse((b['date_invested'] ?? b['created_at'] ?? '').toString()) ?? DateTime(1970);
      final dateCmp = dateB.compareTo(dateA);
      if (dateCmp != 0) return dateCmp;
      final idA = int.tryParse((a['investment_id'] ?? a['id'] ?? '0').toString()) ?? 0;
      final idB = int.tryParse((b['investment_id'] ?? b['id'] ?? '0').toString()) ?? 0;
      return idB.compareTo(idA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Metric Cards
        _buildMetricsRow(totalCapital, totalStocksSpend, totalHogs, activeCount, pendingPartnerCount, isMobile, isDark),
        const SizedBox(height: 24),

        // Main Table Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            border: Border.all(color: cardBorder, width: 1),
            borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
          ),
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isNarrowHeader = headerConstraints.maxWidth < 750 || isMobile;
                  if (isNarrowHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Investment Management',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            letterSpacing: -0.04,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track capital investments, partner approvals, and lifecycle performance',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w500, color: headerText),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onAddInvestment,
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: Text(
                              'Add Investment',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            style: _primaryButtonStyle(minWidth: 0, isDark: isDark),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Investment Management',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                              letterSpacing: -0.04,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track capital investments, partner approvals, and lifecycle performance',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: headerText),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: widget.onAddInvestment,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text(
                          'Add Investment',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: _primaryButtonStyle(minWidth: 160, isDark: isDark),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // View Mode Selector (Direct Allocations vs Partner Requests)
              _buildViewModeToggle(pendingPartnerCount, isDark, isMobile),
              const SizedBox(height: 16),

              // Search & Filters
              _buildSearchAndFilters(isMobile, isDark, fieldBg, fieldBorder, fieldFocus, fieldText, hintText),
              const SizedBox(height: 16),

              // Table Content
              if (widget.isRefreshing)
                TableSkeletonLoader(
                  isDark: isDark,
                  minWidth: 800,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  headerBg: isDark ? const Color(0xFF1B2E48) : const Color(0xFFEDF4FC),
                  headers: _viewMode == 'DIRECT'
                      ? const ['HOG RAISER', 'BATCH ASSIGN', 'CAPITAL', 'STOCKS SPEND', 'HOG TYPE', 'HEADS', 'DATE', 'ACTIONS']
                      : const ['PARTNER INVESTOR', 'BATCH NAME', 'AMOUNT', 'DATE', 'STATUS'],
                  columnFlexes: _viewMode == 'DIRECT'
                      ? const [4, 3, 2, 3, 3, 2, 3, 4]
                      : const [3, 3, 2, 2, 3],
                  actionButtonCount: _viewMode == 'DIRECT'
                      ? (_selectedStageFilter == 'ARCHIVED' ? 3 : 4)
                      : 2,
                  rowCount: 5,
                  borderRadius: 12,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                  final tableWidth = constraints.maxWidth > 880 ? constraints.maxWidth : 880.0;

                  return Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF132238) : Colors.white,
                            border: Border.all(color: cardBorder, width: 1.0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_viewMode == 'DIRECT') ...[
                                  _buildTableHeader(isDark, cardBorder, hintText),
                                  if (filteredDirect.isEmpty)
                                    _buildEmptyPlaceholder(tableWidth, cardBorder, titleColor, _getDirectEmptyMessage())
                                  else
                                    ...List.generate(
                                      filteredDirect.length,
                                      (index) => _buildTableRow(filteredDirect[index], index, isDark, cardBorder, titleColor, hintText),
                                    ),
                                ] else ...[
                                  _buildPartnerTableHeader(isDark, cardBorder, hintText),
                                  if (filteredPartner.isEmpty)
                                    _buildEmptyPlaceholder(tableWidth, cardBorder, titleColor, _getPartnerEmptyMessage())
                                  else
                                    ...List.generate(
                                      filteredPartner.length,
                                      (index) => _buildPartnerTableRow(filteredPartner[index], index, isDark, cardBorder, titleColor, hintText),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getDirectEmptyMessage() {
    final query = _searchCtrl.text.trim();
    if (query.isNotEmpty) {
      return 'No investments matching "$query" found.';
    }
    switch (_selectedStageFilter) {
      case 'PENDING':
        return 'No pending investments found.';
      case 'ACTIVE':
        return 'No active investments found.';
      case 'COMPLETED':
        return 'No completed investments found.';
      case 'ARCHIVED':
        return 'No archived investments found.';
      default:
        return 'No direct investments found.';
    }
  }

  String _getPartnerEmptyMessage() {
    final query = _searchCtrl.text.trim();
    if (query.isNotEmpty) {
      return 'No partner investments matching "$query" found.';
    }
    switch (_selectedStageFilter) {
      case 'PENDING':
        return 'No pending partner investments found.';
      case 'ACTIVE':
        return 'No active partner investments found.';
      case 'COMPLETED':
        return 'No completed partner investments found.';
      case 'ARCHIVED':
        return 'No archived partner investments found.';
      default:
        return 'No partner investments found.';
    }
  }

  Widget _buildEmptyPlaceholder(double tableWidth, Color cardBorder, Color titleColor, String message) {
    return Container(
      width: tableWidth,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cardBorder.withValues(alpha: 0.7))),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: titleColor),
        ),
      ),
    );
  }

  Widget _buildViewModeToggle(int pendingCount, bool isDark, bool isMobile) {
    return Container(
      width: isMobile ? double.infinity : null,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16253B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF28405D) : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
        children: [
          isMobile
              ? Expanded(
                  child: _buildToggleTab(
                    label: 'Direct Allocations',
                    count: widget.investments.where((i) => i.stage.toLowerCase() != 'archived').length,
                    isSelected: _viewMode == 'DIRECT',
                    onTap: () => setState(() => _viewMode = 'DIRECT'),
                    isDark: isDark,
                    isMobile: isMobile,
                  ),
                )
              : _buildToggleTab(
                  label: 'Direct Allocations',
                  count: widget.investments.where((i) => i.stage.toLowerCase() != 'archived').length,
                  isSelected: _viewMode == 'DIRECT',
                  onTap: () => setState(() => _viewMode = 'DIRECT'),
                  isDark: isDark,
                  isMobile: isMobile,
                ),
          const SizedBox(width: 4),
          isMobile
              ? Expanded(
                  child: _buildToggleTab(
                    label: 'Partner Investments',
                    count: widget.partnerInvestments.where((p) => (p['status'] ?? '').toString().toLowerCase() != 'archived').length,
                    isSelected: _viewMode == 'PARTNER',
                    onTap: () => setState(() => _viewMode = 'PARTNER'),
                    isDark: isDark,
                    isMobile: isMobile,
                  ),
                )
              : _buildToggleTab(
                  label: 'Partner Investments',
                  count: widget.partnerInvestments.where((p) => (p['status'] ?? '').toString().toLowerCase() != 'archived').length,
                  isSelected: _viewMode == 'PARTNER',
                  onTap: () => setState(() => _viewMode = 'PARTNER'),
                  isDark: isDark,
                  isMobile: isMobile,
                ),
        ],
      ),
    );
  }

  Widget _buildToggleTab({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required bool isMobile,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 18,
          vertical: isMobile ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF243B5B) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 12 : 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF18314F))
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                        ? const Color(0xFF60A5FA).withValues(alpha: 0.2)
                        : PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.1))
                    : (isDark
                        ? const Color(0xFF28405D).withValues(alpha: 0.5)
                        : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 10.5 : 11.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? (isDark ? const Color(0xFF93C5FD) : PiggyTrunkTheme.ptPrimary)
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(double capital, double stocksSpend, int totalHogs, int activeCount, int pendingCount, bool isMobile, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final use2x2 = isMobile || constraints.maxWidth < 780;
        if (use2x2) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Total Capital', _formatCurrency(capital), Icons.monetization_on_rounded, isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary, isDark, isMobile)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildMetricCard('Stocks Spend', _formatCurrency(stocksSpend), Icons.inventory_2_rounded, const Color(0xFF38BDF8), isDark, isMobile)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Total Heads', '$totalHogs heads', Icons.pets_rounded, const Color(0xFFFFAA00), isDark, isMobile)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildMetricCard('Active Allocations', '$activeCount active', Icons.check_circle_rounded, PiggyTrunkTheme.ptSuccess, isDark, isMobile)),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _buildMetricCard('Total Capital', _formatCurrency(capital), Icons.monetization_on_rounded, isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary, isDark, isMobile)),
            const SizedBox(width: 14),
            Expanded(child: _buildMetricCard('Stocks Spend', _formatCurrency(stocksSpend), Icons.inventory_2_rounded, const Color(0xFF38BDF8), isDark, isMobile)),
            const SizedBox(width: 14),
            Expanded(child: _buildMetricCard('Total Heads', '$totalHogs heads', Icons.pets_rounded, const Color(0xFFFFAA00), isDark, isMobile)),
            const SizedBox(width: 14),
            Expanded(child: _buildMetricCard('Active Allocations', '$activeCount active', Icons.check_circle_rounded, PiggyTrunkTheme.ptSuccess, isDark, isMobile)),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, bool isDark, bool isMobile) {
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final hintText = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: cardBorder, width: 1),
        borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 12 : 14),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: isMobile ? 18 : 22),
          ),
          SizedBox(width: isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: hintText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                widget.isRefreshing
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: ShimmerBox(
                          width: isMobile ? 50 : 70,
                          height: isMobile ? 15 : 18,
                          borderRadius: BorderRadius.circular(4),
                          isDark: isDark,
                        ),
                      )
                    : Text(
                        value,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 15 : 18,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isMobile, bool isDark, Color fieldBg, Color fieldBorder, Color fieldFocus, Color fieldText, Color hintText) {
    final searchField = SizedBox(
      height: 42,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: fieldText, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search by raiser, batch, or hog type...',
          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: hintText),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: hintText),
          filled: true,
          fillColor: fieldBg,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: fieldBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: fieldBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: fieldFocus, width: 1.5)),
        ),
      ),
    );

    final filterButtons = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('ALL', 'All Investments', isDark),
          const SizedBox(width: 8),
          _buildFilterChip('PENDING', 'Pending', isDark),
          const SizedBox(width: 8),
          _buildFilterChip('ACTIVE', 'Active', isDark),
          const SizedBox(width: 8),
          _buildFilterChip('COMPLETED', 'Completed', isDark),
          const SizedBox(width: 8),
          _buildFilterChip('ARCHIVED', 'Archived', isDark),
        ],
      ),
    );

    final refreshBtn = widget.onRefresh != null
        ? Tooltip(
            message: 'Refresh investments',
            child: IconButton(
              onPressed: widget.isRefreshing ? null : widget.onRefresh,
              icon: widget.isRefreshing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fieldFocus,
                      ),
                    )
                  : Icon(Icons.refresh_rounded, color: fieldFocus, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1A2B44) : const Color(0xFFEEF4FD),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: fieldBorder),
                ),
                minimumSize: const Size(42, 42),
                fixedSize: const Size(42, 42),
              ),
            ),
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = isMobile || constraints.maxWidth < 750;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: searchField),
                  if (refreshBtn != null) ...[
                    const SizedBox(width: 8),
                    refreshBtn,
                  ],
                ],
              ),
              const SizedBox(height: 10),
              filterButtons,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            filterButtons,
            if (refreshBtn != null) ...[
              const SizedBox(width: 10),
              refreshBtn,
            ],
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedStageFilter == value;
    final activeBg = isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;
    final unselectedBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final unselectedBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final unselectedTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return InkWell(
      onTap: () => setState(() => _selectedStageFilter = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : unselectedBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? activeBg : unselectedBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? (isDark ? PiggyTrunkTheme.ptPrimary : Colors.white) : unselectedTextColor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  // DIRECT ALLOCATIONS TABLE
  Widget _buildTableHeader(bool isDark, Color cardBorder, Color hintText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2E48) : const Color(0xFFEDF4FC),
        border: Border(bottom: BorderSide(color: cardBorder, width: 1.2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'HOG RAISER',
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'BATCH ASSIGN',
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'CAPITAL',
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'STOCKS SPEND',
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'HOG TYPE',
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                'HEADS',
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: Text(
                'DATE',
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: Text(
                'ACTIONS',
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Investment inv, int index, bool isDark, Color cardBorder, Color titleColor, Color hintText) {
    final batchName = (inv.batchName != null && inv.batchName!.isNotEmpty) ? inv.batchName! : 'Unassigned';
    final hasBatch = batchName != 'Unassigned' && batchName != 'No Batch';
    final isCompleted = inv.stage.toLowerCase() == 'completed';
    final isArchived = inv.stage.toLowerCase() == 'archived';
    final rowBg = index % 2 == 1
        ? (isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFD))
        : (isDark ? const Color(0xFF132238) : Colors.white);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(bottom: BorderSide(color: cardBorder.withValues(alpha: 0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. HOG RAISER (flex: 4)
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: () => InvestmentDetailModal.show(context: context, investment: inv),
                borderRadius: BorderRadius.circular(4),
                child: Text(
                  inv.raiserName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          // 2. BATCH ASSIGN (flex: 3)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                batchName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: hasBatch ? titleColor : hintText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // 3. CAPITAL (flex: 2)
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                _formatCurrency(inv.initialCapital),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF43CB89),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // 4. STOCKS SPEND (flex: 3)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                _formatCurrency(inv.stocksValue),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: inv.stocksValue > 0 ? titleColor : hintText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // 5. HOG TYPE (flex: 3)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                inv.hogType,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // 6. HEADS (flex: 2, Center)
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                '${inv.totalHog} heads',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
            ),
          ),
          // 7. DATE (flex: 3, Center)
          Expanded(
            flex: 3,
            child: Center(
              child: Text(
                _formatDate(inv.investmentDate),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: hintText,
                ),
              ),
            ),
          ),
          // 8. ACTIONS (flex: 4, Center)
          Expanded(
            flex: 4,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Details Icon Button (👁)
                    _buildSquareIconButton(
                      icon: Icons.visibility_outlined,
                      iconColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                      bgColor: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: isDark ? 0.08 : 0.1),
                      borderColor: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: isDark ? 0.22 : 0.3),
                      tooltip: 'View Details',
                      onTap: () => InvestmentDetailModal.show(context: context, investment: inv),
                    ),
                    const SizedBox(width: 6),

                    if (isArchived) ...[
                      // 2. Restore Icon Button (📥)
                      _buildSquareIconButton(
                        icon: Icons.unarchive_outlined,
                        iconColor: PiggyTrunkTheme.ptSuccess,
                        bgColor: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.1),
                        borderColor: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.3),
                        tooltip: 'Restore Investment',
                        onTap: () => widget.onRestoreInvestment?.call(inv),
                      ),
                      const SizedBox(width: 6),
                    ] else ...[
                      // 2. Complete Icon Button (✓)
                      if (isCompleted)
                        _buildSquareIconButton(
                          icon: Icons.check_circle_rounded,
                          iconColor: PiggyTrunkTheme.ptSuccess,
                          bgColor: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.15),
                          borderColor: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.4),
                          tooltip: 'Completed',
                          onTap: null,
                        )
                      else
                        _buildSquareIconButton(
                          icon: Icons.check_rounded,
                          iconColor: PiggyTrunkTheme.ptSuccess,
                          bgColor: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.1),
                          borderColor: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.3),
                          tooltip: 'Mark as Complete',
                          onTap: () => widget.onCompleteInvestment?.call(inv),
                        ),
                      const SizedBox(width: 6),

                      // 3. Archive Icon Button (🗄)
                      _buildSquareIconButton(
                        icon: Icons.archive_outlined,
                        iconColor: const Color(0xFFF59E0B),
                        bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        tooltip: 'Archive Investment',
                        onTap: () => widget.onArchiveInvestment(inv),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // 4. Delete Icon Button (🗑)
                    _buildSquareIconButton(
                      icon: Icons.delete_outline_rounded,
                      iconColor: const Color(0xFFEF4444),
                      bgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderColor: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      tooltip: 'Delete Investment',
                      onTap: () => widget.onDeleteInvestment(inv),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareIconButton({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 16,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerTableHeader(bool isDark, Color cardBorder, Color hintText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2E48) : const Color(0xFFEDF4FC),
        border: Border(bottom: BorderSide(color: cardBorder, width: 1.2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('PARTNER INVESTOR', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText)),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('BATCH NAME', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('AMOUNT', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('DATE', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('STATUS', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText)),
            ),
          ),
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text('ACTIONS', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: hintText)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerTableRow(Map<String, dynamic> p, int index, bool isDark, Color cardBorder, Color titleColor, Color hintText) {
    final status = (p['status'] ?? 'active').toString().toLowerCase();
    final isCompleted = status == 'completed' || status == 'finished';
    final isActive = status == 'active' || status == 'approved';
    final isPending = status == 'pending';
    final Color statusColor = isCompleted
        ? const Color(0xFF3B82F6)
        : (isActive
            ? PiggyTrunkTheme.ptSuccess
            : (isPending ? const Color(0xFFFFAA00) : const Color(0xFFFF758C)));

    final double amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
    final dateStr = p['date_invested']?.toString() ?? '';
    final dt = DateTime.tryParse(dateStr) ?? DateTime.now();
    final rawInvId = p['investment_id'] ?? p['id'];
    final investmentId = rawInvId is int ? rawInvId : int.tryParse(rawInvId?.toString() ?? '');
    final rowBg = index % 2 == 1
        ? (isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFD))
        : (isDark ? const Color(0xFF132238) : Colors.white);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(bottom: BorderSide(color: cardBorder.withValues(alpha: 0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                p['partner_name'] ?? 'Partner Investor',
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: titleColor),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                p['batch_name'] ?? 'Batch #${p['batch_id']}',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                _formatCurrency(amt),
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF43CB89)),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                _formatDate(dt),
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w500, color: hintText),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isActive ? 'ACTIVE' : status.toUpperCase(),
                        maxLines: 1,
                        softWrap: false,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSquareIconButton(
                  icon: Icons.visibility_rounded,
                  iconColor: isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
                  bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF4FC),
                  borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  tooltip: 'View Partner Investment Details',
                  onTap: () => _showPartnerDetailModal(context, p),
                ),
                if (isPending && investmentId != null) ...[
                  const SizedBox(width: 6),
                  _buildSquareIconButton(
                    icon: Icons.check_rounded,
                    iconColor: PiggyTrunkTheme.ptSuccess,
                    bgColor: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.1),
                    borderColor: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.35),
                    tooltip: 'Approve Partner Investment',
                    onTap: () => widget.onApprovePartnerInvestment?.call(investmentId),
                  ),
                  const SizedBox(width: 6),
                  _buildSquareIconButton(
                    icon: Icons.close_rounded,
                    iconColor: const Color(0xFFEF4444),
                    bgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderColor: const Color(0xFFEF4444).withValues(alpha: 0.35),
                    tooltip: 'Reject Partner Investment',
                    onTap: () => widget.onRejectPartnerInvestment?.call(investmentId),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPartnerDetailModal(BuildContext context, Map<String, dynamic> p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final hintText = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
    final innerBg = isDark ? const Color(0xFF182942) : const Color(0xFFF6F9FE);

    final partnerName = (p['partner_name'] ?? 'Partner Investor').toString();
    final batchName = (p['batch_name'] ?? 'Batch Project').toString();
    final raiserName = (p['assigned_raiser'] ?? 'Assigned Raiser').toString();
    final double amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
    final status = (p['status'] ?? 'active').toString().toUpperCase();
    final isCompleted = status.toLowerCase() == 'completed';
    final isActive = status.toLowerCase() == 'active' || status.toLowerCase() == 'approved';
    final Color statusColor = isCompleted
        ? const Color(0xFF3B82F6)
        : (isActive ? PiggyTrunkTheme.ptSuccess : const Color(0xFFFFAA00));

    final dateStr = (p['date_invested'] ?? p['created_at'] ?? '').toString();
    final dt = DateTime.tryParse(dateStr) ?? DateTime.now();

    final targetPigType = (p['target_pig_type'] ?? 'Entire Batch').toString();
    List<String> targetHogs = [];
    if (p['target_hog_tags'] is List) {
      targetHogs = List<String>.from(p['target_hog_tags'].map((e) => e.toString()));
    }

    final int hogsCount = targetHogs.isNotEmpty
        ? targetHogs.length
        : ((p['selected_hogs_count'] as num?)?.toInt() ?? (p['hogs'] is List ? (p['hogs'] as List).length : 6));

    final double perHogAmount = hogsCount > 0 ? (amt / hogsCount) : amt;

    final isMobile = MediaQuery.of(context).size.width < 720;

    Widget buildDrawerContent(BuildContext ctx) {
      return Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Partner Investment Details',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Investment #${p['investment_id'] ?? p['id'] ?? "Direct"}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: hintText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(Icons.close_rounded, color: hintText, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Close panel',
                ),
              ],
            ),
          ),
          Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),

          // Content Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Partner & Status Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: innerBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder, width: 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3),
                          child: Text(
                            partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                partnerName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              Text(
                                'Invested on ${_formatDate(dt)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: hintText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Investment Value Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: innerBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL CAPITAL',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: hintText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(amt),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF43CB89),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: innerBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ALLOCATION RATIO',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: hintText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '≈ ${_formatCurrency(perHogAmount)} / hog',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Batch & Raiser Information
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: innerBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_rounded, size: 16, color: hintText),
                            const SizedBox(width: 6),
                            Text(
                              'BATCH & RAISER DESTINATION',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: hintText,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Funded Batch:',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: hintText, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              batchName,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: titleColor, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Assigned Raiser:',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: hintText, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              raiserName,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: titleColor, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Allocation Target Details
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: innerBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.tune_rounded, size: 16, color: hintText),
                                const SizedBox(width: 6),
                                Text(
                                  'TARGET ALLOCATION',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: hintText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: cardBorder, width: 0.8),
                              ),
                              child: Text(
                                targetPigType,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          targetHogs.isNotEmpty
                              ? 'Allocated Hogs ($hogsCount):'
                              : 'All $hogsCount hogs in batch covered by investment.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        if (targetHogs.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: targetHogs.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF28405D) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.pets_rounded, size: 11, color: titleColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      tag,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: titleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Close Button
          Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                  foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: cardBorder, width: 1.2)),
          ),
          child: SafeArea(
            child: buildDrawerContent(sheetContext),
          ),
        ),
      );
    } else {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Partner Investment Details',
        barrierColor: Colors.black.withValues(alpha: 0.55),
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (dialogContext, anim1, anim2) => const SizedBox.shrink(),
        transitionBuilder: (dialogContext, anim, secondaryAnim, child) {
          final curvedAnimation = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 480,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(left: BorderSide(color: cardBorder, width: 1.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(-4, 0),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: buildDrawerContent(dialogContext),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  ButtonStyle _primaryButtonStyle({double minWidth = 140, required bool isDark}) {
    return ElevatedButton.styleFrom(
      backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
      foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      elevation: 0,
      minimumSize: Size(minWidth, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
