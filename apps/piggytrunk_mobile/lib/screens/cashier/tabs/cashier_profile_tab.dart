import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../services/locale_provider.dart';
import '../../../utils/app_strings.dart';
import '../../../widgets/change_password_modal.dart';

class CashierProfileTab extends StatelessWidget {
  final String cashierName;
  final String cashierEmail;
  final String cashierPhone;
  final String cashierAddress;
  final String? cashierAvatarUrl;
  final VoidCallback onPickAndUploadAvatar;
  final VoidCallback onRestoreDefaultAvatar;
  final VoidCallback onShowEditProfileDialog;
  final VoidCallback onHandleLogout;

  static const Color _brandColor = Color(0xFF18314F);

  const CashierProfileTab({
    super.key,
    required this.cashierName,
    required this.cashierEmail,
    required this.cashierPhone,
    required this.cashierAddress,
    required this.cashierAvatarUrl,
    required this.onPickAndUploadAvatar,
    required this.onRestoreDefaultAvatar,
    required this.onShowEditProfileDialog,
    required this.onHandleLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : _brandColor;
    final cardColor = isDark ? const Color(0xFF1B2638) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28354A) : PiggyTrunkTheme.ptBorder;
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final labelColor = isDark ? Colors.white : _brandColor;
    final strings = AppStrings.of(context);
    final settingsProvider = SettingsProvider.of(context);
    final currentLocale = settingsProvider?.currentLocale ?? 'en';
    final currentThemeMode = settingsProvider?.themeMode ?? ThemeMode.light;

    final name = cashierName.trim().isNotEmpty ? cashierName : 'Cashier Staff';
    final email = cashierEmail.trim().isNotEmpty ? cashierEmail : 'N/A';
    final phone = (cashierPhone.trim().isNotEmpty && cashierPhone != 'N/A') ? cashierPhone : strings.notSet;
    final address = (cashierAddress.trim().isNotEmpty && cashierAddress != 'N/A') ? cashierAddress : strings.notSet;

    final rawAvatar = cashierAvatarUrl;
    final avatarUrl = (rawAvatar != null &&
            rawAvatar.trim().isNotEmpty &&
            rawAvatar.trim() != 'N/A' &&
            rawAvatar.trim() != 'null' &&
            !rawAvatar.toLowerCase().contains('googleusercontent.com') &&
            !rawAvatar.toLowerCase().contains('ggpht.com') &&
            !rawAvatar.toLowerCase().contains('google.com') &&
            !rawAvatar.toLowerCase().contains('graph.facebook.com'))
        ? rawAvatar.trim()
        : null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================== AVATAR & NAME HEADER CARD ====================
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: onPickAndUploadAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? Colors.white54 : _brandColor, width: 2.5),
                          color: isDark ? const Color(0xFF1B2638) : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: _brandColor.withValues(alpha: 0.12),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? Image.network(
                                  avatarUrl,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Image.asset(
                                      'assets/piggytrunk_logo.png',
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, err, st) => Container(
                                        color: Colors.white,
                                        child: const Icon(Icons.person, size: 50, color: _brandColor),
                                      ),
                                    ),
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Image.asset(
                                    'assets/piggytrunk_logo.png',
                                    width: 76,
                                    height: 76,
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
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: _brandColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Cashier & POS Staff',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ==================== ACCOUNT DETAILS SECTION HEADER ====================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.accountDetails,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: onRestoreDefaultAvatar,
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, size: 16, color: titleColor),
                        const SizedBox(width: 4),
                        Text(
                          strings.reset,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: onShowEditProfileDialog,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: titleColor),
                        const SizedBox(width: 4),
                        Text(
                          strings.edit,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ==================== DETAILS LIST CARD ====================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
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
                _buildProfileRow(Icons.email_outlined, strings.emailAddress, email, isDark),
                Divider(height: 24, color: cardBorder),
                _buildProfileRow(Icons.phone_iphone_rounded, strings.phoneNumber, phone, isDark),
                Divider(height: 24, color: cardBorder),
                _buildProfileRow(Icons.store_outlined, 'Store / Branch Address', address, isDark),
                Divider(height: 24, color: cardBorder),
                _buildProfileRow(Icons.point_of_sale_rounded, strings.systemAccess, 'Cashier & POS Staff', isDark),
                Divider(height: 24, color: cardBorder),
                _buildProfileRow(Icons.verified_user_outlined, strings.accountStatus, strings.activeStatus, isDark),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ==================== SETTINGS / LANGUAGE PREFERENCE SECTION ====================
          Text(
            strings.settings,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 14),

          // ---- Language Preference Card ----
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.language_rounded,
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
                            strings.languagePreference,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: labelColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            strings.languageSubtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Language Toggle Option Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildToggleOption(
                        context: context,
                        isDark: isDark,
                        title: 'English',
                        emoji: '🇺🇸',
                        isSelected: currentLocale == 'en',
                        onTap: () => settingsProvider?.setLocale('en'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildToggleOption(
                        context: context,
                        isDark: isDark,
                        title: 'Filipino',
                        emoji: '🇵🇭',
                        isSelected: currentLocale == 'fil',
                        onTap: () => settingsProvider?.setLocale('fil'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ---- App Theme Card ----
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.palette_outlined,
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
                            strings.themePreference,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: labelColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            strings.themeSubtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Theme Toggle Option Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildToggleOption(
                        context: context,
                        isDark: isDark,
                        title: strings.lightMode,
                        icon: Icons.wb_sunny_rounded,
                        isSelected: currentThemeMode == ThemeMode.light,
                        onTap: () => settingsProvider?.setThemeMode(ThemeMode.light),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildToggleOption(
                        context: context,
                        isDark: isDark,
                        title: strings.darkMode,
                        icon: Icons.nights_stay_rounded,
                        isSelected: currentThemeMode == ThemeMode.dark,
                        onTap: () => settingsProvider?.setThemeMode(ThemeMode.dark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---- Security / Change Password Card ----
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
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
                            strings.passwordAndSecurity,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: labelColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            strings.updatePasswordSubtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => ChangePasswordModal.show(context),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF151F2E) : const Color(0xFFF8FAFC),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF28354A) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_reset_rounded,
                          color: isDark ? Colors.white : _brandColor,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings.changePassword,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : _brandColor,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ==================== LOGOUT BUTTON ====================
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: onHandleLogout,
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF151F2E) : Colors.transparent,
                side: BorderSide(
                  color: isDark ? const Color(0xFF28354A) : _brandColor,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.logout_rounded,
                    color: isDark ? Colors.white : _brandColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Unified toggle option for both Language and Theme cards.
  Widget _buildToggleOption({
    required BuildContext context,
    required bool isDark,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    String? emoji,
    IconData? icon,
  }) {
    final activeColor = isDark ? Colors.white : _brandColor;
    final activeTextColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inactiveBg = isDark ? const Color(0xFF151F2E) : const Color(0xFFF8FAFC);
    final inactiveBorder = isDark ? const Color(0xFF28354A) : const Color(0xFFE2E8F0);
    final inactiveText = isDark ? PiggyTrunkTheme.ptTextDark : _brandColor;
    final inactiveIconColor = isDark ? PiggyTrunkTheme.ptMutedDark : _brandColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : inactiveBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? Colors.white : _brandColor).withValues(alpha: isDark ? 0.15 : 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (emoji != null) ...[
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
            ],
            if (icon != null) ...[
              Icon(icon, size: 18, color: isSelected ? activeTextColor : inactiveIconColor),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeTextColor : inactiveText,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle_rounded, color: activeTextColor, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value, bool isDark) {
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final valueColor = isDark ? Colors.white : _brandColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: mutedColor, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
