import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_toast.dart';
import '../../utils/responsive.dart';
import 'scroll_reveal.dart';

class LandingDownloadSection extends StatefulWidget {
  final GlobalKey? downloadSectionKey;

  const LandingDownloadSection({
    super.key,
    this.downloadSectionKey,
  });

  @override
  State<LandingDownloadSection> createState() => _LandingDownloadSectionState();
}

class _LandingDownloadSectionState extends State<LandingDownloadSection> {
  static const String _apkUrl =
      'https://github.com/rewithjie/Piggy-Trunk/releases/latest/download/PiggyTrunkMobile.apk';
  static const String _webAppUrl = 'https://mobile.piggytrunk.site';

  String get _effectiveWebAppUrl => _webAppUrl;

  // 0 = Android APK, 1 = iOS Web App
  int _selectedPlatform = 0;

  Future<void> _handlePrimaryAction() async {
    final url = _selectedPlatform == 0 ? _apkUrl : _effectiveWebAppUrl;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Unable to open link: $e');
      }
    }
  }

  void _copyLink() {
    final url = _selectedPlatform == 0 ? _apkUrl : _effectiveWebAppUrl;
    Clipboard.setData(ClipboardData(text: url));
    AppToast.success(
      context,
      _selectedPlatform == 0
          ? 'APK download link copied to clipboard!'
          : 'Web App link copied to clipboard!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    final titleColor = isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText;
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final cardBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;

    final targetQrData = _selectedPlatform == 0 ? _apkUrl : _effectiveWebAppUrl;
    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=260x260&data=${Uri.encodeComponent(targetQrData)}';

    return Container(
      key: widget.downloadSectionKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : (isDesktop ? 64 : 32),
        vertical: isMobile ? 48 : 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'DOWNLOAD & INSTALL',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                'Ready to Transform Your Swine Operations?',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 28 : 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  'Download the Piggy Trunk Mobile APK directly to your Android device, or scan the QR code. For iOS, install instantly via Safari using "Add to Home Screen".',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: subtitleColor,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Main Download Card (QR + Step-by-Step Guide)
              LayoutBuilder(
                builder: (context, cardConstraints) {
                  final isWideCard = cardConstraints.maxWidth >= 820;

                  return HoverCard(
                    translateY: -5.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(isMobile ? 18 : 28),
                      child: isWideCard
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Left QR & Download Buttons
                                  Expanded(
                                    flex: 5,
                                    child: _buildQrAndActionGroup(
                                      context,
                                      qrUrl,
                                      isDark,
                                      cardBorder,
                                      titleColor,
                                      subtitleColor,
                                    ),
                                  ),
                                  const SizedBox(width: 32),
                                  // Vertical divider
                                  Container(
                                    width: 1,
                                    color: cardBorder,
                                  ),
                                  const SizedBox(width: 32),
                                  // Right Installation Guide
                                  Expanded(
                                    flex: 6,
                                    child: _buildInstallationGuide(
                                      context,
                                      isDark,
                                      cardBorder,
                                      titleColor,
                                      subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                _buildQrAndActionGroup(
                                  context,
                                  qrUrl,
                                  isDark,
                                  cardBorder,
                                  titleColor,
                                  subtitleColor,
                                ),
                                const SizedBox(height: 28),
                                Divider(color: cardBorder),
                                const SizedBox(height: 24),
                                _buildInstallationGuide(
                                  context,
                                  isDark,
                                  cardBorder,
                                  titleColor,
                                  subtitleColor,
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformTabs(bool isDark, Color cardBorder) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132035) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton(
            platformIndex: 0,
            icon: Icons.android_rounded,
            label: 'Android APK',
            activeColor: const Color(0xFF10B981),
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          _buildTabButton(
            platformIndex: 1,
            icon: Icons.apple,
            label: 'iOS',
            activeColor: const Color(0xFF3B82F6),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int platformIndex,
    required IconData icon,
    required String label,
    required Color activeColor,
    required bool isDark,
  }) {
    final isSelected = _selectedPlatform == platformIndex;

    return InkWell(
      onTap: () {
        if (_selectedPlatform != platformIndex) {
          setState(() {
            _selectedPlatform = platformIndex;
          });
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? activeColor.withValues(alpha: 0.22) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDark ? activeColor.withValues(alpha: 0.5) : const Color(0xFFCBD5E1))
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? activeColor
                  : (isDark ? PiggyTrunkTheme.ptMutedDark : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? PiggyTrunkTheme.ptMutedDark : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrBox(String qrUrl, bool isDark) {
    final isAndroid = _selectedPlatform == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              qrUrl,
              width: 180,
              height: 180,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF18314F),
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 180,
                  height: 180,
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: Icon(Icons.qr_code_2_rounded, size: 60, color: Color(0xFF64748B)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAndroid ? Icons.camera_alt_outlined : Icons.camera_enhance_outlined,
                size: 14,
                color: const Color(0xFF475569),
              ),
              const SizedBox(width: 6),
              Text(
                isAndroid ? 'Scan to Download APK' : 'Scan to Open in Safari',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrAndActionGroup(
    BuildContext context,
    String qrUrl,
    bool isDark,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
  ) {
    final border = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final isAndroid = _selectedPlatform == 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // OS Tabs
        _buildPlatformTabs(isDark, cardBorder),
        const SizedBox(height: 14),

        // QR Code Box
        _buildQrBox(qrUrl, isDark),
        const SizedBox(height: 18),

        // Action Buttons Group
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handlePrimaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white
                      : (isAndroid ? const Color(0xFF18314F) : const Color(0xFF0F172A)),
                  foregroundColor: isDark
                      ? const Color(0xFF0F172A)
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: Icon(
                  isAndroid ? Icons.download_rounded : Icons.open_in_browser_rounded,
                  size: 20,
                ),
                label: Text(
                  isAndroid ? 'Download APK File' : 'Open Web App in Safari',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Secondary Copy Link Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _copyLink,
                style: OutlinedButton.styleFrom(
                  foregroundColor: titleColor,
                  side: BorderSide(
                    color: border,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(
                  isAndroid ? 'Copy Download Link' : 'Copy Web App Link',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstallationGuide(
    BuildContext context,
    bool isDark,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
  ) {
    final isAndroid = _selectedPlatform == 0;
    final primaryColor = isAndroid ? const Color(0xFF10B981) : const Color(0xFF3B82F6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Header
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    isAndroid ? Icons.android_rounded : Icons.apple,
                    color: isAndroid
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isAndroid ? 'Android Installation Guide' : 'iOS Installation Guide',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isAndroid ? 'Direct APK' : 'PWA / Web App',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isAndroid
                  ? 'Because Piggy Trunk Mobile is distributed directly as an APK, follow these 3 simple steps:'
                  : 'APKs are exclusively for Android. For iOS devices, install Piggy Trunk directly as a Web App in 3 simple steps:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Steps (Unified style)
        if (isAndroid) ...[
          _buildStepItem(
            stepNumber: '1',
            title: 'Download the APK File',
            description:
                'Tap "Download APK File" on the left or scan the QR code using your phone camera.',
            icon: Icons.file_download_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildStepItem(
            stepNumber: '2',
            title: 'Allow Installation (Unknown Apps)',
            description:
                'If your mobile browser displays a security alert like "File might be harmful", tap "Download anyway" and enable "Allow from this source / Install".',
            icon: Icons.security_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildStepItem(
            stepNumber: '3',
            title: 'Launch & Sign In',
            description:
                'Once installed, tap the Piggy Trunk icon on your home screen and log in with your verified Hog Raiser or Partner account.',
            icon: Icons.check_circle_outline_rounded,
            isDark: isDark,
          ),
        ] else ...[
          _buildStepItem(
            stepNumber: '1',
            title: 'Open Mobile App in Safari',
            description:
                'Scan the QR code with your iPhone camera or open ${_effectiveWebAppUrl.replaceFirst("https://", "")} directly in Safari.',
            icon: Icons.explore_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildStepItem(
            stepNumber: '2',
            title: 'Tap the Share Icon',
            description:
                'Tap the Share icon (the square icon with an upward arrow) at the bottom toolbar of Safari.',
            icon: Icons.ios_share_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildStepItem(
            stepNumber: '3',
            title: 'Scroll down & tap "Add to Home Screen"',
            description:
                'Select "Add to Home Screen" to install Piggy Trunk. It will appear on your home screen and run full screen just like a native app.',
            icon: Icons.add_to_home_screen_rounded,
            isDark: isDark,
          ),
        ],

        const SizedBox(height: 18),

        // Quick platform switch prompt banner at the bottom
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF132035) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              Icon(
                isAndroid ? Icons.apple : Icons.android_rounded,
                size: 16,
                color: subtitleColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAndroid
                      ? 'Using iOS? Switch to iOS guide.'
                      : 'Using Android? Switch to Android guide.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedPlatform = isAndroid ? 1 : 0;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    isAndroid ? 'Switch to iOS' : 'Switch to Android',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isAndroid ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required bool isDark,
  }) {
    final stepColor = isDark ? Colors.white : const Color(0xFF18314F);
    final stepBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFF18314F).withValues(alpha: 0.08);
    final stepBorder = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : const Color(0xFF18314F).withValues(alpha: 0.15);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: stepBg,
            shape: BoxShape.circle,
            border: Border.all(color: stepBorder),
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: stepColor,
              ),
            ),
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
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFF1F5F9) : PiggyTrunkTheme.ptPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF5D7391),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
