import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/email_service.dart';
import '../widgets/piggy_trunk_logo.dart';
import '../styles/login_styles.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  static const Color _loginBg = Colors.white;
  static const Color _brandPanelBg = Color(0xFFE0E6EF);
  static const Color _brandColor = Color(0xFF18314F);
  static const Color _actionColor = Color(0xFF46597A);

  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late FocusNode _emailFocus;
  late FocusNode _passwordFocus;

  late final AnimationController _logoController;
  late final Animation<double> _logoFloatAnimation;

  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _hasAuthCredentialError = false;
  String? _errorMessage;
  String? _successMessage;
  String? _emailError;
  String? _passwordError;

  bool _needsPasswordActivation = false;
  String _lastCheckedEmail = '';
  Timer? _emailDebounceTimer;

  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();


  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _logoFloatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeInOutSine,
      ),
    );

    _passwordController.addListener(() {
      if (mounted) setState(() {});
    });

    _emailController.addListener(_onEmailChanged);

    _loadRememberedCredentials();

    // Auto-redirect if session already exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectIfAdminSession();
    });
  }

  Future<void> _redirectIfAdminSession() async {
    final credentials = await _authService.getRememberedCredentials();
    final rememberMe = credentials['rememberMe'] as bool? ?? false;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      final isAdmin = await _authService.isAdminSession();
      if (!mounted) return;
      if (isAdmin) {
        if (rememberMe) {
          Navigator.of(context).pushReplacementNamed('/dashboard');
          return;
        }
      } else {
        await Supabase.instance.client.auth.signOut();
        return;
      }
    }

    // Auto-login fallback if rememberMe is enabled and saved credentials exist
    if (rememberMe && !_isLoading) {
      final savedEmail = credentials['email'] as String? ?? '';
      final savedPassword = credentials['password'] as String? ?? '';
      if (savedEmail.isNotEmpty && savedPassword.isNotEmpty) {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _handleLogin();
      }
    }
  }

  void _onEmailChanged() {
    if (mounted) setState(() {});
    _emailDebounceTimer?.cancel();
    final text = _emailController.text.trim();
    if (_isValidEmailFormat(text) && !_isDefaultSystemEmail(text)) {
      _emailDebounceTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) {
          _checkAdminActivationStatus(text);
        }
      });
    } else {
      if (_needsPasswordActivation) {
        setState(() {
          _needsPasswordActivation = false;
        });
      }
    }
  }

  Future<void> _checkAdminActivationStatus(String email) async {
    final cleaned = email.trim().toLowerCase();
    if (cleaned == _lastCheckedEmail) return;
    _lastCheckedEmail = cleaned;

    try {
      // 1. Try RPC check if function is present
      try {
        final dynamic rpcRes = await Supabase.instance.client.rpc(
          'admin_check_account_status',
          params: {'email_input': cleaned},
        );
        if (rpcRes is Map && mounted && _emailController.text.trim().toLowerCase() == cleaned) {
          final needsAct = rpcRes['needs_activation'] == true;
          setState(() {
            _needsPasswordActivation = needsAct;
          });
          return;
        }
      } catch (_) {}

      // 2. Direct database query fallback
      final userRecord = await Supabase.instance.client
          .from('app_users')
          .select('role, status, password_hash')
          .eq('email', cleaned)
          .maybeSingle();

      if (mounted && _emailController.text.trim().toLowerCase() == cleaned) {
        if (userRecord != null) {
          final role = userRecord['role']?.toString().toLowerCase() ?? '';
          final status = userRecord['status']?.toString().toLowerCase() ?? '';
          final pwdHash = userRecord['password_hash']?.toString().trim();
          final isAdmin = role.contains('admin');

          final needsAct = isAdmin &&
              (status == 'pending' || pwdHash == null || pwdHash.isEmpty);

          setState(() {
            _needsPasswordActivation = needsAct;
          });
          return;
        }

        setState(() {
          _needsPasswordActivation = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRememberedCredentials() async {
    final credentials = await _authService.getRememberedCredentials();
    final savedEmail = credentials['email'] as String? ?? '';
    final savedPassword = credentials['password'] as String? ?? '';
    final rememberMeStatus = credentials['rememberMe'] as bool? ?? false;

    if (mounted && savedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        if (rememberMeStatus && savedPassword.isNotEmpty) {
          _passwordController.text = savedPassword;
        }
        _rememberMe = rememberMeStatus;
      });
      _onEmailChanged();
    }
  }

  @override
  void dispose() {
    _emailDebounceTimer?.cancel();
    _logoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _clearMessages() {
    if (_errorMessage != null ||
        _successMessage != null ||
        _emailError != null ||
        _passwordError != null ||
        _hasAuthCredentialError) {
      setState(() {
        _errorMessage = null;
        _successMessage = null;
        _emailError = null;
        _passwordError = null;
        _hasAuthCredentialError = false;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_needsPasswordActivation) {
      _showForgotPasswordDialog(isFirstTimeActivation: true);
      return;
    }

    _clearMessages();

    final email = _emailController.text.trim();
    final password = _passwordController.text;


    String? emailErr;
    String? passwordErr;

    if (email.isEmpty) {
      emailErr = 'Please enter your email or username.';
    } else if (!email.contains('@') && (email.contains('.') || RegExp(r'\.[a-zA-Z]{2,}$').hasMatch(email))) {
      emailErr = "Please include an '@' in the email address (e.g. admin@gmail.com).";
    } else if (email.contains('@')) {
      if (email.startsWith('@')) {
        emailErr = "Please enter the part before '@'.";
      } else if (email.endsWith('@')) {
        emailErr = "Please enter a domain after '@' (e.g. piggytrunk.com).";
      } else if (!email.split('@').last.contains('.')) {
        emailErr = "Please enter a complete domain after '@' (e.g. piggytrunk.com).";
      } else {
        final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
        if (!emailRegex.hasMatch(email)) {
          emailErr = 'Please enter a valid email address.';
        }
      }
    } else if (email.length < 3) {
      emailErr = 'Username must be at least 3 characters.';
    }

    if (password.isEmpty) {
      passwordErr = 'Please enter your password.';
    } else if (password.length < 6) {
      passwordErr = 'Password must be at least 6 characters.';
    }

    if (emailErr != null || passwordErr != null) {
      setState(() {
        _emailError = emailErr;
        _passwordError = passwordErr;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.login(
        email: email,
        password: password,
        rememberMe: _rememberMe,
      );

      if (result['success']) {
        setState(() {
          _successMessage = result['message'] ?? 'Login successful!';
        });
        
        // Navigate to dashboard after short delay
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/dashboard');
          }
        });
      } else {
        final msg = (result['message'] ?? 'Incorrect password. Please try again.').toString();
        final errorField = result['errorField']?.toString();

        setState(() {
          if (errorField == 'email') {
            _emailError = msg;
            _passwordError = null;
            _hasAuthCredentialError = false;
          } else {
            _passwordError = msg;
            _emailError = null;
            _hasAuthCredentialError = false;
          }
        });

        // Auto-clear password field on failed login
        _passwordController.clear();
        if (errorField == 'email') {
          _emailFocus.requestFocus();
        } else {
          _passwordFocus.requestFocus();
        }
      }
    } catch (e) {
      setState(() {
        _hasAuthCredentialError = false;
        _emailError = null;
        _passwordError = 'Incorrect password. Please try again.';
      });
      _passwordController.clear();
      _passwordFocus.requestFocus();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 1120;

    return Scaffold(
      backgroundColor: isMobile ? _brandPanelBg : _loginBg,
      body: SafeArea(
        child: isMobile
            ? _buildMobileLayout()
            : _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          child: _buildFormPanel(),
        ),
        Expanded(
          child: _buildBrandPanel(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _brandPanelBg,
                    Color(0xFFEDF2F7),
                    Colors.white,
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top Brand Header for Mobile (Mobile-style Levitation & Shadow)
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      final floatY = _logoController.isAnimating ? _logoFloatAnimation.value * 0.7 : 0.0;
                      final double t = ((floatY + 5.6) / 11.2).clamp(0.0, 1.0);

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: Offset(0, floatY),
                            child: const PiggyTrunkLogo(
                              size: 96,
                              withBorder: false,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Mobile Photorealistic Ambient Floor Shadow
                          Opacity(
                            opacity: (0.16 + 0.14 * t).clamp(0.08, 0.40),
                            child: Transform.scale(
                              scaleX: 0.88 + 0.24 * (1.0 - t),
                              scaleY: 0.85 + 0.20 * (1.0 - t),
                              child: Container(
                                width: 80,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _brandColor.withValues(alpha: 0.4),
                                  borderRadius: const BorderRadius.all(Radius.elliptical(80, 12)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _brandColor.withValues(alpha: 0.30),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Piggy Trunk',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _brandColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 50,
                    height: 3.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: _actionColor,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Elevated White Login Card
                  Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF18314F).withValues(alpha: 0.08),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Admin Login',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _brandColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enter your credentials to access the dashboard',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        if (_successMessage != null) ...[
                          _buildAlert(_successMessage!, isError: false),
                          const SizedBox(height: 18),
                        ],
                        _buildLoginForm(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormPanel() {
    return Container(
      color: _loginBg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 35),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTitle(),
                const SizedBox(height: 24),
                if (_successMessage != null) ...[
                  _buildAlert(_successMessage!, isError: false),
                  const SizedBox(height: 24),
                ],
                _buildLoginForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Admin Login',
      style: LoginStyles.titleStyle(context),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildAlert(String message, {required bool isError}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: isError
          ? LoginStyles.errorAlertDecoration()
          : LoginStyles.successAlertDecoration(),
      child: Text(
        message,
        style: LoginStyles.alertTextStyle.copyWith(
          color: isError ? LoginStyles.errorText : LoginStyles.successText,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isLoading) {
            _handleLogin();
          }
        },
      },
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildEmailField(),
            const SizedBox(height: 20),
            _buildPasswordField(),
            const SizedBox(height: 18),
            _buildFormMeta(),
            const SizedBox(height: 29),
            _buildSignInButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EMAIL OR USERNAME',
          style: LoginStyles.labelStyle,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          enabled: !_isLoading,
          textAlignVertical: TextAlignVertical.center,
          cursorHeight: 18,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: LoginStyles.brandText,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
          decoration: LoginStyles.emailFieldDecoration(
            hintText: 'Enter your email or username',
            hasError: _emailError != null,
            prefixIcon: const Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: LoginStyles.fieldIconColor,
            ),
          ),
          onFieldSubmitted: (_) {
            if (_passwordController.text.isEmpty) {
              _passwordFocus.requestFocus();
            } else if (!_isLoading) {
              _handleLogin();
            }
          },
          onChanged: (_) {
            if (_emailError != null || _passwordError != null || _hasAuthCredentialError) {
              _clearMessages();
            }
          },
        ),
        if (_emailError != null) LoginStyles.buildInlineError(_emailError!),
      ],
    );
  }

  Widget _buildPasswordField() {
    final bool isPasswordEmpty = _passwordController.text.isEmpty;
    final TextStyle fieldStyle = isPasswordEmpty
        ? GoogleFonts.poppins(
            fontSize: 15,
            color: LoginStyles.brandText,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.0,
            height: 1.2,
          )
        : (_isPasswordVisible
            ? GoogleFonts.poppins(
                fontSize: 15,
                color: LoginStyles.brandText,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.0,
                height: 1.2,
              )
            : GoogleFonts.poppins(
                fontSize: 18,
                color: LoginStyles.brandText,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
                height: 1.2,
              ));

    if (_needsPasswordActivation) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PASSWORD',
                style: LoginStyles.labelStyle,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _brandColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _brandColor.withValues(alpha: 0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_clock_outlined, size: 12, color: _brandColor),
                    const SizedBox(width: 4),
                    Text(
                      'SETUP REQUIRED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _brandColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Locked password field representation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: LoginStyles.fieldBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: LoginStyles.fieldBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 18, color: LoginStyles.fieldIconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Password field locked for initial setup',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: LoginStyles.hintText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Clean, brand-aligned activation card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _brandPanelBg.withValues(alpha: 0.40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _actionColor.withValues(alpha: 0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _brandColor.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified_user_rounded, size: 18, color: _brandColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'First-Time Admin Setup Required',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _brandColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'This personal Gmail is registered as Admin. Set your unique password via 6-digit OTP to activate your login.',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: LoginStyles.subtitleText,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => _showForgotPasswordDialog(isFirstTimeActivation: true),
                    icon: const Icon(Icons.key_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'SET ADMIN PASSWORD VIA OTP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _actionColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PASSWORD',
          style: LoginStyles.labelStyle,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          enabled: !_isLoading,
          obscureText: !_isPasswordVisible,
          obscuringCharacter: '•',
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.done,
          cursorHeight: 18,
          style: fieldStyle,
          decoration: LoginStyles.passwordFieldDecoration(
            hintText: 'Enter your password',
            hasError: _passwordError != null,
            suffixIcon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: LoginStyles.visibilityIconSize,
                    color: _isPasswordVisible
                        ? LoginStyles.fieldIconColorActive
                        : LoginStyles.fieldIconColor,
                  ),
                ),
              ),
            ),
          ),
          onFieldSubmitted: (_) {
            if (!_isLoading) {
              _handleLogin();
            }
          },
          onChanged: (_) {
            if (_emailError != null || _passwordError != null || _hasAuthCredentialError) {
              _clearMessages();
            }
          },
        ),
        if (_passwordError != null) LoginStyles.buildInlineError(_passwordError!),
      ],
    );
  }

  Widget _buildFormMeta() {
    if (_needsPasswordActivation) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildRememberCheckbox(),
        _buildForgotPasswordLink(),
      ],
    );
  }

  Widget _buildRememberCheckbox() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (value) async {
              final newValue = value ?? false;
              setState(() {
                _rememberMe = newValue;
              });
              if (!newValue) {
                await _authService.clearRememberedPassword();
              }
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            side: const BorderSide(
              color: LoginStyles.checkboxColor,
              width: 1.4,
            ),
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return _actionColor;
              }
              return Colors.white;
            }),
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Remember this device',
          style: TextStyle(
            fontSize: 12,
            color: LoginStyles.labelText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  bool _isValidEmailFormat(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return false;
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(cleaned);
  }

  bool _isDefaultSystemEmail(String text) {
    final cleaned = text.trim().toLowerCase();
    if (cleaned.isEmpty) return false;
    return cleaned == 'admin' ||
        cleaned == 'admin@piggytrunk.com' ||
        cleaned == 'admin@gmail.com' ||
        cleaned == 'piggytrunk@gmail.com';
  }

  Widget _buildForgotPasswordLink() {
    final currentInput = _emailController.text.trim();
    final isDefaultAccount = _isDefaultSystemEmail(currentInput);
    final isValidPersonal = _isValidEmailFormat(currentInput) && !isDefaultAccount;

    // State 1: Default System Account -> Non-clickable locked state with highlight badge (NO POPUP MODAL)
    if (isDefaultAccount) {
      return Tooltip(
        message: 'Default system account is locked from password reset.\nSign in and change your email in Settings.',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'FORGOT PASSWORD?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 0,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // State 2: Valid Personal Email format -> Active & Highlighted Blue (Clickable, opens recovery dialog)
    if (isValidPersonal) {
      return Tooltip(
        message: 'Reset password for $currentInput',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _showForgotPasswordDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 13, color: Color(0xFF2563EB)),
                  const SizedBox(width: 4),
                  const Text(
                    'FORGOT PASSWORD?',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                      letterSpacing: 0,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // State 3: Empty, incomplete, or invalid format -> Non-clickable locked state (NO POPUP MODAL)
    final emptyOrInvalidHint = currentInput.isEmpty
        ? 'Enter your personal Gmail above to enable password reset'
        : 'Enter a valid personal Gmail address (e.g. name@gmail.com)';

    return Tooltip(
      message: emptyOrInvalidHint,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 12, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(
              'FORGOT PASSWORD?',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPasswordDialog({bool isFirstTimeActivation = false}) {
    final resetEmailController = TextEditingController(
      text: _isValidEmailFormat(_emailController.text) ? _emailController.text.trim() : '',
    );
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    int step = 1; // 1: Request OTP, 2: Verify & Set New Password
    String targetEmail = '';
    String? localGeneratedOtp;
    String? dialogError;
    bool isSubmitting = false;
    bool isNewPasswordVisible = false;
    bool isConfirmPasswordVisible = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dialogTitle = isFirstTimeActivation
                ? (step == 1 ? 'Activate Admin Account' : 'Set Admin Password')
                : (step == 1 ? 'Forgot Password' : 'Enter Verification Code');
            final dialogIcon = isFirstTimeActivation
                ? (step == 1 ? Icons.verified_user_rounded : Icons.key_rounded)
                : (step == 1 ? Icons.lock_reset_rounded : Icons.mark_email_read_rounded);
            final step1Description = isFirstTimeActivation
                ? 'This personal Gmail is registered as Administrator. Click below to receive a 6-digit verification code to set your new admin password.'
                : 'Enter your registered email or personal Gmail address. We will send you a 6-digit verification code to reset your password.';

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _brandColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      dialogIcon,
                      color: _brandColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dialogTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _brandColor,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (step == 1) ...[
                        Text(
                          step1Description,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: LoginStyles.subtitleText,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: resetEmailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.poppins(
                            fontSize: 14,

                            color: LoginStyles.brandText,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Gmail / Email Address',
                            hintText: 'admin@gmail.com',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              color: LoginStyles.hintText,
                            ),
                            prefixIcon: const Icon(Icons.email_outlined, size: 18, color: LoginStyles.fieldIconColor),
                            filled: true,
                            fillColor: LoginStyles.fieldBackground,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: dialogError != null ? LoginStyles.errorBorder : LoginStyles.fieldBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: dialogError != null ? LoginStyles.errorBorder : LoginStyles.fieldBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: _brandColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (_) {
                            if (dialogError != null) {
                              setDialogState(() => dialogError = null);
                            }
                          },
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'A 6-digit code was sent to $targetEmail. Please check your inbox or spam.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF166534),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '6-Digit Verification Code',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: LoginStyles.brandText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 22,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w700,
                            color: _brandColor,
                          ),
                          decoration: InputDecoration(
                            hintText: '------',
                            hintStyle: GoogleFonts.sourceCodePro(
                              fontSize: 22,
                              letterSpacing: 8,
                              color: Colors.grey.shade400,
                            ),
                            filled: true,
                            fillColor: LoginStyles.fieldBackground,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: dialogError != null ? LoginStyles.errorBorder : LoginStyles.fieldBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _brandColor, width: 1.5),
                            ),
                          ),
                          onChanged: (_) {
                            if (dialogError != null) {
                              setDialogState(() => dialogError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'New Password',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: LoginStyles.brandText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: newPasswordController,
                          obscureText: !isNewPasswordVisible,
                          style: GoogleFonts.poppins(fontSize: 13, color: LoginStyles.brandText),
                          decoration: InputDecoration(
                            hintText: 'Enter new password (min. 6 characters)',
                            hintStyle: GoogleFonts.poppins(fontSize: 12, color: LoginStyles.hintText),
                            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: LoginStyles.fieldIconColor),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isNewPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                                color: LoginStyles.fieldIconColor,
                              ),
                              onPressed: () {
                                setDialogState(() => isNewPasswordVisible = !isNewPasswordVisible);
                              },
                            ),
                            filled: true,
                            fillColor: LoginStyles.fieldBackground,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (_) {
                            if (dialogError != null) setDialogState(() => dialogError = null);
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Confirm New Password',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: LoginStyles.brandText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: !isConfirmPasswordVisible,
                          style: GoogleFonts.poppins(fontSize: 13, color: LoginStyles.brandText),
                          decoration: InputDecoration(
                            hintText: 'Confirm new password',
                            hintStyle: GoogleFonts.poppins(fontSize: 12, color: LoginStyles.hintText),
                            prefixIcon: const Icon(Icons.lock_clock_outlined, size: 18, color: LoginStyles.fieldIconColor),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isConfirmPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                                color: LoginStyles.fieldIconColor,
                              ),
                              onPressed: () {
                                setDialogState(() => isConfirmPasswordVisible = !isConfirmPasswordVisible);
                              },
                            ),
                            filled: true,
                            fillColor: LoginStyles.fieldBackground,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (_) {
                            if (dialogError != null) setDialogState(() => dialogError = null);
                          },
                        ),
                      ],
                      if (dialogError != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: LoginStyles.errorText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (step == 2)
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            setDialogState(() {
                              step = 1;
                              dialogError = null;
                            });
                          },
                    child: Text(
                      'Back',
                      style: GoogleFonts.poppins(
                        color: LoginStyles.labelText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: LoginStyles.labelText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (step == 1) {
                            // --- Step 1: Send OTP ---
                            final email = resetEmailController.text.trim().toLowerCase();
                            if (email.isEmpty || !_isValidEmailFormat(email)) {
                              setDialogState(() {
                                dialogError = 'Please enter a valid Gmail / email address (e.g. name@gmail.com).';
                              });
                              return;
                            }

                            if (_isDefaultSystemEmail(email)) {
                              setDialogState(() {
                                dialogError =
                                    'The default system account ($email) cannot receive a reset code. Please enter your connected personal Gmail address.';
                              });
                              return;
                            }

                            setDialogState(() {
                              isSubmitting = true;
                              dialogError = null;
                            });

                            String? adminName;
                            // 0. Verify that the account exists and has Administrator role
                            try {
                              final userRecord = await Supabase.instance.client
                                  .from('app_users')
                                  .select('user_id, email, name, role')
                                  .eq('email', email)
                                  .maybeSingle();

                              if (userRecord == null) {
                                setDialogState(() {
                                  dialogError = 'No registered administrator account found for "$email".';
                                  isSubmitting = false;
                                });
                                return;
                              }

                              adminName = userRecord['name']?.toString();
                              final role = (userRecord['role'] ?? '').toString().toLowerCase();
                              final isAdmin = role == 'admin' ||
                                              role == 'system administrator' ||
                                              role == 'administrator' ||
                                              role.contains('admin');

                              if (!isAdmin) {
                                final displayRole = role == 'hog_raiser'
                                    ? 'Hog Raiser'
                                    : (role == 'partner' ? 'Partner Investor' : (role == 'cashier' ? 'Cashier' : role));
                                setDialogState(() {
                                  dialogError =
                                      'This account is registered as a $displayRole. Password reset on the Admin Portal is exclusively for Administrator accounts. Please use the Piggy Trunk Mobile app to reset your password.';
                                  isSubmitting = false;
                                });
                                return;
                              }
                            } catch (checkErr) {
                              debugPrint('Admin role check notice: $checkErr');
                            }

                            try {
                              // Generate 6-digit random code
                              final generatedOtp = (100000 + Random().nextInt(900000)).toString();

                              // 1. Register code in database via RPC
                              bool registeredInDb = false;
                              try {
                                final dynamic rpcRes = await Supabase.instance.client.rpc(
                                  'admin_request_password_reset_otp',
                                  params: {
                                    'target_email': email,
                                    'otp_code': generatedOtp,
                                  },
                                );
                                if (rpcRes != null && (rpcRes['success'] == true || rpcRes['success'] == 'true')) {
                                  registeredInDb = true;
                                } else if (rpcRes != null && rpcRes['message'] != null) {
                                  // Account does not exist in the database or wrong role!
                                  setDialogState(() {
                                    dialogError = rpcRes['message'].toString();
                                    isSubmitting = false;
                                  });
                                  return;
                                }
                              } catch (rpcErr) {
                                debugPrint('RPC error: $rpcErr');
                              }

                              // Fallback check if RPC function not found or failed
                              if (!registeredInDb) {
                                try {
                                  await Supabase.instance.client.from('admin_password_resets').insert({
                                    'email': email,
                                    'otp_code': generatedOtp,
                                    'expires_at': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
                                    'used': false,
                                  });
                                  registeredInDb = true;
                                } catch (dbErr) {
                                  debugPrint('Fallback check error: $dbErr');
                                  setDialogState(() {
                                    dialogError = 'Failed to verify account in database: $dbErr';
                                    isSubmitting = false;
                                  });
                                  return;
                                }
                              }

                              // 2. Dispatch OTP via Gmail SMTP service
                              final emailSent = await EmailService().sendPasswordResetOtpEmail(
                                recipientEmail: email,
                                otpCode: generatedOtp,
                                recipientName: adminName,
                                userRole: 'Administrator',
                                isAdmin: true,
                              );

                              if (!emailSent) {
                                // In local development / testing, allow proceeding to Step 2 with the generated OTP
                                if (kDebugMode) {
                                  debugPrint('[DEV OTP] Password reset verification code: $generatedOtp');
                                  setDialogState(() {
                                    targetEmail = email;
                                    localGeneratedOtp = generatedOtp;
                                    step = 2;
                                    isSubmitting = false;
                                    dialogError = null;
                                  });
                                  if (dialogCtx.mounted) {
                                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                      SnackBar(
                                        content: Text('[Dev Mode] SMTP notice: Your OTP code is $generatedOtp'),
                                        duration: const Duration(seconds: 12),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: const Color(0xFF18314F),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                setDialogState(() {
                                  dialogError =
                                      'Unable to send verification email. Please verify your internet connection or try again shortly.';
                                  isSubmitting = false;
                                });
                                return;
                              }

                              setDialogState(() {
                                targetEmail = email;
                                localGeneratedOtp = generatedOtp;
                                step = 2;
                                isSubmitting = false;
                                dialogError = null;
                              });
                            } catch (e) {
                              setDialogState(() {
                                dialogError = 'Failed to generate reset code: $e';
                                isSubmitting = false;
                              });
                            }
                          } else {
                            // --- Step 2: Verify & Reset Password ---
                            final enteredOtp = otpController.text.trim();
                            final newPass = newPasswordController.text.trim();
                            final confirmPass = confirmPasswordController.text.trim();

                            if (enteredOtp.length != 6) {
                              setDialogState(() {
                                dialogError = 'Please enter the complete 6-digit code.';
                              });
                              return;
                            }

                            if (newPass.length < 6) {
                              setDialogState(() {
                                dialogError = 'Password must be at least 6 characters.';
                              });
                              return;
                            }

                            if (newPass != confirmPass) {
                              setDialogState(() {
                                dialogError = 'Passwords do not match.';
                              });
                              return;
                            }

                            setDialogState(() {
                              isSubmitting = true;
                              dialogError = null;
                            });

                            try {
                              bool passwordResetSuccess = false;
                              String? failureMsg;

                              // 1. Try RPC password reset
                              try {
                                final dynamic rpcRes = await Supabase.instance.client.rpc(
                                  'admin_verify_otp_and_reset_password',
                                  params: {
                                    'target_email': targetEmail,
                                    'otp_code': enteredOtp,
                                    'new_password': newPass,
                                  },
                                );
                                if (rpcRes != null && (rpcRes['success'] == true || rpcRes['success'] == 'true')) {
                                  passwordResetSuccess = true;
                                } else if (rpcRes != null && rpcRes['message'] != null) {
                                  failureMsg = rpcRes['message'].toString();
                                }
                              } catch (rpcErr) {
                                debugPrint('RPC verify error: $rpcErr');
                              }

                              // 2. Fallback check if local OTP matches
                              if (!passwordResetSuccess && failureMsg == null) {
                                if (localGeneratedOtp != null && enteredOtp == localGeneratedOtp) {
                                  try {
                                    await Supabase.instance.client.auth.updateUser(
                                      UserAttributes(password: newPass),
                                    );
                                    passwordResetSuccess = true;
                                  } catch (_) {}
                                }
                              }

                              if (passwordResetSuccess) {
                                if (dialogCtx.mounted) {
                                  Navigator.of(dialogCtx).pop();
                                }

                                if (mounted) {
                                  setState(() {
                                    _emailController.text = targetEmail;
                                    _passwordController.text = newPass;
                                    _needsPasswordActivation = false;
                                    _lastCheckedEmail = '';
                                    _hasAuthCredentialError = false;
                                    _emailError = null;
                                    _passwordError = null;
                                    _successMessage = isFirstTimeActivation
                                        ? 'Admin account activated! Your new password has been set. Click Sign In to continue.'
                                        : 'Password reset successfully! Please sign in with your new password.';
                                  });
                                }
                              } else {
                                setDialogState(() {
                                  dialogError = failureMsg ??
                                      'Invalid code or reset failed. Please ensure database functions (31_admin_auth_recovery_functions.sql) are executed in Supabase SQL Editor.';
                                  isSubmitting = false;
                                });
                              }
                            } catch (e) {
                              setDialogState(() {
                                dialogError = 'An error occurred: $e';
                                isSubmitting = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _actionColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isFirstTimeActivation
                              ? (step == 1 ? 'Send Activation Code' : 'Activate & Set Password')
                              : (step == 1 ? 'Send Reset Code' : 'Reset Password'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _actionColor,
          disabledBackgroundColor: _actionColor.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'SIGN IN TO DASHBOARD',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.08,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _brandPanelBg,
            _brandPanelBg,
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBrandLogoCard(),
                const SizedBox(height: 32),
                _buildBrandTitle(),
                const SizedBox(height: 16),
                _buildBrandDivider(),
                const SizedBox(height: 21),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandLogoCard() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        final floatY = _logoController.isAnimating ? _logoFloatAnimation.value : 0.0;
        // Normalized t: 0.0 when top (-8px), 1.0 when bottom (+8px)
        final double t = ((floatY + 8.0) / 16.0).clamp(0.0, 1.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Levitating Enlarged Logo
            Transform.translate(
              offset: Offset(0, floatY),
              child: const PiggyTrunkLogo(
                size: LogoSize.hero,
                withBorder: false,
              ),
            ),
            const SizedBox(height: 14),
            // Photorealistic Soft Ambient Floor Shadow (Matching Mobile App)
            Opacity(
              opacity: (0.18 + 0.16 * t).clamp(0.08, 0.45),
              child: Transform.scale(
                scaleX: 0.88 + 0.24 * (1.0 - t),
                scaleY: 0.85 + 0.20 * (1.0 - t),
                child: Container(
                  width: 135,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _brandColor.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.all(Radius.elliptical(135, 18)),
                    boxShadow: [
                      BoxShadow(
                        color: _brandColor.withValues(alpha: 0.35),
                        blurRadius: 22,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBrandTitle() {
    return Center(
      child: Text(
        'Piggy Trunk',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.04,
              color: _brandColor,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBrandDivider() {
    return Center(
      child: Container(
        width: 118,
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: _actionColor,
        ),
      ),
    );
  }
}
