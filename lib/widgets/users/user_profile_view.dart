import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class UserProfileView extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onCancel;
  final Function(Map<String, dynamic>)? onApprove;
  final Function(Map<String, dynamic>)? onReject;
  final Function(Map<String, dynamic>)? onSuspend;
  final Function(Map<String, dynamic>)? onActivate;

  const UserProfileView({
    super.key,
    required this.row,
    required this.onCancel,
    this.onApprove,
    this.onReject,
    this.onSuspend,
    this.onActivate,
  });

  String? _getAvatarUrl(Map<String, dynamic> r) {
    if (r['avatar_url'] != null && r['avatar_url'].toString().trim().isNotEmpty) {
      return r['avatar_url'].toString().trim();
    }
    if (r['profile_picture'] != null && r['profile_picture'].toString().trim().isNotEmpty) {
      return r['profile_picture'].toString().trim();
    }
    if (r['photo_url'] != null && r['photo_url'].toString().trim().isNotEmpty) {
      return r['photo_url'].toString().trim();
    }
    final partnerList = r['partner_investors'];
    if (partnerList is List && partnerList.isNotEmpty) {
      final p = partnerList.first;
      final av = p['avatar_url'] ?? p['profile_picture'] ?? p['photo_url'];
      if (av != null && av.toString().trim().isNotEmpty) return av.toString().trim();
    } else if (partnerList is Map) {
      final av = partnerList['avatar_url'] ?? partnerList['profile_picture'] ?? partnerList['photo_url'];
      if (av != null && av.toString().trim().isNotEmpty) return av.toString().trim();
    }
    final cashierList = r['cashiers'];
    if (cashierList is List && cashierList.isNotEmpty) {
      final c = cashierList.first;
      final av = c['avatar_url'] ?? c['profile_picture'] ?? c['photo_url'];
      if (av != null && av.toString().trim().isNotEmpty) return av.toString().trim();
    } else if (cashierList is Map) {
      final av = cashierList['avatar_url'] ?? cashierList['profile_picture'] ?? cashierList['photo_url'];
      if (av != null && av.toString().trim().isNotEmpty) return av.toString().trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);

    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF27405F) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final mutedColor = isDark ? const Color(0xFF8FA7C4) : const Color(0xFF5D7391);
    final sectionBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF8FAFC);

    final name = (row['name'] ?? 'User').toString();
    final email = (row['email'] ?? 'N/A').toString();
    final roleRaw = (row['role'] ?? 'User').toString();
    final status = (row['status'] ?? 'Active').toString().toUpperCase();
    final createdAt = (row['created_at'] ?? 'N/A').toString().split('T').first;
    final isPending = status == 'PENDING';
    final isSuspended = status == 'SUSPENDED';
    final avatarUrl = _getAvatarUrl(row);

    final isPartner = roleRaw.toLowerCase().contains('partner') || roleRaw.toLowerCase() == 'investor';
    final isCashier = roleRaw.toLowerCase().contains('cashier');

    final roleDisplay = isPartner
        ? 'Partner Investor'
        : (isCashier ? 'Cashier' : (roleRaw.toLowerCase().contains('raiser') ? 'Hog Raiser' : roleRaw));

    final String screenTitle;
    if (isPartner) {
      screenTitle = isPending ? 'Pending Partner Investor Profile' : 'Active Partner Investor Profile';
    } else if (isCashier) {
      screenTitle = isPending ? 'Pending Cashier Profile' : 'Active Cashier Profile';
    } else {
      screenTitle = '$roleDisplay Profile';
    }

    final statusColor = (status == 'ACTIVE' || status == 'APPROVED')
        ? PiggyTrunkTheme.ptSuccess
        : (isPending ? const Color(0xFFFFAA00) : const Color(0xFFEF4444));

    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase()
        : 'US';

    String phone = (row['phone'] ?? row['contact_number'] ?? row['phone_number'] ?? '').toString().trim();
    String address = (row['address'] ?? row['farm_location'] ?? row['store_address'] ?? row['branch_address'] ?? '').toString().trim();

    final partnerList = row['partner_investors'];
    if (partnerList is List && partnerList.isNotEmpty) {
      final p = partnerList.first;
      if (p['contact_number'] != null && p['contact_number'].toString().trim().isNotEmpty) {
        phone = p['contact_number'].toString().trim();
      }
      if (p['address'] != null && p['address'].toString().trim().isNotEmpty) {
        address = p['address'].toString().trim();
      }
    } else if (partnerList is Map) {
      if (partnerList['contact_number'] != null && partnerList['contact_number'].toString().trim().isNotEmpty) {
        phone = partnerList['contact_number'].toString().trim();
      }
      if (partnerList['address'] != null && partnerList['address'].toString().trim().isNotEmpty) {
        address = partnerList['address'].toString().trim();
      }
    }

    final cashierList = row['cashiers'];
    if (cashierList is List && cashierList.isNotEmpty) {
      final c = cashierList.first;
      if ((phone.isEmpty || phone == 'null') && c['phone'] != null && c['phone'].toString().trim().isNotEmpty) {
        phone = c['phone'].toString().trim();
      }
      if ((address.isEmpty || address == 'null') && (c['address'] ?? c['store_address']) != null && (c['address'] ?? c['store_address']).toString().trim().isNotEmpty) {
        address = (c['address'] ?? c['store_address']).toString().trim();
      }
    } else if (cashierList is Map) {
      if ((phone.isEmpty || phone == 'null') && cashierList['phone'] != null && cashierList['phone'].toString().trim().isNotEmpty) {
        phone = cashierList['phone'].toString().trim();
      }
      if ((address.isEmpty || address == 'null') && (cashierList['address'] ?? cashierList['store_address']) != null && (cashierList['address'] ?? cashierList['store_address']).toString().trim().isNotEmpty) {
        address = (cashierList['address'] ?? cashierList['store_address']).toString().trim();
      }
    }

    if (phone.isEmpty || phone == 'null') phone = 'Not provided';
    if (address.isEmpty || address == 'null') address = 'Not provided';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    screenTitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View verified profile details and manage account status.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(
                'Back to Users',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Main Profile Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Profile Summary
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.12),
                      border: Border.all(color: PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.25), width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                initials,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: PiggyTrunkTheme.ptPrimary,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              initials,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: PiggyTrunkTheme.ptPrimary,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isMobile ? 17 : 20,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                roleDisplay,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : PiggyTrunkTheme.ptPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    status,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: cardBorder, height: 1),
              const SizedBox(height: 20),

              // Read-only Details Grid
              Text(
                'PROFILE DETAILS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 650;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                        child: _buildInfoTile(
                          'Full Name',
                          name,
                          Icons.person_outline_rounded,
                          sectionBg,
                          cardBorder,
                          titleColor,
                          mutedColor,
                        ),
                      ),
                      SizedBox(
                        width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                        child: _buildInfoTile(
                          'Email Address',
                          email,
                          Icons.mail_outline_rounded,
                          sectionBg,
                          cardBorder,
                          titleColor,
                          mutedColor,
                        ),
                      ),
                      SizedBox(
                        width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                        child: _buildInfoTile(
                          'Contact Number',
                          phone,
                          Icons.phone_outlined,
                          sectionBg,
                          cardBorder,
                          titleColor,
                          mutedColor,
                        ),
                      ),
                      SizedBox(
                        width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                        child: _buildInfoTile(
                          isCashier ? 'Store / Branch Location' : 'Address / Location',
                          address,
                          Icons.location_on_outlined,
                          sectionBg,
                          cardBorder,
                          titleColor,
                          mutedColor,
                        ),
                      ),
                      SizedBox(
                        width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                        child: _buildInfoTile(
                          'Account Role',
                          roleDisplay,
                          Icons.badge_outlined,
                          sectionBg,
                          cardBorder,
                          titleColor,
                          mutedColor,
                        ),
                      ),
                      SizedBox(
                        width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                        child: _buildInfoTile(
                          'Date Registered',
                          createdAt,
                          Icons.calendar_today_outlined,
                          sectionBg,
                          cardBorder,
                          titleColor,
                          mutedColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        if (isPending || (isSuspended && onActivate != null)) ...[
          const SizedBox(height: 24),
          // Action Buttons Row (Right-Aligned)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isPending) ...[
                if (onReject != null) ...[
                  OutlinedButton.icon(
                    onPressed: () => onReject!(row),
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFFF758C)),
                    label: const Text('Reject', style: TextStyle(color: Color(0xFFFF758C))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF758C)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (onApprove != null)
                  ElevatedButton.icon(
                    onPressed: () => onApprove!(row),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PiggyTrunkTheme.ptSuccess,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
              ] else if (isSuspended && onActivate != null) ...[
                ElevatedButton.icon(
                  onPressed: () => onActivate!(row),
                  icon: const Icon(Icons.lock_open_rounded, size: 16),
                  label: const Text('Activate Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PiggyTrunkTheme.ptSuccess,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon,
    Color bg,
    Color border,
    Color titleColor,
    Color mutedColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: mutedColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
