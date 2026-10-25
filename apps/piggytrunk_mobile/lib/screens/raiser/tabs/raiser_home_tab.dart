import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/app_strings.dart';
import '../widgets/raiser_header_bar.dart';

class RaiserHomeTab extends StatelessWidget {
  final Map<String, dynamic> raiserData;
  final double investedAmount;
  final double initialCapital;
  final double stocksSpendAmount;
  final List<Map<String, dynamic>> providedStocksList;
  final List<Map<String, dynamic>> requestsList;
  final List<Map<String, dynamic>> notificationsList;
  final List<Map<String, dynamic>> activeAssignments;
  final List<Map<String, dynamic>> hogsList;
  final List<Map<String, dynamic>> reportsList;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onNavigateToTab;
  final Function(int notificationId) onMarkNotificationAsRead;
  final VoidCallback onMarkAllRead;
  final Function(String targetStage) onUpdateLifecycleStage;

  static const Color _brandColor = Color(0xFF18314F);
  static const Color _gradientEndColor = Color(0xFF3B5270);
  static const Color _successGreen = Color(0xFF10B981);

  const RaiserHomeTab({
    super.key,
    required this.raiserData,
    required this.investedAmount,
    this.initialCapital = 0.0,
    this.stocksSpendAmount = 0.0,
    this.providedStocksList = const [],
    required this.requestsList,
    required this.notificationsList,
    this.activeAssignments = const [],
    this.hogsList = const [],
    this.reportsList = const [],
    required this.errorMessage,
    required this.onRefresh,
    required this.onNavigateToTab,
    required this.onMarkNotificationAsRead,
    required this.onMarkAllRead,
    required this.onUpdateLifecycleStage,
  });

  String _formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final raiserName = raiserData['name'] ?? strings.hogRaiserRole;

    // Active assignment & investment details
    final activeBatches = activeAssignments.where((a) => a['is_cycle_completed'] != true).toList();
    final hasActiveBatch = activeBatches.isNotEmpty;
    final hasInvestment = investedAmount > 0;
    final List<String> allBatchNames = [];
    for (var a in activeBatches) {
      String n = '';
      if (a['batches'] is Map) {
        n = (a['batches']['batch_name'] ?? a['batches']['name'] ?? '').toString();
      } else if (a['batches'] is List && (a['batches'] as List).isNotEmpty && (a['batches'] as List).first is Map) {
        n = ((a['batches'] as List).first['batch_name'] ?? '').toString();
      }
      if (n.isEmpty) n = (a['batch_name'] ?? '').toString();
      if (n.contains('(')) {
        final parts = n.split('(');
        if (parts.last.endsWith(')')) {
          n = parts.sublist(0, parts.length - 1).join('(').trim();
        }
      }
      if (n.isNotEmpty && !allBatchNames.contains(n)) {
        allBatchNames.add(n);
      }
    }
    final String activeBatchName = (hasActiveBatch && allBatchNames.isNotEmpty)
        ? allBatchNames.join(strings.isFilipino ? ' at ' : ' and ')
        : '';

    // Pig Type and Lifecycle stage
    final String rawPigType = (raiserData['pig_type'] ?? '').toString().trim();
    final String pigType = (rawPigType.isNotEmpty && rawPigType != 'N/A' && rawPigType != 'None')
        ? rawPigType
        : (hasActiveBatch ? (activeAssignments[0]['hog_types']?['type_name'] ?? 'Fattening').toString() : 'Fattening');

    final String rawStage = (raiserData['lifecycle_stage'] ?? '').toString().trim();
    final String activeStage = (rawStage.isNotEmpty && rawStage != 'N/A' && rawStage != 'None')
        ? rawStage
        : (hasActiveBatch ? (activeAssignments[0]['lifecycle_stage'] ?? 'Booster').toString() : 'Booster');

    final String displayStage = hasInvestment ? activeStage : strings.unassigned;
    final String displayPigType = hasInvestment ? pigType : strings.unassigned;

    // Metrics computation
    final int totalHogs = hogsList.isNotEmpty
        ? hogsList.length
        : (hasActiveBatch ? (activeAssignments[0]['assigned_heads'] as num? ?? 0).toInt() : 0);

    final int sickHogsCount = hogsList.where((h) {
      final s = (h['health_status'] ?? '').toString().toLowerCase();
      return s == 'sick' || s == 'under observation' || s == 'quarantine';
    }).length;

    final int healthyHogsCount = (totalHogs - sickHogsCount).clamp(0, 9999);

    final int pendingRequestsCount = requestsList.where((r) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      return s == 'pending' || s == 'for_approval';
    }).length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _brandColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Optional Debug Message
            if (errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'DATABASE NOTICE:\n$errorMessage',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.red[800],
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],

            // ==================== TOP GREETING & NOTIFICATION ====================
            RaiserHeaderBar(
              raiserName: raiserName,
              notificationsList: notificationsList,
              onRefreshNotifications: onRefresh,
              onMarkNotificationAsRead: onMarkNotificationAsRead,
              onMarkAllRead: onMarkAllRead,
              onNavigateToTab: onNavigateToTab,
            ),
            const SizedBox(height: 20),

            // ==================== INVESTED AMOUNT HERO CARD ====================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_brandColor, _gradientEndColor],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _brandColor.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Batch Pill & Cycle Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          (hasActiveBatch && activeBatchName.isNotEmpty)
                              ? activeBatchName.toUpperCase()
                              : (strings.isFilipino ? 'WALANG BATCH' : 'NO BATCH ASSIGNED'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: (hasActiveBatch && hasInvestment) ? _successGreen : const Color(0xFFFFA566),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (hasActiveBatch && hasInvestment)
                                ? (strings.isFilipino ? 'Aktibong Siklo' : 'Active Cycle')
                                : (hasActiveBatch ? (strings.isFilipino ? 'Nakabinbing Puhunan' : 'Pending Investment') : (strings.isFilipino ? 'Nakabinbing Batch' : 'Pending Batch')),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Middle Main Investment Row
                  InkWell(
                    onTap: () => _showInvestmentBreakdownModal(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      strings.totalCurrentInvestment,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.85),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 12),
                                          const SizedBox(width: 3),
                                          Text(
                                            strings.viewBreakdown,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatCurrency(investedAmount),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (initialCapital > 0 || stocksSpendAmount > 0) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.account_balance_wallet_outlined, size: 12, color: Colors.white.withValues(alpha: 0.9)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${strings.initialCapital}: ${_formatCurrency(initialCapital)}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          '  •  ',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                                        ),
                                        const Icon(Icons.remove_circle_outline_rounded, size: 12, color: Color(0xFFFCA5A5)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${strings.deductedLabel}: -${_formatCurrency(stocksSpendAmount)}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFFCA5A5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => onNavigateToTab(1),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.add, color: _brandColor, size: 24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bottom Info Chips Row
                  Container(
                    padding: const EdgeInsets.only(top: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildHeroMiniBadge(
                            icon: Icons.pets_rounded,
                            label: '$totalHogs ${strings.hogs}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildHeroMiniBadge(
                            icon: Icons.restaurant_rounded,
                            label: '${strings.isFilipino ? "Yugto" : "Stage"}: $displayStage',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildHeroMiniBadge(
                            icon: Icons.assignment_outlined,
                            label: '$pendingRequestsCount ${strings.filterPending}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ==================== 4 METRIC STATS OVERVIEW ====================
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    title: strings.totalHogs,
                    value: '$totalHogs ${strings.hogs}',
                    subtitle: hasActiveBatch ? activeBatchName : strings.noActiveBatchNotice,
                    icon: Icons.pets_rounded,
                    accentColor: const Color(0xFFEF5B6C),
                    bgColor: const Color(0xFFFEF2F2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    title: strings.isFilipino ? 'Kalusugan ng Baboy' : 'Hog Health',
                    value: totalHogs > 0
                        ? (sickHogsCount == 0 ? (strings.isFilipino ? '100% Maayos' : '100% Good') : '$healthyHogsCount/$totalHogs')
                        : (strings.isFilipino ? '100% Maayos' : '100% Good'),
                    subtitle: sickHogsCount == 0 ? (strings.isFilipino ? 'Lahat malusog' : 'All healthy') : '$sickHogsCount ${strings.isFilipino ? 'nangangailangan ng lunas' : 'need care'}',
                    icon: Icons.health_and_safety_rounded,
                    accentColor: sickHogsCount == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    bgColor: sickHogsCount == 0 ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    title: strings.stockRequestsTitle,
                    value: '$pendingRequestsCount ${strings.filterPending}',
                    subtitle: strings.isFilipino ? 'Naghihintay ng apruba ng Admin' : 'Awaiting Admin approval',
                    icon: Icons.assignment_rounded,
                    accentColor: const Color(0xFFF59E0B),
                    bgColor: const Color(0xFFFFFBEB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    title: strings.currentFeedsStage,
                    value: displayStage,
                    subtitle: hasInvestment ? displayPigType : (strings.isFilipino ? 'Walang aktibong puhunan' : 'No active investment'),
                    icon: Icons.restaurant_rounded,
                    accentColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ==================== QUICK ACTIONS ====================
            Text(
              strings.isFilipino ? 'Mabilisang Aksyon' : 'Quick Actions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : _brandColor,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                _buildQuickActionTile(
                  context: context,
                  icon: Icons.post_add_rounded,
                  label: strings.request,
                  color: const Color(0xFF2563EB),
                  onTap: () => onNavigateToTab(1),
                ),
                const SizedBox(width: 10),
                _buildQuickActionTile(
                  context: context,
                  icon: Icons.medical_services_rounded,
                  label: strings.isFilipino ? 'Mag-ulat' : 'Report',
                  color: const Color(0xFFEF4444),
                  onTap: () => onNavigateToTab(2),
                ),
                const SizedBox(width: 10),
                _buildQuickActionTile(
                  context: context,
                  icon: Icons.pets_rounded,
                  label: strings.myHogsTitle,
                  color: const Color(0xFF10B981),
                  onTap: () => onNavigateToTab(2),
                ),
                const SizedBox(width: 10),
                _buildQuickActionTile(
                  context: context,
                  icon: Icons.receipt_long_rounded,
                  label: strings.requestHistory,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => onNavigateToTab(1),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ==================== FEEDS STAGES (CONDITIONAL ON ACTIVE BATCH) ====================
            if (hasActiveBatch) ...[
              Builder(
                builder: (context) {
                  final bool isDualType = (pigType.toLowerCase().contains('sow') || pigType.toLowerCase().contains('breed')) &&
                      pigType.toLowerCase().contains('fatten');

                  if (isDualType) {
                    return Column(
                      children: [
                        _buildFeedsCard(
                          context: context,
                          title: strings.isFilipino ? 'Mga Stage ng Pakain (Inahing Baboy)' : 'Feeds Stages (Sow / Breeding)',
                          badgeText: strings.isFilipino ? 'Inahing Baboy' : 'Sow / Breeding',
                          stages: const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation'],
                          activeStage: activeStage,
                          hasInvestment: hasInvestment,
                        ),
                        const SizedBox(height: 16),
                        _buildFeedsCard(
                          context: context,
                          title: strings.isFilipino ? 'Mga Stage ng Pakain (Pangkaraniwan / Fattening)' : 'Feeds Stages (Fattening)',
                          badgeText: strings.isFilipino ? 'Pangkaraniwan' : 'Fattening',
                          stages: const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'],
                          activeStage: activeStage,
                          hasInvestment: hasInvestment,
                        ),
                      ],
                    );
                  }

                  final bool isSow = pigType.toLowerCase().contains('sow') || pigType.toLowerCase().contains('breed');
                  return _buildFeedsCard(
                    context: context,
                    title: strings.isFilipino ? 'Mga Stage ng Pakain' : 'Feeds Stages',
                    badgeText: hasInvestment ? (isSow ? (strings.isFilipino ? 'Inahing Baboy' : 'Sow') : (strings.isFilipino ? 'Pangkaraniwan' : 'Fattening')) : strings.unassigned,
                    stages: isSow
                        ? const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation']
                        : const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'],
                    activeStage: displayStage,
                    hasInvestment: hasInvestment,
                  );
                },
              ),
              const SizedBox(height: 28),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.assignment_late_outlined, size: 36, color: Color(0xffa0aec0)),
                      const SizedBox(height: 10),
                      Text(
                        strings.isFilipino ? 'Walang nakatalagang feeds stage.' : 'No feeds stage assigned.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ==================== RECENT ACTIVITIES ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  strings.recentStockRequests,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : _brandColor,
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigateToTab(1),
                  child: Text(
                    strings.viewAll,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : _brandColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            requestsList.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder),
                    ),
                    child: Center(
                      child: Text(
                        strings.noStockRequestsYet,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: requestsList.take(3).map((req) {
                      final dateStr = _formatDate(req['request_date'] ?? '');
                      final status = (req['status'] ?? 'Pending').toString();
                      final rawBatchName = (req['assignments']?['batches']?['batch_name'] ?? '').toString().trim();
                      String batchName = rawBatchName;
                      if (rawBatchName.contains('(')) {
                        final parts = rawBatchName.split('(');
                        if (parts.last.endsWith(')')) {
                          batchName = parts.sublist(0, parts.length - 1).join('(').trim();
                        }
                      }
                      final feedType = (req['feed_type'] ?? '').toString().trim();
                      final category = (req['category'] ?? '').toString().trim();
                      final productName = feedType.isNotEmpty
                          ? feedType
                          : (category.isNotEmpty ? category : strings.request);
                      final qty = (req['quantity'] as num?)?.toInt();
                      final itemLabel = qty != null ? '$qty × $productName' : productName;

                      return _buildActivityItem(
                        context: context,
                        icon: Icons.assignment_outlined,
                        title: batchName.isNotEmpty ? '$itemLabel ($batchName)' : itemLabel,
                        subtitle: '$dateStr • ${strings.isFilipino ? "Katayuan" : "Status"}: ${strings.formatStatus(status).toUpperCase()}',
                        isCompleted: status.toLowerCase() == 'approved',
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildHeroMiniBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.5, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final textColor = isDark ? Colors.white : _brandColor;
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? accentColor.withValues(alpha: 0.15) : bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: mutedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final textColor = isDark ? Colors.white : _brandColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
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

  Widget _buildFeedsCard({
    required BuildContext context,
    required String title,
    required String badgeText,
    required List<String> stages,
    required String activeStage,
    required bool hasInvestment,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final textColor = isDark ? Colors.white : _brandColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2D42) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.4) : const Color(0xFFDBEAFE)),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTimeline(context, stages, activeStage, hasInvestment),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, List<String> stages, String activeStage, bool hasInvestment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int activeIndex = hasInvestment
        ? stages.indexWhere((s) => s.toLowerCase() == activeStage.toLowerCase())
        : -1;
    if (hasInvestment && activeIndex == -1) {
      activeIndex = 0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final stepWidth = totalWidth / stages.length;

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            // Connecting line
            Positioned(
              top: 16,
              left: stepWidth / 2,
              right: stepWidth / 2,
              child: Row(
                children: List.generate(stages.length - 1, (index) {
                  final isPassed = hasInvestment && index < activeIndex;
                  return Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: isPassed ? _successGreen : (isDark ? const Color(0xFF334A66) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Nodes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(stages.length, (index) {
                final isPassed = hasInvestment && index < activeIndex;
                final isActive = hasInvestment && index == activeIndex;
                final isFuture = !hasInvestment || index > activeIndex;

                Color circleColor;
                Widget iconWidget;
                BoxBorder? nodeBorder;

                if (isPassed) {
                  circleColor = _successGreen;
                  iconWidget = const Icon(Icons.check_rounded, size: 16, color: Colors.white);
                } else if (isActive) {
                  circleColor = isDark ? Colors.white : _brandColor;
                  iconWidget = Icon(
                    Icons.priority_high_rounded,
                    size: 18,
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  );
                } else {
                  circleColor = isDark ? const Color(0xFF1E2D42) : const Color(0xFFF1F5F9);
                  nodeBorder = isDark ? Border.all(color: const Color(0xFF3B506D), width: 1.2) : null;
                  iconWidget = Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFFA0AEC0),
                  );
                }

                return GestureDetector(
                  onTap: () {
                    if (hasInvestment && isFuture) {
                      _showStageProgressionDialog(context, stages[index]);
                    }
                  },
                  child: SizedBox(
                    width: stepWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isActive ? 34 : 30,
                          height: isActive ? 34 : 30,
                          decoration: BoxDecoration(
                            color: circleColor,
                            shape: BoxShape.circle,
                            border: nodeBorder,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: (isDark ? Colors.white : _brandColor).withValues(alpha: isDark ? 0.35 : 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(child: iconWidget),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          stages[index],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: isActive ? FontWeight.w800 : (isPassed ? FontWeight.w700 : FontWeight.w600),
                            color: isActive
                                ? (isDark ? Colors.white : _brandColor)
                                : (isPassed ? _successGreen : (isDark ? const Color(0xFF94A3B8) : const Color(0xFFA0AEC0))),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCompleted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final textColor = isDark ? Colors.white : _brandColor;
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCompleted
                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                  : (isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInvestmentBreakdownModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF111C2E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF18263D) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF283A57) : const Color(0xFFE2E8F0);
    final primaryTextColor = isDark ? const Color(0xFFF1F5F9) : _brandColor;
    final mutedTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final strings = AppStrings.of(ctx);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grabber Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334A6E) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : _brandColor).withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded, color: isDark ? Colors.white : _brandColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.investmentBreakdownTitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                          Text(
                            strings.isFilipino ? 'Paunang Puhunan + Halaga ng Naipamahaging Stock' : 'Initial Capital + Distributed Stocks Value',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: mutedTextColor, size: 22),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // Content List
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Highlight Hero Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [_brandColor, _gradientEndColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _brandColor.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  strings.totalCurrentInvestment,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _successGreen.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    strings.activeStatus.toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF6EE7B7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatCurrency(investedAmount),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              strings.isFilipino
                                  ? 'Natitirang badyet o puhunan matapos ibawas ang mga naipamahaging feeds at gamot sa iyong batch.'
                                  : 'Remaining investment budget after deducting distributed feeds and medicines for your batch.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.75),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Two Summary Cards: Initial Capital & Deducted Supplies
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder, width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF3B82F6), size: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        strings.initialCapital,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: mutedTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatCurrency(initialCapital),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    strings.isFilipino ? 'Alokasyon ng admin' : 'Admin allocation',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: mutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder, width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444), size: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        strings.stockRequestsSpend,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: mutedTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    stocksSpendAmount > 0
                                        ? '-${_formatCurrency(stocksSpendAmount)}'
                                        : _formatCurrency(0.0),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: stocksSpendAmount > 0 ? const Color(0xFFEF4444) : mutedTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    strings.isFilipino ? 'Ibinawas sa badyet' : 'Deducted from budget',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: mutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Formula summary pill
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calculate_outlined, size: 16, color: mutedTextColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                strings.isFilipino
                                    ? '${_formatCurrency(initialCapital)} (Puhunan) - ${_formatCurrency(stocksSpendAmount)} (Bawas) = ${_formatCurrency(investedAmount)} (Natitira)'
                                    : '${_formatCurrency(initialCapital)} (Capital) - ${_formatCurrency(stocksSpendAmount)} (Deducted) = ${_formatCurrency(investedAmount)} (Remaining)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Section Title: Itemized History
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            strings.isFilipino ? 'Mga Naipamahaging Produkto at Pakain' : 'Distributed Products & Feeds',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : _brandColor).withValues(alpha: isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              strings.isFilipino ? '${providedStocksList.length} na item' : '${providedStocksList.length} items',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : _brandColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (providedStocksList.isEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 36, color: mutedTextColor.withValues(alpha: 0.5)),
                              const SizedBox(height: 8),
                              Text(
                                strings.isFilipino ? 'Wala Pang Naipapamahaging Supply' : 'No Feeds/Supplies Distributed Yet',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                strings.isFilipino
                                    ? 'Kapag naaprubahan ng admin ang iyong kahilingan sa stock, awtomatiko itong lalabas dito.'
                                    : 'Once admin approves your stock requests, they will automatically count and appear here.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: mutedTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        ...providedStocksList.map((item) {
                          final pName = item['product_name'] ?? 'Feeds';
                          final pCat = (item['category'] ?? 'Feeds').toString();
                          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                          final uPrice = (item['unit_price'] as num?)?.toDouble() ?? 1650.0;
                          final total = (item['total_amount'] as num?)?.toDouble() ?? (qty * uPrice);
                          final rawDate = (item['request_date'] ?? item['decision_date'])?.toString();
                          final formattedDate = _formatDate(rawDate ?? '');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder, width: 1.1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.white : _brandColor).withValues(alpha: isDark ? 0.15 : 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    pCat.toLowerCase().contains('med') || pCat.toLowerCase().contains('vaccine') || pCat.toLowerCase().contains('vitamin')
                                        ? Icons.medical_services_outlined
                                        : Icons.grain_rounded,
                                    color: isDark ? Colors.white : _brandColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pName,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '$qty ${qty == 1 ? (strings.isFilipino ? "piraso/sako" : "unit/sack") : (strings.isFilipino ? "mga piraso/sako" : "units/sacks")} • ${_formatCurrency(uPrice)}/${strings.isFilipino ? "bawat isa" : "ea"} • $formattedDate',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          color: mutedTextColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '-${_formatCurrency(total)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        strings.isFilipino ? 'IBINAWAS' : 'DEDUCTED',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStageProgressionDialog(BuildContext context, String targetStage) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            strings.stageProgressionTitle,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? Colors.white : _brandColor,
            ),
          ),
          content: Text(
            strings.advanceStagePrompt(targetStage),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      strings.cancel,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onUpdateLifecycleStage(targetStage);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : _brandColor,
                      foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      strings.confirm,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
