import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/app_strings.dart';
import '../../../widgets/piggy_toast.dart';
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
  final Function(String targetStage, [dynamic targetHogId]) onUpdateLifecycleStage;

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

  static int _compareBatchTypes(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aType = (a['hog_types'] is Map
            ? a['hog_types']['type_name']
            : (a['hog_types'] is List && (a['hog_types'] as List).isNotEmpty
                ? (a['hog_types'] as List).first['type_name']
                : null)) ??
        a['pig_type'] ??
        '';
    final bType = (b['hog_types'] is Map
            ? b['hog_types']['type_name']
            : (b['hog_types'] is List && (b['hog_types'] as List).isNotEmpty
                ? (b['hog_types'] as List).first['type_name']
                : null)) ??
        b['pig_type'] ??
        '';

    int getPriority(dynamic t) {
      final s = t.toString().toLowerCase();
      if (s.contains('fatten')) return 0;
      if (s.contains('sow') || s.contains('breed')) return 1;
      return 2;
    }

    final aPrio = getPriority(aType);
    final bPrio = getPriority(bType);
    if (aPrio != bPrio) return aPrio.compareTo(bPrio);

    final aId = a['assignment_id'] is num ? (a['assignment_id'] as num).toInt() : 0;
    final bId = b['assignment_id'] is num ? (b['assignment_id'] as num).toInt() : 0;
    return aId.compareTo(bId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final raiserName = raiserData['name'] ?? strings.hogRaiserRole;

    // Active and Completed Batches Partitioning (Fattening ALWAYS first)
    final activeBatches = activeAssignments.where((a) => a['is_cycle_completed'] != true).toList()
      ..sort(_compareBatchTypes);
    final completedBatches = activeAssignments.where((a) => a['is_cycle_completed'] == true).toList()
      ..sort(_compareBatchTypes);
    final hasInvestment = initialCapital > 0 || investedAmount > 0;

    // Resilient fallback: Only reactivate if the batch's hogs are NOT all at final stage
    if (activeBatches.isEmpty && activeAssignments.isNotEmpty) {
      final fallback = activeAssignments.first;
      final fallbackDone = fallback['is_cycle_completed'] == true;
      if (!fallbackDone && (hogsList.isNotEmpty || hasInvestment)) {
        activeBatches.add(fallback);
        completedBatches.remove(fallback);
      }
    }

    final hasActiveBatch = activeBatches.isNotEmpty;
    final hasCompletedBatch = completedBatches.isNotEmpty;
    final double totalPartnerCapital = (hasActiveBatch ? activeBatches : activeAssignments).fold<double>(
      0.0,
      (sum, a) => sum + ((a['partner_capital'] as num?)?.toDouble() ?? 0.0),
    );

    final List<String> allBatchNames = [];
    final targetBatches = hasActiveBatch ? activeBatches : <Map<String, dynamic>>[];
    for (var a in targetBatches) {
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
    final String pigType = hasActiveBatch
        ? ((rawPigType.isNotEmpty && rawPigType != 'N/A' && rawPigType != 'None')
            ? rawPigType
            : (activeBatches[0]['hog_types']?['type_name'] ?? 'Fattening').toString())
        : (strings.isFilipino ? 'Walang Naka-assign' : 'Unassigned');

    final String rawStage = (raiserData['lifecycle_stage'] ?? '').toString().trim();
    String activeStage = hasActiveBatch
        ? ((rawStage.isNotEmpty && rawStage != 'N/A' && rawStage != 'None' && rawStage.toLowerCase() != 'lactation')
            ? rawStage
            : (activeBatches[0]['lifecycle_stage'] ?? 'Booster').toString())
        : (strings.isFilipino ? 'Walang Siklo' : 'No Cycle');

    // Scope hogs list to active batches only
    final activeAssignIds = activeBatches.map((a) => (a['assignment_id'] ?? a['id'])?.toString()).where((id) => id != null).toSet();
    final activeHogsList = hogsList.where((h) => activeAssignIds.contains(h['assignment_id']?.toString())).toList();

    if (hasActiveBatch && activeHogsList.isNotEmpty) {
      final isBr = pigType.toLowerCase() == 'sow' || pigType.toLowerCase().contains('breed');
      activeStage = _getHogCurrentStage(activeHogsList[0], isBr, activeStage);
    } else if (hasActiveBatch && hogsList.isNotEmpty) {
      // Fallback if hogs couldn't be strictly partitioned by assignment_id
      final isBr = pigType.toLowerCase() == 'sow' || pigType.toLowerCase().contains('breed');
      activeStage = _getHogCurrentStage(hogsList[0], isBr, activeStage);
    }

    final bool isBatchCycleCompleted = activeAssignments.isNotEmpty && !hasActiveBatch;

    final bool isInvestmentDepleted = hasActiveBatch && investedAmount <= 0 && (initialCapital > 0 || stocksSpendAmount > 0);

    String? fatteningStage;
    String? sowStage;
    int fatteningCount = 0;
    int sowCount = 0;
    final targetHogsForStage = activeHogsList.isNotEmpty ? activeHogsList : hogsList;
    if (hasActiveBatch) {
      for (var h in targetHogsForStage) {
        final hType = _getHogPigType(h, pigType);
        final isBreed = hType.toLowerCase().contains('sow') || hType.toLowerCase().contains('breed');
        final st = _getHogCurrentStage(h, isBreed, activeStage);
        if (isBreed) {
          sowCount++;
          sowStage ??= st;
        } else {
          fatteningCount++;
          fatteningStage ??= st;
        }
      }
      if (fatteningCount == 0 && sowCount == 0 && activeAssignments.isNotEmpty) {
        for (var a in activeAssignments) {
          final t = (a['hog_types']?['type_name'] ?? a['pig_type'] ?? '').toString().toLowerCase();
          final heads = (a['assigned_heads'] as num?)?.toInt() ?? 0;
          if (t.contains('sow') || t.contains('breed')) {
            sowCount += heads;
          } else {
            fatteningCount += heads;
          }
        }
      }
    }
    final bool hasBothTypes = hasActiveBatch && ((fatteningCount > 0 && sowCount > 0) || (fatteningStage != null && sowStage != null));

    final String displayStage = hasActiveBatch ? activeStage : (strings.isFilipino ? 'Walang Aktibong Siklo' : 'No Active Cycle');
    final String displayPigType = hasActiveBatch ? pigType : (strings.isFilipino ? 'Walang Naka-assign' : 'Unassigned');

    // Metrics computation
    final int totalHogs = hasActiveBatch
        ? (activeHogsList.isNotEmpty
            ? activeHogsList.length
            : (hogsList.isNotEmpty
                ? hogsList.length
                : (activeAssignments[0]['assigned_heads'] as num? ?? 0).toInt()))
        : 0;

    final int sickHogsCount = hogsList.where((h) {
      final s = (h['health_status'] ?? '').toString().trim().toLowerCase();
      return s == 'sick' ||
          s == 'under observation' ||
          s == 'quarantine' ||
          s == 'fever' ||
          s == 'diarrhea' ||
          s == 'food poisoning' ||
          s == 'injury' ||
          s == 'injured';
    }).length;

    final int healthyHogsCount = (totalHogs - sickHogsCount).clamp(0, totalHogs);
    final double healthPercent = totalHogs > 0 ? (healthyHogsCount / totalHogs * 100) : 0.0;

    final int pendingRequestsCount = requestsList.where((r) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      return s == 'pending' || s == 'for_approval';
    }).length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _brandColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 108.0),
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
                              : (hasCompletedBatch
                                  ? (strings.isFilipino ? 'SIKLO NATAPOS' : 'CYCLE COMPLETED')
                                  : (strings.isFilipino ? 'WALANG BATCH' : 'NO BATCH ASSIGNED')),
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
                              color: (isBatchCycleCompleted || (!hasActiveBatch && hasCompletedBatch))
                                  ? const Color(0xFF38BDF8)
                                  : (isInvestmentDepleted
                                      ? const Color(0xFFF87171)
                                      : ((hasActiveBatch && hasInvestment) ? _successGreen : const Color(0xFFFFA566))),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (isBatchCycleCompleted || (!hasActiveBatch && hasCompletedBatch))
                                ? (strings.isFilipino ? 'Tapos na ang Siklo' : 'Cycle Completed')
                                : (isInvestmentDepleted
                                    ? (strings.isFilipino ? 'Naubos ang Puhunan' : 'Depleted Budget')
                                    : ((hasActiveBatch && hasInvestment)
                                        ? (strings.isFilipino ? 'Aktibong Siklo' : 'Active Cycle')
                                        : (hasActiveBatch ? (strings.isFilipino ? 'Nakabinbing Puhunan' : 'Pending Investment') : (strings.isFilipino ? 'Nakabinbing Batch' : 'Pending Batch')))),
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
                                      stocksSpendAmount > 0
                                          ? strings.remainingBudget.toUpperCase()
                                          : strings.totalCurrentInvestment,
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
                                const SizedBox(height: 6),                                 Text(
                                  (isBatchCycleCompleted || !hasActiveBatch)
                                      ? _formatCurrency(0.0)
                                      : _formatCurrency(investedAmount),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (isBatchCycleCompleted || (!hasActiveBatch && hasCompletedBatch)) ...[
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
                                        const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF34D399)),
                                        const SizedBox(width: 5),
                                        Text(
                                          strings.isFilipino
                                              ? 'Siklo Natapos • Naka-settle na ang Puhunan'
                                              : 'Cycle Concluded • Capital Settled',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (initialCapital > 0 || stocksSpendAmount > 0) ...[
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
                                        if (totalPartnerCapital > 0) ...[
                                          Text(
                                            '  •  ',
                                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                                          ),
                                          const Icon(Icons.handshake_rounded, size: 12, color: Color(0xFF6EE7B7)),
                                          const SizedBox(width: 3),
                                          Text(
                                            '+${_formatCurrency(totalPartnerCapital)} Partner',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF6EE7B7),
                                            ),
                                          ),
                                        ],
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
                                if (isBatchCycleCompleted || isInvestmentDepleted) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isBatchCycleCompleted
                                              ? Icons.task_alt_rounded
                                              : Icons.info_outline_rounded,
                                          color: isBatchCycleCompleted
                                              ? const Color(0xFF34D399)
                                              : const Color(0xFFFDE68A),
                                          size: 15,
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            isBatchCycleCompleted
                                                ? (strings.isFilipino
                                                    ? 'Nakatapos na ang siklo ng batch. Maghintay sa susunod na batch mula sa Admin.'
                                                    : 'Batch cycle completed. Awaiting next batch assignment from Farm Admin.')
                                                : (strings.isFilipino
                                                    ? 'Paalala: Naubos na ang natitirang puhunan (₱0). Makipag-ugnayan sa Farm Admin.'
                                                    : 'Notice: Investment budget depleted (₱0). Coordinate with Farm Admin.'),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white.withValues(alpha: 0.95),
                                              height: 1.25,
                                            ),
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
                            onTap: () {
                              if (isBatchCycleCompleted) {
                                PiggyToast.showInfo(
                                  context,
                                  strings.isFilipino
                                      ? 'Tapos na ang siklo ng batch na ito. Maghintay sa susunod na batch bago makahiling muli ng supply.'
                                      : 'This batch cycle is completed. Please wait for your next batch to request supplies.',
                                  title: strings.isFilipino ? 'Tapos na ang Siklo' : 'Cycle Completed',
                                );
                              } else {
                                onNavigateToTab(1);
                              }
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  isBatchCycleCompleted ? Icons.check_rounded : Icons.add,
                                  color: isBatchCycleCompleted ? const Color(0xFF10B981) : _brandColor,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ==================== 4 METRIC STATS OVERVIEW ====================
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context: context,
                      title: strings.totalHogs,
                      value: '$totalHogs ${strings.hogs}',
                      subtitle: hasBothTypes
                          ? (strings.isFilipino
                              ? '$fatteningCount Pangkaraniwan • $sowCount Inahin'
                              : '$fatteningCount Fattening • $sowCount Sow')
                          : (hasActiveBatch ? activeBatchName : strings.noActiveBatchNotice),
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
                          ? (sickHogsCount == 0
                              ? '${healthPercent.toStringAsFixed(0)}% ${strings.isFilipino ? 'Maayos' : 'Good'}'
                              : '${healthPercent.toStringAsFixed(healthPercent.truncateToDouble() == healthPercent ? 0 : 1)}% ${strings.isFilipino ? 'Maayos' : 'Good'}')
                          : (strings.isFilipino ? 'Walang Alaga' : 'No Hogs'),
                      subtitle: totalHogs > 0
                          ? (sickHogsCount == 0
                              ? (strings.isFilipino ? 'Lahat ng $totalHogs ay malusog' : 'All $totalHogs healthy')
                              : '$sickHogsCount ${strings.isFilipino ? 'nangangailangan ng lunas' : 'need care'}')
                          : (strings.isFilipino ? 'Walang aktibong alaga' : 'No active hogs'),
                      icon: totalHogs > 0
                          ? (sickHogsCount == 0 ? Icons.health_and_safety_rounded : Icons.healing_rounded)
                          : Icons.health_and_safety_outlined,
                      accentColor: totalHogs > 0
                          ? (sickHogsCount == 0
                              ? const Color(0xFF10B981)
                              : (healthPercent >= 75 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)))
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      bgColor: totalHogs > 0
                          ? (sickHogsCount == 0
                              ? const Color(0xFFECFDF5)
                              : (healthPercent >= 75 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)))
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      customValueWidget: hasActiveBatch
                          ? (hasBothTypes
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      strings.isFilipino
                                          ? '$fatteningCount Pangkaraniwan - ${fatteningStage ?? "Booster"}'
                                          : '$fatteningCount Fattening - ${fatteningStage ?? "Booster"}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : _brandColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      strings.isFilipino
                                          ? '$sowCount Inahing Baboy - ${sowStage ?? "Booster"}'
                                          : '$sowCount Sow / Breeding - ${sowStage ?? "Booster"}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : _brandColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                )
                              : Text(
                                  pigType.toLowerCase().contains('sow') || pigType.toLowerCase().contains('breed')
                                      ? (strings.isFilipino ? '$sowCount Inahing Baboy - $displayStage' : '$sowCount Sow / Breeding - $displayStage')
                                      : (strings.isFilipino ? '$fatteningCount Pangkaraniwan - $displayStage' : '$fatteningCount Fattening - $displayStage'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : _brandColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ))
                          : Text(
                              strings.isFilipino ? 'Walang Aktibong Siklo' : 'No Active Cycle',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : _brandColor,
                              ),
                            ),
                      subtitle: hasActiveBatch
                          ? (displayPigType.toLowerCase().contains('sow') && !displayPigType.toLowerCase().contains('fatten')
                              ? 'Sow / Breeding'
                              : (displayPigType.toLowerCase().contains('sow')
                                  ? 'Sow / Breeding & Fattening'
                                  : displayPigType))
                          : (strings.isFilipino ? 'Kailangan ng aktibong batch' : 'Active batch required'),
                      icon: Icons.restaurant_rounded,
                      accentColor: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                    ),
                  ),
                ],
              ),
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

            // ==================== HOGS LIFECYCLE PROGRESS (EACH ASSIGNED HOG) ====================
            if (hasActiveBatch) ...[
              _buildHogsLifecycleProgressSection(
                context: context,
                strings: strings,
                isDark: isDark,
                hasInvestment: hasInvestment,
                targetHogsForStage: targetHogsForStage,
                pigType: pigType,
                activeStage: activeStage,
              ),
              const SizedBox(height: 24),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (hasCompletedBatch ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasCompletedBatch ? Icons.check_circle_outline_rounded : Icons.inventory_2_outlined,
                          size: 32,
                          color: hasCompletedBatch ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        hasCompletedBatch
                            ? (strings.isFilipino ? 'Tapos na ang Siklo ng Alaga' : 'Hog Raising Cycle Concluded')
                            : (strings.isFilipino ? 'Walang Aktibong Batch ng Baboy' : 'No Active Hog Batch'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : _brandColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasCompletedBatch
                            ? (strings.isFilipino
                                ? 'Matagumpay na natapos ang iyong nakaraang batch. Makipag-ugnayan sa Farm Admin upang mabigyan ng bagong batch ng alaga.'
                                : 'Your previous batch concluded successfully. Please contact Farm Admin to assign your new raising batch.')
                            : (strings.isFilipino
                                ? 'Walang aktibong batch na nakatalaga sa kasalukuyan. Makipag-ugnayan sa Farm Admin upang mabigyan ng alaga.'
                                : 'No active raising batch assigned yet. Please contact Farm Admin to get started.'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ==================== CONCLUDED / COMPLETED BATCHES (ARCHIVED & GRAYED OUT) ====================
            if (completedBatches.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    strings.isFilipino ? 'Mga Natapos na Siklo (Archived)' : 'Concluded Cycles (Archived)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (int cIdx = 0; cIdx < completedBatches.length; cIdx++) ...[
                _buildCompletedBatchCard(
                  context: context,
                  assignment: completedBatches[cIdx],
                  strings: strings,
                ),
                if (cIdx < completedBatches.length - 1) const SizedBox(height: 12),
              ],
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
                        title: itemLabel,
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

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    Widget? customValueWidget,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customValueWidget != null)
                customValueWidget
              else
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

  int _stageNameToId(String stage, bool isBreeding) {
    final s = stage.trim().toLowerCase();
    if (s == 'booster') return 1;
    if (s == 'pre-starter' || s == 'pre starter') return 2;
    if (s == 'starter') return 3;
    if (s == 'grower') return 4;
    if (s == 'finisher' || s == 'breeder') return 5;
    if (s == 'selling' || s == 'lactation') return 6;
    return 1;
  }

  String _stageIdToName(dynamic stageId, bool isBreeding, String fallback) {
    if (stageId == null) return fallback;
    final id = int.tryParse(stageId.toString());
    final fatteningStages = const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'];
    final sowStages = const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation'];
    final list = isBreeding ? sowStages : fatteningStages;
    if (id != null && id >= 1 && id <= list.length) {
      return list[id - 1];
    }
    final s = stageId.toString().trim();
    if (s.isNotEmpty && s != 'null' && s != 'N/A' && int.tryParse(s) == null) {
      return s;
    }
    return fallback;
  }

  String _getHogPigType(Map<String, dynamic> hog, String fallbackType) {
    final rawType = (hog['pig_type'] ?? hog['type_name'] ?? hog['type'] ?? '').toString().trim();
    if (rawType.isNotEmpty && rawType != 'null' && rawType != 'N/A' && rawType != 'None') {
      final l = rawType.toLowerCase();
      return (l == 'sow' || l.contains('breed')) ? 'Sow' : 'Fattening';
    }
    final fallbackLower = fallbackType.toLowerCase();
    return (fallbackLower == 'sow' || fallbackLower.contains('breed')) ? 'Sow' : 'Fattening';
  }

  String _getHogCurrentStage(Map<String, dynamic> hog, bool isBreeding, String fallbackStage) {
    final dbStage = hog['stage_id'] ?? hog['lifecycle_stage'] ?? hog['stage'];
    if (dbStage != null) {
      return _stageIdToName(dbStage, isBreeding, fallbackStage);
    }
    return fallbackStage;
  }

  Future<void> _notifyAdminFinalStageReached(String targetStage, [Map<String, dynamic>? hog]) async {
    final sLower = targetStage.trim().toLowerCase();
    final isFinal = sLower == 'selling' || sLower == 'lactation';
    if (!isFinal) return;

    final raiserName = (raiserData['name'] ?? 'Hog Raiser').toString().trim();
    final raiserId = raiserData['hog_raiser_id'] ?? raiserData['id'];

    String pigType = 'Fattening';
    if (hog != null) {
      pigType = _getHogPigType(hog, 'Fattening');
    } else if (activeAssignments.isNotEmpty) {
      final assign = activeAssignments.first;
      final ht = assign['hog_types'];
      if (ht is Map && ht['type_name'] != null) {
        pigType = ht['type_name'].toString();
      } else if (assign['pig_type'] != null) {
        pigType = assign['pig_type'].toString();
      } else if (raiserData['pig_type'] != null) {
        pigType = raiserData['pig_type'].toString();
      }
    }

    String batchName = 'Active Batch';
    dynamic batchId;
    if (activeAssignments.isNotEmpty) {
      final assign = activeAssignments.first;
      final b = assign['batches'];
      if (b is Map) {
        batchName = (b['batch_name'] ?? 'Batch #${b['batch_id']}').toString();
        batchId = b['batch_id'] ?? b['id'];
      } else {
        batchId = assign['batch_id'];
        batchName = 'Batch #$batchId';
      }
    }

    final notifTitle = pigType.toLowerCase().contains('sow')
        ? 'Batch Cycle Completed (Sow)'
        : 'Batch Ready for Selling / Harvest (Fattening)';

    final notifMessage = pigType.toLowerCase().contains('sow')
        ? '$raiserName has reached the final stage ($targetStage) for $batchName (Sow). Ready for batch cycle completion.'
        : '$raiserName has reached the final stage ($targetStage) for $batchName (Fattening). Ready for harvest & batch completion.';

    try {
      final existing = await Supabase.instance.client
          .from('admin_notifications')
          .select('notification_id')
          .eq('type', 'batch')
          .eq('is_read', false)
          .like('message', '%$raiserName%')
          .like('message', '%$targetStage%')
          .limit(1);

      if ((existing as List).isEmpty) {
        await Supabase.instance.client.from('admin_notifications').insert({
          'title': notifTitle,
          'message': notifMessage,
          'type': 'batch',
          'is_read': false,
          'metadata': {
            'hog_raiser_id': raiserId,
            'raiser_name': raiserName,
            'batch_id': batchId,
            'batch_name': batchName,
            'pig_type': pigType,
            'stage': targetStage,
            'timestamp': DateTime.now().toIso8601String(),
          },
        });
        debugPrint('Automatic milestone notification sent to admin: $batchName ($pigType - $targetStage)');
      }
    } catch (e) {
      debugPrint('Notice sending milestone notification to admin: $e');
    }
  }

  String _localizeStageName(String stage, bool isFilipino) {
    if (!isFilipino) return stage;
    final s = stage.trim().toLowerCase();
    if (s == 'selling') return 'Pangbenta';
    if (s == 'breeder') return 'Palahi';
    if (s == 'lactation') return 'Pagpapasuso';
    return stage;
  }

  Widget _buildHogsLifecycleProgressSection({
    required BuildContext context,
    required AppStrings strings,
    required bool isDark,
    required bool hasInvestment,
    required List<Map<String, dynamic>> targetHogsForStage,
    required String pigType,
    required String activeStage,
  }) {
    final textColor = isDark ? Colors.white : _brandColor;
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final cardBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;

    if (targetHogsForStage.isEmpty) {
      final isSow = pigType.toLowerCase().contains('sow') || pigType.toLowerCase().contains('breed');
      final stages = isSow
          ? const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation']
          : const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'];
      return _buildFeedsCard(
        context: context,
        title: strings.isFilipino ? 'Mga Stage ng Pakain' : 'Feeds Stages',
        badgeText: hasInvestment
            ? (isSow
                ? (strings.isFilipino ? 'Inahin' : 'Sow')
                : (strings.isFilipino ? 'Pangkaraniwan' : 'Fattening'))
            : strings.unassigned,
        stages: stages,
        activeStage: activeStage,
        hasInvestment: hasInvestment,
        isBatchCycleCompleted: false,
      );
    }

    // Sort hogs: Fattening first, Sow second, then by tag number / hog_id
    final sortedHogs = List<Map<String, dynamic>>.from(targetHogsForStage);
    sortedHogs.sort((a, b) {
      final aType = _getHogPigType(a, pigType).toLowerCase();
      final bType = _getHogPigType(b, pigType).toLowerCase();
      final aIsFat = aType.contains('fatten');
      final bIsFat = bType.contains('fatten');
      if (aIsFat && !bIsFat) return -1;
      if (!aIsFat && bIsFat) return 1;

      final aTagStr = (a['tag_number'] ?? '').toString().replaceAll('#', '').trim();
      final bTagStr = (b['tag_number'] ?? '').toString().replaceAll('#', '').trim();
      final aTagNum = int.tryParse(aTagStr);
      final bTagNum = int.tryParse(bTagStr);
      if (aTagNum != null && bTagNum != null) {
        return aTagNum.compareTo(bTagNum);
      }

      final aId = (a['hog_id'] as num?)?.toInt() ?? 0;
      final bId = (b['hog_id'] as num?)?.toInt() ?? 0;
      return aId.compareTo(bId);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.isFilipino ? 'Siklo ng mga Alagang Baboy' : 'Hogs Lifecycle Progress',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.isFilipino ? 'Yugto ng bawat alaga sa kasalukuyang batch' : 'Growth stage per assigned hog in active batch',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => onNavigateToTab(2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.isFilipino ? '${sortedHogs.length} na Baboy' : '${sortedHogs.length} Hogs',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // List of Individual Hog Cards
        ...sortedHogs.asMap().entries.map((entry) {
          final idx = entry.key;
          final h = entry.value;

          final rawTag = (h['tag_number'] ?? '').toString().trim();
          final tag = rawTag.isNotEmpty ? (rawTag.startsWith('#') ? rawTag : '#$rawTag') : '#${idx + 1}';

          final hType = _getHogPigType(h, pigType);
          final isBreed = hType.toLowerCase().contains('sow') || hType.toLowerCase().contains('breed');
          final typeLabel = strings.isFilipino
              ? (isBreed ? strings.sowBreedTag.toUpperCase() : strings.fatteningTag.toUpperCase())
              : (isBreed ? 'SOW / BREEDING' : 'FATTENING');

          final currentHogStage = _getHogCurrentStage(h, isBreed, activeStage);
          final stageNum = _stageNameToId(currentHogStage, isBreed);
          final isTerminal = stageNum >= 6 ||
              currentHogStage.trim().toLowerCase() == 'selling' ||
              currentHogStage.trim().toLowerCase() == 'lactation';

          final stages = isBreed
              ? const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation']
              : const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'];

          final hogTitle = strings.isFilipino ? 'Baboy $tag' : 'Hog $tag';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
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
                // Top Header Row (Clean, no icon, strict theme tokens)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hogTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            typeLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isTerminal)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess)
                              .withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess)
                                .withValues(alpha: isDark ? 0.5 : 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 11,
                              color: isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              strings.isFilipino ? 'TAPOS NA' : 'COMPLETE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _localizeStageName(currentHogStage, strings.isFilipino),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // Stepper Timeline
                _buildTimeline(
                  context,
                  stages,
                  currentHogStage,
                  hasInvestment,
                  hog: h,
                  hogName: hogTitle,
                  isCycleCompleted: isTerminal,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFeedsCard({
    required BuildContext context,
    required String title,
    required String badgeText,
    required List<String> stages,
    required String activeStage,
    required bool hasInvestment,
    bool isBatchCycleCompleted = false,
    Color? badgeTextColor,
    Color? badgeBgColor,
    Color? badgeBorderColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final textColor = isDark ? Colors.white : _brandColor;

    final defaultBadgeBg = isDark ? const Color(0xFF1E2D42) : const Color(0xFFEFF6FF);
    final defaultBadgeBorder = isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.4) : const Color(0xFFDBEAFE);
    final defaultBadgeText = isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB);

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
                  color: badgeBgColor ?? defaultBadgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeBorderColor ?? defaultBadgeBorder),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor ?? defaultBadgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTimeline(context, stages, activeStage, hasInvestment, isCycleCompleted: isBatchCycleCompleted),
        ],
      ),
    );
  }

  Widget _buildCompletedBatchCard({
    required BuildContext context,
    required Map<String, dynamic> assignment,
    required AppStrings strings,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final mutedColor = isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

    final rawName = (assignment['batches']?['batch_name'] ?? assignment['batch_name'] ?? 'Batch #${assignment['batch_id']}').toString();
    final rawType = (assignment['hog_types']?['type_name'] ?? assignment['pig_type'] ?? 'Hog').toString();
    final isSow = rawType.toLowerCase().contains('sow') || rawType.toLowerCase().contains('breed');
    final stages = isSow
        ? const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation']
        : const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rawName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      Text(
                        isSow ? (strings.isFilipino ? 'Inahing Baboy (Sow)' : 'Sow / Breeding') : (strings.isFilipino ? 'Pangkaraniwan (Fattening)' : 'Fattening'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14291F) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      strings.isFilipino ? 'Tapos na ang Siklo' : 'Cycle Concluded',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildTimeline(
            context,
            stages,
            stages.last,
            true,
            isCycleCompleted: true,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 14, color: mutedColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    strings.isFilipino
                        ? 'Naka-archive ang datos ng batch na ito. Hiwalay ang puhunan at ulat sa bago mong alaga.'
                        : 'Batch records archived. Investment and reports are isolated from your new batch.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: mutedColor,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    List<String> stages,
    String activeStage,
    bool hasInvestment, {
    Map<String, dynamic>? hog,
    String? hogName,
    bool isCycleCompleted = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int activeIndex = hasInvestment
        ? stages.indexWhere((s) => s.toLowerCase() == activeStage.toLowerCase())
        : -1;
    if (hasInvestment && activeIndex == -1) {
      activeIndex = 0;
    }

    final bool isCompletedAll = isCycleCompleted || (activeIndex >= 0 && activeIndex == stages.length - 1 && isCycleCompleted);

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
                  final isPassed = hasInvestment && (index < activeIndex || isCompletedAll);
                  return Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: isPassed
                            ? (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess)
                            : (isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder),
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
                final bool isPassed = hasInvestment && (isCompletedAll || index < activeIndex);
                final isActive = hasInvestment && !isCompletedAll && index == activeIndex;
                final isFuture = !isCompletedAll && index > activeIndex;

                Color circleColor;
                Widget iconWidget;
                BoxBorder? nodeBorder;

                final successColor = isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess;
                final activeColor = isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;

                if (isPassed) {
                  circleColor = successColor;
                  iconWidget = const Icon(Icons.check_rounded, size: 16, color: Colors.white);
                } else if (isActive) {
                  circleColor = activeColor;
                  iconWidget = Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDark ? PiggyTrunkTheme.ptBgDark : Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                } else {
                  circleColor = isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft;
                  nodeBorder = Border.all(
                    color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                    width: 1.2,
                  );
                  iconWidget = Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                  );
                }

                final strings = AppStrings.of(context);

                return GestureDetector(
                  onTap: () {
                    if (hasInvestment && isFuture) {
                      _showStageProgressionDialog(
                        context,
                        stages[index],
                        hog: hog,
                        hogName: hogName,
                      );
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
                          _localizeStageName(stages[index], strings.isFilipino),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: isActive ? FontWeight.w800 : (isPassed ? FontWeight.w700 : FontWeight.w600),
                            color: isActive
                                ? (isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptPrimary)
                                : (isPassed ? successColor : (isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted)),
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
        final bool hasActiveBatch = activeAssignments.any((a) => a['is_cycle_completed'] != true);
        final bool isConcludedCycle = activeAssignments.isNotEmpty && !hasActiveBatch;

        final completedBatches = activeAssignments.where((a) => a['is_cycle_completed'] == true).toList();
        final double histCapital = completedBatches.isNotEmpty
            ? completedBatches.fold(0.0, (sum, a) => sum + ((a['initial_capital'] as num?)?.toDouble() ?? 0.0))
            : initialCapital;
        final double histSpend = completedBatches.isNotEmpty
            ? completedBatches.fold(0.0, (sum, a) => sum + ((a['stocks_spend'] as num?)?.toDouble() ?? 0.0))
            : stocksSpendAmount;

        final double totalAdminCapital = activeAssignments.fold<double>(
          0.0,
          (sum, a) => sum + ((a['admin_capital'] as num?)?.toDouble() ?? (a['initial_capital'] as num?)?.toDouble() ?? 0.0),
        );
        final double totalPartnerCapital = activeAssignments.fold<double>(
          0.0,
          (sum, a) => sum + ((a['partner_capital'] as num?)?.toDouble() ?? 0.0),
        );

        final List<Map<String, dynamic>> allPartnerInvs = [];
        for (var a in activeAssignments) {
          if (a['partner_investments'] is List) {
            for (var pi in (a['partner_investments'] as List)) {
              if (pi is! Map) continue;
              final invId = (pi['investment_id'] ?? '').toString();
              final existingIdx = allPartnerInvs.indexWhere(
                (x) => (x['investment_id'] ?? '').toString() == invId,
              );
              if (existingIdx != -1) {
                final curAmt = (allPartnerInvs[existingIdx]['amount'] as num?)?.toDouble() ?? 0.0;
                final addAmt = (pi['amount'] as num?)?.toDouble() ?? 0.0;
                allPartnerInvs[existingIdx]['amount'] = curAmt + addAmt;
                final curTags = List<String>.from(allPartnerInvs[existingIdx]['target_hog_tags'] ?? []);
                final addTags = List<String>.from(pi['target_hog_tags'] ?? []);
                for (var t in addTags) {
                  if (!curTags.contains(t)) curTags.add(t);
                }
                allPartnerInvs[existingIdx]['target_hog_tags'] = curTags;
              } else {
                allPartnerInvs.add(Map<String, dynamic>.from(pi));
              }
            }
          }
        }
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
                                    color: isConcludedCycle
                                        ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
                                        : _successGreen.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isConcludedCycle
                                        ? (strings.isFilipino ? 'TAPOS / SETTLED' : 'CONCLUDED / SETTLED')
                                        : strings.activeStatus.toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isConcludedCycle
                                          ? const Color(0xFF7DD3FC)
                                          : const Color(0xFF6EE7B7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatCurrency(isConcludedCycle ? 0.0 : investedAmount),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isConcludedCycle
                                  ? (strings.isFilipino
                                      ? 'Ang iyong nakaraang siklo ng pag-aalaga ay matagumpay na natapos. Naka-settle na ang puhunan at kasalukuyang naghihintay ng bagong batch mula sa Admin.'
                                      : 'Your previous raising cycle concluded successfully. Capital is settled, awaiting next batch assignment from Admin.')
                                  : (strings.isFilipino
                                      ? 'Natitirang badyet o puhunan matapos ibawas ang mga naipamahaging feeds at gamot sa iyong batch.'
                                      : 'Remaining investment budget after deducting distributed feeds and medicines for your batch.'),
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
                                          isConcludedCycle
                                              ? (strings.isFilipino ? 'Nakaraang Puhunan' : 'Concluded Capital')
                                              : strings.initialCapital,
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
                                      _formatCurrency(isConcludedCycle ? histCapital : initialCapital),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                      isConcludedCycle
                                          ? (strings.isFilipino ? 'Alokasyon ng batch' : 'Batch allocation')
                                          : (totalPartnerCapital > 0
                                              ? (strings.isFilipino ? 'Alokasyon (Admin + Partner)' : 'Admin + Partner allocation')
                                              : (strings.isFilipino ? 'Alokasyon ng admin' : 'Admin allocation')),
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
                                      (isConcludedCycle ? histSpend : stocksSpendAmount) > 0
                                          ? '-${_formatCurrency(isConcludedCycle ? histSpend : stocksSpendAmount)}'
                                        : _formatCurrency(0.0),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                        color: (isConcludedCycle ? histSpend : stocksSpendAmount) > 0 ? const Color(0xFFEF4444) : mutedTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                      isConcludedCycle
                                          ? (strings.isFilipino ? 'Ibinawas sa nakaraang batch' : 'Deducted from concluded batch')
                                          : (strings.isFilipino ? 'Ibinawas sa badyet' : 'Deducted from budget'),
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
                                  isConcludedCycle
                                      ? (strings.isFilipino
                                          ? 'Nakaraang Siklo: ${_formatCurrency(histCapital)} (Puhunan) - ${_formatCurrency(histSpend)} (Nagamit) • Katayuan: Naka-settle na (₱0 Aktibo)'
                                          : 'Concluded Cycle: ${_formatCurrency(histCapital)} (Capital) - ${_formatCurrency(histSpend)} (Used) • Status: Concluded & Settled (₱0 Active)')
                                      : (strings.isFilipino
                                          ? '${_formatCurrency(initialCapital)} (Puhunan) - ${_formatCurrency(stocksSpendAmount)} (Bawas) = ${_formatCurrency(investedAmount)} (Natitira)'
                                          : '${_formatCurrency(initialCapital)} (Capital) - ${_formatCurrency(stocksSpendAmount)} (Deducted) = ${_formatCurrency(investedAmount)} (Remaining)'),
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

                      // Funding Sources breakdown (Admin Capital & Partner Investor attribution)
                      if (totalPartnerCapital > 0 || allPartnerInvs.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.pie_chart_outline_rounded, size: 16, color: primaryTextColor),
                            const SizedBox(width: 8),
                            Text(
                              strings.isFilipino ? 'Pinagmulan ng Pondo (Funding Sources)' : 'Funding Sources Breakdown',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder, width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Admin Allocation Row
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.business_rounded, size: 16, color: Color(0xFF3B82F6)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          strings.isFilipino ? 'Farm Admin Pondo' : 'Farm Admin Initial Capital',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                        Text(
                                          strings.isFilipino ? 'Panimulang badyet ng batch' : 'Base operating budget',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: mutedTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(totalAdminCapital),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                ],
                              ),

                              // Partner Investors Rows
                              for (var pi in allPartnerInvs) ...[
                                const SizedBox(height: 10),
                                Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.handshake_rounded, size: 16, color: Color(0xFF10B981)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${strings.isFilipino ? 'Partner Investor' : 'Partner Investor'}: ${pi['partner_name'] ?? 'Investor'}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                          if (pi['target_hog_tags'] != null && (pi['target_hog_tags'] as List).isNotEmpty)
                                            Text(
                                              'Funded ${(pi['target_hog_tags'] as List).join(', ')} • ${pi['target_pig_type'] ?? 'Hogs'}',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                color: mutedTextColor,
                                              ),
                                            )
                                          else
                                            Text(
                                              (pi['target_pig_type'] != null && pi['target_pig_type'].toString().isNotEmpty)
                                                  ? pi['target_pig_type'].toString()
                                                  : (strings.isFilipino ? 'Batch Pondo' : 'Batch Funding'),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                color: mutedTextColor,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _formatCurrency((pi['amount'] as num?)?.toDouble() ?? 0.0),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      if (activeAssignments.length > 1 || isConcludedCycle) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.layers_outlined, size: 16, color: primaryTextColor),
                            const SizedBox(width: 8),
                            Text(
                              strings.isFilipino ? 'Alokasyon sa Bawat Batch' : 'Per-Batch Allocation',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (final bAssign in (List<Map<String, dynamic>>.from(activeAssignments)..sort(_compareBatchTypes))) ...[
                          Builder(
                            builder: (context) {
                              final bDone = bAssign['is_cycle_completed'] == true;
                              final bRawName = (bAssign['batches']?['batch_name'] ?? bAssign['batch_name'] ?? 'Batch #${bAssign['batch_id']}').toString();
                              final bRawType = (bAssign['hog_types']?['type_name'] ?? bAssign['pig_type'] ?? 'Hog').toString();
                              final bCap = (bAssign['initial_capital'] as num?)?.toDouble() ?? 0.0;
                              final bSpend = (bAssign['stocks_spend'] as num?)?.toDouble() ?? 0.0;
                              final bRem = (bAssign['remaining_capital'] as num?)?.toDouble() ?? (bCap - bSpend).clamp(0.0, double.infinity);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: bDone
                                      ? (isDark ? const Color(0xFF142032) : const Color(0xFFF8FAFC))
                                      : cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: bDone
                                        ? (isDark ? Colors.white12 : const Color(0xFFE2E8F0))
                                        : cardBorder,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: bDone
                                            ? (isDark ? Colors.white10 : const Color(0xFFE2E8F0))
                                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        bDone ? Icons.check_circle_outline_rounded : Icons.pets_rounded,
                                        size: 18,
                                        color: bDone
                                            ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                            : (isDark ? const Color(0xFF38BDF8) : _brandColor),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$bRawName ($bRawType)',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: bDone ? mutedTextColor : primaryTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${strings.initialCapital}: ${_formatCurrency(bCap)} • ${strings.deductedLabel}: -${_formatCurrency(bSpend)}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10.5,
                                              color: mutedTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatCurrency(bRem),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: bDone ? mutedTextColor : (bRem > 0 ? _successGreen : const Color(0xFFEF4444)),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: bDone
                                                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                                                : const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            bDone
                                                ? (strings.isFilipino ? 'Tapos na' : 'Concluded')
                                                : (strings.isFilipino ? 'Aktibo' : 'Active'),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: bDone
                                                  ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                                  : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],

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

  void _showStageProgressionDialog(
    BuildContext context,
    String targetStage, {
    Map<String, dynamic>? hog,
    String? hogName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final displayName = hogName ?? (strings.isFilipino ? 'Alagang Baboy' : 'Hog');

    showDialog(
      context: context,
      builder: (dialogCtx) {
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
            hog != null
                ? (strings.isFilipino
                    ? 'Gusto mo bang ilipat ang $displayName sa yugtong "$targetStage"?'
                    : 'Advance $displayName to "$targetStage"?')
                : strings.advanceStagePrompt(targetStage),
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
                    onPressed: () => Navigator.pop(dialogCtx),
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
                    onPressed: () async {
                      Navigator.pop(dialogCtx);
                      if (hog != null && hog['hog_id'] != null) {
                        final hogId = hog['hog_id'];
                        final hogType = _getHogPigType(hog, 'Fattening');
                        final isBreeding = hogType.toLowerCase() == 'sow' ||
                            hogType.toLowerCase().contains('breed');
                        final stageNum = _stageNameToId(targetStage, isBreeding);

                        try {
                          final hogAssignId = hog['assignment_id']?.toString() ?? '';
                          final hogTag = (hog['tag_number'] ?? hogId.toString()).toString();
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final cacheKey = 'hog_stage_${hogAssignId}_$hogTag';
                            await prefs.setString(cacheKey, targetStage);
                            await prefs.setInt('${cacheKey}_id', stageNum);
                          } catch (_) {}

                          bool dbUpdated = false;
                          try {
                            final updateRes = await Supabase.instance.client
                                .from('hogs')
                                .update({
                                  'stage_id': stageNum,
                                  'last_updated': DateTime.now().toIso8601String(),
                                })
                                .eq('hog_id', hogId)
                                .select('hog_id');
                            if ((updateRes as List).isNotEmpty) {
                              dbUpdated = true;
                            }
                          } catch (e) {
                            debugPrint('Notice updating hog stage_id: $e');
                          }

                          if (!dbUpdated && hogAssignId.isNotEmpty) {
                            try {
                              final parsedAssignId = int.tryParse(hogAssignId);
                              if (parsedAssignId != null && parsedAssignId < 900000) {
                                final insertRes = await Supabase.instance.client
                                    .from('hogs')
                                    .insert({
                                      'assignment_id': parsedAssignId,
                                      'stage_id': stageNum,
                                      'status': 'active',
                                      'health_status': hog['health_status'] ?? 'Healthy',
                                      'last_updated': DateTime.now().toIso8601String(),
                                    })
                                    .select('hog_id')
                                    .maybeSingle();
                                if (insertRes != null && insertRes['hog_id'] != null) {
                                  hog['hog_id'] = insertRes['hog_id'];
                                }
                              }
                            } catch (e) {
                              debugPrint('Notice inserting real hog row into public.hogs: $e');
                            }
                          }

                          onUpdateLifecycleStage(targetStage, hogId);
                          await onRefresh();

                          if (stageNum >= 6 || targetStage.trim().toLowerCase() == 'selling' || targetStage.trim().toLowerCase() == 'lactation') {
                            _notifyAdminFinalStageReached(targetStage, hog);
                          }

                          if (context.mounted) {
                            PiggyToast.showSuccess(
                              context,
                              strings.isFilipino
                                  ? 'Nai-update ang $displayName sa $targetStage.'
                                  : 'Updated $displayName to $targetStage.',
                            );
                          }
                        } catch (e) {
                          debugPrint('Error updating hog stage: $e');
                          onUpdateLifecycleStage(targetStage, hogId);
                        }
                      } else {
                        onUpdateLifecycleStage(targetStage);
                        if (targetStage.trim().toLowerCase() == 'selling' || targetStage.trim().toLowerCase() == 'lactation') {
                          _notifyAdminFinalStageReached(targetStage, hog);
                        }
                      }
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
