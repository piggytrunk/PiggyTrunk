import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class RaiserProfileView extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onCancel;
  final Future<void> Function(Map<String, dynamic> row) onApprove;
  final Future<void> Function(Map<String, dynamic> row) onDelete;
  final Future<void> Function(Map<String, dynamic> row)? onArchive;
  final Future<void> Function(Map<String, dynamic> row)? onRestore;

  const RaiserProfileView({
    super.key,
    required this.row,
    required this.onCancel,
    required this.onApprove,
    required this.onDelete,
    this.onArchive,
    this.onRestore,
  });

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

  static String formatPigType(dynamic raw) {
    final str = (raw ?? '').toString().trim();
    if (str.isEmpty ||
        str.toUpperCase() == 'N/A' ||
        str.toUpperCase() == 'NONE' ||
        str.toUpperCase() == 'UNASSIGNED' ||
        str.toLowerCase() == 'null') {
      return 'Unassigned';
    }
    final lower = str.toLowerCase();
    final bool hasSow = lower.contains('sow') || lower.contains('breed') || lower.contains('inahin');
    final bool hasFattening = lower.contains('fatten') || lower.contains('baboy');
    if (hasSow && hasFattening) {
      return 'Sow & Fattening';
    } else if (hasSow) {
      return 'Sow / Breeding';
    } else if (hasFattening) {
      return 'Fattening';
    }
    return str;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);

    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final mutedColor = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final fieldBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF8FAFC);

    final name = (row['name'] ?? 'Hog Raiser').toString();
    final email = (row['email'] ?? 'N/A').toString();
    final phone = (row['phone'] ?? 'N/A').toString();
    final address = (row['address'] ?? 'N/A').toString();
    final pigType = formatPigType(row['pig_type']);
    final rawStatus = (row['account_status'] ?? row['status'] ?? 'Active').toString().toUpperCase();
    final isPending = rawStatus == 'PENDING';
    final isArchived = rawStatus == 'ARCHIVED';
    final avatarUrl = _getAvatarUrl(row);

    final statusColor = rawStatus == 'ACTIVE' || rawStatus == 'APPROVED'
        ? PiggyTrunkTheme.ptSuccess
        : (isPending ? const Color(0xFFFFAA00) : Colors.redAccent);

    final initials = name.trim().isNotEmpty && name != 'N/A'
        ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase()
        : 'HR';

    final dateCreated = (row['created_at'] ?? row['date_registered'] ?? row['date_created'])?.toString().split('T').first ?? 'N/A';
    final assignedBatchRaw = (row['assigned_batch_name'] ?? row['batch_name'] ?? '').toString().trim();
    final assignedBatch = (assignedBatchRaw.isEmpty ||
            assignedBatchRaw.toUpperCase() == 'N/A' ||
            assignedBatchRaw.toLowerCase() == 'null')
        ? 'Unassigned'
        : assignedBatchRaw;

    final rawStage = (row['lifecycle_stage'] ?? row['current_stage'] ?? '').toString().trim();
    final stage = (assignedBatch == 'Unassigned' ||
            pigType == 'Unassigned' ||
            rawStage.isEmpty ||
            rawStage.toUpperCase() == 'N/A' ||
            rawStage.toLowerCase() == 'null')
        ? 'Unassigned'
        : rawStage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          Icons.badge_outlined,
                          color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Raiser Profile',
                        style: GoogleFonts.plusJakartaSans(
                          color: titleColor,
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Comprehensive overview of raiser details, active batch, and livestock capacity.',
                    style: GoogleFonts.plusJakartaSans(
                      color: mutedColor,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(
                'Back to Hog Raisers',
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
        const SizedBox(height: 24),

        // Hero Profile Banner Card
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: isMobile ? 64 : 80,
                height: isMobile ? 64 : 80,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF132238) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                    width: 2,
                  ),
                ),
                child: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: Text(
                            initials,
                            style: AppTextStyles.jakarta(
                              size: 22,
                              weight: FontWeight.w800,
                              color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: AppTextStyles.jakarta(
                            size: 22,
                            weight: FontWeight.w800,
                            color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                rawStatus,
                                style: GoogleFonts.plusJakartaSans(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Information Grid Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
          ),
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACCOUNT & RAISER DETAILS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: mutedColor,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (isMobile || constraints.maxWidth < 560) {
                    return Column(
                      children: [
                        _buildInfoTile('Phone Number', phone, Icons.phone_outlined, fieldBg, cardBorder, titleColor, mutedColor),
                        const SizedBox(height: 12),
                        _buildInfoTile('Address', address, Icons.location_on_outlined, fieldBg, cardBorder, titleColor, mutedColor),
                        const SizedBox(height: 12),
                        _buildInfoTile('Pig Type', pigType, Icons.pets_outlined, fieldBg, cardBorder, titleColor, mutedColor),
                        const SizedBox(height: 12),
                        _buildInfoTile('Lifecycle Stage', stage, Icons.timeline_outlined, fieldBg, cardBorder, titleColor, mutedColor),
                        const SizedBox(height: 12),
                        _buildInfoTile('Assigned Batch', assignedBatch, Icons.inventory_2_outlined, fieldBg, cardBorder, titleColor, mutedColor),
                        const SizedBox(height: 12),
                        _buildInfoTile('Date Registered', dateCreated, Icons.calendar_today_outlined, fieldBg, cardBorder, titleColor, mutedColor),
                      ],
                    );
                  }
                  final int cols = constraints.maxWidth >= 900 ? 3 : 2;
                  const double spacing = 16.0;
                  final double tileWidth = (constraints.maxWidth - (spacing * (cols - 1))) / cols;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: tileWidth,
                        child: _buildInfoTile('Phone Number', phone, Icons.phone_outlined, fieldBg, cardBorder, titleColor, mutedColor),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _buildInfoTile('Address', address, Icons.location_on_outlined, fieldBg, cardBorder, titleColor, mutedColor),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _buildInfoTile('Pig Type', pigType, Icons.pets_outlined, fieldBg, cardBorder, titleColor, mutedColor),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _buildInfoTile('Lifecycle Stage', stage, Icons.timeline_outlined, fieldBg, cardBorder, titleColor, mutedColor),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _buildInfoTile('Assigned Batch', assignedBatch, Icons.inventory_2_outlined, fieldBg, cardBorder, titleColor, mutedColor),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _buildInfoTile('Date Registered', dateCreated, Icons.calendar_today_outlined, fieldBg, cardBorder, titleColor, mutedColor),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        if (isPending || (isArchived && onRestore != null)) ...[
          const SizedBox(height: 24),
          // Action Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isPending) ...[
                OutlinedButton.icon(
                  onPressed: () => onDelete(row),
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFFF758C)),
                  label: const Text('Reject', style: TextStyle(color: Color(0xFFFF758C))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF758C)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => onApprove(row),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Approve Raiser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PiggyTrunkTheme.ptSuccess,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ] else if (isArchived && onRestore != null) ...[
                ElevatedButton.icon(
                  onPressed: () => onRestore!(row),
                  icon: const Icon(Icons.restore_outlined, size: 16),
                  label: const Text('Restore Raiser'),
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
