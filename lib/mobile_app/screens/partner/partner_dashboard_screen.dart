import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:piggytrunk/services/notification_service.dart';

import 'tabs/partner_home_tab.dart';
import 'tabs/partner_projects_tab.dart';
import 'tabs/partner_activities_tab.dart';
import 'tabs/partner_lifecycle_tab.dart';
import 'tabs/partner_profile_tab.dart';
import 'widgets/partner_dashboard_skeleton.dart';
import 'widgets/partner_liquid_bottom_bar.dart';
import '../../services/auth_session_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/location_service.dart';
import '../../widgets/piggy_toast.dart';
import '../../widgets/address_autocomplete_field.dart';
import '../../widgets/house_number_prompt_dialog.dart';
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
  int? _appUserId;
  int? _partnerInvestorId;

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

    if (!await ConnectivityService.hasInternet()) {
      _showOfflineProfileUploadToast();
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 300,
        maxHeight: 300,
      );

      if (image == null) return;

      if (!await ConnectivityService.hasInternet()) {
        _showOfflineProfileUploadToast();
        return;
      }

      if (mounted) setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      final fileName =
          'avatar-partner-${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = 'avatars/$fileName';

      try {
        await Supabase.instance.client.storage
            .from('profile_pictures')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );

        final publicUrl = Supabase.instance.client.storage
            .from('profile_pictures')
            .getPublicUrl(filePath);

        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              data: {'avatar_url': publicUrl, 'picture': publicUrl},
            ),
          );
        } catch (_) {}

        try {
          final pRes = await Supabase.instance.client
              .from('app_users')
              .select('user_id')
              .or(
                'supabase_user_id.eq.${user.id},email.eq.${_partnerEmail.isNotEmpty ? _partnerEmail : user.email}',
              )
              .maybeSingle();
          if (pRes != null && pRes['user_id'] != null) {
            await Supabase.instance.client
                .from('partner_investors')
                .update({'avatar_url': publicUrl})
                .eq('user_id', pRes['user_id']);
          }
        } catch (_) {}

        if (mounted) {
          setState(() {
            _partnerAvatarUrl = publicUrl;
          });
        }
      } catch (uploadErr) {
        debugPrint('Storage upload error: $uploadErr');
        if (mounted) {
          if (ConnectivityService.isNetworkError(uploadErr)) {
            _showOfflineProfileUploadToast();
          } else {
            PiggyToast.showError(
              context,
              AppStrings.of(context).profilePictureUploadFailed,
            );
          }
        }
        return;
      }

      if (mounted) {
        final strings = AppStrings.of(context);
        PiggyToast.showSuccess(
          context,
          strings.isFilipino
              ? 'Matagumpay na na-update ang profile picture!'
              : 'Profile picture updated successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        if (ConnectivityService.isNetworkError(e)) {
          _showOfflineProfileUploadToast();
        } else {
          PiggyToast.showError(
            context,
            AppStrings.of(context).profilePictureUploadFailed,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showOfflineProfileUploadToast() {
    if (!mounted) return;
    final strings = AppStrings.of(context);
    PiggyToast.showWarning(
      context,
      strings.profilePictureUploadOffline,
      title: strings.offlineNotificationTitle,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _restoreDefaultAvatar() async {
    if (!await ConnectivityService.hasInternet()) {
      _showOfflineProfileUploadToast();
      return;
    }
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFECF2FF)
        : const Color(0xFF18314F);
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          surfaceTintColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
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
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
            .or(
              'supabase_user_id.eq.${user.id},email.eq.${_partnerEmail.isNotEmpty ? _partnerEmail : user.email}',
            )
            .maybeSingle();
        if (pRes != null && pRes['user_id'] != null) {
          await Supabase.instance.client
              .from('partner_investors')
              .update({'avatar_url': null})
              .eq('user_id', pRes['user_id']);
        }
      } catch (e) {
        debugPrint('Error clearing avatar in DB: $e');
      }
    }

    if (mounted) {
      final strings = AppStrings.of(context);
      setState(() {
        _partnerAvatarUrl = null;
      });
      PiggyToast.showSuccess(
        context,
        strings.isFilipino
            ? 'Naibalik sa default ang profile picture!'
            : 'Profile picture restored to default successfully!',
      );
    }
  }

  Future<void> _handleAvatarTap() async {
    if (_partnerAvatarUrl == null || _partnerAvatarUrl!.isEmpty) {
      await _pickAndUploadAvatar();
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  strings.changePhotoOption,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18314F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Color(0xFF18314F),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    strings.uploadNewPhoto,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadAvatar();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    strings.restoreDefaultLogo,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _restoreDefaultAvatar();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _resolveDefaultName() async {
    final user = Supabase.instance.client.auth.currentUser;
    final emailToUse = _partnerEmail.isNotEmpty
        ? _partnerEmail
        : (user?.email ?? '');

    // 1. Check user_metadata for stored registered_name or initial_name
    if (user != null) {
      final meta = user.userMetadata ?? {};
      final reg =
          (meta['registered_name'] ??
                  meta['original_name'] ??
                  meta['initial_name'])
              ?.toString()
              .trim();
      if (reg != null &&
          reg.isNotEmpty &&
          reg.toLowerCase() != 'partner investor' &&
          reg.toLowerCase() != 'partner') {
        return reg;
      }

      // 2. Check provider identities (e.g. Google sign-in)
      final identities = user.identities;
      if (identities != null) {
        for (final id in identities) {
          final idData = id.identityData;
          if (idData != null) {
            final idName = (idData['full_name'] ?? idData['name'])
                ?.toString()
                .trim();
            if (idName != null &&
                idName.isNotEmpty &&
                idName.toLowerCase() != 'partner investor') {
              return idName;
            }
          }
        }
      }
    }

    // 3. Check admin_notifications for the original user_registration record
    try {
      if (emailToUse.isNotEmpty) {
        final notif = await Supabase.instance.client
            .from('admin_notifications')
            .select('metadata')
            .eq('type', 'user_registration')
            .filter('metadata->>email', 'eq', emailToUse.trim())
            .order('created_at', ascending: true)
            .limit(1)
            .maybeSingle();

        if (notif != null && notif['metadata'] != null) {
          final meta = notif['metadata'];
          if (meta is Map && meta['name'] != null) {
            final notifName = meta['name'].toString().trim();
            if (notifName.isNotEmpty &&
                notifName.toLowerCase() != 'partner investor') {
              return notifName;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Notice checking admin_notifications for registered name: $e');
    }

    // 4. Derive from email address prefix (e.g. justrejie@gmail.com -> Just Rejie)
    if (emailToUse.contains('@')) {
      final prefix = emailToUse.split('@').first.trim();
      if (prefix.isNotEmpty) {
        final parts = prefix.replaceAll(RegExp(r'[._\-]'), ' ').split(' ');
        final formatted = parts
            .where((p) => p.isNotEmpty)
            .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
            .join(' ');
        if (formatted.isNotEmpty) return formatted;
      }
    }

    return "Partner Investor";
  }

  Future<void> _resetProfileToDefault() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final dialogBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFECF2FF)
        : const Color(0xFF18314F);
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          surfaceTintColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.resetAccountDetailsTitle,
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
            strings.resetAccountDetailsBody,
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
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      strings.cancel,
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      strings.yesReset,
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

    if (mounted) setState(() => _isLoading = true);

    try {
      final defaultName = await _resolveDefaultName();
      String defaultFirstName = defaultName;
      String defaultLastName = '';
      final parts = defaultName
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ')
          .split(' ');
      if (parts.length > 1) {
        defaultFirstName = parts.first;
        defaultLastName = parts.sublist(1).join(' ');
      }

      final user = Supabase.instance.client.auth.currentUser;
      final emailToUse = _partnerEmail.isNotEmpty
          ? _partnerEmail
          : (user?.email ?? '');

      // 1. Update Supabase Auth user metadata and refresh the session
      if (user != null) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              data: {
                'first_name': defaultFirstName,
                'middle_initial': '',
                'last_name': defaultLastName,
                'full_name': defaultName,
                'name': defaultName,
                'registered_name': defaultName,
                'avatar_url': null,
                'picture': null,
              },
            ),
          );
          await Supabase.instance.client.auth.refreshSession();
        } catch (e) {
          debugPrint('Notice updating auth user metadata on reset: $e');
        }
      }

      int? targetUserId = _appUserId;
      if (targetUserId == null && emailToUse.isNotEmpty) {
        try {
          final appUser = await Supabase.instance.client
              .from('app_users')
              .select('user_id')
              .eq('email', emailToUse)
              .maybeSingle();
          if (appUser != null && appUser['user_id'] != null) {
            targetUserId = appUser['user_id'] is int
                ? appUser['user_id'] as int
                : int.tryParse(appUser['user_id'].toString());
          }
        } catch (_) {}
      }

      // 2. Update app_users (reset name and clear custom address)
      try {
        final updateMap = {'name': defaultName, 'address': null};
        if (targetUserId != null) {
          await Supabase.instance.client
              .from('app_users')
              .update(updateMap)
              .eq('user_id', targetUserId);
        } else if (user != null) {
          await Supabase.instance.client
              .from('app_users')
              .update(updateMap)
              .eq('supabase_user_id', user.id);
        } else if (emailToUse.isNotEmpty) {
          await Supabase.instance.client
              .from('app_users')
              .update(updateMap)
              .eq('email', emailToUse);
        }
      } catch (e) {
        debugPrint('Notice updating app_users on reset: $e');
      }

      // 3. Update partner_investors (clear contact_number, address, avatar)
      try {
        if (targetUserId != null) {
          await Supabase.instance.client
              .from('partner_investors')
              .update({
                'contact_number': null,
                'address': null,
                'avatar_url': null,
              })
              .eq('user_id', targetUserId);
        } else if (_partnerInvestorId != null) {
          await Supabase.instance.client
              .from('partner_investors')
              .update({
                'contact_number': null,
                'address': null,
                'avatar_url': null,
              })
              .eq('partner_investor_id', _partnerInvestorId!);
        }
      } catch (e) {
        debugPrint('Notice updating partner_investors on reset: $e');
      }

      if (mounted) {
        setState(() {
          _partnerName = defaultName;
          _partnerPhone = 'N/A';
          _partnerAddress = 'N/A';
          _partnerAvatarUrl = null;
        });

        PiggyToast.showSuccess(context, strings.accountDetailsRestoredSuccess);
      }

      // 4. Re-fetch partner data to ensure all UI states & DB records are fully in sync
      await _fetchPartnerData();
    } catch (e) {
      debugPrint('Error resetting profile to default: $e');
      if (mounted) {
        PiggyToast.showError(context, 'Failed to reset profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEditProfileDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parse First, Middle Initial, and Last Name from the current active _partnerName
    String prefillFirst = '';
    String prefillMiddle = '';
    String prefillLast = '';

    final nameClean = _partnerName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (nameClean.isNotEmpty &&
        nameClean != 'Partner Investor' &&
        nameClean != 'N/A') {
      final parts = nameClean.split(' ');
      if (parts.length == 1) {
        prefillFirst = parts[0];
      } else if (parts.length == 2) {
        prefillFirst = parts[0];
        prefillLast = parts[1];
      } else if (parts.length >= 3) {
        if (parts[1].endsWith('.') || parts[1].length <= 2) {
          prefillFirst = parts[0];
          prefillMiddle = parts[1].replaceAll('.', '');
          prefillLast = parts.sublist(2).join(' ');
        } else {
          prefillFirst = parts.sublist(0, parts.length - 1).join(' ');
          prefillLast = parts.last;
        }
      }
    }

    // Fallback to user metadata only if _partnerName parsing was empty
    if (prefillFirst.isEmpty && prefillLast.isEmpty) {
      final userMeta =
          Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
      prefillFirst = (userMeta['first_name'] ?? '').toString().trim();
      prefillMiddle =
          (userMeta['middle_initial'] ?? userMeta['middle_name'] ?? '')
              .toString()
              .trim();
      prefillLast = (userMeta['last_name'] ?? '').toString().trim();
    }

    final firstNameCtrl = TextEditingController(text: prefillFirst);
    final middleInitialCtrl = TextEditingController(text: prefillMiddle);
    final lastNameCtrl = TextEditingController(text: prefillLast);
    final phoneCtrl = TextEditingController(
      text: (_partnerPhone == 'N/A' || _partnerPhone == 'Not set')
          ? ''
          : _partnerPhone,
    );
    final addrCtrl = TextEditingController(
      text: (_partnerAddress == 'N/A' || _partnerAddress == 'Not set')
          ? ''
          : _partnerAddress,
    );

    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE6EBF2);
    final hintColor = isDark
        ? const Color(0xFF94A3B8)
        : PiggyTrunkTheme.ptMuted;
    final actionColor = isDark ? Colors.white : const Color(0xFF18314F);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final strings = AppStrings.of(ctx);
        bool isDetectingGps = false;
        String? firstNameError;
        String? lastNameError;
        String? phoneError;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> autoDetectGps() async {
              setModalState(() => isDetectingGps = true);
              final result = await LocationService.instance.getCurrentAddress(
                requestPermission: true,
              );
              setModalState(() => isDetectingGps = false);

              if (result.success &&
                  result.address != null &&
                  result.address!.trim().isNotEmpty) {
                final currentText = addrCtrl.text.trim();
                final prefixInfo = LocationService.extractPhilippinePrefix(currentText);

                String finalAddress = result.address!.trim();
                if (prefixInfo != null && !finalAddress.startsWith(RegExp(r'[#№0-9]'))) {
                  finalAddress = '${prefixInfo.prefix}, $finalAddress';
                } else if (!finalAddress.startsWith(RegExp(r'[#№0-9]')) && ctx.mounted) {
                  final prompted = await HouseNumberPromptDialog.show(
                    ctx,
                    detectedAddress: finalAddress,
                  );
                  if (prompted != null && prompted.isNotEmpty) {
                    finalAddress = prompted;
                  }
                }

                addrCtrl.text = finalAddress;
                if (ctx.mounted) {
                  PiggyToast.showSuccess(
                    ctx,
                    '${strings.locationDetectedToast} $finalAddress',
                  );
                }
              } else if (result.isPermanentlyDenied) {
                if (ctx.mounted) {
                  showDialog(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      title: Row(
                        children: [
                          const Icon(
                            Icons.location_off_rounded,
                            color: Color(0xFFF59E0B),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.locationDisabledTitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        strings.locationDisabledDesc,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                          height: 1.45,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: Text(
                            strings.cancel,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dCtx);
                            LocationService.instance.openAppSettings();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            strings.openSettings,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              } else if (ctx.mounted) {
                PiggyToast.showWarning(
                  ctx,
                  result.errorMessage ??
                      'Could not detect location. You can type it manually.',
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.5 : 0.15,
                      ),
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
                              color: isDark
                                  ? const Color(0xFF475569)
                                  : Colors.grey[300],
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
                                    color: isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFDBEAFE),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF18314F),
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
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark ? Colors.white70 : hintColor,
                                size: 22,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: borderColor, height: 1),
                        const SizedBox(height: 18),

                        // 1. First Name & Middle Initial Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldHeaderRow(
                                    label: strings.firstNameLabel,
                                    titleColor: titleColor,
                                  ),
                                  _buildDialogInputField(
                                    context,
                                    controller: firstNameCtrl,
                                    hintText: 'e.g. Juan',
                                    icon: Icons.person_outline_rounded,
                                    hasError: firstNameError != null,
                                    inputFormatters: const [
                                      NameInputFormatter(),
                                    ],
                                    onChanged: (_) {
                                      if (firstNameError != null)
                                        setModalState(
                                          () => firstNameError = null,
                                        );
                                    },
                                  ),
                                  _buildInlineErrorText(firstNameError),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldHeaderRow(
                                    label: strings.middleInitialLabel,
                                    titleColor: titleColor,
                                    trailing: Text(
                                      strings.optionalLabel,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: hintColor,
                                      ),
                                    ),
                                  ),
                                  _buildDialogInputField(
                                    context,
                                    controller: middleInitialCtrl,
                                    hintText: 'M.',
                                    maxLength: 2,
                                    icon: Icons.edit_note_rounded,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z\u00D1\u00F1]'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 2. Last Name Field
                        _buildFieldHeaderRow(
                          label: strings.lastNameLabel,
                          titleColor: titleColor,
                        ),
                        _buildDialogInputField(
                          context,
                          controller: lastNameCtrl,
                          hintText: 'e.g. Dela Cruz',
                          icon: Icons.badge_outlined,
                          hasError: lastNameError != null,
                          inputFormatters: const [NameInputFormatter()],
                          onChanged: (_) {
                            if (lastNameError != null)
                              setModalState(() => lastNameError = null);
                          },
                        ),
                        _buildInlineErrorText(lastNameError),
                        const SizedBox(height: 14),

                        // 3. Phone Number Field
                        _buildFieldHeaderRow(
                          label: strings.phoneLabel,
                          titleColor: titleColor,
                          trailing: Text(
                            strings.phoneHelperNotice,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hintColor,
                            ),
                          ),
                        ),
                        _buildDialogInputField(
                          context,
                          controller: phoneCtrl,
                          hintText: '09XXXXXXXXX',
                          icon: Icons.phone_iphone_rounded,
                          keyboardType: TextInputType.phone,
                          hasError: phoneError != null,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          onChanged: (_) {
                            if (phoneError != null)
                              setModalState(() => phoneError = null);
                          },
                        ),
                        _buildInlineErrorText(phoneError),
                        const SizedBox(height: 14),

                        // 4. Address Field with Auto-Detect Action
                        _buildFieldHeaderRow(
                          label: strings.address,
                          titleColor: titleColor,
                          trailing: InkWell(
                            onTap: isDetectingGps ? null : autoDetectGps,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDetectingGps)
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                        color: actionColor,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.my_location_rounded,
                                      size: 14,
                                      color: actionColor,
                                    ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isDetectingGps
                                        ? strings.detectingGps
                                        : strings.autoDetectLocation,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: actionColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AddressAutocompleteField(
                          controller: addrCtrl,
                          isDetectingGps: isDetectingGps,
                          onAutoDetect: autoDetectGps,
                          hintText: strings.tapToDetectGpsAddress,
                          onChanged: (_) {
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : borderColor,
                                    width: 1.2,
                                  ),
                                  backgroundColor: isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  strings.cancel,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: isDark ? Colors.white : hintColor,
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
                                  final first = firstNameCtrl.text.trim();
                                  final middle = middleInitialCtrl.text
                                      .trim()
                                      .replaceAll('.', '')
                                      .toUpperCase();
                                  final last = lastNameCtrl.text.trim();
                                  final newPhone = phoneCtrl.text.trim();
                                  final newAddr = addrCtrl.text.trim();

                                  // Validate First Name (letters, spaces, accents, ñ/Ñ only)
                                  String? fErr;
                                  if (first.isEmpty) {
                                    fErr = strings.firstNameRequired;
                                  } else if (!RegExp(
                                    r"^[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF \-'\.]+$",
                                  ).hasMatch(first)) {
                                    fErr = strings.nameInvalidCharacters;
                                  }

                                  // Validate Last Name (letters, spaces, accents, ñ/Ñ only)
                                  String? lErr;
                                  if (last.isEmpty) {
                                    lErr = strings.lastNameRequired;
                                  } else if (!RegExp(
                                    r"^[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF \-'\.]+$",
                                  ).hasMatch(last)) {
                                    lErr = strings.nameInvalidCharacters;
                                  }

                                  // Validate Phone (optional, but if provided must start with 09 and be 11 digits)
                                  String? pErr;
                                  if (newPhone.isNotEmpty) {
                                    if (!newPhone.startsWith('09')) {
                                      pErr = strings.phoneMustStart09;
                                    } else if (newPhone.length != 11) {
                                      pErr = strings.phoneMustBe11Digits;
                                    }
                                  }

                                  if (fErr != null ||
                                      lErr != null ||
                                      pErr != null) {
                                    setModalState(() {
                                      firstNameError = fErr;
                                      lastNameError = lErr;
                                      phoneError = pErr;
                                    });
                                    return;
                                  }

                                  final newCombinedName = [
                                    first,
                                    if (middle.isNotEmpty) '$middle.',
                                    last,
                                  ].where((p) => p.isNotEmpty).join(' ');

                                  setState(() {
                                    if (newCombinedName.isNotEmpty)
                                      _partnerName = newCombinedName;
                                    _partnerPhone = newPhone.isNotEmpty
                                        ? newPhone
                                        : 'N/A';
                                    _partnerAddress = newAddr.isNotEmpty
                                        ? newAddr
                                        : 'N/A';
                                  });

                                  Navigator.pop(ctx);

                                  try {
                                    final user = Supabase
                                        .instance
                                        .client
                                        .auth
                                        .currentUser;
                                    final emailToUse = _partnerEmail.isNotEmpty
                                        ? _partnerEmail
                                        : user?.email;

                                    if (user != null &&
                                        newCombinedName.isNotEmpty) {
                                      await Supabase.instance.client
                                          .from('app_users')
                                          .update({'name': newCombinedName})
                                          .eq('supabase_user_id', user.id);
                                    } else if (emailToUse != null &&
                                        emailToUse.isNotEmpty &&
                                        newCombinedName.isNotEmpty) {
                                      await Supabase.instance.client
                                          .from('app_users')
                                          .update({'name': newCombinedName})
                                          .eq('email', emailToUse);
                                    }

                                    // Update Supabase auth user metadata so First, Middle, Last names stay synchronized
                                    try {
                                      final existingMeta =
                                          user?.userMetadata ?? {};
                                      final regName =
                                          (existingMeta['registered_name'] ??
                                                  existingMeta['original_name'] ??
                                                  _partnerName)
                                              .toString()
                                              .trim();
                                      await Supabase.instance.client.auth
                                          .updateUser(
                                            UserAttributes(
                                              data: {
                                                'first_name': first,
                                                'middle_initial': middle,
                                                'last_name': last,
                                                'full_name': newCombinedName,
                                                'name': newCombinedName,
                                                if (regName.isNotEmpty &&
                                                    regName.toLowerCase() !=
                                                        'partner investor')
                                                  'registered_name': regName,
                                              },
                                            ),
                                          );
                                    } catch (_) {}

                                    int? targetUserId;
                                    if (emailToUse != null &&
                                        emailToUse.isNotEmpty) {
                                      final appUser = await Supabase
                                          .instance
                                          .client
                                          .from('app_users')
                                          .select('user_id')
                                          .eq('email', emailToUse)
                                          .maybeSingle();

                                      if (appUser != null &&
                                          appUser['user_id'] != null) {
                                        targetUserId = appUser['user_id'] is int
                                            ? appUser['user_id'] as int
                                            : int.tryParse(
                                                appUser['user_id'].toString(),
                                              );
                                      }
                                    }
                                    targetUserId ??= _appUserId;

                                    if (targetUserId != null) {
                                      await Supabase.instance.client
                                          .from('partner_investors')
                                          .update({
                                            'contact_number':
                                                newPhone.isNotEmpty
                                                ? newPhone
                                                : null,
                                            'address': newAddr.isNotEmpty
                                                ? newAddr
                                                : null,
                                          })
                                          .eq('user_id', targetUserId);

                                      try {
                                        await Supabase.instance.client
                                            .from('app_users')
                                            .update({
                                              'address': newAddr.isNotEmpty
                                                  ? newAddr
                                                  : null,
                                            })
                                            .eq('user_id', targetUserId);
                                      } catch (_) {}
                                    } else if (_partnerInvestorId != null) {
                                      await Supabase.instance.client
                                          .from('partner_investors')
                                          .update({
                                            'contact_number':
                                                newPhone.isNotEmpty
                                                ? newPhone
                                                : null,
                                            'address': newAddr.isNotEmpty
                                                ? newAddr
                                                : null,
                                          })
                                          .eq(
                                            'partner_investor_id',
                                            _partnerInvestorId!,
                                          );
                                    }
                                  } catch (e) {
                                    debugPrint(
                                      'Error updating user name in DB: $e',
                                    );
                                  }

                                  if (mounted) {
                                    PiggyToast.showSuccess(
                                      context,
                                      strings.profileUpdateSuccess,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? Colors.white
                                      : const Color(0xFF18314F),
                                  foregroundColor: isDark
                                      ? const Color(0xFF0F172A)
                                      : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
      },
    );
  }

  Widget _buildFieldHeaderRow({
    required String label,
    required Color titleColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildInlineErrorText(String? errorText) {
    if (errorText == null || errorText.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 13,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              errorText,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEF4444),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInputField(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    Widget? suffixIcon,
    bool hasError = false,
    bool readOnly = false,
    VoidCallback? onTap,
    int? maxLength,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.words,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveFormatters =
        inputFormatters ??
        (keyboardType == TextInputType.phone
            ? null
            : const [CapitalizeWordsInputFormatter()]);
    final errorBorderColor = const Color(0xFFEF4444);
    final normalBorderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE6EBF2);

    return TextField(
      controller: controller,
      readOnly: readOnly,
      enableInteractiveSelection: !readOnly,
      showCursor: !readOnly,
      onTap: onTap,
      keyboardType: readOnly ? TextInputType.none : keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      inputFormatters: effectiveFormatters,
      onChanged: onChanged,
      style: GoogleFonts.plusJakartaSans(
        color: isDark ? Colors.white : const Color(0xFF18314F),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hintText,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          fontWeight: FontWeight.w500,
          fontSize: 13.5,
        ),
        prefixIcon: icon != null
            ? Icon(
                icon,
                size: 20,
                color: hasError
                    ? errorBorderColor
                    : (isDark ? Colors.white70 : const Color(0xFF18314F)),
              )
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        contentPadding: EdgeInsets.symmetric(
          horizontal: icon != null ? 14 : 16,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError ? errorBorderColor : normalBorderColor,
            width: hasError ? 1.4 : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError
                ? errorBorderColor
                : (isDark ? Colors.white : const Color(0xFF18314F)),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(
    DateTime dateTime, [
    bool isFilipino = false,
    bool hasExplicitTime = true,
  ]) {
    final now = DateTime.now();

    // If date-only was parsed and it's today, show "Today" instead of comparing against midnight (which gives 10h ago)
    if (!hasExplicitTime &&
        dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return isFilipino ? 'Ngayong araw' : 'Today';
    }

    final difference = now.difference(dateTime);
    if (difference.isNegative || difference.inMinutes < 1) {
      return isFilipino ? 'Kani-kanina lang' : 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ${isFilipino ? 'ang nakalipas' : 'ago'}';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ${isFilipino ? 'ang nakalipas' : 'ago'}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ${isFilipino ? 'ang nakalipas' : 'ago'}';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
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

      // SECURITY CHECK: If there is no authenticated user and no saved session email,
      // redirect immediately to onboarding so the app starts in a clean state.
      if (user == null && currentEmail.isEmpty) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/onboarding',
            (route) => false,
          );
        }
        return;
      }

      if (user != null) {
        // Initialize native notification listener for Partner Investor
        NotificationService().requestPermission();
        NotificationService().startRoleRealtimeListener(
          role: 'partner',
          userId: user.id,
        );
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

      String resolvedName = "";
      if (profile != null) {
        final rawName = (profile['name'] as String?)?.trim() ?? "";
        if (rawName.isNotEmpty &&
            rawName.toLowerCase() != 'partner investor' &&
            rawName.toLowerCase() != 'partner') {
          resolvedName = rawName;
        }
        if (profile['email'] != null &&
            profile['email'].toString().isNotEmpty) {
          _partnerEmail = profile['email'].toString();
        }
      }

      if (resolvedName.isEmpty && user != null) {
        final meta = user.userMetadata ?? {};
        final metaName =
            (meta['full_name'] ?? meta['name'] ?? meta['display_name'])
                ?.toString()
                .trim();
        if (metaName != null &&
            metaName.isNotEmpty &&
            metaName.toLowerCase() != 'partner investor' &&
            metaName.toLowerCase() != 'partner') {
          resolvedName = metaName;
        }
      }

      if (resolvedName.isEmpty && _partnerEmail.contains('@')) {
        final prefix = _partnerEmail.split('@').first.trim();
        if (prefix.isNotEmpty) {
          final parts = prefix.replaceAll(RegExp(r'[._-]'), ' ').split(' ');
          resolvedName = parts
              .where((p) => p.isNotEmpty)
              .map((p) => p[0].toUpperCase() + p.substring(1))
              .join(' ');
        }
      }

      if (resolvedName.isNotEmpty) {
        _partnerName = resolvedName;
      }

      final int? appUserId = profile?['user_id'] is int
          ? profile!['user_id'] as int
          : int.tryParse(profile?['user_id']?.toString() ?? '');
      _appUserId = appUserId;

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
            if (partnerRecord['contact_number'] != null &&
                partnerRecord['contact_number'].toString().isNotEmpty) {
              _partnerPhone = partnerRecord['contact_number'].toString();
            }
            if (partnerRecord['address'] != null &&
                partnerRecord['address'].toString().isNotEmpty) {
              _partnerAddress = partnerRecord['address'].toString();
            }
            final pAvatar = partnerRecord['avatar_url']?.toString().trim();
            if (pAvatar != null &&
                pAvatar.isNotEmpty &&
                (pAvatar.startsWith('http://') ||
                    pAvatar.startsWith('https://')) &&
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
          _partnerInvestorId = partnerInvestorId;
        } catch (e) {
          debugPrint('Notice on partner_investors record: $e');
        }
      }

      // 2. Fetch Batches, Assignments, Hog Raisers, and Hogs
      List<Map<String, dynamic>> allBatches = [];
      final Map<String, Map<String, dynamic>> raiserMap = {};
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
        try {
          final List<dynamic> raisersRes = await Supabase.instance.client
              .from('hog_raisers')
              .select(
                'hog_raiser_id, name, address, phone, pig_type, lifecycle_stage, user_id, status, account_status, app_users!hog_raisers_user_id_fkey(name, email, address, phone)',
              );

          for (var r in raisersRes) {
            if (r is! Map) continue;
            final rMap = Map<String, dynamic>.from(r);
            final rId = (rMap['hog_raiser_id'] ?? '').toString();
            if (rId.isEmpty) continue;

            final rStatus = (rMap['status'] ?? '').toString().toLowerCase();
            final rAccountStatus = (rMap['account_status'] ?? '')
                .toString()
                .toLowerCase();
            if (rStatus == 'inactive' ||
                rAccountStatus == 'pending' ||
                rAccountStatus == 'deleted' ||
                rAccountStatus == 'rejected') {
              continue;
            }

            dynamic appUsersRaw = rMap['app_users'];
            Map<String, dynamic>? appUsers;
            if (appUsersRaw is Map) {
              appUsers = Map<String, dynamic>.from(appUsersRaw);
            } else if (appUsersRaw is List &&
                appUsersRaw.isNotEmpty &&
                appUsersRaw.first is Map) {
              appUsers = Map<String, dynamic>.from(appUsersRaw.first);
            }

            final googleOrAppName = (appUsers?['name'] ?? '').toString().trim();
            final raiserName = (rMap['name'] ?? '').toString().trim();
            final resolvedFullName =
                (raiserName.isNotEmpty &&
                    raiserName.toLowerCase() != 'hog raiser' &&
                    raiserName.toUpperCase() != 'N/A')
                ? raiserName
                : (googleOrAppName.isNotEmpty &&
                          googleOrAppName.toLowerCase() != 'hog raiser'
                      ? googleOrAppName
                      : (raiserName.isNotEmpty ? raiserName : 'Hog Raiser'));

            final raiserAddress =
                (rMap['address'] ?? appUsers?['address'] ?? '')
                    .toString()
                    .trim();
            final raiserPhone = (rMap['phone'] ?? appUsers?['phone'] ?? '')
                .toString()
                .trim();

            final rawPigType = (rMap['pig_type'] ?? '').toString().trim();
            final safePigType =
                (rawPigType.isEmpty || rawPigType.toUpperCase() == 'N/A')
                ? 'Fattening'
                : rawPigType;

            final rawStage = (rMap['lifecycle_stage'] ?? '').toString().trim();
            final safeStage =
                (rawStage.isEmpty || rawStage.toUpperCase() == 'N/A')
                ? 'Grower'
                : rawStage;

            raiserMap[rId] = {
              'name': resolvedFullName,
              'address': raiserAddress.isNotEmpty
                  ? raiserAddress
                  : 'Farm Location Not Set',
              'phone': raiserPhone.isNotEmpty ? raiserPhone : 'N/A',
              'pig_type': safePigType,
              'lifecycle_stage': safeStage,
            };
          }
        } catch (rErr) {
          debugPrint(
            'Notice fetching raisers with app_users: $rErr. Retrying simple fetch...',
          );
          try {
            final List<dynamic> raisersSimple = await Supabase.instance.client
                .from('hog_raisers')
                .select(
                  'hog_raiser_id, name, address, phone, pig_type, lifecycle_stage, status, account_status',
                );
            for (var r in raisersSimple) {
              if (r is! Map) continue;
              final rMap = Map<String, dynamic>.from(r);
              final rId = (rMap['hog_raiser_id'] ?? '').toString();
              if (rId.isNotEmpty) {
                final rStatus = (rMap['status'] ?? '').toString().toLowerCase();
                final rAccountStatus = (rMap['account_status'] ?? '')
                    .toString()
                    .toLowerCase();
                if (rStatus == 'inactive' ||
                    rAccountStatus == 'pending' ||
                    rAccountStatus == 'deleted' ||
                    rAccountStatus == 'rejected') {
                  continue;
                }

                final raiserAddress = (rMap['address'] ?? '').toString().trim();
                final raiserPhone = (rMap['phone'] ?? '').toString().trim();

                final rawPigType = (rMap['pig_type'] ?? '').toString().trim();
                final safePigType =
                    (rawPigType.isEmpty || rawPigType.toUpperCase() == 'N/A')
                    ? 'Fattening'
                    : rawPigType;

                final rawStage = (rMap['lifecycle_stage'] ?? '')
                    .toString()
                    .trim();
                final safeStage =
                    (rawStage.isEmpty || rawStage.toUpperCase() == 'N/A')
                    ? 'Grower'
                    : rawStage;

                raiserMap[rId] = {
                  'name': (rMap['name'] ?? 'Hog Raiser').toString(),
                  'address': raiserAddress.isNotEmpty
                      ? raiserAddress
                      : 'Farm Location Not Set',
                  'phone': raiserPhone.isNotEmpty ? raiserPhone : 'N/A',
                  'pig_type': safePigType,
                  'lifecycle_stage': safeStage,
                };
              }
            }
          } catch (_) {}
        }

        // Fetch hog types
        final Map<String, String> hogTypeMap = {};
        try {
          final List<dynamic> typesRes = await Supabase.instance.client
              .from('hog_types')
              .select('hog_type_id, type_name');
          for (var t in typesRes) {
            if (t is Map && t['hog_type_id'] != null) {
              hogTypeMap[t['hog_type_id'].toString()] =
                  (t['type_name'] ?? 'Fattening').toString();
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
            if (r is Map &&
                r['hog_raiser_id'] != null &&
                r['total_hog'] != null) {
              final rId = r['hog_raiser_id'].toString();
              final count = (r['total_hog'] as num).toInt();
              raiserHogCountMap[rId] = count;
            }
          }
        } catch (_) {}

        List<dynamic> hogsRes = [];
        try {
          hogsRes = await Supabase.instance.client.from('hogs').select('*');
        } catch (hErr) {
          debugPrint('Notice on hogs query: $hErr');
        }

        for (var b in batchesRes) {
          final bId = b['batch_id'] ?? b['id'];
          final bIdStr = bId.toString();

          // Find all matching assignments for this batch
          final batchAssigns = assignmentsRes
              .where((a) {
                if (a is! Map) return false;
                return a['batch_id']?.toString() == bIdStr ||
                    a['id']?.toString() == bIdStr;
              })
              .map((a) => Map<String, dynamic>.from(a as Map))
              .toList();

          Map<String, dynamic>? matchingAssign;
          for (var a in batchAssigns) {
            if ((a['status'] ?? '').toString().toLowerCase() == 'active') {
              matchingAssign = a;
              break;
            }
            matchingAssign ??= a;
          }

          String raiserName = 'Unassigned';
          String raiserAddress = 'Farm Location Not Set';
          String raiserPhone = 'N/A';
          String stage = 'Grower';
          String hogType = 'Fattening';
          String? raiserIdStr;

          if (matchingAssign != null) {
            final rawRaiserId = (matchingAssign['hog_raiser_id'] ?? '')
                .toString();
            if (rawRaiserId.isNotEmpty && raiserMap.containsKey(rawRaiserId)) {
              final rData = raiserMap[rawRaiserId]!;
              raiserName = rData['name'] ?? 'Hog Raiser';
              raiserAddress = rData['address'] ?? 'Farm Location Not Set';
              raiserPhone = rData['phone'] ?? 'N/A';
              stage = rData['lifecycle_stage'] ?? 'Grower';
              hogType = rData['pig_type'] ?? 'Fattening';
              raiserIdStr = rawRaiserId;
            } else {
              // Raiser was deleted or no longer exists in hog_raisers table
              raiserName = 'Unassigned';
              raiserIdStr = null;
            }

            final rawTypeId = (matchingAssign['hog_type_id'] ?? '').toString();
            if (rawTypeId.isNotEmpty && hogTypeMap.containsKey(rawTypeId)) {
              hogType = hogTypeMap[rawTypeId]!;
            }
          } else {
            // Unassigned batch
            raiserName = 'Unassigned';
            raiserAddress = 'Farm Location Not Set';
            raiserPhone = 'N/A';
            stage = 'Grower';
            hogType = 'Fattening';
            raiserIdStr = null;
          }

          // Exclude batches that do not have an active registered hog raiser account
          if (raiserIdStr == null ||
              !raiserMap.containsKey(raiserIdStr) ||
              raiserName.trim().isEmpty ||
              raiserName.trim().toLowerCase() == 'unassigned') {
            continue;
          }

          // Fattening batches should not inherit 'Gilt' (breeding stage)
          if (hogType.toLowerCase().contains('fatten') &&
              stage.toLowerCase() == 'gilt') {
            stage = 'Booster';
          }

          // Collect all hogs linked to any assignment in this batch
          final batchAssignIds = batchAssigns
              .map((a) => (a['assignment_id'] ?? a['id'])?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .toSet();

          List<dynamic> rawBatchHogs = hogsRes.where((h) {
            final aId = h['assignment_id']?.toString();
            return aId != null && batchAssignIds.contains(aId);
          }).toList();

          if (rawBatchHogs.isEmpty) {
            final raiserAssignIds = assignmentsRes
                .where(
                  (a) => (a['hog_raiser_id'] ?? '').toString() == raiserIdStr,
                )
                .map((a) => (a['assignment_id'] ?? a['id'])?.toString())
                .where((id) => id != null && id.isNotEmpty)
                .toSet();
            final matchingHogs = hogsRes.where((h) {
              final aId = h['assignment_id']?.toString();
              return aId != null && raiserAssignIds.contains(aId);
            }).toList();
            if (matchingHogs.isNotEmpty) {
              // Sort descending to isolate the active cycle hogs for the latest batch
              matchingHogs.sort(
                (a, b) => ((b['hog_id'] as num?) ?? 0).compareTo(
                  (a['hog_id'] as num?) ?? 0,
                ),
              );
              final targetCount = raiserHogCountMap[raiserIdStr] ?? 3;
              final selected = matchingHogs.take(targetCount).toList();
              selected.sort(
                (a, b) => ((a['hog_id'] as num?) ?? 0).compareTo(
                  (b['hog_id'] as num?) ?? 0,
                ),
              );
              rawBatchHogs.addAll(selected);
            }
          }

          // Map each individual hog with its exact pig type and stage
          final mappedBatchHogs = <Map<String, dynamic>>[];
          // Filter out dead or inactive hogs before assigning sequential batch numbers
          final aliveBatchHogs = rawBatchHogs.where((h) {
            final st = (h['status'] ?? '').toString().toLowerCase();
            final hs = (h['health_status'] ?? '').toString().toLowerCase();
            return st != 'dead' && hs != 'dead' && st != 'completed';
          }).toList();

          final isMixedBatch =
              hogType.toLowerCase().contains('sow') &&
              hogType.toLowerCase().contains('fatten');
          final half = (aliveBatchHogs.length / 2).ceil();

          for (int i = 0; i < aliveBatchHogs.length; i++) {
            final h = aliveBatchHogs[i];
            final aId = h['assignment_id']?.toString();
            final assign = assignmentsRes.firstWhere(
              (a) => (a['assignment_id'] ?? a['id'])?.toString() == aId,
              orElse: () => matchingAssign ?? {},
            );
            final rawTypeId = (assign['hog_type_id'] ?? '').toString();
            String typeName =
                hogTypeMap[rawTypeId] ??
                (assign['pig_type'] ?? h['pig_type'] ?? '').toString().trim();

            if (typeName.isEmpty ||
                isMixedBatch ||
                typeName.toLowerCase().contains('and')) {
              typeName = (i < half) ? 'Fattening' : 'Sow / Breeding';
            } else if (typeName.toLowerCase().contains('sow') ||
                typeName.toLowerCase().contains('breed')) {
              typeName = 'Sow / Breeding';
            } else {
              typeName = 'Fattening';
            }

            final isSow =
                typeName.toLowerCase().contains('sow') ||
                typeName.toLowerCase().contains('breed');
            final sId = int.tryParse(h['stage_id']?.toString() ?? '');
            final stageList = isSow
                ? const [
                    'Booster',
                    'Pre-Starter',
                    'Starter',
                    'Grower',
                    'Breeder',
                    'Lactation',
                  ]
                : const [
                    'Booster',
                    'Pre-Starter',
                    'Starter',
                    'Grower',
                    'Finisher',
                    'Selling',
                  ];
            final stageName =
                (sId != null && sId >= 1 && sId <= stageList.length)
                ? stageList[sId - 1]
                : (isSow ? 'Booster' : stage);

            final rawWeight = h['current_weight'] ?? h['weight'];
            final weightStr = rawWeight != null ? '$rawWeight kg' : null;

            mappedBatchHogs.add({
              'hog_id': h['hog_id'] ?? (i + 1),
              'tag_number': 'HOG-${i + 1}',
              'index': i + 1,
              'pig_type': typeName,
              'stage_id': sId ?? 1,
              'stage': stageName,
              'health_status': (h['health_status'] ?? 'Healthy').toString(),
              'status': (h['status'] ?? 'active').toString(),
              'weight': weightStr,
            });
          }

          // Read actual hog count from hogs table; if 0, check investment_records allocation
          int hogsCount = mappedBatchHogs.isNotEmpty
              ? mappedBatchHogs.length
              : rawBatchHogs.length;
          if (hogsCount == 0 && raiserHogCountMap.containsKey(raiserIdStr)) {
            hogsCount = raiserHogCountMap[raiserIdStr]!;
          }

          // If hogs table had no rows but count is known (e.g. 3 active hogs), synthesize individual hogs
          if (mappedBatchHogs.isEmpty && hogsCount > 0) {
            final halfCount = (hogsCount / 2).ceil();
            for (int i = 0; i < hogsCount; i++) {
              final isSow =
                  i >= halfCount &&
                  (hogType.toLowerCase().contains('sow') ||
                      hogType.toLowerCase().contains('breed'));
              final typeLabel = isSow ? 'Sow / Breeding' : 'Fattening';
              final stageName = 'Booster';
              mappedBatchHogs.add({
                'hog_id': i + 1,
                'tag_number': 'HOG-${i + 1}',
                'index': i + 1,
                'pig_type': typeLabel,
                'stage_id': 1,
                'stage': stageName,
                'health_status': 'Healthy',
                'status': 'active',
              });
            }
          }

          // Strictly sort mappedBatchHogs so Fattening hogs come first, Sow/Breeding hogs come last!
          mappedBatchHogs.sort((a, b) {
            final aType = (a['pig_type'] ?? '').toString().toLowerCase();
            final bType = (b['pig_type'] ?? '').toString().toLowerCase();
            final aIsFat = aType.contains('fatten');
            final bIsFat = bType.contains('fatten');
            if (aIsFat && !bIsFat) return -1;
            if (!aIsFat && bIsFat) return 1;
            final aId = (a['hog_id'] as num?)?.toInt() ?? 0;
            final bId = (b['hog_id'] as num?)?.toInt() ?? 0;
            return aId.compareTo(bId);
          });

          // Re-index tag numbers sequentially to match Raiser App (HOG-1, HOG-2 Fattening; HOG-3 Sow)
          for (int idx = 0; idx < mappedBatchHogs.length; idx++) {
            mappedBatchHogs[idx]['tag_number'] = 'HOG-${idx + 1}';
            mappedBatchHogs[idx]['index'] = idx + 1;
          }

          final int mortality = mappedBatchHogs
              .where(
                (h) =>
                    (h['health_status'] ?? '').toString().toLowerCase() ==
                    'dead',
              )
              .length;

          final hasSow = mappedBatchHogs.any(
            (h) =>
                (h['pig_type'] ?? '').toString().toLowerCase().contains('sow'),
          );
          final hasFattening = mappedBatchHogs.any(
            (h) => (h['pig_type'] ?? '').toString().toLowerCase().contains(
              'fatten',
            ),
          );
          final compositeType = (hasSow && hasFattening)
              ? 'Fattening, Sow/Breeding'
              : (hasSow ? 'Sow / Breeding' : 'Fattening');

          allBatches.add({
            'batch_id': bId,
            'batch_name': b['batch_name'] ?? b['name'] ?? 'Batch #$bId',
            'assigned_raiser': raiserName,
            'raiser_name': raiserName,
            'address': raiserAddress,
            'location': raiserAddress,
            'phone': raiserPhone,
            'contact': raiserPhone,
            'hog_type': compositeType,
            'total_hogs': mappedBatchHogs.isNotEmpty
                ? mappedBatchHogs.length
                : hogsCount,
            'mortality': mortality,
            'stage': stage,
            'hogs': mappedBatchHogs,
            'date_created': b['date_created'],
            'hog_raiser_id': int.tryParse(raiserIdStr),
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
              'batch_name': 'Batch ${r['raiser_name'] ?? 'Livestock'}',
              'assigned_raiser': r['raiser_name'] ?? 'Assigned Raiser',
              'raiser_name': r['raiser_name'] ?? 'Assigned Raiser',
              'hog_type': r['hog_type'] ?? 'Fattening',
              'total_hogs': (r['total_hog'] as num?)?.toInt() ?? 15,
              'mortality': 0,
              'stage': rStage == 'ACTIVE' || rStage == 'PENDING'
                  ? 'Grower'
                  : (r['stage'] ?? 'Grower'),
              'date_created': r['investment_date'],
              'hog_raiser_id': r['hog_raiser_id'],
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
              .select(
                'hog_raiser_id, name, pig_type, lifecycle_stage, status, account_status',
              )
              .order('hog_raiser_id', ascending: true);

          for (var r in raisers) {
            final statusStr = (r['status'] ?? '').toString().toLowerCase();
            final accountStatusStr = (r['account_status'] ?? '')
                .toString()
                .toLowerCase();
            if (statusStr == 'archived' ||
                statusStr == 'inactive' ||
                accountStatusStr == 'archived' ||
                accountStatusStr == 'pending') {
              continue;
            }

            final rawType = (r['pig_type'] ?? '').toString().trim();
            final safeType = (rawType.isEmpty || rawType.toUpperCase() == 'N/A')
                ? 'Fattening'
                : rawType;

            final rawStage = (r['lifecycle_stage'] ?? '').toString().trim();
            final safeStage =
                (rawStage.isEmpty || rawStage.toUpperCase() == 'N/A')
                ? 'Grower'
                : rawStage;

            final rId = r['hog_raiser_id'];
            allBatches.add({
              'batch_id': rId,
              'batch_name': 'Batch ${r['name'] ?? 'Livestock'}',
              'assigned_raiser': r['name'] ?? 'Hog Raiser',
              'raiser_name': r['name'] ?? 'Hog Raiser',
              'hog_type': safeType,
              'total_hogs': 15,
              'mortality': 0,
              'stage': safeStage,
              'hog_raiser_id': rId,
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
            .select(
              'investment_id, amount, date_invested, status, batch_id, partner_investor_id',
            );

        if (partnerInvestorId != null) {
          query = query.eq('partner_investor_id', partnerInvestorId);
        }

        final investmentsRes = await query.order(
          'date_invested',
          ascending: false,
        );

        if (investmentsRes.isNotEmpty) {
          for (var inv in investmentsRes) {
            final amt = (inv['amount'] as num?)?.toDouble() ?? 0.0;
            final status = (inv['status'] ?? 'pending')
                .toString()
                .toLowerCase();
            if (status == 'active' || status == 'approved') {
              totalInvested += amt;
            }

            final bId = inv['batch_id']?.toString();
            final matchingBatches = allBatches
                .where((b) => b['batch_id']?.toString() == bId)
                .toList();
            if (matchingBatches.isEmpty) {
              // Defunct or non-existent batch with no registered raiser - do not include in partnerProjects
              continue;
            }
            final matchingBatch = matchingBatches.first;

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

      // Also merge local/session investments for instant reflection and offline persistence
      try {
        final localInvs = await AuthSessionService().getLocalInvestments();
        for (var lInv in localInvs) {
          final lId = lInv['investment_id']?.toString();
          final alreadyPresent = partnerProjects.any(
            (p) => p['investment_id']?.toString() == lId,
          );
          if (!alreadyPresent) {
            final amt = (lInv['amount'] as num?)?.toDouble() ?? 0.0;
            final status = (lInv['status'] ?? 'active')
                .toString()
                .toLowerCase();
            if (status == 'active' || status == 'approved') {
              totalInvested += amt;
            }
            final bId = lInv['batch_id']?.toString();
            final matchingBatches = allBatches
                .where((b) => b['batch_id']?.toString() == bId)
                .toList();
            if (matchingBatches.isEmpty) {
              continue;
            }
            final matchingBatch = matchingBatches.first;

            partnerProjects.add({
              ...matchingBatch,
              ...lInv,
              'invested_amount': amt,
            });
          }
        }
      } catch (lErr) {
        debugPrint('Notice on local investments merge: $lErr');
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

      // 4. Fetch Live Hog Raiser Activities strictly for this Partner's funded batches & active investment cycle
      List<Map<String, dynamic>> liveActivities = [];

      // Collect mapping of funded batch_id -> earliest investment date for this partner
      final Map<String, DateTime> fundedBatchInvestmentDates = {};
      for (var p in partnerProjects) {
        final st = (p['status'] ?? '').toString().toLowerCase();
        if (st == 'active' || st == 'approved') {
          final bId = p['batch_id']?.toString();
          if (bId != null && bId.isNotEmpty) {
            final rawDate = (p['created_at'] ?? p['date_invested'] ?? '')
                .toString();
            final invDate = DateTime.tryParse(rawDate);
            if (invDate != null) {
              if (!fundedBatchInvestmentDates.containsKey(bId) ||
                  invDate.isBefore(fundedBatchInvestmentDates[bId]!)) {
                fundedBatchInvestmentDates[bId] = invDate;
              }
            } else {
              fundedBatchInvestmentDates.putIfAbsent(bId, () => DateTime(2000));
            }
          }
        }
      }

      // Only query hog_reports if this partner investor has active funded batches
      if (fundedBatchInvestmentDates.isNotEmpty) {
        try {
          final reportsRes = await Supabase.instance.client
              .from('hog_reports')
              .select(
                'report_id, report_type, description, created_at, hog_raiser_id, hog_id, batch_id',
              )
              .order('created_at', ascending: false)
              .limit(50);

          for (var rep in reportsRes) {
            final repBatchId = rep['batch_id']?.toString();
            // Filter 1: Must match one of the partner's funded batches
            if (repBatchId == null ||
                !fundedBatchInvestmentDates.containsKey(repBatchId)) {
              continue;
            }

            final createdAt = rep['created_at'] != null
                ? DateTime.tryParse(rep['created_at'].toString()) ??
                      DateTime.now()
                : DateTime.now();

            // Filter 2: Must have occurred ON OR AFTER the partner's investment date
            // (Historical reports prior to the partner's investment date are excluded)
            final invDate = fundedBatchInvestmentDates[repBatchId]!;
            final invDayStart = DateTime(
              invDate.year,
              invDate.month,
              invDate.day,
            );
            if (createdAt.isBefore(invDayStart)) {
              continue;
            }

            final rType = (rep['report_type'] ?? 'Health Check').toString();
            final desc = (rep['description'] ?? '').toString();
            final rId = rep['hog_raiser_id']?.toString() ?? '';
            final raiserName = raiserMap[rId]?['name'] ?? 'Hog Raiser';

            IconData icon = Icons.assignment_outlined;
            final lower = rType.toLowerCase();
            String titleEn = '$rType Alert';
            String titleFil = 'Alerto: $rType';

            if (lower.contains('dead') || lower.contains('mortality')) {
              icon = Icons.error_outline_rounded;
              titleEn = 'Mortality Report';
              titleFil = 'Ulat ng Pagkamatay';
            } else if (lower.contains('sick') ||
                lower.contains('fever') ||
                lower.contains('swine') ||
                lower.contains('poison') ||
                lower.contains('diarrhea') ||
                lower.contains('injur')) {
              icon = Icons.health_and_safety_rounded;
              titleEn = 'Health Observation: $rType';
              titleFil = 'Pagsusuri sa Kalusugan: $rType';
            } else if (lower.contains('vaccin') ||
                lower.contains('med') ||
                lower.contains('deworm')) {
              icon = Icons.medication_rounded;
              titleEn = 'Vaccine & Medication';
              titleFil = 'Bakuna at Gamot';
            } else if (lower.contains('feed') || lower.contains('weight')) {
              icon = Icons.monitor_weight_rounded;
              titleEn = 'Feeding & Nutrition';
              titleFil = 'Pagpapakain at Nutrisyon';
            } else if (lower.contains('stage') || lower.contains('growth')) {
              icon = Icons.trending_up_rounded;
              titleEn = 'Lifecycle Milestone';
              titleFil = 'Yugto ng Paglaki';
            }

            liveActivities.add({
              'report_id': rep['report_id'],
              'title': titleEn,
              'title_en': titleEn,
              'title_fil': titleFil,
              'description': desc.isNotEmpty
                  ? desc
                  : 'Health update submitted by $raiserName',
              'desc_en': desc.isNotEmpty
                  ? desc
                  : 'Health update submitted by $raiserName',
              'desc_fil': desc.isNotEmpty
                  ? desc
                  : 'Ulat pangkalusugan mula kay $raiserName',
              'date': _formatRelativeTime(createdAt),
              'created_at': rep['created_at'],
              'icon': icon,
              'raiser_name': raiserName,
              'type': rType,
            });
          }
        } catch (e) {
          debugPrint('Notice fetching hog reports for funded raisers: $e');
        }
      }

      // Include investment milestones in Recent Activities
      for (var p in partnerProjects) {
        final amt = p['invested_amount'] ?? p['amount'] ?? 0.0;
        final rawBName = (p['batch_name'] ?? 'Batch #${p['batch_id']}')
            .toString();
        final cleanBatch = rawBName
            .replaceAll(RegExp(r'\s*\(#\d+\)'), '')
            .trim();
        final rawRName =
            (p['assigned_raiser'] ?? p['raiser_name'] ?? 'Hog Raiser')
                .toString();
        final cleanRaiser = rawRName
            .replaceAll(RegExp(r'\s*\(#\d+\)'), '')
            .trim();

        final rawTime = (p['created_at'] ?? p['date_invested'] ?? '')
            .toString();
        final bool hasTime = rawTime.contains('T') || rawTime.contains(':');
        DateTime invDate = DateTime.tryParse(rawTime) ?? DateTime.now();
        if (invDate.isUtc) {
          invDate = invDate.toLocal();
        }

        final amtVal =
            (amt is num ? amt : (double.tryParse(amt.toString()) ?? 0))
                .toDouble();
        final formattedAmt = amtVal
            .toStringAsFixed(2)
            .replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            );

        final descTarget = cleanBatch.toLowerCase().startsWith('batch')
            ? cleanBatch
            : 'Batch $cleanBatch';

        liveActivities.add({
          'report_id': 'inv_${p['investment_id']}',
          'title': 'Active Investment',
          'title_en': 'Active Investment',
          'title_fil': 'Aktibong Pamumuhunan',
          'description': 'Funded ₱$formattedAmt for $descTarget.',
          'desc_en': 'Funded ₱$formattedAmt for $descTarget.',
          'desc_fil': 'Naglaan ng ₱$formattedAmt para sa $descTarget.',
          'date': _formatRelativeTime(invDate, false, hasTime),
          'date_fil': _formatRelativeTime(invDate, true, hasTime),
          'created_at': rawTime.isNotEmpty
              ? rawTime
              : invDate.toIso8601String(),
          'icon': Icons.assignment_rounded,
          'raiser_name': cleanRaiser,
          'type': 'Investment',
        });
      }

      // Include individual hog stage milestones for ALL active batches funded by the Partner Investor
      for (var pBatch in partnerProjects) {
        final pStatus = (pBatch['status'] ?? '').toString().toLowerCase();
        if (pStatus != 'active' && pStatus != 'approved') {
          continue;
        }

        final rId = (pBatch['hog_raiser_id'] ?? '').toString();
        final rawRaiserName =
            (pBatch['assigned_raiser'] ?? pBatch['raiser_name'] ?? '')
                .toString()
                .trim();

        // 1. STRICT VERIFICATION: If the raiser was deleted from the database or is unassigned,
        // do NOT display ghost milestone feeds for them!
        final bool isRaiserActiveInDb =
            rId.isNotEmpty && raiserMap.containsKey(rId);
        if (!isRaiserActiveInDb ||
            rawRaiserName.isEmpty ||
            rawRaiserName.toLowerCase() == 'unassigned' ||
            rawRaiserName.toLowerCase().startsWith('raiser #') ||
            rawRaiserName.toLowerCase() == 'n/a') {
          continue;
        }

        final bRaiser = rawRaiserName;
        final batchHogsList = List<Map<String, dynamic>>.from(
          pBatch['hogs'] ?? [],
        );
        final batchCreatedTime =
            (pBatch['created_at'] ?? pBatch['date_invested'] ?? '').toString();

        // 2. Only include active hogs (exclude dead or completed hogs)
        final activeHogs = batchHogsList.where((h) {
          final st = (h['status'] ?? '').toString().toLowerCase();
          final hs = (h['health_status'] ?? '').toString().toLowerCase();
          return st != 'dead' && hs != 'dead' && st != 'completed';
        }).toList();

        for (int idx = 0; idx < activeHogs.length; idx++) {
          final hog = activeHogs[idx];
          final hTag = hog['tag_number'] ?? 'HOG-${idx + 1}';
          final hType = hog['pig_type'] ?? (pBatch['hog_type'] ?? 'Fattening');
          final hStage = hog['stage'] ?? (pBatch['stage'] ?? 'Booster');
          liveActivities.add({
            'report_id':
                'stage_${pBatch['batch_id']}_${hog['hog_id'] ?? (idx + 1)}',
            'title': '$hTag ($hType) • $hStage Stage',
            'title_en': '$hTag ($hType) • $hStage Stage',
            'title_fil': '$hTag ($hType) • Yugtong $hStage',
            'description':
                'Assigned raiser is currently managing $hTag ($hType) at the $hStage lifecycle stage.',
            'desc_en':
                'Assigned raiser is currently managing $hTag ($hType) at the $hStage lifecycle stage.',
            'desc_fil':
                'Kasalukuyang inaalagaan ng nakatalagang raiser ang $hTag ($hType) sa yugtong $hStage.',
            'date': '',
            'date_fil': '',
            'created_at': batchCreatedTime.isNotEmpty
                ? batchCreatedTime
                : DateTime.now().toIso8601String(),
            'icon': Icons.trending_up_rounded,
            'raiser_name': bRaiser,
            'type': 'Lifecycle',
          });
        }
      }

      // Sort liveActivities chronologically (newest updates first)
      liveActivities.sort((a, b) {
        final aTimeStr = (a['created_at'] ?? '').toString();
        final bTimeStr = (b['created_at'] ?? '').toString();
        final aTime = DateTime.tryParse(aTimeStr) ?? DateTime(2000);
        final bTime = DateTime.tryParse(bTimeStr) ?? DateTime(2000);
        final timeComp = bTime.compareTo(aTime);
        if (timeComp != 0) return timeComp;

        // If identical timestamp, keep Investment first, then HOG-1, HOG-2, HOG-3 in order
        final aType = (a['type'] ?? '').toString();
        final bType = (b['type'] ?? '').toString();
        if (aType == 'Investment' && bType != 'Investment') return -1;
        if (bType == 'Investment' && aType != 'Investment') return 1;

        final aTitle = (a['title'] ?? '').toString();
        final bTitle = (b['title'] ?? '').toString();
        return aTitle.compareTo(bTitle);
      });

      _activitiesList.clear();
      _activitiesList.addAll(liveActivities);

      // 5. Fetch partner notifications strictly from `partner_notifications` table
      try {
        var partnerNotifsQuery = Supabase.instance.client
            .from('partner_notifications')
            .select('*');

        if (partnerInvestorId != null) {
          partnerNotifsQuery = partnerNotifsQuery.eq(
            'partner_investor_id',
            partnerInvestorId,
          );
        }

        final List<dynamic> pNotifs = await partnerNotifsQuery
            .order('created_at', ascending: false)
            .limit(40);

        if (pNotifs.isNotEmpty) {
          final List<Map<String, dynamic>> deduped = [];
          final Set<String> seenKeys = <String>{};

          for (var raw in pNotifs) {
            if (raw is! Map) continue;
            final notif = Map<String, dynamic>.from(raw);
            final notifId = (notif['notification_id'] as num?)?.toInt();
            final key = _buildNotificationDeduplicationKey(notif);

            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              notif['linked_ids'] = notifId != null ? <int>[notifId] : <int>[];
              deduped.add(notif);
            } else {
              // Merge duplicate into existing record: keep all duplicate IDs linked
              final existingIndex = deduped.indexWhere(
                (item) => _buildNotificationDeduplicationKey(item) == key,
              );
              if (existingIndex != -1) {
                final existing = deduped[existingIndex];
                final List<int> linked = List<int>.from(
                  existing['linked_ids'] ?? [],
                );
                if (notifId != null && !linked.contains(notifId)) {
                  linked.add(notifId);
                }
                existing['linked_ids'] = linked;
                // If ANY duplicate copy is unread, the visible notification remains unread
                if (notif['is_read'] != true) {
                  existing['is_read'] = false;
                }
              }
            }
          }
          _notificationsList = deduped;
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

    _autoDetectLocationIfNeeded();
  }

  Future<void> _autoDetectLocationIfNeeded() async {
    if (kIsWeb) return;

    final currentAddress = _partnerAddress.trim();
    final bool hasValidAddress =
        currentAddress.isNotEmpty &&
        currentAddress != 'N/A' &&
        currentAddress != 'Not Set' &&
        currentAddress != 'Farm Location Not Set' &&
        currentAddress != 'Location Not Set';

    // If partner already has a valid address saved, do not prompt
    if (hasValidAddress) return;

    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? _appUserId?.toString();
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final promptKey = 'prompted_location_partner_$userId';
    if (prefs.getBool(promptKey) == true) return;

    try {
      final result = await LocationService.instance.getCurrentAddress(
        requestPermission: true,
      );

      // Save prompt flag so we don't prompt repeatedly on every screen load
      await prefs.setBool(promptKey, true);

      if (result.success &&
          result.address != null &&
          result.address!.trim().isNotEmpty) {
        final detectedAddress = result.address!.trim();

        if (_partnerInvestorId != null) {
          try {
            await Supabase.instance.client
                .from('partner_investors')
                .update({'address': detectedAddress})
                .eq('partner_investor_id', _partnerInvestorId!);
          } catch (e) {
            debugPrint('Error updating partner_investors address by id: $e');
          }
        } else if (_appUserId != null) {
          try {
            await Supabase.instance.client
                .from('partner_investors')
                .update({'address': detectedAddress})
                .eq('user_id', _appUserId!);
          } catch (e) {
            debugPrint(
              'Error updating partner_investors address by user_id: $e',
            );
          }
        }

        if (_appUserId != null) {
          try {
            await Supabase.instance.client
                .from('app_users')
                .update({'address': detectedAddress})
                .eq('user_id', _appUserId!);
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _partnerAddress = detectedAddress;
          });
          final strings = AppStrings.of(context);
          PiggyToast.showSuccess(
            context,
            '${strings.locationSavedToast} $detectedAddress',
          );
        }
      }
    } catch (e) {
      debugPrint('[LocationPrompt] Error requesting partner location: $e');
    }
  }

  Future<void> _handleLogout() async {
    await AuthSessionService().clearSession();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  String _buildNotificationDeduplicationKey(Map<String, dynamic> notif) {
    final meta = notif['metadata'];
    dynamic reportId;
    if (meta is Map) {
      reportId = meta['report_id'] ?? meta['reportId'];
    }
    if (reportId != null && reportId.toString().trim().isNotEmpty) {
      return 'rep_${reportId.toString().trim()}';
    }

    final cleanTitle = NotificationService.cleanText(
      notif['title']?.toString() ?? '',
    ).trim().toLowerCase();
    final cleanMsg = NotificationService.cleanText(
      notif['message']?.toString() ?? '',
    ).trim().toLowerCase();
    final rawTime = notif['created_at']?.toString() ?? '';
    final datePrefix = rawTime.length >= 10 ? rawTime.substring(0, 10) : '';
    return '${cleanTitle}___${cleanMsg}___$datePrefix';
  }

  Future<void> _markNotificationAsRead(int id) async {
    List<int> idsToMark = [id];

    setState(() {
      final index = _notificationsList.indexWhere((n) {
        final nid = (n['notification_id'] ?? '').toString();
        final linked =
            (n['linked_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];
        return nid == id.toString() || linked.contains(id.toString());
      });
      if (index != -1) {
        final item = _notificationsList[index];
        item['is_read'] = true;
        final linked = (item['linked_ids'] as List?)?.cast<int>() ?? [];
        if (linked.isNotEmpty) {
          idsToMark = linked;
        }
      }
    });

    try {
      if (idsToMark.length == 1) {
        await Supabase.instance.client
            .from('partner_notifications')
            .update({'is_read': true})
            .eq('notification_id', idsToMark.first);
      } else {
        await Supabase.instance.client
            .from('partner_notifications')
            .update({'is_read': true})
            .inFilter('notification_id', idsToMark);
      }
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
      final Set<int> allIds = {};
      for (var n in _notificationsList) {
        final nid = (n['notification_id'] as num?)?.toInt();
        if (nid != null) allIds.add(nid);
        final linked = (n['linked_ids'] as List?)?.cast<int>() ?? [];
        allIds.addAll(linked);
      }

      if (allIds.isNotEmpty) {
        await Supabase.instance.client
            .from('partner_notifications')
            .update({'is_read': true})
            .inFilter('notification_id', allIds.toList());
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

    final List<Widget> tabs = [
      PartnerHomeTab(
        partnerName: _partnerName,
        investedAmount: _investedAmount,
        activeProjectsCount: _activeProjectsCount,
        projectsList: _availableBatches,
        fundedProjectsList: _projectsList,
        activitiesList: _activitiesList,
        notificationsList: _notificationsList,
        onRefresh: _fetchPartnerData,
        onSeeAllActivities: () => setState(() => _currentIndex = 3),
        onViewProjects: () => setState(() => _currentIndex = 1),
        onNavigateToTab: (idx) {
          setState(() {
            _currentIndex = idx.clamp(0, 4);
          });
        },
        onMarkNotificationAsRead: _markNotificationAsRead,
        onMarkAllRead: _markAllNotificationsRead,
      ),
      PartnerProjectsTab(
        projectsList: _availableBatches,
        onRefresh: _fetchPartnerData,
      ),
      PartnerLifecycleTab(
        projectsList: _projectsList,
        batchName: _projectsList.isNotEmpty
            ? _projectsList.first['batch_name']?.toString()
            : null,
        raiserName: _projectsList.isNotEmpty
            ? (_projectsList.first['assigned_raiser'] ??
                      _projectsList.first['raiser_name'])
                  ?.toString()
            : null,
        hogsList: _projectsList.isNotEmpty
            ? List<Map<String, dynamic>>.from(_projectsList.first['hogs'] ?? [])
            : [],
        currentStage:
            (_projectsList.isNotEmpty
                    ? (_projectsList.first['stage'] ??
                          _projectsList.first['lifecycle_stage'])
                    : 'Booster')
                .toString(),
        hogType: _projectsList.isNotEmpty
            ? (_projectsList.first['hog_type']?.toString() ?? 'Fattening')
            : 'Fattening',
        hasActiveProject: _projectsList.isNotEmpty,
        activitiesList: _activitiesList,
        onRefresh: _fetchPartnerData,
        onNavigateToBatches: () => setState(() => _currentIndex = 1),
      ),
      PartnerActivitiesTab(
        activitiesList: _activitiesList,
        onRefresh: _fetchPartnerData,
        onNavigateToBatches: () => setState(() => _currentIndex = 1),
        onNavigateToLifecycle: () => setState(() => _currentIndex = 2),
      ),
      PartnerProfileTab(
        partnerName: _partnerName,
        partnerEmail: _partnerEmail,
        partnerPhone: _partnerPhone,
        partnerAddress: _partnerAddress,
        partnerAvatarUrl: _partnerAvatarUrl,
        onPickAndUploadAvatar: _handleAvatarTap,
        onRestoreDefaultAvatar: _restoreDefaultAvatar,
        onResetProfile: _resetProfileToDefault,
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
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          PiggyToast.showInfo(
            context,
            strings.isFilipino
                ? 'Pindutin ulit ang Back button upang isara ang app.'
                : 'Press back again to exit the app.',
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        extendBody: true,
        body: SafeArea(
          child: _isLoading
              ? PartnerDashboardSkeleton(currentIndex: _currentIndex)
              : IndexedStack(index: _currentIndex, children: tabs),
        ),
        bottomNavigationBar: PartnerLiquidBottomBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}
