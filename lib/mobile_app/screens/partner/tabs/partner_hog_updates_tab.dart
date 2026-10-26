import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/screen_fit_util.dart';

class PartnerHogUpdatesTab extends StatelessWidget {
  final String raiserName;
  final int totalHog;
  final int totalMortality;
  final String currentStage; // Booster, Pre-starter, Starter, Grower, Finisher / Breeder, Selling / Lactation
  final String hogType;
  final List<Map<String, dynamic>> reportsList;
  final Future<void> Function() onRefresh;
  final VoidCallback? onBack;

  static const Color _brandColor = Color(0xFF18314F);

  const PartnerHogUpdatesTab({
    super.key,
    this.raiserName = "Juan Dela Cruz",
    this.totalHog = 0,
    this.totalMortality = 0,
    this.currentStage = "Grower",
    this.hogType = "Fattening",
    this.reportsList = const [],
    required this.onRefresh,
    this.onBack,
  });

  static const List<String> _fatteningStages = [
    'Booster',
    'Pre-starter',
    'Starter',
    'Grower',
    'Finisher',
    'Selling',
  ];

  static const List<String> _sowStages = [
    'Booster',
    'Pre-starter',
    'Starter',
    'Grower',
    'Breeder',
    'Lactation',
  ];

  List<String> get _stages {
    final t = hogType.toLowerCase();
    if (t.contains('sow') || t.contains('breed')) {
      return _sowStages;
    }
    return _fatteningStages;
  }

  int _getStageIndex(String stage, List<String> stageList) {
    final sLower = stage.toLowerCase().trim();
    if (sLower.contains('sell') ||
        sLower.contains('sold') ||
        sLower.contains('lactat') ||
        sLower.contains('complete') ||
        sLower.contains('harvest')) {
      return stageList.length - 1;
    }
    final idx = stageList.indexWhere((s) => s.toLowerCase() == sLower || sLower.contains(s.toLowerCase()));
    return idx != -1 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final fit = ScreenFit(context);
    final double paddingH = fit.dp(20.0);
    final double paddingV = fit.dp(16.0);
    final double titleFontSize = fit.sp(24.0);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xffecf2ff) : _brandColor;
    final mutedTextColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final cardBgColor = isDark ? const Color(0xff151f2e) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xff28354a) : const Color(0xffe6ebf2);

    final stageList = _stages;
    final int currentStageIdx = _getStageIndex(currentStage, stageList);
    final sLower = currentStage.toLowerCase().trim();
    final bool isTerminalStage = currentStageIdx == stageList.length - 1 &&
        (sLower.contains('sell') ||
         sLower.contains('sold') ||
         sLower.contains('lactat') ||
         sLower.contains('complete') ||
         sLower.contains('harvest'));

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _brandColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (onBack != null) ...[
                      IconButton(
                        onPressed: onBack,
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: primaryTextColor,
                          size: fit.dp(24),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      SizedBox(width: fit.dp(10)),
                    ],
                    Text(
                      'Hog Updates',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: Icon(
                        Icons.search_rounded,
                        color: primaryTextColor,
                        size: fit.dp(24),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    SizedBox(width: fit.dp(16)),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: primaryTextColor,
                          size: fit.dp(24),
                        ),
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF5B6C),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: fit.dp(20.0)),

            // 2. Raiser Name Sub-header
            Text(
              raiserName.isNotEmpty ? raiserName : "No Assigned Raiser",
              style: GoogleFonts.plusJakartaSans(
                fontSize: fit.sp(20.0),
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: fit.dp(16.0)),

            // 3. Top 2 Metric Cards Row (Total Hog & Total Mortality)
            Row(
              children: [
                // Card 1: Total Hog
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: fit.dp(16), vertical: fit.dp(18)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(fit.dp(20)),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF18314F),
                          Color(0xFF2B4360),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF18314F).withValues(alpha: 0.18),
                          blurRadius: fit.dp(12),
                          offset: Offset(0, fit.dp(6)),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Hog',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(13.0),
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        SizedBox(height: fit.dp(10)),
                        Text(
                          '$totalHog',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(28.0),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: fit.dp(14)),

                // Card 2: Total Mortality
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: fit.dp(16), vertical: fit.dp(18)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(fit.dp(20)),
                      gradient: LinearGradient(
                        colors: totalMortality > 0
                            ? const [Color(0xFFEF4444), Color(0xFFF87171)]
                            : const [Color(0xFF2B4360), Color(0xFF3B5270)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (totalMortality > 0 ? const Color(0xFFEF4444) : const Color(0xFF2B4360)).withValues(alpha: 0.18),
                          blurRadius: fit.dp(12),
                          offset: Offset(0, fit.dp(6)),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Mortality',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(13.0),
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        SizedBox(height: fit.dp(10)),
                        Text(
                          '$totalMortality',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(28.0),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: fit.dp(20.0)),

            // 4. Growth Roadmap Stepper Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(fit.dp(18.0)),
              decoration: BoxDecoration(
                color: isDark ? cardBgColor : const Color(0xFFFFF0F3),
                borderRadius: BorderRadius.circular(fit.dp(22)),
                border: Border.all(
                  color: isDark ? cardBorderColor : const Color(0xFFFFD6E0),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Growth Roadmap',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: fit.sp(14.0),
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                  SizedBox(height: fit.dp(18.0)),

                  // Timeline Row with connecting lines
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(stageList.length, (index) {
                      final stageName = stageList[index];
                      final bool isCompleted = index < currentStageIdx || (isTerminalStage && index == currentStageIdx);
                      final bool isCurrent = index == currentStageIdx && !isTerminalStage;

                      return Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Left connecting line
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: index == 0
                                        ? Colors.transparent
                                        : ((index <= currentStageIdx || isTerminalStage) ? _brandColor : const Color(0xFFCBD5E1)),
                                  ),
                                ),
                                // Node Circle Icon
                                Container(
                                  width: fit.dp(30),
                                  height: fit.dp(30),
                                  decoration: BoxDecoration(
                                    color: isCompleted || isCurrent
                                        ? _brandColor
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCompleted
                                        ? Icons.check_rounded
                                        : (isCurrent ? Icons.show_chart_rounded : Icons.lock_outline_rounded),
                                    size: fit.dp(16),
                                    color: isCompleted || isCurrent
                                        ? Colors.white
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                                // Right connecting line
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: index == stageList.length - 1
                                        ? Colors.transparent
                                        : ((index < currentStageIdx || isTerminalStage) ? _brandColor : const Color(0xFFCBD5E1)),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: fit.dp(8)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                stageName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(10.0),
                                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                  color: isCurrent
                                      ? const Color(0xFFEF5B6C)
                                      : (isCompleted ? primaryTextColor : mutedTextColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            SizedBox(height: fit.dp(24.0)),

            // 5. Hog Raiser Report Header & List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Hog Raiser Report',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fit.sp(16.0),
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'See All',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: fit.sp(13.0),
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xffecf2ff) : _brandColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: fit.dp(12.0)),

            // Clean Zero State or Report Cards List
            if (reportsList.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: fit.dp(20), vertical: fit.dp(28)),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(fit.dp(22)),
                  border: Border.all(color: cardBorderColor, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: fit.dp(38),
                      color: isDark ? const Color(0xff9cb0c9) : _brandColor,
                    ),
                    SizedBox(height: fit.dp(10)),
                    Text(
                      'No Reports Recorded Yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(15.0),
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: fit.dp(4)),
                    Text(
                      'Health, feed, and weight reports from your assigned hog raiser will appear here.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(12.0),
                        fontWeight: FontWeight.w500,
                        color: mutedTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...reportsList.map((report) {
                final String title = report['title'] ?? report['report_title'] ?? 'Food Poisoning';
                final String time = report['time'] ?? report['date'] ?? '2h ago';

                return Container(
                  margin: EdgeInsets.only(bottom: fit.dp(10)),
                  padding: EdgeInsets.all(fit.dp(16.0)),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(fit.dp(20)),
                    border: Border.all(color: cardBorderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: fit.dp(42.0),
                        height: fit.dp(42.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(fit.dp(14)),
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: const Color(0xFFEF4444),
                          size: fit.dp(22.0),
                        ),
                      ),
                      SizedBox(width: fit.dp(14.0)),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(15.0),
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(12.0),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                      SizedBox(width: fit.dp(6)),
                      Icon(
                        Icons.more_vert_rounded,
                        color: mutedTextColor,
                        size: fit.dp(20),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
