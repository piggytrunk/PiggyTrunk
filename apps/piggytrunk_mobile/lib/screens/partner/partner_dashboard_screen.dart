import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:piggytrunk/services/notification_service.dart';

import 'tabs/partner_home_tab.dart';
import 'tabs/partner_projects_tab.dart';
import 'tabs/partner_activities_tab.dart';
import 'tabs/partner_profile_tab.dart';
import 'widgets/partner_dashboard_skeleton.dart';
import '../../services/auth_session_service.dart';
import '../../utils/capitalization_formatters.dart';
import '../../utils/app_strings.dart';

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = false;
  
  // Profile Information
  String _partnerName = "Partner Investor";
  String _partnerEmail = "";
  String _partnerPhone = "N/A";
  String _partnerAddress = "N/A";
  String? _partnerAvatarUrl;

  // Financial & Investment Data
  double _investedAmount = 0.0;
  int _activeProjectsCount = 0;
  final List<Map<String, dynamic>> _projectsList = [];
  final List<Map<String, dynamic>> _availableBatches = [];
  final List<Map<String, dynamic>> _activitiesList = [];
  List<Map<String, dynamic>> _notificationsList = [];
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _fetchPartnerData();
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 300,
        maxHeight: 300,
      );

      if (image == null) return;

      if (mounted) setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      final fileName = 'avatar-partner-${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = 'avatars/$fileName';

      try {
        await Supabase.instance.client.storage.from('profile_pictures').uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

        final publicUrl = Supabase.instance.client.storage.from('profile_pictures').getPublicUrl(filePath);

        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'avatar_url': publicUrl, 'picture': publicUrl}),
          );
        } catch (_) {}

        try {
          final pRes = await Supabase.instance.client
              .from('app_users')
              .select('user_id')
              .or('supabase_user_id.eq.${user.id},email.eq.${_partnerEmail.isNotEmpty ? _partnerEmail : user.email}')
              .maybeSingle();
          if (pRes != null && pRes['user_id'] != null) {
            await Supabase.instance.client.from('partner_investors').update({
              'avatar_url': publicUrl,
            }).eq('user_id', pRes['user_id']);
          }
        } catch (_) {}

        if (mounted) {
          setState(() {
            _partnerAvatarUrl = publicUrl;
          });
        }
      } catch (uploadErr) {
        debugPrint('Storage upload error: $uploadErr');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: Color(0xFF2FB36F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking avatar image: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restoreDefaultAvatar() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final titleColor = isDark ? const Color(0xFFECF2FF) : const Color(0xFF18314F);
    final mutedTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          surfaceTintColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.refresh_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reset Profile Picture?',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to restore your profile picture to the default PiggyTrunk logo?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: mutedTextColor,
              height: 1.5,
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        color: mutedTextColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF18314F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      'Yes, Reset',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'avatar_url': null, 'picture': null}),
        );
      } catch (_) {}

      try {
        final pRes = await Supabase.instance.client
            .from('app_users')
            .select('user_id')
            .or('supabase_user_id.eq.${user.id},email.eq.${_partnerEmail.isNotEmpty ? _partnerEmail : user.email}')
            .maybeSingle();
        if (pRes != null && pRes['user_id'] != null) {
          await Supabase.instance.client.from('partner_investors').update({
            'avatar_url': null,
          }).eq('user_id', pRes['user_id']);
        }
      } catch (e) {
        debugPrint('Error clearing avatar in DB: $e');
      }
    }

    if (mounted) {
      setState(() {
        _partnerAvatarUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture restored to default successfully!'),
          backgroundColor: Color(0xFF18314F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showEditProfileDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: _partnerName == 'N/A' ? '' : _partnerName);
    final phoneCtrl = TextEditingController(text: _partnerPhone == 'N/A' ? '' : _partnerPhone);
    final addrCtrl = TextEditingController(text: _partnerAddress == 'N/A' ? '' : _partnerAddress);

    final sheetBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final titleColor = isDark ? const Color(0xFFECF2FF) : const Color(0xFF18314F);
    final borderColor = isDark ? const Color(0xFF28354A) : const Color(0xFFE6EBF2);
    final hintColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final strings = AppStrings.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Drag Handle Pill
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334B68) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E3352) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF18314F),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              strings.editProfileTitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: titleColor,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: hintColor, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: borderColor, height: 1),
                    const SizedBox(height: 18),

                    _buildDialogInputField(
                      context,
                      controller: nameCtrl,
                      label: strings.fullName,
                      icon: Icons.person_outline_rounded,
                      inputFormatters: const [],
                    ),
                    const SizedBox(height: 14),
                    _buildDialogInputField(
                      context,
                      controller: phoneCtrl,
                      label: '${strings.phoneLabel} (${strings.numbersOnlyNotice})',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildDialogInputField(
                      context,
                      controller: addrCtrl,
                      label: strings.address,
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: borderColor, width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              strings.cancel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: hintColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              final newName = nameCtrl.text.trim();
                              final newPhone = phoneCtrl.text.trim();
                              final newAddr = addrCtrl.text.trim();

                              if (newName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(strings.pleaseEnterFullName),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              if (newPhone.isNotEmpty && (newPhone.length != 11 || !newPhone.startsWith('09'))) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(strings.invalidPhoneNumber),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setState(() {
                                if (newName.isNotEmpty) _partnerName = newName;
                                _partnerPhone = newPhone.isNotEmpty ? newPhone : 'N/A';
                                _partnerAddress = newAddr.isNotEmpty ? newAddr : 'N/A';
                              });

                              Navigator.pop(ctx);

                              try {
                                final user = Supabase.instance.client.auth.currentUser;
                                final emailToUse = _partnerEmail.isNotEmpty ? _partnerEmail : user?.email;

                                if (user != null && newName.isNotEmpty) {
                                  await Supabase.instance.client
                                      .from('app_users')
                                      .update({'name': newName})
                                      .eq('supabase_user_id', user.id);
                                } else if (emailToUse != null && emailToUse.isNotEmpty && newName.isNotEmpty) {
                                  await Supabase.instance.client
                                      .from('app_users')
                                      .update({'name': newName})
                                      .eq('email', emailToUse);
                                }

                                if (emailToUse != null && emailToUse.isNotEmpty) {
                                  final appUser = await Supabase.instance.client
                                      .from('app_users')
                                      .select('user_id')
                                      .eq('email', emailToUse)
                                      .maybeSingle();

                                  if (appUser != null && appUser['user_id'] != null) {
                                    await Supabase.instance.client
                                        .from('partner_investors')
                                        .update({
                                          'contact_number': newPhone.isNotEmpty ? newPhone : null,
                                          'address': newAddr.isNotEmpty ? newAddr : null,
                                        })
                                        .eq('user_id', appUser['user_id']);
                                  }
                                }
                              } catch (e) {
                                debugPrint('Error updating user name in DB: $e');
                              }

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(strings.profileUpdateSuccess),
                                    backgroundColor: const Color(0xFF2FB36F),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : const Color(0xFF18314F),
                              foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              strings.saveChanges,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
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
      },
    );
  }

  Widget _buildDialogInputField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.words,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveFormatters = inputFormatters ??
        (keyboardType == TextInputType.phone ? null : const [CapitalizeWordsInputFormatter()]);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: effectiveFormatters,
      style: GoogleFonts.plusJakartaSans(
        color: isDark ? const Color(0xFFECF2FF) : const Color(0xFF18314F),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, size: 20, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF18314F)),
        filled: true,
        fillColor: isDark ? const Color(0xFF1B2638) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF28354A) : const Color(0xFFE6EBF2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF18314F), width: 1.5),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 7) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _fetchPartnerData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      String currentEmail = user?.email ?? "";
      if (currentEmail.isEmpty) {
        final savedEmail = await AuthSessionService().getSavedEmail();
        if (savedEmail != null && savedEmail.isNotEmpty) {
          currentEmail = savedEmail;
        }
      }
      _partnerEmail = currentEmail;

      if (user != null) {
        // Initialize native notification listener for Partner Investor
        NotificationService().requestPermission();
        NotificationService().startRoleRealtimeListener(role: 'partner', userId: user.id);
      }

      // 1. Fetch profile from app_users
      Map<String, dynamic>? profile;
      if (user != null) {
        try {
          profile = await Supabase.instance.client
              .from('app_users')
              .select('user_id, name, email')
              .eq('supabase_user_id', user.id)
              .maybeSingle();
        } catch (_) {}
      }

      if (profile == null && currentEmail.isNotEmpty) {
        try {
          profile = await Supabase.instance.client
              .from('app_users')
              .select('user_id, name, email')
              .ilike('email', currentEmail.trim())
              .maybeSingle();

          if (profile != null && user != null) {
            try {
              await Supabase.instance.client
                  .from('app_users')
                  .update({'supabase_user_id': user.id})
                  .eq('user_id', profile['user_id']);
            } catch (e) {
              debugPrint('Error linking supabase_user_id: $e');
            }
          }
        } catch (_) {}
      }

      if (profile == null && currentEmail.isEmpty) {
        try {
          profile = await Supabase.instance.client
              .from('app_users')
              .select('user_id, name, email')
              .or('role.ilike.partner,role.ilike.partner_investor,role.ilike.investor')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
        } catch (_) {}
      }

      String resolvedName = "";
      if (profile != null) {
        final rawName = (profile['name'] as String?)?.trim() ?? "";
        if (rawName.isNotEmpty && rawName.toLowerCase() != 'partner investor' && rawName.toLowerCase() != 'partner') {
          resolvedName = rawName;
        }
        if (profile['email'] != null && profile['email'].toString().isNotEmpty) {
          _partnerEmail = profile['email'].toString();
        }
      }

      if (resolvedName.isEmpty && user != null) {
        final meta = user.userMetadata ?? {};
        final metaName = (meta['full_name'] ?? meta['name'] ?? meta['display_name'])?.toString().trim();
        if (metaName != null && metaName.isNotEmpty && metaName.toLowerCase() != 'partner investor' && metaName.toLowerCase() != 'partner') {
          resolvedName = metaName;
        }
      }

      if (resolvedName.isEmpty && _partnerEmail.contains('@')) {
        final prefix = _partnerEmail.split('@').first.trim();
        if (prefix.isNotEmpty) {
          final parts = prefix.replaceAll(RegExp(r'[._-]'), ' ').split(' ');
          resolvedName = parts.where((p) => p.isNotEmpty).map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
        }
      }

      if (resolvedName.isNotEmpty) {
        _partnerName = resolvedName;
      }

        final int? appUserId = profile?['user_id'] is int
            ? profile!['user_id'] as int
            : int.tryParse(profile?['user_id']?.toString() ?? '');

        int? partnerInvestorId;
        if (appUserId != null) {
          try {
            final partnerRecord = await Supabase.instance.client
                .from('partner_investors')
                .select('*')
                .eq('user_id', appUserId)
                .maybeSingle();

            if (partnerRecord != null) {
              partnerInvestorId = partnerRecord['partner_investor_id'] as int?;
              if (partnerRecord['contact_number'] != null && partnerRecord['contact_number'].toString().isNotEmpty) {
                _partnerPhone = partnerRecord['contact_number'].toString();
              }
              if (partnerRecord['address'] != null && partnerRecord['address'].toString().isNotEmpty) {
                _partnerAddress = partnerRecord['address'].toString();
              }
              final pAvatar = partnerRecord['avatar_url']?.toString().trim();
              if (pAvatar != null &&
                  pAvatar.isNotEmpty &&
                  (pAvatar.startsWith('http://') || pAvatar.startsWith('https://')) &&
                  !pAvatar.toLowerCase().contains('googleusercontent.com') &&
                  !pAvatar.toLowerCase().contains('ggpht.com') &&
                  !pAvatar.toLowerCase().contains('google.com')) {
                _partnerAvatarUrl = pAvatar;
              } else if (pAvatar != null &&
                  (pAvatar.toLowerCase().contains('googleusercontent.com') ||
                      pAvatar.toLowerCase().contains('ggpht.com'))) {
                try {
                  await Supabase.instance.client
                      .from('partner_investors')
                      .update({'avatar_url': null})
                      .eq('user_id', appUserId);
                } catch (_) {}
              }
            } else {
              final inserted = await Supabase.instance.client
                  .from('partner_investors')
                  .insert({'user_id': appUserId})
                  .select('partner_investor_id')
                  .maybeSingle();
              if (inserted != null) {
                partnerInvestorId = inserted['partner_investor_id'] as int?;
              }
            }
          } catch (e) {
            debugPrint('Notice on partner_investors record: $e');
          }
        }

        // 2. Fetch Batches, Assignments, Hog Raisers, and Hogs
        List<Map<String, dynamic>> allBatches = [];
        try {
          final List<dynamic> batchesRes = await Supabase.instance.client
              .from('batches')
              .select('*')
              .order('date_created', ascending: false);

          List<dynamic> assignmentsRes = [];
          try {
            assignmentsRes = await Supabase.instance.client
                .from('assignments')
                .select('*');
          } catch (aErr) {
            debugPrint('Notice on assignments query: $aErr');
          }

          // Fetch all hog raisers with their user details to resolve real names, addresses, and stages
          final Map<String, Map<String, dynamic>> raiserMap = {};
          try {
            final List<dynamic> raisersRes = await Supabase.instance.client
                .from('hog_raisers')
                .select('hog_raiser_id, name, address, phone, pig_type, lifecycle_stage, user_id, app_users!hog_raisers_user_id_fkey(name, email, address, phone)');

            for (var r in raisersRes) {
              if (r is! Map) continue;
              final rMap = Map<String, dynamic>.from(r);
              final rId = (rMap['hog_raiser_id'] ?? '').toString();
              if (rId.isEmpty) continue;

              dynamic appUsersRaw = rMap['app_users'];
              Map<String, dynamic>? appUsers;
              if (appUsersRaw is Map) {
                appUsers = Map<String, dynamic>.from(appUsersRaw);
              } else if (appUsersRaw is List && appUsersRaw.isNotEmpty && appUsersRaw.first is Map) {
                appUsers = Map<String, dynamic>.from(appUsersRaw.first);
              }

              final googleOrAppName = (appUsers?['name'] ?? '').toString().trim();
              final raiserName = (rMap['name'] ?? '').toString().trim();
              final resolvedFullName = googleOrAppName.isNotEmpty && googleOrAppName.toLowerCase() != 'hog raiser'
                  ? googleOrAppName
                  : (raiserName.isNotEmpty ? raiserName : 'Hog Raiser');

              final raiserAddress = (rMap['address'] ?? appUsers?['address'] ?? '').toString().trim();
              final raiserPhone = (rMap['phone'] ?? appUsers?['phone'] ?? '').toString().trim();

              raiserMap[rId] = {
                'name': resolvedFullName,
                'address': raiserAddress.isNotEmpty ? raiserAddress : 'Farm Location Not Set',
                'phone': raiserPhone.isNotEmpty ? raiserPhone : 'N/A',
                'pig_type': rMap['pig_type'] ?? 'Fattening',
                'lifecycle_stage': rMap['lifecycle_stage'] ?? 'Grower',
              };
            }
          } catch (rErr) {
            debugPrint('Notice fetching raisers with app_users: $rErr. Retrying simple fetch...');
            try {
              final List<dynamic> raisersSimple = await Supabase.instance.client
                  .from('hog_raisers')
                  .select('hog_raiser_id, name, address, phone, pig_type, lifecycle_stage');
              for (var r in raisersSimple) {
                if (r is! Map) continue;
                final rMap = Map<String, dynamic>.from(r);
                final rId = (rMap['hog_raiser_id'] ?? '').toString();
                if (rId.isNotEmpty) {
                  final raiserAddress = (rMap['address'] ?? '').toString().trim();
                  final raiserPhone = (rMap['phone'] ?? '').toString().trim();
                  raiserMap[rId] = {
                    'name': (rMap['name'] ?? 'Hog Raiser').toString(),
                    'address': raiserAddress.isNotEmpty ? raiserAddress : 'Farm Location Not Set',
                    'phone': raiserPhone.isNotEmpty ? raiserPhone : 'N/A',
                    'pig_type': rMap['pig_type'] ?? 'Fattening',
                    'lifecycle_stage': rMap['lifecycle_stage'] ?? 'Grower',
                  };
                }
              }
            } catch (_) {}
          }

          // Fetch hog types
          final Map<String, String> hogTypeMap = {};
          try {
            final List<dynamic> typesRes = await Supabase.instance.client.from('hog_types').select('hog_type_id, type_name');
            for (var t in typesRes) {
              if (t is Map && t['hog_type_id'] != null) {
                hogTypeMap[t['hog_type_id'].toString()] = (t['type_name'] ?? 'Fattening').toString();
              }
            }
          } catch (_) {}

          // Fetch investment records from admin to check total_hog allocation if hogs table rows aren't populated yet
          final Map<String, int> raiserHogCountMap = {};
          try {
            final List<dynamic> invRecs = await Supabase.instance.client
                .from('investment_records')
                .select('hog_raiser_id, total_hog');
            for (var r in invRecs) {
              if (r is Map && r['hog_raiser_id'] != null && r['total_hog'] != null) {
                final rId = r['hog_raiser_id'].toString();
                final count = (r['total_hog'] as num).toInt();
                raiserHogCountMap[rId] = count;
              }
            }
          } catch (_) {}

          List<dynamic> hogsRes = [];
          try {
            hogsRes = await Supabase.instance.client
                .from('hogs')
                .select('hog_id, assignment_id, health_status, weight');
          } catch (_) {}

          for (var b in batchesRes) {
            final bId = b['batch_id'] ?? b['id'];
            final bIdStr = bId.toString();

            // Find matching assignment
            Map<String, dynamic>? matchingAssign;
            for (var a in assignmentsRes) {
              if (a is Map && (a['batch_id']?.toString() == bIdStr || a['id']?.toString() == bIdStr)) {
                if ((a['status'] ?? '').toString().toLowerCase() == 'active') {
                  matchingAssign = Map<String, dynamic>.from(a);
                  break;
                }
                matchingAssign ??= Map<String, dynamic>.from(a);
              }
            }

            String raiserName = 'Unassigned';
            String raiserAddress = 'Farm Location Not Set';
            String raiserPhone = 'N/A';
            String stage = 'Grower';
            String hogType = 'Fattening';
            dynamic assignId = matchingAssign?['assignment_id'];
            String? raiserIdStr;

            if (matchingAssign != null) {
              final rawRaiserId = (matchingAssign['hog_raiser_id'] ?? '').toString();
              raiserIdStr = rawRaiserId;
              if (rawRaiserId.isNotEmpty && raiserMap.containsKey(rawRaiserId)) {
                final rData = raiserMap[rawRaiserId]!;
                raiserName = rData['name'] ?? 'Hog Raiser';
                raiserAddress = rData['address'] ?? 'Farm Location Not Set';
                raiserPhone = rData['phone'] ?? 'N/A';
                stage = rData['lifecycle_stage'] ?? 'Grower';
                hogType = rData['pig_type'] ?? 'Fattening';
              } else if (rawRaiserId.isNotEmpty) {
                raiserName = 'Raiser #$rawRaiserId';
              }

              final rawTypeId = (matchingAssign['hog_type_id'] ?? '').toString();
              if (rawTypeId.isNotEmpty && hogTypeMap.containsKey(rawTypeId)) {
                hogType = hogTypeMap[rawTypeId]!;
              }
            } else {
              // If unassigned directly in batch, check if there are raisers in raiserMap
              if (raiserMap.isNotEmpty) {
                final firstRaiser = raiserMap.values.first;
                raiserName = firstRaiser['name'] ?? 'Hog Raiser';
                raiserAddress = firstRaiser['address'] ?? 'Farm Location Not Set';
                raiserPhone = firstRaiser['phone'] ?? 'N/A';
                stage = firstRaiser['lifecycle_stage'] ?? 'Grower';
                hogType = firstRaiser['pig_type'] ?? 'Fattening';
              }
            }

            final batchHogs = assignId != null
                ? hogsRes.where((h) => h['assignment_id']?.toString() == assignId.toString()).toList()
                : [];

            // Read actual hog count from hogs table; if 0, check investment_records allocation
            int hogsCount = batchHogs.length;
            if (hogsCount == 0 && raiserIdStr != null && raiserHogCountMap.containsKey(raiserIdStr)) {
              hogsCount = raiserHogCountMap[raiserIdStr]!;
            }

            final int mortality = batchHogs.where((h) => (h['health_status'] ?? '').toString().toLowerCase() == 'deceased').length;

            allBatches.add({
              'batch_id': bId,
              'batch_name': b['batch_name'] ?? b['name'] ?? 'Batch #$bId',
              'assigned_raiser': raiserName,
              'raiser_name': raiserName,
              'address': raiserAddress,
              'location': raiserAddress,
              'phone': raiserPhone,
              'contact': raiserPhone,
              'hog_type': hogType,
              'total_hogs': hogsCount,
              'mortality': mortality,
              'stage': stage,
              'date_created': b['date_created'],
              'status': 'Active',
            });
          }
        } catch (e) {
          debugPrint('Notice: Fetching batches from batches table: $e');
        }

        // Fallback: If `batches` table had no rows, fetch from `investment_records` (Admin Web investments)
        if (allBatches.isEmpty) {
          try {
            final List<dynamic> invRecords = await Supabase.instance.client
                .from('investment_records')
                .select('*')
                .order('investment_date', ascending: false);

            for (int i = 0; i < invRecords.length; i++) {
              final r = invRecords[i];
              final bId = i + 1;
              final rStage = (r['stage'] ?? 'Grower').toString().toUpperCase();
              allBatches.add({
                'batch_id': bId,
                'batch_name': 'Batch ${r['raiser_name'] ?? 'Livestock'} (#$bId)',
                'assigned_raiser': r['raiser_name'] ?? 'Assigned Raiser',
                'raiser_name': r['raiser_name'] ?? 'Assigned Raiser',
                'hog_type': r['hog_type'] ?? 'Fattening',
                'total_hogs': (r['total_hog'] as num?)?.toInt() ?? 15,
                'mortality': 0,
                'stage': rStage == 'ACTIVE' || rStage == 'PENDING' ? 'Grower' : (r['stage'] ?? 'Grower'),
                'date_created': r['investment_date'],
                'status': 'Active',
              });
            }
          } catch (invErr) {
            debugPrint('Notice on investment_records fallback: $invErr');
          }
        }

        // Fallback: If still empty, fetch from active `hog_raisers`
        if (allBatches.isEmpty) {
          try {
            final List<dynamic> raisers = await Supabase.instance.client
                .from('hog_raisers')
                .select('hog_raiser_id, name, pig_type, lifecycle_stage, status')
                .limit(10);

            for (var r in raisers) {
              final rId = r['hog_raiser_id'];
              allBatches.add({
                'batch_id': rId,
                'batch_name': 'Batch ${r['name'] ?? 'Livestock'} (#$rId)',
                'assigned_raiser': r['name'] ?? 'Hog Raiser',
                'raiser_name': r['name'] ?? 'Hog Raiser',
                'hog_type': r['pig_type'] ?? 'Fattening',
                'total_hogs': 15,
                'mortality': 0,
                'stage': r['lifecycle_stage'] ?? 'Grower',
                'status': 'Active',
              });
            }
          } catch (_) {}
        }

        // 3. Fetch Investments for this Partner
        double totalInvested = 0.0;
        List<Map<String, dynamic>> partnerProjects = [];

        try {
          var query = Supabase.instance.client
              .from('investments')
              .select('investment_id, amount, date_invested, status, batch_id, partner_investor_id');

          if (partnerInvestorId != null) {
            query = query.eq('partner_investor_id', partnerInvestorId);
          }

          final investmentsRes = await query.order('date_invested', ascending: false);

          if (investmentsRes.isNotEmpty) {
            for (var inv in investmentsRes) {
              final amt = (inv['amount'] as num?)?.toDouble() ?? 0.0;
              final status = (inv['status'] ?? 'pending').toString().toLowerCase();
              if (status == 'active' || status == 'approved') {
                totalInvested += amt;
              }

              final bId = inv['batch_id'];
              final matchingBatches = allBatches.where((b) => b['batch_id'] == bId).toList();
              final matchingBatch = matchingBatches.isNotEmpty
                  ? matchingBatches.first
                  : {
                      'batch_id': bId,
                      'batch_name': 'Batch #$bId',
                      'assigned_raiser': 'Farm Raiser',
                      'raiser_name': 'Farm Raiser',
                      'hog_type': 'Fattening',
                      'total_hogs': 0,
                      'mortality': 0,
                      'stage': 'Booster',
                      'status': 'Active',
                    };

              partnerProjects.add({
                'investment_id': inv['investment_id'],
                'amount': amt,
                'date_invested': inv['date_invested'],
                'status': status,
                ...matchingBatch,
                'invested_amount': amt,
              });
            }
          }
        } catch (e) {
          debugPrint('Notice: Fetching investments: $e');
        }

        _investedAmount = totalInvested;
        _activeProjectsCount = partnerProjects.where((p) {
          final st = (p['status'] ?? '').toString().toLowerCase();
          return st == 'active' || st == 'approved';
        }).length;

        _availableBatches.clear();
        _availableBatches.addAll(allBatches);

        _projectsList.clear();
        _projectsList.addAll(partnerProjects);

        // 4. Fetch Live Hog Raiser Activities from `hog_reports`
        List<Map<String, dynamic>> liveActivities = [];
        try {
          final reportsRes = await Supabase.instance.client
              .from('hog_reports')
              .select('report_id, report_type, description, created_at, hog_raiser_id, hog_raisers(name)')
              .order('created_at', ascending: false)
              .limit(15);

          for (var rep in reportsRes) {
            final rType = (rep['report_type'] ?? 'Health Check').toString();
            final desc = rep['description'] ?? '';
            final raiserName = rep['hog_raisers']?['name'] ?? 'Hog Raiser';
            final createdAt = rep['created_at'] != null
                ? DateTime.tryParse(rep['created_at'].toString()) ?? DateTime.now()
                : DateTime.now();

            IconData icon = Icons.assignment_outlined;
            final lower = rType.toLowerCase();
            if (lower.contains('sick') || lower.contains('health') || lower.contains('observation')
                || lower.contains('fever') || lower.contains('poison') || lower.contains('diarrhea') || lower.contains('injur') || lower.contains('dead')) {
              icon = Icons.health_and_safety_rounded;
            } else if (lower.contains('vaccin') || lower.contains('med')) {
              icon = Icons.medication_rounded;
            } else if (lower.contains('feed') || lower.contains('weight')) {
              icon = Icons.monitor_weight_rounded;
            } else if (lower.contains('stage') || lower.contains('growth')) {
              icon = Icons.trending_up_rounded;
            }

            liveActivities.add({
              'report_id': rep['report_id'],
              'title': '$rType Alert',
              'description': desc.isNotEmpty ? desc : 'Health update submitted by $raiserName',
              'date': _formatRelativeTime(createdAt),
              'created_at': rep['created_at'],
              'icon': icon,
              'raiser_name': raiserName,
              'type': rType,
            });
          }
        } catch (e) {
          debugPrint('Notice fetching hog reports: $e');
        }

        _activitiesList.clear();
        _activitiesList.addAll(liveActivities);

        // 5. Fetch partner notifications strictly from `partner_notifications` table
        try {
          var partnerNotifsQuery = Supabase.instance.client
              .from('partner_notifications')
              .select('*');

          if (partnerInvestorId != null) {
            partnerNotifsQuery = partnerNotifsQuery.eq('partner_investor_id', partnerInvestorId);
          }

          final List<dynamic> pNotifs = await partnerNotifsQuery
              .order('created_at', ascending: false)
              .limit(40);

          if (pNotifs.isNotEmpty) {
            _notificationsList = List<Map<String, dynamic>>.from(pNotifs);
          } else {
            _notificationsList = [];
          }
        } catch (_) {
          _notificationsList = [];
        }
    } catch (e) {
      debugPrint('Error fetching partner profile data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    await AuthSessionService().clearSession();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  Future<void> _markNotificationAsRead(int id) async {
    setState(() {
      final index = _notificationsList.indexWhere((n) => (n['notification_id'] ?? '').toString() == id.toString());
      if (index != -1) {
        _notificationsList[index]['is_read'] = true;
      }
    });

    try {
      await Supabase.instance.client
          .from('partner_notifications')
          .update({'is_read': true})
          .eq('notification_id', id);
    } catch (e) {
      debugPrint('Notice updating is_read for notification #$id: $e');
    }
  }

  Future<void> _markAllNotificationsRead() async {
    setState(() {
      for (var n in _notificationsList) {
        n['is_read'] = true;
      }
    });

    try {
      final unreadIds = _notificationsList
          .map((n) => (n['notification_id'] as num?)?.toInt())
          .whereType<int>()
          .toList();

      if (unreadIds.isNotEmpty) {
        await Supabase.instance.client
            .from('partner_notifications')
            .update({'is_read': true})
            .inFilter('notification_id', unreadIds);
      }
    } catch (e) {
      debugPrint('Notice marking all notifications read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final scaffoldBg = isDark ? const Color(0xff0f1724) : PiggyTrunkTheme.ptBg;
    final navBg = isDark ? const Color(0xff151f2e) : Colors.white;
    final navBorder = isDark ? const Color(0xff28354a) : const Color(0xffe6ebf2);

    final List<Widget> tabs = [
      PartnerHomeTab(
        partnerName: _partnerName,
        investedAmount: _investedAmount,
        activeProjectsCount: _activeProjectsCount,
        projectsList: _availableBatches,
        activitiesList: _activitiesList,
        notificationsList: _notificationsList,
        onRefresh: _fetchPartnerData,
        onSeeAllActivities: () => setState(() => _currentIndex = 2),
        onViewProjects: () => setState(() => _currentIndex = 1),
        onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
        onMarkNotificationAsRead: _markNotificationAsRead,
        onMarkAllRead: _markAllNotificationsRead,
      ),
      PartnerProjectsTab(
        projectsList: _availableBatches,
        onRefresh: _fetchPartnerData,
      ),
      PartnerActivitiesTab(
        activitiesList: _activitiesList,
        onRefresh: _fetchPartnerData,
        onNavigateToBatches: () => setState(() => _currentIndex = 1),
        hasActiveProject: _projectsList.isNotEmpty,
        currentStage: (_projectsList.isNotEmpty
                ? (_projectsList.first['stage'] ?? _projectsList.first['lifecycle_stage'])
                : 'Booster').toString(),
        raiserName: _projectsList.isNotEmpty
            ? (_projectsList.first['assigned_raiser'] ?? _projectsList.first['raiser_name'])?.toString()
            : null,
        totalHogs: _projectsList.isNotEmpty
            ? (int.tryParse(_projectsList.first['total_hogs']?.toString() ?? '') ??
                int.tryParse(_projectsList.first['total_heads']?.toString() ?? '') ??
                0)
            : 0,
      ),
      PartnerProfileTab(
        partnerName: _partnerName,
        partnerEmail: _partnerEmail,
        partnerPhone: _partnerPhone,
        partnerAddress: _partnerAddress,
        partnerAvatarUrl: _partnerAvatarUrl,
        onPickAndUploadAvatar: _pickAndUploadAvatar,
        onRestoreDefaultAvatar: _restoreDefaultAvatar,
        onShowEditProfileDialog: _showEditProfileDialog,
        onLogout: _handleLogout,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                strings.isFilipino
                    ? 'Pindutin ulit ang Back button upang isara ang app.'
                    : 'Press back again to exit the app.',
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF18314F),
            ),
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: SafeArea(
          child: _isLoading
            ? PartnerDashboardSkeleton(
                currentIndex: _currentIndex,
              )
            : IndexedStack(
                index: _currentIndex,
                children: tabs,
              ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(color: navBorder, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: navBg,
          selectedItemColor: isDark ? const Color(0xffecf2ff) : const Color(0xFF18314F),
          unselectedItemColor: isDark ? const Color(0xff9cb0c9) : PiggyTrunkTheme.ptMuted,
          selectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.grid_view_rounded),
              activeIcon: Icon(Icons.grid_view_rounded, color: isDark ? const Color(0xffecf2ff) : const Color(0xFF18314F)),
              label: strings.navHome,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded, color: isDark ? const Color(0xffecf2ff) : const Color(0xFF18314F)),
              label: strings.navInvestment,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.article_outlined),
              activeIcon: Icon(Icons.article_rounded, color: isDark ? const Color(0xffecf2ff) : const Color(0xFF18314F)),
              label: strings.navActivities,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded, color: isDark ? const Color(0xffecf2ff) : const Color(0xFF18314F)),
              label: strings.navProfile,
            ),
          ],
        ),
      ),
    ),
  );
  }
}
