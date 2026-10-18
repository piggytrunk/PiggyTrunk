import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:piggytrunk/widgets/common/shimmer_loading.dart';
import '../../utils/app_strings.dart';
import 'widgets/raiser_empty_state.dart';

class RequestHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> raiserData;
  final VoidCallback onBack;
  final List<Map<String, dynamic>>? initialRequests;

  const RequestHistoryScreen({
    super.key,
    required this.raiserData,
    required this.onBack,
    this.initialRequests,
  });

  @override
  State<RequestHistoryScreen> createState() => _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends State<RequestHistoryScreen> {
  String _activeTab = 'All'; // 'All', 'Pending', 'Completed'
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  Map<String, String> _productImages = {};

  static const Color _brandColor = Color(0xFF18314F);
  static const Color _successGreen = Color(0xFF10B981);
  static const Color _warningAmber = Color(0xFFF59E0B);
  static const Color _dangerRed = Color(0xFFFF758C);

  @override
  void initState() {
    super.initState();
    if (widget.initialRequests != null && widget.initialRequests!.isNotEmpty) {
      _requests = List<Map<String, dynamic>>.from(widget.initialRequests!);
      _isLoading = false;
    }
    _fetchRequests();
    _loadProductImages();
  }

  Future<void> _loadProductImages() async {
    try {
      final res = await Supabase.instance.client
          .from('inventory_products')
          .select('name, image, category');
      final Map<String, String> imgMap = {};
      for (var row in (res as List? ?? [])) {
        if (row is! Map) continue;
        final name = (row['name'] ?? '').toString().trim().toLowerCase();
        final img = (row['image'] ?? '').toString().trim();
        final cat = (row['category'] ?? '').toString().trim().toLowerCase();
        if (img.isNotEmpty) {
          if (name.isNotEmpty) imgMap[name] = img;
          if (cat.isNotEmpty && !imgMap.containsKey(cat)) imgMap[cat] = img;
        }
      }
      if (mounted) {
        setState(() {
          _productImages = imgMap;
        });
      }
    } catch (e) {
      debugPrint('Notice loading product images for requests: $e');
    }
  }

  Future<void> _fetchRequests() async {
    final raiserId = widget.raiserData['hog_raiser_id'] ?? widget.raiserData['id'];
    if (raiserId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      List<dynamic> res = [];
      try {
        res = await Supabase.instance.client
            .from('stock_requests')
            .select('*, assignments(status, batches(batch_name, status))')
            .eq('hog_raiser_id', raiserId)
            .order('request_date', ascending: false)
            .order('request_id', ascending: false);
      } catch (err1) {
        debugPrint('Notice: stock_requests joined fetch failed: $err1');
        res = await Supabase.instance.client
            .from('stock_requests')
            .select('*')
            .eq('hog_raiser_id', raiserId)
            .order('request_date', ascending: false)
            .order('request_id', ascending: false);
      }

      if (mounted) {
        final list = List<Map<String, dynamic>>.from(res);
        list.sort((a, b) {
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
        setState(() {
          _requests = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stock requests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _groupRequests(List<Map<String, dynamic>> list) {
    final Map<String, List<Map<String, dynamic>>> groupMap = {};
    for (final req in list) {
      final aKey = (req['assignment_id'] ?? '').toString();
      final notesKey = (req['notes'] ?? '').toString().trim();
      final statusKey = (req['status'] ?? 'pending').toString().toLowerCase();
      final createdAtStr = (req['created_at'] ?? req['request_date'] ?? '').toString();
      String timeKey = createdAtStr;
      try {
        final dt = DateTime.parse(createdAtStr);
        timeKey = '${dt.year}-${dt.month}-${dt.day} ${dt.hour}:${dt.minute}';
      } catch (_) {
        timeKey = createdAtStr;
      }
      final key = [aKey, timeKey, notesKey, statusKey].join('__');
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

  String? _resolveProductImage(String? feedType, String category) {
    final rawFeedName = feedType?.toString().trim().toLowerCase() ?? '';
    final rawCatName = category.trim().toLowerCase();
    String? productImg = _productImages[rawFeedName];
    if (productImg == null || productImg.isEmpty) {
      for (final entry in _productImages.entries) {
        if (rawFeedName.isNotEmpty && (rawFeedName.contains(entry.key) || entry.key.contains(rawFeedName))) {
          productImg = entry.value;
          break;
        }
      }
    }
    productImg ??= _productImages[rawCatName];
    return productImg;
  }

  String _formatUnitString(BuildContext context, String category, int quantity) {
    final strings = AppStrings.of(context);
    final cat = category.toLowerCase();
    if (cat.contains('feed')) {
      return quantity == 1
          ? (strings.isFilipino ? 'Sako' : 'Sack')
          : (strings.isFilipino ? 'mga Sako' : 'Sacks');
    }
    return quantity == 1
        ? (strings.isFilipino ? 'Piraso' : 'Unit')
        : (strings.isFilipino ? 'mga Piraso' : 'Units');
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('vit')) return Icons.medication_liquid_rounded;
    if (cat.contains('med')) return Icons.medical_services_rounded;
    return Icons.grass_rounded;
  }

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('vit')) return const Color(0xFF8B5CF6);
    if (cat.contains('med')) return _dangerRed;
    return const Color(0xFF10B981);
  }

  List<Map<String, dynamic>> get _groupedRequests => _groupRequests(_requests);

  List<Map<String, dynamic>> get _filteredRequests {
    final grouped = _groupedRequests;
    if (_activeTab == 'All' || _activeTab == 'Lahat') return grouped;
    if (_activeTab == 'Pending') {
      return grouped.where((r) {
        final s = (r['status'] ?? '').toString().toLowerCase();
        return s == 'pending' || s == 'for_approval';
      }).toList();
    }
    // Completed includes approved, rejected, delivered, completed
    return grouped.where((r) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      return s != 'pending' && s != 'for_approval';
    }).toList();
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateStr).toLocal();
      if (date.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        date = date.subtract(date.timeZoneOffset);
      }
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final formattedDate = '${months[date.month - 1]} ${date.day}, ${date.year}';

      if (dateStr.contains('T') || dateStr.contains(' ') || dateStr.contains(':')) {
        final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
        final ampm = date.hour >= 12 ? 'PM' : 'AM';
        final minute = date.minute.toString().padLeft(2, '0');
        return '$formattedDate • $hour:$minute $ampm';
      }
      return formattedDate;
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
    final surfaceBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final textColor = isDark ? Colors.white : _brandColor;
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

    final grouped = _groupedRequests;
    final filtered = _filteredRequests;

    final int pendingCount = grouped.where((r) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      return s == 'pending' || s == 'for_approval';
    }).length;

    final int completedCount = grouped.where((r) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      return s != 'pending' && s != 'for_approval';
    }).length;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Segmented Toggle: [ Request Supplies ] [ My Requests ]
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: widget.onBack,
                        borderRadius: BorderRadius.circular(10),
                        child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 16, color: mutedColor),
                                const SizedBox(width: 6),
                                Text(
                                  strings.isFilipino ? 'Humiling ng Supply' : 'Request Supplies',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: mutedColor,
                                  ),
                                ),
                              ],
                            ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 16, color: isDark ? Colors.white : _brandColor),
                              const SizedBox(width: 6),
                              Text(
                                strings.isFilipino ? 'Aking Requests' : 'My Requests',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : _brandColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterChip(
                      'All',
                      strings.filterAll,
                      grouped.length,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFilterChip(
                      'Pending',
                      strings.filterPending,
                      pendingCount,
                      color: _warningAmber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFilterChip(
                      'Completed',
                      strings.isFilipino ? 'Natapos' : 'Completed',
                      completedCount,
                      color: _successGreen,
                    ),
                  ),
                ],
              ),
            ),

            // ==================== HISTORY LOGS LIST / EMPTY STATE ====================
            Expanded(
              child: _isLoading
                  ? ShimmerProvider(
                      child: ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 108),
                        itemCount: 5,
                        itemBuilder: (context, _) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B2A3F) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF28354A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              ShimmerBox(
                                width: 44,
                                height: 44,
                                borderRadius: BorderRadius.circular(12),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ShimmerBox(
                                      width: 150,
                                      height: 15,
                                      borderRadius: BorderRadius.circular(4),
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 6),
                                    ShimmerBox(
                                      width: 100,
                                      height: 12,
                                      borderRadius: BorderRadius.circular(4),
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                              ),
                              ShimmerBox(
                                width: 70,
                                height: 24,
                                borderRadius: BorderRadius.circular(12),
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: RaiserEmptyState(
                              icon: Icons.history_rounded,
                              message: strings.noStockRequestsYet,
                              subtitle: strings.isFilipino
                                  ? 'Wala pang rekord ng mga kahilingan.'
                                  : 'No request records available.',
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchRequests,
                          color: isDark ? Colors.white : _brandColor,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 108),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final req = filtered[index];
                              final isGroup = req['is_group'] == true;
                              final items = (req['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [req];
                              final dateStr = _formatDateString(req['created_at']?.toString() ?? req['request_date']?.toString());
                              final status = (req['status'] ?? 'Pending').toString();
                              final notes = (req['notes'] ?? '').toString().trim();
                              final displayNotes = notes.replaceAll(RegExp(r'\[Batch:\s*[^\]]+\]'), '').trim();
                              final rawBatchName = (req['assignments']?['batches']?['batch_name'] ?? 'Batch').toString();

                              String batchName = rawBatchName;
                              if (rawBatchName.contains('(')) {
                                final parts = rawBatchName.split('(');
                                if (parts.last.endsWith(')')) {
                                  batchName = parts.sublist(0, parts.length - 1).join('(').trim();
                                }
                              }
                              if ((batchName == 'Batch' || batchName == 'Unassigned') && notes.contains('[Batch: ') && notes.contains(']')) {
                                final startIdx = notes.indexOf('[Batch: ') + 8;
                                final endIdx = notes.indexOf(']', startIdx);
                                if (endIdx > startIdx) {
                                  batchName = notes.substring(startIdx, endIdx).trim();
                                }
                              }

                              final assignStatus = (req['assignments']?['status'] ?? '').toString().toLowerCase();
                              final batchStatus = (req['assignments']?['batches']?['status'] ?? '').toString().toLowerCase();
                              final isConcluded = assignStatus == 'completed' ||
                                  assignStatus == 'finished' ||
                                  batchStatus == 'completed' ||
                                  batchStatus == 'archived' ||
                                  batchStatus == 'sold' ||
                                  batchStatus == 'finished';

                              Color statusColor;
                              Color statusBgColor;

                              final lowerStatus = status.toLowerCase();
                              if (lowerStatus == 'approved') {
                                statusColor = _successGreen;
                                statusBgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
                              } else if (lowerStatus == 'pending' || lowerStatus == 'for_approval') {
                                statusColor = _warningAmber;
                                statusBgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB);
                              } else if (lowerStatus == 'rejected' || lowerStatus == 'cancelled') {
                                statusColor = _dangerRed;
                                statusBgColor = _dangerRed.withValues(alpha: isDark ? 0.15 : 0.1);
                              } else {
                                statusColor = const Color(0xFF6366F1);
                                statusBgColor = isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF);
                              }

                              if (isGroup) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isConcluded
                                        ? (isDark ? const Color(0xFF142032) : const Color(0xFFF8FAFC))
                                        : surfaceBg,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isConcluded
                                          ? (isDark ? Colors.white12 : const Color(0xFFE2E8F0))
                                          : cardBorder,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header
                                      Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white.withValues(alpha: 0.08) : _brandColor.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isDark ? Colors.white.withValues(alpha: 0.15) : _brandColor.withValues(alpha: 0.15),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.inventory_2_rounded,
                                                color: isDark ? Colors.white : _brandColor,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  strings.isFilipino ? 'Kahilingan ng Gamit' : 'Supply Request',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: textColor,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Wrap(
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: [
                                                    Text(
                                                      '$batchName • $dateStr',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 12,
                                                        color: mutedColor,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    if (isConcluded)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(5),
                                                          border: Border.all(
                                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          strings.isFilipino ? 'Tapos na' : 'Concluded',
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w700,
                                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusBgColor,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                                            ),
                                            child: Text(
                                              strings.formatStatus(status).toUpperCase(),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: statusColor,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      // Group Items List
                                      ...items.map((item) {
                                        final itemCat = (item['category'] ?? 'Feeds').toString();
                                        final itemFeed = item['feed_type'];
                                        final itemQty = (item['quantity'] as num?)?.toInt() ?? 1;
                                        final itemUnitWord = _formatUnitString(context, itemCat, itemQty);
                                        final itemImg = _resolveProductImage(itemFeed?.toString(), itemCat);
                                        final itemCatIcon = _getCategoryIcon(itemCat);
                                        final itemCatColor = _getCategoryColor(itemCat);
                                        final itemDisplayName = (itemFeed != null && itemFeed.toString().trim().isNotEmpty)
                                            ? itemFeed.toString().trim()
                                            : itemCat;

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF283A52) : const Color(0xFFE2E8F0),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Crisp Pure White Container with BoxFit.contain - NO background tint!
                                              Container(
                                                width: 42,
                                                height: 42,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: const Color(0xFFE2E8F0),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                padding: const EdgeInsets.all(2.5),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: (itemImg != null && itemImg.isNotEmpty)
                                                      ? Image.network(
                                                          itemImg,
                                                          width: 37,
                                                          height: 37,
                                                          fit: BoxFit.contain,
                                                          errorBuilder: (_, _, _) => Icon(itemCatIcon, color: itemCatColor, size: 20),
                                                        )
                                                      : Icon(itemCatIcon, color: itemCatColor, size: 20),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      itemDisplayName,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: textColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: itemCatColor.withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        itemCat.toUpperCase(),
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w800,
                                                          color: itemCatColor,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  '$itemQty $itemUnitWord',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: textColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),

                                      if (displayNotes.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.notes_rounded, size: 14, color: mutedColor),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  displayNotes,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11.5,
                                                    color: mutedColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (lowerStatus == 'rejected' && (req['rejection_reason'] != null && req['rejection_reason'].toString().trim().isNotEmpty)) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _dangerRed.withValues(alpha: isDark ? 0.15 : 0.08),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: _dangerRed.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.info_outline_rounded, size: 14, color: _dangerRed),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  '${strings.isFilipino ? "Dahilan" : "Reason"}: ${req['rejection_reason']}',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11.5,
                                                    color: _dangerRed,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }

                              // Single item request
                              final category = (req['category'] ?? 'Feeds').toString();
                              final feedType = req['feed_type'];
                              final quantity = (req['quantity'] as num?)?.toInt() ?? 1;
                              final unitWord = _formatUnitString(context, category, quantity);
                              final ofWord = strings.isFilipino ? 'ng' : 'of';
                              String titleText = '$quantity $unitWord $ofWord $category';
                              if (feedType != null && feedType.toString().trim().isNotEmpty && feedType.toString().trim().toLowerCase() != category.toLowerCase()) {
                                titleText = '$quantity $unitWord $ofWord ${feedType.toString().trim()}';
                              }

                              final productImg = _resolveProductImage(feedType?.toString(), category);
                              final itemIcon = _getCategoryIcon(category);
                              final itemColor = _getCategoryColor(category);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isConcluded
                                      ? (isDark ? const Color(0xFF142032) : const Color(0xFFF8FAFC))
                                      : surfaceBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isConcluded
                                        ? (isDark ? Colors.white12 : const Color(0xFFE2E8F0))
                                        : cardBorder,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Crisp Pure White Container with BoxFit.contain - NO background tint!
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                              width: 1.0,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(3.0),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(9),
                                            child: (productImg != null && productImg.isNotEmpty)
                                                ? Image.network(
                                                    productImg,
                                                    width: 40,
                                                    height: 40,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, _, _) => Icon(itemIcon, color: itemColor, size: 22),
                                                  )
                                                : Icon(itemIcon, color: itemColor, size: 22),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                titleText,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: textColor,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  Text(
                                                    '$batchName • $dateStr',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      color: mutedColor,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  if (isConcluded)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                                        borderRadius: BorderRadius.circular(5),
                                                        border: Border.all(
                                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        strings.isFilipino ? 'Tapos na' : 'Concluded',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusBgColor,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                                          ),
                                          child: Text(
                                            strings.formatStatus(status).toUpperCase(),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: statusColor,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (notes.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.notes_rounded, size: 14, color: mutedColor),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                notes,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11.5,
                                                  color: mutedColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (lowerStatus == 'rejected' && (req['rejection_reason'] != null && req['rejection_reason'].toString().trim().isNotEmpty)) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _dangerRed.withValues(alpha: isDark ? 0.15 : 0.08),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: _dangerRed.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.info_outline_rounded, size: 14, color: _dangerRed),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '${strings.isFilipino ? "Dahilan" : "Reason"}: ${req['rejection_reason']}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11.5,
                                                  color: _dangerRed,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, int count, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _activeTab == key;
    final inactiveBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final inactiveBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final inactiveText = isDark ? Colors.white : _brandColor;
    final selectedBg = isDark ? Colors.white : _brandColor;
    final selectedText = isDark ? const Color(0xFF0F172A) : Colors.white;

    return GestureDetector(
      onTap: () => setState(() => _activeTab = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? selectedBg : inactiveBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? Colors.white : _brandColor).withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? selectedText : inactiveText,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.22))
                    : (color?.withValues(alpha: isDark ? 0.2 : 0.12) ?? (isDark ? const Color(0xFF1E293B) : PiggyTrunkTheme.ptBg)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? selectedText : (color ?? inactiveText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
