import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/investment_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import 'investment_detail_modal.dart';

class InvestmentDetailView extends StatelessWidget {
  final Investment investment;
  final VoidCallback onBack;
  final void Function(Investment item)? onEdit;
  final void Function(Investment item)? onComplete;
  final void Function(Investment item)? onArchive;
  final void Function(Investment item)? onRestore;
  final void Function(Investment item)? onDelete;

  const InvestmentDetailView({
    super.key,
    required this.investment,
    required this.onBack,
    this.onEdit,
    this.onComplete,
    this.onArchive,
    this.onRestore,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);

    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final mutedColor = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);


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
                          Icons.monetization_on_outlined,
                          color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Investment Details',
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
                    'Complete breakdown of capital, batch allocation, and livestock records.',
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
              InvestmentDetailModal.buildContent(
                investment,
                isDark,
                cardBorder,
                titleColor,
                mutedColor,
              ),

            ],
          ),
        ),
      ],
    );
  }
}
