import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/screen_fit_util.dart';
import '../../../utils/app_strings.dart';

class PartnerActivitiesTab extends StatefulWidget {
  final List<Map<String, dynamic>> activitiesList;
  final Future<void> Function() onRefresh;
  final VoidCallback? onNavigateToBatches;
  final VoidCallback? onNavigateToLifecycle;

  const PartnerActivitiesTab({
    super.key,
    required this.activitiesList,
    required this.onRefresh,
    this.onNavigateToBatches,
    this.onNavigateToLifecycle,
  });

  @override
  State<PartnerActivitiesTab> createState() => _PartnerActivitiesTabState();
}

class _PartnerActivitiesTabState extends State<PartnerActivitiesTab> {
  static const Color _brandColor = Color(0xFF18314F);

  String _selectedFilter = 'All'; // 'All', 'Investment', or 'Reports'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredActivities() {
    return widget.activitiesList.where((act) {
      final title = (act['title'] ?? '').toString().toLowerCase();
      final desc = (act['description'] ?? act['message'] ?? '').toString().toLowerCase();
      final type = (act['type'] ?? '').toString().toLowerCase();
      final raiser = (act['raiser_name'] ?? '').toString().toLowerCase();
      final reportId = (act['report_id'] ?? '').toString().toLowerCase();

      // Check whether this record represents an investment transaction
      final isInvestment = type.contains('invest') ||
          reportId.startsWith('inv_') ||
          title.contains('funded') ||
          title.contains('invest') ||
          title.contains('puhu') ||
          desc.contains('invest') ||
          desc.contains('funded') ||
          desc.contains('puhu');

      // Category filter
      if (_selectedFilter == 'Investment') {
        if (!isInvestment) return false;
      } else if (_selectedFilter == 'Reports') {
        // Exclude pure investment records, focus on farm raiser field updates
        if (isInvestment) return false;
      }

      if (_searchController.text.trim().isNotEmpty) {
        final query = _searchController.text.trim().toLowerCase();
        return title.contains(query) || desc.contains(query) || raiser.contains(query);
      }

      return true;
    }).toList();
  }

  _ActivityThemeStyle _resolveActivityStyle({
    required String? type,
    required String title,
    required bool isDark,
  }) {
    final lowerType = (type ?? '').toLowerCase();
    final lowerTitle = title.toLowerCase();

    // 1. Mortality / Critical Alert
    if (lowerType.contains('mortality') ||
        lowerType.contains('dead') ||
        lowerType.contains('injur') ||
        lowerType.contains('diarrhea') ||
        lowerType.contains('poison') ||
        lowerTitle.contains('mortality') ||
        lowerTitle.contains('death') ||
        lowerTitle.contains('fever')) {
      return _ActivityThemeStyle(
        iconColor: isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent,
        bgColor: isDark ? const Color(0xFF2F1B22) : const Color(0xFFFEF2F2),
        borderColor: isDark ? const Color(0xFF4D2531) : const Color(0xFFFCDADF),
      );
    }

    // 2. Investment / Funding (Financial Success)
    if (lowerType.contains('invest') ||
        lowerTitle.contains('invest') ||
        lowerTitle.contains('fund') ||
        lowerTitle.contains('puhu')) {
      return _ActivityThemeStyle(
        iconColor: isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess,
        bgColor: isDark ? const Color(0xFF1B2F2B) : const Color(0xFFE8F7EE),
        borderColor: isDark ? const Color(0xFF264A3E) : const Color(0xFFC6F0D8),
      );
    }

    // 3. Health & Veterinary Care
    if (lowerType.contains('health') ||
        lowerType.contains('vaccin') ||
        lowerType.contains('med') ||
        lowerType.contains('observation') ||
        lowerTitle.contains('health') ||
        lowerTitle.contains('gamot')) {
      return _ActivityThemeStyle(
        iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
        bgColor: isDark ? const Color(0xFF132E27) : const Color(0xFFECFDF5),
        borderColor: isDark ? const Color(0xFF1F453B) : const Color(0xFFA7F3D0),
      );
    }

    // 4. Feeding & Restock
    if (lowerType.contains('feed') ||
        lowerType.contains('weight') ||
        lowerType.contains('nutrition') ||
        lowerTitle.contains('feed') ||
        lowerTitle.contains('pakain')) {
      return _ActivityThemeStyle(
        iconColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
        bgColor: isDark ? const Color(0xFF2E2415) : const Color(0xFFFEF3C7),
        borderColor: isDark ? const Color(0xFF4B3A20) : const Color(0xFFFDE68A),
      );
    }

    // 5. Lifecycle / Milestone / Stage
    if (lowerType.contains('lifecycle') ||
        lowerType.contains('stage') ||
        lowerType.contains('growth') ||
        lowerType.contains('milestone') ||
        lowerTitle.contains('stage')) {
      return _ActivityThemeStyle(
        iconColor: isDark ? const Color(0xFF9CB0C9) : _brandColor,
        bgColor: isDark ? const Color(0xFF1B2638) : const Color(0xFFEEF4FD),
        borderColor: isDark ? const Color(0xFF28354A) : const Color(0xFFE2E8F0),
      );
    }

    // 6. Default / General Activity
    return _ActivityThemeStyle(
      iconColor: isDark ? const Color(0xFF9CB0C9) : const Color(0xFF243B53),
      bgColor: isDark ? const Color(0xFF1B2638) : const Color(0xFFF1F5F9),
      borderColor: isDark ? const Color(0xFF28354A) : const Color(0xFFE2E8F0),
    );
  }

  IconData _getIconForActivity(String type) {
    final t = type.toLowerCase();
    if (t.contains('invest')) {
      return Icons.assignment_rounded;
    } else if (t.contains('vaccin') || t.contains('med')) {
      return Icons.medication_rounded;
    } else if (t.contains('sick') || t.contains('health') || t.contains('observation')
        || t.contains('fever') || t.contains('poison') || t.contains('diarrhea') || t.contains('injur') || t.contains('dead') || t.contains('mortality')) {
      return Icons.health_and_safety_rounded;
    } else if (t.contains('feed') || t.contains('weight') || t.contains('nutrition')) {
      return Icons.monitor_weight_rounded;
    } else if (t.contains('stage') || t.contains('growth') || t.contains('lifecycle')) {
      return Icons.trending_up_rounded;
    }
    return Icons.assignment_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final fit = ScreenFit(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    final primaryTextColor = isDark ? Colors.white : _brandColor;
    final cardBgColor = isDark ? const Color(0xff151f2e) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xff28354a) : const Color(0xffe6ebf2);
    final secondaryBgColor = isDark ? const Color(0xff1b2638) : const Color(0xfff8fafc);
    final mutedTextColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

    final filteredActivities = _getFilteredActivities();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: isDark ? Colors.white : _brandColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(fit.dp(20), fit.dp(20), fit.dp(20), fit.dp(36)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== 1. FILTER PILLS ====================
            Row(
              children: [
                Expanded(
                  child: _buildFilterChip(
                    fit: fit,
                    label: strings.isFilipino ? 'Lahat ng Log' : 'All Logs',
                    value: 'All',
                    isDark: isDark,
                    icon: Icons.list_alt_rounded,
                  ),
                ),
                SizedBox(width: fit.dp(8)),
                Expanded(
                  child: _buildFilterChip(
                    fit: fit,
                    label: strings.isFilipino ? 'Pamumuhunan' : 'Investment',
                    value: 'Investment',
                    isDark: isDark,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                SizedBox(width: fit.dp(8)),
                Expanded(
                  child: _buildFilterChip(
                    fit: fit,
                    label: strings.isFilipino ? 'Mga Ulat ng Raiser' : 'Raiser Reports',
                    value: 'Reports',
                    isDark: isDark,
                    icon: Icons.health_and_safety_outlined,
                  ),
                ),
              ],
            ),
            SizedBox(height: fit.dp(16)),

            // ==================== 2. ACTIVITIES LIST ====================
            if (filteredActivities.isEmpty) ...[
              _buildCategoryEmptyState(
                fit: fit,
                isDark: isDark,
                cardBg: cardBgColor,
                cardBorder: cardBorderColor,
                primaryText: primaryTextColor,
                mutedText: mutedTextColor,
                filter: _selectedFilter,
                strings: strings,
              ),
              if (widget.onNavigateToBatches != null) ...[
                SizedBox(height: fit.dp(16)),
                _buildExploreBatchesButton(fit: fit, isDark: isDark, strings: strings),
              ],
            ] else ...[
              // Summary counter
              Padding(
                padding: EdgeInsets.only(bottom: fit.dp(12)),
                child: Text(
                  _selectedFilter == 'Investment'
                      ? (strings.isFilipino
                          ? 'MGA AKTIBIDAD SA PAMUMUHUNAN (${filteredActivities.length})'
                          : 'INVESTMENT ACTIVITIES (${filteredActivities.length})')
                      : _selectedFilter == 'Reports'
                          ? (strings.isFilipino
                              ? 'MGA ULAT NG RAISER (${filteredActivities.length})'
                              : 'RAISER FIELD REPORTS (${filteredActivities.length})')
                          : (strings.isFilipino
                              ? 'LAHAT NG AKTIBIDAD (${filteredActivities.length})'
                              : 'ALL ACTIVITIES & LOGS (${filteredActivities.length})'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fit.sp(11.5),
                    fontWeight: FontWeight.w800,
                    color: mutedTextColor,
                    letterSpacing: 0.6,
                  ),
                ),
              ),

              // Activity Cards Stream
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredActivities.length,
                separatorBuilder: (context, index) => SizedBox(height: fit.dp(12)),
                itemBuilder: (ctx, index) {
                  final act = filteredActivities[index];
                  final isFil = strings.isFilipino;
                  final String title = isFil
                      ? (act['title_fil'] ?? act['title'] ?? 'Aktibidad')
                      : (act['title_en'] ?? act['title'] ?? 'Activity Update');
                  final String description = isFil
                      ? (act['desc_fil'] ?? act['description'] ?? act['message'] ?? '')
                      : (act['desc_en'] ?? act['description'] ?? act['message'] ?? '');
                  final String date = isFil
                      ? (act['date_fil'] ?? act['date'] ?? act['created_at'] ?? '')
                      : (act['date'] ?? act['created_at'] ?? '');
                  final String type = act['type'] ?? 'general';
                  final bool isInvestment = type.toLowerCase().contains('invest') ||
                      (act['report_id'] ?? '').toString().startsWith('inv_');

                  final style = _resolveActivityStyle(
                    type: isInvestment ? 'invest' : type,
                    title: title,
                    isDark: isDark,
                  );
                  final IconData typeIcon = isInvestment
                      ? Icons.assignment_rounded
                      : ((act['icon'] is IconData) ? act['icon'] as IconData : _getIconForActivity(type));

                  return Container(
                    padding: EdgeInsets.all(fit.dp(16)),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(fit.dp(18)),
                      border: Border.all(color: cardBorderColor, width: 1.1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: fit.dp(40),
                          height: fit.dp(40),
                          decoration: BoxDecoration(
                            color: style.bgColor,
                            borderRadius: BorderRadius.circular(fit.dp(12)),
                            border: Border.all(
                              color: style.borderColor,
                              width: 1,
                            ),
                          ),
                          child: Icon(typeIcon, size: fit.dp(20), color: style.iconColor),
                        ),
                        SizedBox(width: fit.dp(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: fit.sp(14.5),
                                        fontWeight: FontWeight.w800,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ),
                                  if (date.isNotEmpty && !date.toLowerCase().contains('milestone')) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: fit.dp(8), vertical: fit.dp(3)),
                                      decoration: BoxDecoration(
                                        color: secondaryBgColor,
                                        borderRadius: BorderRadius.circular(fit.dp(10)),
                                        border: Border.all(color: cardBorderColor, width: 0.8),
                                      ),
                                      child: Text(
                                        date,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: fit.sp(10.5),
                                          fontWeight: FontWeight.w600,
                                          color: mutedTextColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (description.isNotEmpty) ...[
                                SizedBox(height: fit.dp(6)),
                                Text(
                                  description,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(12.5),
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              if (!isInvestment) ...[
                                SizedBox(height: fit.dp(10)),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_pin_circle_outlined,
                                      size: fit.dp(14),
                                      color: mutedTextColor,
                                    ),
                                    SizedBox(width: fit.dp(4)),
                                    Text(
                                      isFil ? 'Itinala ng Nakatalagang Raiser' : 'Logged by Assigned Raiser',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: fit.sp(11.5),
                                        fontWeight: FontWeight.w600,
                                        color: mutedTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Filter Chip Component
  Widget _buildFilterChip({
    required ScreenFit fit,
    required String label,
    required String value,
    required bool isDark,
    IconData? icon,
  }) {
    final isSelected = _selectedFilter == value;
    final activeBg = isDark ? Colors.white : _brandColor;
    final activeText = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inactiveBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final inactiveBorder = isDark ? const Color(0xFF28354A) : const Color(0xFFE2E8F0);
    final inactiveText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(fit.dp(20)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: fit.dp(38),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: fit.dp(6)),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(fit.dp(20)),
          border: Border.all(
            color: isSelected ? activeBg : inactiveBorder,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? Colors.white : _brandColor).withValues(alpha: isDark ? 0.15 : 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: fit.dp(14),
                  color: isSelected ? activeText : inactiveText,
                ),
                SizedBox(width: fit.dp(5)),
              ],
              Text(
                label,
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fit.sp(11.5),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? activeText : inactiveText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Context-aware empty state for filters
  Widget _buildCategoryEmptyState({
    required ScreenFit fit,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color primaryText,
    required Color mutedText,
    required String filter,
    required AppStrings strings,
  }) {
    IconData icon = Icons.assignment_outlined;
    String title = strings.noReportsYet;
    String subtitle = strings.noReportsSubtitle;

    if (filter == 'Investment') {
      icon = Icons.account_balance_wallet_outlined;
      title = strings.isFilipino ? 'Walang Tala ng Pamumuhunan' : 'No Investment Records Yet';
      subtitle = strings.isFilipino
          ? 'Wala pang aktibidad sa pamumuhunan na naitala para sa iyong account.'
          : 'No investment activities found yet. Your investments and funding logs will appear here.';
    } else if (filter == 'Reports') {
      icon = Icons.health_and_safety_rounded;
      title = strings.isFilipino ? 'Walang Sakit na Naitala' : 'No Health Alerts Reported';
      subtitle = strings.isFilipino
          ? 'Walang sakit o alertong naitala mula sa iyong mga inaalagaang baboy.'
          : 'No health alerts reported; hogs are healthy with regular checkups on track.';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: fit.dp(20), vertical: fit.dp(24)),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(fit.dp(20)),
        border: Border.all(color: cardBorder, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: fit.dp(48),
            height: fit.dp(48),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: fit.dp(22), color: isDark ? Colors.white : _brandColor),
          ),
          SizedBox(height: fit.dp(10)),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fit.sp(14.5),
              fontWeight: FontWeight.w800,
              color: primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: fit.dp(4)),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fit.sp(12.0),
              fontWeight: FontWeight.w500,
              color: mutedText,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExploreBatchesButton({
    required ScreenFit fit,
    required bool isDark,
    required AppStrings strings,
  }) {
    return SizedBox(
      width: double.infinity,
      height: fit.dp(48),
      child: ElevatedButton.icon(
        onPressed: widget.onNavigateToBatches,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : _brandColor,
          foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(fit.dp(14))),
        ),
        icon: Icon(
          Icons.inventory_2_outlined,
          size: fit.dp(18),
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
        ),
        label: Text(
          strings.isFilipino ? 'Tingnan ang mga Batch' : 'Explore Available Batches',
          style: GoogleFonts.plusJakartaSans(
            fontSize: fit.sp(13.5),
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ActivityThemeStyle {
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;

  const _ActivityThemeStyle({
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
  });
}
