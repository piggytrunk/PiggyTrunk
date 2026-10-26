import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/screen_fit_util.dart';
import '../../../utils/app_strings.dart';

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

  static const Color _brandNavy = PiggyTrunkTheme.ptPrimary;
  static const Color _accentGreen = PiggyTrunkTheme.ptSuccess;

  const _BatchRaiserDetailsContent({
    required this.batch,
    required this.onInvestNow,
    this.onViewActivities,
    this.onViewLifecycle,
  });

  static const List<String> _fatteningStages = [
    'Booster',
    'Pre-Starter',
    'Starter',
    'Grower',
    'Finisher',
    'Selling',
  ];

  static const List<String> _sowStages = [
    'Booster',
    'Pre-Starter',
    'Starter',
    'Grower',
    'Breeder',
    'Lactation',
  ];

  String _getHogPigType(Map<String, dynamic> hog, String fallbackType) {
    final raw = (hog['pig_type'] ?? hog['type_name'] ?? hog['type'] ?? hog['production_type'] ?? '').toString().trim();
    if (raw.isNotEmpty && raw != 'null' && raw != 'N/A' && raw != 'None') {
      final l = raw.toLowerCase();
      return (l == 'sow' || l.contains('breed')) ? 'Sow' : 'Fattening';
    }
    final fallbackLower = fallbackType.toLowerCase();
    return (fallbackLower == 'sow' || fallbackLower.contains('breed')) ? 'Sow' : 'Fattening';
  }

  String _getHogStage(Map<String, dynamic> hog, String fallbackStage, bool isBreeding) {
    final stages = isBreeding ? _sowStages : _fatteningStages;
    final sId = hog['stage_id'];
    if (sId != null) {
      final id = int.tryParse(sId.toString());
      if (id != null && id >= 1 && id <= stages.length) {
        return stages[id - 1];
      }
    }
    final rawStage = (hog['stage'] ?? hog['lifecycle_stage'])?.toString().trim();
    if (rawStage != null && rawStage.isNotEmpty && rawStage != 'null') {
      for (final st in stages) {
        if (st.toLowerCase() == rawStage.toLowerCase()) return st;
      }
      final l = rawStage.toLowerCase();
      if (l.contains('finish')) return isBreeding ? 'Breeder' : 'Finisher';
      if (l.contains('breed') || l.contains('gilt')) return isBreeding ? 'Breeder' : 'Grower';
      if (l.contains('sell') || l.contains('sold')) return isBreeding ? 'Lactation' : 'Selling';
      if (l.contains('lactat')) return isBreeding ? 'Lactation' : 'Selling';
      if (l.contains('pre')) return 'Pre-Starter';
      if (l.contains('boost')) return 'Booster';
      if (l.contains('start')) return 'Starter';
      if (l.contains('grow')) return 'Grower';
      return rawStage;
    }
    return fallbackStage.isNotEmpty ? fallbackStage : 'Booster';
  }

  int _getStageIndex(String stage, List<String> stages) {
    final idx = stages.indexWhere((s) => s.toLowerCase() == stage.toLowerCase());
    if (idx != -1) return idx;
    final lower = stage.toLowerCase();
    if (lower.contains('finish')) {
      final fi = stages.indexWhere((s) => s.toLowerCase().contains('finish'));
      if (fi != -1) return fi;
    }
    if (lower.contains('breed') || lower.contains('gilt')) {
      final bi = stages.indexWhere((s) => s.toLowerCase().contains('breed'));
      if (bi != -1) return bi;
    }
    if (lower.contains('sell') || lower.contains('sold') || lower.contains('complete')) {
      return stages.length - 1;
    }
    if (lower.contains('lactat')) {
      final li = stages.indexWhere((s) => s.toLowerCase().contains('lactat'));
      if (li != -1) return li;
    }
    if (lower.contains('grow')) {
      final gi = stages.indexWhere((s) => s.toLowerCase().contains('grow'));
      if (gi != -1) return gi;
    }
    if (lower.contains('start')) {
      final si = stages.indexWhere((s) => s.toLowerCase() == 'starter');
      if (si != -1) return si;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final fit = ScreenFit(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

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
    final bool isBatchSow = hogType.toLowerCase().contains('sow') || hogType.toLowerCase().contains('breed');

    final String rawStage = (batch['stage'] ?? batch['lifecycle_stage'] ?? '').toString().trim();
    final String batchStage = (rawStage.isEmpty || rawStage.toUpperCase() == 'N/A') ? 'Booster' : rawStage;

    final int totalHogs = (batch['total_hogs'] as num?)?.toInt() ?? (batch['total_hog'] as num?)?.toInt() ?? 0;
    final String appliedDate = batch['date_created']?.toString().split('T')[0] ?? batch['appliedDate'] ?? 'Active Season';

    // Parse hogs list from batch
    final List<Map<String, dynamic>> rawHogs = batch['hogs'] is List
        ? List<Map<String, dynamic>>.from(
            (batch['hogs'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)))
        : [];

    List<Map<String, dynamic>> hogs = List.from(rawHogs);
    if (hogs.isEmpty && totalHogs > 0) {
      hogs = List.generate(totalHogs, (i) {
        return {
          'tag_number': 'Hog #${i + 1}',
          'index': i + 1,
          'pig_type': isBatchSow ? 'Sow' : 'Fattening',
          'stage': batchStage,
          'status': 'active',
        };
      });
    }

    if (hogs.isNotEmpty) {
      hogs.sort((a, b) {
        final isSowA = _getHogPigType(a, hogType) == 'Sow';
        final isSowB = _getHogPigType(b, hogType) == 'Sow';
        if (isSowA != isSowB) {
          return isSowA ? 1 : -1; // Fattening first, Sow/Breeding second
        }
        final tagA = (a['tag_number'] ?? a['hog_id'] ?? '').toString();
        final tagB = (b['tag_number'] ?? b['hog_id'] ?? '').toString();
        final numA = int.tryParse(tagA.replaceAll(RegExp(r'[^0-9]'), '')) ?? (a['index'] as num?)?.toInt() ?? 0;
        final numB = int.tryParse(tagB.replaceAll(RegExp(r'[^0-9]'), '')) ?? (b['index'] as num?)?.toInt() ?? 0;
        return numA.compareTo(numB);
      });
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                                strings.isFilipino ? 'AKTIBONG BATCH' : 'ACTIVE BATCH',
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
                                label: strings.isFilipino ? 'NUMERO NG KONTAK' : 'CONTACT NUMBER',
                                value: phone,
                                isDark: isDark,
                                primaryColor: primaryTextColor,
                                mutedColor: mutedTextColor,
                              ),
                              _buildInfoItem(
                                fit: fit,
                                icon: Icons.calendar_today_outlined,
                                label: strings.isFilipino ? 'PETSA NG GAWA' : 'DATE CREATED',
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
                                strings.isFilipino ? 'Bilang at Uri ng Baboy' : 'Hog Population & Type',
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
                                label: strings.isFilipino ? 'KABUUANG BABOY' : 'TOTAL HOGS',
                                count: '$totalHogs',
                                color: isDark ? Colors.white : _brandNavy,
                                isDark: isDark,
                              ),
                              SizedBox(width: fit.dp(12)),
                              _buildCountPill(
                                fit: fit,
                                label: strings.isFilipino ? 'KALUSUGAN' : 'HEALTH STATUS',
                                count: strings.isFilipino ? 'Malusog' : 'Healthy',
                                color: _accentGreen,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: fit.dp(18)),

                    // ================= 3. ALL HOGS LIFECYCLE PROGRESS (FULL LIST) =================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.isFilipino ? 'Siklo ng mga Alagang Baboy' : 'Hogs Lifecycle Progress',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(15.0),
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                ),
                              ),
                              SizedBox(height: fit.dp(2)),
                              Text(
                                strings.isFilipino
                                    ? 'Yugto ng bawat alaga sa kasalukuyang batch'
                                    : 'Growth stage per assigned hog in active batch',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(11.0),
                                  fontWeight: FontWeight.w500,
                                  color: mutedTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: fit.dp(10), vertical: fit.dp(4)),
                          decoration: BoxDecoration(
                            color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                            borderRadius: BorderRadius.circular(fit.dp(10)),
                            border: Border.all(
                              color: cardBorder,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            strings.isFilipino ? '${hogs.length} na Baboy' : '${hogs.length} Hogs',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: fit.sp(11.0),
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: fit.dp(6)),

                    // Full Vertical List of Individual Hog Cards with 6-Stage Steppers
                    if (hogs.isNotEmpty)
                      ...hogs.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final h = entry.value;

                        final hType = _getHogPigType(h, hogType);
                        final hIsSow = hType == 'Sow';
                        final hStages = hIsSow ? _sowStages : _fatteningStages;

                        final hStage = _getHogStage(h, batchStage, hIsSow);
                        final isHogDone = (h['status'] ?? '').toString().toLowerCase() == 'completed' ||
                            (h['status'] ?? '').toString().toLowerCase() == 'sold' ||
                            hStage.toLowerCase() == 'selling' ||
                            hStage.toLowerCase() == 'lactation' ||
                            hStage.toLowerCase().contains('sell') ||
                            hStage.toLowerCase().contains('lactat');

                        final hStageIdx = isHogDone ? hStages.length - 1 : _getStageIndex(hStage, hStages);
                        final hDisplayStage = isHogDone ? (hIsSow ? 'Lactation' : 'Selling') : hStages[hStageIdx];

                        final rawTag = (h['tag_number'] ?? h['hog_id'] ?? '').toString().trim();
                        final hogLabel = rawTag.isNotEmpty && !rawTag.toLowerCase().contains('null')
                            ? (rawTag.toLowerCase().startsWith('tag') || rawTag.toLowerCase().startsWith('hog')
                                ? rawTag
                                : 'Hog #$rawTag')
                            : '${strings.isFilipino ? "Baboy" : "Hog"} #${idx + 1}';

                        return Container(
                          margin: EdgeInsets.only(top: fit.dp(12)),
                          padding: EdgeInsets.all(fit.dp(15)),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(fit.dp(18)),
                            border: Border.all(color: cardBorder, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Card Top Header: Hog Name & Production Type on Left, Status Pill on Right
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        hogLabel,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: fit.sp(13.5),
                                          fontWeight: FontWeight.w800,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      SizedBox(width: fit.dp(8)),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: fit.dp(7), vertical: fit.dp(2.5)),
                                        decoration: BoxDecoration(
                                          color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                                          borderRadius: BorderRadius.circular(fit.dp(6)),
                                          border: Border.all(
                                            color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          hIsSow
                                              ? (strings.isFilipino ? 'INAHING BABOY' : 'SOW / BREEDING')
                                              : (strings.isFilipino ? 'PANG-KATAY' : 'FATTENING'),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: fit.sp(9.0),
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Live Status Badge
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: fit.dp(8), vertical: fit.dp(3.5)),
                                    decoration: BoxDecoration(
                                      color: (isHogDone ? _accentGreen : const Color(0xFF10B981)).withValues(alpha: isDark ? 0.2 : 0.12),
                                      borderRadius: BorderRadius.circular(fit.dp(14)),
                                      border: Border.all(
                                        color: (isHogDone ? _accentGreen : const Color(0xFF10B981)).withValues(alpha: isDark ? 0.4 : 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: fit.dp(5),
                                          height: fit.dp(5),
                                          decoration: BoxDecoration(
                                            color: isHogDone ? _accentGreen : const Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: fit.dp(4)),
                                        Text(
                                          isHogDone
                                              ? (strings.isFilipino ? 'Tapos Na ($hDisplayStage)' : 'Completed ($hDisplayStage)')
                                              : '$hDisplayStage ${strings.isFilipino ? "Yugto" : "Stage"}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: fit.sp(10.0),
                                            fontWeight: FontWeight.w800,
                                            color: isHogDone ? _accentGreen : const Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: fit.dp(14)),

                              // 6-Step Stepper Track for this specific hog
                              Row(
                                children: List.generate(hStages.length, (i) {
                                  final sName = hStages[i];
                                  final isStepCompleted = isHogDone ? true : i < hStageIdx;
                                  final isStepCurrent = !isHogDone && (i == hStageIdx);

                                  return Expanded(
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                height: 2.5,
                                                color: i == 0
                                                    ? Colors.transparent
                                                    : (isHogDone || i <= hStageIdx
                                                        ? (isDark ? Colors.white : _brandNavy)
                                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                              ),
                                            ),
                                            Container(
                                              width: fit.dp(22),
                                              height: fit.dp(22),
                                              decoration: BoxDecoration(
                                                color: isStepCurrent
                                                    ? (isDark ? Colors.white : _brandNavy)
                                                    : (isStepCompleted
                                                        ? const Color(0xFF10B981)
                                                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isStepCurrent
                                                      ? (isDark ? Colors.white : _brandNavy)
                                                      : (isStepCompleted
                                                          ? const Color(0xFF10B981)
                                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                                  width: isStepCurrent ? 2.0 : 1.0,
                                                ),
                                              ),
                                              child: isStepCompleted
                                                  ? const Icon(
                                                      Icons.check_rounded,
                                                      size: 12,
                                                      color: Colors.white,
                                                    )
                                                  : (isStepCurrent
                                                      ? Center(
                                                          child: Container(
                                                            width: fit.dp(6),
                                                            height: fit.dp(6),
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
                                                height: 2.5,
                                                color: i == hStages.length - 1
                                                    ? Colors.transparent
                                                    : (isHogDone || i < hStageIdx
                                                        ? (isDark ? Colors.white : _brandNavy)
                                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: fit.dp(5)),
                                        Text(
                                          sName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: fit.sp(8.5),
                                            fontWeight: (isStepCurrent || isStepCompleted) ? FontWeight.w800 : FontWeight.w600,
                                            color: isStepCurrent
                                                ? (isDark ? Colors.white : _brandNavy)
                                                : (isStepCompleted ? primaryTextColor : mutedTextColor),
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
                        );
                      })
                    else
                      Container(
                        margin: EdgeInsets.only(top: fit.dp(12)),
                        padding: EdgeInsets.all(fit.dp(16)),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(fit.dp(18)),
                          border: Border.all(color: cardBorder, width: 1.2),
                        ),
                        child: Center(
                          child: Text(
                            strings.isFilipino
                                ? 'Walang naitalang baboy sa batch na ito.'
                                : 'No individual hogs recorded for this batch yet.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: fit.sp(12.0),
                              fontWeight: FontWeight.w600,
                              color: mutedTextColor,
                            ),
                          ),
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
                          strings.isFilipino ? 'Siklo' : 'Lifecycle',
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
                          strings.isFilipino ? 'Talaan' : 'Raiser Logs',
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
                        strings.isFilipino ? 'Mamuhunan' : 'Invest in Batch',
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
