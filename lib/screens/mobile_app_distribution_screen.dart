import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/app_toast.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/common/shimmer_loading.dart';
import '../utils/responsive.dart';

class MobileAppDistributionScreen extends StatefulWidget {
  const MobileAppDistributionScreen({super.key});

  @override
  State<MobileAppDistributionScreen> createState() => _MobileAppDistributionScreenState();
}

class _MobileAppDistributionScreenState extends State<MobileAppDistributionScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _urlCtrl = TextEditingController();

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgDark => _isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
  Color get _panelStart => _isDark ? const Color(0xFF16253B) : Colors.white;
  Color get _panelBorder => _isDark ? const Color(0xFF2D4263) : const Color(0xFFE3EAF3);
  Color get _titleColor => _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18314F);
  Color get _subtitleColor => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF5D7391);
  Color get _fieldBg => _isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF4FD);
  Color get _fieldBorder => _isDark ? const Color(0xFF334155) : const Color(0xFFB4C9E6);
  Color get _fieldText => _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18314F);
  Color get _iconColor => _isDark ? const Color(0xFF38BDF8) : PiggyTrunkTheme.ptPrimary;

  void _copyToClipboard() {
    final text = _urlCtrl.text.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    AppToast.success(context, 'Download link copied to clipboard!');
  }

  @override
  void initState() {
    super.initState();
    final session = _supabase.auth.currentSession;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return;
    }
    _urlCtrl.text = 'https://piggytrunk.site/download/apk';
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = Responsive.isSmallScreen(context);
    final isMobile = Responsive.isMobile(context);
    final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=260x260&data=${Uri.encodeComponent(_urlCtrl.text.trim())}';

    return Scaffold(
      backgroundColor: _bgDark,
      drawer: isSmall
          ? Drawer(
              backgroundColor: _panelStart,
              child: AdminSidebar(
                currentRoute: '/mobile-app',
                onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
                isDrawer: true,
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenTopBar(),
          Expanded(
            child: Row(
              children: [
                if (!isSmall)
                  AdminSidebar(
                    currentRoute: '/mobile-app',
                    onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 24,
                      vertical: isMobile ? 16 : 32,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        decoration: BoxDecoration(
                          color: _panelStart,
                          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                          border: Border.all(color: _panelBorder, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: _isDark ? 0.5 : 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(isMobile ? 16 : 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // PiggyTrunk Logo Header (Edge-to-Edge Circle Fit)
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isDark ? const Color(0xFF385277) : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/piggytrunk_logo.png',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'PiggyTrunk Mobile App',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _titleColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Scan QR Code or copy link to install PiggyTrunk for Android',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: _subtitleColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),

                            // QR Code Card Container
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Image.network(
                                    qrUrl,
                                    width: 220,
                                    height: 220,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return ShimmerBox(
                                        width: 220,
                                        height: 220,
                                        borderRadius: BorderRadius.circular(12),
                                        isDark: _isDark,
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 220,
                                        height: 220,
                                        color: const Color(0xFFF1F5F9),
                                        child: const Center(
                                          child: Icon(Icons.qr_code_2_rounded, size: 80, color: Color(0xFF64748B)),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Scan with phone camera',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // URL Field with Copy Action
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'APK Download Link',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _titleColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: _fieldBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _fieldBorder),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(Icons.link_rounded, color: _iconColor, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _urlCtrl,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            color: _fieldText,
                                          ),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 18),
                                        tooltip: 'Copy Link',
                                        color: _iconColor,
                                        onPressed: _copyToClipboard,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Version & Auto-Update Status Card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _fieldBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _fieldBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.cloud_done_rounded,
                                      color: PiggyTrunkTheme.ptSuccess,
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
                                              'Current Mobile Release: v1.0.0',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: _titleColor,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '25.58 MB',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: PiggyTrunkTheme.ptSuccess,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'In-app update checks & Supabase storage limit (≤ 26 MB) compliant',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: _subtitleColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Security Notice Box
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _isDark
                                    ? const Color(0xFF451A03).withValues(alpha: 0.6)
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isDark ? const Color(0xFFD97706) : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    color: _isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Notice: Please share this download link or QR code only with trusted team members and authorized personnel within your organization.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: _isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
