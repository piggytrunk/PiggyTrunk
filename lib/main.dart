import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'screens/admin_login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/hog_raiser_screen.dart';
import 'screens/investments_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/inventory_print_preview_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/user_approvals_screen.dart';
import 'screens/batch_management_screen.dart';
import 'screens/mobile_app_distribution_screen.dart';
import 'screens/best_sellers_screen.dart';
import 'screens/demand_forecasting_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/admin_notifications_screen.dart';

// Mobile Web App screens and wrappers
import 'mobile_app/screens/login_screen.dart';
import 'mobile_app/screens/signup_screen.dart';
import 'mobile_app/screens/splash_screen.dart';
import 'mobile_app/screens/onboarding_screen.dart';
import 'mobile_app/screens/raiser/dashboard_screen.dart';
import 'mobile_app/screens/partner/partner_dashboard_screen.dart';
import 'mobile_app/screens/cashier/cashier_dashboard_screen.dart';
import 'mobile_app/screens/admin/admin_dashboard_screen.dart';
import 'mobile_app/services/locale_provider.dart';
import 'mobile_app/widgets/responsive_mobile_wrapper.dart';
import 'mobile_app/services/connectivity_service.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
bool isInitialLaunch = true;

const String _defaultSupabaseUrl = 'https://ywwwrshblzyqmxkbkxsp.supabase.co';
const String _defaultSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3d3dyc2hibHp5cW14a2JreHNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3MjU2MDMsImV4cCI6MjA5MzMwMTYwM30.ceKymQgbjU3IAbHxS2OUiOV9Mf5DxVxf9eBgzRuCHXo';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  String supabaseUrl = _defaultSupabaseUrl;
  String supabaseAnonKey = _defaultSupabaseAnonKey;

  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: '.env');
      final envUrl = dotenv.env['SUPABASE_URL']?.trim();
      final envKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();
      if (envUrl != null && envUrl.isNotEmpty) supabaseUrl = envUrl;
      if (envKey != null && envKey.isNotEmpty) supabaseAnonKey = envKey;
    } catch (_) {
      // Use defaults if .env is missing
    }
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase init warning: $e');
  }

  ConnectivityService.start();

  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService init warning: $e');
  }

  // Pre-load saved theme mode to prevent light/dark flicker on launch
  ThemeMode initialThemeMode = ThemeMode.light;
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme_mode');
    if (savedTheme == 'dark') {
      initialThemeMode = ThemeMode.dark;
    }
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => initialThemeMode),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          final themeMode = ref.watch(themeModeProvider);
          return SettingsProvider(
            initialThemeMode: themeMode,
            onThemeModeChanged: (newMode) {
              if (ref.read(themeModeProvider) != newMode) {
                ref.read(themeModeProvider.notifier).state = newMode;
              }
            },
            child: const MyApp(),
          );
        },
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = SettingsProvider.of(context);
    final themeMode = settings?.themeMode ?? ref.watch(themeModeProvider);

    // Host detection for Flutter Web (strip .vercel.app / .app suffix so main domain is not misidentified as mobile app)
    final host = kIsWeb ? Uri.base.host.toLowerCase() : '';
    final subdomain = host.endsWith('.vercel.app')
        ? host.substring(0, host.length - 11)
        : (host.endsWith('.app') ? host.substring(0, host.length - 4) : host);

    final uri = kIsWeb ? Uri.base : Uri();
    final bool isNativeMobile = !kIsWeb;
    final isLocalhost = host == 'localhost' || host == '127.0.0.1' || host.startsWith('192.168.');
    final hasAdminQuery = uri.queryParameters.containsKey('admin') || uri.queryParameters['role'] == 'admin';
    final hasAdminPath = uri.path.startsWith('/admin') ||
        uri.path.startsWith('/dashboard') ||
        uri.path.startsWith('/users') ||
        uri.path.startsWith('/raisers') ||
        uri.path.startsWith('/inventory') ||
        uri.path.startsWith('/investments') ||
        uri.path.startsWith('/pos') ||
        uri.path.startsWith('/batches') ||
        uri.path.startsWith('/notifications') ||
        uri.path.startsWith('/settings');

    final isAdminDomain = subdomain.contains('admin') || (isLocalhost && (hasAdminQuery || hasAdminPath));
    final isMobileDomain = isNativeMobile ||
        subdomain.contains('mobile') ||
        subdomain.startsWith('app') ||
        subdomain.endsWith('app') ||
        subdomain.contains('-app') ||
        subdomain.contains('app-') ||
        subdomain.contains('.app') ||
        subdomain == 'app';

    final String initialRoute;
    if (isAdminDomain) {
      initialRoute = '/login';
    } else if (isNativeMobile || isMobileDomain) {
      initialRoute = '/splash';
    } else {
      initialRoute = '/';
    }

    return MaterialApp(
      title: isAdminDomain ? 'Piggy Trunk Admin' : 'Piggy Trunk',
      theme: PiggyTrunkTheme.lightTheme,
      darkTheme: PiggyTrunkTheme.darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      themeAnimationCurve: Curves.linear,
      initialRoute: initialRoute,
      routes: {
        // Web Admin & Landing Routes
        '/': (context) => isAdminDomain
            ? const AdminLoginScreen()
            : ((isNativeMobile || isMobileDomain)
                ? const ResponsiveMobileWrapper(child: SplashScreen())
                : const LandingScreen()),
        '/login': (context) => (isAdminDomain || (isLocalhost && hasAdminPath))
            ? const AdminLoginScreen()
            : const ResponsiveMobileWrapper(child: LoginScreen()),
        '/admin': (context) => const AdminLoginScreen(),
        '/admin_login': (context) => const AdminLoginScreen(),
        '/landing': (context) => const LandingScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/raisers': (context) => const HogRaiserScreen(),
        '/investments': (context) => const InvestmentsScreen(),
        '/inventory': (context) => const InventoryScreen(),
        '/inventory/print-preview': (context) => const InventoryPrintPreviewScreen(),
        '/pos': (context) => const POSScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/users': (context) => const UserApprovalsScreen(),
        '/batches': (context) => const BatchManagementScreen(),
        '/notifications': (context) => const AdminNotificationsScreen(),
        '/mobile-app': (context) => const MobileAppDistributionScreen(),
        '/best-sellers': (context) => const BestSellersScreen(),
        '/forecasting': (context) => const DemandForecastingScreen(),

        // Mobile App on Web Routes (Responsive Wrapper applied)
        '/app': (context) => const ResponsiveMobileWrapper(child: SplashScreen()),
        '/mobile': (context) => const ResponsiveMobileWrapper(child: SplashScreen()),
        '/mobile_login': (context) => const ResponsiveMobileWrapper(child: LoginScreen()),
        '/signup': (context) => const ResponsiveMobileWrapper(child: SignUpScreen()),
        '/onboarding': (context) => const ResponsiveMobileWrapper(child: OnboardingScreen()),
        '/splash': (context) => const ResponsiveMobileWrapper(child: SplashScreen()),
        '/raiser_dashboard': (context) => const ResponsiveMobileWrapper(child: MobileDashboardScreen()),
        '/partner_dashboard': (context) => const ResponsiveMobileWrapper(child: PartnerDashboardScreen()),
        '/cashier_dashboard': (context) => const ResponsiveMobileWrapper(child: CashierDashboardScreen()),
        '/admin_dashboard': (context) => const ResponsiveMobileWrapper(child: AdminMobileDashboardScreen()),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
