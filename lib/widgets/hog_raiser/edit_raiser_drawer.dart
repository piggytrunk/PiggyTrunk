import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/capitalization_formatters.dart';

class EditRaiserDrawer {
  static int? _parseId(dynamic rawId) {
    if (rawId == null) return null;
    if (rawId is int) return rawId;
    return int.tryParse(rawId.toString());
  }

  static String? _getAvatarUrl(Map<String, dynamic> row) {
    final appUsers = row['app_users'] as Map<String, dynamic>?;
    final metadata = row['raw_user_meta_data'] as Map<String, dynamic>?;
    final dynamic candidate = row['avatar_url'] ??
        row['profile_picture'] ??
        row['photo_url'] ??
        row['image_url'] ??
        row['profile_image'] ??
        row['picture'] ??
        appUsers?['avatar_url'] ??
        appUsers?['profile_picture'] ??
        appUsers?['photo_url'] ??
        appUsers?['picture'] ??
        metadata?['avatar_url'] ??
        metadata?['picture'];

    if (candidate != null) {
      final str = candidate.toString().trim();
      if (str.startsWith('http://') || str.startsWith('https://')) {
        return str;
      }
    }
    return null;
  }

  static void show({
    required BuildContext context,
    required Map<String, dynamic> row,
    required VoidCallback onUpdated,
    required void Function(String msg, {bool isError}) onShowSnackBar,
  }) {
    final id = _parseId(row['id'] ?? row['hog_raiser_id']);
    final userId = _parseId(row['user_id']);
    if (id == null) return;

    final initialName = (row['name'] ?? '').toString();
    final initialPhone = (row['phone'] ?? '').toString();
    final initialAddress = (row['address'] ?? '').toString();
    final status = (row['status'] ?? 'Active').toString().toUpperCase();
    final avatarUrl = _getAvatarUrl(row);

    final nameCtrl = TextEditingController(text: initialName == 'N/A' ? '' : initialName);
    final phoneCtrl = TextEditingController(text: initialPhone == 'N/A' ? '' : initialPhone);
    final addressCtrl = TextEditingController(text: initialAddress == 'N/A' ? '' : initialAddress);

    final initials = initialName.trim().isNotEmpty && initialName != 'N/A'
        ? initialName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase()
        : 'HR';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Hog Raiser',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, anim1, anim2) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surfaceColor = isDark ? const Color(0xFF132238) : Colors.white;
        final borderColor = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
        final titleTextColor = isDark ? Colors.white : const Color(0xFF18314F);
        final mutedTextColor = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
        final fieldBgColor = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF8FAFC);
        final fieldBorderColor = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
        final fieldFocusColor = isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;

        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final drawerWidth = isMobile ? screenWidth : 420.0;

        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: drawerWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                color: surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                    blurRadius: 32,
                    spreadRadius: 2,
                    offset: const Offset(-6, 0),
                  ),
                ],
                border: Border(
                  left: BorderSide(color: borderColor, width: 1.2),
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 20, 18, isMobile ? 12 : 16, 16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.22),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.edit_note_rounded,
                                  color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Edit Hog Raiser Details',
                                style: AppTextStyles.jakarta(
                                  size: 17,
                                  weight: FontWeight.w800,
                                  color: titleTextColor,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: mutedTextColor, size: 20),
                            tooltip: 'Close',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Raiser Profile Header Card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A2B44) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF132238) : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                        ? Image.network(
                                            avatarUrl,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Padding(
                                              padding: const EdgeInsets.all(6),
                                              child: Image.asset(
                                                'assets/piggytrunk_logo.png',
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, _, _) => Center(
                                                  child: Text(
                                                    initials,
                                                    style: AppTextStyles.jakarta(
                                                      size: 15,
                                                      weight: FontWeight.w800,
                                                      color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Image.asset(
                                              'assets/piggytrunk_logo.png',
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, _, _) => Center(
                                                child: Text(
                                                  initials,
                                                  style: AppTextStyles.jakarta(
                                                    size: 15,
                                                    weight: FontWeight.w800,
                                                    color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          initialName.isEmpty ? 'Hog Raiser' : initialName,
                                          style: AppTextStyles.jakarta(
                                            size: 14.5,
                                            weight: FontWeight.w700,
                                            color: titleTextColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: status == 'ACTIVE'
                                                ? PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.15)
                                                : Colors.orangeAccent.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: status == 'ACTIVE' ? PiggyTrunkTheme.ptSuccess : Colors.orangeAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Full Name Field
                            Text(
                              'Full Name',
                              style: AppTextStyles.jakarta(
                                size: 13,
                                weight: FontWeight.w700,
                                color: titleTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: nameCtrl,
                              inputFormatters: const [CapitalizeWordsInputFormatter()],
                              style: AppTextStyles.body(titleTextColor),
                              decoration: InputDecoration(
                                hintText: 'Enter full name',
                                hintStyle: AppTextStyles.body(mutedTextColor),
                                prefixIcon: Icon(Icons.person_outline_rounded, size: 18, color: mutedTextColor),
                                filled: true,
                                fillColor: fieldBgColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: fieldBorderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: fieldFocusColor, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Phone Number Field
                            Text(
                              'Phone Number',
                              style: AppTextStyles.jakarta(
                                size: 13,
                                weight: FontWeight.w700,
                                color: titleTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(11),
                              ],
                              style: AppTextStyles.body(titleTextColor),
                              decoration: InputDecoration(
                                hintText: 'Enter phone number (e.g. 09123456789)',
                                hintStyle: AppTextStyles.body(mutedTextColor),
                                prefixIcon: Icon(Icons.phone_outlined, size: 18, color: mutedTextColor),
                                filled: true,
                                fillColor: fieldBgColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: fieldBorderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: fieldFocusColor, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Address Field
                            Text(
                              'Address / Farm Location',
                              style: AppTextStyles.jakarta(
                                size: 13,
                                weight: FontWeight.w700,
                                color: titleTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: addressCtrl,
                              maxLines: 2,
                              inputFormatters: const [CapitalizeWordsInputFormatter()],
                              style: AppTextStyles.body(titleTextColor),
                              decoration: InputDecoration(
                                hintText: 'Enter complete street address / barangay / municipality',
                                hintStyle: AppTextStyles.body(mutedTextColor),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: Icon(Icons.location_on_outlined, size: 18, color: mutedTextColor),
                                ),
                                filled: true,
                                fillColor: fieldBgColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: fieldBorderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: fieldFocusColor, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer Actions
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        border: Border(top: BorderSide(color: borderColor, width: 1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF1E2D42) : Colors.white,
                                foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF28405D) : const Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppTextStyles.jakarta(
                                  size: 13.5,
                                  weight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                try {
                                  final pkCol = row['id'] != null ? 'id' : 'hog_raiser_id';
                                  await Supabase.instance.client.from('hog_raisers').update({
                                    'name': nameCtrl.text.trim(),
                                    'phone': phoneCtrl.text.trim(),
                                    'address': addressCtrl.text.trim(),
                                  }).eq(pkCol, id);

                                  if (userId != null) {
                                    try {
                                      await Supabase.instance.client.from('app_users').update({
                                        'name': nameCtrl.text.trim(),
                                      }).eq('user_id', userId);
                                    } catch (_) {}
                                  }

                                  onUpdated();
                                  onShowSnackBar('Hog raiser profile updated successfully.');
                                } catch (e) {
                                  onShowSnackBar('Update failed: $e', isError: true);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                              ),
                              label: Text(
                                'Save Changes',
                                style: AppTextStyles.jakarta(
                                  size: 13.5,
                                  weight: FontWeight.w700,
                                  color: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (dialogContext, anim, secondaryAnim, child) {
        final curvedAnim = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnim),
          child: child,
        );
      },
    );
  }
}
