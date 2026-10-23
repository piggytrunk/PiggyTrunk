import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../services/locale_provider.dart';
import '../../../utils/app_strings.dart';
import '../../../widgets/change_password_modal.dart';

class RaiserProfileTab extends StatelessWidget {
  final Map<String, dynamic> raiserData;
  final VoidCallback onPickAndUploadAvatar;
  final VoidCallback onRestoreDefaultAvatar;
  final VoidCallback? onResetProfile;
  final VoidCallback onShowEditProfileDialog;
  final VoidCallback onHandleSignOut;

  static const Color _brandColor = Color(0xFF18314F);

  static String _formatStage(dynamic rawStage, String pigType, AppStrings strings) {
    if (rawStage == null) return strings.notSet;
    final s = rawStage.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'N/A' || s == 'None' || s == strings.notSet) {
      return strings.notSet;
    }
    final id = int.tryParse(s);
    if (id != null) {
      final isSow = pigType.toLowerCase().contains('sow') || pigType.toLowerCase().contains('breed');
      final fatteningStages = const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'];
      final sowStages = const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation'];
      final list = isSow ? sowStages : fatteningStages;
      if (id >= 1 && id <= list.length) return list[id - 1];
      return 'Booster';
    }
    return s;
  }

  /// Formats fetched per-assignment stages for the Profile card.
  /// Fattening is always listed before Sow / Breeding.
  static String _formatProfileFeedsStage(String stage, String pigType) {
    final normalizedType = pigType.toLowerCase();
    final hasFattening = normalizedType.contains('fatten');
    final hasSow = normalizedType.contains('sow') || normalizedType.contains('breed');

    if (hasFattening && hasSow) {
      final stages = stage.split(' ${String.fromCharCode(0x2022)} ');
      final fatteningStage = stages.isNotEmpty
          ? stages.first.replaceFirst(RegExp(r'^Fattening:\s*'), '').trim()
          : stage;
      final sowStage = stages.length > 1
          ? stages[1].replaceFirst(RegExp(r'^Sow:\s*'), '').trim()
          : stage;
      return 'Fattening - $fatteningStage\nSow / Breeding - $sowStage';
    }

    if (hasSow) return 'Sow / Breeding - $stage';
    if (hasFattening) return 'Fattening - $stage';
    return stage;
  }

  const RaiserProfileTab({
    super.key,
    required this.raiserData,
    required this.onPickAndUploadAvatar,
    required this.onRestoreDefaultAvatar,
    this.onResetProfile,
    required this.onShowEditProfileDialog,
    required this.onHandleSignOut,
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
    final currentThemeMode = settingsProvider?.themeMode ?? (isDark ? ThemeMode.dark : ThemeMode.light);

    final name = (raiserData['name'] ?? '').toString().trim().isNotEmpty
        ? (raiserData['name'] as String)
        : strings.hogRaiserRole;
    final email = (raiserData['email'] ?? '').toString().trim().isNotEmpty
        ? (raiserData['email'] as String)
        : 'N/A';
    final phone = (raiserData['phone'] != null && raiserData['phone'] != 'N/A' && raiserData['phone'].toString().trim().isNotEmpty)
        ? raiserData['phone'].toString()
        : strings.notSet;
    final rawAddress = raiserData['address']?.toString().trim();
    final bool isAddressMissing = rawAddress == null ||
        rawAddress.isEmpty ||
        rawAddress == 'N/A' ||
        rawAddress == 'null' ||
        rawAddress == strings.notSet ||
        rawAddress == 'Not Set' ||
        rawAddress == 'Farm Location Not Set';
    final address = !isAddressMissing ? rawAddress : strings.notSet;
    final type = (raiserData['pig_type'] != null && raiserData['pig_type'] != 'N/A' && raiserData['pig_type'] != 'None')
        ? raiserData['pig_type'].toString()
        : strings.unassigned;
    final stage = _formatStage(raiserData['lifecycle_stage'], type, strings);
    final profileFeedsStage = _formatProfileFeedsStage(stage, type);
    final rawAvatar = raiserData['avatar_url'] as String?;
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 108),
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
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : _brandColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
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
                    strings.hogRaiserRole,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ==================== FARM LOCATION REMINDER BANNER (IF MISSING) ====================
          if (isAddressMissing) ...[
            GestureDetector(
              onTap: onShowEditProfileDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF26190D) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF92400E) : const Color(0xFFFBBF24),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                strings.farmLocationMissing,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF451A03) : const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  strings.actionNeeded,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            strings.farmLocationMissingDesc,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 8),

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
                    onTap: onResetProfile ?? onRestoreDefaultAvatar,
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
                _buildAddressRow(
                  context: context,
                  strings: strings,
                  address: address,
                  isAddressMissing: isAddressMissing,
                  isDark: isDark,
                  onTap: onShowEditProfileDialog,
                ),
                Divider(height: 24, color: cardBorder),
                _buildProfileRow(Icons.pets_outlined, strings.pigTypeAssignment, type, isDark),
                Divider(height: 24, color: cardBorder),
                _buildProfileRow(Icons.restaurant_rounded, strings.currentFeedsStage, profileFeedsStage, isDark),
                Divider(height: 24, color: cardBorder),
                _buildProfileRow(Icons.security_rounded, strings.systemAccess, strings.hogRaiserRole, isDark),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ==================== SETTINGS / PREFERENCES SECTION ====================
          Text(
            strings.settings,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 14),

          // ---- Unified Grouped Settings Card ----
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cardBorder),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildSettingsIcon(
                        icon: Icons.translate_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          strings.languagePreference,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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

                Divider(height: 1, thickness: 1, color: cardBorder),

                // 2. App Theme Row (Compact Light / Dark Toggle)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildSettingsIcon(
                        icon: Icons.palette_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          strings.themePreference,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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

                Divider(height: 1, thickness: 1, color: cardBorder),

                // 3. Password & Security Row (Tappable Tile with Chevron)
                Material(
                  color: Colors.transparent,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                  child: InkWell(
                    onTap: () => ChangePasswordModal.show(context),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          _buildSettingsIcon(
                            icon: Icons.shield_outlined,
                            isDark: isDark,
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
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: subtitleColor,
                          ),
                        ],
                      ),
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
              onPressed: onHandleSignOut,
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
          const SizedBox(height: 18),
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

  Widget _buildProfileRow(IconData icon, String label, String value, bool isDark) {
    final mutedColor = isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted;
    final valueColor = isDark ? Colors.white : _brandColor;

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
        const SizedBox(width: 14),
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
              const SizedBox(height: 3),
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

  Widget _buildAddressRow({
    required BuildContext context,
    required AppStrings strings,
    required String address,
    required bool isAddressMissing,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final mutedColor = isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted;
    final iconColor = isDark ? Colors.white70 : PiggyTrunkTheme.ptMuted;
    final valueColor = isDark ? Colors.white : _brandColor;

    if (!isAddressMissing) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
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
                    Icons.location_on_outlined,
                    color: isDark ? Colors.white : _brandColor,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.farmAddress,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      address,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: valueColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 16, color: iconColor),
            ],
          ),
        ),
      );
    }

    // Address is missing - show warning exclamation icon and Action Needed badge!
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF26190D).withValues(alpha: 0.7) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF78350F) : const Color(0xFFFECACA),
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFFB45309) : const Color(0xFFFCA5A5),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        strings.farmAddress,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF451A03) : const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          strings.actionNeeded,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    strings.locationNotSetTap,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
              size: 20,
            ),
          ],
        ),
      ),
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

