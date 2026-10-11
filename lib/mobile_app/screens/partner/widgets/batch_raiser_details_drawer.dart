import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utils/screen_fit_util.dart';

void showBatchRaiserDetailsDrawer({
  required BuildContext context,
  required Map<String, dynamic> batch,
  required VoidCallback onInvestNow,
  VoidCallback? onViewActivities,
  VoidCallback? onViewLifecycle,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BatchRaiserDetailsContent(
      batch: batch,
      onInvestNow: onInvestNow,
      onViewActivities: onViewActivities,
      onViewLifecycle: onViewLifecycle,
    ),
  );
}

class _BatchRaiserDetailsContent extends StatelessWidget {
  final Map<String, dynamic> batch;
  final VoidCallback onInvestNow;
  final VoidCallback? onViewActivities;
  final VoidCallback? onViewLifecycle;

  static const Color _brandNavy = Color(0xFF18314F);
  static const Color _accentGreen = Color(0xFF10B981);

  const _BatchRaiserDetailsContent({
    required this.batch,
    required this.onInvestNow,
    this.onViewActivities,
    this.onViewLifecycle,
  });

  static const List<String> _fatteningStages = [
    'Booster',
    'Pre-starter',
    'Starter',
    'Grower',
    'Finisher',
  ];

  static const List<String> _sowStages = [
    'Booster',
    'Pre-starter',
    'Starter',
    'Grower',
    'Breeder',
    'Lactation',
  ];

  int _getStageIndex(String stage, List<String> stages) {
    final idx = stages.indexWhere((s) => s.toLowerCase() == stage.toLowerCase());
    return idx != -1 ? idx : 0;
  }



  @override
  Widget build(BuildContext context) {
    final fit = ScreenFit(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg = isDark ? const Color(0xFF111C2E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF18263D) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF283A57) : const Color(0xFFE2E8F0);
    final primaryTextColor = isDark ? const Color(0xFFF1F5F9) : _brandNavy;
    final mutedTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final String bName = batch['batch_name'] ?? batch['title'] ?? 'Batch Project';
    final String raiserName = batch['assigned_raiser'] ?? batch['raiser_name'] ?? 'Hog Raiser';
    final String? rawLoc = batch['location'] ?? batch['address'];
    final String location = (rawLoc != null && rawLoc.trim().isNotEmpty && rawLoc.trim().toLowerCase() != 'n/a')
        ? rawLoc.trim()
        : 'Farm Location Not Set';
    final String? rawPhone = batch['phone'] ?? batch['contact'];
    final String phone = (rawPhone != null && rawPhone.trim().isNotEmpty && rawPhone.trim().toLowerCase() != 'n/a')
        ? rawPhone.trim()
        : 'Not set';
    final String? rawAvatar = batch['avatar_url'] ?? batch['raiser_avatar_url'];
    final String? avatarUrl = (rawAvatar != null &&
            rawAvatar.trim().isNotEmpty &&
            !rawAvatar.toLowerCase().contains('googleusercontent.com') &&
            !rawAvatar.toLowerCase().contains('ggpht.com') &&
            !rawAvatar.toLowerCase().contains('google.com'))
        ? rawAvatar.trim()
        : null;
    final String rawHogType = (batch['hog_type'] ?? batch['pig_type'] ?? '').toString().trim();
    final String hogType = (rawHogType.isEmpty || rawHogType.toUpperCase() == 'N/A') ? 'Fattening' : rawHogType;
    final bool isSow = hogType.toLowerCase().contains('sow') || hogType.toLowerCase().contains('breed');
    final List<String> stages = isSow ? _sowStages : _fatteningStages;

    final String rawStage = (batch['stage'] ?? batch['lifecycle_stage'] ?? '').toString().trim();
    String stage = (rawStage.isEmpty || rawStage.toUpperCase() == 'N/A') ? 'Booster' : rawStage;

    // Sanitize stage: Fattening batches should never display breeding stages (like 'Gilt')
    if (!isSow && (stage.toLowerCase() == 'gilt' || !stages.any((s) => s.toLowerCase() == stage.toLowerCase()))) {
      stage = 'Booster';
    } else if (isSow && stage.toLowerCase() == 'gilt') {
      stage = 'Breeder';
    }

    final int totalHogs = (batch['total_hogs'] as num?)?.toInt() ?? (batch['total_hog'] as num?)?.toInt() ?? 0;
    final String appliedDate = batch['date_created']?.toString().split('T')[0] ?? batch['appliedDate'] ?? 'Active Season';

    final currentStageIdx = _getStageIndex(stage, stages);
    final displayStage = stages[currentStageIdx];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grabber Bar
            Container(
              margin: EdgeInsets.only(top: fit.dp(12), bottom: fit.dp(8)),
              width: fit.dp(40),
              height: fit.dp(4.5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Top Header: Batch Info & Close Button
            Padding(
              padding: EdgeInsets.fromLTRB(fit.dp(20), fit.dp(6), fit.dp(14), fit.dp(12)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: fit.dp(8), vertical: fit.dp(3.5)),
                              decoration: BoxDecoration(
                                color: _accentGreen.withValues(alpha: isDark ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(fit.dp(6)),
                              ),
                              child: Text(
                                'ACTIVE BATCH',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(10.5),
                                  fontWeight: FontWeight.w800,
                                  color: _accentGreen,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: fit.dp(4)),
                        Text(
                          bName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(20.0),
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: mutedTextColor,
                      size: fit.dp(22),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(fit.dp(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= 1. HOG RAISER PROFILE CARD =================
                    Container(
                      padding: EdgeInsets.all(fit.dp(16)),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(fit.dp(20)),
                        border: Border.all(color: cardBorder, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Avatar Container with default PiggyTrunk logo
                              Container(
                                width: fit.dp(54),
                                height: fit.dp(54),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _brandNavy, width: 2),
                                  color: isDark ? const Color(0xff1b2638) : Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _brandNavy.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                      ? Image.network(
                                          avatarUrl,
                                          width: fit.dp(54),
                                          height: fit.dp(54),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Padding(
                                            padding: EdgeInsets.all(fit.dp(6)),
                                            child: Image.asset(
                                              'assets/piggytrunk_logo.png',
                                              width: fit.dp(40),
                                              height: fit.dp(40),
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 28, color: _brandNavy),
                                            ),
                                          ),
                                        )
                                      : Padding(
                                          padding: EdgeInsets.all(fit.dp(6)),
                                          child: Image.asset(
                                            'assets/piggytrunk_logo.png',
                                            width: fit.dp(40),
                                            height: fit.dp(40),
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 28, color: _brandNavy),
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(width: fit.dp(14)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      raiserName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: fit.sp(16.5),
                                        fontWeight: FontWeight.w800,
                                        color: primaryTextColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: fit.dp(3)),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: fit.dp(13),
                                          color: mutedTextColor,
                                        ),
                                        SizedBox(width: fit.dp(3)),
                                        Expanded(
                                          child: Text(
                                            location,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: fit.sp(12.0),
                                              fontWeight: FontWeight.w600,
                                              color: mutedTextColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: fit.dp(14)),
                          Container(
                            height: 1,
                            color: cardBorder,
                          ),
                          SizedBox(height: fit.dp(12)),

                          // Contact & Applied Details Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInfoItem(
                                fit: fit,
                                icon: Icons.phone_outlined,
                                label: 'CONTACT NUMBER',
                                value: phone,
                                isDark: isDark,
                                primaryColor: primaryTextColor,
                                mutedColor: mutedTextColor,
                              ),
                              _buildInfoItem(
                                fit: fit,
                                icon: Icons.calendar_today_outlined,
                                label: 'DATE CREATED',
                                value: appliedDate,
                                isDark: isDark,
                                primaryColor: primaryTextColor,
                                mutedColor: mutedTextColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: fit.dp(16)),

                    // ================= 2. BATCH HOG METRICS =================
                    Container(
                      padding: EdgeInsets.all(fit.dp(16)),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(fit.dp(20)),
                        border: Border.all(color: cardBorder, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Hog Population & Type',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(13.5),
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: fit.dp(10), vertical: fit.dp(4.5)),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(fit.dp(12)),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  hogType,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(11.5),
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : _brandNavy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: fit.dp(14)),
                          Row(
                            children: [
                              _buildCountPill(
                                fit: fit,
                                label: 'TOTAL HOGS',
                                count: '$totalHogs',
                                color: isDark ? Colors.white : _brandNavy,
                                isDark: isDark,
                              ),
                              SizedBox(width: fit.dp(12)),
                              _buildCountPill(
                                fit: fit,
                                label: 'HEALTH STATUS',
                                count: 'Healthy',
                                color: _accentGreen,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: fit.dp(16)),

                    // ================= 3. 5-STAGE LIFECYCLE PROGRESS =================
                    Container(
                      padding: EdgeInsets.all(fit.dp(16)),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(fit.dp(20)),
                        border: Border.all(color: cardBorder, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lifecycle Stage',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(13.5),
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: fit.dp(10), vertical: fit.dp(4.5)),
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
                                      '$displayStage Stage',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: fit.sp(11.0),
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: fit.dp(18)),

                          // Interactive 5-Step Progress Track
                          Row(
                            children: List.generate(stages.length, (i) {
                              final sName = stages[i];
                              final isCurrent = i == currentStageIdx;
                              final isCompleted = i < currentStageIdx;

                              return Expanded(
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 3,
                                            color: i == 0
                                                ? Colors.transparent
                                                : (i <= currentStageIdx
                                                    ? (isDark ? Colors.white : _brandNavy)
                                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                          ),
                                        ),
                                        Container(
                                          width: fit.dp(26),
                                          height: fit.dp(26),
                                          decoration: BoxDecoration(
                                            color: isCurrent
                                                ? (isDark ? Colors.white : _brandNavy)
                                                : (isCompleted
                                                    ? const Color(0xFF10B981)
                                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isCurrent
                                                  ? (isDark ? Colors.white : _brandNavy)
                                                  : (isCompleted
                                                      ? const Color(0xFF10B981)
                                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                              width: isCurrent ? 2.5 : 1.2,
                                            ),
                                          ),
                                          child: isCompleted
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  size: 14,
                                                  color: Colors.white,
                                                )
                                              : (isCurrent
                                                  ? Center(
                                                      child: Container(
                                                        width: fit.dp(8),
                                                        height: fit.dp(8),
                                                        decoration: BoxDecoration(
                                                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                    )
                                                  : null),
                                        ),
                                        Expanded(
                                          child: Container(
                                            height: 3,
                                            color: i == stages.length - 1
                                                ? Colors.transparent
                                                : (i < currentStageIdx
                                                    ? (isDark ? Colors.white : _brandNavy)
                                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: fit.dp(6)),
                                    Text(
                                      sName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: fit.sp(9.5),
                                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                        color: isCurrent
                                            ? (isDark ? Colors.white : _brandNavy)
                                            : (isCompleted ? primaryTextColor : mutedTextColor),
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Strip
            Container(
              padding: EdgeInsets.fromLTRB(fit.dp(20), fit.dp(14), fit.dp(20), fit.dp(14)),
              decoration: BoxDecoration(
                color: sheetBg,
                border: Border(
                  top: BorderSide(color: cardBorder, width: 1),
                ),
              ),
              child: Row(
                children: [
                  if (onViewLifecycle != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onViewLifecycle?.call();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? const Color(0xFF334155) : cardBorder, width: 1.2),
                          padding: EdgeInsets.symmetric(vertical: fit.dp(14)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(fit.dp(14)),
                          ),
                        ),
                        icon: Icon(
                          Icons.timeline_rounded,
                          size: fit.dp(18),
                          color: isDark ? Colors.white : _brandNavy,
                        ),
                        label: Text(
                          'Lifecycle',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(12.5),
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : primaryTextColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: fit.dp(8)),
                  ],
                  if (onViewActivities != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onViewActivities?.call();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? const Color(0xFF334155) : cardBorder, width: 1.2),
                          padding: EdgeInsets.symmetric(vertical: fit.dp(14)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(fit.dp(14)),
                          ),
                        ),
                        icon: Icon(
                          Icons.feed_outlined,
                          size: fit.dp(18),
                          color: isDark ? Colors.white : primaryTextColor,
                        ),
                        label: Text(
                          'Raiser Logs',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(12.5),
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : primaryTextColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: fit.dp(8)),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onInvestNow();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : _brandNavy,
                        foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: fit.dp(14)),
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
                        'Invest in Batch',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(14.0),
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
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

  Widget _buildInfoItem({
    required ScreenFit fit,
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required Color primaryColor,
    required Color mutedColor,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: fit.dp(12), color: mutedColor),
              SizedBox(width: fit.dp(4)),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fit.sp(9.5),
                  fontWeight: FontWeight.w700,
                  color: mutedColor,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          SizedBox(height: fit.dp(3)),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fit.sp(12.5),
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCountPill({
    required ScreenFit fit,
    required String label,
    required String count,
    required Color color,
    required bool isDark,
  }) {
    final effectiveColor = (isDark && color == _brandNavy) ? Colors.white : color;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: fit.dp(10)),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131F33) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(fit.dp(12)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: fit.sp(9.0),
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: fit.dp(2)),
            Text(
              count,
              style: GoogleFonts.plusJakartaSans(
                fontSize: fit.sp(16.0),
                fontWeight: FontWeight.w900,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
