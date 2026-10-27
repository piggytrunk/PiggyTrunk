import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../common/shimmer_loading.dart';

class StockRequestsTab extends StatefulWidget {
  final List<Product> products;
  final VoidCallback onProductsReload;
  final void Function(String msg, {Color? backgroundColor}) onShowSnackBar;
  final Future<void> Function({
    required String? productId,
    required String productName,
    required String action,
    required double price,
    required int units,
    String? details,
  })
  onInsertLog;

  const StockRequestsTab({
    super.key,
    required this.products,
    required this.onProductsReload,
    required this.onShowSnackBar,
    required this.onInsertLog,
  });

  @override
  State<StockRequestsTab> createState() => _StockRequestsTabState();
}

class _StockRequestsTabState extends State<StockRequestsTab> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _stockRequests = [];
  bool _isLoadingRequests = false;
  String _requestsFilter = 'All';
  bool _isProcessingRequest = false;

  Map<String, dynamic>? _viewingRequestDetails;
  Map<String, dynamic>? _approvingRequest;
  Map<String, dynamic>? _rejectingRequest;
  final TextEditingController _approvalMsgController = TextEditingController();
  final TextEditingController _rejectionReasonController = TextEditingController();

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => _isDark ? const Color(0xFF132238) : Colors.white;
  Color get _cardBorder =>
      _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _mutedColor =>
      _isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
  Color get _fieldBg =>
      _isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
  Color get _fieldText => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _fieldFocus =>
      _isDark ? const Color(0xFF88A7CE) : const Color(0xFF315C8F);

  @override
  void initState() {
    super.initState();
    _loadStockRequests();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _approvalMsgController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadStockRequests() async {
    if (!mounted) return;
    setState(() => _isLoadingRequests = true);
    try {
      // 1. Fetch raw stock requests
      List<dynamic> res = [];
      try {
        res = await _supabase
            .from('stock_requests')
            .select('*, assignments(*, batches(*))')
            .order('request_date', ascending: false)
            .order('request_id', ascending: false);
      } catch (_) {
        try {
          res = await _supabase
              .from('stock_requests')
              .select('*')
              .order('request_date', ascending: false)
              .order('request_id', ascending: false);
        } catch (e1) {
          try {
            res = await _supabase
                .from('stock_requests')
                .select('*')
                .order('created_at', ascending: false);
          } catch (e2) {
            res = await _supabase.from('stock_requests').select('*');
          }
        }
      }

      // 2. Fetch raisers with app_users
      List<dynamic> raisersRaw = [];
      try {
        raisersRaw = await _supabase
            .from('hog_raisers')
            .select(
              'hog_raiser_id, name, app_users!hog_raisers_user_id_fkey(name, email)',
            );
      } catch (_) {
        try {
          raisersRaw = await _supabase
              .from('hog_raisers')
              .select('hog_raiser_id, name');
        } catch (_) {}
      }

      final Map<String, String> raisersMap = {};
      for (var r in raisersRaw) {
        if (r is! Map) continue;
        final rId = (r['hog_raiser_id'] ?? r['id'])?.toString() ?? '';
        if (rId.isEmpty) continue;

        dynamic appUsersRaw = r['app_users'];
        Map<String, dynamic>? appUsers;
        if (appUsersRaw is Map) {
          appUsers = Map<String, dynamic>.from(appUsersRaw);
        } else if (appUsersRaw is List &&
            appUsersRaw.isNotEmpty &&
            appUsersRaw.first is Map) {
          appUsers = Map<String, dynamic>.from(appUsersRaw.first);
        }

        final googleOrAppName = (appUsers?['name'] ?? '').toString().trim();
        final raiserDbName = (r['name'] ?? '').toString().trim();
        final resolvedName =
            (raiserDbName.isNotEmpty &&
                raiserDbName.toLowerCase() != 'hog raiser' &&
                raiserDbName.toUpperCase() != 'N/A')
            ? raiserDbName
            : (googleOrAppName.isNotEmpty &&
                      googleOrAppName.toLowerCase() != 'hog raiser'
                  ? googleOrAppName
                  : (raiserDbName.isNotEmpty ? raiserDbName : 'Hog Raiser'));

        raisersMap[rId] = resolvedName;
      }

      // 3. Fetch assignments and batches
      List<dynamic> assignmentsRaw = [];
      try {
        assignmentsRaw = await _supabase
            .from('assignments')
            .select('assignment_id, batch_id, hog_raiser_id, status, hog_types(type_name)');
      } catch (_) {
        try {
          assignmentsRaw = await _supabase.from('assignments').select('*');
        } catch (_) {}
      }

      List<dynamic> batchesRaw = [];
      try {
        batchesRaw = await _supabase
            .from('batches')
            .select('batch_id, batch_name');
      } catch (_) {
        try {
          batchesRaw = await _supabase.from('batches').select('*');
        } catch (_) {}
      }

      final Map<String, String> batchNameMap = {};
      for (var b in batchesRaw) {
        if (b is! Map) continue;
        final bId = (b['batch_id'] ?? b['id'])?.toString() ?? '';
        final bName = (b['batch_name'] ?? b['name'])?.toString() ?? '';
        if (bId.isNotEmpty && bName.isNotEmpty) {
          batchNameMap[bId] = bName;
        }
      }

      final Map<String, String> assignToBatchMap = {};
      final Map<String, String> assignToTypeMap = {};
      final Map<String, String> assignToRaiserMap = {};
      final Map<String, String> raiserToActiveBatchMap = {};
      for (var a in assignmentsRaw) {
        if (a is! Map) continue;
        final aId = (a['assignment_id'] ?? a['id'])?.toString() ?? '';
        final bId = a['batch_id']?.toString() ?? '';
        final rId = a['hog_raiser_id']?.toString() ?? '';
        final status = (a['status'] ?? '').toString().toLowerCase();
        final rawHogType = (a['hog_types'] is Map ? a['hog_types']['type_name'] : a['pig_type'])?.toString() ?? '';
        if (aId.isNotEmpty) {
          if (bId.isNotEmpty && batchNameMap.containsKey(bId)) {
            assignToBatchMap[aId] = batchNameMap[bId]!;
          }
          if (rawHogType.isNotEmpty) {
            assignToTypeMap[aId] = rawHogType;
          }
          if (rId.isNotEmpty) {
            assignToRaiserMap[aId] = rId;
          }
        }
        if (rId.isNotEmpty && bId.isNotEmpty && batchNameMap.containsKey(bId)) {
          if (status == 'active' || !raiserToActiveBatchMap.containsKey(rId)) {
            raiserToActiveBatchMap[rId] = batchNameMap[bId]!;
          }
        }
      }

      final List<Map<String, dynamic>> enriched = [];
      for (var r in res) {
        if (r is! Map) continue;
        final rMap = Map<String, dynamic>.from(r);

        final rId = (rMap['hog_raiser_id'] ?? '').toString();
        final aId = (rMap['assignment_id'] ?? '').toString();

        String resolvedName = 'Hog Raiser';
        if (rId.isNotEmpty && raisersMap.containsKey(rId)) {
          resolvedName = raisersMap[rId]!;
        } else if (aId.isNotEmpty &&
            assignToRaiserMap.containsKey(aId) &&
            raisersMap.containsKey(assignToRaiserMap[aId])) {
          resolvedName = raisersMap[assignToRaiserMap[aId]]!;
        } else if ((rMap['user_name'] ?? '').toString().trim().isNotEmpty) {
          resolvedName = (rMap['user_name'] ?? '').toString().trim();
        } else if ((rMap['raiser_name'] ?? '').toString().trim().isNotEmpty) {
          resolvedName = (rMap['raiser_name'] ?? '').toString().trim();
        }

        String resolvedBatch = 'Unassigned';
        final joinedAssignment = rMap['assignments'] is Map
            ? rMap['assignments'] as Map
            : null;
        final joinedBatch = joinedAssignment?['batches'] is Map
            ? joinedAssignment!['batches'] as Map
            : null;
        final joinedBatchName = (joinedBatch?['batch_name'] ?? '')
            .toString()
            .trim();

        if (joinedBatchName.isNotEmpty &&
            joinedBatchName.toLowerCase() != 'null') {
          resolvedBatch = joinedBatchName;
        } else if (aId.isNotEmpty && assignToBatchMap.containsKey(aId)) {
          resolvedBatch = assignToBatchMap[aId]!;
        } else if (rId.isNotEmpty && raiserToActiveBatchMap.containsKey(rId)) {
          resolvedBatch = raiserToActiveBatchMap[rId]!;
        }

        final rawNotesStr = (rMap['notes'] ?? '').toString();
        if ((resolvedBatch == 'Unassigned' || resolvedBatch.isEmpty) &&
            rawNotesStr.contains('[Batch: ') &&
            rawNotesStr.contains(']')) {
          final startIdx = rawNotesStr.indexOf('[Batch: ') + 8;
          final endIdx = rawNotesStr.indexOf(']', startIdx);
          if (endIdx > startIdx) {
            resolvedBatch = rawNotesStr.substring(startIdx, endIdx).trim();
          }
        }
        rMap['notes'] = rawNotesStr.replaceAll(RegExp(r'\[Batch:\s*[^\]]+\]'), '').trim();

        // Attach hog type label if known and not already in batch name
        final hType = assignToTypeMap[aId] ?? (joinedAssignment?['hog_types'] is Map ? joinedAssignment!['hog_types']['type_name'] : null)?.toString();
        if (hType != null && hType.toString().trim().isNotEmpty) {
          final tClean = hType.toString().trim();
          if (!resolvedBatch.toLowerCase().contains(tClean.toLowerCase())) {
            resolvedBatch = '$resolvedBatch ($tClean)';
          }
        }

        rMap['fetched_raiser_name'] = resolvedName;
        rMap['fetched_batch_name'] = resolvedBatch;
        enriched.add(rMap);
      }

      enriched.sort((a, b) {
        final dateA = (a['request_date'] ?? '').toString();
        final dateB = (b['request_date'] ?? '').toString();
        final dateComp = dateB.compareTo(dateA);
        if (dateComp != 0) return dateComp;
        final idA = a['request_id'] is num
            ? (a['request_id'] as num).toInt()
            : (int.tryParse(a['request_id']?.toString() ?? '') ?? 0);
        final idB = b['request_id'] is num
            ? (b['request_id'] as num).toInt()
            : (int.tryParse(b['request_id']?.toString() ?? '') ?? 0);
        return idB.compareTo(idA);
      });

      if (!mounted) return;
      setState(() {
        _stockRequests = enriched;
      });
    } catch (e) {
      debugPrint('Error loading stock requests: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final groupedList = _groupRequests(_stockRequests);
    final filteredRequests = groupedList.where((req) {
      final status = req['status']?.toString().toUpperCase() ?? 'PENDING';
      if (_requestsFilter != 'All' && status != _requestsFilter.toUpperCase()) {
        return false;
      }
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final raiserName = (req['fetched_raiser_name'] ?? '')
            .toString()
            .toLowerCase();
        final items =
            (req['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [req];
        final anyMatch = items.any((i) {
          final cat = (i['category'] ?? '').toString().toLowerCase();
          final feed = (i['feed_type'] ?? '').toString().toLowerCase();
          return cat.contains(q) || feed.contains(q);
        });
        if (!raiserName.contains(q) && !anyMatch) {
          return false;
        }
      }
      return true;
    }).toList();

    if (_viewingRequestDetails != null) {
      return _buildInPageDetailsView(_viewingRequestDetails!);
    }
    if (_approvingRequest != null) {
      return _buildInPageApproveView(_approvingRequest!);
    }
    if (_rejectingRequest != null) {
      return _buildInPageRejectView(_rejectingRequest!);
    }

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
                    style: GoogleFonts.plusJakartaSans(
                      color: _fieldText,
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search request or raiser...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: _mutedColor,
                        fontSize: 13.5,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _mutedColor,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: _fieldBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
                  Row(
                    children: [
                      Expanded(
                        child: _buildRequestFilterChip(
                          'All',
                          'All Requests (${groupedList.length})',
                          isMobile: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildRequestFilterChip(
                          'Pending',
                          'Pending (${groupedList.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'PENDING').length})',
                          isMobile: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildRequestFilterChip(
                          'Approved',
                          'Approved',
                          isMobile: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildRequestFilterChip(
                          'Rejected',
                          'Rejected',
                          isMobile: true,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.plusJakartaSans(
                        color: _fieldText,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Search raiser name, category, or feed type...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: _mutedColor,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _mutedColor,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: _fieldBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _fieldFocus,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Row(
                    children: [
                      _buildRequestFilterChip(
                        'All',
                        'All (${groupedList.length})',
                      ),
                      const SizedBox(width: 8),
                      _buildRequestFilterChip(
                        'Pending',
                        'Pending (${groupedList.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'PENDING').length})',
                      ),
                      const SizedBox(width: 8),
                      _buildRequestFilterChip('Approved', 'Approved'),
                      const SizedBox(width: 8),
                      _buildRequestFilterChip('Rejected', 'Rejected'),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isLoadingRequests
                            ? null
                            : _loadStockRequests,
                        tooltip: 'Refresh requests',
                        icon: _isLoadingRequests
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _isDark
                                      ? Colors.white
                                      : PiggyTrunkTheme.ptPrimary,
                                ),
                              )
                            : Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: _isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
        const SizedBox(height: 18),

        // Requests Table
        if (_isLoadingRequests)
          TableSkeletonLoader(
            isDark: _isDark,
            minWidth: 720,
            cardBg: _cardBg,
            cardBorder: _cardBorder,
            headerBg: _isDark
                ? const Color(0xFF1B2E48)
                : const Color(0xFFEDF4FC),
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(0.95),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(0.85),
              4: FlexColumnWidth(0.8),
              5: FixedColumnWidth(180),
            },
            headers: const [
              'RAISER NAME',
              'REQUEST DATE',
              'ITEM & CATEGORY',
              'QUANTITY',
              'STATUS',
              'ACTIONS',
            ],
            rowCount: 5,
          )
        else if (filteredRequests.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: _mutedColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No stock requests found',
                    style: GoogleFonts.plusJakartaSans(
                      color: _titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Raiser feed and supplies requests will appear here in real-time.',
                    style: GoogleFonts.plusJakartaSans(
                      color: _mutedColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              border: Border.all(color: _cardBorder),
              borderRadius: BorderRadius.circular(18),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = constraints.maxWidth > 920
                      ? constraints.maxWidth
                      : 920.0;
                  return Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.15),
                            1: FlexColumnWidth(1.0),
                            2: FlexColumnWidth(1.5),
                            3: FlexColumnWidth(0.9),
                            4: FlexColumnWidth(0.95),
                            5: FixedColumnWidth(160),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: _isDark
                                    ? const Color(0xFF1B2E48)
                                    : const Color(0xFFEDF4FC),
                                border: Border(
                                  bottom: BorderSide(color: _cardBorder),
                                ),
                              ),
                              children: [
                                _tableHeaderCell('RAISER NAME'),
                                _tableHeaderCell('REQUEST DATE'),
                                _tableHeaderCell('ITEM & CATEGORY'),
                                _tableHeaderCell('QUANTITY'),
                                _tableHeaderCell('STATUS', isCenter: true),
                                _tableHeaderCell('ACTIONS', isCenter: true),
                              ],
                            ),
                            ...filteredRequests.map(
                              (req) => _buildRequestRow(req),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _tableHeaderCell(String label, {bool isCenter = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Text(
        label,
        textAlign: isCenter ? TextAlign.center : TextAlign.start,
        maxLines: 1,
        softWrap: false,
        style: GoogleFonts.plusJakartaSans(
          color: _titleColor,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildRequestFilterChip(
    String filterValue,
    String label, {
    bool isMobile = false,
  }) {
    final isSelected = _requestsFilter == filterValue;
    final activeBg = _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;
    final activeTextColor = _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white;
    final unselectedBg = _isDark
        ? const Color(0xFF1A2B44)
        : const Color(0xFFF1F5F9);
    final unselectedBorder = _isDark
        ? const Color(0xFF28405D)
        : const Color(0xFFE2E8F0);
    final unselectedTextColor = _mutedColor;

    return InkWell(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _requestsFilter = filterValue;
          });
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: BoxConstraints(
          minHeight: isMobile ? 38 : 38,
          minWidth: isMobile ? 0 : 48,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 2 : 16,
          vertical: 8,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeBg : unselectedBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.transparent : unselectedBorder,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isDark ? 0.25 : 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? activeTextColor : unselectedTextColor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: isMobile ? 11.5 : 13,
          ),
        ),
      ),
    );
  }

  TableRow _buildRequestRow(Map<String, dynamic> req) {
    final raiser = req['hog_raisers'] as Map<String, dynamic>?;
    final raiserName =
        req['fetched_raiser_name'] ??
        req['raiser_name'] ??
        req['hog_raiser_name'] ??
        req['user_name'] ??
        raiser?['name'] ??
        'Unknown Raiser';
    final requestDate = _formatDateTimeString(
      req['created_at'] ?? req['request_date'],
    );
    final isGroup = req['is_group'] == true;
    final items =
        (req['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [req];
    final category = req['category']?.toString().trim() ?? 'Feeds';
    final rawFeedType = req['feed_type']?.toString().trim() ?? '';
    final hasDistinctFeedType =
        rawFeedType.isNotEmpty &&
        rawFeedType.toUpperCase() != 'N/A' &&
        rawFeedType.toLowerCase() != category.toLowerCase();
    final mainItem = hasDistinctFeedType ? rawFeedType : category;
    final subItem = hasDistinctFeedType ? category : null;
    final quantity =
        req['total_quantity']?.toString() ?? req['quantity']?.toString() ?? '0';
    final status = req['status']?.toString().toUpperCase() ?? 'PENDING';

    Color statusFg;
    if (status == 'APPROVED') {
      statusFg = const Color(0xFF43CB89);
    } else if (status == 'REJECTED') {
      statusFg = const Color(0xFFFF758C);
    } else {
      statusFg = const Color(0xFFFFAA00);
    }

    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _cardBorder.withValues(alpha: 0.5)),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Text(
            raiserName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: _titleColor,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Text(
            requestDate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: _mutedColor,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: isGroup
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      items
                          .map((i) => (i['feed_type'] ?? i['category']).toString())
                          .where((s) => s.isNotEmpty && s != 'N/A')
                          .join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: _titleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items
                          .map((i) => (i['category'] ?? '').toString())
                          .where((c) => c.isNotEmpty && c != 'N/A')
                          .toSet()
                          .join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: _mutedColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mainItem,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: _titleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    if (subItem != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subItem,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: _mutedColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isGroup ? '$quantity units total' : '$quantity units',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: _titleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              if (isGroup) ...[
                const SizedBox(height: 2),
                Text(
                  '(${items.length} products)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: _mutedColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusFg.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusFg.withValues(alpha: 0.35),
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
                      color: statusFg,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status,
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.plusJakartaSans(
                      color: statusFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Details Action Button
                  Tooltip(
                    message: 'View Request Details',
                    waitDuration: const Duration(milliseconds: 250),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _viewingRequestDetails = req;
                            _approvingRequest = null;
                            _rejectingRequest = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color:
                                (_isDark
                                        ? Colors.white
                                        : PiggyTrunkTheme.ptPrimary)
                                    .withValues(alpha: _isDark ? 0.08 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  (_isDark
                                          ? Colors.white
                                          : PiggyTrunkTheme.ptPrimary)
                                      .withValues(alpha: _isDark ? 0.22 : 0.3),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: _isDark
                                  ? Colors.white
                                  : PiggyTrunkTheme.ptPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (status == 'PENDING') ...[
                    const SizedBox(width: 5),
                    // Quick Approve Icon Button
                    Tooltip(
                      message: 'Approve Request',
                      child: InkWell(
                        onTap: _isProcessingRequest
                            ? null
                            : () {
                                _approvalMsgController.clear();
                                setState(() {
                                  _approvingRequest = req;
                                  _viewingRequestDetails = null;
                                  _rejectingRequest = null;
                                });
                              },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: PiggyTrunkTheme.ptSuccess.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: PiggyTrunkTheme.ptSuccess.withValues(
                                alpha: 0.4,
                              ),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: PiggyTrunkTheme.ptSuccess,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    // Quick Reject Icon Button
                    Tooltip(
                      message: 'Reject Request',
                      child: InkWell(
                        onTap: _isProcessingRequest
                            ? null
                            : () {
                                _rejectionReasonController.clear();
                                setState(() {
                                  _rejectingRequest = req;
                                  _viewingRequestDetails = null;
                                  _approvingRequest = null;
                                });
                              },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF758C,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(
                                0xFFFF758C,
                              ).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Color(0xFFFF758C),
                            ),
                          ),
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
    );
  }



  Widget _buildInPageDetailsView(Map<String, dynamic> req) {
    final isDark = _isDark;
    final drawerBg = isDark ? const Color(0xFF132238) : Colors.white;
    final borderColor = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final mutedColor = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
    final cardBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFE2E8F0);

    final raiser = req['hog_raisers'] as Map<String, dynamic>?;
    final raiserName = req['fetched_raiser_name'] ??
        req['raiser_name'] ??
        req['hog_raiser_name'] ??
        req['user_name'] ??
        raiser?['name'] ??
        'Unknown Raiser';
    final batchName = req['fetched_batch_name'] ?? 'General Stock';
    final requestDate = _formatDateTimeString(
      req['created_at'] ?? req['request_date'],
    );
    final isGroup = req['is_group'] == true;
    final items =
        (req['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [req];
    final status = req['status']?.toString().toUpperCase() ?? 'PENDING';
    final rawNotes = (req['notes'] ?? '').toString().trim();
    final notes = rawNotes.replaceAll(RegExp(r'\[Batch:\s*[^\]]+\]'), '').trim();
    final decisionDate = req['decision_date']?.toString();
    final rejectionReason = (req['rejection_reason'] ?? '').toString().trim();

    Color statusBg;
    Color statusFg;
    IconData statusIcon;
    if (status == 'APPROVED') {
      statusBg = const Color(0x3343CB89);
      statusFg = const Color(0xFF43CB89);
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (status == 'REJECTED') {
      statusBg = const Color(0x33FF758C);
      statusFg = const Color(0xFFFF758C);
      statusIcon = Icons.cancel_outlined;
    } else {
      statusBg = const Color(0x33FFAA00);
      statusFg = const Color(0xFFFFAA00);
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: drawerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _viewingRequestDetails = null);
                    },
                    icon: Icon(Icons.arrow_back_rounded, color: titleColor, size: 20),
                    tooltip: 'Back to Requests',
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.assignment_outlined,
                      color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock Request Details',
                          style: GoogleFonts.plusJakartaSans(
                            color: titleColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isGroup
                              ? '${items.length} Supplies Requested'
                              : 'Request ID #${req['request_id'] ?? ''}',
                          style: GoogleFonts.plusJakartaSans(
                            color: mutedColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _viewingRequestDetails = null);
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back to List'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: titleColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusFg.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: statusFg, size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status: $status',
                              style: GoogleFonts.plusJakartaSans(
                                color: statusFg,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              'Requested on $requestDate',
                              style: GoogleFonts.plusJakartaSans(
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF475569),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Raiser & Batch Card
                  _buildDetailSectionTitle('RAISER & BATCH INFORMATION', titleColor),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          'Hog Raiser',
                          raiserName,
                          Icons.person_outline_rounded,
                          titleColor,
                          mutedColor,
                          isDark,
                        ),
                        const Divider(height: 20, thickness: 0.8),
                        _buildDetailRow(
                          'Assigned Batch',
                          batchName,
                          Icons.layers_outlined,
                          titleColor,
                          mutedColor,
                          isDark,
                        ),
                        const Divider(height: 20, thickness: 0.8),
                        _buildDetailRow(
                          'Date & Time Submitted',
                          requestDate,
                          Icons.schedule_rounded,
                          titleColor,
                          mutedColor,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Requested Item(s) Card
                  _buildDetailSectionTitle(
                    items.length > 1
                        ? 'REQUESTED SUPPLIES (${items.length} ITEMS)'
                        : 'REQUESTED SUPPLY',
                    titleColor,
                  ),
                  const SizedBox(height: 8),
                  ...items.map((it) {
                    final itCat = it['category']?.toString() ?? 'Feeds';
                    final itFeedType = it['feed_type']?.toString() ?? 'N/A';
                    final itQty = it['quantity']?.toString() ?? '0';
                    final itProd = _findMatchingProduct(itCat, itFeedType);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (itProd?.image != null && itProd!.image!.isNotEmpty) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF132238) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: cardBorder.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: Image.network(
                                        itProd.image!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => Icon(
                                          Icons.inventory_2_outlined,
                                          color: mutedColor,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itProd.name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: titleColor,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF1E293B)
                                                    : const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                itCat.toUpperCase(),
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: mutedColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${itProd.units} in stock',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: itProd.units <= 5
                                                    ? const Color(0xFFFF758C)
                                                    : PiggyTrunkTheme.ptSuccess,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          _buildDetailRow(
                            'Category',
                            itCat,
                            Icons.category_outlined,
                            titleColor,
                            mutedColor,
                            isDark,
                          ),
                          const Divider(height: 16, thickness: 0.8),
                          _buildDetailRow(
                            'Item / Feed Type',
                            itFeedType.isNotEmpty && itFeedType != 'N/A'
                                ? itFeedType
                                : itCat,
                            Icons.inventory_2_outlined,
                            titleColor,
                            mutedColor,
                            isDark,
                          ),
                          const Divider(height: 16, thickness: 0.8),
                          _buildDetailRow(
                            'Quantity Requested',
                            '$itQty units / sacks',
                            Icons.format_list_numbered_rounded,
                            titleColor,
                            mutedColor,
                            isDark,
                            isHighlight: true,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 18),

                  // RAISER'S MESSAGE (HIGHLIGHTED)
                  _buildDetailSectionTitle("RAISER'S MESSAGE / NOTE", titleColor),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 16,
                              color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              notes.isNotEmpty
                                  ? 'Message from Raiser'
                                  : 'No Message Attached',
                              style: GoogleFonts.plusJakartaSans(
                                color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notes.isNotEmpty
                              ? notes
                              : 'The raiser did not include any specific notes with this stock request.',
                          style: GoogleFonts.plusJakartaSans(
                            color: notes.isNotEmpty ? titleColor : mutedColor,
                            fontSize: 13.5,
                            fontWeight: notes.isNotEmpty
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontStyle: notes.isNotEmpty
                                ? FontStyle.normal
                                : FontStyle.italic,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Rejection Reason (if rejected)
                  if (status == 'REJECTED' && rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _buildDetailSectionTitle('REJECTION REASON', const Color(0xFFFF758C)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF758C).withValues(alpha: isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: Color(0xFFFF758C),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Admin Reason ($decisionDate)',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFFF758C),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            rejectionReason,
                            style: GoogleFonts.plusJakartaSans(
                              color: titleColor,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: status == 'PENDING'
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _rejectionReasonController.clear();
                              setState(() {
                                _rejectingRequest = req;
                                _viewingRequestDetails = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF758C),
                              side: BorderSide(
                                color: const Color(0xFFFF758C).withValues(
                                  alpha: isDark ? 0.35 : 0.3,
                                ),
                              ),
                              backgroundColor: const Color(0xFFFF758C).withValues(
                                alpha: isDark ? 0.1 : 0.08,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Reject',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _approvalMsgController.clear();
                              setState(() {
                                _approvingRequest = req;
                                _viewingRequestDetails = null;
                              });
                            },
                            icon: const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: Text(
                              isGroup
                                  ? 'Approve & Fulfill (${items.length} Items)'
                                  : 'Approve & Fulfill',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PiggyTrunkTheme.ptSuccess,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _viewingRequestDetails = null);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Close & Return to List',
                          style: GoogleFonts.plusJakartaSans(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInPageApproveView(Map<String, dynamic> req) {
    final isDark = _isDark;
    final drawerBg = isDark ? const Color(0xFF132238) : Colors.white;
    final borderColor = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final mutedColor = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
    final fieldBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
    final fieldBorder = isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);
    final cardBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFEFF6FF);
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFBFDBFE);

    final isGroup = req['is_group'] == true;
    final items =
        (req['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [req];
    final raiser = req['hog_raisers'] as Map<String, dynamic>?;
    final raiserName =
        req['fetched_raiser_name'] ?? raiser?['name'] ?? 'Unknown Raiser';
    final raiserId = req['hog_raiser_id'];
    final batchName = req['fetched_batch_name'] ?? 'General Stock';
    final rawNotes = (req['notes'] ?? '').toString().trim();
    final notes = rawNotes.replaceAll(RegExp(r'\[Batch:\s*[^\]]+\]'), '').trim();

    if (isGroup) {
      final List<Map<String, dynamic>> itemsWithProducts = [];
      for (final item in items) {
        final cat = item['category']?.toString() ?? 'Feeds';
        final feed = item['feed_type']?.toString() ?? '';
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final prod = _findMatchingProduct(cat, feed);
        final hasStock = prod != null && prod.units >= qty;
        itemsWithProducts.add({
          'item': item,
          'product': prod,
          'quantity': qty,
          'has_stock': hasStock,
        });
      }

      return Container(
        decoration: BoxDecoration(
          color: drawerBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() => _approvingRequest = null);
                      },
                      icon: Icon(Icons.arrow_back_rounded, color: titleColor, size: 20),
                      tooltip: 'Cancel & Go Back',
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.task_alt_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Approve Supply Request',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fulfill ${items.length} items for $raiserName',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _approvingRequest = null);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: titleColor,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RAISER & BATCH',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: mutedColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${items.length} Items',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Batch: $batchName',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: mutedColor,
                            ),
                          ),
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF111C2E) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2C3E55) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.speaker_notes_outlined,
                                    size: 15,
                                    color: Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Notes: "$notes"',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                        color: titleColor,
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
                    const SizedBox(height: 20),
                    Text(
                      'ITEMS TO DISPATCH (${items.length})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: mutedColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...itemsWithProducts.map((entry) {
                      final item = entry['item'] as Map<String, dynamic>;
                      final prod = entry['product'] as Product?;
                      final qty = entry['quantity'] as int;
                      final hasStock = entry['has_stock'] as bool;
                      final cat = item['category']?.toString() ?? 'Feeds';
                      final feed = item['feed_type']?.toString() ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasStock
                                ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                                : const Color(0xFFFF758C).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: (prod?.image != null && prod!.image!.isNotEmpty)
                                    ? Image.network(
                                        prod.image!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.inventory_2_outlined,
                                          size: 20,
                                        ),
                                      )
                                    : const Icon(Icons.inventory_2_outlined, size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prod?.name ?? (feed.isNotEmpty ? feed : cat),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Requesting: $qty units • Stock: ${prod?.units ?? 0}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: hasStock
                                          ? (isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B))
                                          : const Color(0xFFFF758C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              hasStock
                                  ? Icons.check_circle_rounded
                                  : Icons.warning_rounded,
                              size: 18,
                              color: hasStock
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFFF758C),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 18),
                    Text(
                      'MESSAGE TO RAISER (OPTIONAL)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: mutedColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _approvalMsgController,
                      maxLines: 3,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: titleColor,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g., Stock approved and ready for pickup tomorrow morning.',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: mutedColor.withValues(alpha: 0.7),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE),
                        contentPadding: const EdgeInsets.all(12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFC),
                  border: Border(
                    top: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _approvingRequest = null);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessingRequest
                            ? null
                            : () async {
                                final msg = _approvalMsgController.text.trim();
                                setState(() => _approvingRequest = null);
                                await _processApproveGroupRequest(
                                  items: items,
                                  req: req,
                                  raiserName: raiserName,
                                  raiserId: raiserId,
                                  approvalMessage: msg.isNotEmpty ? msg : null,
                                );
                              },
                        icon: const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Approve & Dispatch All',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PiggyTrunkTheme.ptSuccess,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Single Request Approval View
    final category = req['category']?.toString() ?? 'Feeds';
    final feedType = req['feed_type']?.toString() ?? '';
    final requestedQuantity = (req['quantity'] as num?)?.toInt() ?? 1;
    final requestId = req['request_id'];
    final matchedProduct = _findMatchingProduct(category, feedType);
    final hasSufficientStock = matchedProduct != null && matchedProduct.units >= requestedQuantity;

    return Container(
      decoration: BoxDecoration(
        color: drawerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _approvingRequest = null);
                    },
                    icon: Icon(Icons.arrow_back_rounded, color: titleColor, size: 20),
                    tooltip: 'Cancel & Go Back',
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Approve Request',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Release stock from inventory',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _approvingRequest = null);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: titleColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REQUEST DETAILS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: mutedColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                category,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Item: ${feedType.isNotEmpty ? feedType : category}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Requested Amount: $requestedQuantity units',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF111C2E) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2C3E55) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.speaker_notes_outlined,
                                  size: 15,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Notes: "$notes"',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                      color: titleColor,
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
                  const SizedBox(height: 20),

                  // Item to Dispatch From Inventory
                  Text(
                    'ITEM TO DISPATCH FROM INVENTORY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: mutedColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasSufficientStock
                            ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                            : const Color(0xFFFF758C).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: (matchedProduct?.image != null && matchedProduct!.image!.isNotEmpty)
                                ? Image.network(
                                    matchedProduct.image!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 20,
                                    ),
                                  )
                                : const Icon(Icons.inventory_2_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                matchedProduct?.name ?? (feedType.isNotEmpty ? feedType : category),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                matchedProduct != null
                                    ? 'In Stock: ${matchedProduct.units} units • Deducting: $requestedQuantity units'
                                    : 'Product not registered in inventory stock table',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: hasSufficientStock ? mutedColor : const Color(0xFFFF758C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          hasSufficientStock ? Icons.check_circle_rounded : Icons.warning_rounded,
                          size: 20,
                          color: hasSufficientStock
                              ? const Color(0xFF10B981)
                              : const Color(0xFFFF758C),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Stock preview banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasSufficientStock
                          ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08)
                          : const Color(0xFFFF758C).withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasSufficientStock
                            ? const Color(0xFF10B981).withValues(alpha: 0.3)
                            : const Color(0xFFFF758C).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasSufficientStock
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          color: hasSufficientStock
                              ? const Color(0xFF10B981)
                              : const Color(0xFFFF758C),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            hasSufficientStock
                                ? 'Stock available. ${matchedProduct.units} units in stock. After dispatch: ${matchedProduct.units - requestedQuantity} units.'
                                : (matchedProduct != null
                                    ? 'Insufficient stock! Only ${matchedProduct.units} units available ($requestedQuantity needed).'
                                    : 'Item "$feedType" is not registered in inventory stock table.'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: hasSufficientStock
                                  ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
                                  : (isDark ? const Color(0xFFFDA4AF) : const Color(0xFF9F1239)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Message to Raiser (Optional)
                  Text(
                    'MESSAGE TO RAISER (OPTIONAL)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: mutedColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _approvalMsgController,
                    maxLines: 3,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: titleColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g., Stock approved and ready for pickup tomorrow morning.',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: mutedColor.withValues(alpha: 0.7),
                      ),
                      filled: true,
                      fillColor: fieldBg,
                      contentPadding: const EdgeInsets.all(12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: fieldBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF10B981),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessingRequest
                          ? null
                          : () {
                              setState(() => _approvingRequest = null);
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: fieldBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: (_isProcessingRequest || !hasSufficientStock)
                          ? null
                          : () async {
                              final msg = _approvalMsgController.text.trim();
                              setState(() => _approvingRequest = null);
                              await _processApproveRequest(
                                requestId: requestId,
                                product: matchedProduct,
                                requestedUnits: requestedQuantity,
                                raiserName: raiserName,
                                raiserId: req['hog_raiser_id'],
                                feedType: feedType,
                                category: category,
                                approvalMessage: msg.isNotEmpty ? msg : null,
                              );
                            },
                      icon: _isProcessingRequest
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _isProcessingRequest ? 'Processing...' : 'Confirm Approval',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInPageRejectView(Map<String, dynamic> req) {
    final isDark = _isDark;
    final drawerBg = isDark ? const Color(0xFF132238) : Colors.white;
    final borderColor = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final mutedColor = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
    final fieldBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
    final fieldBorder = isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);

    final category = req['category']?.toString() ?? 'Feeds';
    final feedType = req['feed_type']?.toString() ?? '';
    final requestedQuantity = (req['quantity'] as num?)?.toInt() ?? 1;
    final raiser = req['hog_raisers'] as Map<String, dynamic>?;
    final raiserName =
        req['fetched_raiser_name'] ?? raiser?['name'] ?? 'Unknown Raiser';
    final requestId = req['request_id'];
    final raiserId = req['hog_raiser_id'];
    final itemDesc = feedType.isNotEmpty
        ? '$requestedQuantity $feedType'
        : '$requestedQuantity $category';

    return Container(
      decoration: BoxDecoration(
        color: drawerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _rejectingRequest = null);
                    },
                    icon: Icon(Icons.arrow_back_rounded, color: titleColor, size: 20),
                    tooltip: 'Cancel & Return',
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF758C).withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.cancel_outlined,
                      color: Color(0xFFFF758C),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reject Stock Request',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Decline supply request from $raiserName',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _rejectingRequest = null);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: titleColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rejection Reason *',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This message will be sent as a notification to the Hog Raiser to explain why their request could not be approved.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: mutedColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _rejectionReasonController,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      color: titleColor,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'e.g., Insufficient warehouse stock, please check back later or update batch details...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: mutedColor,
                      ),
                      filled: true,
                      fillColor: fieldBg,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: fieldBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: fieldBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF758C),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _rejectingRequest = null);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: fieldBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessingRequest
                          ? null
                          : () async {
                              final reasonText = _rejectionReasonController.text.trim();
                              setState(() => _rejectingRequest = null);
                              if (req['is_group'] == true) {
                                final items = (req['items'] as List<dynamic>?)
                                        ?.cast<Map<String, dynamic>>() ??
                                    [req];
                                await _processRejectGroupRequest(
                                  items: items,
                                  raiserId: raiserId,
                                  raiserName: raiserName,
                                  rejectionReason: reasonText,
                                );
                              } else {
                                await _processRejectRequest(
                                  requestId: requestId,
                                  raiserId: raiserId,
                                  raiserName: raiserName,
                                  itemDesc: itemDesc,
                                  rejectionReason: reasonText,
                                );
                              }
                            },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Confirm Rejection',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF758C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSectionTitle(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color titleColor,
    Color mutedColor,
    bool isDark, {
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: mutedColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: mutedColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
              color: isHighlight
                  ? (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
                  : titleColor,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTimeString(dynamic dateVal) {
    if (dateVal == null) return 'N/A';
    final str = dateVal.toString().trim();
    if (str.isEmpty || str == 'N/A') return 'N/A';
    try {
      DateTime dt = DateTime.parse(str).toLocal();
      if (dt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        dt = dt.subtract(dt.timeZoneOffset);
      }
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final formattedDate = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
      if (str.contains('T') || str.contains(':') || str.contains(' ')) {
        final hour = dt.hour > 12
            ? dt.hour - 12
            : (dt.hour == 0 ? 12 : dt.hour);
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final minute = dt.minute.toString().padLeft(2, '0');
        return '$formattedDate • $hour:$minute $ampm';
      }
      return formattedDate;
    } catch (_) {
      return str;
    }
  }

  List<Map<String, dynamic>> _groupRequests(List<Map<String, dynamic>> list) {
    final Map<String, List<Map<String, dynamic>>> groupMap = {};
    for (final req in list) {
      final rKey = (req['hog_raiser_id'] ?? req['fetched_raiser_name'] ?? '')
          .toString();
      final aKey = (req['assignment_id'] ?? '').toString();
      final notesKey = (req['notes'] ?? '').toString().replaceAll(RegExp(r'\[Batch:\s*[^\]]+\]'), '').trim();
      final statusKey = (req['status'] ?? 'pending').toString().toLowerCase();
      final createdAtStr = (req['created_at'] ?? req['request_date'] ?? '')
          .toString();
      String timeKey = createdAtStr;
      try {
        final dt = DateTime.parse(createdAtStr);
        timeKey = '${dt.year}-${dt.month}-${dt.day} ${dt.hour}:${dt.minute}';
      } catch (_) {
        timeKey = createdAtStr;
      }
      final key = [rKey, aKey, timeKey, notesKey, statusKey].join('__');
      groupMap.putIfAbsent(key, () => []).add(req);
    }

    final List<Map<String, dynamic>> result = [];
    for (final items in groupMap.values) {
      final primary = Map<String, dynamic>.from(items.first);
      primary['items'] = items;
      primary['is_group'] = items.length > 1;
      primary['item_count'] = items.length;
      final totalQty = items.fold<int>(0, (sum, i) {
        final q = i['quantity'];
        if (q is num) return sum + q.toInt();
        return sum + (int.tryParse(q?.toString() ?? '1') ?? 1);
      });
      primary['total_quantity'] = totalQty;
      result.add(primary);
    }
    return result;
  }

  Product? _findMatchingProduct(String category, String feedType) {
    final catClean = category.trim().toLowerCase();
    final feedClean = feedType.trim().toLowerCase();

    if (feedClean.isNotEmpty) {
      // 1. Exact name match
      for (final p in widget.products) {
        if (p.name.trim().toLowerCase() == feedClean) {
          return p;
        }
      }

      // 2. Full substring match
      for (final p in widget.products) {
        final pName = p.name.trim().toLowerCase();
        if (pName.contains(feedClean) || feedClean.contains(pName)) {
          return p;
        }
      }

      // 3. Best token overlap match
      Product? bestProduct;
      int bestScore = 0;
      final feedTokens = feedClean
          .split(RegExp(r'[^a-zA-Z0-9]+'))
          .where((t) => t.length > 2)
          .toSet();

      for (final p in widget.products) {
        final pName = p.name.trim().toLowerCase();
        final pTokens = pName
            .split(RegExp(r'[^a-zA-Z0-9]+'))
            .where((t) => t.length > 2)
            .toSet();
        final overlap = feedTokens.intersection(pTokens).length;
        if (overlap > bestScore) {
          bestScore = overlap;
          bestProduct = p;
        }
      }

      if (bestProduct != null && bestScore > 0) {
        return bestProduct;
      }
    }

    // 4. Fallback only if feedType is blank: match first product of same category
    if (feedClean.isEmpty && catClean.isNotEmpty) {
      for (final p in widget.products) {
        final pCat = p.category.trim().toLowerCase();
        if (catClean.contains('feed') || catClean == 'feeds' || catClean == 'pagkain') {
          if (pCat.contains('feed') || pCat == 'feeds') return p;
        } else if (catClean.contains('vitamin') || catClean == 'bitamina') {
          if (pCat.contains('vitamin') || pCat == 'vitamins') return p;
        } else if (catClean.contains('med') || catClean == 'gamot') {
          if (pCat.contains('med') || pCat == 'medicines' || pCat == 'medicine') return p;
        } else if (pCat == catClean) {
          return p;
        }
      }
    }

    return null;
  }

  Future<void> _processApproveGroupRequest({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> req,
    required String raiserName,
    dynamic raiserId,
    String? approvalMessage,
  }) async {
    setState(() => _isProcessingRequest = true);
    try {
      final nowDay = DateTime.now().toIso8601String().split('T').first;
      for (final item in items) {
        final rId = item['request_id'];
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final matchedProd = _findMatchingProduct(
          item['category']?.toString() ?? '',
          item['feed_type']?.toString() ?? '',
        );
        if (matchedProd != null) {
          final newUnits = (matchedProd.units - qty).clamp(0, 999999);
          await _supabase
              .from('inventory_products')
              .update({'units': newUnits})
              .eq('id', matchedProd.id);
          await widget.onInsertLog(
            productId: matchedProd.id,
            productName: matchedProd.name,
            action: 'REQUEST_APPROVE',
            price: matchedProd.price,
            units: newUnits,
            details:
                'Approved in request for $raiserName. Dispatched -$qty units. Remaining: $newUnits.',
          );
        }
        await _supabase
            .from('stock_requests')
            .update({'status': 'approved', 'decision_date': nowDay})
            .eq('request_id', rId);
      }

      if (raiserId != null) {
        // Delete any generic duplicate notifications created by database trigger
        try {
          await _supabase
              .from('raiser_notifications')
              .delete()
              .eq('hog_raiser_id', raiserId)
              .eq('title', 'Stock Request Update');
        } catch (_) {}

        final summary = items
            .map((i) => "${i['quantity']}x ${i['feed_type'] ?? i['category']}")
            .join(', ');
        String notifMessage = 'Your request for $summary has been approved.';
        if (approvalMessage != null && approvalMessage.trim().isNotEmpty) {
          notifMessage += '\n\nNote: "${approvalMessage.trim()}"';
        }

        try {
          await _supabase.from('raiser_notifications').insert({
            'hog_raiser_id': raiserId,
            'title': 'Stock Request Approved',
            'message': notifMessage,
            'type': 'request_approved',
            'is_read': false,
          });
        } catch (_) {}
      }

      widget.onShowSnackBar(
        'Stock request (${items.length} items) for $raiserName approved successfully!',
        backgroundColor: PiggyTrunkTheme.ptSuccess,
      );

      await _loadStockRequests();
      widget.onProductsReload();
    } catch (e) {
      debugPrint('Error approving group stock request: $e');
      widget.onShowSnackBar(
        'Failed to approve request: $e',
        backgroundColor: Colors.redAccent,
      );
    } finally {
      setState(() => _isProcessingRequest = false);
    }
  }

  Future<void> _processRejectGroupRequest({
    required List<Map<String, dynamic>> items,
    required dynamic raiserId,
    required String raiserName,
    required String rejectionReason,
  }) async {
    setState(() => _isProcessingRequest = true);
    try {
      final nowDay = DateTime.now().toIso8601String().split('T').first;
      for (final item in items) {
        final rId = item['request_id'];
        try {
          await _supabase
              .from('stock_requests')
              .update({
                'status': 'rejected',
                'decision_date': nowDay,
                'rejection_reason': rejectionReason.isNotEmpty
                    ? rejectionReason
                    : null,
              })
              .eq('request_id', rId);
        } catch (_) {
          await _supabase
              .from('stock_requests')
              .update({'status': 'rejected', 'decision_date': nowDay})
              .eq('request_id', rId);
        }
      }

      if (raiserId != null) {
        final summary = items
            .map((i) => "${i['quantity']}x ${i['feed_type'] ?? i['category']}")
            .join(', ');
        final notifMsg = rejectionReason.isNotEmpty
            ? 'Your request for $summary has been rejected. Reason: "$rejectionReason"'
            : 'Your request for $summary has been rejected.';
        try {
          await _supabase.from('raiser_notifications').insert({
            'hog_raiser_id': raiserId,
            'title': 'Stock Request Update',
            'message': notifMsg,
            'type': 'request_rejected',
            'is_read': false,
          });
        } catch (_) {}
      }

      widget.onShowSnackBar(
        'Stock request (${items.length} items) from $raiserName has been rejected.',
        backgroundColor: Colors.orange,
      );

      await _loadStockRequests();
    } catch (e) {
      debugPrint('Error rejecting stock request: $e');
      widget.onShowSnackBar(
        'Failed to reject request: $e',
        backgroundColor: Colors.redAccent,
      );
    } finally {
      setState(() => _isProcessingRequest = false);
    }
  }

  Future<void> _processApproveRequest({
    required dynamic requestId,
    Product? product,
    required int requestedUnits,
    required String raiserName,
    dynamic raiserId,
    String feedType = '',
    String category = 'Feeds',
    String? approvalMessage,
  }) async {
    setState(() => _isProcessingRequest = true);
    try {
      int remainingUnits = 0;
      if (product != null) {
        remainingUnits =
            (product.units - requestedUnits).clamp(0, 999999);
        await _supabase
            .from('inventory_products')
            .update({'units': remainingUnits})
            .eq('id', product.id);

        await widget.onInsertLog(
          productId: product.id,
          productName: product.name,
          action: 'REQUEST_APPROVE',
          price: product.price,
          units: remainingUnits,
          details:
              'Approved request for $raiserName. Dispatched -$requestedUnits units. Remaining: $remainingUnits units.',
        );
      }

      final nowDay = DateTime.now().toIso8601String().split('T').first;
      await _supabase
          .from('stock_requests')
          .update({
            'status': 'approved',
            'decision_date': nowDay,
          })
          .eq('request_id', requestId);

      if (raiserId != null) {
        // Delete generic duplicate notifications created by DB trigger
        try {
          await _supabase
              .from('raiser_notifications')
              .delete()
              .eq('hog_raiser_id', raiserId)
              .eq('title', 'Stock Request Update');
        } catch (_) {}

        final itemName =
            product?.name ?? (feedType.isNotEmpty ? feedType : category);
        String notifMessage =
            'Your request for $requestedUnits $itemName has been approved.';
        if (approvalMessage != null && approvalMessage.trim().isNotEmpty) {
          notifMessage += '\n\nNote: "${approvalMessage.trim()}"';
        }

        try {
          await _supabase.from('raiser_notifications').insert({
            'hog_raiser_id': raiserId,
            'title': 'Stock Request Approved',
            'message': notifMessage,
            'type': 'request_approved',
            'is_read': false,
          });
        } catch (_) {}
      }

      widget.onShowSnackBar(
        'Stock request for $raiserName approved successfully! Dispatched $requestedUnits units.',
        backgroundColor: PiggyTrunkTheme.ptSuccess,
      );

      await _loadStockRequests();
      widget.onProductsReload();
    } catch (e) {
      debugPrint('Error approving stock request: $e');
      widget.onShowSnackBar(
        'Failed to approve request: $e',
        backgroundColor: Colors.redAccent,
      );
    } finally {
      setState(() => _isProcessingRequest = false);
    }
  }



  Future<void> _processRejectRequest({
    required dynamic requestId,
    required dynamic raiserId,
    required String raiserName,
    required String itemDesc,
    required String rejectionReason,
  }) async {
    setState(() => _isProcessingRequest = true);
    try {
      try {
        await _supabase
            .from('stock_requests')
            .update({
              'status': 'rejected',
              'decision_date': DateTime.now()
                  .toIso8601String()
                  .split('T')
                  .first,
              'rejection_reason': rejectionReason.isNotEmpty
                  ? rejectionReason
                  : null,
            })
            .eq('request_id', requestId);
      } catch (_) {
        await _supabase
            .from('stock_requests')
            .update({
              'status': 'rejected',
              'decision_date': DateTime.now()
                  .toIso8601String()
                  .split('T')
                  .first,
            })
            .eq('request_id', requestId);
      }

      if (raiserId != null) {
        final notifMsg = rejectionReason.isNotEmpty
            ? 'Your request for $itemDesc has been rejected. Reason: "$rejectionReason"'
            : 'Your request for $itemDesc has been rejected.';
        try {
          await _supabase.from('raiser_notifications').insert({
            'hog_raiser_id': raiserId,
            'title': 'Stock Request Update',
            'message': notifMsg,
            'type': 'request_rejected',
            'is_read': false,
          });
        } catch (notifErr) {
          debugPrint('Error inserting raiser notification: $notifErr');
        }
      }

      widget.onShowSnackBar(
        'Stock request from $raiserName has been rejected.',
        backgroundColor: Colors.orange,
      );

      await _loadStockRequests();
    } catch (e) {
      debugPrint('Error rejecting stock request: $e');
      widget.onShowSnackBar(
        'Failed to reject request: $e',
        backgroundColor: Colors.redAccent,
      );
    } finally {
      setState(() => _isProcessingRequest = false);
    }
  }
}
