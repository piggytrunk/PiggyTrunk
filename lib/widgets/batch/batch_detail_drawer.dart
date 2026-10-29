import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class BatchDetailDrawer {
  static void show({
    required BuildContext context,
    required Map<String, dynamic> batch,
    VoidCallback? onEdit,
    VoidCallback? onArchive,
    VoidCallback? onDelete,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    if (isMobile) {
      _showBottomSheet(context, batch);
    } else {
      _showSideDrawer(context, batch);
    }
  }

  static void _showBottomSheet(
    BuildContext context,
    Map<String, dynamic> batch,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final hintText = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);

    final batchName = batch['batch_name']?.toString() ?? 'Batch Details';
    final raiserName = batch['raiser_name']?.toString() ?? 'Unassigned';
    final dateCreated = batch['date_created']?.toString() ?? 'N/A';
    final status = batch['status']?.toString().toUpperCase() ?? 'ACTIVE';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: cardBorder, width: 1.2)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: hintText.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Batch Details',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: Icon(Icons.close_rounded, color: hintText, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B2E48) : const Color(0xFFF6F9FD),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorder.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            _detailRow('Batch Name', batchName, hintText, titleColor),
                            Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                            _detailRow('Assigned Raiser', raiserName, hintText, titleColor, customValue: _buildRaiserValue(batch['raiser_name']?.toString(), titleColor)),
                            Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                            _detailRow('Status', status, hintText, titleColor, customValue: _buildStatusValue(status)),
                            Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                            _detailRow('Date Created', dateCreated, hintText, titleColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _BatchHogsList(
                        batch: batch,
                        isDark: isDark,
                        cardBorder: cardBorder,
                        titleColor: titleColor,
                        hintText: hintText,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showSideDrawer(
    BuildContext context,
    Map<String, dynamic> batch,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final hintText = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);

    final batchName = batch['batch_name']?.toString() ?? 'Batch Details';
    final raiserName = batch['raiser_name']?.toString() ?? 'Unassigned';
    final dateCreated = batch['date_created']?.toString() ?? 'N/A';
    final status = batch['status']?.toString().toUpperCase() ?? 'ACTIVE';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Batch Details',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 420,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(left: BorderSide(color: cardBorder, width: 1.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(-4, 0),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Text(
                              'Batch Profile',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: Icon(Icons.close_rounded, color: hintText, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Close panel',
                            ),
                          ],
                        ),
                      ),
                      Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1B2E48) : const Color(0xFFF6F9FD),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: cardBorder.withValues(alpha: 0.5)),
                                ),
                                child: Column(
                                  children: [
                                    _detailRow('Batch Name', batchName, hintText, titleColor),
                                    Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                                    _detailRow('Assigned Raiser', raiserName, hintText, titleColor, customValue: _buildRaiserValue(batch['raiser_name']?.toString(), titleColor)),
                                    Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                                    _detailRow('Status', status, hintText, titleColor, customValue: _buildStatusValue(status)),
                                    Divider(color: cardBorder.withValues(alpha: 0.35), height: 1),
                                    _detailRow('Date Created', dateCreated, hintText, titleColor),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              _BatchHogsList(
                                batch: batch,
                                isDark: isDark,
                                cardBorder: cardBorder,
                                titleColor: titleColor,
                                hintText: hintText,
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildRaiserValue(String? rawRaiser, Color valueColor) {
    final clean = (rawRaiser ?? '').trim();
    final bool hasRaiser = clean.isNotEmpty &&
        clean.toLowerCase() != 'unassigned' &&
        clean.toLowerCase() != 'none' &&
        clean != 'null';

    if (hasRaiser) {
      return Text(
        clean,
        textAlign: TextAlign.right,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: valueColor,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined, size: 13, color: Color(0xFFF59E0B)),
              const SizedBox(width: 5),
              Text(
                'No raiser at the moment',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildStatusValue(String rawStatus) {
    final sUpper = rawStatus.toUpperCase().trim();
    final bool isFinished = sUpper == 'FINISHED' || sUpper == 'COMPLETED' || sUpper == 'HARVESTED';
    final bool isActive = sUpper == 'ACTIVE';

    final Color badgeColor = isActive
        ? const Color(0xFF10B981)
        : (isFinished ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8));

    final String displayText = sUpper == 'UNASSIGNED' ? 'STANDBY' : sUpper;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                displayText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _detailRow(String label, String value, Color labelColor, Color valueColor, {Widget? customValue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: customValue ??
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _BatchHogsList extends StatefulWidget {
  final Map<String, dynamic> batch;
  final bool isDark;
  final Color cardBorder;
  final Color titleColor;
  final Color hintText;

  const _BatchHogsList({
    required this.batch,
    required this.isDark,
    required this.cardBorder,
    required this.titleColor,
    required this.hintText,
  });

  @override
  State<_BatchHogsList> createState() => _BatchHogsListState();
}

class _BatchHogsListState extends State<_BatchHogsList> {
  List<Map<String, dynamic>> _hogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBatchHogs();
  }

  Future<void> _fetchBatchHogs() async {
    try {
      final assignId = widget.batch['assignment_id'];
      final batchId = widget.batch['batch_id'] ?? widget.batch['id'];

      final Map<int, String> hogTypeNamesMap = {};
      try {
        final htList = await Supabase.instance.client
            .from('hog_types')
            .select('hog_type_id, type_name');
        for (var ht in (htList as List? ?? [])) {
          if (ht is Map && ht['hog_type_id'] != null) {
            hogTypeNamesMap[(ht['hog_type_id'] as num).toInt()] =
                (ht['type_name'] ?? '').toString();
          }
        }
      } catch (_) {}

      final Set<dynamic> allAssignIds = {};
      final Set<dynamic> activeAssignIds = {};
      final Map<String, String> assignTypeMap = {};

      if (batchId != null) {
        try {
          final assignRows = await Supabase.instance.client
              .from('assignments')
              .select('assignment_id, hog_type_id, status')
              .eq('batch_id', batchId);
          for (var a in (assignRows as List? ?? [])) {
            if (a is Map && a['assignment_id'] != null) {
              final aId = a['assignment_id'];
              allAssignIds.add(aId);
              final st = (a['status'] ?? 'active').toString().toLowerCase();
              if (st == 'active') {
                activeAssignIds.add(aId);
              }
              final htId = int.tryParse((a['hog_type_id'] ?? '').toString());
              if (htId != null && hogTypeNamesMap.containsKey(htId)) {
                assignTypeMap[aId.toString()] = hogTypeNamesMap[htId]!;
              }
            }
          }
        } catch (_) {}
      }
      if (assignId != null) allAssignIds.add(assignId);

      final targetAssignIds =
          activeAssignIds.isNotEmpty ? activeAssignIds : allAssignIds;

      List<dynamic> res = [];
      if (targetAssignIds.isNotEmpty) {
        res = await Supabase.instance.client
            .from('hogs')
            .select('*')
            .inFilter('assignment_id', targetAssignIds.toList())
            .order('hog_id', ascending: true);
      }

      if (res.isEmpty &&
          activeAssignIds.isNotEmpty &&
          allAssignIds.length > activeAssignIds.length) {
        res = await Supabase.instance.client
            .from('hogs')
            .select('*')
            .inFilter('assignment_id', allAssignIds.toList())
            .order('hog_id', ascending: true);
      }

      final loadedHogs = List<Map<String, dynamic>>.from(res)
          .where((h) =>
              (h['health_status'] ?? '').toString().toLowerCase() != 'dead')
          .map((h) {
        final copy = Map<String, dynamic>.from(h);
        final aIdStr = (copy['assignment_id'] ?? '').toString();
        final currentType = (copy['pig_type'] ?? '').toString().trim();
        if (currentType.isEmpty && assignTypeMap.containsKey(aIdStr)) {
          copy['pig_type'] = assignTypeMap[aIdStr];
        }
        return copy;
      }).toList();

      loadedHogs.sort((a, b) {
        final typeA = (a['pig_type'] ?? '').toString().toLowerCase();
        final typeB = (b['pig_type'] ?? '').toString().toLowerCase();
        final isSowA = typeA.contains('sow') || typeA.contains('breed');
        final isSowB = typeB.contains('sow') || typeB.contains('breed');
        if (!isSowA && isSowB) return -1;
        if (isSowA && !isSowB) return 1;
        final idA = (a['hog_id'] as num?)?.toInt() ?? 0;
        final idB = (b['hog_id'] as num?)?.toInt() ?? 0;
        return idA.compareTo(idB);
      });

      if (mounted) {
        setState(() {
          _hogs = loadedHogs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Notice loading batch hogs: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _resolveStageName(dynamic stageVal, [bool isBreeding = false]) {
    final fatteningStages = const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'];
    final sowStages = const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation'];
    final stages = isBreeding ? sowStages : fatteningStages;
    final id = int.tryParse(stageVal?.toString() ?? '');
    if (id != null && id >= 1 && id <= stages.length) {
      return stages[id - 1];
    }
    final s = stageVal?.toString().trim() ?? '';
    if (s.isNotEmpty && s != 'null' && s != 'N/A' && int.tryParse(s) == null) {
      return s;
    }
    return 'Booster';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBorder = widget.cardBorder;
    final titleColor = widget.titleColor;
    final hintText = widget.hintText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pets_rounded,
                  size: 16,
                  color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'HOGS IN THIS BATCH',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF243B5B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_hogs.length} head${_hogs.length == 1 ? '' : 's'}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
              ),
            ),
          )
        else if (_hogs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2E48).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Icon(Icons.pets_outlined, size: 24, color: hintText.withValues(alpha: 0.5)),
                const SizedBox(height: 6),
                Text(
                  'No hogs recorded in this batch yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: hintText,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _hogs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final hog = _hogs[idx];
              final rawType = (hog['pig_type'] ?? '').toString().trim();
              final isBreed = rawType.toLowerCase().contains('sow') || rawType.toLowerCase().contains('breed');
              final stageName = _resolveStageName(hog['stage_id'] ?? hog['lifecycle_stage'], isBreed);
              final health = (hog['health_status'] ?? 'healthy').toString().toLowerCase();
              final isSick = health == 'sick' || health == 'fever' || health == 'injured';
              final isObserving = health.contains('observ');

              final healthColor = isSick
                  ? const Color(0xFFEF4444)
                  : (isObserving ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
              final healthLabel = isSick
                  ? 'SICK'
                  : (isObserving ? 'OBSERVATION' : 'HEALTHY');

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16253B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBorder.withValues(alpha: 0.7)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF243B5B).withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.pets_rounded,
                        size: 16,
                        color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hog #${idx + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Builder(
                          builder: (context) {
                            final isComplete = stageName.toLowerCase() == 'selling' ||
                                stageName.toLowerCase() == 'lactation' ||
                                stageName.toLowerCase() == 'completed';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isComplete
                                    ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.12)
                                    : (isDark ? const Color(0xFF243B5B) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isComplete
                                      ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.6 : 0.4)
                                      : cardBorder.withValues(alpha: isDark ? 0.7 : 0.8),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isComplete) ...[
                                    const Icon(Icons.check_rounded, size: 10, color: Color(0xFF10B981)),
                                    const SizedBox(width: 3),
                                  ],
                                  Text(
                                    isComplete ? '$stageName • Complete' : stageName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: isComplete
                                          ? const Color(0xFF10B981)
                                          : (isDark ? const Color(0xFFE2E8F0) : PiggyTrunkTheme.ptPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(color: healthColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              healthLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: healthColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
