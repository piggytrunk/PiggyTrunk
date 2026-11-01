import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/investment_model.dart';
import '../../theme/app_theme.dart';

class InvestmentDrawer {
  static void show({
    required BuildContext context,
    Investment? existingInvestment,
    required VoidCallback onSaved,
    required void Function(String msg, {bool isError}) onShowSnackBar,
  }) async {
    final supabase = Supabase.instance.client;
    final isEdit = existingInvestment != null;

    final capitalCtrl = TextEditingController(text: isEdit ? existingInvestment.initialCapital.toInt().toString() : '');
    final totalHogCtrl = TextEditingController(text: isEdit ? existingInvestment.totalHog.toString() : '');

    String? selectedRaiserId = isEdit
        ? (existingInvestment.hogRaiserId.isEmpty ? 'unassigned' : existingInvestment.hogRaiserId)
        : 'unassigned';

    List<String> selectedHogTypes = ['Fattening'];
    if (isEdit && existingInvestment.hogType.isNotEmpty) {
      final types = existingInvestment.hogType
          .split(RegExp(r'[,;]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => s.toLowerCase().contains('sow') || s.toLowerCase().contains('breed') ? 'Sow / Breeding' : 'Fattening')
          .toSet()
          .toList();
      if (types.isNotEmpty) selectedHogTypes = types;
    }

    String? selectedBatchId = 'unassigned';
    List<Map<String, dynamic>> activeBatches = [];
    List<Map<String, dynamic>> activeRaisers = [];

    // Fetch batches and raisers
    try {
      // 1. Fetch authorized active/approved raisers
      List<dynamic> raisersRaw = [];
      try {
        raisersRaw = await supabase
            .from('hog_raisers')
            .select('hog_raiser_id, name, pig_type, status, account_status, app_users!hog_raisers_user_id_fkey(name, email)')
            .order('hog_raiser_id', ascending: false);
      } catch (rErr) {
        debugPrint('Notice loading raisers in drawer: $rErr. Falling back to plain hog_raisers...');
        try {
          raisersRaw = await supabase
              .from('hog_raisers')
              .select('hog_raiser_id, name, pig_type, status, account_status')
              .order('hog_raiser_id', ascending: false);
        } catch (rErr2) {
          debugPrint('Error fetching raisers fallback in drawer: $rErr2');
        }
      }

      final Map<String, Map<String, dynamic>> raisersMap = {};
      final List<Map<String, dynamic>> parsedRaisers = [];

      for (var r in raisersRaw) {
        if (r is! Map) continue;
        final rMap = Map<String, dynamic>.from(r);
        final accStatus = (rMap['account_status'] ?? '').toString().toLowerCase();
        if (accStatus == 'rejected' || accStatus == 'pending') continue;

        dynamic appUsersRaw = rMap['app_users'];
        Map<String, dynamic>? appUsers;
        if (appUsersRaw is Map) {
          appUsers = Map<String, dynamic>.from(appUsersRaw);
        } else if (appUsersRaw is List && appUsersRaw.isNotEmpty && appUsersRaw.first is Map) {
          appUsers = Map<String, dynamic>.from(appUsersRaw.first);
        }

        final googleOrAppName = (appUsers?['name'] ?? '').toString().trim();
        final raiserName = (rMap['name'] ?? '').toString().trim();
        final resolvedFullName = (raiserName.isNotEmpty &&
                raiserName.toLowerCase() != 'hog raiser' &&
                raiserName.toUpperCase() != 'N/A')
            ? raiserName
            : (googleOrAppName.isNotEmpty && googleOrAppName.toLowerCase() != 'hog raiser'
                ? googleOrAppName
                : (raiserName.isNotEmpty ? raiserName : 'Hog Raiser'));

        final idStr = (rMap['hog_raiser_id'] ?? rMap['id'] ?? '').toString();
        if (idStr.isEmpty) continue;

        final raiserEntry = {
          'id': idStr,
          'name': resolvedFullName,
          'pig_type': rMap['pig_type'] ?? 'Fattening',
          'real_pk_col': 'hog_raiser_id',
        };
        parsedRaisers.add(raiserEntry);
        raisersMap[idStr] = raiserEntry;
      }

      activeRaisers = [
        {'id': 'unassigned', 'name': 'Unassigned (General Pool)'},
        ...parsedRaisers,
      ];

      // 2. Fetch Batches
      List<dynamic> batchesRaw = [];
      try {
        batchesRaw = await supabase.from('batches').select('*').order('batch_id', ascending: false);
      } catch (bErr) {
        debugPrint('Error fetching batches in drawer: $bErr');
        try {
          batchesRaw = await supabase.from('batches').select('*');
        } catch (_) {}
      }

      // 3. Fetch Assignments
      List<dynamic> assignmentsRaw = [];
      try {
        assignmentsRaw = await supabase.from('assignments').select('*');
      } catch (aErr) {
        debugPrint('Error fetching assignments in drawer: $aErr');
      }

      // 4. Fetch Hogs (to calculate hog count per batch / assignment)
      List<dynamic> hogsRaw = [];
      try {
        hogsRaw = await supabase.from('hogs').select('*');
      } catch (hErr) {
        debugPrint('Error fetching hogs in drawer: $hErr');
      }

      final Map<String, int> assignmentHogCounts = {};
      for (var h in hogsRaw) {
        if (h is! Map) continue;
        final assignId = (h['assignment_id'] ?? h['id'])?.toString() ?? '';
        if (assignId.isNotEmpty) {
          assignmentHogCounts[assignId] = (assignmentHogCounts[assignId] ?? 0) + 1;
        }
      }

      final List<Map<String, dynamic>> parsedBatches = [];
      for (var b in batchesRaw) {
        if (b is! Map) continue;
        final bMap = Map<String, dynamic>.from(b);
        final bId = (bMap['batch_id'] ?? bMap['id'] ?? bMap['batch_number'] ?? bMap['batch_code'])?.toString() ?? '';
        if (bId.isEmpty) continue;
        final bName = bMap['batch_name']?.toString() ?? bMap['name']?.toString() ?? 'Batch $bId';

        Map<String, dynamic>? matchingAssign;
        for (var a in assignmentsRaw) {
          if (a is Map && (a['batch_id']?.toString() == bId || a['id']?.toString() == bId)) {
            if ((a['status'] ?? '').toString().toLowerCase() == 'active') {
              matchingAssign = Map<String, dynamic>.from(a);
              break;
            }
            matchingAssign ??= Map<String, dynamic>.from(a);
          }
        }

        String raiserId = '';
        String raiserName = 'Unassigned';
        String pigType = 'Fattening';
        int hogCount = 0;

        if (matchingAssign != null) {
          final assignId = (matchingAssign['assignment_id'] ?? matchingAssign['id'])?.toString() ?? '';
          hogCount = assignmentHogCounts[assignId] ?? 0;

          raiserId = (matchingAssign['hog_raiser_id'] ?? '').toString();

          if (raisersMap.containsKey(raiserId)) {
            raiserName = raisersMap[raiserId]!['name'] ?? 'Hog Raiser';
            pigType = raisersMap[raiserId]!['pig_type'] ?? 'Fattening';
          }
        }

        parsedBatches.add({
          'batch_id': bId,
          'batch_name': bName,
          'display_label': bName,
          'raiser_id': raiserId,
          'raiser_name': raiserName,
          'pig_type': pigType,
          'hog_count': hogCount,
        });
      }

      parsedRaisers.sort((a, b) {
        final idA = int.tryParse(a['id'].toString()) ?? 0;
        final idB = int.tryParse(b['id'].toString()) ?? 0;
        return idB.compareTo(idA);
      });

      parsedBatches.sort((a, b) {
        final idA = int.tryParse(a['batch_id'].toString()) ?? 0;
        final idB = int.tryParse(b['batch_id'].toString()) ?? 0;
        return idB.compareTo(idA);
      });

      activeBatches = [
        {
          'batch_id': 'unassigned',
          'batch_name': 'No Specific Batch (General Fund)',
          'display_label': 'General Fund (No Batch)',
          'raiser_id': '',
          'raiser_name': 'Unassigned',
          'pig_type': 'Fattening',
          'hog_count': 0,
        },
        ...parsedBatches,
      ];

      if (!isEdit) {
        selectedBatchId = activeBatches.length > 1 ? activeBatches[1]['batch_id'] : 'unassigned';
        if (selectedBatchId != null && selectedBatchId != 'unassigned') {
          final matched = activeBatches.firstWhere((b) => b['batch_id'] == selectedBatchId, orElse: () => {});
          final rId = (matched['raiser_id'] ?? '').toString();
          if (rId.isNotEmpty && activeRaisers.any((r) => r['id'] == rId)) {
            selectedRaiserId = rId;
          }
          final pt = (matched['pig_type'] ?? 'Fattening').toString();
          if (pt.isNotEmpty) {
            final parsed = pt.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).map((s) => s.toLowerCase().contains('sow') ? 'Sow / Breeding' : 'Fattening').toSet().toList();
            if (parsed.isNotEmpty) selectedHogTypes = parsed;
          }
        }
      }
    } catch (e) {
      debugPrint('Error in investment drawer _fetchDropdownData: $e');
    }

    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final fieldBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
    final fieldBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFC9D8EC);
    final fieldFocus = isDark ? const Color(0xFF88A7CE) : const Color(0xFF315C8F);
    final fieldText = isDark ? Colors.white : const Color(0xFF18314F);
    final hintText = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);

    String? capitalError;
    String? totalHogError;
    bool isDrawerSaving = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Investment Drawer',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        final curvedAnimation = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final isMobile = screenWidth < 600;
        final drawerWidth = isMobile ? screenWidth : 460.0;

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
                width: drawerWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(left: BorderSide(color: cardBorder, width: 1.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                      blurRadius: 32,
                      offset: const Offset(-6, 0),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: StatefulBuilder(
                    builder: (context, setDrawerState) {
                      return Column(
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: isDark ? 0.08 : 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isEdit ? Icons.edit_note_rounded : Icons.account_balance_wallet_rounded,
                                    color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEdit ? 'Edit Investment' : 'Add New Investment',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: titleColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isEdit ? 'Update investment details and capital' : 'Assign capital to an active farm batch',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: hintText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

                          // Body
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Batch Selector
                                  Text(
                                    'SELECT BATCH TO FUND *',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: hintText,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('drawer_batch_dropdown_${selectedBatchId}_${activeBatches.length}'),
                                    initialValue: activeBatches.any((b) => b['batch_id'] == selectedBatchId)
                                        ? selectedBatchId
                                        : (activeBatches.isNotEmpty ? activeBatches.first['batch_id'] : null),
                                    isExpanded: true,
                                    hint: Text(
                                      'Select a batch to fund',
                                      style: GoogleFonts.plusJakartaSans(color: hintText, fontSize: 13.5, fontWeight: FontWeight.w500),
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: fieldBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: fieldBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: fieldFocus, width: 1.5),
                                      ),
                                    ),
                                    dropdownColor: fieldBg,
                                    style: GoogleFonts.plusJakartaSans(color: fieldText, fontSize: 13.5, fontWeight: FontWeight.w600),
                                    items: activeBatches.map((b) {
                                      final isUnassigned = b['batch_id'] == 'unassigned';
                                      return DropdownMenuItem<String>(
                                        value: b['batch_id'].toString(),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isUnassigned ? Icons.layers_clear_outlined : Icons.layers_outlined,
                                              size: 16,
                                              color: isUnassigned ? hintText : (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                b['display_label'].toString(),
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: isUnassigned ? hintText : fieldText,
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setDrawerState(() {
                                        selectedBatchId = val;
                                        if (val != 'unassigned') {
                                          final matched = activeBatches.firstWhere((b) => b['batch_id'] == val, orElse: () => {});
                                          selectedRaiserId = (matched['raiser_id'] ?? '').toString();
                                          final pt = (matched['pig_type'] ?? 'Fattening').toString();
                                          if (pt.isNotEmpty) {
                                            final parsed = pt.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).map((s) => s.toLowerCase().contains('sow') ? 'Sow / Breeding' : 'Fattening').toSet().toList();
                                            if (parsed.isNotEmpty) selectedHogTypes = parsed;
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 18),

                                  // Capital
                                  Text(
                                    'INITIAL CAPITAL (PHP) *',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: hintText,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: capitalCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (_) {
                                      if (capitalError != null) setDrawerState(() => capitalError = null);
                                    },
                                    style: GoogleFonts.plusJakartaSans(color: fieldText, fontSize: 14, fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      hintStyle: GoogleFonts.plusJakartaSans(color: hintText, fontSize: 14),
                                      prefixIcon: Container(
                                        width: 40,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '₱',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: hintText,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: fieldBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: capitalError != null ? const Color(0xFFE53E3E) : fieldBorder,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: capitalError != null ? const Color(0xFFE53E3E) : fieldFocus,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (capitalError != null) ...[
                                    const SizedBox(height: 4),
                                    Text(capitalError!, style: const TextStyle(color: Color(0xFFE53E3E), fontSize: 11.5)),
                                  ],
                                  const SizedBox(height: 18),

                                  // Total Heads
                                  Text(
                                    'TOTAL HEADS *',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: hintText,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: totalHogCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (_) {
                                      if (totalHogError != null) setDrawerState(() => totalHogError = null);
                                    },
                                    style: GoogleFonts.plusJakartaSans(color: fieldText, fontSize: 14, fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: GoogleFonts.plusJakartaSans(color: hintText, fontSize: 14),
                                      filled: true,
                                      fillColor: fieldBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: totalHogError != null ? const Color(0xFFE53E3E) : fieldBorder,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: totalHogError != null ? const Color(0xFFE53E3E) : fieldFocus,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (totalHogError != null) ...[
                                    const SizedBox(height: 4),
                                    Text(totalHogError!, style: const TextStyle(color: Color(0xFFE53E3E), fontSize: 11.5)),
                                  ],
                                  const SizedBox(height: 18),

                                  // Hog Types (Stacked vertically for clean UI)
                                  Text(
                                    'HOG TYPE *',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: hintText,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _buildCheckboxOption(
                                            title: 'Fattening',
                                            isSelected: selectedHogTypes.contains('Fattening'),
                                            isDark: isDark,
                                            onToggle: () {
                                              setDrawerState(() {
                                                if (selectedHogTypes.contains('Fattening')) {
                                                  if (selectedHogTypes.length > 1) selectedHogTypes.remove('Fattening');
                                                } else {
                                                  selectedHogTypes.add('Fattening');
                                                }
                                              });
                                            },
                                          ),
                                          const SizedBox(width: 16),
                                          _buildCheckboxOption(
                                            title: 'Sow / Breeding',
                                            isSelected: selectedHogTypes.contains('Sow / Breeding'),
                                            isDark: isDark,
                                            onToggle: () {
                                              setDrawerState(() {
                                                if (selectedHogTypes.contains('Sow / Breeding')) {
                                                  if (selectedHogTypes.length > 1) selectedHogTypes.remove('Sow / Breeding');
                                                } else {
                                                  selectedHogTypes.add('Sow / Breeding');
                                                }
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Footer Actions
                          Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isDrawerSaving ? null : () => Navigator.pop(dialogContext),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: BorderSide(color: fieldBorder),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: fieldText,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: isDrawerSaving
                                        ? null
                                        : () async {
                                            final parsedCapital = int.tryParse(capitalCtrl.text.trim());
                                            final parsedTotalHog = int.tryParse(totalHogCtrl.text.trim());

                                            if (parsedCapital == null || parsedCapital <= 0) {
                                              setDrawerState(() => capitalError = 'Please enter a valid capital greater than ₱0.');
                                              return;
                                            }
                                            if (parsedTotalHog == null || parsedTotalHog <= 0) {
                                              setDrawerState(() => totalHogError = 'Please enter total number of heads (min 1).');
                                              return;
                                            }

                                            setDrawerState(() => isDrawerSaving = true);
                                            try {
                                              final isUnassigned = selectedRaiserId == 'unassigned' || selectedRaiserId!.isEmpty;
                                              final raiserName = isUnassigned
                                                  ? 'Unassigned'
                                                  : (activeRaisers.firstWhere(
                                                      (r) => r['id'].toString() == selectedRaiserId,
                                                      orElse: () => {'name': ''},
                                                    )['name'] ?? 'Unassigned');

                                                final cleanTypes = selectedHogTypes
                                                    .map((s) => s.toLowerCase().contains('sow') || s.toLowerCase().contains('breed') ? 'Sow' : 'Fattening')
                                                    .toSet()
                                                    .toList();
                                                final hogTypeStr = cleanTypes.isNotEmpty ? cleanTypes.join(', ') : 'Fattening';
                                              final payload = {
                                                'hog_raiser_id': isUnassigned ? '' : selectedRaiserId,
                                                'raiser_name': raiserName,
                                                'initial_capital': parsedCapital,
                                                'hog_type': hogTypeStr,
                                                'total_hog': parsedTotalHog,
                                                'investment_date': isEdit ? existingInvestment.investmentDate.toIso8601String() : DateTime.now().toIso8601String(),
                                                if (!isEdit) 'stage': 'active',
                                              };

                                              try {
                                                if (isEdit) {
                                                  await supabase.from('investment_records').update(payload).eq('id', existingInvestment.id);
                                                } else {
                                                  await supabase.from('investment_records').insert(payload);
                                                }
                                              } catch (dbErr) {
                                                final errStr = dbErr.toString().toLowerCase();
                                                if (errStr.contains('batch_id') || errStr.contains('batch_name') || errStr.contains('pgrst204')) {
                                                  final fallbackPayload = Map<String, dynamic>.from(payload)
                                                    ..remove('batch_id')
                                                    ..remove('batch_name');
                                                  if (isEdit) {
                                                    await supabase.from('investment_records').update(fallbackPayload).eq('id', existingInvestment.id);
                                                  } else {
                                                    await supabase.from('investment_records').insert(fallbackPayload);
                                                  }
                                                } else {
                                                  rethrow;
                                                }
                                              }

                                              if (!isUnassigned && int.tryParse(selectedRaiserId!) != null) {
                                                final parsedRaiserId = int.parse(selectedRaiserId!);
                                                final raiserRow = activeRaisers.firstWhere(
                                                  (r) => r['id'].toString() == selectedRaiserId,
                                                  orElse: () => {},
                                                );
                                                final pkCol = raiserRow['real_pk_col'] ?? (raiserRow['id'] != null ? 'id' : 'hog_raiser_id');
                                                final isSow = hogTypeStr.toLowerCase().contains('sow') || hogTypeStr.toLowerCase().contains('breed');
                                                String currentType = '';
                                                try {
                                                  final cur = await supabase.from('hog_raisers').select('pig_type').eq(pkCol, parsedRaiserId).maybeSingle();
                                                  currentType = (cur?['pig_type'] ?? '').toString().toLowerCase();
                                                } catch (_) {}
                                                final hadType = currentType.isNotEmpty && currentType != 'none' && currentType != 'n/a';
                                                final hasSow = isSow || currentType.contains('sow') || currentType.contains('breed');
                                                final hasFattening = !isSow || currentType.contains('fatten');
                                                await supabase
                                                    .from('hog_raisers')
                                                    .update({
                                                      if (!hadType) 'lifecycle_stage': isSow ? 'Gilt' : 'Booster',
                                                      'pig_type': hasSow && hasFattening ? 'Sow and Fattening' : (hasSow ? 'Sow' : 'Fattening'),
                                                    })
                                                    .eq(pkCol, parsedRaiserId);
                                              }

                                              if (!dialogContext.mounted) return;
                                              Navigator.pop(dialogContext);
                                              onSaved();
                                              onShowSnackBar(isEdit ? 'Investment updated successfully.' : 'Investment created successfully.');
                                            } catch (e) {
                                              setDrawerState(() => isDrawerSaving = false);
                                              onShowSnackBar('Operation failed: $e', isError: true);
                                            }
                                          },
                                    icon: isDrawerSaving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                                    label: Text(
                                      isDrawerSaving ? 'Saving...' : (isEdit ? 'Save Changes' : 'Save Investment'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                      foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildCheckboxOption({
    required String title,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onToggle,
  }) {
    final activeColor = isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;
    final checkColor = isDark ? const Color(0xFF132238) : Colors.white;
    final inactiveBorder = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: isSelected ? activeColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? activeColor : inactiveBorder,
                  width: 1.8,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: checkColor,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF18314F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
