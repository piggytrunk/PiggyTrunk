import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class BatchDetailView extends StatefulWidget {
  final Map<String, dynamic> batch;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic> batch)? onEdit;
  final void Function(Map<String, dynamic> batch)? onArchive;

  const BatchDetailView({
    super.key,
    required this.batch,
    required this.onBack,
    this.onEdit,
    this.onArchive,
  });

  @override
  State<BatchDetailView> createState() => _BatchDetailViewState();
}

class _BatchDetailViewState extends State<BatchDetailView> {
  List<Map<String, dynamic>> _hogs = [];
  bool _isLoadingHogs = true;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _mutedColor => _isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
  Color get _cardBg => _isDark ? const Color(0xFF132238) : Colors.white;
  Color get _cardBorder => _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
  Color get _fieldBg => _isDark ? const Color(0xFF1A2B44) : const Color(0xFFF8FAFC);

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
      if (assignId != null) {
        allAssignIds.add(assignId);
      }

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

      // Strictly sort Fattening first, Sow/Breeding second, then by hog_id ascending
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
          _isLoadingHogs = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching hogs for batch detail view: $e');
      if (mounted) {
        setState(() => _isLoadingHogs = false);
      }
    }
  }

  static String _resolveStageName(dynamic stageVal, bool isBreeding) {
    final fatteningStages = const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Finisher', 'Selling'];
    final sowStages = const ['Booster', 'Pre-Starter', 'Starter', 'Grower', 'Breeder', 'Lactation'];
    final list = isBreeding ? sowStages : fatteningStages;

    final id = int.tryParse(stageVal?.toString() ?? '');
    if (id != null && id >= 1 && id <= list.length) {
      return list[id - 1];
    }
    final s = stageVal?.toString().trim() ?? '';
    if (s.isNotEmpty && s != 'null' && s != 'N/A' && int.tryParse(s) == null) {
      return s;
    }
    return 'Booster';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final batchName = widget.batch['batch_name']?.toString() ?? 'Batch Details';
    final raiserName = widget.batch['raiser_name']?.toString() ?? 'Unassigned';
    final dateCreated = widget.batch['date_created']?.toString().split('T').first ?? 'N/A';
    final status = widget.batch['status']?.toString().toUpperCase() ?? 'ACTIVE';

    final sUpper = status.toUpperCase().trim();
    final bool isFinished = sUpper == 'FINISHED' || sUpper == 'COMPLETED';
    final bool isActive = sUpper == 'ACTIVE';

    final Color badgeColor = isActive
        ? const Color(0xFF10B981)
        : (isFinished ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8));

    final totalHeads = _hogs.length;
    final fatteningHeads = _hogs.where((h) {
      final t = (h['pig_type'] ?? '').toString().toLowerCase();
      return !t.contains('sow') && !t.contains('breed');
    }).length;
    final sowHeads = _hogs.where((h) {
      final t = (h['pig_type'] ?? '').toString().toLowerCase();
      return t.contains('sow') || t.contains('breed');
    }).length;

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
                          color: (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        batchName,
                        style: GoogleFonts.plusJakartaSans(
                          color: _titleColor,
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              status,
                              style: GoogleFonts.plusJakartaSans(
                                color: badgeColor,
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
                    'Full livestock allocation, assigned hog raiser, and active stage telemetry.',
                    style: GoogleFonts.plusJakartaSans(
                      color: _mutedColor,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(
                'Back to Batches',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                foregroundColor: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Key Metrics Summary Cards
        isMobile
            ? Column(
                children: [
                  _buildMetricCard('Assigned Raiser', raiserName, Icons.person_outline_rounded, const Color(0xFF3B82F6)),
                  const SizedBox(height: 10),
                  _buildMetricCard('Total Active Heads', _isLoadingHogs ? '...' : '$totalHeads heads ($fatteningHeads Fattening, $sowHeads Sow)', Icons.pets_outlined, const Color(0xFF10B981)),
                  const SizedBox(height: 10),
                  _buildMetricCard('Created Date', dateCreated, Icons.calendar_today_outlined, const Color(0xFFF59E0B)),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _buildMetricCard('Assigned Raiser', raiserName, Icons.person_outline_rounded, const Color(0xFF3B82F6)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMetricCard('Total Active Heads', _isLoadingHogs ? '...' : '$totalHeads heads ($fatteningHeads Fattening, $sowHeads Sow)', Icons.pets_outlined, const Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMetricCard('Date Created', dateCreated, Icons.calendar_today_outlined, const Color(0xFFF59E0B)),
                  ),
                ],
              ),
        const SizedBox(height: 22),

        // Hogs Breakdown Section
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorder),
          ),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LIVESTOCK HEADS IN BATCH',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: _mutedColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (!_isLoadingHogs)
                    Text(
                      '$totalHeads total heads allocated',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _mutedColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoadingHogs)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else if (_hogs.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        Icon(Icons.pets_outlined, size: 36, color: _mutedColor),
                        const SizedBox(height: 10),
                        Text(
                          'No Hogs Currently Seeded',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hogs will be seeded when capital investment is assigned.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: _mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _hogs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final hog = _hogs[index];
                    final hogNumber = index + 1;
                    final rawType = (hog['pig_type'] ?? '').toString();
                    final isBreed = rawType.toLowerCase().contains('sow') || rawType.toLowerCase().contains('breed');
                    final stageName = _resolveStageName(hog['stage_id'] ?? hog['lifecycle_stage'], isBreed);
                    final health = (hog['health_status'] ?? 'Healthy').toString();

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorder.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.tag_rounded, size: 16, color: _titleColor),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hog $hogNumber',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _titleColor,
                                    ),
                                  ),
                                  Text(
                                    isBreed ? 'Sow / Breeding' : 'Fattening',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: _mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  stageName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  health,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        if (widget.onEdit != null) ...[
          const SizedBox(height: 24),
          // Action Buttons Row (Right-Aligned, Edit Batch only)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onEdit!(widget.batch),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Batch'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                  side: BorderSide(color: _isDark ? Colors.white38 : PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _mutedColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                  ),
                  maxLines: 1,
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
