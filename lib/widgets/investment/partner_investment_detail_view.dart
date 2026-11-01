import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class PartnerInvestmentDetailView extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onBack;
  final void Function(int id)? onApprove;
  final void Function(int id)? onReject;

  const PartnerInvestmentDetailView({
    super.key,
    required this.data,
    required this.onBack,
    this.onApprove,
    this.onReject,
  });

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(0);
    final formatted = parts.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₱$formatted';
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = months[date.month - 1];
    return '$monthName ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);

    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final mutedColor = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
    final innerBg = isDark ? const Color(0xFF182942) : const Color(0xFFF6F9FE);

    final p = data;
    final partnerName = (p['partner_name'] ?? 'Partner Investor').toString();
    final batchName = (p['batch_name'] ?? 'Batch Project').toString();
    final raiserName = (p['assigned_raiser'] ?? 'Assigned Raiser').toString();
    final double amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
    final status = (p['status'] ?? 'active').toString().toUpperCase();
    final isCompleted = status.toLowerCase() == 'completed';
    final isActive = status.toLowerCase() == 'active' || status.toLowerCase() == 'approved';
    final isPending = status.toLowerCase() == 'pending';
    final Color statusColor = isCompleted
        ? const Color(0xFF3B82F6)
        : (isActive ? PiggyTrunkTheme.ptSuccess : (isPending ? const Color(0xFFFFAA00) : const Color(0xFFFF758C)));

    final dateStr = (p['date_invested'] ?? p['created_at'] ?? '').toString();
    final dt = DateTime.tryParse(dateStr) ?? DateTime.now();

    final targetPigType = (p['target_pig_type'] ?? 'Entire Batch').toString();
    List<String> targetHogs = [];
    if (p['target_hog_tags'] is List) {
      targetHogs = List<String>.from(p['target_hog_tags'].map((e) => e.toString()));
    }

    final int hogsCount = targetHogs.isNotEmpty
        ? targetHogs.length
        : ((p['selected_hogs_count'] as num?)?.toInt() ?? (p['hogs'] is List ? (p['hogs'] as List).length : 6));

    final double perHogAmount = hogsCount > 0 ? (amt / hogsCount) : amt;
    final rawInvId = p['investment_id'] ?? p['id'];
    final investmentId = rawInvId is int ? rawInvId : int.tryParse(rawInvId?.toString() ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          Icons.account_balance_wallet_rounded,
                          color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Partner Investment Details',
                          style: GoogleFonts.plusJakartaSans(
                            color: titleColor,
                            fontSize: isMobile ? 22 : 28,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Investment #${p['investment_id'] ?? p['id'] ?? "Direct"} • Complete breakdown of capital, batch allocation, and partner investor records.',
                    style: GoogleFonts.plusJakartaSans(
                      color: mutedColor,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(
                'Back to Investments',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Full In-Page Content Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
            border: Border.all(color: cardBorder),
          ),
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Partner Profile & Status Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: innerBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3),
                      child: Text(
                        partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: titleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partnerName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Invested on ${_formatDate(dt)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 2. Financial Metrics Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: innerBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL CAPITAL',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: mutedColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatCurrency(amt),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF43CB89),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: innerBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ALLOCATION RATIO',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: mutedColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '≈ ${_formatCurrency(perHogAmount)} / hog',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. Batch & Raiser Destination Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: innerBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2_rounded, size: 18, color: mutedColor),
                        const SizedBox(width: 8),
                        Text(
                          'BATCH & RAISER DESTINATION',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: mutedColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Funded Batch:',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: mutedColor, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          batchName,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: titleColor, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assigned Raiser:',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: mutedColor, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          raiserName,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: titleColor, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. Target Allocation Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: innerBg,
                  borderRadius: BorderRadius.circular(14),
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
                            Icon(Icons.tune_rounded, size: 18, color: mutedColor),
                            const SizedBox(width: 8),
                            Text(
                              'TARGET ALLOCATION',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: mutedColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: cardBorder, width: 0.8),
                          ),
                          child: Text(
                            targetPigType,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      targetHogs.isNotEmpty
                          ? 'Allocated Hogs ($hogsCount):'
                          : 'All $hogsCount hogs in batch covered by investment.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    if (targetHogs.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: targetHogs.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF28405D) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.pets_rounded, size: 12, color: titleColor),
                                const SizedBox(width: 5),
                                Text(
                                  tag,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: titleColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // 5. Quick Actions for Pending Investments
              if (isPending && investmentId != null) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => onReject?.call(investmentId),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text(
                        'Reject Investment',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => onApprove?.call(investmentId),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        'Approve Investment',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PiggyTrunkTheme.ptSuccess,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

