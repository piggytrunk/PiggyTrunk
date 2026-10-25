import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/investment_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../common/searchable_dropdown_field.dart';
import '../common/shimmer_loading.dart';

class InvestmentFormView extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onSaved;
  final Investment? existingInvestment;
  final void Function(String msg, {bool isError}) onShowSnackBar;

  const InvestmentFormView({
    super.key,
    required this.onCancel,
    required this.onSaved,
    this.existingInvestment,
    required this.onShowSnackBar,
  });

  @override
  State<InvestmentFormView> createState() => _InvestmentFormViewState();
}

class _InvestmentFormViewState extends State<InvestmentFormView> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late final TextEditingController _capitalCtrl;
  late final TextEditingController _totalHogCtrl;
  late final TextEditingController _fatteningCountCtrl;
  late final TextEditingController _sowCountCtrl;

  String? _selectedRaiserId;
  String? _selectedBatchId;
  bool _isFatteningSelected = true;
  bool _isSowSelected = false;

  List<Map<String, dynamic>> _activeBatches = [];
  List<Map<String, dynamic>> _activeRaisers = [];
  bool _isLoadingData = true;
  bool _isSubmitting = false;

  String? _capitalError;
  String? _totalHogError;

  bool get _isEdit => widget.existingInvestment != null;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _panelStart => _isDark ? const Color(0xFF1A2940) : Colors.white;
  Color get _panelEnd => _isDark ? const Color(0xFF0F1C2F) : Colors.white;
  Color get _panelBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);
  Color get _cardBg => _isDark ? const Color(0xFF132238) : Colors.white;
  Color get _cardBorder => _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _mutedColor => _isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
  Color get _fieldBg => _isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
  Color get _fieldText => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _fieldBorder => _isDark ? const Color(0xFF28405D) : const Color(0xFFC9D8EC);
  Color get _fieldFocus => _isDark ? const Color(0xFF88A7CE) : const Color(0xFF315C8F);

  int get _fatteningCount => _isFatteningSelected ? (int.tryParse(_fatteningCountCtrl.text.trim()) ?? 0) : 0;
  int get _sowCount => _isSowSelected ? (int.tryParse(_sowCountCtrl.text.trim()) ?? 0) : 0;
  int get _calculatedTotalHogs => _fatteningCount + _sowCount;

  String get _breakdownSummaryText {
    final f = _fatteningCount;
    final s = _sowCount;
    if (f > 0 && s > 0) {
      return '$f Fattening + $s Sow / Breeding';
    } else if (f > 0) {
      return '$f Fattening';
    } else if (s > 0) {
      return '$s Sow / Breeding';
    }
    return '';
  }

  void _syncTotalHogCtrl() {
    final total = _calculatedTotalHogs;
    _totalHogCtrl.text = total > 0 ? total.toString() : '';
    if (_totalHogError != null && total > 0) {
      _totalHogError = null;
    }
  }

  void _incrementFattening([int amount = 1]) {
    final cur = int.tryParse(_fatteningCountCtrl.text.trim()) ?? 0;
    setState(() {
      _fatteningCountCtrl.text = (cur + amount).toString();
      _isFatteningSelected = true;
      _syncTotalHogCtrl();
    });
  }

  void _decrementFattening([int amount = 1]) {
    final cur = int.tryParse(_fatteningCountCtrl.text.trim()) ?? 0;
    if (cur > 0) {
      final newVal = (cur - amount).clamp(0, 99999);
      setState(() {
        _fatteningCountCtrl.text = newVal.toString();
        _syncTotalHogCtrl();
      });
    }
  }

  void _incrementSow([int amount = 1]) {
    final cur = int.tryParse(_sowCountCtrl.text.trim()) ?? 0;
    setState(() {
      _sowCountCtrl.text = (cur + amount).toString();
      _isSowSelected = true;
      _syncTotalHogCtrl();
    });
  }

  void _decrementSow([int amount = 1]) {
    final cur = int.tryParse(_sowCountCtrl.text.trim()) ?? 0;
    if (cur > 0) {
      final newVal = (cur - amount).clamp(0, 99999);
      setState(() {
        _sowCountCtrl.text = newVal.toString();
        _syncTotalHogCtrl();
      });
    }
  }

  void _toggleFattening() {
    setState(() {
      _isFatteningSelected = !_isFatteningSelected;
      if (!_isFatteningSelected) {
        _fatteningCountCtrl.text = '0';
      }
      _syncTotalHogCtrl();
    });
  }

  void _toggleSow() {
    setState(() {
      _isSowSelected = !_isSowSelected;
      if (!_isSowSelected) {
        _sowCountCtrl.text = '0';
      }
      _syncTotalHogCtrl();
    });
  }

  @override
  void initState() {
    super.initState();
    final initialCapitalVal = widget.existingInvestment?.initialCapital.toInt() ?? 0;
    final initialCapitalStr = initialCapitalVal > 0
        ? initialCapitalVal.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )
        : '';
    _capitalCtrl = TextEditingController(
      text: _isEdit ? initialCapitalStr : '',
    );
    _totalHogCtrl = TextEditingController(
      text: _isEdit ? widget.existingInvestment!.totalHog.toString() : '',
    );

    final existingTotal = widget.existingInvestment?.totalHog ?? 0;
    final existingType = (widget.existingInvestment?.hogType ?? '').toLowerCase();
    final bool hasExistingSow = existingType.contains('sow') || existingType.contains('breed');
    final bool hasExistingFattening = existingType.contains('fatten') || !hasExistingSow;

    if (_isEdit) {
      _isFatteningSelected = hasExistingFattening;
      _isSowSelected = hasExistingSow;
      if (hasExistingSow && hasExistingFattening) {
        final int fCount = (existingTotal / 2).ceil();
        final int sCount = existingTotal - fCount;
        _fatteningCountCtrl = TextEditingController(text: fCount.toString());
        _sowCountCtrl = TextEditingController(text: sCount.toString());
      } else if (hasExistingSow) {
        _fatteningCountCtrl = TextEditingController(text: '0');
        _sowCountCtrl = TextEditingController(text: existingTotal.toString());
      } else {
        _fatteningCountCtrl = TextEditingController(text: existingTotal.toString());
        _sowCountCtrl = TextEditingController(text: '0');
      }
    } else {
      _isFatteningSelected = true;
      _isSowSelected = false;
      _fatteningCountCtrl = TextEditingController(text: '0');
      _sowCountCtrl = TextEditingController(text: '0');
    }

    _selectedRaiserId = _isEdit
        ? (widget.existingInvestment!.hogRaiserId.isEmpty
            ? 'unassigned'
            : widget.existingInvestment!.hogRaiserId)
        : 'unassigned';

    _selectedBatchId = _isEdit
        ? (widget.existingInvestment!.batchId != null && widget.existingInvestment!.batchId!.isNotEmpty
            ? widget.existingInvestment!.batchId!
            : 'unassigned')
        : 'unassigned';

    _fetchDropdownData();
  }

  @override
  void dispose() {
    _capitalCtrl.dispose();
    _totalHogCtrl.dispose();
    _fatteningCountCtrl.dispose();
    _sowCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    try {
      // 1. Fetch Batches (ordered newest first)
      List<dynamic> batchesRaw = [];
      try {
        batchesRaw = await _supabase
            .from('batches')
            .select('*')
            .order('batch_id', ascending: false);
      } catch (bErr) {
        debugPrint('Error fetching batches with order: $bErr');
        try {
          batchesRaw = await _supabase.from('batches').select('*');
        } catch (_) {}
      }

      final Map<String, String> batchNamesMap = {
        for (var b in batchesRaw)
          (b['batch_id'] ?? b['id'] ?? '').toString(): (b['batch_name'] ?? 'Batch #${b['batch_id']}').toString()
      };

      // 2. Fetch Assignments
      List<dynamic> assignmentsRaw = [];
      try {
        assignmentsRaw = await _supabase.from('assignments').select('*');
      } catch (aErr) {
        debugPrint('Error fetching assignments: $aErr');
      }

      // 3. Fetch Hogs (to calculate hog count per batch / assignment)
      List<dynamic> hogsRaw = [];
      try {
        hogsRaw = await _supabase.from('hogs').select('*');
      } catch (hErr) {
        debugPrint('Error fetching hogs: $hErr');
      }

      final Map<String, int> assignmentHogCounts = {};
      for (var h in hogsRaw) {
        if (h is! Map) continue;
        final assignId = (h['assignment_id'] ?? h['id'])?.toString() ?? '';
        if (assignId.isNotEmpty) {
          assignmentHogCounts[assignId] = (assignmentHogCounts[assignId] ?? 0) + 1;
        }
      }

      final Map<String, String> batchStatusMap = {
        for (var b in batchesRaw)
          (b['batch_id'] ?? b['id'] ?? '').toString(): (b['status'] ?? b['batch_status'] ?? 'Active').toString().toLowerCase()
      };

      // Map active raisers to assigned batches (1 is to 1 tracking)
      final Map<String, Map<String, dynamic>> raiserAssignedBatchMap = {};
      for (var a in assignmentsRaw) {
        if (a is! Map) continue;
        final assignId = (a['assignment_id'] ?? a['id'])?.toString() ?? '';
        final rId = (a['hog_raiser_id'] ?? '').toString();
        final bId = (a['batch_id'] ?? '').toString();
        final bName = batchNamesMap[bId] ?? 'Batch #$bId';
        final bStatus = batchStatusMap[bId] ?? 'active';
        final st = (a['status'] ?? 'active').toString().toLowerCase();

        // Check if batch itself is explicitly completed or archived
        final bool isBatchCompleted = bStatus == 'completed' || bStatus == 'archived' || bStatus == 'harvested' || bStatus == 'sold';
        final bool isAssignCompleted = st == 'completed' || st == 'archived' || st == 'finished';

        // Check if all hogs of this assignment reached terminal stage (sow in lactation, fattening in selling/sold)
        final assignHogs = hogsRaw.where((h) {
          if (h is! Map) return false;
          final hAssignId = (h['assignment_id'] ?? '').toString();
          final hBatchId = (h['batch_id'] ?? '').toString();
          final hRaiserId = (h['hog_raiser_id'] ?? '').toString();
          return (assignId.isNotEmpty && hAssignId == assignId) ||
                 (bId.isNotEmpty && hBatchId == bId) ||
                 (rId.isNotEmpty && hRaiserId == rId);
        }).toList();

        bool allHogsCycleDone = false;
        if (assignHogs.isNotEmpty) {
          final htStr = (a['hog_types']?['type_name'] ?? a['pig_type'] ?? '').toString().toLowerCase();
          final isSow = htStr.contains('sow') || htStr.contains('breed');
          allHogsCycleDone = assignHogs.every((h) {
            final s = (h['stage_id'] ?? h['lifecycle_stage'] ?? h['stage'] ?? '').toString().trim().toLowerCase();
            return isSow ? (s == 'lactation' || s == '6' || s.contains('lactat')) : (s == 'selling' || s == 'sold' || s == '6' || s.contains('sell'));
          });
        }

        final bool isCycleCompleted = isBatchCompleted || isAssignCompleted || allHogsCycleDone;

        if (rId.isNotEmpty && bId.isNotEmpty) {
          final existing = raiserAssignedBatchMap[rId];
          if (existing == null || (existing['is_completed'] == true && !isCycleCompleted)) {
            raiserAssignedBatchMap[rId] = {
              'batch_id': bId,
              'batch_name': bName,
              'is_completed': isCycleCompleted,
              'status': st,
            };
          }
        }
      }

      // 4. Fetch authorized active/approved raisers (ordered newest first by hog_raiser_id)
      List<dynamic> raisersRaw = [];
      try {
        raisersRaw = await _supabase
            .from('hog_raisers')
            .select('hog_raiser_id, name, pig_type, status, account_status, app_users!hog_raisers_user_id_fkey(name, email)')
            .order('hog_raiser_id', ascending: false);
      } catch (rErr) {
        debugPrint('Notice loading raisers with app_users relation: $rErr. Retrying basic...');
        try {
          raisersRaw = await _supabase
              .from('hog_raisers')
              .select('hog_raiser_id, name, pig_type, status, account_status')
              .order('hog_raiser_id', ascending: false);
        } catch (rErr2) {
          debugPrint('Error fetching raisers fallback: $rErr2');
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

        final assignedInfo = raiserAssignedBatchMap[idStr];
        final assignedBatchId = assignedInfo?['batch_id']?.toString();
        final assignedBatchName = assignedInfo?['batch_name']?.toString();
        final rStage = (rMap['lifecycle_stage'] ?? rMap['current_stage'] ?? '').toString().toLowerCase();
        final isRaiserStageCompleted = rStage.contains('lactat') || rStage.contains('sell') || rStage == 'completed';
        final isBatchCompleted = (assignedInfo?['is_completed'] == true) || isRaiserStageCompleted;

        final raiserEntry = {
          'id': idStr,
          'name': resolvedFullName,
          'pig_type': rMap['pig_type'] ?? 'Fattening',
          'phone': rMap['phone'] ?? 'N/A',
          'assigned_batch_id': assignedBatchId,
          'assigned_batch_name': assignedBatchName,
          'is_batch_completed': isBatchCompleted,
          'real_pk_col': 'hog_raiser_id',
        };
        parsedRaisers.add(raiserEntry);
        raisersMap[idStr] = raiserEntry;
      }

      // Fetch hog types mapping
      final Map<String, String> hogTypeNamesMap = {};
      try {
        final List<dynamic> typesRes = await _supabase.from('hog_types').select('hog_type_id, type_name');
        for (var t in typesRes) {
          if (t is Map && t['hog_type_id'] != null) {
            hogTypeNamesMap[t['hog_type_id'].toString()] = (t['type_name'] ?? '').toString();
          }
        }
      } catch (_) {}

      final List<Map<String, dynamic>> parsedBatches = [];
      for (var b in batchesRaw) {
        if (b is! Map) continue;
        final bMap = Map<String, dynamic>.from(b);
        final bId = (bMap['batch_id'] ?? bMap['id'] ?? bMap['batch_number'] ?? bMap['batch_code'])?.toString() ?? '';
        if (bId.isEmpty) continue;
        final bName = bMap['batch_name']?.toString() ?? bMap['name']?.toString() ?? 'Batch $bId';
        final bStatus = (bMap['status'] ?? bMap['batch_status'] ?? 'Active').toString().toLowerCase();
        final bool isBatchFinished = bStatus == 'finished' || bStatus == 'completed' || bStatus == 'archived';
        if (!_isEdit && isBatchFinished) {
          continue; // Finished batches cannot accept new investments
        }

        final batchAssigns = assignmentsRaw.where((a) => a is Map && (a['batch_id']?.toString() == bId || a['id']?.toString() == bId)).toList();

        int totalHogsInBatch = 0;
        String raiserId = '';
        String raiserName = 'Unassigned';
        final Set<String> batchTypes = {};

        for (var a in batchAssigns) {
          final assignId = (a['assignment_id'] ?? a['id'])?.toString() ?? '';
          if (assignId.isNotEmpty) {
            totalHogsInBatch += (assignmentHogCounts[assignId] ?? 0);
          }
          final rId = (a['hog_raiser_id'] ?? '').toString();
          if (rId.isNotEmpty && rId != 'unassigned' && raiserId.isEmpty) {
            raiserId = rId;
          }
          final htId = a['hog_type_id']?.toString() ?? '';
          final htName = (hogTypeNamesMap[htId] ?? a['hog_types']?['type_name'] ?? a['pig_type'] ?? '').toString();
          if (htName.isNotEmpty) {
            batchTypes.add(htName.toLowerCase().contains('sow') || htName.toLowerCase().contains('breed') ? 'Sow / Breeding' : 'Fattening');
          }
        }

        if (raiserId.isNotEmpty && raisersMap.containsKey(raiserId)) {
          raiserName = raisersMap[raiserId]!['name'] ?? 'Hog Raiser';
          final rType = (raisersMap[raiserId]!['pig_type'] ?? '').toString();
          if (rType.isNotEmpty && batchTypes.isEmpty) {
            if (rType.toLowerCase().contains('sow')) batchTypes.add('Sow / Breeding');
            if (rType.toLowerCase().contains('fatten')) batchTypes.add('Fattening');
          }
        }

        final pigType = batchTypes.isNotEmpty ? batchTypes.join(', ') : 'Fattening';

        parsedBatches.add({
          'batch_id': bId,
          'batch_name': bName,
          'display_label': bName,
          'raiser_id': raiserId,
          'raiser_name': raiserName,
          'pig_type': pigType,
          'hog_count': totalHogsInBatch,
        });
      }

      // Sort raisers newest first (highest id at top, oldest created at bottom)
      parsedRaisers.sort((a, b) {
        final idA = int.tryParse(a['id'].toString()) ?? 0;
        final idB = int.tryParse(b['id'].toString()) ?? 0;
        return idB.compareTo(idA);
      });

      // Sort batches newest first (highest batch_id at top, oldest at bottom)
      parsedBatches.sort((a, b) {
        final idA = int.tryParse(a['batch_id'].toString()) ?? 0;
        final idB = int.tryParse(b['batch_id'].toString()) ?? 0;
        return idB.compareTo(idA);
      });

      if (_isEdit) {
        if (_selectedBatchId == null || _selectedBatchId == 'unassigned') {
          final bNameFromInv = widget.existingInvestment!.batchName;
          if (bNameFromInv != null && bNameFromInv.isNotEmpty) {
            final match = parsedBatches.firstWhere(
              (b) => b['batch_name'].toString().toLowerCase() == bNameFromInv.toLowerCase(),
              orElse: () => {},
            );
            if (match.isNotEmpty) {
              _selectedBatchId = match['batch_id'].toString();
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _activeRaisers = parsedRaisers;
          _activeBatches = [
            {
              'batch_id': 'unassigned',
              'batch_name': 'No Specific Batch (General Fund)',
              'display_label': 'General Fund (No Batch)',
              'raiser_id': '',
              'raiser_name': 'Unassigned',
              'pig_type': 'Fattening',
              'hog_count': 0,
              'is_assigned_elsewhere': false,
            },
            ...parsedBatches,
          ];
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _fetchDropdownData: $e');
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    final cleanCapitalStr = _capitalCtrl.text.replaceAll(',', '').trim();
    final parsedCapital = int.tryParse(cleanCapitalStr);
    final fatteningCount = _fatteningCount;
    final sowCount = _sowCount;
    final parsedTotalHog = fatteningCount + sowCount;

    if (parsedCapital == null || parsedCapital <= 0) {
      setState(() => _capitalError = 'Please enter a valid capital greater than ₱0.');
      return;
    }
    if (parsedTotalHog <= 0) {
      setState(() => _totalHogError = 'Please allocate at least 1 head across selected hog types.');
      return;
    }

    final isRaiserUnassigned = _selectedRaiserId == 'unassigned' || _selectedRaiserId == null || _selectedRaiserId!.isEmpty;
    final isBatchUnassigned = _selectedBatchId == 'unassigned' || _selectedBatchId == null || _selectedBatchId!.isEmpty;

    // 1-IS-TO-1 STRICT VALIDATION: Batch cannot be assigned to multiple raisers, and Raiser cannot manage multiple active batches
    if (!isBatchUnassigned && !isRaiserUnassigned) {
      final matchedBatch = _activeBatches.firstWhere(
        (b) => b['batch_id'].toString() == _selectedBatchId,
        orElse: () => {},
      );
      final assignedRaiserId = (matchedBatch['raiser_id'] ?? '').toString();
      if (assignedRaiserId.isNotEmpty && assignedRaiserId != 'unassigned' && assignedRaiserId != _selectedRaiserId && !_isEdit) {
        final rName = matchedBatch['raiser_name'] ?? 'another Hog Raiser';
        widget.onShowSnackBar(
          '${matchedBatch['batch_name']} is already assigned to $rName. Each batch can only be assigned to one Hog Raiser.',
          isError: true,
        );
        return;
      }

      final matchedRaiser = _activeRaisers.firstWhere(
        (r) => r['id'].toString() == _selectedRaiserId,
        orElse: () => {},
      );
      final rBatchId = matchedRaiser['assigned_batch_id']?.toString();
      final isDone = matchedRaiser['is_batch_completed'] == true;
      if (rBatchId != null && rBatchId.isNotEmpty && !isDone && rBatchId != _selectedBatchId && !_isEdit) {
        final bName = matchedRaiser['assigned_batch_name'] ?? 'another Batch';
        widget.onShowSnackBar(
          '${matchedRaiser['name']} is already managing $bName. Each Hog Raiser can only manage one active batch at a time.',
          isError: true,
        );
        return;
      }
    }

    setState(() {
      _capitalError = null;
      _totalHogError = null;
      _isSubmitting = true;
    });

    try {
      final raiserName = isRaiserUnassigned
          ? 'Unassigned'
          : (_activeRaisers.firstWhere(
              (r) => r['id'].toString() == _selectedRaiserId,
              orElse: () => {'name': 'Hog Raiser'},
            )['name'] ?? 'Hog Raiser');

      final batchName = isBatchUnassigned
          ? 'Unassigned'
          : (_activeBatches.firstWhere(
              (b) => b['batch_id'].toString() == _selectedBatchId,
              orElse: () => {'batch_name': 'Batch'},
            )['batch_name'] ?? 'Batch');

      final List<String> activeTypes = [];
      if (fatteningCount > 0) activeTypes.add('Fattening');
      if (sowCount > 0) activeTypes.add('Sow');

      final cleanTypes = activeTypes.isNotEmpty
          ? activeTypes
          : [
              if (_isFatteningSelected) 'Fattening',
              if (_isSowSelected) 'Sow',
            ];
      final hogTypeStr = cleanTypes.length > 1
          ? 'Fattening, Sow'
          : (cleanTypes.isNotEmpty ? cleanTypes.first : 'Fattening');

      // Batch-to-raiser validation before saving: ensures 1:1 consistency in database
      if (!isRaiserUnassigned && !isBatchUnassigned && int.tryParse(_selectedRaiserId!) != null) {
        final parsedRaiserId = int.parse(_selectedRaiserId!);
        try {
          final batchAssigns = await _supabase
              .from('assignments')
              .select('assignment_id, hog_raiser_id')
              .eq('batch_id', _selectedBatchId!)
              .or('status.eq.active,status.eq.Active');

          for (final bA in (batchAssigns as List? ?? [])) {
            final assignedRaiserId = bA['hog_raiser_id'];
            if (assignedRaiserId != null && assignedRaiserId != parsedRaiserId && !_isEdit) {
              if (!mounted) return;
              setState(() => _isSubmitting = false);
              widget.onShowSnackBar(
                'This batch is already assigned to another Hog Raiser. Each batch can only be assigned to one Hog Raiser.',
                isError: true,
              );
              return;
            }
          }

          final raiserAssigns = await _supabase
              .from('assignments')
              .select('assignment_id, batch_id')
              .eq('hog_raiser_id', parsedRaiserId)
              .neq('batch_id', _selectedBatchId!)
              .or('status.eq.active,status.eq.Active');

          if ((raiserAssigns as List? ?? []).isNotEmpty && !_isEdit) {
            if (!mounted) return;
            setState(() => _isSubmitting = false);
            widget.onShowSnackBar(
              '$raiserName is already assigned to another active batch. Each Hog Raiser can only manage one active batch at a time.',
              isError: true,
            );
            return;
          }
        } catch (valErr) {
          debugPrint('Notice during batch assignment pre-validation: $valErr');
        }
      }

      final payload = <String, dynamic>{
        'hog_raiser_id': isRaiserUnassigned ? null : _selectedRaiserId,
        'raiser_name': raiserName,
        'initial_capital': parsedCapital,
        'hog_type': hogTypeStr,
        'total_hog': parsedTotalHog,
        'investment_date': _isEdit
            ? widget.existingInvestment!.investmentDate.toIso8601String()
            : DateTime.now().toIso8601String(),
        if (!_isEdit) 'stage': 'active',
        if (!isBatchUnassigned && _selectedBatchId != null && _selectedBatchId != 'unassigned')
          'batch_id': _selectedBatchId,
        if (!isBatchUnassigned && _selectedBatchId != null && _selectedBatchId != 'unassigned' && batchName.isNotEmpty && batchName != 'Unassigned')
          'batch_name': batchName,
      };

      try {
        if (_isEdit) {
          await _supabase.from('investment_records').update(payload).eq('id', widget.existingInvestment!.id);
        } else {
          await _supabase.from('investment_records').insert(payload);
        }
      } catch (dbErr) {
        final errStr = dbErr.toString().toLowerCase();
        if (errStr.contains('batch_id') || errStr.contains('batch_name') || errStr.contains('pgrst204')) {
          final fallbackPayload = Map<String, dynamic>.from(payload)
            ..remove('batch_id')
            ..remove('batch_name');
          if (_isEdit) {
            await _supabase.from('investment_records').update(fallbackPayload).eq('id', widget.existingInvestment!.id);
          } else {
            await _supabase.from('investment_records').insert(fallbackPayload);
          }
        } else {
          rethrow;
        }
      }

      // Assign Hog Raiser to Batch in `assignments` table (1:1 linking, allows multiple pig types under that batch)
      if (!isBatchUnassigned && !isRaiserUnassigned && int.tryParse(_selectedRaiserId!) != null) {
        final parsedRaiserId = int.parse(_selectedRaiserId!);

        // Load all hog types from database
        List<dynamic> allHogTypesRes = [];
        try {
          allHogTypesRes = await _supabase.from('hog_types').select('hog_type_id, type_name');
        } catch (e) {
          debugPrint('Error loading hog types: $e');
        }

        int findHogTypeId(String keyword) {
          for (final row in allHogTypesRes) {
            if (row is Map) {
              final name = (row['type_name'] ?? '').toString().toLowerCase();
              if (name.contains(keyword.toLowerCase())) {
                return (row['hog_type_id'] as num).toInt();
              }
            }
          }
          return 1;
        }

        final List<Map<String, dynamic>> targetAllocations = [];
        if (fatteningCount > 0) {
          targetAllocations.add({
            'type_name': 'Fattening',
            'count': fatteningCount,
            'hog_type_id': findHogTypeId('fatten'),
          });
        }
        if (sowCount > 0) {
          targetAllocations.add({
            'type_name': 'Sow',
            'count': sowCount,
            'hog_type_id': findHogTypeId('sow'),
          });
        }
        if (targetAllocations.isEmpty && parsedTotalHog > 0) {
          final defType = _isSowSelected && !_isFatteningSelected ? 'Sow' : 'Fattening';
          targetAllocations.add({
            'type_name': defType,
            'count': parsedTotalHog,
            'hog_type_id': findHogTypeId(defType.toLowerCase().contains('sow') ? 'sow' : 'fatten'),
          });
        }

        for (final alloc in targetAllocations) {
          final typeName = alloc['type_name'] as String;
          final int allocationForThisType = alloc['count'] as int;
          final int typeHogId = alloc['hog_type_id'] as int;

          // Look for an existing assignment for this batch, raiser and hog type
          final existingTypeAssignList = await _supabase
              .from('assignments')
              .select('assignment_id, hog_type_id, hog_raiser_id, status')
              .eq('batch_id', _selectedBatchId!)
              .eq('hog_type_id', typeHogId)
              .eq('hog_raiser_id', parsedRaiserId)
              .order('assignment_id', ascending: false);

          dynamic targetAssignPk;
          bool reuseAssignment = false;

          if (existingTypeAssignList.isNotEmpty) {
            final latest = existingTypeAssignList.first as Map;
            final assignId = latest['assignment_id'];
            final assignStatus = (latest['status'] ?? '').toString().toLowerCase();
            final bool isExplicitlyDone = assignStatus == 'completed' || assignStatus == 'finished' || assignStatus == 'archived';

            if (!isExplicitlyDone) {
              // Check if all its hogs are already sold or completed
              final existingHogs = await _supabase
                  .from('hogs')
                  .select('hog_id, stage_id, status')
                  .eq('assignment_id', assignId);
              final existingList = existingHogs as List? ?? [];
              final bool allHogsConcluded = existingList.isNotEmpty && existingList.every((h) {
                final st = (h['status'] ?? '').toString().toLowerCase();
                final sId = int.tryParse((h['stage_id'] ?? '').toString()) ?? 1;
                return st == 'completed' || st == 'archived' || st == 'sold' || sId >= 6;
              });

              if (!allHogsConcluded) {
                // Truly active ongoing cycle: reuse and top up
                reuseAssignment = true;
                targetAssignPk = assignId;
                await _supabase.from('assignments').update({
                  'status': 'active',
                }).eq('assignment_id', targetAssignPk);
              } else {
                // Hogs are already at final stage / completed: mark past assignment as completed permanently
                await _supabase.from('assignments').update({
                  'status': 'completed',
                }).eq('assignment_id', assignId);
              }
            }
          }

          if (!reuseAssignment) {
            final newAssign = await _supabase.from('assignments').insert({
              'batch_id': _selectedBatchId,
              'hog_raiser_id': parsedRaiserId,
              'status': 'active',
              'hog_type_id': typeHogId,
              'assigned_date': DateTime.now().toIso8601String().split('T').first,
            }).select('assignment_id').maybeSingle();
            if (newAssign != null) {
              targetAssignPk = newAssign['assignment_id'];
            }
          }

          // Seed or top up hogs for this assignment
          if (targetAssignPk != null && allocationForThisType > 0) {
            try {
              if (reuseAssignment) {
                final existingHogs = await _supabase
                    .from('hogs')
                    .select('hog_id, stage_id, status')
                    .eq('assignment_id', targetAssignPk);
                final existingList = existingHogs as List? ?? [];
                final activeHogs = existingList.where((h) {
                  final st = (h['status'] ?? '').toString().toLowerCase();
                  final sId = int.tryParse((h['stage_id'] ?? '').toString()) ?? 1;
                  return st != 'completed' && st != 'sold' && st != 'archived' && sId < 6;
                }).toList();
                final needed = allocationForThisType - activeHogs.length;
                if (needed > 0) {
                  for (int i = 0; i < needed; i++) {
                    await _supabase.from('hogs').insert({
                      'assignment_id': targetAssignPk,
                      'status': 'active',
                      'health_status': 'healthy',
                      'stage_id': 1,
                      'pig_type': typeName,
                      'last_updated': DateTime.now().toIso8601String(),
                    });
                  }
                }
              } else {
                // New assignment cycle: seed full allocation of fresh hogs at Stage 1
                for (int i = 0; i < allocationForThisType; i++) {
                  await _supabase.from('hogs').insert({
                    'assignment_id': targetAssignPk,
                    'status': 'active',
                    'health_status': 'healthy',
                    'stage_id': 1,
                    'pig_type': typeName,
                    'last_updated': DateTime.now().toIso8601String(),
                  });
                }
              }
            } catch (hErr) {
              debugPrint('Notice seeding hogs for type $typeName: $hErr');
            }
          }
        }

        // Reactivate batch in batches table
        try {
          final parsedBId = int.tryParse(_selectedBatchId!) ?? _selectedBatchId!;
          await _supabase.from('batches').update({'status': 'Active'}).eq('batch_id', parsedBId);
        } catch (_) {}

        // Update hog raiser status and pig_type without erasing existing types
        final bool hasSow = sowCount > 0;
        final bool hasFattening = fatteningCount > 0;

        String existingRaiserType = '';
        try {
          final cur = await _supabase.from('hog_raisers').select('pig_type').eq('hog_raiser_id', parsedRaiserId).maybeSingle();
          existingRaiserType = (cur?['pig_type'] ?? '').toString().toLowerCase();
        } catch (_) {}

        final bool overallHasSow = hasSow || existingRaiserType.contains('sow') || existingRaiserType.contains('breed');
        final bool overallHasFattening = hasFattening || existingRaiserType.contains('fatten');

        final String combinedType = (overallHasSow && overallHasFattening)
            ? 'Sow and Fattening'
            : (overallHasSow ? 'Sow' : 'Fattening');

        final defaultStage = overallHasSow ? 'Gilt' : 'Booster';

        await _supabase.from('hog_raisers').update({
          'status': 'Active',
          'lifecycle_stage': defaultStage,
          'pig_type': combinedType,
        }).eq('hog_raiser_id', parsedRaiserId);
      } else if (!isRaiserUnassigned && int.tryParse(_selectedRaiserId!) != null) {
        // Fallback: If batch was left unassigned, attach newly added hogs to raiser's active assignment
        final parsedRaiserId = int.parse(_selectedRaiserId!);
        try {
          final raiserAssignList = await _supabase
              .from('assignments')
              .select('assignment_id, batch_id, status')
              .eq('hog_raiser_id', parsedRaiserId)
              .inFilter('status', ['active', 'Active'])
              .order('assignment_id', ascending: false)
              .limit(1);

          if (raiserAssignList.isNotEmpty) {
            final targetAssignId = raiserAssignList.first['assignment_id'];
            final bId = raiserAssignList.first['batch_id'];
            await _supabase.from('assignments').update({'status': 'active'}).eq('assignment_id', targetAssignId);
            if (bId != null) {
              try {
                await _supabase.from('batches').update({'status': 'Active'}).eq('batch_id', bId);
              } catch (_) {}
            }
            for (int i = 0; i < parsedTotalHog; i++) {
              await _supabase.from('hogs').insert({
                'assignment_id': targetAssignId,
                'status': 'active',
                'health_status': 'healthy',
                'stage_id': 1,
                'last_updated': DateTime.now().toIso8601String(),
              });
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      widget.onShowSnackBar(
        _isEdit
            ? 'Investment updated successfully.'
            : (isRaiserUnassigned
                ? 'Investment created successfully.'
                : 'Investment for $batchName created and $raiserName assigned successfully.'),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      widget.onShowSnackBar('Operation failed: $e', isError: true);
    }
  }

  Widget _buildHogTypeCard({
    required String title,
    required bool isSelected,
    required TextEditingController controller,
    required VoidCallback onToggle,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required ValueChanged<String> onChanged,
  }) {
    final activeColor = _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;
    final checkColor = _isDark ? const Color(0xFF132238) : Colors.white;
    final inactiveBorder = _isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final cardBorderColor = isSelected
        ? (_isDark ? const Color(0xFF4B6F96) : const Color(0xFF90B3D6))
        : (_isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3));
    final cardBgColor = isSelected
        ? (_isDark ? const Color(0xFF1B2E49) : const Color(0xFFF7FAFD))
        : (_isDark ? const Color(0xFF16253B) : Colors.white);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor, width: isSelected ? 1.5 : 1.0),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: PiggyTrunkTheme.ptPrimary.withValues(alpha: _isDark ? 0.25 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Checkbox + Title
          Expanded(
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? _titleColor : _mutedColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Stepper / Direct Number Input (Only active / visible when selected)
          if (isSelected) ...[
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: _fieldBg,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _fieldBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minus Button
                  InkWell(
                    onTap: onDecrement,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Icon(Icons.remove_rounded, size: 16, color: _fieldText),
                    ),
                  ),
                  // Number Field
                  SizedBox(
                    width: 48,
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: onChanged,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _fieldText,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                  // Plus Button
                  InkWell(
                    onTap: onIncrement,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Icon(Icons.add_rounded, size: 16, color: _fieldText),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'heads',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _mutedColor,
              ),
            ),
          ],
        ],
      ),
    );
  }


  /// Skeleton for a single labeled form field (dropdown or text input).
  Widget _buildFormFieldSkeleton({
    required String label,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: _mutedColor,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        ShimmerBox(
          width: double.infinity,
          height: 48,
          borderRadius: BorderRadius.circular(10),
          isDark: _isDark,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    if (_isLoadingData) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1350),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_panelStart, _panelEnd],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border.all(color: _panelBorder, width: 1),
              borderRadius: BorderRadius.circular(isMobile ? 16 : 34),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 34,
              vertical: isMobile ? 16 : 32,
            ),
            child: ShimmerProvider(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header skeleton (Title + Close button)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(
                              width: isMobile ? 200 : 280,
                              height: isMobile ? 22 : 28,
                              borderRadius: BorderRadius.circular(6),
                              isDark: _isDark,
                            ),
                            const SizedBox(height: 8),
                            ShimmerBox(
                              width: isMobile ? 260 : 420,
                              height: 12,
                              borderRadius: BorderRadius.circular(4),
                              isDark: _isDark,
                            ),
                          ],
                        ),
                      ),
                      ShimmerBox(
                        width: isMobile ? 32 : 36,
                        height: isMobile ? 32 : 36,
                        borderRadius: BorderRadius.circular(8),
                        isDark: _isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Form Card skeleton
                  Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                      border: Border.all(color: _cardBorder),
                    ),
                    padding: EdgeInsets.all(isMobile ? 16 : 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SELECT BATCH TO FUND label + dropdown skeleton
                        _buildFormFieldSkeleton(
                          label: 'SELECT BATCH TO FUND *',
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 22),

                        // ASSIGN HOG RAISER label + dropdown skeleton
                        _buildFormFieldSkeleton(
                          label: 'ASSIGN HOG RAISER *',
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 22),

                        // INITIAL CAPITAL label + input skeleton
                        _buildFormFieldSkeleton(
                          label: 'INITIAL CAPITAL (PHP) *',
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 22),

                        // HOG TYPE & HEADS ALLOCATION skeleton
                        Text(
                          'HOG TYPE & HEADS ALLOCATION *',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: _mutedColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ShimmerBox(
                          width: double.infinity,
                          height: 140,
                          borderRadius: BorderRadius.circular(14),
                          isDark: _isDark,
                        ),
                        const SizedBox(height: 12),
                        ShimmerBox(
                          width: double.infinity,
                          height: 48,
                          borderRadius: BorderRadius.circular(10),
                          isDark: _isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons skeleton
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ShimmerBox(
                          height: 48,
                          borderRadius: BorderRadius.circular(10),
                          isDark: _isDark,
                        ),
                        const SizedBox(height: 10),
                        ShimmerBox(
                          height: 48,
                          borderRadius: BorderRadius.circular(10),
                          isDark: _isDark,
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ShimmerBox(
                          width: 100,
                          height: 48,
                          borderRadius: BorderRadius.circular(10),
                          isDark: _isDark,
                        ),
                        const SizedBox(width: 12),
                        ShimmerBox(
                          width: 170,
                          height: 48,
                          borderRadius: BorderRadius.circular(10),
                          isDark: _isDark,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1350),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_panelStart, _panelEnd],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(color: _panelBorder, width: 1),
            borderRadius: BorderRadius.circular(isMobile ? 16 : 34),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 34,
            vertical: isMobile ? 16 : 32,
          ),
          child: Column(
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
                        Text(
                          _isEdit ? 'Edit Investment' : 'Add New Investment',
                          style: GoogleFonts.plusJakartaSans(
                            color: _titleColor,
                            fontSize: isMobile ? 22 : 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEdit
                              ? 'Update investment details, assigned raiser, and capital allocation.'
                              : 'Assign an authorized hog raiser, allocate capital, and fund a batch.',
                          style: GoogleFonts.plusJakartaSans(
                            color: _mutedColor,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: Icon(Icons.close_rounded, color: _titleColor, size: isMobile ? 24 : 28),
                    tooltip: 'Back to investments',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Form Card Container
              Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                  border: Border.all(color: _cardBorder),
                ),
                padding: EdgeInsets.all(isMobile ? 16 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SELECT BATCH TO FUND DROPDOWN (Searchable & Sorted Newest First)
                    Text(
                      'SELECT BATCH TO FUND *',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _mutedColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SearchableDropdownField<String>(
                      key: ValueKey('batch_dropdown_${_selectedBatchId}_${_activeBatches.length}'),
                      value: _activeBatches.any((b) => b['batch_id'].toString() == _selectedBatchId)
                          ? _selectedBatchId
                          : (_activeBatches.isNotEmpty ? _activeBatches.first['batch_id'].toString() : 'unassigned'),
                      unassignedValue: 'unassigned',
                      hintText: 'Select or search a batch to fund',
                      searchHintText: 'Type to search batch name or raiser...',
                      isDark: _isDark,
                      fieldBg: _fieldBg,
                      fieldBorder: _fieldBorder,
                      fieldFocus: _fieldFocus,
                      fieldText: _fieldText,
                      mutedColor: _mutedColor,
                      cardBg: _cardBg,
                      cardBorder: _cardBorder,
                      defaultPrefixIcon: Icons.layers_outlined,
                      items: _activeBatches.map((b) {
                        final isUnassigned = b['batch_id'] == 'unassigned';
                        final rName = (b['raiser_name'] ?? '').toString();
                        final hasRaiser = rName.isNotEmpty && rName != 'Unassigned';
                        final count = b['hog_count'] ?? 0;
                        return SearchableDropdownItem<String>(
                          value: b['batch_id'].toString(),
                          label: b['display_label'].toString(),
                          subtitle: isUnassigned
                              ? null
                              : (hasRaiser ? 'Raiser: $rName • $count hogs' : (count > 0 ? '$count hogs' : null)),
                          badge: hasRaiser ? rName : null,
                          badgeColor: hasRaiser
                              ? (_isDark ? const Color(0xFFCBD5E1) : PiggyTrunkTheme.ptPrimary)
                              : null,
                          icon: isUnassigned ? Icons.layers_clear_outlined : Icons.layers_outlined,
                          iconColor: isUnassigned
                              ? (_isDark ? const Color(0xFF94A3B8) : _mutedColor)
                              : (_isDark ? const Color(0xFF9CB0C9) : PiggyTrunkTheme.ptPrimary),
                          searchKeywords: '${b['batch_name']} $rName',
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _selectedBatchId = val;
                          if (val != 'unassigned') {
                            final matched = _activeBatches.firstWhere(
                              (b) => b['batch_id'].toString() == val,
                              orElse: () => {},
                            );
                            final rId = (matched['raiser_id'] ?? '').toString();
                            if (rId.isNotEmpty && rId != 'unassigned') {
                              if (_activeRaisers.any((r) => r['id'].toString() == rId)) {
                                _selectedRaiserId = rId;
                              }
                            } else {
                              // If this batch has no raiser assigned yet,
                              // check if the currently selected raiser is already assigned to a DIFFERENT active batch.
                              // If so, reset _selectedRaiserId to 'unassigned' so an already-assigned raiser is not mistakenly kept!
                              final currentRaiser = _activeRaisers.firstWhere(
                                (r) => r['id'].toString() == _selectedRaiserId,
                                orElse: () => {},
                              );
                              final rBatch = currentRaiser['assigned_batch_id']?.toString();
                              final isDone = currentRaiser['is_batch_completed'] == true;
                              if (rBatch != null && rBatch.isNotEmpty && rBatch != val && !isDone) {
                                _selectedRaiserId = 'unassigned';
                              }
                            }
                            final pt = (matched['pig_type'] ?? 'Fattening').toString().trim();
                            if (pt.isNotEmpty && pt != 'N/A') {
                              final ptLower = pt.toLowerCase();
                              final hasSow = ptLower.contains('sow') || ptLower.contains('breed');
                              final hasFat = ptLower.contains('fatten');
                              if (hasSow && hasFat) {
                                _isFatteningSelected = true;
                                _isSowSelected = true;
                              } else if (hasSow) {
                                _isFatteningSelected = false;
                                _isSowSelected = true;
                              } else if (hasFat) {
                                _isFatteningSelected = true;
                                _isSowSelected = false;
                              }
                            }
                          } else {
                            final currentRaiser = _activeRaisers.firstWhere(
                              (r) => r['id'].toString() == _selectedRaiserId,
                              orElse: () => {},
                            );
                            final rBatch = currentRaiser['assigned_batch_id']?.toString();
                            final isDone = currentRaiser['is_batch_completed'] == true;
                            if (rBatch != null && rBatch.isNotEmpty && !isDone) {
                              _selectedRaiserId = 'unassigned';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 22),

                    // ASSIGN HOG RAISER DROPDOWN (Searchable & Sorted Newest First)
                    Text(
                      'ASSIGN HOG RAISER *',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _mutedColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SearchableDropdownField<String>(
                      key: ValueKey('raiser_dropdown_${_selectedRaiserId}_${_activeRaisers.length}'),
                      value: _activeRaisers.any((r) => r['id'].toString() == _selectedRaiserId)
                          ? _selectedRaiserId
                          : 'unassigned',
                      unassignedValue: 'unassigned',
                      hintText: 'Select or search a hog raiser',
                      searchHintText: 'Type to search hog raiser by name...',
                      isDark: _isDark,
                      fieldBg: _fieldBg,
                      fieldBorder: _fieldBorder,
                      fieldFocus: _fieldFocus,
                      fieldText: _fieldText,
                      mutedColor: _mutedColor,
                      cardBg: _cardBg,
                      cardBorder: _cardBorder,
                      defaultPrefixIcon: Icons.person_outline_rounded,
                      items: [
                        () {
                          final currentSelectedBatch = (_selectedBatchId != null && _selectedBatchId != 'unassigned')
                              ? _activeBatches.firstWhere((b) => b['batch_id'].toString() == _selectedBatchId, orElse: () => {})
                              : null;
                          final currentBatchRaiserId = (currentSelectedBatch?['raiser_id'] ?? '').toString();
                          final hasCurrentBatchRaiser = currentBatchRaiserId.isNotEmpty && currentBatchRaiserId != 'unassigned';

                          return SearchableDropdownItem<String>(
                            value: 'unassigned',
                            label: _activeRaisers.isEmpty
                                ? 'No Authorized Raisers (Unassigned)'
                                : 'Unassigned (General Pool)',
                            subtitle: hasCurrentBatchRaiser
                                ? 'Locked (Batch assigned to ${currentSelectedBatch!['raiser_name']})'
                                : null,
                            badge: null,
                            badgeColor: null,
                            isEnabled: !hasCurrentBatchRaiser,
                            icon: hasCurrentBatchRaiser ? Icons.lock_outline_rounded : Icons.person_off_outlined,
                            iconColor: _isDark ? const Color(0xFF94A3B8) : _mutedColor,
                            searchKeywords: 'unassigned general pool none',
                          );
                        }(),
                        ..._activeRaisers.map((r) {
                          final rBatchId = r['assigned_batch_id']?.toString();
                          final hasBatch = rBatchId != null && rBatchId.isNotEmpty;
                          final assignedBatchName = r['assigned_batch_name'] ?? 'another Batch';
                          final isBatchCompleted = r['is_batch_completed'] == true;

                          final currentSelectedBatch = (_selectedBatchId != null && _selectedBatchId != 'unassigned')
                              ? _activeBatches.firstWhere((b) => b['batch_id'].toString() == _selectedBatchId, orElse: () => {})
                              : null;
                          final currentBatchRaiserId = (currentSelectedBatch?['raiser_id'] ?? '').toString();
                          final hasCurrentBatchRaiser = currentBatchRaiserId.isNotEmpty && currentBatchRaiserId != 'unassigned';

                          final isAssignedToCurrent = hasBatch &&
                              _selectedBatchId != null &&
                              _selectedBatchId != 'unassigned' &&
                              rBatchId == _selectedBatchId;

                          // 1:1 Strict Rule:
                          // Condition 1: If current selected batch is already assigned to another raiser, lock out everyone else.
                          final bool isBatchAssignedToOther = hasCurrentBatchRaiser && r['id'].toString() != currentBatchRaiserId;

                          // Condition 2: If this raiser is already active in another batch, they cannot take a new batch.
                          final bool isRaiserActiveInOther = hasBatch &&
                              !isBatchCompleted &&
                              (_selectedBatchId == null || _selectedBatchId == 'unassigned' || rBatchId != _selectedBatchId);

                          final bool isLockedOut = isBatchAssignedToOther || isRaiserActiveInOther;

                          String subText = '';
                          Color? bColor;
                          String? badgeText;
                          IconData itemIcon;
                          Color? iconCol;

                          if (isBatchAssignedToOther) {
                            subText = 'Locked (Batch assigned to ${currentSelectedBatch!['raiser_name']})';
                            bColor = null;
                            badgeText = null;
                            itemIcon = Icons.lock_outline_rounded;
                            iconCol = _isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
                          } else if (isRaiserActiveInOther) {
                            subText = 'Locked (Active in $assignedBatchName)';
                            bColor = null;
                            badgeText = null;
                            itemIcon = Icons.lock_outline_rounded;
                            iconCol = _isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
                          } else if (isAssignedToCurrent) {
                            subText = 'Currently assigned to $assignedBatchName';
                            bColor = _isDark ? const Color(0xFFCBD5E1) : PiggyTrunkTheme.ptPrimary;
                            badgeText = assignedBatchName;
                            itemIcon = Icons.person_rounded;
                            iconCol = _isDark ? const Color(0xFF9CB0C9) : PiggyTrunkTheme.ptPrimary;
                          } else if (isBatchCompleted) {
                            subText = 'Available (Completed $assignedBatchName)';
                            bColor = PiggyTrunkTheme.ptSuccess;
                            badgeText = 'Available';
                            itemIcon = Icons.check_circle_outline_rounded;
                            iconCol = PiggyTrunkTheme.ptSuccess;
                          } else {
                            subText = 'Ready to assign';
                            bColor = null;
                            badgeText = null;
                            itemIcon = Icons.person_outline_rounded;
                            iconCol = _isDark ? const Color(0xFF9CB0C9) : const Color(0xFF64748B);
                          }

                          return SearchableDropdownItem<String>(
                            value: r['id'].toString(),
                            label: r['name'].toString(),
                            subtitle: subText.isNotEmpty ? subText : null,
                            badge: badgeText,
                            badgeColor: bColor,
                            isEnabled: !isLockedOut,
                            icon: itemIcon,
                            iconColor: iconCol,
                            searchKeywords: '${r['name']} $assignedBatchName ${r['pig_type'] ?? ''} ${isBatchCompleted ? 'available completed' : ''}',
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        // 1:1 Batch-to-Raiser Enforcement:
                        // 1. If currently selected batch is already assigned to a DIFFERENT raiser, prevent changing:
                        if (_selectedBatchId != null && _selectedBatchId != 'unassigned' && val != 'unassigned') {
                          final currentBatch = _activeBatches.firstWhere(
                            (b) => b['batch_id'].toString() == _selectedBatchId,
                            orElse: () => {},
                          );
                          final assignedRaiserId = (currentBatch['raiser_id'] ?? '').toString();
                          if (assignedRaiserId.isNotEmpty && assignedRaiserId != 'unassigned' && assignedRaiserId != val) {
                            final assignedRaiserName = currentBatch['raiser_name'] ?? 'another Hog Raiser';
                            widget.onShowSnackBar(
                              '${currentBatch['batch_name']} is already assigned to $assignedRaiserName. Each batch can only be assigned to one Hog Raiser.',
                              isError: true,
                            );
                            return;
                          }
                        }

                        // 2. If the chosen raiser is already active in another batch, prevent selecting:
                        if (val != 'unassigned') {
                          final chosenRaiser = _activeRaisers.firstWhere(
                            (r) => r['id'].toString() == val,
                            orElse: () => {},
                          );
                          final rBatchId = chosenRaiser['assigned_batch_id']?.toString();
                          final isBatchCompleted = chosenRaiser['is_batch_completed'] == true;
                          if (rBatchId != null && rBatchId.isNotEmpty && !isBatchCompleted) {
                            if (_selectedBatchId != null && _selectedBatchId != 'unassigned' && rBatchId != _selectedBatchId) {
                              final assignedBatchName = chosenRaiser['assigned_batch_name'] ?? 'another Batch';
                              widget.onShowSnackBar(
                                '${chosenRaiser['name']} is already active in $assignedBatchName. Each Hog Raiser can only manage one active batch at a time.',
                                isError: true,
                              );
                              return;
                            }
                          }
                        }

                        final matched = _activeRaisers.firstWhere(
                          (r) => r['id'].toString() == val,
                          orElse: () => {},
                        );
                        setState(() {
                          _selectedRaiserId = val;
                          if (val != 'unassigned') {
                            // If this raiser already has an active batch and no batch is currently selected, auto-select it!
                            final rBatchId = matched['assigned_batch_id']?.toString();
                            if (rBatchId != null && rBatchId.isNotEmpty && (_selectedBatchId == null || _selectedBatchId == 'unassigned')) {
                              if (_activeBatches.any((b) => b['batch_id'].toString() == rBatchId)) {
                                _selectedBatchId = rBatchId;
                              }
                            }
                            final pt = (matched['pig_type'] ?? '').toString().trim();
                            if (pt.isNotEmpty && pt != 'N/A') {
                              final ptLower = pt.toLowerCase();
                              final hasSow = ptLower.contains('sow') || ptLower.contains('breed');
                              final hasFat = ptLower.contains('fatten');
                              if (hasSow && hasFat) {
                                _isFatteningSelected = true;
                                _isSowSelected = true;
                              } else if (hasSow) {
                                _isFatteningSelected = false;
                                _isSowSelected = true;
                              } else if (hasFat) {
                                _isFatteningSelected = true;
                                _isSowSelected = false;
                              }
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 22),

                    // Initial Capital
                    Text(
                      'INITIAL CAPITAL (PHP) *',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _mutedColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _capitalCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        ThousandsSeparatorInputFormatter(),
                      ],
                      onChanged: (_) {
                        if (_capitalError != null) setState(() => _capitalError = null);
                      },
                      style: GoogleFonts.plusJakartaSans(
                        color: _fieldText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 14),
                        prefixIcon: Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: Text(
                            '₱',
                            style: GoogleFonts.plusJakartaSans(
                              color: _mutedColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: _fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _capitalError != null ? const Color(0xFFE53E3E) : _fieldBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _capitalError != null ? const Color(0xFFE53E3E) : _fieldFocus,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (_capitalError != null) ...[
                      const SizedBox(height: 4),
                      Text(_capitalError!, style: const TextStyle(color: Color(0xFFE53E3E), fontSize: 11.5)),
                    ],
                    const SizedBox(height: 22),

                    // HOG TYPE & HEADS
                    Text(
                      'HOG TYPE & HEADS *',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _mutedColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Fattening Card
                    _buildHogTypeCard(
                      title: 'Fattening',
                      isSelected: _isFatteningSelected,
                      controller: _fatteningCountCtrl,
                      onToggle: _toggleFattening,
                      onIncrement: () => _incrementFattening(1),
                      onDecrement: () => _decrementFattening(1),
                      onChanged: (_) => setState(() => _syncTotalHogCtrl()),
                    ),
                    const SizedBox(height: 10),

                    // Sow / Breeding Card
                    _buildHogTypeCard(
                      title: 'Sow / Breeding',
                      isSelected: _isSowSelected,
                      controller: _sowCountCtrl,
                      onToggle: _toggleSow,
                      onIncrement: () => _incrementSow(1),
                      onDecrement: () => _decrementSow(1),
                      onChanged: (_) => setState(() => _syncTotalHogCtrl()),
                    ),
                    const SizedBox(height: 14),

                    // Total Heads Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: _calculatedTotalHogs > 0
                            ? (_isDark ? PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.22) : const Color(0xFFEFF6FF))
                            : (_isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _totalHogError != null
                              ? const Color(0xFFE53E3E)
                              : (_calculatedTotalHogs > 0
                                  ? (_isDark ? const Color(0xFF385579) : const Color(0xFFBFDBFE))
                                  : _cardBorder),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Total Heads:',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _mutedColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$_calculatedTotalHogs',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: _calculatedTotalHogs > 0 ? _titleColor : _mutedColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_calculatedTotalHogs > 0) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    _breakdownSummaryText,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _mutedColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_totalHogError != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFE53E3E)),
                          const SizedBox(width: 6),
                          Text(
                            _totalHogError!,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFE53E3E),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Responsive Action Buttons
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitForm,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                          label: Text(
                            _isSubmitting ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Save Investment'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            foregroundColor: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _isSubmitting ? null : widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: _fieldBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              color: _fieldText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _isSubmitting ? null : widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            side: BorderSide(color: _fieldBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              color: _fieldText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitForm,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                          label: Text(
                            _isSubmitting ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Save Investment'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            foregroundColor: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Automatically adds thousand separators (commas) to numeric money inputs as the user types.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String textToFormat = newValue.text;
    int selectionEnd = newValue.selection.end;

    // Handle backspace when the cursor was right after a comma
    if (oldValue.text.length == newValue.text.length + 1 &&
        oldValue.selection.end > 0 &&
        oldValue.text[oldValue.selection.end - 1] == ',') {
      final deleteIndex = oldValue.selection.end - 2;
      if (deleteIndex >= 0) {
        textToFormat = oldValue.text.substring(0, deleteIndex) +
            oldValue.text.substring(oldValue.selection.end);
        selectionEnd = deleteIndex;
      }
    }

    final digitsOnly = textToFormat.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = digitsOnly.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    // Calculate new cursor position based on digit count before the cursor
    final textBeforeCursor = textToFormat.substring(
      0,
      selectionEnd.clamp(0, textToFormat.length),
    );
    final digitsBeforeCursor = textBeforeCursor.replaceAll(RegExp(r'[^\d]'), '').length;

    int newCursorPos = 0;
    int digitCount = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (formatted[i] != ',') {
        digitCount++;
      }
      if (digitCount == digitsBeforeCursor) {
        newCursorPos = i + 1;
        break;
      }
    }
    if (digitCount < digitsBeforeCursor) {
      newCursorPos = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPos.clamp(0, formatted.length)),
    );
  }
}
