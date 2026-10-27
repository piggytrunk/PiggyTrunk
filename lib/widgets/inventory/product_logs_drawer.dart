import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_log_model.dart';
import '../../theme/app_theme.dart';
import '../common/shimmer_loading.dart';

class ProductLogsDrawer extends StatefulWidget {
  final String? filterProductId;
  final String? filterProductName;
  final VoidCallback? onClearFilter;
  final bool isBottomSheet;
  final bool isModal;
  final ScrollController? scrollController;
  /// When set, the widget renders as full in-page content and this closes it.
  final VoidCallback? onClose;

  const ProductLogsDrawer({
    super.key,
    this.filterProductId,
    this.filterProductName,
    this.onClearFilter,
    this.isBottomSheet = false,
    this.isModal = false,
    this.scrollController,
    this.onClose,
  });

  static void showModal({
    required BuildContext context,
    String? filterProductId,
    String? filterProductName,
    VoidCallback? onClearFilter,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    if (isMobile) {
      showBottomSheet(
        context: context,
        filterProductId: filterProductId,
        filterProductName: filterProductName,
        onClearFilter: onClearFilter,
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final modalWidth = (size.width > 1200) ? 900.0 : (size.width > 800 ? 760.0 : size.width * 0.95);
    final modalHeight = size.height * 0.88;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Inventory Activity Logs',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogCtx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (dialogCtx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: modalWidth,
                  height: modalHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [const Color(0xFF1A2940), const Color(0xFF0F1C2F)]
                          : [Colors.white, const Color(0xFFF8FAFC)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                        blurRadius: 36,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: ProductLogsDrawer(
                      filterProductId: filterProductId,
                      filterProductName: filterProductName,
                      onClearFilter: onClearFilter,
                      isBottomSheet: false,
                      isModal: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static void showBottomSheet({
    required BuildContext context,
    String? filterProductId,
    String? filterProductName,
    VoidCallback? onClearFilter,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => ProductLogsDrawer(
          filterProductId: filterProductId,
          filterProductName: filterProductName,
          onClearFilter: onClearFilter,
          isBottomSheet: true,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  State<ProductLogsDrawer> createState() => _ProductLogsDrawerState();
}

class _ProductLogsDrawerState extends State<ProductLogsDrawer> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ProductLog> _logs = [];
  bool _isLoadingLogs = false;
  String? _selectedLogFilter;
  String? _logsErrorMessage;

  String? _activeProductId;
  String? _activeProductName;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => _isDark ? const Color(0xFF132238) : Colors.white;
  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _mutedColor => _isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
  Color get _accentDark => _isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent;

  @override
  void initState() {
    super.initState();
    _activeProductId = widget.filterProductId;
    _activeProductName = widget.filterProductName;
    _loadLogs();
  }

  @override
  void didUpdateWidget(covariant ProductLogsDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterProductId != widget.filterProductId ||
        oldWidget.filterProductName != widget.filterProductName) {
      setState(() {
        _activeProductId = widget.filterProductId;
        _activeProductName = widget.filterProductName;
      });
      _loadLogs();
    }
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLogs = true;
      _logsErrorMessage = null;
    });
    try {
      var query = _supabase.from('inventory_logs').select();
      if (_activeProductId != null) {
        query = query.eq('product_id', _activeProductId!);
      }
      final response = await query.order('created_at', ascending: false);
      final list = response as List;
      final parsed = list.map((e) => ProductLog.fromJson(e)).toList();

      if (!mounted) return;
      setState(() {
        _logs = parsed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logsErrorMessage = 'Could not load activity logs.\nMake sure the database table is created: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingLogs = false);
      }
    }
  }

  String _formatDate(DateTime dt) {
    final localDt = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[localDt.month - 1];
    final day = localDt.day.toString().padLeft(2, '0');
    final year = localDt.year;
    final hourVal = localDt.hour > 12 ? localDt.hour - 12 : (localDt.hour == 0 ? 12 : localDt.hour);
    final hour = hourVal.toString().padLeft(2, '0');
    final minute = localDt.minute.toString().padLeft(2, '0');
    final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, $year $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final title = _activeProductName != null
        ? 'History: $_activeProductName'
        : 'Inventory Activity Logs';

    final filteredList = _logs.where((log) {
      if (_selectedLogFilter == null) return true;
      final actionUpper = log.action.toUpperCase();
      if (_selectedLogFilter == 'ADD') return actionUpper == 'ADD';
      if (_selectedLogFilter == 'UPDATE') return actionUpper == 'UPDATE' || actionUpper == 'PRICE UPDATE';
      if (_selectedLogFilter == 'PRICE UPDATE') {
        return actionUpper == 'PRICE UPDATE' || (log.details != null && log.details!.toLowerCase().contains('price'));
      }
      if (_selectedLogFilter == 'RESTOCK') return actionUpper == 'RESTOCK';
      return true;
    }).toList();

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isBottomSheet) ...[
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(24, widget.isBottomSheet ? 12 : 24, 24, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.onClose != null) ...[
                Material(
                  color: _isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: widget.onClose,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (_activeProductName != null) ...[
                      InkWell(
                        onTap: () {
                          setState(() {
                            _activeProductId = null;
                            _activeProductName = null;
                          });
                          widget.onClearFilter?.call();
                          _loadLogs();
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Showing only this product. Click to clear.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                color: _accentDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.clear, size: 12, color: _accentDark),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Real-time log of product addition & updates.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: _mutedColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: _isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _isLoadingLogs ? null : _loadLogs,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _isLoadingLogs
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            ),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            size: 20,
                          ),
                  ),
                ),
              ),
              if (widget.onClose == null) ...[
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.close_rounded, color: _mutedColor, size: 20),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildLogFilterChip(null, 'All Actions'),
                const SizedBox(width: 8),
                _buildLogFilterChip('ADD', 'Creations'),
                const SizedBox(width: 8),
                _buildLogFilterChip('UPDATE', 'Updates'),
                const SizedBox(width: 8),
                _buildLogFilterChip('PRICE UPDATE', 'Price Changes'),
                const SizedBox(width: 8),
                _buildLogFilterChip('RESTOCK', 'Restocks'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _isLoadingLogs
              ? _buildLogsSkeleton()
              : _logsErrorMessage != null
                  ? _buildLogsErrorState()
                  : filteredList.isEmpty
                      ? _buildLogsEmptyState()
                      : ListView.builder(
                          controller: widget.scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            return _buildLogItem(filteredList[index]);
                          },
                        ),

        ),
      ],
    );

    if (widget.onClose != null) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(color: Colors.transparent, child: content),
      );
    }

    if (widget.isModal) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(child: content),
      );
    }

    if (widget.isBottomSheet) {
      return Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: content,
      );
    }

    return Drawer(
      width: MediaQuery.of(context).size.width > 600 ? 550 : double.infinity,
      backgroundColor: _cardBg,
      child: SafeArea(child: content),
    );
  }

  Widget _buildLogFilterChip(String? filterValue, String label) {
    final isSelected = _selectedLogFilter == filterValue;
    final activeBg = _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;
    final activeTextColor = _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white;
    final unselectedBg = _isDark ? const Color(0xFF1A2B44) : const Color(0xFFF1F5F9);
    final unselectedBorder = _isDark ? const Color(0xFF28405D) : const Color(0xFFE2E8F0);
    final unselectedTextColor = _mutedColor;

    return InkWell(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _selectedLogFilter = filterValue;
          });
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : unselectedBg,
          borderRadius: BorderRadius.circular(20),
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
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? activeTextColor : unselectedTextColor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLogsErrorState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isDark ? const Color(0x11FF758C) : const Color(0xFFFFF0F2),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Database Setup Required',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'To view and record real-time product logs, the database table must be created in your Supabase project.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: _titleColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_toggle_off_rounded, size: 36, color: _mutedColor),
            ),
            const SizedBox(height: 16),
            Text(
              'No Activity Logs Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Stock changes and product updates will appear here automatically.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: _mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(ProductLog log) {
    Color badgeBg;
    Color badgeFg;
    IconData icon;

    switch (log.action.toUpperCase()) {
      case 'ADD':
        badgeBg = _isDark ? const Color(0x2210B981) : const Color(0xFFDCFCE7);
        badgeFg = _isDark ? const Color(0xFF34D399) : const Color(0xFF166534);
        icon = Icons.add_circle_outline_rounded;
        break;
      case 'PRICE UPDATE':
        badgeBg = _isDark ? const Color(0x22F59E0B) : const Color(0xFFFEF3C7);
        badgeFg = _isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
        icon = Icons.price_change_outlined;
        break;
      case 'UPDATE':
        badgeBg = _isDark ? const Color(0x223B82F6) : const Color(0xFFDBEAFE);
        badgeFg = _isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF);
        icon = Icons.edit_note_rounded;
        break;
      case 'RESTOCK':
        badgeBg = _isDark ? const Color(0x228B5CF6) : const Color(0xFFEDE9FE);
        badgeFg = _isDark ? const Color(0xFFA78BFA) : const Color(0xFF5B21B6);
        icon = Icons.add_shopping_cart_rounded;
        break;
      default:
        badgeBg = _isDark ? const Color(0x2294A3B8) : const Color(0xFFF1F5F9);
        badgeFg = _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1A2B44) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDark ? const Color(0xFF28405D) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: badgeFg),
                    const SizedBox(width: 4),
                    Text(
                      log.action.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: badgeFg,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(log.createdAt),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: _mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            log.productName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: _titleColor,
            ),
          ),
          if (log.details != null && log.details!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF132035) : const Color(0xFFEFF5FC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isDark ? const Color(0xFF283B55) : const Color(0xFFD6E4F5),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1, right: 8),
                    child: Icon(
                      log.action.toUpperCase() == 'PRICE UPDATE' || (log.details?.contains('Price:') == true)
                          ? Icons.price_change_outlined
                          : Icons.info_outline_rounded,
                      size: 15,
                      color: log.action.toUpperCase() == 'PRICE UPDATE' || (log.details?.contains('Price:') == true)
                          ? (_isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                          : _mutedColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      log.details!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Price: ₱${log.price.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _mutedColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Stock: ${log.units} units',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _mutedColor,
                ),
              ),
              const Spacer(),
              Text(
                'By: ${log.performedBy.split('@').first}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSkeleton() {
    return ShimmerProvider(
      child: ListView.builder(
        controller: widget.scrollController,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF1A2B44) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDark ? const Color(0xFF28405D) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShimmerBox(
                      width: 76,
                      height: 22,
                      borderRadius: BorderRadius.circular(6),
                      isDark: _isDark,
                    ),
                    const Spacer(),
                    ShimmerBox(
                      width: 110,
                      height: 12,
                      borderRadius: BorderRadius.circular(3),
                      isDark: _isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ShimmerBox(
                  width: index % 2 == 0 ? 170 : 130,
                  height: 15,
                  borderRadius: BorderRadius.circular(4),
                  isDark: _isDark,
                ),
                const SizedBox(height: 8),
                ShimmerBox(
                  width: index % 2 == 0 ? 250 : 190,
                  height: 12,
                  borderRadius: BorderRadius.circular(3),
                  isDark: _isDark,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ShimmerBox(
                      width: 65,
                      height: 12,
                      borderRadius: BorderRadius.circular(3),
                      isDark: _isDark,
                    ),
                    const SizedBox(width: 12),
                    ShimmerBox(
                      width: 75,
                      height: 12,
                      borderRadius: BorderRadius.circular(3),
                      isDark: _isDark,
                    ),
                    const Spacer(),
                    ShimmerBox(
                      width: 65,
                      height: 11,
                      borderRadius: BorderRadius.circular(3),
                      isDark: _isDark,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

