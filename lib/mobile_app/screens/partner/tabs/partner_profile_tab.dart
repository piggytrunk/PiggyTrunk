import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../services/locale_provider.dart';
import '../../../utils/app_strings.dart';
import '../../../utils/screen_fit_util.dart';
import '../../../widgets/change_password_modal.dart';
import '../../../widgets/check_for_updates_tile.dart';

class PartnerProfileTab extends StatelessWidget {
  final String partnerName;
  final String partnerEmail;
  final String partnerPhone;
  final String partnerAddress;
  final String? partnerAvatarUrl;
  final VoidCallback onPickAndUploadAvatar;
  final VoidCallback onRestoreDefaultAvatar;
  final VoidCallback? onResetProfile;
  final VoidCallback onShowEditProfileDialog;
  final VoidCallback onLogout;

  static const Color _brandColor = Color(0xFF18314F);

  const PartnerProfileTab({
    super.key,
    required this.partnerName,
    required this.partnerEmail,
    required this.partnerPhone,
    required this.partnerAddress,
    this.partnerAvatarUrl,
    required this.onPickAndUploadAvatar,
    required this.onRestoreDefaultAvatar,
    this.onResetProfile,
    required this.onShowEditProfileDialog,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final fit = ScreenFit(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final settingsProvider = SettingsProvider.of(context);
    final currentLocale = settingsProvider?.currentLocale ?? 'en';
    final currentThemeMode = settingsProvider?.themeMode ?? (isDark ? ThemeMode.dark : ThemeMode.light);

    final primaryTextColor = isDark ? Colors.white : _brandColor;
    final titleColor = isDark ? Colors.white : _brandColor;
    final labelColor = isDark ? Colors.white : _brandColor;
    final cardBgColor = isDark ? const Color(0xff151f2e) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xff28354a) : PiggyTrunkTheme.ptBorder;
    final mutedTextColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

    final name = (partnerName.trim().isNotEmpty && partnerName.trim().toLowerCase() != 'partner investor')
        ? partnerName.trim()
        : strings.partnerRole;
    final email = partnerEmail.trim().isNotEmpty ? partnerEmail.trim() : strings.notSet;
    final phone = (partnerPhone.trim().isNotEmpty && partnerPhone != 'N/A') ? partnerPhone.trim() : strings.notSet;
    final address = (partnerAddress.trim().isNotEmpty && partnerAddress != 'N/A') ? partnerAddress.trim() : strings.notSet;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(fit.dp(20.0), fit.dp(24.0), fit.dp(20.0), fit.dp(108.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================== 1. AVATAR & NAME HEADER CARD ====================
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: onPickAndUploadAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: fit.dp(100.0),
                        height: fit.dp(100.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _brandColor, width: 2.5),
                          color: isDark ? const Color(0xff1b2638) : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: _brandColor.withValues(alpha: 0.12),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: (partnerAvatarUrl != null && partnerAvatarUrl!.isNotEmpty)
                              ? Image.network(
                                  partnerAvatarUrl!,
                                  width: fit.dp(100.0),
                                  height: fit.dp(100.0),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Padding(
                                    padding: EdgeInsets.all(fit.dp(12.0)),
                                    child: Image.asset(
                                      'assets/piggytrunk_logo.png',
                                      width: fit.dp(76.0),
                                      height: fit.dp(76.0),
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, err, st) => Container(
                                        color: Colors.white,
                                        child: const Icon(Icons.person, size: 50, color: _brandColor),
                                      ),
                                    ),
                                  ),
                                )
                              : Padding(
                                  padding: EdgeInsets.all(fit.dp(12.0)),
                                  child: Image.asset(
                                    'assets/piggytrunk_logo.png',
                                    width: fit.dp(76.0),
                                    height: fit.dp(76.0),
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, err, st) => Container(
                                      color: Colors.white,
                                      child: const Icon(Icons.person, size: 50, color: _brandColor),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(fit.dp(6)),
                          decoration: const BoxDecoration(
                            color: _brandColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: fit.dp(16),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: fit.dp(12)),
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fit.sp(22.0),
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                SizedBox(height: fit.dp(8)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: fit.dp(16), vertical: fit.dp(6)),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(fit.dp(20)),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    strings.partnerRole,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: fit.sp(13.5),
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: fit.dp(32.0)),

          // ==================== 2. ACCOUNT DETAILS SECTION HEADER ====================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.accountDetails,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fit.sp(16.0),
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: onResetProfile ?? onRestoreDefaultAvatar,
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: fit.dp(16),
                          color: primaryTextColor,
                        ),
                        SizedBox(width: fit.dp(4)),
                        Text(
                          strings.reset,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(14.0),
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: fit.dp(16)),
                  GestureDetector(
                    onTap: onShowEditProfileDialog,
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: fit.dp(16),
                          color: primaryTextColor,
                        ),
                        SizedBox(width: fit.dp(4)),
                        Text(
                          strings.edit,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(14.0),
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: fit.dp(16.0)),

          // ==================== 3. DETAILS LIST CARD ====================
          Container(
            padding: EdgeInsets.all(fit.dp(20.0)),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(fit.dp(20.0)),
              border: Border.all(color: cardBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildProfileRow(fit, isDark, Icons.email_outlined, strings.emailAddress, email, primaryTextColor, mutedTextColor),
                Divider(height: fit.dp(24.0), color: cardBorderColor),
                _buildProfileRow(fit, isDark, Icons.phone_iphone_rounded, strings.phoneNumber, phone, primaryTextColor, mutedTextColor),
                Divider(height: fit.dp(24.0), color: cardBorderColor),
                _buildProfileRow(fit, isDark, Icons.location_on_outlined, strings.address, address, primaryTextColor, mutedTextColor),
                Divider(height: fit.dp(24.0), color: cardBorderColor),
                _buildProfileRow(fit, isDark, Icons.security_rounded, strings.systemAccess, strings.partnerRole, primaryTextColor, mutedTextColor),
              ],
            ),
          ),
          SizedBox(height: fit.dp(32.0)),

          // ==================== 4. SETTINGS & PREFERENCES ====================
          Text(
            strings.settings,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fit.sp(16.0),
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          SizedBox(height: fit.dp(14.0)),

          // ---- Unified Grouped Settings Card ----
          Container(
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(fit.dp(18.0)),
              border: Border.all(color: cardBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // 1. Language Preference Row (Clean Typography, No Flags)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: fit.dp(16.0), vertical: fit.dp(12.0)),
                  child: Row(
                    children: [
                      _buildSettingsIcon(
                        icon: Icons.translate_rounded,
                        isDark: isDark,
                      ),
                      SizedBox(width: fit.dp(12.0)),
                      Expanded(
                        child: Text(
                          strings.languagePreference,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(14.0),
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                      ),
                      SizedBox(width: fit.dp(8.0)),
                      _buildSegmentedControl(
                        isDark: isDark,
                        options: [
                          _SegmentOption(
                            icon: Icons.language_rounded,
                            label: 'English',
                            isSelected: currentLocale == 'en',
                            onTap: () => settingsProvider?.setLocale('en'),
                          ),
                          _SegmentOption(
                            icon: Icons.translate_rounded,
                            label: 'Filipino',
                            isSelected: currentLocale == 'fil',
                            onTap: () => settingsProvider?.setLocale('fil'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, thickness: 1, color: cardBorderColor),

                // 2. App Theme Row (Compact Light / Dark Toggle)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: fit.dp(16.0), vertical: fit.dp(12.0)),
                  child: Row(
                    children: [
                      _buildSettingsIcon(
                        icon: Icons.palette_outlined,
                        isDark: isDark,
                      ),
                      SizedBox(width: fit.dp(12.0)),
                      Expanded(
                        child: Text(
                          strings.themePreference,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(14.0),
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                      ),
                      SizedBox(width: fit.dp(8.0)),
                      _buildSegmentedControl(
                        isDark: isDark,
                        options: [
                          _SegmentOption(
                            icon: Icons.wb_sunny_rounded,
                            label: strings.lightMode,
                            isSelected: currentThemeMode == ThemeMode.light,
                            onTap: () => settingsProvider?.setThemeMode(ThemeMode.light),
                          ),
                          _SegmentOption(
                            icon: Icons.nights_stay_rounded,
                            label: strings.darkMode,
                            isSelected: currentThemeMode == ThemeMode.dark,
                            onTap: () => settingsProvider?.setThemeMode(ThemeMode.dark),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, thickness: 1, color: cardBorderColor),

                // 3. Password & Security Row (Tappable Tile with Chevron)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => ChangePasswordModal.show(context),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: fit.dp(16.0), vertical: fit.dp(14.0)),
                      child: Row(
                        children: [
                          _buildSettingsIcon(
                            icon: Icons.shield_outlined,
                            isDark: isDark,
                          ),
                          SizedBox(width: fit.dp(12.0)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.passwordAndSecurity,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(14.0),
                                    fontWeight: FontWeight.w700,
                                    color: labelColor,
                                  ),
                                ),
                                SizedBox(height: fit.dp(2.0)),
                                Text(
                                  strings.updatePasswordSubtitle,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(11.5),
                                    fontWeight: FontWeight.w500,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: fit.dp(8.0)),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: fit.dp(14.0),
                            color: subtitleColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Divider(height: 1, thickness: 1, color: cardBorderColor),

                // 4. Check for Updates Row
                CheckForUpdatesTile(
                  isDark: isDark,
                  labelColor: labelColor,
                  subtitleColor: subtitleColor,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(fit.dp(18.0))),
                  horizontalPadding: fit.dp(16.0),
                  verticalPadding: fit.dp(14.0),
                ),
              ],
            ),
          ),
          SizedBox(height: fit.dp(32.0)),

          // ==================== 5. SIGN OUT BUTTON ====================
          SizedBox(
            width: double.infinity,
            height: fit.dp(54.0),
            child: OutlinedButton(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF151F2E) : Colors.transparent,
                side: BorderSide(
                  color: isDark ? const Color(0xFF28354A) : _brandColor,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(fit.dp(14)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    strings.signOut,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : _brandColor,
                      fontSize: fit.sp(15.0),
                    ),
                  ),
                  SizedBox(width: fit.dp(8)),
                  Icon(Icons.logout_rounded, color: isDark ? Colors.white : _brandColor, size: fit.dp(20)),
                ],
              ),
            ),
          ),
          SizedBox(height: fit.dp(18.0)),
        ],
      ),
    );
  }

  Widget _buildSettingsIcon({
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.09) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFDBEAFE),
          width: 0.8,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: isDark ? Colors.white : _brandColor,
          size: 19,
        ),
      ),
    );
  }

  Widget _buildSegmentedControl({
    required bool isDark,
    required List<_SegmentOption> options,
    double width = 186.0,
  }) {
    final activeBg = isDark ? Colors.white : _brandColor;
    final activeText = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inactiveText = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final containerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final containerBorder = isDark ? const Color(0xFF28354A) : const Color(0xFFE2E8F0);

    return Container(
      width: width,
      height: 38,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: containerBorder, width: 0.8),
      ),
      child: Row(
        children: options.map((opt) {
          final selected = opt.isSelected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: opt.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: (isDark ? Colors.black : _brandColor).withValues(
                              alpha: isDark ? 0.35 : 0.18,
                            ),
                            blurRadius: 5,
                            offset: const Offset(0, 1.5),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (opt.icon != null) ...[
                      Icon(
                        opt.icon,
                        size: 13,
                        color: selected ? activeText : inactiveText,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        opt.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? activeText : inactiveText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProfileRow(
    ScreenFit fit,
    bool isDark,
    IconData icon,
    String label,
    String value,
    Color primaryColor,
    Color mutedColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.09) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFDBEAFE),
              width: 0.8,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: isDark ? Colors.white : _brandColor,
              size: 19,
            ),
          ),
        ),
        SizedBox(width: fit.dp(14.0)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fit.sp(12.0),
                  color: mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: fit.dp(2.0)),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fit.sp(14.0),
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentOption {
  final IconData? icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentOption({
    this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
}

