import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/admin_notification_model.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';

class HogReportDetailModal extends StatefulWidget {
  final AdminNotification notif;
  final bool isBottomSheet;

  const HogReportDetailModal({
    super.key,
    required this.notif,
    this.isBottomSheet = false,
  });

  static Future<void> show(BuildContext context, {required AdminNotification notif}) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 768) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => HogReportDetailModal(
          notif: notif,
          isBottomSheet: true,
        ),
      );
    }

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Hog Health Report Details',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: HogReportDetailModal(
            notif: notif,
            isBottomSheet: false,
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  State<HogReportDetailModal> createState() => _HogReportDetailModalState();
}

class _HogReportDetailModalState extends State<HogReportDetailModal> {
  Map<String, dynamic>? _reportData;
  Map<String, dynamic>? _raiserData;
  Map<String, dynamic>? _batchData;
  int? _resolvedHogIndex;

  @override
  void initState() {
    super.initState();
    _fetchExtraDetails();
  }

  Future<void> _fetchExtraDetails() async {
    final meta = widget.notif.metadata ?? <String, dynamic>{};
    final dynamic reportIdRaw = meta['report_id'];
    final dynamic raiserIdRaw = meta['hog_raiser_id'];
    final dynamic batchIdRaw = meta['batch_id'];
    final dynamic hogIdRaw = meta['hog_id'];

    try {
      // 1. Fetch Report
      Map<String, dynamic>? reportRow;
      if (reportIdRaw != null) {
        final rId = int.tryParse(reportIdRaw.toString());
        if (rId != null) {
          reportRow = await Supabase.instance.client
              .from('hog_reports')
              .select('*')
              .eq('report_id', rId)
              .maybeSingle();
        }
      }

      // 2. Fetch Raiser directly (with address and phone)
      final effectiveRaiserId = reportRow?['hog_raiser_id'] ?? raiserIdRaw;
      Map<String, dynamic>? raiserRow;
      if (effectiveRaiserId != null) {
        final hrId = int.tryParse(effectiveRaiserId.toString());
        if (hrId != null) {
          raiserRow = await Supabase.instance.client
              .from('hog_raisers')
              .select('*')
              .eq('hog_raiser_id', hrId)
              .maybeSingle();
        }
      }

      // 3. Fetch Batch directly
      final effectiveBatchId = reportRow?['batch_id'] ?? batchIdRaw;
      Map<String, dynamic>? batchRow;
      if (effectiveBatchId != null) {
        final bId = int.tryParse(effectiveBatchId.toString());
        if (bId != null) {
          batchRow = await Supabase.instance.client
              .from('batches')
              .select('*')
              .eq('batch_id', bId)
              .maybeSingle();
        }
      }

      // 4. Resolve relative Hog Index (e.g. Hog #1 instead of database PK #17)
      final targetHogId = reportRow?['hog_id'] ?? hogIdRaw;
      int? calculatedIndex;
      if (targetHogId != null) {
        try {
          final tHogNum = int.tryParse(targetHogId.toString());
          final hogRecord = await Supabase.instance.client
              .from('hogs')
              .select('hog_id, assignment_id')
              .eq('hog_id', tHogNum ?? targetHogId)
              .maybeSingle();

          final aId = hogRecord?['assignment_id'];
          if (aId != null) {
            final hogsRes = await Supabase.instance.client
                .from('hogs')
                .select('hog_id')
                .eq('assignment_id', aId)
                .order('hog_id', ascending: true);
            if (hogsRes.isNotEmpty) {
              final idx = hogsRes.indexWhere(
                (h) => h['hog_id'].toString() == targetHogId.toString(),
              );
              if (idx != -1) {
                calculatedIndex = idx + 1;
              }
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _reportData = reportRow;
          _raiserData = raiserRow;
          _batchData = batchRow;
          _resolvedHogIndex = calculatedIndex;
        });
      }
    } catch (_) {}
  }

  Color _getReportTypeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('fever')) return const Color(0xFFEA580C);
    if (t.contains('poison') || t.contains('dead')) return const Color(0xFFDC2626);
    if (t.contains('injury') || t.contains('diarrhea')) return const Color(0xFFD97706);
    return const Color(0xFF0284C7);
  }

  IconData _getReportTypeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('fever')) return Icons.thermostat_rounded;
    if (t.contains('poison')) return Icons.warning_amber_rounded;
    if (t.contains('injury')) return Icons.healing_rounded;
    if (t.contains('dead')) return Icons.cancel_rounded;
    return Icons.pets_rounded;
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month ${dt.day}, ${dt.year} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1B2A42) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF283F5E) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final mutedText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final meta = widget.notif.metadata ?? <String, dynamic>{};

    final reportType = (_reportData?['report_type'] ?? meta['report_type'] ?? 'Health Issue').toString();
    final raiserName = (_raiserData?['name'] ?? meta['raiser_name'] ?? 'Assigned Raiser').toString();
    final raiserPhone = (_raiserData?['phone'] ?? 'N/A').toString();
    final raiserAddress = (_raiserData?['address'] ?? 'N/A').toString();
    final batchName = (_batchData?['batch_name'] ?? meta['batch_name'] ?? 'Active Batch').toString();
    final batchId = _batchData?['batch_id'] ?? _reportData?['batch_id'] ?? meta['batch_id'];
    final raiserId = _raiserData?['hog_raiser_id'] ?? _reportData?['hog_raiser_id'] ?? meta['hog_raiser_id'];

    final hogIdRaw = _reportData?['hog_id'] ?? meta['hog_id'];
    final String hogLabel;
    if (_resolvedHogIndex != null) {
      hogLabel = 'Hog #$_resolvedHogIndex';
    } else if (hogIdRaw != null) {
      hogLabel = 'Hog #$hogIdRaw';
    } else {
      hogLabel = 'Assigned Hog';
    }

    final description = (_reportData?['description'] ?? meta['description'] ?? widget.notif.message).toString().trim();

    final statusColor = _getReportTypeColor(reportType);
    final statusIcon = _getReportTypeIcon(reportType);

    final initials = raiserName.trim().isNotEmpty
        ? raiserName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase()
        : 'HR';

    final contentWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clean Top Header (No redundant icon - clean & executive)
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hog Health Alert',
                    style: AppTextStyles.jakarta(
                      size: 17,
                      weight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTime(widget.notif.createdAt),
                    style: AppTextStyles.jakarta(
                      size: 11.5,
                      weight: FontWeight.w500,
                      color: mutedText,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: mutedText, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        Divider(color: cardBorder, height: 1),

        // Scrollable Body
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Severity Status Banner (The sole, prominent health diagnosis banner)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.18 : 0.09),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reportType.toUpperCase(),
                              style: AppTextStyles.jakarta(
                                size: 15,
                                weight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Incident reported by raiser requiring farm attention.',
                              style: AppTextStyles.jakarta(
                                size: 12,
                                weight: FontWeight.w500,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Hog & Batch Quick Specs Grid
                Row(
                  children: [
                    // Hog Identifier Box
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.pets_rounded, size: 14, color: mutedText),
                                const SizedBox(width: 6),
                                Text(
                                  'HOG TARGET',
                                  style: AppTextStyles.jakarta(
                                    size: 10.5,
                                    weight: FontWeight.w700,
                                    color: mutedText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hogLabel,
                              style: AppTextStyles.jakarta(
                                size: 13.5,
                                weight: FontWeight.w800,
                                color: titleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Batch Box
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.layers_outlined, size: 14, color: mutedText),
                                const SizedBox(width: 6),
                                Text(
                                  'BATCH',
                                  style: AppTextStyles.jakarta(
                                    size: 10.5,
                                    weight: FontWeight.w700,
                                    color: mutedText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              batchName,
                              style: AppTextStyles.jakarta(
                                size: 13,
                                weight: FontWeight.w800,
                                color: titleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Raiser Observations & Notes
                Text(
                  'RAISER OBSERVATIONS & DETAILS',
                  style: AppTextStyles.jakarta(
                    size: 11,
                    weight: FontWeight.w800,
                    color: mutedText,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notes_rounded, size: 16, color: statusColor),
                          const SizedBox(width: 8),
                          Text(
                            'Recorded Notes',
                            style: AppTextStyles.jakarta(
                              size: 12.5,
                              weight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        description.isNotEmpty
                            ? '"$description"'
                            : 'No additional observations written by raiser.',
                        style: AppTextStyles.jakarta(
                          size: 13.5,
                          weight: FontWeight.w500,
                          color: description.isNotEmpty
                              ? (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B))
                              : mutedText,
                          height: 1.45,
                        ).copyWith(
                          fontStyle: description.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Assigned Raiser Info Card (Clean with accurate address & phone)
                Text(
                  'REPORTED BY',
                  style: AppTextStyles.jakarta(
                    size: 11,
                    weight: FontWeight.w800,
                    color: mutedText,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.white : const Color(0xFF18314F),
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Image.asset(
                            'assets/piggytrunk_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                initials,
                                style: AppTextStyles.jakarta(
                                  size: 13,
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
                              raiserName,
                              style: AppTextStyles.jakarta(
                                size: 14,
                                weight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 13, color: mutedText),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    raiserAddress != 'N/A' ? raiserAddress : 'Address: Unspecified',
                                    style: AppTextStyles.jakarta(
                                      size: 12,
                                      weight: FontWeight.w500,
                                      color: mutedText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (raiserPhone != 'N/A') ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 13, color: mutedText),
                                  const SizedBox(width: 4),
                                  Text(
                                    raiserPhone,
                                    style: AppTextStyles.jakarta(
                                      size: 12,
                                      weight: FontWeight.w500,
                                      color: mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Clean Footer (Only "View Raiser" and "View Batch" buttons)
        Divider(color: cardBorder, height: 1),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          color: surfaceBg,
          child: Row(
            children: [
              // View Raiser Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed(
                      '/raisers',
                      arguments: {
                        'raiser_id': raiserId,
                        'raiser_name': raiserName,
                      },
                    );
                  },
                  icon: const Icon(Icons.person_search_rounded, size: 16),
                  label: Text(
                    'View Raiser',
                    style: AppTextStyles.jakarta(size: 12.5, weight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PiggyTrunkTheme.ptPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // View Batch Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed(
                      '/investments',
                      arguments: {
                        'batch_id': batchId,
                        'batch_name': batchName,
                        'raiser_name': raiserName,
                      },
                    );
                  },
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: Text(
                    'View Batch',
                    style: AppTextStyles.jakarta(size: 12.5, weight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: titleColor,
                    side: BorderSide(color: cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.isBottomSheet) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: surfaceBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: cardBorder, width: 1.2)),
        ),
        child: SafeArea(child: contentWidget),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 480,
        height: double.infinity,
        decoration: BoxDecoration(
          color: surfaceBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
              blurRadius: 28,
              spreadRadius: 2,
              offset: const Offset(-4, 0),
            ),
          ],
          border: Border(left: BorderSide(color: cardBorder, width: 1.2)),
        ),
        child: SafeArea(child: contentWidget),
      ),
    );
  }
}
