import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

enum InPageActionType {
  danger, // Red / Coral for Archive, Delete, Reject
  success, // Green / Emerald for Approve, Complete
  warning, // Amber for Status changes
  primary, // Brand Navy for General actions
}

class InPageConfirmationView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String message;
  final InPageActionType actionType;
  final IconData? customIcon;
  final String? userName;
  final String? userEmail;
  final String? userRole;
  final String? avatarUrl;
  final String? itemTitle;
  final String? itemSubtitle;
  final String? itemImageUrl;
  final Map<String, String>? itemExtraDetails;
  final String? warningText;
  final String confirmButtonText;
  final String cancelButtonText;
  final Future<void> Function() onConfirm;
  final VoidCallback onCancel;
  final bool isLoading;
  final bool showHeader;

  const InPageConfirmationView({
    super.key,
    required this.title,
    this.subtitle,
    required this.message,
    this.actionType = InPageActionType.danger,
    this.customIcon,
    this.userName,
    this.userEmail,
    this.userRole,
    this.avatarUrl,
    this.itemTitle,
    this.itemSubtitle,
    this.itemImageUrl,
    this.itemExtraDetails,
    this.warningText,
    this.confirmButtonText = 'Confirm',
    this.cancelButtonText = 'Cancel',
    required this.onConfirm,
    required this.onCancel,
    this.isLoading = false,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);

    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final mutedColor = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);

    Color themeColor;
    IconData defaultIcon;

    switch (actionType) {
      case InPageActionType.danger:
        themeColor = isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent;
        defaultIcon = Icons.archive_outlined;
        break;
      case InPageActionType.success:
        themeColor = isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess;
        defaultIcon = Icons.check_circle_outline_rounded;
        break;
      case InPageActionType.warning:
        themeColor = const Color(0xFFFFA566);
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case InPageActionType.primary:
        themeColor = isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;
        defaultIcon = Icons.info_outline_rounded;
        break;
    }

    final effectiveIcon = customIcon ?? defaultIcon;
    final effectiveWarning = warningText ??
        (actionType == InPageActionType.danger
            ? 'This action may permanently modify or remove records. Please proceed with caution.'
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        if (showHeader) ...[
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
                            color: themeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: themeColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            effectiveIcon,
                            color: themeColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
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
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: GoogleFonts.plusJakartaSans(
                          color: mutedColor,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],

        // Entity Identity Card (User or Item)
        if (userName != null || itemTitle != null) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                if (userName != null) ...[
                  Container(
                    width: isMobile ? 48 : 56,
                    height: isMobile ? 48 : 56,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF132238) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: cardBorder, width: 1.5),
                    ),
                    child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                        ? Image.network(
                            avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildInitialsAvatar(userName!, isDark),
                          )
                        : _buildInitialsAvatar(userName!, isDark),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        if (userEmail != null && userEmail!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            userEmail!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: mutedColor,
                            ),
                          ),
                        ],
                        if (userRole != null && userRole!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              userRole!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else if (itemTitle != null) ...[
                  if (itemImageUrl != null && itemImageUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        itemImageUrl!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B293E) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: mutedColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ] else ...[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B293E) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: mutedColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemTitle!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        if (itemSubtitle != null && itemSubtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            itemSubtitle!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Confirmation Question & Warning Container
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            border: Border.all(color: cardBorder),
          ),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 15 : 17,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  height: 1.45,
                ),
              ),

              // Extra Details Grid if provided
              if (itemExtraDetails != null && itemExtraDetails!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: itemExtraDetails!.entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2E44) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${entry.key}: ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: mutedColor,
                            ),
                          ),
                          Text(
                            entry.value,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Warning Banner
              if (effectiveWarning != null && effectiveWarning.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: themeColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: themeColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          effectiveWarning,
                          style: GoogleFonts.plusJakartaSans(
                            color: themeColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
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
        const SizedBox(height: 24),

        // Action Buttons Row
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: isLoading ? null : onCancel,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 26,
                  vertical: isMobile ? 12 : 15,
                ),
                side: BorderSide(color: cardBorder, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                cancelButtonText,
                style: GoogleFonts.plusJakartaSans(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            ElevatedButton(
              onPressed: isLoading ? null : () => onConfirm(),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 22 : 28,
                  vertical: isMobile ? 12 : 15,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(effectiveIcon, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          confirmButtonText,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar(String name, bool isDark) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase()
        : '?';
    return Center(
      child: Text(
        initials,
        style: AppTextStyles.jakarta(
          size: 16,
          weight: FontWeight.w800,
          color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
        ),
      ),
    );
  }
}
