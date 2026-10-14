import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:piggytrunk/services/email_service.dart';
import '../services/google_auth_service.dart';
import '../utils/screen_fit_util.dart';
import '../utils/capitalization_formatters.dart';

const String googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
  <path fill="none" d="M0 0h48v48H0z"/>
</svg>
''';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleInitialController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String _selectedRole = 'hog_raiser'; // 'hog_raiser', 'partner', or 'cashier'
  bool _roleInitialized = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _errorMessage;
  String? _fullNameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  final GoogleAuthService _googleAuthService = GoogleAuthService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_roleInitialized) {
      _roleInitialized = true;
      final arg = ModalRoute.of(context)?.settings.arguments as String?;
      if (arg != null && (arg == 'partner' || arg == 'investor')) {
        _selectedRole = 'partner';
      } else if (arg != null && arg == 'cashier') {
        _selectedRole = 'cashier';
      } else if (arg != null && (arg == 'hog_raiser' || arg == 'raiser')) {
        _selectedRole = 'hog_raiser';
      }
    }
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _middleInitialController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _normalizedFullName() {
    final lastName = _lastNameController.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final firstName = _firstNameController.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final middleInitial = _middleInitialController.text
        .trim()
        .replaceAll('.', '')
        .toUpperCase();
    return [
      firstName,
      if (middleInitial.isNotEmpty) '${middleInitial[0]}.',
      lastName,
    ].where((p) => p.isNotEmpty).join(' ');
  }

  Widget _buildNameField(
    String label,
    String hint,
    TextEditingController controller,
    bool isInitial, {
    bool hasError = false,
    double labelFontSize = 12.5,
    double inputFontSize = 13.5,
    double inputPaddingV = 7.0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: labelFontSize,
            fontWeight: FontWeight.w700,
            color: hasError ? const Color(0xFFE53935) : const Color(0xFF18314F),
          ),
        ),
        const SizedBox(height: 2),
        TextField(
          controller: controller,
          cursorColor: const Color(0xFF18314F),
          textCapitalization: TextCapitalization.words,
          keyboardType: TextInputType.name,
          maxLength: isInitial ? 1 : null,
          inputFormatters: [
            if (isInitial) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
            if (!isInitial) const NameInputFormatter(),
          ],
          onChanged: (_) {
            if (_fullNameError != null) setState(() => _fullNameError = null);
          },
          style: GoogleFonts.plusJakartaSans(
            fontSize: inputFontSize,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF18314F),
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: inputPaddingV,
            ),
            hintStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF64748B),
              fontSize: inputFontSize,
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFE53935) : const Color(0xFFCBD5E1),
                width: hasError ? 1.4 : 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFE53935) : const Color(0xFFCBD5E1),
                width: hasError ? 1.4 : 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFE53935) : const Color(0xFF18314F),
                width: 1.6,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.4),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  void _clearErrors() {
    if (_fullNameError != null ||
        _emailError != null ||
        _passwordError != null ||
        _confirmPasswordError != null ||
        _errorMessage != null) {
      setState(() {
        _fullNameError = null;
        _emailError = null;
        _passwordError = null;
        _confirmPasswordError = null;
        _errorMessage = null;
      });
    }
  }

  Widget _buildPasswordRequirementItem({
    required bool satisfied,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            satisfied
                ? Icons.check_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: satisfied
                ? const Color(0xFF18314F)
                : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: satisfied ? FontWeight.w600 : FontWeight.w500,
              color: satisfied
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1.5),
            child: Icon(
              Icons.error_outline_rounded,
              size: 13,
              color: Color(0xFFE53935),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePasswordSignUp() async {
    _clearErrors();

    final String fullName = _normalizedFullName();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    String? nameErr;
    String? emailErr;
    String? passErr;
    String? confirmPassErr;

    // 1. Normalized name validation: First Name, MI, Last Name
    final nameTrimmed = fullName.trim();
    final nameValidCharsRegex = RegExp(r"^[a-zA-Z\u00C0-\u024F\s\.\-']+$");
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      nameErr = 'Please enter your first name and last name.';
    } else if (RegExp(r'\d').hasMatch(nameTrimmed)) {
      nameErr =
          'Full name should only contain letters and spaces (no numbers).';
    } else if (!nameValidCharsRegex.hasMatch(nameTrimmed)) {
      nameErr = 'Full name contains invalid characters.';
    } else if (nameTrimmed.length < 2) {
      nameErr = 'Full name must be at least 2 characters.';
    }

    // 2. Email Address Validation
    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (email.isEmpty) {
      emailErr = 'Please enter your email address.';
    } else if (!emailRegExp.hasMatch(email)) {
      emailErr = 'Please enter a valid email address (e.g. name@domain.com).';
    }

    // 3. Password Validation
    if (password.isEmpty) {
      passErr = 'Please enter your password.';
    } else if (password.length < 6) {
      passErr = 'Password must be at least 6 characters.';
    } else if (password.contains(' ')) {
      passErr = 'Password should not contain spaces.';
    } else if (RegExp(r'[^\x21-\x7E]').hasMatch(password)) {
      passErr = 'Password cannot contain emojis or unsupported characters.';
    } else if (!RegExp(r'[a-zA-Z]').hasMatch(password)) {
      passErr = 'Password must contain at least one letter (a-z).';
    } else if (!RegExp(
      r'[0-9!@#\$%^&*()_\+\-=\[\]{};:"\\|,.<>/?~`]',
    ).hasMatch(password)) {
      passErr =
          'Password must contain at least one number or special character (0-9, !@#...).';
    } else if ([
      '123456',
      '12345678',
      'password',
      'qwerty',
      '111111',
      '000000',
    ].contains(password.toLowerCase())) {
      passErr =
          'Password is too common and weak. Please choose a stronger password.';
    }

    // 4. Confirm Password Validation
    if (confirmPassword.isEmpty) {
      confirmPassErr = 'Please confirm your password.';
    } else if (confirmPassword != password) {
      confirmPassErr = 'Passwords do not match.';
    }

    if (nameErr != null ||
        emailErr != null ||
        passErr != null ||
        confirmPassErr != null) {
      setState(() {
        _fullNameError = nameErr;
        _emailError = emailErr;
        _passwordError = passErr;
        _confirmPasswordError = confirmPassErr;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Register with Supabase Auth with complete user metadata
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'name': fullName,
          'registered_name': fullName,
          'last_name': _lastNameController.text.trim(),
          'first_name': _firstNameController.text.trim(),
          'middle_initial': _middleInitialController.text
              .trim()
              .replaceAll('.', '')
              .toUpperCase(),
          'role': _selectedRole,
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Failed to create account.');
      }

      // 2. Defensive Client-side Upsert to app_users (if session/trigger allows)
      try {
        final insertedUser = await Supabase.instance.client
            .from('app_users')
            .upsert({
              'supabase_user_id': user.id,
              'email': email,
              'name': fullName,
              'role': _selectedRole,
              'status': 'Pending',
            }, onConflict: 'email')
            .select('user_id')
            .maybeSingle();

        final userId = insertedUser?['user_id'];

        // 3. Insert into role table if userId is available
        if (userId != null) {
          if (_selectedRole == 'hog_raiser' || _selectedRole == 'raiser') {
            await Supabase.instance.client.from('hog_raisers').upsert({
              'user_id': userId,
              'name': fullName,
              'email': email,
              'phone': 'N/A',
              'address': 'N/A',
              'status': 'Inactive',
              'account_status': 'Pending',
              'pig_type': 'N/A',
              'lifecycle_stage': 'N/A',
            }, onConflict: 'user_id');
          } else if (_selectedRole == 'partner' ||
              _selectedRole == 'investor') {
            await Supabase.instance.client.from('partner_investors').upsert({
              'user_id': userId,
            }, onConflict: 'user_id');
          } else if (_selectedRole == 'cashier') {
            try {
              await Supabase.instance.client.from('cashiers').upsert({
                'user_id': userId,
                'status': 'Pending',
                'date_hired': DateTime.now().toIso8601String().split('T').first,
              }, onConflict: 'user_id');
            } catch (_) {
              try {
                await Supabase.instance.client.from('cashiers').upsert({
                  'user_id': userId,
                  'date_hired': DateTime.now().toIso8601String().split('T').first,
                }, onConflict: 'user_id');
              } catch (_) {}
            }
          }
        }

        // 4. Send Notification to Admin Web
        try {
          final String roleDisplay =
              _selectedRole == 'hog_raiser' || _selectedRole == 'raiser'
              ? 'Hog Raiser'
              : (_selectedRole == 'partner' || _selectedRole == 'investor'
                    ? 'Partner Investor'
                    : 'Cashier');
          await Supabase.instance.client.from('admin_notifications').insert({
            'title': 'New User Registration',
            'message':
                '$fullName ($email) registered as $roleDisplay and is pending approval.',
            'type': 'user_registration',
            'is_read': false,
            'metadata': {
              'user_id': userId,
              'email': email,
              'name': fullName,
              'role': _selectedRole,
            },
          });
        } catch (notifErr) {
          debugPrint('Admin notification insert notice: $notifErr');
        }
      } catch (dbErr) {
        debugPrint('Client fallback db sync notice: $dbErr');
      }

      // 5. Send Registration Confirmation Email via Gmail SMTP
      try {
        EmailService().sendRegistrationEmail(
          recipientEmail: email,
          recipientName: fullName,
          role: _selectedRole,
        );
      } catch (_) {}

      // Sign out auth session
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      if (mounted) {
        _showSuccessDialog();
      }
    } on AuthException catch (e) {
      final msg = e.message;
      final lower = msg.toLowerCase();
      setState(() {
        if (lower.contains('already registered') ||
            lower.contains('already exists') ||
            lower.contains('user_already_exists') ||
            lower.contains('email address is already registered')) {
          _emailError =
              'An account with this email already exists. Please sign in or use another email.';
        } else if (lower.contains('password') ||
            lower.contains('weak') ||
            lower.contains('pwned') ||
            lower.contains('characters') ||
            lower.contains('compromised') ||
            lower.contains('security')) {
          _passwordError =
              'Password is too weak or common. Please use a stronger combination of letters and numbers.';
        } else if (lower.contains('email') &&
            (lower.contains('invalid') || lower.contains('format'))) {
          _emailError = 'Please enter a valid email address.';
        } else if (lower.contains('rate limit') ||
            lower.contains('too many requests') ||
            lower.contains('over_email_send_rate_limit')) {
          _errorMessage =
              'Too many registration attempts. Please wait a moment before trying again.';
        } else {
          _errorMessage = msg.isNotEmpty
              ? msg
              : 'Registration failed. Please check your details and try again.';
        }
      });
    } catch (e) {
      final str = e.toString();
      final lower = str.toLowerCase();
      setState(() {
        if (lower.contains('email') &&
            (lower.contains('exist') || lower.contains('duplicate'))) {
          _emailError = 'An account with this email already exists.';
        } else if (lower.contains('network') ||
            lower.contains('socketexception') ||
            lower.contains('connection')) {
          _errorMessage =
              'Network connection error. Please check your internet connection.';
        } else {
          _errorMessage =
              'Registration notice: ${str.replaceAll('Exception:', '').trim()}';
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _errorMessage = null;
      _isGoogleLoading = true;
    });

    try {
      final result = await _googleAuthService.signInWithGoogle(
        targetRole: _selectedRole,
        isSignUpMode: true,
      );

      if (result['success'] == true) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          _showSuccessDialog();
        }
      } else if (result['message'] != null &&
          result['message'] != 'Canceled Google sign-in.' &&
          result['message'] != 'Google Sign-In was canceled.') {
        setState(() {
          _errorMessage = result['message'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google Sign-Up error: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 28,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Account Created Successfully!',
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
          'Your account has been registered and is awaiting Admin review and approval before you can sign in.\n\nWe will notify you once approved!',
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
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pushReplacementNamed(
                  context,
                  '/login',
                  arguments: _selectedRole,
                );
              },
              child: const Text(
                'Go to Sign In',
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

  Widget _buildRoleSegmentedButton({
    required String roleKey,
    required String title,
    required IconData icon,
  }) {
    final bool isSelected = _selectedRole == roleKey;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = roleKey),
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
                size: 15,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
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


  String _getRoleDescription() {
    switch (_selectedRole) {
      case 'partner':
        return 'Invest in hog production batches & track returns.';
      case 'cashier':
        return 'Manage store supplies and process point of sales.';
      case 'hog_raiser':
      default:
        return 'Raise hogs, request supplies & track pig growth.';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Universal ScreenFit Auto-Scaling
    final fit = ScreenFit(context);
    final double logoHeight = fit.dp(92.0);
    final double logoScale = 1.18;
    final double titleFontSize = fit.sp(22.0);
    final double subtitleFontSize = fit.sp(12.5);
    final double fieldSpacing = fit.dp(5.0);
    final double labelFontSize = fit.sp(12.5);
    final double inputPaddingV = fit.dp(7.0);
    final double inputFontSize = fit.sp(13.5);
    final double cardPaddingH = fit.dp(16.0);
    final double cardPaddingV = fit.dp(10.0);
    final double buttonHeight = fit.dp(48.0);

    const String backText = 'Back';
    const String actionTitle = 'Create Account';
    const String subtitleText = 'Choose your role and register to get started';

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
              // FIXED TOP HEADER SECTION (Anchored at Top - Compact)
              Padding(
                padding: const EdgeInsets.only(
                  left: 18.0,
                  top: 4.0,
                  right: 18.0,
                  bottom: 2.0,
                ),
                child: Column(
                  children: [
                    // Back Button Top Left
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
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
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_back_rounded,
                                size: 16,
                                color: Color(0xFF18314F),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                backText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF18314F),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: fieldSpacing * 0.2),

                    // Prominent Piggy Trunk Logo with Scale
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

                    // Brand & Action Titles
                    Column(
                      children: [
                        Text(
                          'Piggy Trunk',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: titleFontSize + 2,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF18314F),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          actionTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: titleFontSize - 1,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF18314F),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          subtitleText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: subtitleFontSize,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6F8096),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // SCROLLABLE/FITTED FORM BODY
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: cardPaddingH,
                      vertical: 2.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE53935),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFE53935),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: const Color(0xFFC62828),
                                      fontSize: labelFontSize,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: fieldSpacing),
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
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF18314F,
                                ).withValues(alpha: 0.06),
                                blurRadius: 18,
                                spreadRadius: 0,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Select Your Role Section Header
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 7,
                                  left: 2,
                                  right: 2,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.assignment_ind_outlined,
                                      size: 15,
                                      color: Color(0xFF18314F),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Select Your Role',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF18314F),
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Compact Segmented Role Selector
                              Container(
                                padding: const EdgeInsets.all(3),
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
                                      title: 'Hog Raiser',
                                      icon: Icons.pets_rounded,
                                    ),
                                    _buildRoleSegmentedButton(
                                      roleKey: 'partner',
                                      title: 'Partner',
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
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 8,
                                  left: 4,
                                ),
                                child: Text(
                                  _getRoleDescription(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),

                              // Name fields — label inside field, full-width stacked
                              _buildNameField(
                                'First Name',
                                'e.g. Juan',
                                _firstNameController,
                                false,
                                hasError: _fullNameError != null,
                                labelFontSize: labelFontSize,
                                inputFontSize: inputFontSize,
                                inputPaddingV: inputPaddingV,
                              ),
                              const SizedBox(height: 6),
                              _buildNameField(
                                'Middle Initial (optional)',
                                'e.g. M',
                                _middleInitialController,
                                true,
                                hasError: _fullNameError != null,
                                labelFontSize: labelFontSize,
                                inputFontSize: inputFontSize,
                                inputPaddingV: inputPaddingV,
                              ),
                              const SizedBox(height: 6),
                              _buildNameField(
                                'Last Name',
                                'e.g. Dela Cruz',
                                _lastNameController,
                                false,
                                hasError: _fullNameError != null,
                                labelFontSize: labelFontSize,
                                inputFontSize: inputFontSize,
                                inputPaddingV: inputPaddingV,
                              ),
                              _buildInlineError(_fullNameError),
                              SizedBox(height: fieldSpacing),
                              // Email Label
                              Text(
                                'Email Address',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: labelFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF18314F),
                                ),
                              ),
                              const SizedBox(height: 2),

                              // Email Input Field
                              TextField(
                                controller: _emailController,
                                cursorColor: const Color(0xFF18314F),
                                keyboardType: TextInputType.emailAddress,
                                textCapitalization: TextCapitalization.none,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: inputFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF18314F),
                                ),
                                onChanged: (_) {
                                  if (_emailError != null) {
                                    setState(() => _emailError = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: inputPaddingV,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide(
                                      color: _emailError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFFCBD5E1),
                                      width: _emailError != null ? 1.4 : 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide(
                                      color: _emailError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFFCBD5E1),
                                      width: _emailError != null ? 1.4 : 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide(
                                      color: _emailError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFF18314F),
                                      width: 1.6,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE53935),
                                      width: 1.4,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE53935),
                                      width: 1.6,
                                    ),
                                  ),
                                  hintText: 'e.g. juan@gmail.com',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF64748B),
                                    fontSize: inputFontSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    color: Color(0xFF18314F),
                                    size: 20,
                                  ),
                                ),
                              ),
                              _buildInlineError(_emailError),
                              SizedBox(height: fieldSpacing),

                              // Password Label
                              Text(
                                'Password',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: labelFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF18314F),
                                ),
                              ),
                              const SizedBox(height: 2),

                              // Password Input Field
                              TextField(
                                controller: _passwordController,
                                cursorColor: const Color(0xFF18314F),
                                obscureText: _obscurePassword,
                                textCapitalization: TextCapitalization.none,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(
                                    RegExp(r'\s'),
                                  ),
                                  FilteringTextInputFormatter.allow(
                                    RegExp(
                                      r'[a-zA-Z0-9!@#\$%^&*()_\+\-=\[\]{};:"\\|,.<>/?~`]',
                                    ),
                                  ),
                                ],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: inputFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF18314F),
                                ),
                                onChanged: (_) {
                                  setState(() {
                                    if (_passwordError != null) {
                                      _passwordError = null;
                                    }
                                  });
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: inputPaddingV,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide(
                                      color: _passwordError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFFCBD5E1),
                                      width: _passwordError != null ? 1.4 : 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide(
                                      color: _passwordError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFFCBD5E1),
                                      width: _passwordError != null ? 1.4 : 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide(
                                      color: _passwordError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFF18314F),
                                      width: 1.6,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE53935),
                                      width: 1.4,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE53935),
                                      width: 1.6,
                                    ),
                                  ),
                                  hintText:
                                      'Min. 6 chars (letters & numbers or symbols)',
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
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
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
                              if (_passwordController.text.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 4.0,
                                    bottom: 2.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildPasswordRequirementItem(
                                        satisfied:
                                            _passwordController.text.length >=
                                            6,
                                        label: 'At least 6 characters',
                                      ),
                                      _buildPasswordRequirementItem(
                                        satisfied: RegExp(
                                          r'[a-zA-Z]',
                                        ).hasMatch(_passwordController.text),
                                        label: 'Contains letters (a-z)',
                                      ),
                                      _buildPasswordRequirementItem(
                                        satisfied: RegExp(
                                          r'[0-9!@#\$%^&*()_\+\-=\[\]{};:"\\|,.<>/?~`]',
                                        ).hasMatch(_passwordController.text),
                                        label:
                                            'Contains numbers or symbols (0-9, !@#...)',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              _buildInlineError(_passwordError),
                              SizedBox(height: fieldSpacing),

                              // Confirm Password Label
                              Text(
                                'Confirm Password',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: labelFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF18314F),
                                ),
                              ),
                              const SizedBox(height: 2),

                              // Confirm Password Input Field
                              TextField(
                                controller: _confirmPasswordController,
                                cursorColor: const Color(0xFF18314F),
                                obscureText: _obscureConfirmPassword,
                                textCapitalization: TextCapitalization.none,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(
                                    RegExp(r'\s'),
                                  ),
                                  FilteringTextInputFormatter.allow(
                                    RegExp(
                                      r'[a-zA-Z0-9!@#\$%^&*()_\+\-=\[\]{};:"\\|,.<>/?~`]',
                                    ),
                                  ),
                                ],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: inputFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF18314F),
                                ),
                                onChanged: (_) {
                                  if (_confirmPasswordError != null) {
                                    setState(
                                      () => _confirmPasswordError = null,
                                    );
                                  }
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: inputPaddingV,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide(
                                      color: _confirmPasswordError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFFCBD5E1),
                                      width: _confirmPasswordError != null
                                          ? 1.4
                                          : 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide(
                                      color: _confirmPasswordError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFFCBD5E1),
                                      width: _confirmPasswordError != null
                                          ? 1.4
                                          : 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide(
                                      color: _confirmPasswordError != null
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFF18314F),
                                      width: 1.6,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE53935),
                                      width: 1.4,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE53935),
                                      width: 1.6,
                                    ),
                                  ),
                                  hintText: 'Re-enter your password',
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
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: const Color(0xFF64748B),
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              _buildInlineError(_confirmPasswordError),
                              SizedBox(height: fieldSpacing * 1.5),

                              // Sign Up Button
                              Container(
                                width: double.infinity,
                                height: buttonHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14.0),
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
                                      ).withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _handlePasswordSignUp(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.center,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.0),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                            strokeWidth: 2.2,
                                          ),
                                        )
                                      : Text(
                                          'Create Account',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),

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
                                      horizontal: 10.0,
                                    ),
                                    child: Text(
                                      'or continue with',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
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
                              const SizedBox(height: 12),

                              // Sign up with Google Button (Official Vector SVG Logo)
                              Container(
                                width: double.infinity,
                                height: buttonHeight,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24.0),
                                  border: Border.all(
                                    color: const Color(0xFF747775),
                                    width: 1.0,
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: _isGoogleLoading
                                      ? null
                                      : () => _handleGoogleSignUp(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1F1F1F),
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24.0),
                                    ),
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.center,
                                  ),
                                  child: _isGoogleLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF18314F),
                                                ),
                                            strokeWidth: 2.0,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SvgPicture.string(
                                              googleLogoSvg,
                                              height: 20.0,
                                              width: 20.0,
                                            ),
                                            const SizedBox(width: 10.0),
                                            Text(
                                              'Sign Up with Google',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 14.0,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(
                                                      0xFF1F1F1F,
                                                    ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: fieldSpacing * 1.2),

                        // Bottom Navigation Link: "Already have an account? Sign In"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.0,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                  arguments: _selectedRole,
                                );
                              },
                              child: Text(
                                'Sign In',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF18314F),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: fieldSpacing),
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
