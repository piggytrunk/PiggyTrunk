import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/models/pos_model.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/app_strings.dart';
import '../../../utils/capitalization_formatters.dart';

class CashierRequestsTab extends StatefulWidget {
  final List<Map<String, dynamic>> pendingRequests;
  final List<POSProduct> allProducts;
  final Future<void> Function(int requestId, String status, {int? allocatedSacks, int? productId}) onProcessRequest;

  const CashierRequestsTab({
    super.key,
    required this.pendingRequests,
    required this.allProducts,
    required this.onProcessRequest,
  });

  @override
  State<CashierRequestsTab> createState() => _CashierRequestsTabState();
}

class _CashierRequestsTabState extends State<CashierRequestsTab> {
  static const Color _brandColor = Color(0xFF18314F);
  static const Color _brandBlue = Color(0xFF2563EB);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _brandAmber = Color(0xFFF59E0B);
  static const Color _brandRed = Color(0xFFFF758C);

  int _selectedTab = 0; // 0 = Pending Requests, 1 = History
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  // Selected request for allocation view
  Map<String, dynamic>? _selectedRequest;
  int _allocatedSacks = 10;
  bool _isProcessing = false;

  void _openAllocationView(Map<String, dynamic> request) {
    final qty = request['quantity'] as int? ?? (request['sacks'] as int? ?? 1);
    setState(() {
      _selectedRequest = request;
      _allocatedSacks = qty > 0 ? qty : 1;
    });
  }

  void _closeAllocationView() {
    setState(() {
      _selectedRequest = null;
    });
  }

  String _getTimeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recent';
    }
  }

  bool _matchesDateFilter(Map<String, dynamic> req) {
    if (_startDate == null || _endDate == null) return true;
    final dateStr = (req['created_at'] as String?) ?? (req['request_date'] as String?);
    if (dateStr == null || dateStr.isEmpty) return true;

    try {
      final reqDt = DateTime.parse(dateStr).toLocal();
      final reqDateOnly = DateTime(reqDt.year, reqDt.month, reqDt.day);
      final sDate = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final eDate = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);

      if (reqDateOnly.isBefore(sDate)) return false;
      if (reqDt.isAfter(eDate)) return false;
      return true;
    } catch (_) {
      return true;
    }
  }

  void _showFilterModal() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    } else {
      setState(() {
        _startDate = null;
        _endDate = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    final bg = isDark ? PiggyTrunkTheme.ptBgDark : const Color(0xFFF8FAFC);
    final topBarBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1B2638) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28354A) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : _brandColor;
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final fieldBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF8FAFC);

    if (_selectedRequest != null) {
      return _buildAllocationView(
        _selectedRequest!,
        isDark: isDark,
        cardBg: cardBg,
        cardBorder: cardBorder,
        titleColor: titleColor,
        subtitleColor: subtitleColor,
      );
    }

    final allPending = widget.pendingRequests.where((req) {
      final st = (req['status'] as String? ?? 'Pending').toLowerCase();
      return st == 'pending' || st == 'for_approval' || st.isEmpty;
    }).toList();

    final allHistorical = widget.pendingRequests.where((req) {
      final st = (req['status'] as String? ?? '').toLowerCase();
      return st.isNotEmpty && st != 'pending' && st != 'for_approval';
    }).toList();

    List<Map<String, dynamic>> requestsToDisplay = _selectedTab == 0 ? allPending : allHistorical;

    // Filter by Date
    requestsToDisplay = requestsToDisplay.where(_matchesDateFilter).toList();

    // Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      requestsToDisplay = requestsToDisplay.where((req) {
        final raiser = req['hog_raisers'];
        final raiserName = (raiser is Map ? (raiser['name'] ?? raiser['app_users']?['name']) : null)?.toString() ??
            req['raiser_name']?.toString() ??
            '';
        final pName = req['product_name']?.toString() ?? req['item_name']?.toString() ?? '';
        return raiserName.toLowerCase().contains(q) || pName.toLowerCase().contains(q);
      }).toList();
    }

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ==================== TOP BAR & CONTROLS ====================
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: topBarBg,
              border: Border(bottom: BorderSide(color: cardBorder)),
            ),
            child: Column(
              children: [
                // Segmented Pill Navigation Control
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedTab == 0
                                  ? (isDark ? Colors.white : _brandColor)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _selectedTab == 0
                                  ? [
                                      BoxShadow(
                                        color: (isDark ? Colors.white : _brandColor).withValues(alpha: isDark ? 0.12 : 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.pending_actions_rounded,
                                  size: 16,
                                  color: _selectedTab == 0
                                      ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                      : subtitleColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  strings.filterPending,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedTab == 0
                                        ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                        : subtitleColor,
                                  ),
                                ),
                                if (allPending.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 0
                                          ? const Color(0xFFEF4444)
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${allPending.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _selectedTab == 0
                                            ? Colors.white
                                            : (isDark ? Colors.white70 : _brandColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedTab == 1
                                  ? (isDark ? Colors.white : _brandColor)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _selectedTab == 1
                                  ? [
                                      BoxShadow(
                                        color: (isDark ? Colors.white : _brandColor).withValues(alpha: isDark ? 0.12 : 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 16,
                                  color: _selectedTab == 1
                                      ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                      : subtitleColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  strings.requestHistory,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedTab == 1
                                        ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                        : subtitleColor,
                                  ),
                                ),
                                if (allHistorical.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 1
                                          ? (isDark ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.25))
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${allHistorical.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _selectedTab == 1
                                            ? Colors.white
                                            : (isDark ? Colors.white70 : _brandColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Search Box & Date Filter Action Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: fieldBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: const [CapitalizeWordsInputFormatter()],
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: titleColor),
                          decoration: InputDecoration(
                            hintText: strings.searchRequests,
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: subtitleColor,
                            ),
                            prefixIcon: Icon(Icons.search_rounded, color: subtitleColor, size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 16, color: subtitleColor),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showFilterModal,
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: (_startDate != null && _endDate != null)
                              ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                              : cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_startDate != null && _endDate != null) ? _brandBlue : cardBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 15,
                              color: (_startDate != null && _endDate != null) ? _brandBlue : subtitleColor,
                            ),
                            if (_startDate != null && _endDate != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${_startDate!.month}/${_startDate!.day}-${_endDate!.month}/${_endDate!.day}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF93C5FD) : _brandBlue,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ==================== LIST OF REQUESTS ====================
          Expanded(
            child: requestsToDisplay.isEmpty
                ? _buildEmptyState(isDark: isDark, titleColor: titleColor, subtitleColor: subtitleColor)
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: requestsToDisplay.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final req = requestsToDisplay[index];
                      return _selectedTab == 0
                          ? _buildPendingRequestCard(
                              req,
                              isDark: isDark,
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              titleColor: titleColor,
                              subtitleColor: subtitleColor,
                            )
                          : _buildHistoricalCard(
                              req,
                              isDark: isDark,
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              titleColor: titleColor,
                              subtitleColor: subtitleColor,
                            );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    final bool isPending = _selectedTab == 0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isPending
                    ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                    : (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPending ? Icons.task_alt_rounded : Icons.history_toggle_off_rounded,
                size: 48,
                color: isPending ? _brandGreen : _brandBlue,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isPending ? 'All Requests Processed!' : 'No Request History',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isPending
                  ? 'There are no pending stock requests from hog raisers at the moment.'
                  : 'Completed and processed feed allocation requests will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: subtitleColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequestCard(
    Map<String, dynamic> request, {
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    final raiser = request['hog_raisers'] ?? request['raiser'];
    final String raiserName = (raiser is Map ? (raiser['name'] ?? raiser['app_users']?['name']) : null)?.toString() ??
        request['raiser_name']?.toString() ??
        'Hog Raiser';

    final String productName = request['product_name']?.toString() ??
        request['item_name']?.toString() ??
        (request['product'] as Map?)?['name']?.toString() ??
        'Booster Feeds';

    final int quantity = request['quantity'] as int? ?? (request['sacks'] as int? ?? 1);
    final String timeAgo = _getTimeAgo(request['created_at']?.toString() ?? request['request_date']?.toString());
    final int requestId = (request['id'] ?? request['request_id'] ?? 0) as int;

    // Find live stock in inventory
    int inStock = 0;
    for (final p in widget.allProducts) {
      if (p.name.toLowerCase().contains(productName.toLowerCase()) ||
          productName.toLowerCase().contains(p.name.toLowerCase())) {
        inStock = p.units;
        break;
      }
    }
    if (inStock == 0 && widget.allProducts.isNotEmpty) {
      inStock = widget.allProducts.first.units;
    }

    final bool hasEnoughStock = inStock >= quantity;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Raiser info + Pending badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  child: Text(
                    raiserName.isNotEmpty ? raiserName[0].toUpperCase() : 'R',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF93C5FD) : _brandBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        raiserName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: subtitleColor),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.16) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: isDark ? const Color(0xFFFDE68A) : _brandAmber),
                      const SizedBox(width: 5),
                      Text(
                        'PENDING',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFFDE68A) : _brandAmber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cardBorder),

          // Requested Item Details Box
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131E2D) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.inventory_2_rounded,
                              color: isDark ? const Color(0xFF93C5FD) : _brandBlue,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                              Text(
                                'Feed Type • Standard 50kg Sack',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : _brandColor,
                          borderRadius: BorderRadius.circular(10),
                          border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
                        ),
                        child: Text(
                          '$quantity ${quantity == 1 ? 'Sack' : 'Sacks'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFE2E8F0) : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Warehouse Inventory:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: subtitleColor,
                        ),
                      ),
                      Text(
                        hasEnoughStock ? '$inStock sacks in stock' : 'Low stock: only $inStock available',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: hasEnoughStock
                              ? (isDark ? const Color(0xFF6EE7B7) : _brandGreen)
                              : (isDark ? const Color(0xFFFCA5A5) : _brandRed),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons: Allocate & Reject
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => _openAllocationView(request),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : _brandColor,
                        foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Allocate & Approve',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => _showRejectConfirmationDialog(requestId, raiserName, isDark: isDark),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFFFCA5A5),
                        ),
                        foregroundColor: isDark ? const Color(0xFFFCA5A5) : _brandRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Reject',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFFCA5A5) : _brandRed,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalCard(
    Map<String, dynamic> request, {
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    final raiser = request['hog_raisers'] ?? request['raiser'];
    final String raiserName = (raiser is Map ? (raiser['name'] ?? raiser['app_users']?['name']) : null)?.toString() ??
        request['raiser_name']?.toString() ??
        'Hog Raiser';

    final String productName = request['product_name']?.toString() ??
        request['item_name']?.toString() ??
        (request['product'] as Map?)?['name']?.toString() ??
        'Booster Feeds';

    final int quantity = request['quantity'] as int? ?? (request['sacks'] as int? ?? 1);
    final String status = (request['status'] as String? ?? 'Approved').toLowerCase();
    final bool isApproved = status == 'approved' || status == 'completed';
    final String dateStr = _getTimeAgo(request['created_at']?.toString() ?? request['request_date']?.toString());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isApproved
                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                  : (const Color(0xFFFF758C).withValues(alpha: isDark ? 0.15 : 0.1)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isApproved ? _brandGreen : _brandRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      raiserName,
                      style: GoogleFonts.plusJakartaSans(
                         fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                            : (const Color(0xFFFF758C).withValues(alpha: isDark ? 0.15 : 0.1)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isApproved ? 'APPROVED' : 'REJECTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isApproved ? _brandGreen : _brandRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$productName • $quantity Sacks',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectConfirmationDialog(int requestId, String raiserName, {required bool isDark}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151F2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reject Stock Request?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : _brandColor,
          ),
        ),
        content: Text(
          'Are you sure you want to reject the feed request from $raiserName?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.onProcessRequest(requestId, 'Rejected');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Reject Request',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ALLOCATION SHEET VIEW ====================
  Widget _buildAllocationView(
    Map<String, dynamic> request, {
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    final int requestId = (request['id'] ?? request['request_id'] ?? 0) as int;
    final raiser = request['hog_raisers'] ?? request['raiser'];
    final String raiserName = (raiser is Map ? (raiser['name'] ?? raiser['app_users']?['name']) : null)?.toString() ??
        request['raiser_name']?.toString() ??
        'Hog Raiser';

    final String productName = request['product_name']?.toString() ??
        request['item_name']?.toString() ??
        (request['product'] as Map?)?['name']?.toString() ??
        'Booster Feeds';

    final int requestedQty = request['quantity'] as int? ?? (request['sacks'] as int? ?? 1);

    // Live inventory check
    int inStock = 0;
    int? matchedProductId;
    for (final p in widget.allProducts) {
      if (p.name.toLowerCase().contains(productName.toLowerCase()) ||
          productName.toLowerCase().contains(p.name.toLowerCase())) {
        inStock = p.units;
        matchedProductId = int.tryParse(p.id);
        break;
      }
    }
    if (inStock == 0 && widget.allProducts.isNotEmpty) {
      inStock = widget.allProducts.first.units;
      matchedProductId = int.tryParse(widget.allProducts.first.id);
    }

    final double totalWeightKg = _allocatedSacks * 50.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Back Button
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: titleColor),
                onPressed: _closeAllocationView,
              ),
              const SizedBox(width: 4),
              Text(
                'Allocate & Distribute',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Request Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Raiser Details',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: subtitleColor,
                      ),
                    ),
                    Text(
                      'Requested: $requestedQty Sacks',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF38BDF8) : _brandBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  raiserName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Feed Product: $productName',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Allocation Stepper Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              children: [
                Text(
                  'Allocated Sacks to Release',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove_rounded),
                      onPressed: _allocatedSacks > 1 ? () => setState(() => _allocatedSacks--) : null,
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        foregroundColor: titleColor,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131E2D) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF38BDF8) : _brandBlue, width: 1.5),
                      ),
                      child: Text(
                        '$_allocatedSacks',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => setState(() => _allocatedSacks++),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        foregroundColor: titleColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Total Weight: ${totalWeightKg.toStringAsFixed(0)} kg ($inStock available in warehouse)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _allocatedSacks > inStock ? _brandRed : subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Confirm Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : () async {
                      setState(() => _isProcessing = true);
                      await widget.onProcessRequest(
                        requestId,
                        'Approved',
                        allocatedSacks: _allocatedSacks,
                        productId: matchedProductId,
                      );
                      setState(() => _isProcessing = false);
                      _closeAllocationView();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : _brandColor,
                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isProcessing
                  ? CircularProgressIndicator(color: isDark ? const Color(0xFF0F172A) : Colors.white)
                  : Text(
                      'Confirm & Distribute $_allocatedSacks Sacks',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
