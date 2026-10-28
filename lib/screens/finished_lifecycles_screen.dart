import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/dashboard/cycle_history_drawer.dart';
import 'dashboard_screen.dart';

class FinishedLifecyclesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> completedRaisers;

  const FinishedLifecyclesScreen({super.key, required this.completedRaisers});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = Responsive.isSmallScreen(context);
    final isMobile = Responsive.isMobile(context);

    final bg = isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
    final surface = isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface;
    final border = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final titleColor = isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText;
    final hint = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final brandPrimary = isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;

    return Scaffold(
      backgroundColor: bg,
      drawer: isSmall
          ? Drawer(
              backgroundColor: surface,
              child: AdminSidebar(
                currentRoute: '/dashboard',
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
                    currentRoute: '/dashboard',
                    onLogout: () =>
                        Navigator.of(context).pushReplacementNamed('/login'),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isMobile ? 12 : 20),
                    child: Container(
                      width: double.infinity,
                      decoration: isMobile
                          ? null
                          : BoxDecoration(
                              color: surface.withValues(alpha: isDark ? 0.5 : 1.0),
                              border: Border.all(
                                color: border,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                      padding: EdgeInsets.all(isMobile ? 0 : 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop();
                                  } else {
                                    Navigator.of(context).pushReplacement(
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation,
                                                secondaryAnimation) =>
                                            const DashboardScreen(),
                                        settings: const RouteSettings(
                                            name: '/dashboard'),
                                        transitionDuration: Duration.zero,
                                        reverseTransitionDuration:
                                            Duration.zero,
                                      ),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E2F47)
                                        : const Color(0xFFEEF4FD),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: border),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    size: 20,
                                    color: brandPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E3A8A)
                                          .withValues(alpha: 0.35)
                                      : const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.verified_rounded,
                                  size: 20,
                                  color: isDark
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFF1E40AF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Finished Lifecycles',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: isMobile ? 18 : 22,
                                              fontWeight: FontWeight.w800,
                                              color: titleColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 9, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF1E2F47)
                                                : const Color(0xFFEEF4FD),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(color: border),
                                          ),
                                          child: Text(
                                            '${completedRaisers.length}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? hint
                                                  : PiggyTrunkTheme.ptPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Batches that completed all feeding stages',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: isMobile ? 11.5 : 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: hint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Divider(
                            color: border.withValues(alpha: 0.6),
                            height: 1,
                            thickness: 1,
                          ),
                          const SizedBox(height: 24),
                          CycleHistoryDrawer.buildContent(
                            context: context,
                            completedRaisers: completedRaisers,
                            isDark: isDark,
                            cardBorder: border,
                            titleColor: titleColor,
                            hintText: hint,
                            onNavigateToBatches: () => Navigator.of(context)
                                .pushReplacementNamed('/batches'),
                          ),
                        ],
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
