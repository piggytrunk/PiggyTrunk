import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/screen_fit_util.dart';
import 'partner_hog_updates_tab.dart';

class PartnerMyProjectsTab extends StatefulWidget {
  final List<Map<String, dynamic>> projectsList;
  final double investedAmount;
  final List<Map<String, dynamic>> activitiesList;
  final Future<void> Function() onRefresh;
  final VoidCallback? onMakeInvestment;

  const PartnerMyProjectsTab({
    super.key,
    required this.projectsList,
    required this.investedAmount,
    this.activitiesList = const [],
    required this.onRefresh,
    this.onMakeInvestment,
  });

  @override
  State<PartnerMyProjectsTab> createState() => _PartnerMyProjectsTabState();
}

class _PartnerMyProjectsTabState extends State<PartnerMyProjectsTab> {
  static const Color _brandColor = Color(0xFF18314F);
  static const Color _brandAccent = Color(0xFF2FB36F);

  int _selectedSubTab = 0; // 0: Active Projects, 1: History
  Map<String, dynamic>? _selectedProjectForUpdates;

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _openProjectHogUpdates(Map<String, dynamic> project) {
    setState(() {
      _selectedProjectForUpdates = project;
    });
  }

  Color _getStageColor(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('finisher') || s.contains('harvest') || s.contains('sell') || s.contains('lactat')) {
      return const Color(0xFF10B981);
    } else if (s.contains('grower') || s.contains('breed')) {
      return const Color(0xFF3B82F6);
    } else if (s.contains('starter')) {
      return const Color(0xFFF59E0B);
    } else if (s.contains('booster') || s.contains('pre')) {
      return const Color(0xFF8B5CF6);
    }
    return const Color(0xFF10B981);
  }

  int _getStageProgressIndex(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('booster')) return 0;
    if (s.contains('pre-starter') || s.contains('pre starter')) return 1;
    if (s.contains('starter')) return 2;
    if (s.contains('grower')) return 3;
    if (s.contains('finisher') || s.contains('breed')) return 4;
    if (s.contains('selling') || s.contains('sold') || s.contains('lactat') || s.contains('harvest') || s.contains('complete')) return 5;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    // If a project is selected for live updates, show the updates screen with a back button
    if (_selectedProjectForUpdates != null) {
      final proj = _selectedProjectForUpdates!;
      final raiserName = proj['raiser_name'] ?? proj['assigned_raiser'] ?? "Assigned Hog Raiser";
      final int hogs = (proj['total_hogs'] as num?)?.toInt() ?? 15;
      final int mortality = (proj['mortality'] as num?)?.toInt() ?? 0;
      final String stage = proj['stage'] ?? "Grower";

      final matchingReports = widget.activitiesList.where((act) {
        final rName = (act['raiser_name'] ?? '').toString().toLowerCase();
        final curRaiser = raiserName.toLowerCase();
        return (curRaiser.isNotEmpty && rName.isNotEmpty) &&
            (curRaiser.contains(rName) || rName.contains(curRaiser));
      }).toList();

      final String hogType = (proj['hog_type'] ?? proj['pig_type'] ?? 'Fattening').toString();
      return PartnerHogUpdatesTab(
        raiserName: raiserName,
        totalHog: hogs,
        totalMortality: mortality,
        currentStage: stage,
        hogType: hogType,
        reportsList: matchingReports.isNotEmpty ? matchingReports : widget.activitiesList,
        onRefresh: widget.onRefresh,
        onBack: () => setState(() => _selectedProjectForUpdates = null),
      );
    }

    final fit = ScreenFit(context);
    final double paddingH = fit.dp(20.0);
    final double paddingV = fit.dp(16.0);
    final double titleFontSize = fit.sp(24.0);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xffecf2ff) : _brandColor;
    final mutedTextColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final cardBgColor = isDark ? const Color(0xff151f2e) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xff28354a) : const Color(0xffe6ebf2);
    final statsBoxBg = isDark ? const Color(0xff1b2638) : const Color(0xfff8fafc);
    final statsBoxBorder = isDark ? const Color(0xff28354a) : const Color(0xffe6ebf2);

    final activeProjects = (widget.investedAmount > 0 || widget.projectsList.isNotEmpty)
        ? widget.projectsList
            .where((p) =>
                p['is_cycle_completed'] != true &&
                (p['status'] ?? '').toString().toLowerCase() != 'completed')
            .toList()
        : <Map<String, dynamic>>[];

    // Calculate total summary metrics
    int totalHogsFunded = 0;
    for (var p in activeProjects) {
      totalHogsFunded += (p['total_hogs'] as num?)?.toInt() ?? 15;
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: _brandColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Clean Modern Header (No search icon, no notification bell)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Projects',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: fit.dp(3)),
                Text(
                  'Track and monitor your funded hog batches and raisers',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fit.sp(12.5),
                    fontWeight: FontWeight.w500,
                    color: mutedTextColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: fit.dp(16.0)),

            // 2. Modern Segmented Tab Switcher (Pill Style)
            Container(
              padding: EdgeInsets.all(fit.dp(4)),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(fit.dp(16)),
                border: Border.all(color: cardBorderColor, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSubTab = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(vertical: fit.dp(10)),
                        decoration: BoxDecoration(
                          color: _selectedSubTab == 0
                              ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(fit.dp(12)),
                          boxShadow: _selectedSubTab == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_special_rounded,
                              size: fit.dp(16),
                              color: _selectedSubTab == 0
                                  ? (isDark ? Colors.white : _brandColor)
                                  : mutedTextColor,
                            ),
                            SizedBox(width: fit.dp(6)),
                            Text(
                              'Active Projects',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: fit.sp(12.5),
                                fontWeight: _selectedSubTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                color: _selectedSubTab == 0 ? primaryTextColor : mutedTextColor,
                              ),
                            ),
                            if (activeProjects.isNotEmpty) ...[
                              SizedBox(width: fit.dp(6)),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: fit.dp(6), vertical: fit.dp(2)),
                                decoration: BoxDecoration(
                                  color: _brandAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${activeProjects.length}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(10.5),
                                    fontWeight: FontWeight.w800,
                                    color: _brandAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSubTab = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(vertical: fit.dp(10)),
                        decoration: BoxDecoration(
                          color: _selectedSubTab == 1
                              ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(fit.dp(12)),
                          boxShadow: _selectedSubTab == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                                    blurRadius: 6,
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
                              size: fit.dp(16),
                              color: _selectedSubTab == 1
                                  ? (isDark ? Colors.white : _brandColor)
                                  : mutedTextColor,
                            ),
                            SizedBox(width: fit.dp(6)),
                            Text(
                              'History',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: fit.sp(12.5),
                                fontWeight: _selectedSubTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                color: _selectedSubTab == 1 ? primaryTextColor : mutedTextColor,
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
            SizedBox(height: fit.dp(18.0)),

            // 3. Tab Contents
            if (_selectedSubTab == 0) ...[
              // ==================== ACTIVE PROJECTS TAB ====================
              if (activeProjects.isEmpty)
                // Modern Empty State Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: fit.dp(24), vertical: fit.dp(36)),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(fit.dp(24)),
                    border: Border.all(color: cardBorderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(fit.dp(20)),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : _brandColor.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.folder_open_rounded,
                          size: fit.dp(44),
                          color: isDark ? Colors.white : _brandColor,
                        ),
                      ),
                      SizedBox(height: fit.dp(16)),
                      Text(
                        'No Active Projects Yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(17.0),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: fit.dp(6)),
                      Text(
                        'You have not funded any hog raiser projects yet. Explore active batches to start earning returns and tracking live growth.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(12.5),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.onMakeInvestment != null) ...[
                        SizedBox(height: fit.dp(20)),
                        ElevatedButton.icon(
                          onPressed: () => widget.onMakeInvestment?.call(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : _brandColor,
                            foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(horizontal: fit.dp(22), vertical: fit.dp(13)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(fit.dp(14)),
                            ),
                          ),
                          icon: Icon(
                            Icons.add_card_rounded,
                            size: fit.dp(18),
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          ),
                          label: Text(
                            'Explore Batches to Invest',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: fit.sp(13.5),
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else ...[
                // Metric Strip Summary Bar
                Container(
                  margin: EdgeInsets.only(bottom: fit.dp(16)),
                  padding: EdgeInsets.symmetric(horizontal: fit.dp(16), vertical: fit.dp(14)),
                  decoration: BoxDecoration(
                    color: statsBoxBg,
                    borderRadius: BorderRadius.circular(fit.dp(16)),
                    border: Border.all(color: statsBoxBorder, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        fit,
                        'TOTAL INVESTED',
                        '₱${_formatCurrency(widget.investedAmount)}',
                        isDark,
                        primaryTextColor,
                      ),
                      Container(height: fit.dp(28), width: 1, color: statsBoxBorder),
                      _buildSummaryItem(
                        fit,
                        'BATCHES',
                        '${activeProjects.length}',
                        isDark,
                        primaryTextColor,
                      ),
                      Container(height: fit.dp(28), width: 1, color: statsBoxBorder),
                      _buildSummaryItem(
                        fit,
                        'TOTAL HOGS',
                        '$totalHogsFunded',
                        isDark,
                        primaryTextColor,
                      ),
                    ],
                  ),
                ),

                // Active Project Cards
                ...activeProjects.map((project) {
                  final String title = project['title'] ?? project['batch_name'] ?? 'Batch Project';
                  final String status = project['status'] ?? 'Active';
                  final String stage = project['stage'] ?? 'Grower';
                  final String rawHogType = (project['target_pig_type'] ?? project['hog_type'] ?? project['pig_type'] ?? 'Fattening').toString();
                  final String hogType = (rawHogType.isEmpty || rawHogType.toUpperCase() == 'N/A') ? 'Fattening' : rawHogType;
                  final String raiserName = project['raiser_name'] ?? project['assigned_raiser'] ?? 'Assigned Hog Raiser';
                  final double amount = (project['invested_amount'] ?? project['amount'] as num?)?.toDouble() ??
                      (widget.investedAmount > 0 ? widget.investedAmount : 10000.0);
                  final int totalRaisers = (project['total_raisers'] as num?)?.toInt() ?? 1;
                  final int totalHogs = (project['total_hogs'] as num?)?.toInt() ?? 15;
                  final int mortality = (project['mortality'] as num?)?.toInt() ?? 0;

                  final stageColor = _getStageColor(stage);
                  final progressStep = _getStageProgressIndex(stage);

                  return Container(
                    margin: EdgeInsets.only(bottom: fit.dp(16)),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(fit.dp(22)),
                      border: Border.all(color: cardBorderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header: Pig Type Badge & Status Pill
                        Padding(
                          padding: EdgeInsets.fromLTRB(fit.dp(16), fit.dp(16), fit.dp(16), 0),
                          child: Wrap(
                            spacing: fit.dp(8),
                            runSpacing: fit.dp(8),
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Hog Type Badge (e.g. Fattening or Sow/Breeding)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: fit.dp(9), vertical: fit.dp(4.5)),
                                    margin: EdgeInsets.only(right: fit.dp(6)),
                                    decoration: BoxDecoration(
                                      color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                                      borderRadius: BorderRadius.circular(fit.dp(20)),
                                      border: Border.all(
                                        color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.pets_rounded,
                                          size: fit.dp(11),
                                          color: isDark ? PiggyTrunkTheme.ptTextDark : _brandColor,
                                        ),
                                        SizedBox(width: fit.dp(4)),
                                        Text(
                                          hogType,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: fit.sp(10.5),
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status Badge (e.g. Active Batch or Pending Approval)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: fit.dp(9), vertical: fit.dp(4.5)),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12),
                                      borderRadius: BorderRadius.circular(fit.dp(20)),
                                      border: Border.all(
                                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.4 : 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: fit.dp(6),
                                          height: fit.dp(6),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: fit.dp(5)),
                                        Text(
                                          status.toLowerCase() == 'pending' ? 'Pending Approval' : 'Active Batch',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: fit.sp(10.5),
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Batch Title & Raiser Name
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: fit.dp(16), vertical: fit.dp(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(18.0),
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: fit.dp(5)),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: fit.dp(14),
                                    color: mutedTextColor,
                                  ),
                                  SizedBox(width: fit.dp(4)),
                                  Text(
                                    'Raiser: $raiserName',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: fit.sp(12.5),
                                      fontWeight: FontWeight.w600,
                                      color: mutedTextColor,
                                    ),
                                  ),
                                  SizedBox(width: fit.dp(8)),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: mutedTextColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: fit.dp(8)),
                                  Text(
                                    project['target_hog_tags'] is List && (project['target_hog_tags'] as List).isNotEmpty
                                        ? '$hogType (${(project['target_hog_tags'] as List).join(", ")})'
                                        : hogType,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: fit.sp(12.0),
                                      fontWeight: FontWeight.w600,
                                      color: mutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Lifecycle Step Progress Bar (5 stages)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: fit.dp(18), vertical: fit.dp(4)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'LIFECYCLE PROGRESS',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: fit.sp(10.0),
                                      fontWeight: FontWeight.w700,
                                      color: mutedTextColor,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  Text(
                                    'Step ${progressStep + 1} of 6',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: fit.sp(10.5),
                                      fontWeight: FontWeight.w700,
                                      color: stageColor,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: fit.dp(6)),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(fit.dp(6)),
                                child: LinearProgressIndicator(
                                  value: (progressStep + 1) / 6.0,
                                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(stageColor),
                                  minHeight: fit.dp(6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: fit.dp(12)),

                        // Stats Grid Box
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: fit.dp(18)),
                          padding: EdgeInsets.symmetric(vertical: fit.dp(12), horizontal: fit.dp(10)),
                          decoration: BoxDecoration(
                            color: statsBoxBg,
                            borderRadius: BorderRadius.circular(fit.dp(14)),
                            border: Border.all(color: statsBoxBorder, width: 1),
                          ),
                          child: Row(
                            children: [
                              _buildMetricColumn(fit, 'RAISERS', '$totalRaisers', primaryTextColor, isDark),
                              Container(height: fit.dp(26), width: 1, color: statsBoxBorder),
                              _buildMetricColumn(fit, 'TOTAL HOGS', '$totalHogs', primaryTextColor, isDark),
                              Container(height: fit.dp(26), width: 1, color: statsBoxBorder),
                              _buildMetricColumn(
                                fit,
                                'MORTALITY',
                                '$mortality',
                                mortality > 0 ? const Color(0xFFEF4444) : primaryTextColor,
                                isDark,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: fit.dp(14)),

                        // Investment Amount & View Button Row
                        Padding(
                          padding: EdgeInsets.fromLTRB(fit.dp(18), 0, fit.dp(18), fit.dp(16)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'YOUR INVESTMENT',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: fit.sp(10.5),
                                      fontWeight: FontWeight.w700,
                                      color: mutedTextColor,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  SizedBox(height: fit.dp(2)),
                                  Text(
                                    '₱${_formatCurrency(amount)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: fit.sp(16.0),
                                      fontWeight: FontWeight.w800,
                                      color: primaryTextColor,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _openProjectHogUpdates(project),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _brandColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(horizontal: fit.dp(16), vertical: fit.dp(10)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(fit.dp(12)),
                                  ),
                                ),
                                icon: Text(
                                  'Live Updates',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(12.5),
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                label: Icon(
                                  Icons.chevron_right_rounded,
                                  size: fit.dp(18),
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ] else ...[
              // ==================== HISTORY TAB ====================
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: fit.dp(24), vertical: fit.dp(36)),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(fit.dp(24)),
                  border: Border.all(color: cardBorderColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(fit.dp(20)),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : _brandColor.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history_toggle_off_rounded,
                        size: fit.dp(44),
                        color: isDark ? Colors.white : _brandColor,
                      ),
                    ),
                    SizedBox(height: fit.dp(16)),
                    Text(
                      'No Project History',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(17.0),
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: fit.dp(6)),
                    Text(
                      'Completed, harvested, or closed project investments will appear here.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(12.5),
                        fontWeight: FontWeight.w500,
                        color: mutedTextColor,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(ScreenFit fit, String label, String value, bool isDark, Color textColor) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: fit.sp(10.0),
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: fit.dp(3)),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: fit.sp(15.0),
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricColumn(ScreenFit fit, String label, String value, Color valueColor, bool isDark) {
    final effectiveColor = (isDark && (valueColor == _brandColor || valueColor == const Color(0xFF18314F)))
        ? Colors.white
        : valueColor;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fit.sp(9.5),
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: fit.dp(3)),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fit.sp(17.0),
              fontWeight: FontWeight.w800,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
