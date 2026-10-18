import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/raiser/dashboard_screen.dart';
import 'screens/partner/partner_dashboard_screen.dart';
import 'screens/cashier/cashier_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'services/locale_provider.dart';
import 'widgets/responsive_mobile_wrapper.dart';
import 'services/connectivity_service.dart';

const String _defaultSupabaseUrl = 'https://ywwwrshblzyqmxkbkxsp.supabase.co';
const String _defaultSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3d3dyc2hibHp5cW14a2JreHNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3MjU2MDMsImV4cCI6MjA5MzMwMTYwM30.ceKymQgbjU3IAbHxS2OUiOV9Mf5DxVxf9eBgzRuCHXo';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String supabaseUrl = _defaultSupabaseUrl;
  String supabaseAnonKey = _defaultSupabaseAnonKey;

  try {
    await dotenv.load(fileName: '.env');
    final envUrl = dotenv.env['SUPABASE_URL']?.trim();
    final envKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();
    if (envUrl != null && envUrl.isNotEmpty) supabaseUrl = envUrl;
    if (envKey != null && envKey.isNotEmpty) supabaseAnonKey = envKey;
  } catch (_) {
    // Ignore missing env file during local development.
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

  // Initialize Native Device Notifications safely
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService init warning: $e');
  }

  runApp(
    const SettingsProvider(
      child: HogRaiserMobileApp(),
    ),
  );
}

class HogRaiserMobileApp extends StatelessWidget {
  const HogRaiserMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsProvider.of(context);
    final themeMode = settings?.themeMode ?? ThemeMode.light;

    return MaterialApp(
      title: 'Piggy Trunk',
      debugShowCheckedModeBanner: false,
      theme: PiggyTrunkTheme.lightTheme.copyWith(
        snackBarTheme: SnackBarThemeData(
          contentTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      darkTheme: PiggyTrunkTheme.darkTheme.copyWith(
        snackBarTheme: SnackBarThemeData(
          contentTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      themeMode: themeMode,
      builder: (context, child) {
        return ResponsiveMobileWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/raiser_dashboard': (context) => const MobileDashboardScreen(),
        '/partner_dashboard': (context) => const PartnerDashboardScreen(),
        '/cashier_dashboard': (context) => const CashierDashboardScreen(),
        '/admin_dashboard': (context) => const AdminMobileDashboardScreen(),
      },
    );
  }
}
