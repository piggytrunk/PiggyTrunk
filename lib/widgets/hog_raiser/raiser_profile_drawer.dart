import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';

class RaiserProfileDrawer {
  static void show({
    required BuildContext context,
    required Map<String, dynamic> row,
    required Future<void> Function(Map<String, dynamic> row) onApprove,
    required Future<void> Function(Map<String, dynamic> row) onDelete,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    if (isMobile) {
      _showBottomSheet(context, row, onApprove, onDelete);
    } else {
      _showSideDrawer(context, row, onApprove, onDelete);
    }
  }

  static String? _getAvatarUrl(Map<String, dynamic> row) {
    final appUsers = row['app_users'] as Map<String, dynamic>?;
    final metadata = row['raw_user_meta_data'] as Map<String, dynamic>?;
    final dynamic candidate = row['profile_picture'] ??
        row['avatar_url'] ??
        row['photo_url'] ??
        row['image_url'] ??
        row['profile_image'] ??
        row['picture'] ??
        appUsers?['profile_picture'] ??
        appUsers?['avatar_url'] ??
        appUsers?['photo_url'] ??
        appUsers?['image_url'] ??
        appUsers?['profile_image'] ??
        appUsers?['picture'] ??
        metadata?['avatar_url'] ??
        metadata?['picture'] ??
        metadata?['profile_picture'];

    if (candidate != null) {
      final str = candidate.toString().trim();
      if (str.startsWith('http://') || str.startsWith('https://')) {
        return str;
      }
    }
    return null;
  }

  static String formatPigType(dynamic raw) {
    final str = (raw ?? '').toString().trim();
    if (str.isEmpty ||
        str.toUpperCase() == 'N/A' ||
        str.toUpperCase() == 'NONE' ||
        str.toUpperCase() == 'UNASSIGNED' ||
        str.toLowerCase() == 'null') {
      return 'Unassigned';
    }
    final lower = str.toLowerCase();
    final bool hasSow = lower.contains('sow') || lower.contains('breed') || lower.contains('inahin');
    final bool hasFattening = lower.contains('fatten') || lower.contains('baboy');
    if (hasSow && hasFattening) {
      return 'Sow and Fattening';
    } else if (hasSow) {
      return 'Sow';
    } else if (hasFattening) {
      return 'Fattening';
    }
    return str;
  }

  static Widget _buildAvatarWidget({
    required BuildContext context,
    required String initials,
    String? avatarUrl,
    double size = 68,
    double fontSize = 20,
  }) {
    final hasUrl = avatarUrl != null && avatarUrl.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const bgColor = Colors.white;
    final borderColor = isDark ? Colors.white : const Color(0xFF18314F);
    final textColor = isDark ? const Color(0xFF0F172A) : const Color(0xFF18314F);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.white : const Color(0xFF18314F)).withValues(alpha: isDark ? 0.25 : 0.12),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: hasUrl
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Padding(
                padding: EdgeInsets.all(size * 0.14),
                child: Image.asset(
                  'assets/piggytrunk_logo.png',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      initials,
                      style: AppTextStyles.jakarta(
                        size: fontSize,
                        weight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: SizedBox(
                    width: size * 0.35,
                    height: size * 0.35,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  ),
                );
              },
            )
          : Padding(
              padding: EdgeInsets.all(size * 0.14),
              child: Image.asset(
                'assets/piggytrunk_logo.png',
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    initials,
                    style: AppTextStyles.jakarta(
                      size: fontSize,
                      weight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  static Widget _drawerDetailRow(String label, String value, Color hintText, Color titleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.jakarta(size: 13, weight: FontWeight.w600, color: hintText),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.jakarta(size: 13, weight: FontWeight.w700, color: titleColor),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  static void _showBottomSheet(
    BuildContext context,
    Map<String, dynamic> row,
    Future<void> Function(Map<String, dynamic> row) onApprove,
    Future<void> Function(Map<String, dynamic> row) onDelete,
  ) {
    final name = (row['name'] ?? 'Hog Raiser').toString();
    final email = (row['email'] ?? 'N/A').toString();
    final phone = (row['phone'] ?? 'N/A').toString();
    final address = (row['address'] ?? 'N/A').toString();
    final pigType = formatPigType(row['pig_type']);
    final status = (row['account_status'] ?? row['status'] ?? 'Active').toString().toUpperCase();
    final isPending = status == 'PENDING';
    final avatarUrl = _getAvatarUrl(row);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF27405F) : const Color(0xFFC6D8EF);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final hintText = isDark ? const Color(0xFF8FA7C4) : const Color(0xFF5D7391);

    final statusColor = status == 'ACTIVE' || status == 'APPROVED'
        ? PiggyTrunkTheme.ptSuccess
        : (status == 'PENDING' ? const Color(0xFFFFAA00) : Colors.redAccent);

    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase()
        : 'HR';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: cardBorder, width: 1.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: hintText.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Raiser Profile',
                      style: AppTextStyles.jakarta(
                        size: 17,
                        weight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: Icon(Icons.close_rounded, color: hintText, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildAvatarWidget(context: context, initials: initials, avatarUrl: avatarUrl, size: 64, fontSize: 20),
                      const SizedBox(height: 10),
                      Text(
                        name,
                        style: AppTextStyles.jakarta(size: 17, weight: FontWeight.w800, color: titleColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: AppTextStyles.jakarta(size: 13, weight: FontWeight.w500, color: hintText),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.35),
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
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              status,
                              maxLines: 1,
                              softWrap: false,
                              style: AppTextStyles.jakarta(
                                color: statusColor,
                                size: 11,
                                weight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B2E48) : const Color(0xFFF6F9FD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder.withValues(alpha: 0.5)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Column(
                          children: [
                            _drawerDetailRow('Name', name, hintText, titleColor),
                            Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                            _drawerDetailRow('Email', email, hintText, titleColor),
                            Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                            _drawerDetailRow('Phone', phone, hintText, titleColor),
                            Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                            _drawerDetailRow('Address', address, hintText, titleColor),
                            if (!isPending) ...[
                              Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                              _drawerDetailRow('Pig Type', pigType, hintText, titleColor),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (isPending) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            onDelete(row);
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: (isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent).withValues(alpha: 0.1),
                            side: BorderSide(color: isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'Reject',
                            style: AppTextStyles.jakarta(
                              size: 13,
                              weight: FontWeight.w800,
                              color: isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            onApprove(row);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Approve',
                            style: AppTextStyles.jakarta(
                              size: 13,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ] else
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Close',
                            style: AppTextStyles.jakarta(
                              size: 13,
                              weight: FontWeight.w800,
                              color: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
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

  static void _showSideDrawer(
    BuildContext context,
    Map<String, dynamic> row,
    Future<void> Function(Map<String, dynamic> row) onApprove,
    Future<void> Function(Map<String, dynamic> row) onDelete,
  ) {
    final name = (row['name'] ?? 'Hog Raiser').toString();
    final email = (row['email'] ?? 'N/A').toString();
    final phone = (row['phone'] ?? 'N/A').toString();
    final address = (row['address'] ?? 'N/A').toString();
    final pigType = formatPigType(row['pig_type']);
    final status = (row['account_status'] ?? row['status'] ?? 'Active').toString().toUpperCase();
    final isPending = status == 'PENDING';
    final avatarUrl = _getAvatarUrl(row);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF27405F) : const Color(0xFFC6D8EF);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final hintText = isDark ? const Color(0xFF8FA7C4) : const Color(0xFF5D7391);

    final statusColor = status == 'ACTIVE' || status == 'APPROVED'
        ? PiggyTrunkTheme.ptSuccess
        : (status == 'PENDING' ? const Color(0xFFFFAA00) : Colors.redAccent);

    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase()
        : 'HR';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Raiser Details',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 420,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(left: BorderSide(color: cardBorder, width: 1.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(-4, 0),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Text(
                              'Raiser Profile',
                              style: AppTextStyles.jakarta(
                                size: 17,
                                weight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: Icon(Icons.close_rounded, color: hintText, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Close panel',
                            ),
                          ],
                        ),
                      ),
                      Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    _buildAvatarWidget(context: context, initials: initials, avatarUrl: avatarUrl, size: 68, fontSize: 22),
                                    const SizedBox(height: 12),
                                    Text(
                                      name,
                                      style: AppTextStyles.jakarta(
                                        size: 18,
                                        weight: FontWeight.w800,
                                        color: titleColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: AppTextStyles.jakarta(
                                        size: 13,
                                        weight: FontWeight.w500,
                                        color: hintText,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: statusColor.withValues(alpha: 0.35),
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
                                              color: statusColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            status,
                                            maxLines: 1,
                                            softWrap: false,
                                            style: AppTextStyles.jakarta(
                                              color: statusColor,
                                              size: 11,
                                              weight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'PROFILE DETAILS',
                                style: AppTextStyles.jakarta(
                                  size: 11,
                                  weight: FontWeight.w800,
                                  color: hintText,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1B2E48) : const Color(0xFFF6F9FD),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cardBorder.withValues(alpha: 0.5)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Column(
                                  children: [
                                    _drawerDetailRow('Name', name, hintText, titleColor),
                                    Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                                    _drawerDetailRow('Email', email, hintText, titleColor),
                                    Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                                    _drawerDetailRow('Phone', phone, hintText, titleColor),
                                    Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                                    _drawerDetailRow('Address', address, hintText, titleColor),
                                    if (!isPending) ...[
                                      Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                                      _drawerDetailRow('Pig Type', pigType, hintText, titleColor),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            if (isPending) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    onDelete(row);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: (isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent).withValues(alpha: 0.1),
                                    side: BorderSide(color: isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent, width: 1.2),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    'Reject',
                                    style: AppTextStyles.jakarta(
                                      size: 13,
                                      weight: FontWeight.w800,
                                      color: isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    onApprove(row);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Approve',
                                    style: AppTextStyles.jakarta(
                                      size: 13,
                                      weight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ] else
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                    foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Close',
                                    style: AppTextStyles.jakarta(
                                      size: 13,
                                      weight: FontWeight.w800,
                                      color: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
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
            ),
          ),
        );
      },
    );
  }
}
