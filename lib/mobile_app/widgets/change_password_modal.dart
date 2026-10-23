import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../services/connectivity_service.dart';
import 'piggy_toast.dart';

class ChangePasswordModal extends StatefulWidget {
  const ChangePasswordModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ChangePasswordModal(),
    );
  }

  @override
  State<ChangePasswordModal> createState() => _ChangePasswordModalState();
}

class _ChangePasswordModalState extends State<ChangePasswordModal> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPass = true;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isGoogleUser() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    final provider = user.appMetadata['provider']?.toString().toLowerCase();
    if (provider == 'google') return true;
    final identities = user.identities;
    if (identities != null) {
      for (final id in identities) {
        if (id.provider.toLowerCase() == 'google') return true;
      }
    }
    return false;
  }

  Future<void> _handleUpdatePassword() async {
    final strings = AppStrings.of(context);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'User session not found. Please log in again.');
      return;
    }

    final isOAuth = _isGoogleUser();
    final currentPass = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    // Validation
    if (!isOAuth && currentPass.isEmpty) {
      setState(() => _errorMessage = 'Please enter your current password.');
      return;
    }

    if (newPass.length < 6) {
      setState(() => _errorMessage = strings.passwordTooShort);
      return;
    }

    if (!RegExp(r'[a-zA-Z]').hasMatch(newPass)) {
      setState(() => _errorMessage = strings.passwordMustContainLetters);
      return;
    }

    if (!RegExp(r'[0-9!@#\$%^&*()_\+\-=\[\]{};:"\\|,.<>/?~`]').hasMatch(newPass)) {
      setState(() => _errorMessage = strings.passwordMustContainNumbers);
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _errorMessage = strings.passwordsDoNotMatch);
      return;
    }

    if (!isOAuth && currentPass == newPass) {
      setState(() => _errorMessage = 'New password cannot be the same as your current password.');
      return;
    }

    // Pre-flight Connectivity Check (Solves Screenshot 1)
    final hasNet = await ConnectivityService.hasInternet();
    if (!hasNet) {
      setState(() {
        _errorMessage = strings.internetRequiredForPassword;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Verify current password if email user
      if (!isOAuth && user.email != null) {
        try {
          await Supabase.instance.client.auth.signInWithPassword(
            email: user.email!,
            password: currentPass,
          );
        } on AuthException catch (authErr) {
          final errLower = authErr.message.toLowerCase();
          if (errLower.contains('invalid') ||
              errLower.contains('credential') ||
              errLower.contains('password')) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Incorrect current password. Please try again.';
                _isLoading = false;
              });
            }
            return;
          }
        }
      }

      // 2. Update to new password in Supabase Auth
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPass),
      );

      if (mounted) {
        Navigator.pop(context);
        PiggyToast.showSuccess(
          context,
          strings.passwordChangedSuccess,
          title: 'Security Updated',
        );
      }
    } catch (e) {
      if (mounted) {
        String friendlyError;
        final errStr = e.toString().toLowerCase();

        if (ConnectivityService.isNetworkError(e) ||
            errStr.contains('socket') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('clientexception') ||
            errStr.contains('retryable') ||
            errStr.contains('network')) {
          friendlyError = strings.internetRequiredForPassword;
        } else if (e is AuthWeakPasswordException ||
            errStr.contains('weak') ||
            errStr.contains('authweakpasswordexception')) {
          friendlyError = strings.passwordWeakNotice;
        } else if (e is AuthException) {
          friendlyError = e.message;
        } else {
          friendlyError = 'Failed to update password. Please try again.';
        }

        setState(() {
          _errorMessage = friendlyError;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final isOAuth = _isGoogleUser();

    final sheetBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final inputBg = isDark ? const Color(0xFF1B2A3F) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF28354A) : const Color(0xFFE2E8F0);
    final focusedBorderColor = isDark ? Colors.white : const Color(0xFF18314F);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle Pill
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334B68) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.lock_reset_rounded,
                            color: isDark ? Colors.white : const Color(0xFF18314F),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          strings.changePassword,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: subtitleColor, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  isOAuth ? strings.googleAccountNotice : strings.updatePasswordSubtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: subtitleColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),

                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 1. Current Password (only for non-OAuth users)
                if (!isOAuth) ...[
                  Text(
                    strings.currentPasswordLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrentPass,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: GoogleFonts.plusJakartaSans(color: subtitleColor, fontSize: 13),
                      filled: true,
                      fillColor: inputBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: subtitleColor, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrentPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: subtitleColor,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureCurrentPass = !_obscureCurrentPass),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: focusedBorderColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. New Password
                Text(
                  strings.newPasswordLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPass,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: GoogleFonts.plusJakartaSans(color: subtitleColor, fontSize: 13),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    prefixIcon: Icon(Icons.vpn_key_outlined, color: subtitleColor, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: subtitleColor,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: focusedBorderColor, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Confirm New Password
                Text(
                  strings.confirmNewPasswordLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPass,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: GoogleFonts.plusJakartaSans(color: subtitleColor, fontSize: 13),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    prefixIcon: Icon(Icons.check_circle_outline_rounded, color: subtitleColor, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: subtitleColor,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: focusedBorderColor, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons: Cancel & Submit
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            strings.cancel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleUpdatePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : const Color(0xFF18314F),
                            foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  ),
                                )
                              : Text(
                                  strings.updatePasswordBtn,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
