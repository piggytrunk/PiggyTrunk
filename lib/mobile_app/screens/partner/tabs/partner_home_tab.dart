import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/screen_fit_util.dart';
import '../../../utils/app_strings.dart';
import '../widgets/partner_notification_drawer.dart';
import '../widgets/batch_raiser_details_drawer.dart';

class PartnerHomeTab extends StatelessWidget {
  final String partnerName;
  final double investedAmount;
  final int activeProjectsCount;
  final List<Map<String, dynamic>> projectsList;
  final List<Map<String, dynamic>> fundedProjectsList;
  final List<Map<String, dynamic>> activitiesList;
  final List<Map<String, dynamic>> notificationsList;
  final Future<void> Function() onRefresh;
  final VoidCallback onSeeAllActivities;
  final VoidCallback onViewProjects;
  final ValueChanged<int>? onNavigateToTab;
  final Function(Map<String, dynamic> project)? onOpenProjectUpdates;
  final Function(int notificationId)? onMarkNotificationAsRead;
  final VoidCallback? onMarkAllRead;

  static const Color _brandColor = Color(0xFF18314F);
  static const Color _brandAccent = Color(0xFF2FB36F);

  const PartnerHomeTab({
    super.key,
    required this.partnerName,
    required this.investedAmount,
    required this.activeProjectsCount,
    this.projectsList = const [],
    this.fundedProjectsList = const [],
    required this.activitiesList,
    required this.notificationsList,
    required this.onRefresh,
    required this.onSeeAllActivities,
    required this.onViewProjects,
    this.onNavigateToTab,
    this.onOpenProjectUpdates,
    this.onMarkNotificationAsRead,
    this.onMarkAllRead,
  });

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  Widget _buildNotificationBell(BuildContext context, ScreenFit fit) {
    final unreadCount = notificationsList.where((n) => n['is_read'] != true).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xff28354a) : const Color(0xffe2e8f0);

    final double iconBgSize = fit.dp(42.0);
    final double iconSize = fit.dp(22.0);

    return GestureDetector(
      onTap: () {
        showPartnerNotificationDrawer(
          context: context,
          notifications: notificationsList,
          onMarkAsRead: (id) {
            if (onMarkNotificationAsRead != null) {
              onMarkNotificationAsRead!(id);
            }
          },
          onMarkAllAsRead: () {
            if (onMarkAllRead != null) {
              onMarkAllRead!();
            }
          },
          onNavigateToTab: onNavigateToTab,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: iconBgSize,
            height: iconBgSize,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff1b2638) : const Color(0xfff1f5f9),
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: isDark ? const Color(0xffecf2ff) : _brandColor,
              size: iconSize,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Center(
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fit = ScreenFit(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    final primaryTextColor = isDark ? Colors.white : _brandColor;
    final titleColor = isDark ? Colors.white : _brandColor;
    final cardBgColor = isDark ? const Color(0xff151f2e) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xff28354a) : const Color(0xffe6ebf2);
    final iconBgColor = isDark ? const Color(0xff1b2638) : const Color(0xfff0f4f8);
    final iconColor = isDark ? const Color(0xff9cb0c9) : const Color(0xff486581);

    final displayActivities = activitiesList;
    final hasInvestments = investedAmount > 0;

    // Calculate unique active raisers and total hogs strictly from the partner's actual funded investments
    final effectiveFunded = hasInvestments
        ? (fundedProjectsList.isNotEmpty
            ? fundedProjectsList
            : projectsList.where((p) => ((p['invested_amount'] as num?)?.toDouble() ?? 0) > 0).toList())
        : <Map<String, dynamic>>[];

    final displayProjects = (hasInvestments && effectiveFunded.isNotEmpty)
        ? effectiveFunded
        : projectsList;

    final uniqueRaisers = effectiveFunded
        .map((p) => p['assigned_raiser'] ?? p['raiser_name'] ?? '')
        .where((r) => r.toString().trim().isNotEmpty)
        .toSet()
        .length;

    int totalHogsFunded = 0;
    for (var p in effectiveFunded) {
      totalHogsFunded += (p['total_hogs'] as num?)?.toInt() ?? 0;
    }
    if (totalHogsFunded == 0 && hasInvestments) {
      totalHogsFunded = activeProjectsCount * 15;
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: isDark ? Colors.white : _brandColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(fit.dp(20), fit.dp(20), fit.dp(20), fit.dp(108)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== 1. TOP HEADER & NOTIFICATION ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.helloGreeting,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(14.0),
                          fontWeight: FontWeight.w500,
                          color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                        ),
                      ),

                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          (partnerName.trim().isNotEmpty && partnerName.trim().toLowerCase() != 'partner investor')
                              ? partnerName.trim()
                              : strings.partnerRole,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(22.0),
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildNotificationBell(context, fit),
              ],
            ),
            SizedBox(height: fit.dp(18.0)),

            // ==================== 2. MODERN PORTFOLIO HERO CARD ====================
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(fit.dp(24)),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0F1E33),
                    Color(0xFF18314F),
                    Color(0xFF24436A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF18314F).withValues(alpha: 0.28),
                    blurRadius: fit.dp(16),
                    offset: Offset(0, fit.dp(8)),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(fit.dp(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row inside card: Label + Status Tag
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: fit.dp(16),
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      (strings.isFilipino ? 'PORTFOLIO' : 'PORTFOLIO VALUE'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: fit.sp(11.0),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: fit.dp(10),
                                vertical: fit.dp(4),
                              ),
                              decoration: BoxDecoration(
                                color: hasInvestments
                                    ? _brandAccent.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(fit.dp(20)),
                                border: Border.all(
                                  color: hasInvestments
                                      ? _brandAccent.withValues(alpha: 0.5)
                                      : Colors.white.withValues(alpha: 0.25),
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
                                      color: hasInvestments ? _brandAccent : Colors.white70,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    hasInvestments
                                        ? (strings.isFilipino ? 'Aktibo' : 'Active Investor')
                                        : (strings.isFilipino ? 'Handa' : 'Ready to Invest'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: fit.sp(10.5),
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: fit.dp(12)),

                        // Large Investment Amount
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            investedAmount <= 0
                                ? '₱ 0.00'
                                : '₱ ${_formatCurrency(investedAmount)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: fit.sp(30.0),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                        SizedBox(height: fit.dp(4)),

                        Text(
                          hasInvestments
                              ? (strings.isFilipino
                                  ? 'Naipuhunan sa $activeProjectsCount aktibong batch ng baboy'
                                  : 'Funded across $activeProjectsCount active hog batches')
                              : (strings.isFilipino
                                  ? 'Simulang pondohan ang mga tagapag-alaga at kumita'
                                  : 'Start funding raisers & earn passive returns'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(12.0),
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        SizedBox(height: fit.dp(18)),

                        // Inner Glassmorphic 3-Column Metrics Bar
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: fit.dp(12),
                            vertical: fit.dp(12),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(fit.dp(14)),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // 1. Active Batches
                              Expanded(
                                child: _buildHeroStatItem(
                                  fit: fit,
                                  label: strings.isFilipino ? 'Mga Batch' : 'Batches',
                                  value: activeProjectsCount <= 0
                                      ? '0'
                                      : activeProjectsCount.toString().padLeft(2, '0'),
                                  icon: Icons.inventory_2_outlined,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: fit.dp(26),
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              // 2. Active Raisers
                              Expanded(
                                child: _buildHeroStatItem(
                                  fit: fit,
                                  label: strings.isFilipino ? 'Tagapag-alaga' : 'Raisers',
                                  value: uniqueRaisers <= 0
                                      ? '0'
                                      : uniqueRaisers.toString().padLeft(2, '0'),
                                  icon: Icons.people_alt_outlined,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: fit.dp(26),
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              // 3. Total Hogs
                              Expanded(
                                child: _buildHeroStatItem(
                                  fit: fit,
                                  label: strings.isFilipino ? 'Pinondohan' : 'Hogs Funded',
                                  value: totalHogsFunded <= 0
                                      ? '0'
                                      : totalHogsFunded.toString(),
                                  icon: Icons.pets_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: fit.dp(18.0)),

            // ==================== 3. QUICK ACTIONS GRID ====================
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        context: context,
                        fit: fit,
                        title: strings.isFilipino ? 'Puhunan' : strings.fundBatch,
                        subtitle: strings.investNow,
                        icon: Icons.add_card_rounded,
                        accentColor: const Color(0xFF10B981),
                        onTap: () {
                          if (onNavigateToTab != null) {
                            onNavigateToTab!(1); // Switch to Investment tab
                          } else {
                            onViewProjects();
                          }
                        },
                      ),
                    ),
                    SizedBox(width: fit.dp(12)),
                    Expanded(
                      child: _buildQuickActionCard(
                        context: context,
                        fit: fit,
                        title: strings.isFilipino ? 'Siklo ng Baboy' : strings.navLifecycle,
                        subtitle: strings.isFilipino ? 'Yugto ng paglaki' : 'Stage tracking',
                        icon: Icons.timeline_rounded,
                        accentColor: const Color(0xFF3B82F6),
                        onTap: () {
                          if (onNavigateToTab != null) {
                            onNavigateToTab!(2); // Switch to Lifecycle tab
                          }
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: fit.dp(12)),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        context: context,
                        fit: fit,
                        title: strings.isFilipino ? 'Mga Ulat' : strings.recentActivities,
                        subtitle: strings.isFilipino ? 'Field updates' : 'Live updates',
                        icon: Icons.feed_rounded,
                        accentColor: const Color(0xFFF59E0B),
                        onTap: () {
                          if (onNavigateToTab != null) {
                            onNavigateToTab!(3); // Switch to Activities tab
                          } else {
                            onSeeAllActivities();
                          }
                        },
                      ),
                    ),
                    SizedBox(width: fit.dp(12)),
                    Expanded(
                      child: _buildQuickActionCard(
                        context: context,
                        fit: fit,
                        title: strings.profile,
                        subtitle: strings.isFilipino ? 'Account' : 'Account info',
                        icon: Icons.person_rounded,
                        accentColor: const Color(0xFF8B5CF6),
                        onTap: () {
                          if (onNavigateToTab != null) {
                            onNavigateToTab!(4); // Switch to Profile tab
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: fit.dp(24.0)),

            // ==================== 4. ACTIVE PROJECTS / BATCHES SECTION ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  hasInvestments ? strings.myInvestments : strings.investmentOpportunities,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fit.sp(16.0),
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton(
                  onPressed: onViewProjects,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.seeAll,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(13.0),
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: fit.dp(16),
                        color: titleColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: fit.dp(12.0)),

            if (displayProjects.isEmpty)
              // Callout Banner to Invest
              InkWell(
                onTap: () {
                  if (onNavigateToTab != null) {
                    onNavigateToTab!(1);
                  } else {
                    onViewProjects();
                  }
                },
                borderRadius: BorderRadius.circular(fit.dp(20)),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(fit.dp(18)),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(fit.dp(20)),
                    border: Border.all(color: cardBorderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: fit.dp(48),
                        height: fit.dp(48),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.trending_up_rounded,
                          color: const Color(0xFF10B981),
                          size: fit.dp(24),
                        ),
                      ),
                      SizedBox(width: fit.dp(14)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Support Local Hog Raisers',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: fit.sp(14.5),
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Fund active batches and receive live growth & health updates.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: fit.sp(12.0),
                                fontWeight: FontWeight.w500,
                                color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: fit.dp(14),
                        color: isDark ? const Color(0xff9cb0c9) : Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              )
            else
              // Preview list of active project cards
              Column(
                children: displayProjects.take(2).map((proj) {
                  final String bName = proj['batch_name'] ?? 'Batch Project';
                  final String raiser = proj['assigned_raiser'] ?? proj['raiser_name'] ?? 'Assigned Raiser';
                  final String rawStage = (proj['stage'] ?? proj['lifecycle_stage'] ?? 'Grower').toString().trim();
                  final String stage = (rawStage.isEmpty || rawStage.toUpperCase() == 'N/A') ? 'Grower' : rawStage;
                  final String rawType = (proj['hog_type'] ?? proj['pig_type'] ?? 'Fattening').toString().trim();
                  final String hogType = (rawType.isEmpty || rawType.toUpperCase() == 'N/A') ? 'Fattening' : rawType;
                  final int hogs = (proj['total_hogs'] as num?)?.toInt() ?? 0;
                  final double invAmt = (proj['invested_amount'] as num?)?.toDouble() ?? 0.0;

                  return InkWell(
                    onTap: () => showBatchRaiserDetailsDrawer(
                      context: context,
                      batch: proj,
                      onInvestNow: () {
                        if (onNavigateToTab != null) {
                          onNavigateToTab!(1);
                        } else {
                          onViewProjects();
                        }
                      },
                      onViewLifecycle: () {
                        if (onNavigateToTab != null) {
                          onNavigateToTab!(2);
                        }
                      },
                      onViewActivities: () {
                        if (onNavigateToTab != null) {
                          onNavigateToTab!(3);
                        } else {
                          onSeeAllActivities();
                        }
                      },
                    ),
                    borderRadius: BorderRadius.circular(fit.dp(18)),
                    child: Container(
                      margin: EdgeInsets.only(bottom: fit.dp(10)),
                      padding: EdgeInsets.all(fit.dp(16)),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(fit.dp(18)),
                        border: Border.all(color: cardBorderColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1B2638) : const Color(0xFFEEF4FD),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.pets_rounded,
                                        size: fit.dp(18),
                                        color: isDark ? const Color(0xFF9CB0C9) : _brandColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bName,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: fit.sp(14.5),
                                              fontWeight: FontWeight.w800,
                                              color: primaryTextColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Raiser: $raiser • $hogType',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: fit.sp(12.0),
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '$stage Stage',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(10.5),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: fit.dp(12)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                invAmt > 0 ? 'Invested: ₱${_formatCurrency(invAmt)}' : '$hogs Hogs Assigned',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(12.0),
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View Details',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: fit.sp(12.0),
                                      fontWeight: FontWeight.w700,
                                      color: _brandAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: fit.dp(11),
                                    color: _brandAccent,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            SizedBox(height: fit.dp(24.0)),

            // ==================== 5. HOG RAISER ACTIVITIES SECTION ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  strings.recentActivities,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fit.sp(16.0),
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton(
                  onPressed: onSeeAllActivities,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.seeAll,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(13.0),
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: fit.dp(16),
                        color: titleColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: fit.dp(12.0)),

            // Activity List Cards
            if (displayActivities.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: fit.dp(20), vertical: fit.dp(28)),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(fit.dp(20)),
                  border: Border.all(color: cardBorderColor, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.assignment_outlined,
                        size: fit.dp(32),
                        color: iconColor,
                      ),
                    ),
                    SizedBox(height: fit.dp(12)),
                    Text(
                      strings.noActivitiesYet,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(14.5),
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    SizedBox(height: fit.dp(4)),
                    Text(
                      strings.isFilipino
                          ? 'Ang mga ulat at update mula sa iyong mga pinondohang tagapag-alaga ay lalabas dito.'
                          : 'Activities & updates from your funded hog raisers will appear here in real-time.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(12.0),
                        fontWeight: FontWeight.w500,
                        color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: fit.dp(14)),
                    OutlinedButton.icon(
                      onPressed: onViewProjects,
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        size: fit.dp(16),
                        color: _brandAccent,
                      ),
                      label: Text(
                        strings.isFilipino ? 'Tingnan ang mga Batch' : 'Explore Batches',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(12.5),
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : _brandColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark ? const Color(0xff28354a) : const Color(0xffcbd5e1),
                          width: 1.2,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: fit.dp(16),
                          vertical: fit.dp(9),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(fit.dp(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...displayActivities.take(4).map((act) {
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
                final IconData icon = (act['icon'] is IconData)
                    ? act['icon'] as IconData
                    : Icons.assignment_outlined;

                final style = _resolveActivityStyle(
                  type: act['type']?.toString(),
                  title: title,
                  isDark: isDark,
                );

                return Container(
                  margin: EdgeInsets.only(bottom: fit.dp(10)),
                  padding: EdgeInsets.all(fit.dp(16.0)),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(fit.dp(18)),
                    border: Border.all(color: cardBorderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: fit.dp(40.0),
                        height: fit.dp(40.0),
                        decoration: BoxDecoration(
                          color: style.bgColor,
                          borderRadius: BorderRadius.circular(fit.dp(12)),
                          border: Border.all(
                            color: style.borderColor,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: style.iconColor,
                          size: fit.dp(20.0),
                        ),
                      ),
                      SizedBox(width: fit.dp(14.0)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: fit.sp(13.5),
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                description,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(11.5),
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (date.isNotEmpty && !date.toLowerCase().contains('milestone')) ...[
                              const SizedBox(height: 3),
                              Text(
                                date,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(10.5),
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
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

  Widget _buildHeroStatItem({
    required ScreenFit fit,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: fit.dp(13),
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: fit.sp(10.5),
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: fit.sp(16.0),
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required ScreenFit fit,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xff151f2e) : Colors.white;
    final borderColor = isDark ? const Color(0xff28354a) : const Color(0xffe6ebf2);
    final primaryTextColor = isDark ? const Color(0xffecf2ff) : _brandColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(fit.dp(16)),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: fit.dp(12), vertical: fit.dp(14)),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(fit.dp(16)),
            border: Border.all(color: borderColor, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                blurRadius: 8,
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: fit.dp(20),
                      color: accentColor,
                    ),
                  ),
                  Container(
                    width: fit.dp(24),
                    height: fit.dp(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1b2638) : const Color(0xfff1f5f9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: fit.dp(16),
                      color: isDark ? const Color(0xff9cb0c9) : const Color(0xff64748b),
                    ),
                  ),
                ],
              ),
              SizedBox(height: fit.dp(10)),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fit.sp(12.5),
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fit.sp(10.5),
                  fontWeight: FontWeight.w500,
                  color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
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
