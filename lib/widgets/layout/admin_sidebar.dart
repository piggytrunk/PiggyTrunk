import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_text_styles.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/hog_raiser_screen.dart';
import '../../screens/investments_screen.dart';
import '../../screens/inventory_screen.dart';
import '../../screens/pos_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/user_approvals_screen.dart';
import '../../screens/batch_management_screen.dart';
import '../../screens/mobile_app_distribution_screen.dart';

final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

class AdminSidebar extends ConsumerStatefulWidget {
  final String currentRoute;
  final VoidCallback onLogout;
  final bool isDrawer;
  final bool showHeader;

  const AdminSidebar({
    super.key,
    required this.currentRoute,
    required this.onLogout,
    this.isDrawer = false,
    this.showHeader = false,
  });

  @override
  ConsumerState<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends ConsumerState<AdminSidebar> {
  late List<SidebarItem> mainItems;
  late List<SidebarItem> footerItems;
  String? _hoveredRoute;

  @override
  void initState() {
    super.initState();
    mainItems = [
      SidebarItem(
        label: 'Dashboard',
        iconAsset: 'assets/icons/sidebar/dashboard.svg',
        fallbackIcon: Icons.apps_outlined,
        route: '/dashboard',
      ),
      SidebarItem(
        label: 'Hog Raiser',
        iconAsset: 'assets/icons/sidebar/raisers.svg',
        fallbackIcon: Icons.group_outlined,
        route: '/raisers',
      ),
      SidebarItem(
        label: 'User Approvals',
        iconAsset: '',
        fallbackIcon: Icons.people_outline,
        route: '/users',
      ),
      SidebarItem(
        label: 'Batch Management',
        iconAsset: '',
        fallbackIcon: Icons.layers_outlined,
        route: '/batches',
      ),
      SidebarItem(
        label: 'Investment Management',
        iconAsset: 'assets/icons/sidebar/investment.svg',
        fallbackIcon: Icons.trending_up_outlined,
        route: '/investments',
      ),
      SidebarItem(
        label: 'Inventory',
        iconAsset: 'assets/icons/sidebar/pos.svg',
        fallbackIcon: Icons.description_outlined,
        route: '/inventory',
      ),
      SidebarItem(
        label: 'POS',
        iconAsset: 'assets/icons/sidebar/inventory.svg',
        fallbackIcon: Icons.point_of_sale_outlined,
        route: '/pos',
      ),
      SidebarItem(
        label: 'Mobile App',
        iconAsset: '',
        fallbackIcon: Icons.get_app_outlined,
        route: '/mobile-app',
      ),
    ];

    footerItems = [
      SidebarItem(
        label: 'Theme',
        iconAsset: 'assets/icons/sidebar/theme.svg',
        fallbackIcon: Icons.dark_mode_outlined,
        route: '/theme',
      ),
      SidebarItem(
        label: 'Settings',
        iconAsset: 'assets/icons/sidebar/settings.svg',
        fallbackIcon: Icons.settings_outlined,
        route: '/settings',
      ),
      SidebarItem(
        label: 'Sign out',
        iconAsset: 'assets/icons/sidebar/logout.svg',
        fallbackIcon: Icons.logout_outlined,
        route: '/logout',
      ),
    ];
  }

  void _navigate(String route) {
    if (route == '/theme') {
      final current = ref.read(themeModeProvider);
      final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      ref.read(themeModeProvider.notifier).state = next;
      return;
    }

    if (route == '/logout') {
      if (widget.isDrawer) {
        Navigator.of(context).pop();
      }
      _handleLogout();
      return;
    } else {
      if (widget.currentRoute == route) {
        if (widget.isDrawer) {
          Navigator.of(context).pop();
        }
        return;
      }
      if (widget.isDrawer) {
        Navigator.of(context).pop();
      }
      final screen = _screenForRoute(route);
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.removeCurrentSnackBar();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          settings: RouteSettings(name: route),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      await AuthService().logout();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
    widget.onLogout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xff151f2e) : PiggyTrunkTheme.ptSurface;
    final borderColor = isDark ? const Color(0xff28354a) : PiggyTrunkTheme.ptBorder;
    final textColor = isDark ? const Color(0xffecf2ff) : PiggyTrunkTheme.ptText;
    final isExpanded = widget.isDrawer || ref.watch(sidebarExpandedProvider);

    final screenHeight = MediaQuery.of(context).size.height;
    final isUltraCompact = screenHeight < 640;
    final isCompactHeight = screenHeight < 840;

    final targetWidth = widget.isDrawer
        ? null
        : (isExpanded ? (isCompactHeight ? 255.0 : 275.0) : 56.0);

    return Container(
      width: targetWidth,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          right: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showExpandedContent = widget.isDrawer || constraints.maxWidth >= 200;

          Widget buildMainItems() {
            return Padding(
              padding: EdgeInsets.symmetric(
                vertical: isUltraCompact ? 2 : (isCompactHeight ? 4 : 8),
                horizontal: isCompactHeight ? 6 : 8,
              ),
              child: Column(
                children: mainItems
                    .map((item) => _buildNavItem(
                          item,
                          widget.currentRoute == item.route,
                          showExpandedContent,
                          isCompactHeight,
                          isUltraCompact,
                        ))
                    .toList(),
              ),
            );
          }

          Widget buildFooterItems() {
            return Padding(
              padding: EdgeInsets.symmetric(
                vertical: isUltraCompact ? 2 : (isCompactHeight ? 4 : 8),
                horizontal: isCompactHeight ? 6 : 8,
              ),
              child: Column(
                children: footerItems
                    .map((item) => _buildNavItem(
                          item,
                          false,
                          showExpandedContent,
                          isCompactHeight,
                          isUltraCompact,
                        ))
                    .toList(),
              ),
            );
          }

          final headerHeight = isUltraCompact
              ? 56.0
              : (isCompactHeight ? 66.0 : 70.0);
          final logoSize = showExpandedContent
              ? (isUltraCompact ? 44.0 : (isCompactHeight ? 48.0 : 50.0))
              : (isUltraCompact ? 38.0 : (isCompactHeight ? 40.0 : 42.0));

          final shouldShowHeader = widget.showHeader || widget.isDrawer;

          return Column(
            children: [
              if (shouldShowHeader)
                Container(
                  height: headerHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    border: Border(
                      bottom: BorderSide(
                        color: borderColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: logoSize,
                          height: logoSize,
                          child: Image.asset(
                            'assets/piggytrunk_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Piggy Trunk',
                          style: AppTextStyles.sidebarBrand(textColor).copyWith(
                            fontSize: isCompactHeight ? 18.5 : 20.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (widget.isDrawer)
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: textColor,
                            size: isCompactHeight ? 20 : 24,
                          ),
                          tooltip: 'Close menu',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      else
                        _buildSidebarToggle(isExpanded, isCompactHeight),
                    ],
                  ),
                ),

              /// Main Navigation (Fills available space in the middle, zero scroll on 14" screens)
              Expanded(
                child: ScrollConfiguration(
                  behavior: const ScrollBehavior().copyWith(scrollbars: false),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    children: [
                      buildMainItems(),
                    ],
                  ),
                ),
              ),

              /// Divider before Footer
              Divider(
                color: borderColor,
                thickness: 1,
                height: 1,
              ),

              /// Footer (Theme, Settings, Sign out) PINNED TO BOTTOM
              buildFooterItems(),
            ],
          );
        },
      ),
    );
  }

  Widget _screenForRoute(String route) {
    switch (route) {
      case '/dashboard':
        return const DashboardScreen();
      case '/raisers':
        return const HogRaiserScreen();
      case '/investments':
        return const InvestmentsScreen();
      case '/inventory':
        return const InventoryScreen();
      case '/pos':
        return const POSScreen();
      case '/settings':
        return const SettingsScreen();
      case '/users':
        return const UserApprovalsScreen();
      case '/batches':
        return const BatchManagementScreen();
      case '/mobile-app':
        return const MobileAppDistributionScreen();
      default:
        return const DashboardScreen();
    }
  }

  /// Build individual navigation item with hover effects & adaptive height
  Widget _buildNavItem(
    SidebarItem item,
    bool isActive,
    bool isExpanded,
    bool isCompactHeight,
    bool isUltraCompact,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xff28354a) : PiggyTrunkTheme.ptBorder;
    final textColor = isDark ? const Color(0xffecf2ff) : PiggyTrunkTheme.ptText;
    final mutedColor = isDark ? const Color(0xff9cb0c9) : PiggyTrunkTheme.ptMuted;

    final itemVerticalMargin = isUltraCompact
        ? 1.0
        : (isCompactHeight ? 1.5 : 3.0);
    final itemVerticalPadding = isUltraCompact
        ? 5.5
        : (isCompactHeight ? 6.5 : 9.5);
    final iconSize = isCompactHeight ? 18.0 : 20.0;
    final fontSize = isCompactHeight ? 12.5 : 13.5;

    return MouseRegion(
      onEnter: (_) {
        if (!mounted) return;
        setState(() {
          _hoveredRoute = item.route;
        });
      },
      onExit: (_) {
        if (!mounted) return;
        setState(() {
          _hoveredRoute = null;
        });
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _navigate(item.route),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: itemVerticalMargin),
          padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? 10 : 0,
            vertical: itemVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? borderColor.withValues(alpha: 0.5)
                : _hoveredRoute == item.route
                    ? borderColor.withValues(alpha: 0.25)
                    : Colors.transparent,
            border: Border.all(
              color: isActive
                  ? borderColor
                  : _hoveredRoute == item.route
                      ? borderColor.withValues(alpha: 0.5)
                      : Colors.transparent,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment:
                isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              /// Icon
              Tooltip(
                message: item.label,
                waitDuration: const Duration(milliseconds: 300),
                child: SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: item.iconAsset.isNotEmpty
                      ? SvgPicture.asset(
                          item.iconAsset,
                          width: iconSize,
                          height: iconSize,
                          colorFilter: ColorFilter.mode(
                            isActive ? textColor : mutedColor,
                            BlendMode.srcIn,
                          ),
                          placeholderBuilder: (context) => Icon(
                            item.fallbackIcon,
                            size: iconSize,
                            color: isActive ? textColor : mutedColor,
                          ),
                        )
                      : Icon(
                          item.fallbackIcon,
                          size: iconSize,
                          color: isActive ? textColor : mutedColor,
                        ),
                ),
              ),
              if (isExpanded) ...[
                SizedBox(width: isCompactHeight ? 12 : 14),

                /// Label
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTextStyles.sidebarLabel(
                      isActive ? textColor : mutedColor,
                    ).copyWith(
                      fontSize: fontSize,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarToggle(bool isExpanded, bool isCompactHeight) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xffecf2ff) : PiggyTrunkTheme.ptText;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ref.read(sidebarExpandedProvider.notifier).state = !isExpanded;
        },
        child: Tooltip(
          message: isExpanded ? 'Collapse sidebar' : 'Expand sidebar',
          child: Container(
            padding: EdgeInsets.all(isCompactHeight ? 5 : 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.transparent,
            ),
            child: Icon(
              isExpanded ? Icons.menu_open_outlined : Icons.menu_outlined,
              color: textColor,
              size: isCompactHeight ? 18 : 20,
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarItem {
  final String label;
  final String iconAsset;
  final IconData fallbackIcon;
  final String route;

  SidebarItem({
    required this.label,
    required this.iconAsset,
    required this.fallbackIcon,
    required this.route,
  });
}
