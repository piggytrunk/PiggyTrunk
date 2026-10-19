import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:piggytrunk/services/notification_service.dart';
import '../services/google_auth_service.dart';
import '../services/auth_session_service.dart';
import '../utils/screen_fit_util.dart';
import '../widgets/piggy_toast.dart';
import '../widgets/forgot_password_modal.dart';
import '../widgets/install_pwa_banner.dart';
import '../services/locale_provider.dart';
import '../../services/app_update_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/no_connection_modal.dart';
import '../../theme/app_theme.dart';


const String googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
  <path fill="none" d="M0 0h48v48H0z"/>
</svg>
''';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _targetRole = 'hog_raiser';
  String? _errorMessage;
  String? _identifierError;
  String? _passwordError;
  StreamSubscription<AuthState>? _authSubscription;

  final GoogleAuthService _googleAuthService = GoogleAuthService();

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRedirectOAuthSession();
      AppUpdateService.instance.promptUpdateIfAvailable(context);
    });
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        _checkRedirectOAuthSession();
      }
    });
  }

  Future<void> _checkRedirectOAuthSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.user.email != null) {
      if (_isGoogleLoading) return;
      setState(() => _isGoogleLoading = true);
      final result = await _googleAuthService.handleIncomingOAuthSession(targetRole: _targetRole);
      if (result != null && mounted) {
        await _processGoogleAuthResult(result);
      } else {
        if (mounted) setState(() => _isGoogleLoading = false);
      }
    }
  }

  bool _isDefaultSystemEmail(String text) {
    final cleaned = text.trim().toLowerCase();
    if (cleaned.isEmpty) return false;
    return cleaned == 'admin' ||
        cleaned == 'admin@piggytrunk.com' ||
        cleaned == 'admin@gmail.com' ||
        cleaned == 'piggytrunk@gmail.com';
  }

  bool _isValidEmailFormat(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return false;
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(cleaned);
  }

  bool _roleInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_roleInitialized) {
      _roleInitialized = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _targetRole = args;
      } else if (args is Map && args['role'] != null) {
        _targetRole = args['role'].toString();
      }
      _targetRole ??= 'hog_raiser';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_identifierError != null || _passwordError != null || _errorMessage != null) {
      setState(() {
        _identifierError = null;
        _passwordError = null;
        _errorMessage = null;
      });
    }
  }

  Widget _buildInlineError(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1.5),
            child: Icon(
              Icons.error_outline_rounded,
              size: 14,
              color: Color(0xFFE53935),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePasswordSignIn() async {
    _clearErrors();

    final String identifier = _usernameController.text.trim();
    final String password = _passwordController.text;

    String? idErr;
    String? passErr;

    final cleanId = identifier.trim().toLowerCase();
    if (cleanId.isEmpty) {
      idErr = 'Please enter your full name or email address.';
    } else if (cleanId.contains('gmail') && !cleanId.contains('@')) {
      idErr = 'Please include "@" in your email address (e.g. name@gmail.com).';
    }

    if (password.isEmpty) {
      passErr = 'Please enter your password.';
    } else if (password.length < 6) {
      passErr = 'Password must be at least 6 characters.';
    }

    if (idErr != null || passErr != null) {
      setState(() {
        _identifierError = idErr;
        _passwordError = passErr;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (!await ConnectivityService.hasInternet()) {
      if (mounted) {
        setState(() => _isLoading = false);
        showNoConnectionModal(context, onRetry: _handlePasswordSignIn);
      }
      return;
    }

    String emailToUse = identifier;

    try {
      if (!identifier.contains('@')) {
        try {
          final res = await Supabase.instance.client
              .from('app_users')
              .select('email')
              .ilike('name', identifier)
              .maybeSingle();

          if (res != null && res['email'] != null) {
            emailToUse = res['email'];
          }
        } catch (_) {
          // Gracefully fallback if username lookup fails
        }
      }

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: emailToUse,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Invalid account credentials.');
      }

      await _verifyAndProcessAuthSession(
        email: user.email ?? emailToUse,
        userId: user.id,
        loginMethod: 'password',
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (e is AuthRetryableFetchException || ConnectivityService.isNetworkError(e)) {
        if (mounted) showNoConnectionModal(context, onRetry: _handlePasswordSignIn);
      } else if (msg.contains('email not confirmed')) {
        if (mounted) _showUnconfirmedEmailDialog(emailToUse);
      } else {
        // Smart check: Does this user exist in app_users?
        bool userExists = false;
        try {
          final existing = await Supabase.instance.client
              .from('app_users')
              .select('user_id')
              .or('email.ilike.$identifier,name.ilike.$identifier')
              .maybeSingle();
          userExists = existing != null;
        } catch (_) {}

        if (!userExists) {
          setState(() {
            _identifierError = 'No registered account found. Please create an account before signing in.';
          });
        } else {
          setState(() {
            _passwordError = 'Incorrect password. Please verify and try again.';
          });
        }
      }
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        if (mounted) showNoConnectionModal(context, onRetry: _handlePasswordSignIn);
      } else {
        setState(() {
          _passwordError = 'Invalid Email or Password. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _errorMessage = null;
      _identifierError = null;
      _passwordError = null;
      _isGoogleLoading = true;
    });

    // Block the browser OAuth redirect entirely when offline.
    if (!await ConnectivityService.hasInternet()) {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        showNoConnectionModal(context, onRetry: _handleGoogleSignIn);
      }
      return;
    }

    try {
      final result = await _googleAuthService.signInWithGoogle(
        targetRole: _targetRole,
        isSignUpMode: false,
      );

      await _processGoogleAuthResult(result);
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        if (mounted) showNoConnectionModal(context, onRetry: _handleGoogleSignIn);
      } else {
        setState(() {
          _errorMessage = 'Google Sign-In error: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _processGoogleAuthResult(Map<String, dynamic> result) async {
    if (result['is_network_error'] == true) {
      if (mounted) showNoConnectionModal(context, onRetry: _handleGoogleSignIn);
      return;
    }
    if (result['canceled'] == true ||
        result['message'] == 'Canceled Google sign-in.' ||
        result['message'] == 'Google Sign-In was canceled.') {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
      return;
    }
    if (result['success'] == true) {
      final bool isNewUser = result['is_new_user'] == true;
      final String? googleEmail = result['email'];

      if (isNewUser) {
        // Unregistered user on Sign In screen: sign out and prompt to sign up
        await Supabase.instance.client.auth.signOut();
        await AuthSessionService().clearSession();
        if (mounted) {
          setState(() {
            _isGoogleLoading = false;
            _errorMessage = 'No registered account found for this Google email. Please sign up first.';
          });
        }
        return;
      }

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (googleEmail != null && googleEmail.isNotEmpty) {
        await _verifyAndProcessAuthSession(
          email: googleEmail,
          userId: currentUser?.id,
          loginMethod: 'google',
        );
      }
    } else if (result['message'] != null && result['message'] != 'Canceled Google sign-in.' && result['message'] != 'Google Sign-In was canceled.') {
      final rawMsg = result['message'].toString();
      if (rawMsg.contains('Walang nakalaang account') || rawMsg.contains('mag-Sign Up muna') || rawMsg.contains('No registered account')) {
        setState(() {
          _identifierError = 'No registered account found for this Google account. Please sign up first.';
        });
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
      }
    }
  }

  bool _isRoleMatching(String actualRole, String targetRole) {
    final a = actualRole.trim().toLowerCase();
    final t = targetRole.trim().toLowerCase();

    if (t == 'hog_raiser' || t == 'raiser') {
      return a == 'hog_raiser' || a == 'raiser';
    } else if (t == 'partner' || t == 'investor') {
      return a == 'partner' || a == 'investor';
    } else if (t == 'cashier') {
      return a == 'cashier';
    } else if (t == 'admin') {
      return a == 'admin';
    }
    return a == t;
  }

  String _getRoleDisplayName(String role) {
    final r = role.trim().toLowerCase();
    if (r.contains('raiser')) return 'Hog Raiser';
    if (r.contains('partner') || r.contains('investor')) return 'Partner Investor';
    if (r.contains('cashier')) return 'Cashier';
    if (r.contains('admin')) return 'Admin';
    return role;
  }

  void _showRoleMismatchDialog({
    required String actualRole,
    required String targetRole,
  }) {
    final actualDisplayName = _getRoleDisplayName(actualRole);
    final targetDisplayName = _getRoleDisplayName(targetRole);
    final normalizedActualRoleKey = actualRole.toLowerCase().contains('raiser')
        ? 'hog_raiser'
        : (actualRole.toLowerCase().contains('partner') || actualRole.toLowerCase().contains('investor')
            ? 'partner'
            : (actualRole.toLowerCase().contains('cashier') ? 'cashier' : actualRole.toLowerCase()));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      constraints: const BoxConstraints(maxWidth: 480),
      barrierColor: PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.45),
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final surface = isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface;
        final border = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
        final text = isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText;
        final muted = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
        final primaryColor = isDark ? PiggyTrunkTheme.ptPrimaryDark : PiggyTrunkTheme.ptPrimary;
        final primaryBtnBg = isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptPrimary;

        return Container(
          padding: EdgeInsets.fromLTRB(24, 10, 24, 20 + MediaQuery.of(sheetCtx).padding.bottom),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 22),

              // Swap Role Icon Badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: 0.10),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  size: 34,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Role Mismatch',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.04,
                  color: text,
                ),
              ),
              const SizedBox(height: 10),

              // Description with clear role highlighting
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: muted,
                  ),
                  children: [
                    const TextSpan(text: 'This account is registered as a '),
                    TextSpan(
                      text: actualDisplayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                    const TextSpan(text: ', but you are signing in under the '),
                    TextSpan(
                      text: targetDisplayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                    const TextSpan(text: ' portal.\n\nPlease switch to the '),
                    TextSpan(
                      text: actualDisplayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                    const TextSpan(text: ' tab to continue.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action: Switch to Actual Role
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    setState(() {
                      _targetRole = normalizedActualRoleKey;
                      _clearErrors();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBtnBg,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.swap_horiz_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Switch to $actualDisplayName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Secondary Action: Cancel
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: border, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _verifyAndProcessAuthSession({
    required String email,
    required String? userId,
    required String loginMethod,
  }) async {
    final cleanTarget = _targetRole ?? 'hog_raiser';

    // 1. Fetch user profile from app_users
    Map<String, dynamic>? userData;
    try {
      if (userId != null && userId.isNotEmpty) {
        userData = await Supabase.instance.client
            .from('app_users')
            .select('user_id, email, name, role, status')
            .or('supabase_user_id.eq.$userId,email.ilike.$email')
            .maybeSingle();
      } else {
        userData = await Supabase.instance.client
            .from('app_users')
            .select('user_id, email, name, role, status')
            .ilike('email', email)
            .maybeSingle();
      }
    } catch (e) {
      debugPrint('Error querying app_users: $e');
    }

    // 2. Fallback check on hog_raisers table
    if (userData == null) {
      try {
        final raiser = await Supabase.instance.client
            .from('hog_raisers')
            .select('account_status, status, name')
            .ilike('email', email)
            .maybeSingle();
        if (raiser != null) {
          userData = {
            'role': 'hog_raiser',
            'status': raiser['account_status'] ?? raiser['status'] ?? 'Pending',
            'name': raiser['name'],
          };
        }
      } catch (_) {}
    }

    // 3. User does not exist in backend database
    if (userData == null) {
      await Supabase.instance.client.auth.signOut();
      await AuthSessionService().clearSession();
      if (mounted) {
        setState(() {
          _identifierError = 'No registered account found for this email. Please sign up first.';
        });
      }
      return false;
    }

    final String actualRole = (userData['role'] ?? '').toString();
    final String rawStatus = (userData['status'] ?? 'Pending').toString();
    final String statusLower = rawStatus.toLowerCase();

    // 4. Role Mismatch Verification
    if (!_isRoleMatching(actualRole, cleanTarget)) {
      await Supabase.instance.client.auth.signOut();
      await AuthSessionService().clearSession();
      if (mounted) {
        _showRoleMismatchDialog(
          actualRole: actualRole,
          targetRole: cleanTarget,
        );
      }
      return false;
    }

    // 5. Account Status Verification (Pending / Inactive / Suspended)
    bool isApproved = statusLower == 'active' || statusLower == 'approved';

    // Deep check role-specific table for Hog Raisers
    if (actualRole.toLowerCase().contains('raiser')) {
      try {
        final raiser = await Supabase.instance.client
            .from('hog_raisers')
            .select('account_status, status')
            .or('email.ilike.$email${userId != null ? ",user_id.eq.${userData['user_id']}" : ""}')
            .maybeSingle();
        if (raiser != null) {
          final accStatus = (raiser['account_status'] ?? '').toString().toLowerCase();
          final rStatus = (raiser['status'] ?? '').toString().toLowerCase();
          if (accStatus == 'pending' || rStatus == 'pending' || accStatus == 'inactive') {
            isApproved = false;
          }
        }
      } catch (_) {}
    }

    if (!isApproved) {
      await Supabase.instance.client.auth.signOut();
      await AuthSessionService().clearSession();
      if (mounted) {
        _showPendingDialog();
      }
      return false;
    }

    // 6. Verification Passed! Save session & Navigate
    await AuthSessionService().saveSession(
      email: email,
      role: actualRole,
      loginMethod: loginMethod,
      userId: userId ?? userData['user_id']?.toString(),
    );

    if (mounted) {
      await _navigateToDashboard(actualRole);
    }
    return true;
  }

  void _showPendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Account Pending Approval',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF18314F),
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your account has been registered and is currently awaiting Admin approval before you can access the dashboard.\n\nWe will notify you once approved!',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF334155),
            height: 1.45,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18314F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Got It',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnconfirmedEmailDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_unread_rounded, color: Color(0xFF2563EB), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Email Not Confirmed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF18314F),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'A confirmation email was sent to $email.\n\nPlease check your inbox (and spam folder) and click the confirmation link before signing in.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF334155),
            height: 1.45,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    try {
                      await Supabase.instance.client.auth.resend(
                        type: OtpType.signup,
                        email: email,
                      );
                      if (mounted) {
                        PiggyToast.showSuccess(
                          context,
                          'Verification email resent to $email',
                          title: 'Email Sent',
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        PiggyToast.showError(
                          context,
                          'Failed to resend confirmation email: ${e.toString()}',
                          title: 'Error',
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Resend Link',
                    style: TextStyle(
                      color: Color(0xFF18314F),
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF18314F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'Got It',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToDashboard(String role) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await NotificationService().requestPermission();
      NotificationService().startRoleRealtimeListener(role: role, userId: user.id);
    }

    if (!mounted) return;

    switch (role) {
      case 'hog_raiser':
      case 'raiser':
        Navigator.of(context).pushNamedAndRemoveUntil('/raiser_dashboard', (route) => false);
        break;
      case 'partner':
      case 'investor':
        Navigator.of(context).pushNamedAndRemoveUntil('/partner_dashboard', (route) => false);
        break;
      case 'cashier':
        Navigator.of(context).pushNamedAndRemoveUntil('/cashier_dashboard', (route) => false);
        break;
      case 'admin':
        Navigator.of(context).pushNamedAndRemoveUntil('/admin_dashboard', (route) => false);
        break;
      default:
        Supabase.instance.client.auth.signOut();
        setState(() {
          _errorMessage =
              'No appropriate dashboard found for your assigned role.';
        });
    }
  }

  Widget _buildRoleSegmentedButton({
    required String roleKey,
    required String title,
    required IconData icon,
  }) {
    final cur = (_targetRole ?? 'hog_raiser').toLowerCase();
    final bool isSelected = (roleKey == 'partner')
        ? (cur.contains('partner') || cur.contains('investor'))
        : (roleKey == 'cashier')
            ? cur.contains('cashier')
            : (cur.contains('raiser') || (!cur.contains('partner') && !cur.contains('investor') && !cur.contains('cashier')));

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _targetRole = roleKey;
            _clearErrors();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF18314F) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF18314F).withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Universal ScreenFit Auto-Scaling
    final fit = ScreenFit(context);
    final double logoHeight = fit.dp(96.0);
    final double logoScale = 1.15;
    final double titleFontSize = fit.sp(22.0);
    final double subtitleFontSize = fit.sp(13.5);
    final double fieldSpacing = fit.dp(8.0);
    final double labelFontSize = fit.sp(14.0);
    final double inputPaddingV = fit.dp(10.0);
    final double inputFontSize = fit.sp(15.0);
    final double cardPaddingH = fit.dp(18.0);
    final double cardPaddingV = fit.dp(12.0);
    final double buttonHeight = fit.dp(54.0);
    final double textOffsetV = 0.0;

    final isFilipino = SettingsProvider.of(context)?.currentLocale == 'fil';
    final String backText = isFilipino ? 'Bumalik' : 'Back';
    final String actionTitle = isFilipino ? 'Mag-sign In' : 'Sign In';

    String roleLabel = isFilipino ? 'Tagapag-alaga' : 'Hog Raiser';
    final r = (_targetRole ?? 'hog_raiser').toLowerCase();
    if (r.contains('cashier')) {
      roleLabel = 'Cashier';
    } else if (r.contains('partner') || r.contains('investor')) {
      roleLabel = isFilipino ? 'Kasosyong Mamumuhunan' : 'Partner Investor';
    } else {
      roleLabel = isFilipino ? 'Tagapag-alaga' : 'Hog Raiser';
    }


    final String subtitleText = isFilipino
        ? 'Mag-sign in upang magpatuloy bilang $roleLabel'
        : 'Sign in to continue as $roleLabel';


    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F7FB), Color(0xFFE8EEF5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // FIXED TOP HEADER SECTION (Anchored at Top - Never Scrolls)
              Padding(
                padding: const EdgeInsets.only(
                  left: 20.0,
                  top: 10.0,
                  right: 20.0,
                  bottom: 2.0,
                ),
                child: Column(
                  children: [
                    // Back / Bumalik Button Top Left
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(
                              context,
                              '/signup',
                              arguments: _targetRole,
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                                color: Color(0xFF18314F),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                backText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF18314F),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: fieldSpacing * 0.4),

                    // Prominent Piggy Trunk Logo (Fixed Position with MediaQuery Height)
                    Transform.scale(
                      scale: logoScale,
                      child: Image.asset(
                        'assets/piggytrunk_logo.png',
                        height: logoHeight,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          width: logoHeight * 0.9,
                          height: logoHeight * 0.9,
                          decoration: BoxDecoration(
                            color: const Color(0xFF18314F),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.pets_rounded,
                            color: Colors.white,
                            size: logoHeight * 0.45,
                          ),
                        ),
                      ),
                    ),

                    // Titles shifted UP closer to logo graphic
                    Transform.translate(
                      offset: Offset(0, textOffsetV),
                      child: Column(
                        children: [
                          // Brand Name Text: "Piggy Trunk"
                          Text(
                            'Piggy Trunk',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: titleFontSize + 2,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF18314F),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Action Title "Sign In"
                          Text(
                            actionTitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: titleFontSize - 1,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF18314F),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Subtitle: Dynamic based on selected role
                          Text(
                            subtitleText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: subtitleFontSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6F8096),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Interactive 3-Role Segmented Selector (Hog Raiser, Partner, Cashier)
                          Container(
                            constraints: const BoxConstraints(maxWidth: 380),
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildRoleSegmentedButton(
                                  roleKey: 'hog_raiser',
                                  title: isFilipino ? 'Tagapag-alaga' : 'Hog Raiser',
                                  icon: Icons.pets_rounded,
                                ),
                                _buildRoleSegmentedButton(
                                  roleKey: 'partner',
                                  title: isFilipino ? 'Kasosyo' : 'Partner',
                                  icon: Icons.trending_up_rounded,
                                ),
                                _buildRoleSegmentedButton(
                                  roleKey: 'cashier',
                                  title: 'Cashier',
                                  icon: Icons.point_of_sale_rounded,
                                ),
                              ],
                            ),
                          ),


                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // SCROLLABLE FORM BODY (Below Fixed Header)
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: cardPaddingH,
                      vertical: 4.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE53935),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFE53935),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFC62828),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Main White Elevation Card Container
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: cardPaddingH,
                            vertical: cardPaddingV,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24.0),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF18314F,
                                ).withValues(alpha: 0.07),
                                blurRadius: 24,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Full Name/Email Label
                              Text(
                                isFilipino ? 'Buong Pangalan o Email Address' : 'Full Name or Email Address',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: labelFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF18314F),
                                ),
                              ),
                              const SizedBox(height: 3),

                              // Username Input Field
                              TextField(
                                controller: _usernameController,
                                cursorColor: const Color(0xFF18314F),
                                keyboardType: TextInputType.emailAddress,
                                textCapitalization: TextCapitalization.none,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => _clearErrors(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: inputFontSize,
                                  color: const Color(0xFF18314F),
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: inputPaddingV,
                                    horizontal: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide(
                                      color: _identifierError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide(
                                      color: _identifierError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide(
                                      color: _identifierError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFF18314F),
                                      width: 1.6,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE53935),
                                      width: 1.4,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE53935),
                                      width: 1.6,
                                    ),
                                  ),
                                  hintText: isFilipino ? 'Ilagay ang buong pangalan o email' : 'Enter full name or email',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF64748B),
                                    fontSize: inputFontSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                    color: Color(0xFF18314F),
                                    size: 20,
                                  ),
                                ),
                              ),
                              _buildInlineError(_identifierError),
                              SizedBox(height: fieldSpacing * 0.8),

                              // Password Label
                              Text(
                                'Password',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: labelFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF18314F),
                                ),
                              ),
                              const SizedBox(height: 3),

                              // Password Input Field
                              TextField(
                                controller: _passwordController,
                                cursorColor: const Color(0xFF18314F),
                                obscureText: _obscurePassword,
                                textCapitalization: TextCapitalization.none,
                                textInputAction: TextInputAction.done,
                                onChanged: (_) => _clearErrors(),
                                onSubmitted: (_) => _handlePasswordSignIn(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: inputFontSize,
                                  color: const Color(0xFF18314F),
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: inputPaddingV,
                                    horizontal: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide(
                                      color: _passwordError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide(
                                      color: _passwordError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide(
                                      color: _passwordError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFF18314F),
                                      width: 1.6,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE53935),
                                      width: 1.4,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE53935),
                                      width: 1.6,
                                    ),
                                  ),
                                  hintText: isFilipino ? 'Ilagay ang password' : 'Enter password',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF64748B),
                                    fontSize: inputFontSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: Color(0xFF18314F),
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF64748B),
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              _buildInlineError(_passwordError),
                              SizedBox(height: fieldSpacing * 0.6),

                              // Forgot Password Link
                              Align(
                                alignment: Alignment.centerRight,
                                child: Builder(
                                  builder: (context) {
                                    final currentInput = _usernameController.text.trim();
                                    final isDefault = _isDefaultSystemEmail(currentInput);
                                    final isValidPersonal = _isValidEmailFormat(currentInput) && !isDefault;

                                    // State 1: Default System Account -> Locked, NO POPUP MODAL
                                    if (isDefault) {
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.lock_rounded, size: 13, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(
                                            isFilipino ? 'Nakalimutan ang Password?' : 'Forgot Password?',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade500,
                                              decoration: TextDecoration.lineThrough,
                                              decorationColor: Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      );
                                    }

                                    // State 2: Valid Personal Email -> Highlighted Blue with mail icon, opens modal
                                    if (isValidPersonal) {
                                      return GestureDetector(
                                        onTap: () async {
                                          if (!await ConnectivityService.hasInternet()) {
                                            if (context.mounted) showNoConnectionModal(context);
                                            return;
                                          }
                                          if (!context.mounted) return;
                                          ForgotPasswordModal.show(
                                            context,
                                            initialEmail: currentInput,
                                            onPasswordResetSuccess: (email) {
                                              setState(() {
                                                _usernameController.text = email;
                                                _passwordController.clear();
                                                _errorMessage = null;
                                                _identifierError = null;
                                                _passwordError = null;
                                              });
                                            },
                                          );
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.mark_email_read_outlined, size: 14, color: Color(0xFF2366CC)),
                                            const SizedBox(width: 4),
                                            Text(
                                              isFilipino ? 'Nakalimutan ang Password?' : 'Forgot Password?',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF2366CC),
                                                decoration: TextDecoration.underline,
                                                decorationColor: const Color(0xFF2366CC),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    // State 3: Incomplete / invalid format / empty -> Locked & Muted gray, NO POPUP MODAL
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.lock_outline_rounded, size: 13, color: Colors.grey.shade400),
                                        const SizedBox(width: 4),
                                        Text(
                                          isFilipino ? 'Nakalimutan ang Password?' : 'Forgot Password?',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),

                              SizedBox(height: fieldSpacing * 1.2),

                              ValueListenableBuilder<bool>(
                                valueListenable: ConnectivityService.isOnline,
                                builder: (context, isOnline, _) {
                                  return AnimatedOpacity(
                                    duration: const Duration(milliseconds: 250),
                                    opacity: isOnline ? 1.0 : 0.72,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Sign In Button (Piggy Brand Navy Gradient without arrow icon)
                                        Container(
                                          width: double.infinity,
                                          height: buttonHeight,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16.0),
                                            gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF18314F),
                                      Color(0xFF243B53),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF18314F,
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: (_isLoading || _isGoogleLoading)
                                      ? null
                                      : () => _handlePasswordSignIn(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.center,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          actionTitle,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                            height: 1.15,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Divider with "or continue with"
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                    ),
                                    child: Text(
                                      isFilipino ? 'o magpatuloy gamit ang' : 'or continue with',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Sign in with Google Button (Official Google Sign-In Pill Style)
                              Container(
                                width: double.infinity,
                                height: buttonHeight,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(27.0),
                                  border: Border.all(
                                    color: const Color(0xFF747775),
                                    width: 1.0,
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: (_isGoogleLoading || _isLoading)
                                      ? null
                                      : () => _handleGoogleSignIn(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1F1F1F),
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(27.0),
                                    ),
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.center,
                                  ),
                                  child: _isGoogleLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF18314F),
                                                ),
                                            strokeWidth: 2.2,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            SvgPicture.string(
                                              googleLogoSvg,
                                              height: 20.0,
                                              width: 20.0,
                                            ),
                                            const SizedBox(width: 10.0),
                                            Text(
                                              isFilipino ? 'Magpatuloy gamit ang Google' : 'Continue with Google',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(
                                                      0xFF1F1F1F,
                                                    ),
                                                    letterSpacing: 0.1,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                            ],
                          ),
                        ),
                        SizedBox(height: fieldSpacing * 1.5),

                        // Bottom Navigation Link: "Don't have an account? Sign Up"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isFilipino ? 'Wala pang account? ' : "Don't have an account? ",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    '/signup',
                                    arguments: _targetRole,
                                  );
                                },
                              child: Text(
                                isFilipino ? 'Mag-sign Up' : 'Sign Up',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF18314F),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),

                          ],
                        ),
                        SizedBox(height: fieldSpacing),
                        const InstallPwaBanner(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
