import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';

enum SlideOverActionType {
  danger,   // For Rejection, Delete, Suspend, Clear All (Red)
  success,  // For Approval, Activation (Green)
  warning,  // For Status Change, Archive, Reset (Amber)
  info,     // For Confirmation (Blue)
  primary,  // Brand Primary (Navy in Light / White in Dark)
}

/// Universal Slide-Over Right Drawer for Action Confirmations
class SlideOverConfirmationDrawer extends StatelessWidget {
  final String title;
  final String message;
  final SlideOverActionType actionType;
  final String? userName;
  final String? userEmail;
  final String? userRole;
  final String? avatarUrl;
  final String confirmButtonText;
  final String cancelButtonText;
  final IconData? customIcon;
  final bool isBottomSheet;

  const SlideOverConfirmationDrawer({
    super.key,
    required this.title,
    required this.message,
    this.actionType = SlideOverActionType.danger,
    this.userName,
    this.userEmail,
    this.userRole,
    this.avatarUrl,
    this.confirmButtonText = 'Confirm',
    this.cancelButtonText = 'Cancel',
    this.customIcon,
    this.isBottomSheet = false,
  });

  /// Static helper to trigger the Slide-Over Drawer with smooth slide transition or Bottom Sheet on mobile
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    SlideOverActionType actionType = SlideOverActionType.danger,
    String? userName,
    String? userEmail,
    String? userRole,
    String? avatarUrl,
    String confirmButtonText = 'Confirm',
    String cancelButtonText = 'Cancel',
    IconData? customIcon,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 768) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => SlideOverConfirmationDrawer(
          title: title,
          message: message,
          actionType: actionType,
          userName: userName,
          userEmail: userEmail,
          userRole: userRole,
          avatarUrl: avatarUrl,
          confirmButtonText: confirmButtonText,
          cancelButtonText: cancelButtonText,
          customIcon: customIcon,
          isBottomSheet: true,
        ),
      );
    }

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Action Confirmation',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: SlideOverConfirmationDrawer(
            title: title,
            message: message,
            actionType: actionType,
            userName: userName,
            userEmail: userEmail,
            userRole: userRole,
            avatarUrl: avatarUrl,
            confirmButtonText: confirmButtonText,
            cancelButtonText: cancelButtonText,
            customIcon: customIcon,
            isBottomSheet: false,
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curvedAnim = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnim),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Core Layout Colors
    final surfaceColor = isDark ? const Color(0xFF132238) : Colors.white;
    final borderColor = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleTextColor = isDark ? Colors.white : const Color(0xFF18314F);
    final bodyTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final mutedTextColor = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
    final targetCardBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF8FAFC);
    final targetCardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);

    // Dynamic Action Tone Colors
    final Color actionAccent;
    final Color actionLightBg;
    final IconData defaultIcon;

    switch (actionType) {
      case SlideOverActionType.danger:
        actionAccent = isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent;
        actionLightBg = (isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent).withValues(alpha: isDark ? 0.18 : 0.1);
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case SlideOverActionType.success:
        actionAccent = isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess;
        actionLightBg = (isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess).withValues(alpha: isDark ? 0.18 : 0.1);
        defaultIcon = Icons.check_circle_outline_rounded;
        break;
      case SlideOverActionType.warning:
        actionAccent = isDark ? PiggyTrunkTheme.ptInProgressDark : PiggyTrunkTheme.ptInProgress;
        actionLightBg = (isDark ? PiggyTrunkTheme.ptInProgressDark : PiggyTrunkTheme.ptInProgress).withValues(alpha: isDark ? 0.18 : 0.1);
        defaultIcon = Icons.info_outline_rounded;
        break;
      case SlideOverActionType.info:
        actionAccent = isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptPrimary;
        actionLightBg = (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.08);
        defaultIcon = Icons.help_outline_rounded;
        break;
      case SlideOverActionType.primary:
        actionAccent = isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;
        actionLightBg = (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.08);
        defaultIcon = Icons.archive_outlined;
        break;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final drawerWidth = isMobile ? screenWidth : 420.0;

    if (isBottomSheet) {
      return Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 6),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: actionLightBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: actionAccent.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            customIcon ?? defaultIcon,
                            color: actionAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          title,
                          style: AppTextStyles.jakarta(
                            size: 17,
                            weight: FontWeight.w800,
                            color: titleTextColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: mutedTextColor, size: 20),
                      tooltip: 'Cancel and Close',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target Profile Info Card (if user details are passed)
                    if (userName != null && userName!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: targetCardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: targetCardBorder, width: 1),
                        ),
                        child: Row(
                          children: [
                            _buildAvatar(isDark, actionAccent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName!,
                                    style: AppTextStyles.jakarta(
                                      size: 14.5,
                                      weight: FontWeight.w700,
                                      color: titleTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (userEmail != null && userEmail!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      userEmail!,
                                      style: AppTextStyles.jakarta(
                                        size: 12.5,
                                        weight: FontWeight.w500,
                                        color: mutedTextColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (userRole != null && userRole!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: actionLightBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: actionAccent.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  userRole!,
                                  style: AppTextStyles.jakarta(
                                    size: 11,
                                    weight: FontWeight.w800,
                                    color: actionAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Confirmation Prompt Text
                    Text(
                      message,
                      style: AppTextStyles.jakarta(
                        size: 13.5,
                        weight: FontWeight.w500,
                        color: bodyTextColor,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: borderColor, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          cancelButtonText,
                          style: AppTextStyles.jakarta(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: titleTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: actionAccent,
                          foregroundColor: actionType == SlideOverActionType.primary && isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          confirmButtonText,
                          style: AppTextStyles.jakarta(
                            size: 13.5,
                            weight: FontWeight.w800,
                            color: actionType == SlideOverActionType.primary && isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
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

    return Material(
      color: Colors.transparent,
      child: Container(
        width: drawerWidth,
        height: double.infinity,
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(-6, 0),
            ),
          ],
          border: Border(
            left: BorderSide(color: borderColor, width: 1.2),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================== DRAWER HEADER ====================
              Container(
                padding: EdgeInsets.fromLTRB(isMobile ? 16 : 20, 18, isMobile ? 12 : 16, 16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: actionLightBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: actionAccent.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            customIcon ?? defaultIcon,
                            color: actionAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          title,
                          style: AppTextStyles.jakarta(
                            size: 17,
                            weight: FontWeight.w800,
                            color: titleTextColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: mutedTextColor, size: 20),
                      tooltip: 'Cancel and Close',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),

              // ==================== DRAWER BODY ====================
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target Profile Info Card (if user details are passed)
                      if (userName != null && userName!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: targetCardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: targetCardBorder, width: 1),
                          ),
                          child: Row(
                            children: [
                              _buildAvatar(isDark, actionAccent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName!,
                                      style: AppTextStyles.jakarta(
                                        size: 14.5,
                                        weight: FontWeight.w700,
                                        color: titleTextColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (userEmail != null && userEmail!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        userEmail!,
                                        style: AppTextStyles.jakarta(
                                          size: 12,
                                          weight: FontWeight.w400,
                                          color: mutedTextColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (userRole != null && userRole!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          userRole!,
                                          style: AppTextStyles.jakarta(
                                            size: 10.5,
                                            weight: FontWeight.w700,
                                            color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Message Body
                      Text(
                        message,
                        style: AppTextStyles.jakarta(
                          size: 13.5,
                          weight: FontWeight.w400,
                          color: bodyTextColor,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Danger Caution Banner (for Danger Action Types)
                      if (actionType == SlideOverActionType.danger)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 17,
                                color: Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This action may permanently modify or remove records. Please proceed with caution.',
                                  style: AppTextStyles.jakarta(
                                    size: 11.5,
                                    weight: FontWeight.w500,
                                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ==================== DRAWER FOOTER ACTIONS ====================
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                ),
                child: Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          cancelButtonText,
                          style: AppTextStyles.jakarta(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action Confirm Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: actionAccent,
                          foregroundColor: actionType == SlideOverActionType.primary && isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          confirmButtonText,
                          style: AppTextStyles.jakarta(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: actionType == SlideOverActionType.primary && isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
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
      ),
    );
  }

  Widget _buildAvatar(bool isDark, Color actionAccent) {
    final initials = userName != null && userName!.trim().isNotEmpty
        ? userName!.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase()
        : 'U';

    final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    const bgColor = Colors.white;
    final borderColor = isDark ? Colors.white : const Color(0xFF18314F);
    final textColor = isDark ? const Color(0xFF0F172A) : const Color(0xFF18314F);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.white : const Color(0xFF18314F)).withValues(alpha: isDark ? 0.25 : 0.12),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasAvatar
          ? Image.network(
              avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  'assets/piggytrunk_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      initials,
                      style: AppTextStyles.jakarta(
                        size: 15,
                        weight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                'assets/piggytrunk_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    initials,
                    style: AppTextStyles.jakarta(
                      size: 15,
                      weight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
