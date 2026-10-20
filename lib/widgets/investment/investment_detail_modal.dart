import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/investment_model.dart';
import '../../theme/app_theme.dart';

class InvestmentDetailModal {
  static void show({
    required BuildContext context,
    required Investment investment,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    if (isMobile) {
      _showBottomSheet(context, investment);
    } else {
      _showSideDrawer(context, investment);
    }
  }

  static String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(0);
    final formatted = parts.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₱$formatted';
  }

  static String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = months[date.month - 1];
    return '$monthName ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  static void _showBottomSheet(BuildContext context, Investment inv) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final hintText = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: hintText.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Investment Details',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: Icon(Icons.close_rounded, color: hintText, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildModalContent(inv, isDark, cardBorder, titleColor, hintText),
                ),
              ),
              Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
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
          ),
        ),
      ),
    );
  }

  static void _showSideDrawer(BuildContext context, Investment inv) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final hintText = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Investment Details',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, anim1, anim2) {
        return const SizedBox.shrink();
      },
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
                  child: Column(
                    children: [
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
                                Icons.monetization_on_outlined,
                                size: 18,
                                color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Investment Details',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: Icon(Icons.close_rounded, color: hintText, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Close panel',
                            ),
                          ],
                        ),
                      ),
                      Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _buildModalContent(inv, isDark, cardBorder, titleColor, hintText),
                        ),
                      ),
                      Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildModalContent(
    Investment inv,
    bool isDark,
    Color cardBorder,
    Color titleColor,
    Color hintText,
  ) {
    final batchName = (inv.batchName != null && inv.batchName!.isNotEmpty) ? inv.batchName! : 'Unassigned';
    final stage = inv.stage.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. FINANCIAL SUMMARY HIGHLIGHT CARDS
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16253B) : const Color(0xFFF1F6FD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL INVESTMENT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF243B5B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      stage,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatCurrency(inv.totalInvestment),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E314B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Capital (Cash)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hintText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCurrency(inv.initialCapital),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E314B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stocks Spend',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hintText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCurrency(inv.stocksValue),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 2. CORE DETAILS CARD
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B2E48) : const Color(0xFFF6F9FD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              _detailRow('Hog Raiser', inv.raiserName, hintText, titleColor),
              Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
              _detailRow('Batch Assigned', batchName, hintText, isDark ? Colors.white : PiggyTrunkTheme.ptPrimary),
              Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
              _detailRow('Hog Type', inv.hogType, hintText, titleColor),
              Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
              _detailRow('Total Hogs', '${inv.totalHog} heads', hintText, titleColor),
              Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
              _detailRow('Investment Date', _formatDate(inv.investmentDate), hintText, titleColor),
              Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
              _detailRow(
                'Lifecycle Stage',
                inv.stage.toUpperCase(),
                hintText,
                inv.stage.toLowerCase() == 'active'
                    ? const Color(0xFF10B981)
                    : (inv.stage.toLowerCase() == 'completed' || inv.stage.toLowerCase() == 'finished'
                        ? const Color(0xFF3B82F6)
                        : titleColor),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 3. ASSIGNED HOGS & FEED STAGES SECTION
        _AssignedHogsSection(
          investment: inv,
          isDark: isDark,
          cardBorder: cardBorder,
          titleColor: titleColor,
          hintText: hintText,
        ),

        const SizedBox(height: 24),

        // 4. PROVIDED STOCKS & SUPPLIES HISTORY SECTION
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 17,
                  color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'PROVIDED STOCKS & SUPPLIES',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF243B5B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${inv.providedStocks.length} request${inv.providedStocks.length == 1 ? '' : 's'}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (inv.providedStocks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2E48).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_rounded, size: 32, color: hintText.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Text(
                  'No stocks or supplies provided for this batch yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: hintText,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: inv.providedStocks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final item = inv.providedStocks[idx];
              final pName = (item['product_name'] ?? 'Feeds').toString();
              final cat = (item['category'] ?? 'Feeds').toString();
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
              final totalAmt = (item['total_amount'] as num?)?.toDouble() ?? 0.0;
              final dateStr = (item['request_date'] ?? item['decision_date'] ?? '').toString();
              final dt = DateTime.tryParse(dateStr);
              final dateDisplay = dt != null ? _formatDate(dt) : dateStr;
              final notes = (item['notes'] ?? '').toString().trim();

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16253B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBorder.withValues(alpha: 0.7)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF243B5B) : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      cat.toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dateDisplay,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: hintText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCurrency(totalAmt),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$qty sack${qty == 1 ? '' : 's'} @ ${_formatCurrency(unitPrice)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: hintText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B2E48).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: cardBorder.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes_rounded, size: 13, color: hintText),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                notes,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: hintText,
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

        const SizedBox(height: 24),

        // 4. HOG HEALTH REPORTS SECTION
        _HogHealthReportsSection(
          investment: inv,
          isDark: isDark,
          cardBorder: cardBorder,
          titleColor: titleColor,
          hintText: hintText,
        ),
      ],
    );
  }

  static Widget _detailRow(String label, String value, Color labelColor, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedHogsSection extends StatefulWidget {
  final Investment investment;
  final bool isDark;
  final Color cardBorder;
  final Color titleColor;
  final Color hintText;

  const _AssignedHogsSection({
    required this.investment,
    required this.isDark,
    required this.cardBorder,
    required this.titleColor,
    required this.hintText,
  });

  @override
  State<_AssignedHogsSection> createState() => _AssignedHogsSectionState();
}

class _AssignedHogsSectionState extends State<_AssignedHogsSection> {
  List<Map<String, dynamic>> _hogs = [];
  Map<String, String> _assignTypeMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHogs();
  }

  Future<void> _fetchHogs() async {
    try {
      final assignId = widget.investment.assignmentId;
      String? batchId = widget.investment.batchId;
      final raiserId = widget.investment.hogRaiserId.trim();

      // 1. Resolve batchId if missing
      if ((batchId == null || batchId.isEmpty) && assignId != null && assignId.isNotEmpty) {
        try {
          final aRow = await Supabase.instance.client
              .from('assignments')
              .select('batch_id')
              .eq('assignment_id', assignId)
              .maybeSingle();
          if (aRow != null && aRow['batch_id'] != null) {
            batchId = aRow['batch_id'].toString();
          }
        } catch (_) {}
      }

      final bName = widget.investment.batchName;
      if ((batchId == null || batchId.isEmpty) &&
          bName != null &&
          bName.isNotEmpty &&
          bName != 'Unassigned') {
        try {
          final bRow = await Supabase.instance.client
              .from('batches')
              .select('batch_id, id')
              .ilike('batch_name', bName)
              .maybeSingle();
          if (bRow != null) {
            batchId = (bRow['batch_id'] ?? bRow['id'])?.toString();
          }
        } catch (_) {}
      }

      if ((batchId == null || batchId.isEmpty) && widget.investment.id.isNotEmpty) {
        try {
          final bRows = await Supabase.instance.client
              .from('batches')
              .select('batch_id, id, batch_name');
          for (final b in (bRows as List? ?? [])) {
            if (b is Map) {
              final bName = (b['batch_name'] ?? '').toString();
              if (bName.contains('(${widget.investment.id})')) {
                batchId = (b['batch_id'] ?? b['id'])?.toString();
                break;
              }
            }
          }
        } catch (_) {}
      }

      // 2. Collect all assignment IDs for this batch/investment
      final Set<dynamic> allAssignmentIds = {};
      final Map<String, String> assignTypeMap = {};

      if (batchId != null && batchId.isNotEmpty) {
        try {
          final assignRows = await Supabase.instance.client
              .from('assignments')
              .select('assignment_id, hog_type_id, hog_types(type_name)')
              .eq('batch_id', batchId);
          for (final row in (assignRows as List? ?? [])) {
            if (row is Map && row['assignment_id'] != null) {
              final aId = row['assignment_id'];
              allAssignmentIds.add(aId);
              final tName = (row['hog_types'] is Map)
                  ? (row['hog_types']['type_name'] ?? '').toString()
                  : ((row['hog_types'] is List && (row['hog_types'] as List).isNotEmpty)
                      ? ((row['hog_types'] as List).first['type_name'] ?? '').toString()
                      : '');
              if (tName.isNotEmpty) {
                assignTypeMap[aId.toString()] = tName;
              }
            }
          }
        } catch (e) {
          debugPrint('Notice loading assignments by batch_id: $e');
          try {
            final plainRows = await Supabase.instance.client
                .from('assignments')
                .select('assignment_id, hog_type_id')
                .eq('batch_id', batchId);
            for (final row in (plainRows as List? ?? [])) {
              if (row is Map && row['assignment_id'] != null) {
                allAssignmentIds.add(row['assignment_id']);
              }
            }
          } catch (_) {}
        }
      }

      if (assignId != null && assignId.isNotEmpty) {
        allAssignmentIds.add(assignId);
      }

      if (allAssignmentIds.isEmpty && raiserId.isNotEmpty) {
        try {
          final rRows = await Supabase.instance.client
              .from('assignments')
              .select('assignment_id, hog_type_id, hog_types(type_name)')
              .eq('hog_raiser_id', raiserId)
              .eq('status', 'active');
          for (final row in (rRows as List? ?? [])) {
            if (row is Map && row['assignment_id'] != null) {
              final aId = row['assignment_id'];
              allAssignmentIds.add(aId);
              final tName = (row['hog_types'] is Map)
                  ? (row['hog_types']['type_name'] ?? '').toString()
                  : '';
              if (tName.isNotEmpty) {
                assignTypeMap[aId.toString()] = tName;
              }
            }
          }
        } catch (_) {}
      }

      // Resolve hog type names if any assignment is missing type_name
      try {
        final htList = await Supabase.instance.client.from('hog_types').select('hog_type_id, type_name');
        final Map<int, String> hogTypeNamesMap = {};
        for (var ht in (htList as List? ?? [])) {
          if (ht is Map && ht['hog_type_id'] != null) {
            hogTypeNamesMap[(ht['hog_type_id'] as num).toInt()] = (ht['type_name'] ?? '').toString();
          }
        }

        if (allAssignmentIds.isNotEmpty && hogTypeNamesMap.isNotEmpty) {
          final aDetails = await Supabase.instance.client
              .from('assignments')
              .select('assignment_id, hog_type_id')
              .inFilter('assignment_id', allAssignmentIds.toList());
          for (var row in (aDetails as List? ?? [])) {
            if (row is Map) {
              final aId = (row['assignment_id'] ?? '').toString();
              if (!assignTypeMap.containsKey(aId) || assignTypeMap[aId]!.isEmpty) {
                final htId = int.tryParse((row['hog_type_id'] ?? '').toString());
                if (htId != null && hogTypeNamesMap.containsKey(htId)) {
                  assignTypeMap[aId] = hogTypeNamesMap[htId]!;
                }
              }
            }
          }
        }
      } catch (_) {}

      // 3. Fetch all individual hogs
      List<dynamic> res = [];
      if (allAssignmentIds.isNotEmpty) {
        final aIdsList = allAssignmentIds.toList();
        try {
          res = await Supabase.instance.client
              .from('hogs')
              .select('*')
              .inFilter('assignment_id', aIdsList)
              .order('hog_id', ascending: true);
        } catch (hErr) {
          debugPrint('Notice loading hogs by assignment_ids: $hErr');
        }
      }

      if (mounted) {
        setState(() {
          _assignTypeMap = assignTypeMap;
          _hogs = List<Map<String, dynamic>>.from(res)
              .where((h) => (h['health_status'] ?? '').toString().toLowerCase() != 'dead')
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Notice loading hogs in modal: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _resolveStageName(dynamic stageVal, bool isBreeding) {
    final fatteningStages = const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'];
    final sowStages = const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation'];
    final list = isBreeding ? sowStages : fatteningStages;

    final id = int.tryParse(stageVal?.toString() ?? '');
    if (id != null && id >= 1 && id <= list.length) {
      return list[id - 1];
    }
    final s = stageVal?.toString().trim() ?? '';
    if (s.isNotEmpty && s != 'null' && s != 'N/A' && int.tryParse(s) == null) {
      return s;
    }
    return 'Booster';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBorder = widget.cardBorder;
    final titleColor = widget.titleColor;
    final hintText = widget.hintText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pets_rounded,
                  size: 17,
                  color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'ASSIGNED HOGS & FEED STAGES',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF243B5B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_hogs.length} head${_hogs.length == 1 ? '' : 's'}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
              ),
            ),
          )
        else if (_hogs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2E48).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Icon(Icons.pets_outlined, size: 28, color: hintText.withValues(alpha: 0.5)),
                const SizedBox(height: 6),
                Text(
                  'No individual hogs recorded for this batch yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: hintText,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _hogs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final hog = _hogs[idx];
              final hogAssignId = (hog['assignment_id'] ?? '').toString();
              String hogTypeName = (hog['pig_type'] ?? '').toString().trim();
              if (hogTypeName.isEmpty && _assignTypeMap.containsKey(hogAssignId)) {
                hogTypeName = _assignTypeMap[hogAssignId]!;
              }
              if (hogTypeName.isEmpty && hog['assignments'] is Map) {
                final aData = hog['assignments'];
                if (aData['hog_types'] is Map) {
                  hogTypeName = (aData['hog_types']['type_name'] ?? '').toString().trim();
                }
              }
              if (hogTypeName.isEmpty) {
                final invTypeLower = widget.investment.hogType.toLowerCase();
                if (invTypeLower.contains('sow') && invTypeLower.contains('fatten')) {
                  final half = (_hogs.length / 2).ceil();
                  hogTypeName = idx < half ? 'Fattening' : 'Sow';
                } else if (invTypeLower.contains('sow') || invTypeLower.contains('breed')) {
                  hogTypeName = 'Sow';
                } else {
                  hogTypeName = 'Fattening';
                }
              }

              final isHogBreeding = hogTypeName.toLowerCase().contains('sow') || hogTypeName.toLowerCase().contains('breed');
              final stageName = _resolveStageName(hog['stage_id'] ?? hog['lifecycle_stage'], isHogBreeding);
              final displayTagText = isHogBreeding ? 'Sow' : 'Fattening';

              final health = (hog['health_status'] ?? 'healthy').toString().toLowerCase();
              final isSick = health == 'sick' || health == 'fever' || health == 'injured';
              final isObserving = health.contains('observ');

              final healthColor = isSick
                  ? const Color(0xFFEF4444)
                  : (isObserving ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
              final healthLabel = isSick
                  ? 'SICK'
                  : (isObserving ? 'OBSERVATION' : 'HEALTHY');

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16253B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBorder.withValues(alpha: 0.7)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF243B5B).withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.pets_rounded,
                        size: 18,
                        color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Hog #${idx + 1}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF243B5B) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: cardBorder.withValues(alpha: isDark ? 0.6 : 0.8),
                              ),
                            ),
                            child: Text(
                              displayTagText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Builder(
                          builder: (context) {
                            final isComplete = stageName.toLowerCase() == 'selling' ||
                                stageName.toLowerCase() == 'lactation' ||
                                stageName.toLowerCase() == 'completed';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isComplete
                                    ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.12)
                                    : (isDark ? const Color(0xFF243B5B) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isComplete
                                      ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.6 : 0.4)
                                      : cardBorder.withValues(alpha: isDark ? 0.7 : 0.8),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isComplete) ...[
                                    const Icon(Icons.check_rounded, size: 11, color: Color(0xFF10B981)),
                                    const SizedBox(width: 3),
                                  ],
                                  Text(
                                    isComplete ? '$stageName • Complete' : stageName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isComplete
                                          ? const Color(0xFF10B981)
                                          : (isDark ? const Color(0xFFE2E8F0) : PiggyTrunkTheme.ptPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: healthColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              healthLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: healthColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _HogHealthReportsSection extends StatefulWidget {
  final Investment investment;
  final bool isDark;
  final Color cardBorder;
  final Color titleColor;
  final Color hintText;

  const _HogHealthReportsSection({
    required this.investment,
    required this.isDark,
    required this.cardBorder,
    required this.titleColor,
    required this.hintText,
  });

  @override
  State<_HogHealthReportsSection> createState() => _HogHealthReportsSectionState();
}

class _HogHealthReportsSectionState extends State<_HogHealthReportsSection> {
  List<Map<String, dynamic>> _reports = [];
  Map<String, int> _hogIndexMap = {};

  @override
  void initState() {
    super.initState();
    _reports = List<Map<String, dynamic>>.from(widget.investment.healthReports);
    _fetchLiveReports();
  }

  Future<void> _fetchLiveReports() async {
    final raiserId = widget.investment.hogRaiserId.trim();
    if (raiserId.isEmpty) return;

    try {
      final res = await Supabase.instance.client
          .from('hog_reports')
          .select('*')
          .eq('hog_raiser_id', raiserId)
          .order('created_at', ascending: false);

      final assignId = widget.investment.assignmentId;
      final batchId = widget.investment.batchId;

      final Set<dynamic> allAssignIds = {};
      if (batchId != null && batchId.isNotEmpty) {
        try {
          final aRows = await Supabase.instance.client
              .from('assignments')
              .select('assignment_id')
              .eq('batch_id', batchId);
          for (var r in (aRows as List? ?? [])) {
            if (r is Map && r['assignment_id'] != null) allAssignIds.add(r['assignment_id']);
          }
        } catch (_) {}
      }
      if (assignId != null && assignId.isNotEmpty) allAssignIds.add(assignId);

      List<dynamic> hogsList = [];
      if (allAssignIds.isNotEmpty) {
        hogsList = await Supabase.instance.client
            .from('hogs')
            .select('hog_id')
            .inFilter('assignment_id', allAssignIds.toList())
            .order('hog_id', ascending: true);
      } else if (assignId != null && assignId.isNotEmpty) {
        hogsList = await Supabase.instance.client
            .from('hogs')
            .select('hog_id')
            .eq('assignment_id', assignId)
            .order('hog_id', ascending: true);
      }

      final Map<String, int> indexMap = {};
      for (int i = 0; i < hogsList.length; i++) {
        indexMap[hogsList[i]['hog_id'].toString()] = i + 1;
      }

      if (mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(res);
          _hogIndexMap = indexMap;
        });
      }
    } catch (e) {
      debugPrint('Notice loading live hog_reports: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBorder = widget.cardBorder;
    final titleColor = widget.titleColor;
    final hintText = widget.hintText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 17,
                  color: isDark ? const Color(0xFF43CB89) : PiggyTrunkTheme.ptSuccess,
                ),
                const SizedBox(width: 8),
                Text(
                  'HOG HEALTH REPORTS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF43CB89) : PiggyTrunkTheme.ptSuccess).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_reports.length} update${_reports.length == 1 ? '' : 's'}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF43CB89) : PiggyTrunkTheme.ptSuccess,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_reports.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2E48).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 32,
                  color: hintText.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'No health reports submitted for this hog raiser yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: hintText,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reports.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final rep = _reports[idx];
              final rType = (rep['report_type'] ?? 'Health Observation').toString();
              final desc = (rep['description'] ?? rep['notes'] ?? '').toString().trim();
              final hogId = rep['hog_id'];
              final dateStr = (rep['created_at'] ?? '').toString();
              final dt = DateTime.tryParse(dateStr);
              final dateDisplay = dt != null ? _formatDateTime(dt) : dateStr;

              final lower = rType.toLowerCase();
              final isCritical = lower.contains('dead') ||
                  lower.contains('sick') ||
                  lower.contains('fever') ||
                  lower.contains('poison') ||
                  lower.contains('diarrhea');
              final isRoutine = lower.contains('healthy') ||
                  lower.contains('routine') ||
                  lower.contains('normal') ||
                  lower.contains('checkup');

              final Color badgeFg = isCritical
                  ? const Color(0xFFFF758C)
                  : (isRoutine
                      ? (isDark ? const Color(0xFF43CB89) : PiggyTrunkTheme.ptSuccess)
                      : (isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptPrimary));
              final Color badgeBg = badgeFg.withValues(alpha: isDark ? 0.15 : 0.1);

              final IconData badgeIcon = isCritical
                  ? Icons.warning_amber_rounded
                  : (isRoutine ? Icons.check_circle_outline_rounded : Icons.medical_services_outlined);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16253B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBorder.withValues(alpha: 0.7)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: badgeFg.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(badgeIcon, size: 13, color: badgeFg),
                                  const SizedBox(width: 5),
                                  Text(
                                    rType.toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: badgeFg,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hogId != null && hogId.toString() != '0') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF243B5B) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'HOG #${_hogIndexMap[hogId.toString()] ?? hogId}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          dateDisplay,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: hintText,
                          ),
                        ),
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B2E48).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: cardBorder.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes_rounded, size: 13, color: hintText),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                desc,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
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
      ],
    );
  }

  static String _formatDateTime(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = months[date.month - 1];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$monthName ${date.day.toString().padLeft(2, '0')}, ${date.year} • $hour:$minute $period';
  }
}
