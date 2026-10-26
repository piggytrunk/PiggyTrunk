import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../../../utils/app_strings.dart';
import '../../../utils/capitalization_formatters.dart';
import '../../../widgets/piggy_toast.dart';
import '../widgets/raiser_empty_state.dart';

class RaiserHogsTab extends StatefulWidget {
  final Map<String, dynamic> raiserData;
  final double investedAmount;
  final List<Map<String, dynamic>> activeAssignments;
  final List<Map<String, dynamic>> hogsList;
  final List<Map<String, dynamic>> reportsList;
  final List<Map<String, dynamic>> notificationsList;
  final BigInt? selectedAssignmentId;
  final Future<void> Function() onRefresh;
  final Function(int notificationId) onMarkNotificationAsRead;
  final VoidCallback onMarkAllRead;
  final Future<void> Function(BigInt hogId, String reportType, String notes) onSubmitHogReport;
  final Function(String targetStage)? onUpdateLifecycleStage;

  const RaiserHogsTab({
    super.key,
    required this.raiserData,
    this.investedAmount = 0.0,
    this.activeAssignments = const [],
    required this.hogsList,
    required this.reportsList,
    required this.notificationsList,
    required this.selectedAssignmentId,
    required this.onRefresh,
    required this.onMarkNotificationAsRead,
    required this.onMarkAllRead,
    required this.onSubmitHogReport,
    this.onUpdateLifecycleStage,
  });

  @override
  State<RaiserHogsTab> createState() => _RaiserHogsTabState();
}

class _RaiserHogsTabState extends State<RaiserHogsTab> {
  static const Color _brandColor = Color(0xFF18314F);
  static const Color _successGreen = Color(0xFF10B981);
  static const Color _dangerRed = Color(0xFFEF4444);

  String _selectedTab = 'Hogs'; // 'Hogs' or 'Reports'
  int _selectedHogIndex = 0;
  int? _hoveredHogIndex;
  final Map<String, String> _hogSpecificStages = {};
  BigInt? _selectedBatchAssignmentId;

  @override
  void initState() {
    super.initState();
    _initSelectedBatch();
    _loadCachedHogStages();
  }

  Future<void> _loadCachedHogStages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('hog_stage_') && !k.endsWith('_id'));
      if (keys.isNotEmpty && mounted) {
        setState(() {
          for (final key in keys) {
            final val = prefs.getString(key);
            if (val != null && val.isNotEmpty) {
              final parts = key.split('_');
              if (parts.length >= 4) {
                final idOrTag = parts.sublist(3).join('_');
                _hogSpecificStages[idOrTag] = val;
              }
            }
          }
          _syncLocalStagesWithHogsList();
        });
      }
    } catch (_) {}
  }

  void _syncLocalStagesWithHogsList() {
    for (var h in widget.hogsList) {
      final idStr = (h['hog_id'] ?? '').toString();
      final tagStr = (h['tag_number'] ?? '').toString();
      final staged = _hogSpecificStages[idStr] ?? _hogSpecificStages[tagStr];
      if (staged != null) {
        final isBreeding = _getHogPigType(h, '').toLowerCase() == 'sow';
        final stageId = _stageNameToId(staged, isBreeding);
        h['stage_id'] = stageId;
        h['stage'] = staged;
        h['lifecycle_stage'] = staged;
      }
    }
  }

  @override
  void didUpdateWidget(covariant RaiserHogsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLocalStagesWithHogsList();
    if (widget.selectedAssignmentId != oldWidget.selectedAssignmentId && widget.selectedAssignmentId != null) {
      _selectedBatchAssignmentId = widget.selectedAssignmentId;
      _selectedHogIndex = 0;
    } else if (_selectedBatchAssignmentId == null ||
        !widget.activeAssignments.any((a) =>
            BigInt.from(a['assignment_id'] as num) == _selectedBatchAssignmentId)) {
      _initSelectedBatch();
    } else {
      // If currently selected batch is completed, but a fresh active batch is available, prefer the active batch
      final currentAssign = widget.activeAssignments.firstWhere(
        (a) => BigInt.from(a['assignment_id'] as num) == _selectedBatchAssignmentId,
        orElse: () => {},
      );
      final isCurrentDone = currentAssign['is_cycle_completed'] == true ||
          (currentAssign['status'] ?? '').toString().toLowerCase() == 'completed';
      final firstActive = widget.activeAssignments.firstWhere(
        (a) => a['is_cycle_completed'] != true && (a['status'] ?? '').toString().toLowerCase() != 'completed',
        orElse: () => {},
      );
      if (isCurrentDone && firstActive.isNotEmpty) {
        _selectedBatchAssignmentId = BigInt.from(firstActive['assignment_id'] as num);
        _selectedHogIndex = 0;
      }
    }
  }

  int _compareAssignments(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aDone = a['is_cycle_completed'] == true;
    final bDone = b['is_cycle_completed'] == true;
    if (!aDone && bDone) return -1;
    if (aDone && !bDone) return 1;

    final aType = (a['hog_types']?['type_name'] ?? a['pig_type'] ?? '').toString().toLowerCase();
    final bType = (b['hog_types']?['type_name'] ?? b['pig_type'] ?? '').toString().toLowerCase();
    int getPrio(String t) {
      if (t.contains('fatten')) return 0;
      if (t.contains('sow') || t.contains('breed')) return 1;
      return 2;
    }
    final pA = getPrio(aType);
    final pB = getPrio(bType);
    if (pA != pB) return pA.compareTo(pB);

    final aId = a['assignment_id'] is num ? (a['assignment_id'] as num).toInt() : 0;
    final bId = b['assignment_id'] is num ? (b['assignment_id'] as num).toInt() : 0;
    return aId.compareTo(bId);
  }

  void _initSelectedBatch() {
    final sortedActive = List<Map<String, dynamic>>.from(widget.activeAssignments)
      ..sort(_compareAssignments);

    final activeOnly = sortedActive.where(
      (a) => a['is_cycle_completed'] != true && (a['status'] ?? '').toString().toLowerCase() != 'completed',
    ).toList();

    if (activeOnly.length > 1) {
      // Mixed active assignments in batch (e.g. Fattening + Sow): show All Heads by default
      _selectedBatchAssignmentId = null;
    } else if (widget.selectedAssignmentId != null &&
        sortedActive.any((a) {
          final id = a['assignment_id'] ?? a['id'];
          return id != null && BigInt.from(id as num) == widget.selectedAssignmentId;
        })) {
      _selectedBatchAssignmentId = widget.selectedAssignmentId;
    } else if (activeOnly.isNotEmpty && (activeOnly[0]['assignment_id'] ?? activeOnly[0]['id']) != null) {
      _selectedBatchAssignmentId = BigInt.from((activeOnly[0]['assignment_id'] ?? activeOnly[0]['id']) as num);
    } else if (sortedActive.isNotEmpty && (sortedActive[0]['assignment_id'] ?? sortedActive[0]['id']) != null) {
      _selectedBatchAssignmentId = BigInt.from((sortedActive[0]['assignment_id'] ?? sortedActive[0]['id']) as num);
    } else {
      _selectedBatchAssignmentId = null;
    }
  }

  String _formatReportTime(String? createdAtStr, AppStrings strings) {
    if (createdAtStr == null || createdAtStr.isEmpty) return strings.isFilipino ? 'Kani-kanina lang' : 'Recent';
    try {
      final created = DateTime.parse(createdAtStr);
      return strings.formatRelativeTime(created);
    } catch (_) {
      return strings.isFilipino ? 'Kani-kanina lang' : 'Recent';
    }
  }

  String _formatReadableDateTime(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      final DateTime dt = (dateVal is DateTime ? dateVal : DateTime.parse(dateVal.toString())).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final m = months[dt.month - 1];
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$m ${dt.day}, ${dt.year} • $hour:$min $period';
    } catch (_) {
      return dateVal.toString();
    }
  }

  String _formatAssignmentLabel(Map<String, dynamic> a) {
    final activeOnly = widget.activeAssignments.where(
      (x) => x['is_cycle_completed'] != true && (x['status'] ?? '').toString().toLowerCase() != 'completed',
    ).toList();
    if (_selectedBatchAssignmentId == null && activeOnly.length > 1) {
      final first = activeOnly.first;
      final bData = first['batches'];
      String rawBatchName = '';
      if (bData is Map) {
        rawBatchName = bData['batch_name']?.toString() ?? '';
      } else if (bData is List && bData.isNotEmpty && bData.first is Map) {
        rawBatchName = bData.first['batch_name']?.toString() ?? '';
      }
      if (rawBatchName.isEmpty) {
        rawBatchName = (first['batch_name'] ?? 'Batch').toString();
      }
      if (rawBatchName.contains(' (')) {
        final parts = rawBatchName.split(' (');
        if (parts.last.endsWith(')')) {
          rawBatchName = parts.sublist(0, parts.length - 1).join(' (');
        }
      }
      final strings = AppStrings.of(context);
      return '$rawBatchName (${strings.isFilipino ? "Lahat ng Ulo" : "All Heads"})';
    }

    final bData = a['batches'];
    String rawBatchName = '';
    if (bData is Map) {
      rawBatchName = bData['batch_name']?.toString() ?? '';
    } else if (bData is List && bData.isNotEmpty && bData.first is Map) {
      rawBatchName = bData.first['batch_name']?.toString() ?? '';
    }
    if (rawBatchName.isEmpty) {
      rawBatchName = (a['batch_name'] ?? (a['assignment_id'] != null ? 'Batch #${a['assignment_id']}' : 'No Batch')).toString();
    }
    String displayBatchName = rawBatchName;
    if (rawBatchName.contains(' (')) {
      final parts = rawBatchName.split(' (');
      if (parts.last.endsWith(')')) {
        displayBatchName = parts.sublist(0, parts.length - 1).join(' (');
      }
    }
    final htData = a['hog_types'];
    String rawHogType = '';
    if (htData is Map) {
      rawHogType = htData['type_name']?.toString() ?? '';
    } else if (htData is List && htData.isNotEmpty && htData.first is Map) {
      rawHogType = htData.first['type_name']?.toString() ?? '';
    }
    if (rawHogType.isEmpty) {
      rawHogType = a['pig_type']?.toString() ??
          widget.raiserData['pig_type']?.toString() ??
          '';
    }
    return '$displayBatchName${rawHogType.isNotEmpty ? " ($rawHogType)" : ""}';
  }

  void _showBatchPickerModal(BuildContext parentContext) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : _brandColor;
    final surfaceBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final borderColor = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final strings = AppStrings.of(context);

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: surfaceBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mutedColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _brandColor.withValues(alpha: isDark ? 0.25 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.pets_rounded, color: isDark ? const Color(0xFF38BDF8) : _brandColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.isFilipino ? 'Piliin ang Batch ng Alaga' : 'Select Batch of Hogs',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            Text(
                              strings.isFilipino
                                  ? 'Piliin kung aling batch ang titingnan at susubaybayan'
                                  : 'Choose which batch to view and monitor',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textColor, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: borderColor),
                Flexible(
                  child: Builder(
                    builder: (context) {
                      final sortedAssignments = List<Map<String, dynamic>>.from(widget.activeAssignments)
                        ..sort(_compareAssignments);
                      final activeOnly = sortedAssignments.where(
                        (a) => a['is_cycle_completed'] != true && (a['status'] ?? '').toString().toLowerCase() != 'completed',
                      ).toList();
                      final bool showAllHeads = activeOnly.length > 1;
                      final totalCount = sortedAssignments.length + (showAllHeads ? 1 : 0);

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
                        itemCount: totalCount,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          if (showAllHeads && index == 0) {
                            final isSelected = _selectedBatchAssignmentId == null;
                            final bData = activeOnly.first['batches'];
                            String bName = '';
                            if (bData is Map) bName = bData['batch_name']?.toString() ?? '';
                            if (bName.isEmpty) bName = activeOnly.first['batch_name']?.toString() ?? 'Batch';
                            if (bName.contains(' (')) {
                              final parts = bName.split(' (');
                              if (parts.last.endsWith(')')) {
                                bName = parts.sublist(0, parts.length - 1).join(' (');
                              }
                            }
                            final totalActiveHogs = widget.hogsList.where((h) {
                              final aId = h['assignment_id'];
                              return activeOnly.any((a) => (a['assignment_id'] ?? a['id']) == aId);
                            }).length;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedBatchAssignmentId = null;
                                  _selectedHogIndex = 0;
                                });
                                Navigator.pop(ctx);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF))
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF38BDF8) : _brandColor)
                                        : borderColor,
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.2) : _brandColor.withValues(alpha: 0.1))
                                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.grid_view_rounded,
                                        color: isSelected
                                            ? (isDark ? const Color(0xFF38BDF8) : _brandColor)
                                            : mutedColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bName,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              color: isSelected
                                                  ? (isDark ? Colors.white : _brandColor)
                                                  : textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  strings.isFilipino ? 'Lahat ng Ulo ($totalActiveHogs)' : 'All Heads ($totalActiveHogs)',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white70 : _brandColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  strings.isFilipino ? 'Aktibo' : 'Active',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      color: isSelected
                                          ? (isDark ? const Color(0xFF38BDF8) : _brandColor)
                                          : mutedColor.withValues(alpha: 0.5),
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final a = sortedAssignments[showAllHeads ? index - 1 : index];
                      final aId = BigInt.from(a['assignment_id'] as num);
                      final isSelected = aId == _selectedBatchAssignmentId;

                      final bData = a['batches'];
                      String rawBatchName = '';
                      if (bData is Map) {
                        rawBatchName = bData['batch_name']?.toString() ?? '';
                      } else if (bData is List && bData.isNotEmpty && bData.first is Map) {
                        rawBatchName = bData.first['batch_name']?.toString() ?? '';
                      }
                      if (rawBatchName.isEmpty) {
                        rawBatchName = (a['batch_name'] ?? 'Assignment #${a['assignment_id']}').toString();
                      }
                      String displayBatchName = rawBatchName;
                      if (rawBatchName.contains(' (')) {
                        final parts = rawBatchName.split(' (');
                        if (parts.last.endsWith(')')) {
                          displayBatchName = parts.sublist(0, parts.length - 1).join(' (');
                        }
                      }
                      final htData = a['hog_types'];
                      String rawHogType = '';
                      if (htData is Map) {
                        rawHogType = htData['type_name']?.toString() ?? '';
                      } else if (htData is List && htData.isNotEmpty && htData.first is Map) {
                        rawHogType = htData.first['type_name']?.toString() ?? '';
                      }
                      if (rawHogType.isEmpty) {
                        rawHogType = a['pig_type']?.toString() ??
                            widget.raiserData['pig_type']?.toString() ??
                            'Fattening';
                      }

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedBatchAssignmentId = aId;
                            _selectedHogIndex = 0;
                          });
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF))
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF38BDF8) : _brandColor)
                                  : borderColor,
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.2) : _brandColor.withValues(alpha: 0.1))
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.pets_rounded,
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF38BDF8) : _brandColor)
                                      : mutedColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayBatchName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected
                                            ? (isDark ? Colors.white : _brandColor)
                                            : textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            rawHogType,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white70 : _brandColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (a['is_cycle_completed'] == true)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF14291F) : const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.check_rounded, size: 10, color: Color(0xFF10B981)),
                                                const SizedBox(width: 3),
                                                Text(
                                                  strings.isFilipino ? 'Tapos na' : 'Concluded',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              strings.isFilipino ? 'Aktibo' : 'Active',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isSelected
                                    ? (isDark ? const Color(0xFF38BDF8) : _brandColor)
                                    : mutedColor.withValues(alpha: 0.5),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _findHog(dynamic hogId) {
    if (hogId == null) return null;
    final idStr = hogId.toString();
    for (var h in widget.hogsList) {
      if (h['hog_id']?.toString() == idStr) {
        return h;
      }
    }
    return null;
  }

  String _resolveHogSpecificType(Map<String, dynamic> hog) {
    // 1. Try finding assignment
    final hAssId = hog['assignment_id'];
    if (hAssId != null) {
      for (final a in widget.activeAssignments) {
        if (a['assignment_id'] != null && (a['assignment_id'] as num).toInt() == (hAssId as num).toInt()) {
          final ht = a['hog_types'];
          String aType = '';
          if (ht is Map) {
            aType = (ht['type_name'] ?? '').toString();
          } else if (ht is List && ht.isNotEmpty && ht.first is Map) {
            aType = (ht.first['type_name'] ?? '').toString();
          }
          if (aType.isEmpty) {
            aType = (a['pig_type'] ?? '').toString();
          }
          if (aType.isNotEmpty && !aType.toLowerCase().contains('and')) {
            return aType.toLowerCase().contains('fatten') ? 'Fattening' : 'Sow/Breeding';
          }
        }
      }
    }

    // 2. Check hog's direct pig_type
    final directType = (hog['pig_type'] ?? '').toString().trim();
    if (directType.isNotEmpty && !directType.toLowerCase().contains('and')) {
      return directType.toLowerCase().contains('fatten') ? 'Fattening' : 'Sow/Breeding';
    }

    // 3. Check stage_id / lifecycle_stage
    final stageName = (hog['lifecycle_stage'] ?? '').toString().toLowerCase();
    if (stageName.contains('gestat') || stageName.contains('breed') || stageName.contains('lactat') || stageName.contains('dry')) {
      return 'Sow/Breeding';
    }

    // 4. Position fallback if mixed raiser data
    final totalHogs = List<Map<String, dynamic>>.from(widget.hogsList);
    totalHogs.sort((a, b) {
      final aId = a['hog_id'] as num? ?? 0;
      final bId = b['hog_id'] as num? ?? 0;
      return aId.compareTo(bId);
    });
    final idx = totalHogs.indexWhere((h) => h['hog_id']?.toString() == hog['hog_id']?.toString());
    if (idx >= 0 && totalHogs.length > 1) {
      final half = (totalHogs.length / 2).ceil();
      return idx < half ? 'Fattening' : 'Sow/Breeding';
    }

    return 'Fattening';
  }

  String _formatHogTypeLabel(String resolvedType, AppStrings strings) {
    if (resolvedType.toLowerCase().contains('fatten')) {
      return strings.isFilipino ? 'Pampataba' : 'Fattening';
    }
    return strings.isFilipino ? 'Inahin / Sow' : 'Sow/Breeding';
  }

  String _getHogDisplayName(dynamic hogId, AppStrings strings) {
    if (hogId == null) return strings.isFilipino ? 'Alagang Baboy' : 'Hog';
    final hog = _findHog(hogId);
    final hogPrefix = strings.isFilipino ? 'Baboy' : 'Hog';
    if (hog != null) {
      if (hog['tag_number'] != null && hog['tag_number'].toString().isNotEmpty) {
        return '$hogPrefix ${hog['tag_number']}';
      }
      final sortedHogs = List<Map<String, dynamic>>.from(widget.hogsList);
      sortedHogs.sort((a, b) {
        final aType = _resolveHogSpecificType(a).toLowerCase();
        final bType = _resolveHogSpecificType(b).toLowerCase();
        final aIsFat = aType.contains('fatten');
        final bIsFat = bType.contains('fatten');
        if (aIsFat && !bIsFat) return -1;
        if (!aIsFat && bIsFat) return 1;
        final aId = a['hog_id'] as num? ?? 0;
        final bId = b['hog_id'] as num? ?? 0;
        return aId.compareTo(bId);
      });
      final idx = sortedHogs.indexWhere((h) => h['hog_id']?.toString() == hog['hog_id']?.toString());
      final hogNum = idx >= 0 ? (idx + 1) : 1;
      return '$hogPrefix #$hogNum';
    }
    return strings.isFilipino ? 'Alagang Baboy' : 'Hog';
  }

  IconData _getReportIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('fever')) return Icons.thermostat_rounded;
    if (t.contains('poison')) return Icons.warning_amber_rounded;
    if (t.contains('diarrhea')) return Icons.water_drop_outlined;
    if (t.contains('injury')) return Icons.healing_rounded;
    if (t.contains('dead') || t.contains('deceased')) return Icons.dangerous_rounded;
    return Icons.medical_services_rounded;
  }

  Color _getReportColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('fever')) return const Color(0xFFEF4444);
    if (t.contains('injury')) return const Color(0xFFF43F5E);
    if (t.contains('poison')) return const Color(0xFFEA580C);
    if (t.contains('diarrhea')) return const Color(0xFFF59E0B);
    if (t.contains('dead') || t.contains('deceased')) return const Color(0xFF64748B);
    return const Color(0xFFEF4444);
  }

  int _stageNameToId(String stage, bool isBreeding) {
    final s = stage.trim().toLowerCase();
    if (s == 'booster') return 1;
    if (s == 'pre-starter' || s == 'pre starter') return 2;
    if (s == 'starter') return 3;
    if (s == 'grower') return 4;
    if (s == 'finisher' || s == 'breeder') return 5;
    if (s == 'selling' || s == 'lactation') return 6;
    return 1;
  }

  String _stageIdToName(dynamic stageId, bool isBreeding, String fallback) {
    if (stageId == null) return fallback;
    final id = int.tryParse(stageId.toString());
    final fatteningStages = const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'];
    final sowStages = const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation'];
    final list = isBreeding ? sowStages : fatteningStages;
    if (id != null && id >= 1 && id <= list.length) {
      return list[id - 1];
    }
    final s = stageId.toString().trim();
    if (s.isNotEmpty && s != 'null' && s != 'N/A' && int.tryParse(s) == null) {
      return s;
    }
    return fallback;
  }

  String _getHogPigType(Map<String, dynamic> hog, String fallbackType) {
    final rawType = (hog['pig_type'] ?? hog['type_name'] ?? hog['type'] ?? '').toString().trim();
    if (rawType.isNotEmpty && rawType != 'null' && rawType != 'N/A' && rawType != 'None') {
      final l = rawType.toLowerCase();
      return (l == 'sow' || l.contains('breed')) ? 'Sow' : 'Fattening';
    }
    final fallbackLower = fallbackType.toLowerCase();
    return (fallbackLower == 'sow' || fallbackLower.contains('breed')) ? 'Sow' : 'Fattening';
  }

  String _getHogStage(Map<String, dynamic> hog, String fallbackStage, bool isBreeding) {
    final hogId = hog['hog_id']?.toString() ?? '';
    final hogTag = (hog['tag_number'] ?? '').toString();
    if (hogId.isNotEmpty && _hogSpecificStages.containsKey(hogId)) {
      return _hogSpecificStages[hogId]!;
    }
    if (hogTag.isNotEmpty && _hogSpecificStages.containsKey(hogTag)) {
      return _hogSpecificStages[hogTag]!;
    }
    final dbStage = hog['stage_id'] ?? hog['lifecycle_stage'] ?? hog['stage'];
    if (dbStage != null) {
      return _stageIdToName(dbStage, isBreeding, fallbackStage.isNotEmpty ? fallbackStage : 'Booster');
    }
    return fallbackStage.isNotEmpty ? fallbackStage : 'Booster';
  }

  Future<void> _notifyAdminFinalStageReached(String targetStage, Map<String, dynamic> hog, bool isBreeding) async {
    final sLower = targetStage.trim().toLowerCase();
    final isFinal = sLower == 'selling' || sLower == 'lactation';
    if (!isFinal) return;

    final raiserName = (widget.raiserData['name'] ?? 'Hog Raiser').toString().trim();
    final raiserId = widget.raiserData['hog_raiser_id'] ?? widget.raiserData['id'];
    final pigType = _getHogPigType(hog, isBreeding ? 'Sow' : 'Fattening');

    String batchName = 'Active Batch';
    dynamic batchId;
    if (widget.activeAssignments.isNotEmpty) {
      final assign = widget.activeAssignments.first;
      final b = assign['batches'];
      if (b is Map) {
        batchName = (b['batch_name'] ?? 'Batch #${b['batch_id']}').toString();
        batchId = b['batch_id'] ?? b['id'];
      } else {
        batchId = assign['batch_id'];
        batchName = 'Batch #$batchId';
      }
    }

    final notifTitle = pigType.toLowerCase() == 'sow'
        ? 'Batch Cycle Completed (Sow)'
        : 'Batch Ready for Selling / Harvest (Fattening)';

    final notifMessage = pigType.toLowerCase() == 'sow'
        ? '$raiserName has reached the final stage ($targetStage) for $batchName (Sow). Ready for batch cycle completion.'
        : '$raiserName has reached the final stage ($targetStage) for $batchName (Fattening). Ready for harvest & batch completion.';

    try {
      final existing = await Supabase.instance.client
          .from('admin_notifications')
          .select('notification_id')
          .eq('type', 'batch')
          .eq('is_read', false)
          .like('message', '%$raiserName%')
          .like('message', '%$targetStage%')
          .limit(1);

      if ((existing as List).isEmpty) {
        await Supabase.instance.client.from('admin_notifications').insert({
          'title': notifTitle,
          'message': notifMessage,
          'type': 'batch',
          'is_read': false,
          'metadata': {
            'hog_raiser_id': raiserId,
            'raiser_name': raiserName,
            'batch_id': batchId,
            'batch_name': batchName,
            'pig_type': pigType,
            'stage': targetStage,
            'timestamp': DateTime.now().toIso8601String(),
          },
        });
        debugPrint('Automatic milestone notification sent to admin: $batchName ($pigType - $targetStage)');
      }
    } catch (e) {
      debugPrint('Notice sending milestone notification to admin: $e');
    }
  }

  Future<void> _updateSpecificHogStage(Map<String, dynamic> hog, String targetStage, bool isBreeding) async {
    final hogAssignId = hog['assignment_id']?.toString();
    final hogId = hog['hog_id'];
    final hogIdStr = hogId?.toString() ?? '';
    final hogTag = (hog['tag_number'] ?? '').toString();
    final hogName = _getHogDisplayName(hogId, AppStrings.of(context));

    final s = (hog['stage_id'] ?? hog['lifecycle_stage'] ?? hog['stage'] ?? '').toString().trim().toLowerCase();
    final isTerminalHog = (hog['status'] ?? '').toString().toLowerCase() == 'completed' ||
        (isBreeding ? (s == 'lactation' || s == '6' || s.contains('lactat')) : (s == 'selling' || s == 'sold' || s == '6' || s.contains('sell')));

    if (isTerminalHog) {
      final strings = AppStrings.of(context);
      PiggyToast.showInfo(
        context,
        strings.isFilipino
            ? 'Naitapos na ang siklo ng alagang ito ($hogName).'
            : '$hogName has already reached its final lifecycle stage.',
      );
      return;
    }

    final int stageNum = _stageNameToId(targetStage, isBreeding);

    setState(() {
      if (hogIdStr.isNotEmpty) {
        _hogSpecificStages[hogIdStr] = targetStage;
      }
      if (hogTag.isNotEmpty) {
        _hogSpecificStages[hogTag] = targetStage;
      }
      hog['stage_id'] = stageNum;
      hog['stage'] = targetStage;
      hog['lifecycle_stage'] = targetStage;
    });

    // Save to local SharedPreferences cache so stage survives page reloads
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'hog_stage_${hogAssignId}_${hogTag.isNotEmpty ? hogTag : hogIdStr}';
      await prefs.setString(cacheKey, targetStage);
      await prefs.setInt('${cacheKey}_id', stageNum);
    } catch (_) {}

    // Persist to Supabase
    bool dbUpdated = false;
    if (hogId != null) {
      try {
        final updateRes = await Supabase.instance.client
            .from('hogs')
            .update({
              'stage_id': stageNum,
              'last_updated': DateTime.now().toIso8601String(),
            })
            .eq('hog_id', hogId)
            .select('hog_id');
        if ((updateRes as List).isNotEmpty) {
          dbUpdated = true;
        }
      } catch (e) {
        debugPrint('Notice updating hog stage_id: $e');
      }
    }

    // Fallback: If hog was in-memory or not found in public.hogs, attempt to insert a real hog row if assignment exists in DB
    if (!dbUpdated && hogAssignId != null) {
      try {
        final parsedAssignId = int.tryParse(hogAssignId.toString());
        if (parsedAssignId != null && parsedAssignId < 900000) {
          final insertRes = await Supabase.instance.client
              .from('hogs')
              .insert({
                'assignment_id': parsedAssignId,
                'stage_id': stageNum,
                'status': 'active',
                'health_status': hog['health_status'] ?? 'Healthy',
                'last_updated': DateTime.now().toIso8601String(),
              })
              .select('hog_id')
              .maybeSingle();
          if (insertRes != null && insertRes['hog_id'] != null) {
            hog['hog_id'] = insertRes['hog_id'];
            final newIdStr = insertRes['hog_id'].toString();
            _hogSpecificStages[newIdStr] = targetStage;
            dbUpdated = true;
          }
        }
      } catch (e) {
        debugPrint('Notice inserting real hog row into public.hogs: $e');
      }
    }

    if (stageNum >= 6 || targetStage.trim().toLowerCase() == 'selling' || targetStage.trim().toLowerCase() == 'lactation') {
      _notifyAdminFinalStageReached(targetStage, hog, isBreeding);
    }

    if (mounted) {
      PiggyToast.showSuccess(
        context,
        AppStrings.of(context).hogStageUpdatedSuccess(hogName, targetStage),
      );
    }

    try {
      await widget.onRefresh();
    } catch (_) {}
  }


  void _showHogDetailModal(
    BuildContext context,
    Map<String, dynamic> hog,
    int index,
    String fallbackType,
    String fallbackStage, {
    bool isConcluded = false,
  }) {
    final strings = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : _brandColor;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final hogId = BigInt.from(hog['hog_id'] as num);
    final tagNumber = hog['tag_number'] ?? '#${index + 1}';
    final rawStatus = (hog['health_status'] ?? 'Healthy').toString();
    final isHealthy = rawStatus.toLowerCase() == 'healthy' || rawStatus.isEmpty;
    final weight = hog['current_weight'] != null
        ? '${hog['current_weight']} kg'
        : (hog['weight'] != null ? '${hog['weight']} kg' : null);
    final hogType = _getHogPigType(hog, fallbackType);
    final isSow = hogType == 'Sow';
    final stages = isSow
        ? const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation']
        : const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final currentStageNow = _getHogStage(hog, fallbackStage, isSow);

            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with Hog name and close button
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.pets_rounded,
                            color: isDark ? Colors.white : _brandColor,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${strings.isFilipino ? "Baboy" : "Hog"} $tagNumber',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            if (weight != null && weight.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                weight,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Health badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isHealthy
                              ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F5E9))
                              : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFFEBEE)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          strings.formatStatus(rawStatus).toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFE53935),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Tags Card (Pig Type & Current Feed Stage)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.isFilipino ? 'Uri ng Pag-aalaga' : 'Production Type',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  isSow ? strings.sowBreedTag : strings.fatteningTag,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFFF1F5F9) : _brandColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 36, color: borderColor),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.feedStageLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentStageNow,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (isConcluded) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: _successGreen, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.isFilipino
                                  ? 'Naitapos na ang siklo ng alagang ito. Naka-archive ang talaan nito at hindi na maaaring palitan ang stage.'
                                  : 'This hog has completed its cycle. Records are archived and stage cannot be changed.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Interactive Feed Stage Quick Selector
                    Builder(
                      builder: (context) {
                        Widget buildPill(String st) {
                          final isCurrent = st.toLowerCase() == currentStageNow.toLowerCase();
                          return Expanded(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (!isCurrent) {
                                    Navigator.pop(ctx);
                                    _showStageProgressionDialog(context, hog, st, isSow);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8.5),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? (isDark ? Colors.white : _brandColor)
                                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isCurrent
                                          ? (isDark ? Colors.white : _brandColor)
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isCurrent) ...[
                                          Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                          ),
                                          const SizedBox(width: 3),
                                        ],
                                        Flexible(
                                          child: Text(
                                            st,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11.5,
                                              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                              color: isCurrent
                                                  ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                for (int i = 0; i < 3 && i < stages.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  buildPill(stages[i]),
                                ],
                              ],
                            ),
                            if (stages.length > 3) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (int i = 3; i < stages.length; i++) ...[
                                    if (i > 3) const SizedBox(width: 8),
                                    buildPill(stages[i]),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),

                    // Action Button: Report Issue (Full-width & aligned)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddReportDialog(context, hogId);
                        },
                        icon: const Icon(Icons.medical_services_outlined, size: 16),
                        label: Text(
                          strings.isFilipino ? 'Mag-ulat ng Isyu' : 'Report Issue',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showReportDetailModal(BuildContext context, Map<String, dynamic> report) {
    final strings = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : _brandColor;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final type = (report['report_type'] ?? 'Health Report').toString();
    final notes = (report['description'] ?? report['notes'] ?? '').toString().trim();
    final hogId = report['hog_id'];
    final hogName = _getHogDisplayName(hogId, strings);
    final rawType = (widget.raiserData['pig_type'] ?? '').toString().trim();
    final targetHog = _findHog(hogId);
    final targetHogType = targetHog != null ? _resolveHogSpecificType(targetHog) : '';
    final targetHogTypeLabel = targetHogType.isNotEmpty
        ? _formatHogTypeLabel(targetHogType, strings)
        : ((rawType.isNotEmpty && rawType != 'N/A' && rawType != 'None') ? rawType : 'Fattening');
    final formattedTime = _formatReadableDateTime(report['created_at']);
    final reportColor = _getReportColor(type);
    final reportIcon = _getReportIcon(type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: reportColor.withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(reportIcon, color: reportColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.isFilipino ? 'Detalye ng Ulat sa Kalusugan' : 'Health Report Details',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            report['report_id'] != null
                                ? 'Report Ref #${report['report_id']}'
                                : (strings.isFilipino ? 'Opisyal na Tala ng Alaga' : 'Official Hog Record'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: isDark ? PiggyTrunkTheme.ptMutedDark : const Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.isFilipino ? 'Naisumite na sa Farm Admin at Investor' : 'Submitted to Farm Admin & Investor',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              strings.isFilipino
                                  ? 'Nakatala na sa sistema ang iyong ulat para sa agarang gabay o gamot ng alaga.'
                                  : 'Logged in the system. Farm management and investor are notified for guidance.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        context,
                        icon: Icons.pets_rounded,
                        label: strings.isFilipino ? 'Alagang Baboy' : 'Target Hog',
                        value: '$hogName ($targetHogTypeLabel)',
                        valueColor: textColor,
                      ),
                      Divider(height: 16, color: borderColor),
                      _buildDetailRow(
                        context,
                        icon: reportIcon,
                        label: strings.isFilipino ? 'Uri ng Ulat' : 'Report Type',
                        value: strings.formatStatus(type),
                        valueColor: reportColor,
                      ),
                      Divider(height: 16, color: borderColor),
                      _buildDetailRow(
                        context,
                        icon: Icons.calendar_today_rounded,
                        label: strings.isFilipino ? 'Petsa at Oras' : 'Date & Time',
                        value: formattedTime.isNotEmpty ? formattedTime : 'Kamakailan',
                        valueColor: textColor,
                      ),
                      Divider(height: 16, color: borderColor),
                      _buildDetailRow(
                        context,
                        icon: Icons.info_outline_rounded,
                        label: strings.isFilipino ? 'Katayuan' : 'Status',
                        value: strings.isFilipino ? 'Naiulat / Aktibo' : 'Reported / Active',
                        valueColor: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  strings.isFilipino ? 'Inilagay na Obserbasyon / Tala' : 'Reported Observation / Notes',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote_rounded, size: 20, color: reportColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notes.isNotEmpty
                              ? notes
                              : (strings.isFilipino ? 'Walang karagdagang detalye na inilagay.' : 'No additional details provided.'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: notes.isNotEmpty
                                ? textColor
                                : (isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted),
                            fontStyle: notes.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : _brandColor,
                      foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      strings.isFilipino ? 'Naintindihan' : 'Close',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: valueColor ?? (isDark ? Colors.white : _brandColor),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddReportDialog(BuildContext context, [BigInt? preSelectedHogId]) {
    final activeAssignIds = widget.activeAssignments
        .where((a) => a['is_cycle_completed'] != true && (a['status'] ?? '').toString().toLowerCase() != 'completed')
        .map((a) => (a['assignment_id'] as num).toInt())
        .toSet();

    final filteredHogs = widget.hogsList.where((h) {
      final assId = h['assignment_id'];
      if (assId == null) return false;
      final assInt = (assId as num).toInt();
      // Only allow hogs belonging to active, non-completed assignments
      return activeAssignIds.contains(assInt);
    }).toList();

    if (filteredHogs.isEmpty) {
      final strings = AppStrings.of(context);
      PiggyToast.showWarning(
        context,
        strings.isFilipino
            ? 'Walang aktibong alagang baboy na maaaring iulat. Naitapos na ang lahat ng siklo at naka-archive sa history.'
            : 'No active hogs available for reporting. All batch cycles are completed and archived in history.',
        title: strings.isFilipino ? 'Naitapos na ang Siklo' : 'All Cycles Completed',
      );
      return;
    }

    filteredHogs.sort((a, b) {
      final aType = _resolveHogSpecificType(a).toLowerCase();
      final bType = _resolveHogSpecificType(b).toLowerCase();
      final aIsFat = aType.contains('fatten');
      final bIsFat = bType.contains('fatten');
      if (aIsFat && !bIsFat) return -1;
      if (!aIsFat && bIsFat) return 1;
      final aId = a['hog_id'] as num? ?? 0;
      final bId = b['hog_id'] as num? ?? 0;
      return aId.compareTo(bId);
    });

    BigInt? selectedHogId = preSelectedHogId;
    if (selectedHogId != null && !filteredHogs.any((h) => BigInt.from(h['hog_id'] as num) == selectedHogId)) {
      selectedHogId = null;
    }
    if (selectedHogId == null && filteredHogs.isNotEmpty) {
      selectedHogId = BigInt.from(filteredHogs[0]['hog_id'] as num);
    }
    String selectedReportType = 'Food Poisoning';
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final strings = AppStrings.of(modalCtx);
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final bg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
            final textColor = isDark ? Colors.white : _brandColor;
            final inputBg = isDark ? const Color(0xFF1E2D42) : const Color(0xFFF8FAFC);
            final inputBorder = isDark ? const Color(0xFF3B506D) : const Color(0xFFE2E8F0);
            final dropdownBg = isDark ? const Color(0xFF1E2D42) : Colors.white;

            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.medical_services_rounded, color: _dangerRed, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.healthReportTitle,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                strings.healthReportSubtitle,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? PiggyTrunkTheme.ptMutedDark : const Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Piliin ang Baboy
                    Text(
                      strings.selectHog,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    filteredHogs.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: inputBorder),
                            ),
                            child: Text(
                              strings.noHogsAssignedCurrently,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : DropdownButtonFormField<BigInt>(
                            initialValue: selectedHogId,
                            isExpanded: true,
                            dropdownColor: dropdownBg,
                            borderRadius: BorderRadius.circular(14),
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white70 : _brandColor),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              fillColor: inputBg,
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: inputBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: inputBorder),
                              ),
                            ),
                            items: List.generate(filteredHogs.length, (index) {
                              final h = filteredHogs[index];
                              final id = h['hog_id'];
                              final specificType = _resolveHogSpecificType(h);
                              final typeLabel = _formatHogTypeLabel(specificType, strings);
                              return DropdownMenuItem<BigInt>(
                                value: BigInt.from(id as num),
                                child: Text('${strings.isFilipino ? "Baboy" : "Hog"} #${index + 1} ($typeLabel)'),
                              );
                            }),
                            onChanged: (val) {
                              setModalState(() {
                                selectedHogId = val;
                              });
                            },
                          ),
                    const SizedBox(height: 16),

                    // Uri ng Ulat
                    Text(
                      strings.reportType,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedReportType,
                      isExpanded: true,
                      dropdownColor: dropdownBg,
                      borderRadius: BorderRadius.circular(14),
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white70 : _brandColor),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        fillColor: inputBg,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(value: 'Food Poisoning', child: Text(strings.foodPoisoning)),
                        DropdownMenuItem(value: 'Fever', child: Text(strings.fever)),
                        DropdownMenuItem(value: 'Diarrhea', child: Text(strings.diarrhea)),
                        DropdownMenuItem(value: 'Injury', child: Text(strings.injury)),
                        DropdownMenuItem(value: 'Dead', child: Text(strings.deceasedReport)),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedReportType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Karagdagang Detalye
                    Text(
                      strings.additionalDetails,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: const [
                        CapitalizeSentencesInputFormatter(),
                      ],
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: textColor),
                      decoration: InputDecoration(
                        hintText: strings.healthNotesHint,
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted),
                        fillColor: inputBg,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(modalCtx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: isDark ? const Color(0xFF3B506D) : const Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              strings.cancel,
                              style: GoogleFonts.plusJakartaSans(
                                color: isDark ? PiggyTrunkTheme.ptMutedDark : const Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: selectedHogId == null
                                ? null
                                : () async {
                                    Navigator.pop(modalCtx);
                                    await widget.onSubmitHogReport(
                                      selectedHogId!,
                                      selectedReportType,
                                      notesController.text.trim(),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : _brandColor,
                              foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              strings.submitReportAction,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : _brandColor;
    final surfaceBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final borderColor = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final strings = AppStrings.of(context);

    final bool hasActiveBatch = widget.activeAssignments.isNotEmpty;

    final String rawPigType = (widget.raiserData['pig_type'] ?? '').toString().trim();
    final bool isRaiserTypeSet = rawPigType.isNotEmpty &&
        rawPigType != 'N/A' &&
        rawPigType != 'None' &&
        rawPigType.toLowerCase() != 'unassigned';

    final String assignedType = (hasActiveBatch && widget.activeAssignments[0]['hog_types']?['type_name'] != null)
        ? widget.activeAssignments[0]['hog_types']['type_name'].toString()
        : (hasActiveBatch && isRaiserTypeSet ? rawPigType : strings.unassigned);

    final String displayPigType = hasActiveBatch
        ? (assignedType.toLowerCase() == 'sow' ? 'Sow' : 'Fattening')
        : strings.unassigned;

    final String rawStage = (widget.raiserData['lifecycle_stage'] ?? '').toString().trim();
    final String activeStage = (rawStage.isNotEmpty && rawStage != 'N/A' && rawStage != 'None' && rawStage.toLowerCase() != 'unassigned')
        ? rawStage
        : (hasActiveBatch ? (widget.activeAssignments[0]['lifecycle_stage'] ?? 'Booster').toString() : 'Booster');

    final String displayStage = hasActiveBatch ? activeStage : strings.unassigned;

    final int totalHogs = widget.hogsList.length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: _brandColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 108.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== TOP BALANCED FILTER PILLS ====================
            Row(
              children: [
                Expanded(
                  child: _buildFilterChip('Hogs', strings.isFilipino ? 'Mga Baboy' : 'My Hogs', totalHogs),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildFilterChip('Reports', strings.isFilipino ? 'Mga Ulat' : 'Health Reports', widget.reportsList.length, color: _dangerRed),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (!hasActiveBatch) ...[
              // ==================== EMPTY STATE WHEN NO BATCH ====================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : _brandColor).withValues(alpha: isDark ? 0.15 : 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.assignment_late_outlined,
                            size: 28,
                            color: isDark ? Colors.white : _brandColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        strings.isFilipino ? 'Walang nakatalagang alagang baboy.' : 'No hogs assigned yet.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF18314F),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.isFilipino ? 'I-aassign ng Farm Admin ang iyong batch dito.' : 'Farm Admin will assign your batch here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // ==================== BATCH SELECTION & FILTERING (1:MANY) ====================
              Builder(
                builder: (context) {
                  final activeOnly = widget.activeAssignments.where(
                    (x) => x['is_cycle_completed'] != true && (x['status'] ?? '').toString().toLowerCase() != 'completed',
                  ).toList();
                  final bool isAllHeads = _selectedBatchAssignmentId == null && activeOnly.length > 1;

                  final selectedAssignment = isAllHeads && activeOnly.isNotEmpty
                      ? activeOnly.first
                      : widget.activeAssignments.firstWhere(
                          (a) =>
                              _selectedBatchAssignmentId != null &&
                              BigInt.from(a['assignment_id'] as num) == _selectedBatchAssignmentId,
                          orElse: () => widget.activeAssignments.isNotEmpty
                              ? widget.activeAssignments[0]
                              : <String, dynamic>{},
                        );

                  final selectedAssignId = isAllHeads ? null : (_selectedBatchAssignmentId ?? (selectedAssignment['assignment_id'] != null ? BigInt.from(selectedAssignment['assignment_id'] as num) : null));
                  final visibleHogs = widget.hogsList.where((h) {
                    if (isAllHeads) {
                      final aId = h['assignment_id'];
                      return activeOnly.any((a) => (a['assignment_id'] ?? a['id'])?.toString() == aId?.toString());
                    }
                    if (selectedAssignId == null && widget.activeAssignments.length <= 1) {
                      return true;
                    }
                    final aId = h['assignment_id'];
                    if (aId != null && selectedAssignId != null) {
                      final parsedAId = aId is num ? BigInt.from(aId) : BigInt.tryParse(aId.toString());
                      return parsedAId == selectedAssignId;
                    }
                    return selectedAssignId == null;
                  }).toList();

                  visibleHogs.sort((a, b) {
                    final aType = (a['pig_type'] ?? a['type_name'] ?? '').toString().toLowerCase();
                    final bType = (b['pig_type'] ?? b['type_name'] ?? '').toString().toLowerCase();
                    final aIsFat = aType.contains('fatten');
                    final bIsFat = bType.contains('fatten');
                    if (aIsFat && !bIsFat) return -1;
                    if (!aIsFat && bIsFat) return 1;

                    final aTag = int.tryParse((a['tag_number'] ?? a['hog_id'] ?? '').toString().replaceAll('#', '')) ?? 0;
                    final bTag = int.tryParse((b['tag_number'] ?? b['hog_id'] ?? '').toString().replaceAll('#', '')) ?? 0;
                    return aTag.compareTo(bTag);
                  });

                  final String batchType = (selectedAssignment['hog_types']?['type_name'] ??
                          selectedAssignment['pig_type'] ??
                          displayPigType)
                      .toString();
                  final bool isBatchSow = batchType.toLowerCase() == 'sow' ||
                      batchType.toLowerCase().contains('breed');

                  final bool hasActiveUnfinishedHogs = visibleHogs.any((h) {
                    final hStatus = (h['status'] ?? '').toString().trim().toLowerCase();
                    final s = (h['stage_id'] ?? h['lifecycle_stage'] ?? h['stage'] ?? '').toString().trim().toLowerCase();
                    final sId = int.tryParse(s);
                    final isBreed = _getHogPigType(h, displayPigType) == 'Sow';
                    final bool isTerminal = hStatus == 'completed' || (isBreed
                        ? (s == 'lactation' || s == '6' || s.contains('lactat'))
                        : (s == 'selling' || s == 'sold' || s == '6' || s.contains('sell')));
                    return !isTerminal && (sId == null || sId < 6);
                  });

                  final bool allVisibleHogsDone = visibleHogs.isNotEmpty && !hasActiveUnfinishedHogs;

                  // Strict business logic: Batch cycle concludes ONLY when ALL visible hogs are finished and NONE are active
                  final bool isBatchConcluded = visibleHogs.isNotEmpty && !hasActiveUnfinishedHogs && allVisibleHogsDone;

                  final selectedHog = visibleHogs.isNotEmpty
                      ? visibleHogs[_selectedHogIndex.clamp(0, visibleHogs.length - 1)]
                      : null;
                  final String currentHogType = selectedHog != null
                      ? _getHogPigType(selectedHog, batchType)
                      : batchType;
                  final bool isCurrentBreeding = selectedHog != null
                      ? (currentHogType.toLowerCase() == 'sow' || currentHogType.toLowerCase().contains('breed'))
                      : (isBatchSow || currentHogType.toLowerCase() == 'sow');
                  final List<String> currentStages = isCurrentBreeding
                      ? const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation']
                      : const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'];

                  String currentHogStage = selectedHog != null
                      ? _getHogStage(selectedHog, displayStage, isCurrentBreeding)
                      : (selectedAssignment['lifecycle_stage']?.toString() ?? displayStage);
                  if (!isCurrentBreeding && currentHogStage.toLowerCase() == 'lactation') {
                    currentHogStage = currentStages.first;
                  } else if (isCurrentBreeding && (currentHogStage.toLowerCase() == 'selling' || currentHogStage.toLowerCase() == 'finisher')) {
                    currentHogStage = currentStages.first;
                  }

                  final int batchHogsCount = visibleHogs.length;
                  final int batchHealthyCount = visibleHogs.where((h) {
                    final raw = (h['health_status'] ?? 'Healthy').toString().toLowerCase();
                    return raw == 'healthy' || raw.isEmpty;
                  }).length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.activeAssignments.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: surfaceBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: widget.activeAssignments.length > 1
                                ? () => _showBatchPickerModal(context)
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: _brandColor.withValues(alpha: isDark ? 0.25 : 0.08),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Icon(Icons.pets_rounded, size: 14, color: isDark ? Colors.white : _brandColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Batch:',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: mutedColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _formatAssignmentLabel(selectedAssignment),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (selectedAssignment['is_cycle_completed'] == true) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.5 : 0.25),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 10.5, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                          const SizedBox(width: 3.5),
                                          Text(
                                            strings.isFilipino ? 'Tapos Na' : 'Completed',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (widget.activeAssignments.length > 1) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            strings.isFilipino ? 'Palitan' : 'Change',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFF38BDF8) : _brandColor,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Icon(
                                            Icons.unfold_more_rounded,
                                            size: 14,
                                            color: isDark ? const Color(0xFF38BDF8) : _brandColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

                      if (isBatchConcluded) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14291F) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.6 : 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.history_edu_rounded, color: Color(0xFF10B981), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      strings.isFilipino ? 'Naitapos na ang Siklo (Kasaysayan)' : 'Batch Cycle Completed (Archived)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF065F46),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      strings.isFilipino
                                          ? 'Ang batch na ito ay tapos na at naka-archive sa history. Hindi na maaaring palitan ang stage o mag-ulat.'
                                          : 'All hogs in this batch reached selling stage and are archived in history. Stage updates and reports are locked.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ==================== FEEDS STAGES TIMELINE CARD ====================
                      _buildFeedsCard(
                        title: strings.isFilipino ? 'Mga Stage ng Pakain' : 'Feeds Stages',
                        badgeText: isBatchConcluded
                            ? (strings.isFilipino ? 'Tapos na ang Siklo' : 'Concluded Cycle')
                            : (hasActiveBatch
                                ? (isCurrentBreeding ? strings.sowBreedTag : strings.fatteningTag)
                                : strings.unassigned),
                        stages: currentStages,
                        activeStage: isBatchConcluded ? currentStages.last : currentHogStage,
                        targetHog: selectedHog,
                        isBreeding: isCurrentBreeding,
                        fallbackType: batchType,
                        fallbackStage: displayStage,
                        hogs: visibleHogs,
                        isConcluded: isBatchConcluded,
                      ),
                      const SizedBox(height: 24),

                      // ==================== TAB CONTENT: HOGS OR REPORTS ====================
                      if (_selectedTab == 'Hogs') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              strings.isFilipino ? 'Listahan ng Alaga' : 'Hogs Inventory',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '$batchHogsCount ${strings.hogs} ($batchHealthyCount ${strings.healthy})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: PiggyTrunkTheme.ptMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (visibleHogs.isEmpty) ...[
                          RaiserEmptyState(
                            icon: Icons.pets_outlined,
                            message: strings.noHogsFound,
                            subtitle: strings.noHogsSubtitle,
                          ),
                        ] else ...[
                          ...visibleHogs.asMap().entries.map((entry) {
                            final index = entry.key;
                            final hog = entry.value;
                            final rawStatus = (hog['health_status'] ?? 'Healthy').toString();
                            final isHealthy = rawStatus.toLowerCase() == 'healthy' || rawStatus.isEmpty;
                            final tagNumber = hog['tag_number'] ?? '#${index + 1}';
                            final String? weight = null;
                            final hogType = _getHogPigType(hog, batchType);
                            final isSow = hogType == 'Sow';
                            final hogStage = _getHogStage(hog, displayStage, isSow);
                            final bool isThisHogDone = (hogStage.toLowerCase() == 'selling' ||
                                hogStage.toLowerCase() == 'lactation' ||
                                (hog['status'] ?? '').toString().toLowerCase() == 'completed');

                            return GestureDetector(
                              onTap: () => _showHogDetailModal(context, hog, index, batchType, displayStage, isConcluded: isBatchConcluded || isThisHogDone),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: (isBatchConcluded || isThisHogDone)
                                      ? (isDark ? const Color(0xFF142032) : const Color(0xFFF8FAFC))
                                      : (isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: (isBatchConcluded || isThisHogDone)
                                        ? (isDark ? const Color(0xFF24334A) : const Color(0xFFE2E8F0))
                                        : (isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.pets_rounded,
                                          color: isBatchConcluded
                                              ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                                              : (isDark ? Colors.white : _brandColor),
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                '${strings.isFilipino ? "Baboy" : "Hog"} $tagNumber',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: isBatchConcluded
                                                      ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                                      : (isDark ? Colors.white : _brandColor),
                                                ),
                                              ),
                                              if (isBatchConcluded && isThisHogDone) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    strings.isFilipino ? 'Tapos na' : 'Concluded',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              // Distinct Fattening vs Sow/Breed Tag
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  isSow ? strings.sowBreedTag : strings.fatteningTag,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? const Color(0xFFF1F5F9) : _brandColor,
                                                  ),
                                                ),
                                              ),
                                              // Specific Feed Stage Tag
                                              Builder(
                                                builder: (context) {
                                                  final isHogCompleted = hogStage.toLowerCase() == 'selling' || hogStage.toLowerCase() == 'lactation';
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                    decoration: BoxDecoration(
                                                      color: isHogCompleted
                                                          ? _successGreen.withValues(alpha: isDark ? 0.22 : 0.12)
                                                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: isHogCompleted
                                                            ? _successGreen.withValues(alpha: isDark ? 0.6 : 0.4)
                                                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        if (isHogCompleted) ...[
                                                          const Icon(Icons.check_rounded, size: 10, color: _successGreen),
                                                          const SizedBox(width: 3),
                                                        ],
                                                        Text(
                                                          isHogCompleted ? '$hogStage • Complete' : hogStage,
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 10.5,
                                                            fontWeight: FontWeight.w700,
                                                            color: isHogCompleted ? _successGreen : (isDark ? const Color(0xFFE2E8F0) : _brandColor),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          if (weight != null && weight.isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            Text(
                                              weight,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isHealthy
                                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F5E9))
                                        : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFFEBEE)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isHealthy ? Icons.check_circle_outline : Icons.error_outline,
                                        size: 13,
                                        color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFE53935),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        strings.formatStatus(rawStatus).toUpperCase(),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFE53935),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 13,
                                  color: isDark ? PiggyTrunkTheme.ptMutedDark : const Color(0xFFCBD5E1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ] else ...[
                // ==================== REPORTS TAB ====================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.healthReportsActivity,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    if (!isBatchConcluded)
                      GestureDetector(
                        onTap: () => _showAddReportDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : _brandColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? Colors.white : _brandColor).withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 16, color: isDark ? const Color(0xFF0F172A) : Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                strings.addReportButton,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (widget.reportsList.isEmpty) ...[
                  RaiserEmptyState(
                    icon: Icons.health_and_safety_outlined,
                    message: strings.noHealthReports,
                    subtitle: strings.noHealthReportsSubtitle,
                  ),
                ] else ...[
                  ...widget.reportsList.map((report) {
                    final type = (report['report_type'] ?? 'Health Report').toString();
                    final notes = (report['description'] ?? report['notes'] ?? '').toString().trim();
                    final hogId = report['hog_id'];
                    final hogName = _getHogDisplayName(hogId, strings);
                    final hog = _findHog(hogId);
                    final timeAgo = _formatReportTime(report['created_at'], strings);
                    final reportColor = _getReportColor(type);
                    final reportIcon = _getReportIcon(type);

                    // Resolve batch and cycle status
                    final hAssignId = hog?['assignment_id'];
                    Map<String, dynamic>? reportAssign;
                    if (hAssignId != null) {
                      for (final a in widget.activeAssignments) {
                        if (a['assignment_id']?.toString() == hAssignId.toString()) {
                          reportAssign = a;
                          break;
                        }
                      }
                    }
                    final bool isReportFromCompletedBatch = reportAssign?['is_cycle_completed'] == true ||
                        (reportAssign?['status'] ?? '').toString().toLowerCase() == 'completed';
                    final String rawReportBatchName = (reportAssign?['batches']?['batch_name'] ?? reportAssign?['batch_name'] ?? '').toString().trim();
                    final String reportBatchName = rawReportBatchName.isNotEmpty ? rawReportBatchName : '';
                    final String reportPigType = (reportAssign?['hog_types']?['type_name'] ?? reportAssign?['pig_type'] ?? (hog?['pig_type'] ?? '')).toString().trim();
                    final String displayReportPigType = reportPigType.toLowerCase().contains('sow') ? 'Sow' : (reportPigType.isNotEmpty ? 'Fattening' : '');

                    return GestureDetector(
                      onTap: () => _showReportDetailModal(context, report),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isReportFromCompletedBatch
                              ? (isDark ? const Color(0xFF142032) : const Color(0xFFF8FAFC))
                              : (isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isReportFromCompletedBatch
                                ? (isDark ? const Color(0xFF24334A) : const Color(0xFFE2E8F0))
                                : (isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row: Icon, Title & Hog chip, and Status badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: (isReportFromCompletedBatch ? const Color(0xFF64748B) : reportColor).withValues(alpha: isDark ? 0.25 : 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    reportIcon,
                                    color: isReportFromCompletedBatch ? const Color(0xFF94A3B8) : reportColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        strings.formatStatus(type),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: isReportFromCompletedBatch
                                              ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                              : textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.pets_rounded,
                                                  size: 11,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  hogName,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (reportBatchName.isNotEmpty) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isReportFromCompletedBatch
                                                    ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                                                    : (isDark ? const Color(0xFF0F2E47) : const Color(0xFFE0F2FE)),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isReportFromCompletedBatch
                                                    ? (displayReportPigType.isNotEmpty ? '$reportBatchName ($displayReportPigType) • ${strings.isFilipino ? "Tapos na" : "Concluded"}' : '$reportBatchName • ${strings.isFilipino ? "Tapos na" : "Concluded"}')
                                                    : (displayReportPigType.isNotEmpty ? '$reportBatchName ($displayReportPigType)' : reportBatchName),
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: isReportFromCompletedBatch
                                                      ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                                      : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isReportFromCompletedBatch
                                        ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
                                        : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFECFDF5)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isReportFromCompletedBatch
                                          ? (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
                                          : (isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0)),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 11,
                                        color: isReportFromCompletedBatch ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isReportFromCompletedBatch
                                            ? (strings.isFilipino ? 'Nakaraang Siklo' : 'Past Cycle')
                                            : (strings.isFilipino ? 'Naiulat' : 'Reported'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isReportFromCompletedBatch
                                              ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                              : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Raiser Observation Box (Fixes the missing notes issue!)
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border(
                                    left: BorderSide(color: reportColor, width: 3),
                                    top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    right: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.format_quote_rounded, size: 14, color: reportColor),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        notes,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: isDark ? Colors.white : const Color(0xFF334155),
                                          fontWeight: FontWeight.w500,
                                          height: 1.35,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            // Footer: Timestamp and "View Details" prompt
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 13,
                                      color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      timeAgo,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      strings.isFilipino ? 'Tingnan ang detalye' : 'View details',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : _brandColor,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 10,
                                      color: isDark ? Colors.white : _brandColor,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                      ],
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildFilterChip(String key, String label, int count, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedTab == key;
    final inactiveBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final inactiveBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final inactiveText = isDark ? Colors.white : _brandColor;
    final selectedBg = isDark ? Colors.white : _brandColor;
    final selectedText = isDark ? const Color(0xFF0F172A) : Colors.white;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? selectedBg : inactiveBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? Colors.white : _brandColor).withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? selectedText : inactiveText,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.22))
                    : (color?.withValues(alpha: isDark ? 0.2 : 0.12) ?? (isDark ? const Color(0xFF1E293B) : PiggyTrunkTheme.ptBg)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? selectedText : (color ?? inactiveText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedsCard({
    required String title,
    required String badgeText,
    required List<String> stages,
    required String activeStage,
    Map<String, dynamic>? targetHog,
    required bool isBreeding,
    required String fallbackType,
    required String fallbackStage,
    List<Map<String, dynamic>>? hogs,
    bool isConcluded = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final bool isUnassigned = badgeText.toLowerCase() == 'unassigned';
    final cardBg = isConcluded
        ? (isDark ? const Color(0xFF142032) : const Color(0xFFF8FAFC))
        : (isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white);
    final cardBorder = isConcluded
        ? (isDark ? const Color(0xFF24334A) : const Color(0xFFE2E8F0))
        : (isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder);
    final textColor = isConcluded
        ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))
        : (isDark ? Colors.white : _brandColor);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Pig Type Badge + Complete Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isConcluded ||
                      activeStage.toLowerCase() == 'selling' ||
                      activeStage.toLowerCase() == 'lactation' ||
                      (!isUnassigned && stages.isNotEmpty && activeStage.toLowerCase() == stages.last.toLowerCase())) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: _successGreen.withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _successGreen.withValues(alpha: isDark ? 0.6 : 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 12, color: _successGreen),
                          const SizedBox(width: 4),
                          Text(
                            strings.isFilipino ? 'TAPOS NA' : 'COMPLETE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _successGreen,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isConcluded
                          ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                          : (isUnassigned
                              ? (isDark ? const Color(0xFF1E2D42) : const Color(0xFFF1F5F9))
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isConcluded
                            ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
                            : (isUnassigned
                                ? (isDark ? const Color(0xFF3B506D) : const Color(0xFFE2E8F0))
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isConcluded
                            ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                            : (isUnassigned
                                ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                : (isDark ? const Color(0xFFF1F5F9) : _brandColor)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (isConcluded) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 16, color: _successGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.isFilipino
                          ? 'Naitapos na ang siklong ito. Naka-archive ang talaan nito at hindi na makaaapekto sa susunod na batch.'
                          : 'This batch cycle is concluded. Records are archived and independent of your next batch.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Hog Switcher Tab Bar (when there are multiple hogs in batch!)
          Builder(
            builder: (context) {
              final effectiveHogs = hogs ?? widget.hogsList;
              if (effectiveHogs.length <= 1) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: effectiveHogs.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final h = entry.value;
                      final isSelected = _selectedHogIndex == idx;
                      final isHovered = _hoveredHogIndex == idx;
                      final tag = h['tag_number'] ?? '#${idx + 1}';
                      final hType = _getHogPigType(h, fallbackType);
                      final hIsBreed = hType.toLowerCase() == 'sow';
                      final hStage = _getHogStage(h, fallbackStage, hIsBreed);
                      final isHogDone = hStage.toLowerCase() == 'selling' || hStage.toLowerCase() == 'lactation';

                      return Expanded(
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _hoveredHogIndex = idx),
                          onExit: (_) => setState(() {
                            if (_hoveredHogIndex == idx) _hoveredHogIndex = null;
                          }),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _selectedHogIndex = idx;
                                _hoveredHogIndex = null;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white)
                                    : (isHovered
                                        ? (isDark ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.65))
                                        : Colors.transparent),
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: SelectionContainer.disabled(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.pets_rounded,
                                          size: 13,
                                          color: isSelected
                                              ? (isDark ? Colors.white : _brandColor)
                                              : (isHovered
                                                  ? (isDark ? Colors.white : _brandColor)
                                                  : PiggyTrunkTheme.ptMuted),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '${strings.isFilipino ? "Baboy" : "Hog"} $tag',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              color: isSelected
                                                  ? (isDark ? Colors.white : _brandColor)
                                                  : (isHovered
                                                      ? (isDark ? Colors.white : _brandColor)
                                                      : PiggyTrunkTheme.ptMuted),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isHogDone) ...[
                                          const Icon(Icons.check_rounded, size: 11, color: _successGreen),
                                          const SizedBox(width: 3),
                                        ],
                                        Text(
                                          isHogDone ? '$hStage • Complete' : hStage,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isHogDone
                                                ? _successGreen
                                                : (isSelected
                                                    ? (isDark ? const Color(0xFFF1F5F9) : _brandColor)
                                                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          _buildTimeline(stages, activeStage, targetHog, isBreeding, isConcluded: isConcluded),
        ],
      ),
    );
  }

  Widget _buildTimeline(
    List<String> stages,
    String activeStage,
    Map<String, dynamic>? targetHog,
    bool isBreeding, {
    bool isConcluded = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasActiveBatch = widget.activeAssignments.isNotEmpty;
    final bool isUnassigned = activeStage.toLowerCase() == 'unassigned';
    int activeIndex = isUnassigned
        ? -1
        : stages.indexWhere((s) => s.toLowerCase() == activeStage.toLowerCase());
    final bool isLastStageReached = isConcluded || (activeIndex >= 0 && activeIndex == stages.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final stepWidth = totalWidth / stages.length;

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            // Connecting line
            Positioned(
              top: 16,
              left: stepWidth / 2,
              right: stepWidth / 2,
              child: Row(
                children: List.generate(stages.length - 1, (index) {
                  final isPassed = isConcluded || index < activeIndex || isLastStageReached;
                  return Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: isPassed ? _successGreen : (isDark ? const Color(0xFF334A66) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Nodes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(stages.length, (index) {
                final bool isLastNodeAndCompleted = isConcluded || (isLastStageReached && index == stages.length - 1);
                final isPassed = isConcluded || index < activeIndex || isLastNodeAndCompleted;
                final isActive = !isConcluded && index == activeIndex && !isLastStageReached;

                Color circleColor;
                Widget iconWidget;
                BoxBorder? nodeBorder;

                if (isPassed) {
                  circleColor = _successGreen;
                  iconWidget = const Icon(Icons.check_rounded, size: 16, color: Colors.white);
                } else if (isActive) {
                  circleColor = isDark ? Colors.white : _brandColor;
                  iconWidget = Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                } else {
                  circleColor = isDark ? const Color(0xFF1E2D42) : const Color(0xFFF1F5F9);
                  nodeBorder = isDark ? Border.all(color: const Color(0xFF3B506D), width: 1.2) : null;
                  iconWidget = Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFFA0AEC0),
                  );
                }

                final isFuture = index > activeIndex;

                return GestureDetector(
                  onTap: () {
                    if (!isConcluded && hasActiveBatch && isFuture) {
                      final effectiveHog = targetHog ?? (widget.hogsList.isNotEmpty ? widget.hogsList[0] : null);
                      if (effectiveHog != null) {
                        _showStageProgressionDialog(context, effectiveHog, stages[index], isBreeding);
                      }
                    }
                  },
                  child: SizedBox(
                    width: stepWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: (isActive || isLastNodeAndCompleted) ? 34 : 30,
                          height: (isActive || isLastNodeAndCompleted) ? 34 : 30,
                          decoration: BoxDecoration(
                            color: circleColor,
                            shape: BoxShape.circle,
                            border: nodeBorder,
                            boxShadow: (isActive || isLastNodeAndCompleted)
                                ? [
                                    BoxShadow(
                                      color: (isLastNodeAndCompleted ? _successGreen : (isDark ? Colors.white : _brandColor)).withValues(alpha: isDark ? 0.35 : 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(child: iconWidget),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          stages[index],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: (isActive || isLastNodeAndCompleted) ? FontWeight.w800 : (isPassed ? FontWeight.w700 : FontWeight.w600),
                            color: isActive
                                ? (isDark ? Colors.white : _brandColor)
                                : (isPassed ? _successGreen : (isDark ? const Color(0xFF94A3B8) : const Color(0xFFA0AEC0))),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  void _showStageProgressionDialog(
    BuildContext context,
    Map<String, dynamic> targetHog,
    String targetStage,
    bool isBreeding,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final hogId = targetHog['hog_id'];
    final hogName = _getHogDisplayName(hogId, strings);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            strings.stageProgressionTitle,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? Colors.white : _brandColor,
            ),
          ),
          content: Text(
            strings.advanceHogStagePrompt(hogName, targetStage),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      strings.cancel,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _updateSpecificHogStage(targetHog, targetStage, isBreeding);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : _brandColor,
                      foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      strings.confirm,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
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
  }
}
