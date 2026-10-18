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
  int _selectedTab = 0; // 0 = Pending Requests, 1 = History
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  // Selected request for allocation view
  Map<String, dynamic>? _selectedRequest;
  int _allocatedSacks = 10;
  bool _isProcessing = false;
  Map<int, int> _allocatedPerItem = {};

  int _getProductStock(String productName) {
    final targetLower = productName.toLowerCase().trim();
    for (final p in widget.allProducts) {
      final pNameLower = p.name.toLowerCase().trim();
      if (pNameLower == targetLower || pNameLower.contains(targetLower) || targetLower.contains(pNameLower)) {
        return p.units;
      }
    }
    return 0;
  }

  String _getProductImage(String productName, String? currentImg) {
    if (currentImg != null && currentImg.trim().isNotEmpty && currentImg.trim() != 'null') {
      return currentImg.trim();
    }
    final targetLower = productName.toLowerCase().trim();
    for (final p in widget.allProducts) {
      final pNameLower = p.name.toLowerCase().trim();
      if (pNameLower == targetLower || pNameLower.contains(targetLower) || targetLower.contains(pNameLower)) {
        if (p.image != null && p.image!.trim().isNotEmpty && p.image!.trim() != 'null') {
          return p.image!.trim();
        }
      }
    }
    return '';
  }

  List<Map<String, dynamic>> _groupRequests(List<Map<String, dynamic>> rawRequests) {
    final Map<String, List<Map<String, dynamic>>> groupMap = {};
    for (final req in rawRequests) {
      final raiserKey = (req['fetched_raiser_name'] ?? req['raiser_name'] ?? 'Raiser').toString();
      final batchKey = (req['fetched_batch_name'] ?? req['assignment_id'] ?? '').toString();
      final notesKey = (req['notes'] ?? '').toString().trim();
      final dateKey = (req['request_date'] ?? req['created_at'] ?? '').toString().split('T').first;
      final statusKey = (req['status'] ?? 'pending').toString().toLowerCase();

      final groupKey = '$raiserKey|$batchKey|$notesKey|$dateKey|$statusKey';
      groupMap.putIfAbsent(groupKey, () => []).add(req);
    }

    final List<Map<String, dynamic>> result = [];
    for (final items in groupMap.values) {
      if (items.isEmpty) continue;
      final primary = Map<String, dynamic>.from(items.first);
      primary['bundled_items'] = items;
      result.add(primary);
    }
    return result;
  }

  void _openAllocationView(Map<String, dynamic> request) {
    final bundled = (request['bundled_items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [request];
    final Map<int, int> initialAlloc = {};
    for (final item in bundled) {
      final reqId = (item['request_id'] ?? item['id'] ?? 0) as int;
      final qty = item['quantity'] as int? ?? (item['sacks'] as int? ?? 1);
      initialAlloc[reqId] = qty > 0 ? qty : 1;
    }

    final firstQty = request['quantity'] as int? ?? (request['sacks'] as int? ?? 1);
    setState(() {
      _selectedRequest = request;
      _allocatedSacks = firstQty > 0 ? firstQty : 1;
      _allocatedPerItem = initialAlloc;
    });
  }

  void _closeAllocationView() {
    setState(() {
      _selectedRequest = null;
      _allocatedPerItem.clear();
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

    final bg = isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
    final topBarBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface;
    final cardBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final titleColor = isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText;
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final fieldBg = isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft;

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

    List<Map<String, dynamic>> rawRequests = _selectedTab == 0 ? allPending : allHistorical;

    // Filter by Date
    rawRequests = rawRequests.where(_matchesDateFilter).toList();

    // Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      rawRequests = rawRequests.where((req) {
        final raiserName = (req['fetched_raiser_name'] ?? req['raiser_name'] ?? '').toString();
        final pName = (req['fetched_product_name'] ?? req['feed_type'] ?? req['product_name'] ?? req['item_name'] ?? '').toString();
        final bName = (req['fetched_batch_name'] ?? '').toString();
        final phone = (req['fetched_raiser_phone'] ?? '').toString();
        return raiserName.toLowerCase().contains(q) ||
            pName.toLowerCase().contains(q) ||
            bName.toLowerCase().contains(q) ||
            phone.toLowerCase().contains(q);
      }).toList();
    }

    // Group items from the same submission into bundles
    final List<Map<String, dynamic>> requestsToDisplay = _groupRequests(rawRequests);

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
                    color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
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
                                  ? (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _selectedTab == 0
                                  ? [
                                      BoxShadow(
                                        color: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: isDark ? 0.12 : 0.25),
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
                                      ? (isDark ? PiggyTrunkTheme.ptPrimary : Colors.white)
                                      : subtitleColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  strings.filterPending,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedTab == 0
                                        ? (isDark ? PiggyTrunkTheme.ptPrimary : Colors.white)
                                        : subtitleColor,
                                  ),
                                ),
                                if (allPending.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 0
                                          ? (isDark ? PiggyTrunkTheme.ptPrimary : PiggyTrunkTheme.ptAccent)
                                          : (isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptBorder),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${allPending.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _selectedTab == 0
                                            ? Colors.white
                                            : subtitleColor,
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
                                  ? (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _selectedTab == 1
                                  ? [
                                      BoxShadow(
                                        color: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: isDark ? 0.12 : 0.25),
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
                                      ? (isDark ? PiggyTrunkTheme.ptPrimary : Colors.white)
                                      : subtitleColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  strings.requestHistory,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedTab == 1
                                        ? (isDark ? PiggyTrunkTheme.ptPrimary : Colors.white)
                                        : subtitleColor,
                                  ),
                                ),
                                if (allHistorical.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 1
                                          ? (isDark ? PiggyTrunkTheme.ptPrimary : PiggyTrunkTheme.ptAccent)
                                          : (isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptBorder),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${allHistorical.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _selectedTab == 1
                                            ? Colors.white
                                            : subtitleColor,
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
                              ? (isDark ? PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.2) : PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.08))
                              : cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_startDate != null && _endDate != null)
                                ? (isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary)
                                : cardBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 15,
                              color: (_startDate != null && _endDate != null)
                                  ? (isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary)
                                  : subtitleColor,
                            ),
                            if (_startDate != null && _endDate != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${_startDate!.month}/${_startDate!.day}-${_endDate!.month}/${_endDate!.day}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary,
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 108),
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
                    ? (isDark ? PiggyTrunkTheme.ptSuccessDark.withValues(alpha: 0.15) : PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.12))
                    : (isDark ? PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.2) : PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.08)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPending ? Icons.task_alt_rounded : Icons.history_toggle_off_rounded,
                size: 48,
                color: isPending
                    ? (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess)
                    : (isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary),
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

  String _formatUnit(String category, int qty) {
    final cat = category.toLowerCase();
    if (cat.contains('feed')) {
      return qty == 1 ? 'Sack' : 'Sacks';
    } else if (cat.contains('med') || cat.contains('drug') || cat.contains('inject')) {
      return qty == 1 ? 'Bottle' : 'Bottles';
    } else if (cat.contains('vit')) {
      return qty == 1 ? 'Pack' : 'Packs';
    }
    return qty == 1 ? 'Unit' : 'Units';
  }

  String _getCategorySubtitle(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('feed')) {
      return 'Feed Supply • Standard 50kg Sack';
    } else if (cat.contains('med')) {
      return 'Veterinary Medicine • Standard Unit';
    } else if (cat.contains('vit')) {
      return 'Supplement / Vitamins • Pack Unit';
    }
    return 'Farm Supply';
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('feed')) {
      return Icons.inventory_2_rounded;
    } else if (cat.contains('med')) {
      return Icons.medical_services_rounded;
    } else if (cat.contains('vit')) {
      return Icons.auto_awesome_rounded;
    }
    return Icons.category_rounded;
  }

  Widget _buildAvatar(String avatarUrl, String name, {required bool isDark, double size = 42}) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'R';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isNotEmpty
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(initial, isDark, size: size),
            )
          : _buildAvatarFallback(initial, isDark, size: size),
    );
  }

  Widget _buildAvatarFallback(String initial, bool isDark, {double size = 42}) {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.plusJakartaSans(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary,
        ),
      ),
    );
  }

  Widget _buildProductThumbnail(
    String? imageUrl,
    String category, {
    double size = 52,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final borderColor = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final bg = isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft;

    Widget imageWidget;
    if (imageUrl != null && imageUrl.trim().isNotEmpty && imageUrl.trim() != 'null') {
      imageWidget = Image.network(
        imageUrl.trim(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackCategoryIcon(category, size, isDark),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: size * 0.35,
              height: size * 0.35,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary,
              ),
            ),
          );
        },
      );
    } else {
      imageWidget = _buildFallbackCategoryIcon(category, size, isDark);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: imageWidget,
      ),
    );
  }

  Widget _buildFallbackCategoryIcon(String category, double size, bool isDark) {
    final catLower = category.toLowerCase();
    String? assetPath;
    if (catLower.contains('feed')) {
      assetPath = 'assets/feeds_icon.png';
    } else if (catLower.contains('med')) {
      assetPath = 'assets/medicine_icon.png';
    } else if (catLower.contains('vit')) {
      assetPath = 'assets/vitamins_icon.png';
    }

    if (assetPath != null) {
      return Padding(
        padding: EdgeInsets.all(size * 0.16),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            _getCategoryIcon(category),
            color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary,
            size: size * 0.45,
          ),
        ),
      );
    }

    return Icon(
      _getCategoryIcon(category),
      color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary,
      size: size * 0.45,
    );
  }

  void _showProductImageDialog(
    BuildContext context, {
    required String productName,
    required String? imageUrl,
    required String category,
    required int inStock,
    required bool isDark,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        productName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 180,
                    color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                    child: (imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'null')
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: _buildFallbackCategoryIcon(category, 70, isDark),
                            ),
                          )
                        : Center(
                            child: _buildFallbackCategoryIcon(category, 70, isDark),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary,
                        ),
                      ),
                    ),
                    Text(
                      'Warehouse Stock: $inStock units',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: inStock > 5
                            ? (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess)
                            : (isDark ? const Color(0xFFF87171) : PiggyTrunkTheme.ptAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
    final bundled = (request['bundled_items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [request];
    final String raiserName = (request['fetched_raiser_name'] ??
            request['raiser_name'] ??
            (request['hog_raisers'] is Map ? request['hog_raisers']['name'] : null) ??
            'Hog Raiser')
        .toString();

    final String raiserPhone = (request['fetched_raiser_phone'] ?? request['phone'] ?? '').toString().trim();
    final String raiserAddress = (request['fetched_raiser_address'] ?? request['address'] ?? '').toString().trim();
    final String raiserAvatar = (request['fetched_raiser_avatar'] ?? request['avatar_url'] ?? '').toString().trim();
    final String batchName = (request['fetched_batch_name'] ?? '').toString().trim();

    final String rawProductName = (request['fetched_product_name'] ??
            request['feed_type'] ??
            request['product_name'] ??
            request['item_name'] ??
            '')
        .toString()
        .trim();
    final String productName = rawProductName.isNotEmpty ? rawProductName : 'Feed Supply';

    final String category = (request['category'] ?? 'Feeds').toString();
    final int quantity = request['quantity'] as int? ?? (request['sacks'] as int? ?? 1);
    final String unitLabel = _formatUnit(category, quantity);
    final String notes = (request['notes'] ?? '').toString().trim();

    final String timeAgo = _getTimeAgo(request['created_at']?.toString() ?? request['request_date']?.toString());

    // Live inventory check
    int inStock = 0;
    for (final p in widget.allProducts) {
      final pNameLower = p.name.toLowerCase();
      final targetLower = productName.toLowerCase();
      if (pNameLower == targetLower || pNameLower.contains(targetLower) || targetLower.contains(pNameLower)) {
        inStock = p.units;
        break;
      }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(raiserAvatar, raiserName, isDark: isDark, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            raiserName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
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
                        color: isDark
                            ? PiggyTrunkTheme.ptInProgressDark.withValues(alpha: 0.16)
                            : PiggyTrunkTheme.ptInProgress.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: isDark ? PiggyTrunkTheme.ptInProgressDark : PiggyTrunkTheme.ptInProgress,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'PENDING',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark ? PiggyTrunkTheme.ptInProgressDark : PiggyTrunkTheme.ptInProgress,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Contact & Location Line
                if (raiserPhone.isNotEmpty || raiserAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (raiserPhone.isNotEmpty) ...[
                        Icon(Icons.phone_rounded, size: 12, color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary),
                        const SizedBox(width: 4),
                        Text(
                          raiserPhone,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary,
                          ),
                        ),
                      ],
                      if (raiserPhone.isNotEmpty && raiserAddress.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('•', style: TextStyle(color: subtitleColor, fontSize: 11)),
                        ),
                      ],
                      if (raiserAddress.isNotEmpty) ...[
                        Icon(Icons.location_on_rounded, size: 12, color: subtitleColor),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            raiserAddress,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: subtitleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // Assigned Batch Tag
                if (batchName.isNotEmpty && batchName != 'Unassigned') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_rounded, size: 12, color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary),
                        const SizedBox(width: 4),
                        Text(
                          batchName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: cardBorder),

          // Requested Item Details Box (Supports Single or Multi-Item Bundle)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bundled.length > 1) ...[
                    // Multi-Item Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_rounded, size: 14, color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary),
                            const SizedBox(width: 5),
                            Text(
                              'Requested Supplies (${bundled.length} items)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Tap photo to zoom',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...bundled.map((item) {
                      final itemPName = (item['fetched_product_name'] ?? item['feed_type'] ?? 'Supply').toString();
                      final itemCat = (item['category'] ?? 'Feeds').toString();
                      final itemImg = _getProductImage(itemPName, item['fetched_product_image'] as String?);
                      final itemQty = item['quantity'] as int? ?? (item['sacks'] as int? ?? 1);
                      final itemUnit = _formatUnit(itemCat, itemQty);
                      final itemStock = _getProductStock(itemPName);
                      final isLowStock = itemStock < itemQty;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          children: [
                            _buildProductThumbnail(
                              itemImg,
                              itemCat,
                              size: 52,
                              isDark: isDark,
                              onTap: () => _showProductImageDialog(
                                context,
                                productName: itemPName,
                                imageUrl: itemImg,
                                category: itemCat,
                                inStock: itemStock,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemPName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: titleColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isLowStock
                                        ? 'Low stock: $itemStock avail.'
                                        : '$itemStock available in warehouse',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      color: isLowStock
                                          ? (isDark ? const Color(0xFFF87171) : PiggyTrunkTheme.ptAccent)
                                          : (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptPrimary,
                                borderRadius: BorderRadius.circular(8),
                                border: isDark ? Border.all(color: PiggyTrunkTheme.ptBorderDark) : null,
                              ),
                              child: Text(
                                '$itemQty $itemUnit',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? PiggyTrunkTheme.ptTextDark : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    // Single Item View with Prominent Product Thumbnail
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _buildProductThumbnail(
                                _getProductImage(productName, request['fetched_product_image'] as String?),
                                category,
                                size: 54,
                                isDark: isDark,
                                onTap: () => _showProductImageDialog(
                                  context,
                                  productName: productName,
                                  imageUrl: _getProductImage(productName, request['fetched_product_image'] as String?),
                                  category: category,
                                  inStock: inStock,
                                  isDark: isDark,
                                ),
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
                                    Text(
                                      _getCategorySubtitle(category),
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
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptPrimary,
                            borderRadius: BorderRadius.circular(10),
                            border: isDark ? Border.all(color: PiggyTrunkTheme.ptBorderDark) : null,
                          ),
                          child: Text(
                            '$quantity $unitLabel',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? PiggyTrunkTheme.ptTextDark : Colors.white,
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
                          hasEnoughStock ? '$inStock $unitLabel in stock' : 'Low stock: only $inStock available',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: hasEnoughStock
                                ? (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess)
                                : (isDark ? const Color(0xFFF87171) : PiggyTrunkTheme.ptAccent),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Raiser Notes (if any)
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes_rounded, size: 13, color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              notes,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: isDark ? PiggyTrunkTheme.ptTextDark.withValues(alpha: 0.8) : PiggyTrunkTheme.ptText,
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
                        backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                        foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
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
                            bundled.length > 1 ? 'Allocate Bundle (${bundled.length})' : 'Allocate & Approve',
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
                      onPressed: () => _showRejectConfirmationDialog(request, raiserName, isDark: isDark),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.05) : Colors.transparent,
                        side: BorderSide(
                          color: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.28) : const Color(0xFFFCA5A5),
                        ),
                        foregroundColor: isDark ? const Color(0xFFF87171) : PiggyTrunkTheme.ptAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Reject',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF87171) : PiggyTrunkTheme.ptAccent,
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
    final String raiserName = (request['fetched_raiser_name'] ??
            request['raiser_name'] ??
            (request['hog_raisers'] is Map ? request['hog_raisers']['name'] : null) ??
            'Hog Raiser')
        .toString();

    final String batchName = (request['fetched_batch_name'] ?? '').toString().trim();
    final String rawProductName = (request['fetched_product_name'] ??
            request['feed_type'] ??
            request['product_name'] ??
            request['item_name'] ??
            '')
        .toString()
        .trim();
    final String productName = rawProductName.isNotEmpty ? rawProductName : 'Feed Supply';
    final String category = (request['category'] ?? 'Feeds').toString();
    final int quantity = request['quantity'] as int? ?? (request['sacks'] as int? ?? 1);
    final String unitLabel = _formatUnit(category, quantity);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isApproved
                  ? (isDark ? PiggyTrunkTheme.ptSuccessDark.withValues(alpha: 0.15) : PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.12))
                  : (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.14) : PiggyTrunkTheme.ptAccent.withValues(alpha: 0.12)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isApproved
                  ? (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess)
                  : (isDark ? const Color(0xFFF87171) : PiggyTrunkTheme.ptAccent),
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
                    Expanded(
                      child: Text(
                        raiserName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? (isDark ? PiggyTrunkTheme.ptSuccessDark.withValues(alpha: 0.15) : PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.12))
                            : (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.14) : PiggyTrunkTheme.ptAccent.withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isApproved ? 'APPROVED' : 'REJECTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isApproved
                              ? (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess)
                              : (isDark ? const Color(0xFFF87171) : PiggyTrunkTheme.ptAccent),
                        ),
                      ),
                    ),
                  ],
                ),
                if (batchName.isNotEmpty && batchName != 'Unassigned') ...[
                  const SizedBox(height: 3),
                  Text(
                    batchName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildProductThumbnail(
                      _getProductImage(productName, request['fetched_product_image'] as String?),
                      category,
                      size: 38,
                      isDark: isDark,
                      onTap: () => _showProductImageDialog(
                        context,
                        productName: productName,
                        imageUrl: _getProductImage(productName, request['fetched_product_image'] as String?),
                        category: category,
                        inStock: _getProductStock(productName),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$productName • $quantity $unitLabel',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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

  void _showRejectConfirmationDialog(Map<String, dynamic> request, String raiserName, {required bool isDark}) {
    final bundled = (request['bundled_items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [request];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reject Stock Request?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText,
          ),
        ),
        content: Text(
          bundled.length > 1
              ? 'Are you sure you want to reject this request bundle of ${bundled.length} items from $raiserName?'
              : 'Are you sure you want to reject the feed request from $raiserName?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: isDark ? PiggyTrunkTheme.ptTextDark.withValues(alpha: 0.8) : PiggyTrunkTheme.ptText,
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
              for (final item in bundled) {
                final reqId = (item['request_id'] ?? item['id'] ?? 0) as int;
                await widget.onProcessRequest(reqId, 'Rejected');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFFDC2626) : PiggyTrunkTheme.ptAccent,
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
    final bundled = (request['bundled_items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [request];
    final int requestId = (request['request_id'] ?? request['id'] ?? 0) as int;
    final String raiserName = (request['fetched_raiser_name'] ??
            request['raiser_name'] ??
            (request['hog_raisers'] is Map ? request['hog_raisers']['name'] : null) ??
            'Hog Raiser')
        .toString();

    final String raiserPhone = (request['fetched_raiser_phone'] ?? request['phone'] ?? '').toString().trim();
    final String raiserAddress = (request['fetched_raiser_address'] ?? request['address'] ?? '').toString().trim();
    final String raiserAvatar = (request['fetched_raiser_avatar'] ?? request['avatar_url'] ?? '').toString().trim();
    final String batchName = (request['fetched_batch_name'] ?? '').toString().trim();
    final String notes = (request['notes'] ?? '').toString().trim();

    final String rawProductName = (request['fetched_product_name'] ??
            request['feed_type'] ??
            request['product_name'] ??
            request['item_name'] ??
            '')
        .toString()
        .trim();
    final String productName = rawProductName.isNotEmpty ? rawProductName : 'Feed Supply';
    final String category = (request['category'] ?? 'Feeds').toString();
    final int requestedQty = request['quantity'] as int? ?? (request['sacks'] as int? ?? 1);
    final String unitLabel = _formatUnit(category, _allocatedSacks);
    final String requestedUnitLabel = _formatUnit(category, requestedQty);

    // Live inventory check for single item
    int inStock = _getProductStock(productName);
    int? matchedProductId = request['fetched_product_id'] as int?;
    if (matchedProductId == null) {
      for (final p in widget.allProducts) {
        final pNameLower = p.name.toLowerCase();
        final targetLower = productName.toLowerCase();
        if (pNameLower == targetLower || pNameLower.contains(targetLower) || targetLower.contains(pNameLower)) {
          matchedProductId = int.tryParse(p.id);
          break;
        }
      }
    }
    if (inStock == 0 && widget.allProducts.isNotEmpty) {
      inStock = widget.allProducts.first.units;
      matchedProductId ??= int.tryParse(widget.allProducts.first.id);
    }

    final String singleProductImg = _getProductImage(productName, request['fetched_product_image'] as String?);
    final double totalWeightKg = category.toLowerCase().contains('feed') ? _allocatedSacks * 50.0 : 0.0;

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

          // Raiser Details Card
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
                      'Hog Raiser Profile',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: subtitleColor,
                      ),
                    ),
                    Text(
                      bundled.length > 1
                          ? 'Bundle: ${bundled.length} items'
                          : 'Requested: $requestedQty $requestedUnitLabel',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildAvatar(raiserAvatar, raiserName, isDark: isDark, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            raiserName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          if (raiserPhone.isNotEmpty)
                            Text(
                              '📞 $raiserPhone',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (raiserAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 13, color: subtitleColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          raiserAddress,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: subtitleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (batchName.isNotEmpty && batchName != 'Unassigned') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.layers_rounded, size: 13, color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary),
                      const SizedBox(width: 4),
                      Text(
                        'Target Batch: $batchName',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote_rounded, size: 14, color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            notes,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark ? PiggyTrunkTheme.ptTextDark.withValues(alpha: 0.8) : PiggyTrunkTheme.ptText,
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
          const SizedBox(height: 16),

          if (bundled.length > 1) ...[
            // MULTI-ITEM BUNDLE ALLOCATION VIEW
            Text(
              'Requested Supplies (${bundled.length} items)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 10),
            ...bundled.map((item) {
              final reqId = (item['request_id'] ?? item['id'] ?? 0) as int;
              final itemPName = (item['fetched_product_name'] ?? item['feed_type'] ?? 'Supply').toString();
              final itemCat = (item['category'] ?? 'Feeds').toString();
              final itemImg = _getProductImage(itemPName, item['fetched_product_image'] as String?);
              final itemStock = _getProductStock(itemPName);
              final itemAlloc = _allocatedPerItem[reqId] ?? (item['quantity'] as int? ?? 1);
              final itemUnit = _formatUnit(itemCat, itemAlloc);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildProductThumbnail(
                          itemImg,
                          itemCat,
                          size: 54,
                          isDark: isDark,
                          onTap: () => _showProductImageDialog(
                            context,
                            productName: itemPName,
                            imageUrl: itemImg,
                            category: itemCat,
                            inStock: itemStock,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemPName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$itemStock in warehouse stock',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: itemStock >= itemAlloc
                                      ? (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess)
                                      : (isDark ? const Color(0xFFF87171) : PiggyTrunkTheme.ptAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Allocate $itemUnit:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: subtitleColor,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.remove_rounded, size: 18),
                              onPressed: itemAlloc > 1
                                  ? () {
                                      setState(() {
                                        _allocatedPerItem[reqId] = itemAlloc - 1;
                                      });
                                    }
                                  : null,
                              style: IconButton.styleFrom(
                                backgroundColor: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                                foregroundColor: titleColor,
                                minimumSize: const Size(36, 36),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                '$itemAlloc',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.add_rounded, size: 18),
                              onPressed: () {
                                setState(() {
                                  _allocatedPerItem[reqId] = itemAlloc + 1;
                                });
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                                foregroundColor: titleColor,
                                minimumSize: const Size(36, 36),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),

            // Bundle Confirm Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () async {
                        setState(() => _isProcessing = true);
                        for (final item in bundled) {
                          final reqId = (item['request_id'] ?? item['id'] ?? 0) as int;
                          final allocQty = _allocatedPerItem[reqId] ?? (item['quantity'] as int? ?? 1);
                          final pName = (item['fetched_product_name'] ?? item['feed_type'] ?? '').toString();
                          int? pId = item['fetched_product_id'] as int?;
                          if (pId == null) {
                            for (final p in widget.allProducts) {
                              if (p.name.toLowerCase().trim() == pName.toLowerCase().trim() ||
                                  p.name.toLowerCase().contains(pName.toLowerCase().trim()) ||
                                  pName.toLowerCase().contains(p.name.toLowerCase().trim())) {
                                 pId = int.tryParse(p.id);
                                break;
                              }
                            }
                          }
                          await widget.onProcessRequest(
                            reqId,
                            'Approved',
                            allocatedSacks: allocQty,
                            productId: pId,
                          );
                        }
                        if (mounted) {
                          setState(() => _isProcessing = false);
                          _closeAllocationView();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                  foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isProcessing
                    ? CircularProgressIndicator(color: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white)
                    : Text(
                        'Confirm & Distribute Bundle (${bundled.length} items)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ] else ...[
            // SINGLE ITEM ALLOCATION VIEW
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
                  Text(
                    'Supply Item Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildProductThumbnail(
                        singleProductImg,
                        category,
                        size: 56,
                        isDark: isDark,
                        onTap: () => _showProductImageDialog(
                          context,
                          productName: productName,
                          imageUrl: singleProductImg,
                          category: category,
                          inStock: inStock,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            Text(
                              _getCategorySubtitle(category),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Warehouse Stock Available:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                      Text(
                        '$inStock units',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: inStock > 0
                              ? (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess)
                              : (isDark ? const Color(0xFFF87171) : PiggyTrunkTheme.ptAccent),
                        ),
                      ),
                    ],
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
                    'Allocated $unitLabel to Release',
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
                          backgroundColor: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                          foregroundColor: titleColor,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary, width: 1.5),
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
                          backgroundColor: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                          foregroundColor: titleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (totalWeightKg > 0)
                    Text(
                      'Total Weight: ${totalWeightKg.toStringAsFixed(0)} kg • ($inStock in warehouse)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _allocatedSacks > inStock ? (isDark ? const Color(0xFFF87171) : PiggyTrunkTheme.ptAccent) : subtitleColor,
                      ),
                    )
                  else
                    Text(
                      'Remaining in warehouse after release: ${(inStock - _allocatedSacks).clamp(0, 999999)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _allocatedSacks > inStock ? (isDark ? const Color(0xFFF87171) : PiggyTrunkTheme.ptAccent) : subtitleColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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
                        if (mounted) {
                          setState(() => _isProcessing = false);
                          _closeAllocationView();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                  foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isProcessing
                    ? CircularProgressIndicator(color: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white)
                    : Text(
                        'Confirm & Distribute $_allocatedSacks $unitLabel',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
