import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/app_toast.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/screen_top_bar.dart';
import '../utils/responsive.dart';
import '../widgets/batch/batch_detail_view.dart';
import '../widgets/batch/batch_form_view.dart';
import '../widgets/batch/batch_table_view.dart';
import '../widgets/common/in_page_confirmation_view.dart';
import '../main.dart';

class BatchManagementScreen extends StatefulWidget {
  const BatchManagementScreen({super.key});

  @override
  State<BatchManagementScreen> createState() => _BatchManagementScreenState();
}

class _BatchManagementScreenState extends State<BatchManagementScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _batchesList = [];
  List<Map<String, dynamic>> _activeRaisers = [];
  bool _isLoading = true;
  bool _isTableRefreshing = false;
  bool _showBatchForm = false;
  Map<String, dynamic>? _editingBatch;
  Map<String, dynamic>? _selectedBatchForDetails;
  Widget? _inPageConfirmation;
  String _searchQuery = '';
  String _selectedStatusFilter = 'ALL';
  String? _loadError;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgDark => _isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
  Color get _panelStart => _isDark ? const Color(0xFF1A2940) : Colors.white;
  Color get _panelEnd => _isDark ? const Color(0xFF0F1C2F) : Colors.white;
  Color get _panelBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);

  @override
  void initState() {
    super.initState();
    final session = _supabase.auth.currentSession;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return;
    }
    if (isInitialLaunch) {
      isInitialLaunch = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      });
      return;
    }
    _loadData();
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (isRefresh) {
        _isTableRefreshing = true;
      } else {
        _isLoading = true;
      }
      _loadError = null;
    });

    try {
      // 1. Fetch batches
      List<dynamic> batchesData = [];
      try {
        batchesData = await _supabase.from('batches').select('*');
      } catch (e) {
        debugPrint('Error fetching batches with select(*): $e');
        try {
          batchesData = await _supabase.from('batches').select();
        } catch (e2) {
          debugPrint('Error fetching batches fallback: $e2');
          _loadError = 'Batches query error: $e2';
        }
      }

      // 2. Fetch assignments directly
      List<dynamic> assignmentsData = [];
      try {
        assignmentsData = await _supabase.from('assignments').select('*');
      } catch (e) {
        debugPrint('Error fetching assignments: $e');
      }

      // 3. Fetch active authorized raisers
      List<dynamic> raisersData = [];
      try {
        raisersData = await _supabase.from('hog_raisers').select('*');
      } catch (e) {
        debugPrint('Error fetching raisers: $e');
      }

      // 4. Fetch hogs for lifecycle completion resolution
      List<dynamic> hogsData = [];
      try {
        hogsData = await _supabase.from('hogs').select('*');
      } catch (e) {
        debugPrint('Notice loading all hogs for batch status: $e. Fallback to specific fields...');
        try {
          hogsData = await _supabase
              .from('hogs')
              .select('hog_id, assignment_id, stage_id, status, health_status');
        } catch (e2) {
          debugPrint('Error fetching hogs for batch status: $e2');
        }
      }

      final Map<String, List<Map<String, dynamic>>> assignmentHogsMap = {};
      for (var h in hogsData) {
        if (h is! Map) continue;
        final aId = (h['assignment_id'] ?? '').toString();
        if (aId.isNotEmpty) {
          assignmentHogsMap.putIfAbsent(aId, () => []).add(Map<String, dynamic>.from(h));
        }
      }

      final Map<String, String> batchNamesMap = {
        for (var b in batchesData)
          (b['batch_id'] ?? b['id'] ?? '').toString(): (b['batch_name'] ?? 'Batch #${b['batch_id']}').toString()
      };

      final Map<String, String> batchStatusMap = {
        for (var b in batchesData)
          (b['batch_id'] ?? b['id'] ?? '').toString(): (b['status'] ?? b['batch_status'] ?? 'Active').toString().toLowerCase()
      };

      final Map<String, String> assignedToBatchMap = {};
      for (var a in assignmentsData) {
        if (a is! Map) continue;
        final st = (a['status'] ?? 'active').toString().toLowerCase();
        if (st == 'completed' || st == 'archived' || st == 'finished') continue;

        final bId = (a['batch_id'] ?? '').toString();
        final bStatus = batchStatusMap[bId] ?? 'active';
        if (bStatus == 'finished' || bStatus == 'completed' || bStatus == 'archived') continue;

        final aIdStr = (a['assignment_id'] ?? a['id'] ?? '').toString();
        final assignHogs = assignmentHogsMap[aIdStr] ?? [];
        if (assignHogs.isNotEmpty) {
          final bool allHogsDone = assignHogs.every((hog) {
            final health = (hog['health_status'] ?? '').toString().toLowerCase();
            if (health == 'dead') return true;
            final sId = int.tryParse((hog['stage_id'] ?? '').toString());
            final stageStr = _resolveStageName(hog['stage_id'] ?? hog['lifecycle_stage'], false).toLowerCase();
            final hogStatus = (hog['status'] ?? '').toString().toLowerCase();
            return (sId != null && sId >= 6) ||
                stageStr.contains('selling') ||
                stageStr.contains('sold') ||
                stageStr.contains('lactation') ||
                stageStr.contains('complete') ||
                hogStatus == 'completed' ||
                hogStatus == 'archived';
          });
          if (allHogsDone) continue;
        }

        final rId = (a['hog_raiser_id'] ?? '').toString();
        final bName = batchNamesMap[bId] ?? 'Batch #$bId';
        if (rId.isNotEmpty) {
          assignedToBatchMap[rId] = bName;
        }
      }

      final Map<String, String> raiserMap = {};
      final List<Map<String, dynamic>> parsedRaisers = [];
      for (var r in raisersData) {
        if (r is! Map) continue;
        final rMap = Map<String, dynamic>.from(r);
        final realPk = rMap['hog_raiser_id'] ?? rMap['id'];
        if (realPk != null) {
          final pkStr = realPk.toString();
          
          dynamic appUsersRaw = rMap['app_users'];
          Map<String, dynamic>? appUsers;
          if (appUsersRaw is Map) {
            appUsers = Map<String, dynamic>.from(appUsersRaw);
          } else if (appUsersRaw is List && appUsersRaw.isNotEmpty && appUsersRaw.first is Map) {
            appUsers = Map<String, dynamic>.from(appUsersRaw.first);
          }

          final gName = (appUsers?['name'] ?? '').toString().trim();
          final rName = (rMap['name'] ?? '').toString().trim();
          final resolvedName = (gName.isNotEmpty && gName.toLowerCase() != 'hog raiser')
              ? gName
              : (rName.isNotEmpty ? rName : 'Hog Raiser');

          final isAssignedElsewhere = assignedToBatchMap.containsKey(pkStr);
          final assignedBatchName = assignedToBatchMap[pkStr];

          raiserMap[pkStr] = resolvedName;
          parsedRaisers.add({
            'id': realPk,
            'name': resolvedName,
            'phone': rMap['phone'] ?? 'N/A',
            'email': appUsers?['email'] ?? '',
            'is_assigned_elsewhere': isAssignedElsewhere,
            'assigned_batch_name': assignedBatchName,
          });
        }
      }

      final List<Map<String, dynamic>> parsedBatches = [];

      for (var b in batchesData) {
        if (b is! Map) continue;
        final bMap = Map<String, dynamic>.from(b);
        final bId = bMap['batch_id'] ?? bMap['id'] ?? bMap['batch_number'] ?? bMap['batch_code'];
        if (bId == null) continue;

        final rawStatus = (bMap['status'] ?? bMap['batch_status'] ?? '').toString().toLowerCase();
        if (rawStatus == 'archived' || rawStatus == 'deleted') continue;

        // Find assignments for this batch safely
        Map<String, dynamic>? matchingAssign;
        final List<Map<String, dynamic>> allBatchAssigns = [];
        for (var a in assignmentsData) {
          if (a is Map && (a['batch_id']?.toString() == bId.toString() || a['id']?.toString() == bId.toString())) {
            final aMap = Map<String, dynamic>.from(a);
            allBatchAssigns.add(aMap);
            final st = (aMap['status'] ?? '').toString().toLowerCase();
            if (st == 'active') {
              matchingAssign = aMap;
            } else {
              matchingAssign ??= aMap;
            }
          }
        }

        String raiserName = 'Unassigned';
        dynamic raiserId;
        String batchStatus = 'Unassigned';

        if (matchingAssign != null) {
          final rawRaiserId = matchingAssign['hog_raiser_id'];
          if (rawRaiserId != null) {
            raiserId = rawRaiserId;
            raiserName = raiserMap[rawRaiserId.toString()] ?? 'Hog Raiser';

            // Gather all hogs assigned to this batch
            final assignHogs = <Map<String, dynamic>>[];
            final assignsToCheck = allBatchAssigns.isNotEmpty ? allBatchAssigns : [matchingAssign];
            for (var assign in assignsToCheck) {
              final aIdStr = (assign['assignment_id'] ?? assign['id'] ?? '').toString();
              if (assignmentHogsMap.containsKey(aIdStr)) {
                assignHogs.addAll(assignmentHogsMap[aIdStr]!);
              }
            }

            final bool hasActiveHogs = assignHogs.any((hog) {
              final health = (hog['health_status'] ?? '').toString().toLowerCase();
              if (health == 'dead') return false;
              final sId = int.tryParse((hog['stage_id'] ?? '').toString());
              final stageStr = _resolveStageName(hog['stage_id'] ?? hog['lifecycle_stage'], false).toLowerCase();
              final hogStatus = (hog['status'] ?? '').toString().toLowerCase();
              final bool isConcluded = (sId != null && sId >= 6) ||
                  stageStr.contains('selling') ||
                  stageStr.contains('sold') ||
                  stageStr.contains('lactation') ||
                  stageStr.contains('complete') ||
                  hogStatus == 'completed' ||
                  hogStatus == 'archived';
              return !isConcluded;
            });

            final bool hasActiveAssignment = allBatchAssigns.any((a) {
              final st = (a['status'] ?? '').toString().toLowerCase();
              return st == 'active';
            });

            bool isAllHogsFinished = false;
            if (assignHogs.isNotEmpty) {
              isAllHogsFinished = !hasActiveHogs;
            }

            if (hasActiveHogs || hasActiveAssignment || rawStatus == 'active') {
              batchStatus = 'Active';
            } else if (rawStatus == 'completed' || rawStatus == 'finished' || isAllHogsFinished) {
              batchStatus = 'Finished';
            } else {
              batchStatus = 'Active';
            }
          }
        } else if (rawStatus == 'completed' || rawStatus == 'finished') {
          batchStatus = 'Finished';
        }

        parsedBatches.add({
          'batch_id': bId,
          'batch_name': bMap['batch_name'] ?? bMap['name'] ?? 'Batch $bId',
          'date_created': (bMap['date_created'] ?? bMap['created_at'])?.toString() ?? 'N/A',
          'status': batchStatus,
          'assignment_id': matchingAssign?['assignment_id'],
          'raiser_id': raiserId,
          'raiser_name': raiserName,
        });
      }

      parsedBatches.sort((a, b) {
        final aId = int.tryParse(a['batch_id']?.toString() ?? '0') ?? 0;
        final bId = int.tryParse(b['batch_id']?.toString() ?? '0') ?? 0;
        return bId.compareTo(aId);
      });

      debugPrint('Loaded ${parsedBatches.length} batches and ${parsedRaisers.length} raisers');

      if (!mounted) return;
      setState(() {
        _batchesList = parsedBatches;
        _activeRaisers = parsedRaisers;
        _isLoading = false;
        _isTableRefreshing = false;
      });
    } catch (e) {
      debugPrint('Error in _loadData: $e');
      if (mounted) {
        setState(() {
          _loadError = 'Load error: $e';
          _isLoading = false;
          _isTableRefreshing = false;
        });
      }
    }
  }

  void _showThemedSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppToast.error(context, message);
    } else {
      AppToast.success(context, message);
    }
  }

  static String _resolveStageName(dynamic stageVal, bool isBreeding) {
    final fatteningStages = const [
      'Booster',
      'Pre-Starter',
      'Starter',
      'Grower',
      'Finisher',
      'Selling',
    ];
    final sowStages = const [
      'Booster',
      'Pre-Starter',
      'Starter',
      'Grower',
      'Breeder',
      'Lactation',
    ];
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
    final isSmall = Responsive.isSmallScreen(context);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: _bgDark,
      drawer: isSmall
          ? Drawer(
              backgroundColor: _panelStart,
              child: AdminSidebar(
                currentRoute: '/batches',
                onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
                isDrawer: true,
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenTopBar(),
          Expanded(
            child: Row(
              children: [
                if (!isSmall)
                  AdminSidebar(
                    currentRoute: '/batches',
                    onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
                  ),
                Expanded(
                  child: _showBatchForm
                      ? BatchFormView(
                          onCancel: () => setState(() {
                            _showBatchForm = false;
                            _editingBatch = null;
                          }),
                          onBatchSaved: () {
                            setState(() {
                              _showBatchForm = false;
                              _editingBatch = null;
                            });
                            _loadData();
                          },
                          existingBatch: _editingBatch,
                          activeRaisers: _activeRaisers,
                          onShowSnackBar: _showThemedSnackBar,
                        )
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(isMobile ? 12 : 20),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_panelStart, _panelEnd],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              border: Border.all(color: _panelBorder, width: 1),
                              borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 14 : 26,
                              vertical: isMobile ? 16 : 26,
                            ),
                                  child: _inPageConfirmation != null
                                      ? _inPageConfirmation!
                                      : (_selectedBatchForDetails != null
                                          ? BatchDetailView(
                                              batch: _selectedBatchForDetails!,
                                              onBack: () => setState(() => _selectedBatchForDetails = null),
                                              onEdit: (batch) => setState(() {
                                                _selectedBatchForDetails = null;
                                                _showBatchForm = true;
                                                _editingBatch = batch;
                                              }),
                                              onArchive: (batch) {
                                                setState(() => _selectedBatchForDetails = null);
                                                _archiveBatch(batch);
                                              },
                                            )
                                          : BatchTableView(
                                          batches: _batchesList,
                                          searchQuery: _searchQuery,
                                          selectedStatusFilter: _selectedStatusFilter,
                                          errorMessage: _loadError,
                                          onRefresh: () => _loadData(isRefresh: true),
                                          isRefreshing: _isLoading || _isTableRefreshing,
                                          onSearchChanged: (val) => setState(() => _searchQuery = val),
                                          onFilterChanged: (val) => setState(() => _selectedStatusFilter = val),
                                          onCreateBatch: () => setState(() {
                                            _showBatchForm = true;
                                            _editingBatch = null;
                                          }),
                                          onViewDetails: (batch) => setState(() => _selectedBatchForDetails = batch),
                                          onEditBatch: (batch) => setState(() {
                                            _showBatchForm = true;
                                            _editingBatch = batch;
                                          }),
                                          onArchiveBatch: _archiveBatch,
                                          onDeleteBatch: _deleteBatch,
                                        )),
                            ),
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _archiveBatch(Map<String, dynamic> batch) {
    final batchName = batch['batch_name'] ?? 'Batch';
    final batchId = batch['batch_id'] ?? batch['id'];
    if (batchId == null) return;

    setState(() {
      _inPageConfirmation = InPageConfirmationView(
        title: 'Archive Hog Batch',
        subtitle: 'Move this hog batch to archived records.',
        message: 'Are you sure you want to archive "$batchName"?',
        actionType: InPageActionType.danger,
        customIcon: Icons.archive_outlined,
        itemTitle: batchName.toString(),
        itemSubtitle: 'Batch Code: ${batch['batch_number'] ?? batch['batch_code'] ?? 'N/A'}',
        confirmButtonText: 'Archive Batch',
        cancelButtonText: 'Cancel',
        onCancel: () => setState(() => _inPageConfirmation = null),
        onConfirm: () async {
          setState(() {
            _inPageConfirmation = null;
            _selectedBatchForDetails = null;
            _isLoading = true;
          });
          try {
            try {
              await _supabase.from('batches').update({'status': 'Archived'}).eq('batch_id', batchId);
            } catch (_) {
              await _supabase.from('batches').update({'status': 'Archived'}).eq('id', batchId);
            }

            try {
              await _supabase.from('assignments').update({'status': 'archived'}).eq('batch_id', batchId);
            } catch (_) {}

            try {
              await _supabase.from('investment_records').update({'stage': 'archived'}).eq('batch_id', batchId);
            } catch (_) {}

            _showThemedSnackBar('Batch "$batchName" archived successfully.');
            await _loadData();
          } catch (e) {
            _showThemedSnackBar('Archive failed: $e', isError: true);
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      );
    });
  }

  void _deleteBatch(Map<String, dynamic> batch) async {
    final batchName = batch['batch_name'] ?? 'Batch';
    final batchId = batch['batch_id'] ?? batch['id'];
    if (batchId == null) return;

    int activeHogsCount = 0;
    String? assignedRaiserName;
    try {
      final assignmentsRes = await _supabase
          .from('assignments')
          .select('assignment_id, status, hog_raisers(name)')
          .eq('batch_id', batchId);
      
      final activeAssignments = (assignmentsRes as List).where((a) {
        final s = (a['status'] ?? 'active').toString().toLowerCase();
        return s != 'archived' && s != 'deleted';
      }).toList();

      if (activeAssignments.isNotEmpty) {
        final firstA = activeAssignments.first;
        if (firstA['hog_raisers'] is Map) {
          final hr = firstA['hog_raisers'];
          assignedRaiserName = (hr['name'] ?? '').toString().trim();
        }
        final aIds = activeAssignments.map((a) => a['assignment_id']).toList();
        if (aIds.isNotEmpty) {
          final hogsRes = await _supabase
              .from('hogs')
              .select('hog_id')
              .inFilter('assignment_id', aIds)
              .eq('status', 'active');
          activeHogsCount = (hogsRes as List).length;
        }
      }
    } catch (e) {
      debugPrint('Active batch safety guard check error: $e');
    }

    if (activeHogsCount > 0 || (assignedRaiserName != null && assignedRaiserName.isNotEmpty)) {
      if (!mounted) return;
      final raiserText = assignedRaiserName != null && assignedRaiserName.isNotEmpty ? ' to $assignedRaiserName' : '';
      setState(() {
        _inPageConfirmation = InPageConfirmationView(
          title: 'Active Batch Protected',
          subtitle: 'Cannot delete an active batch with live hogs.',
          message: 'Cannot delete "$batchName": This batch currently has $activeHogsCount live hogs assigned$raiserText.\n\nDeleting an active batch will wipe live farm animals and cause errors on the raiser\'s mobile app.\n\nPlease complete the raising cycle or archive the batch instead.',
          actionType: InPageActionType.warning,
          customIcon: Icons.shield_outlined,
          itemTitle: batchName.toString(),
          confirmButtonText: 'I Understand',
          cancelButtonText: 'Close',
          onCancel: () => setState(() => _inPageConfirmation = null),
          onConfirm: () async => setState(() => _inPageConfirmation = null),
        );
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _inPageConfirmation = InPageConfirmationView(
        title: 'Delete Hog Batch',
        subtitle: 'Permanently remove this batch record.',
        message: 'Are you sure you want to permanently delete "$batchName"?\nThis will also remove any linked assignment records for this batch.',
        actionType: InPageActionType.danger,
        customIcon: Icons.delete_outline_rounded,
        itemTitle: batchName.toString(),
        warningText: 'This action is irreversible. All linked assignment records will be deleted immediately.',
        confirmButtonText: 'Delete Permanently',
        cancelButtonText: 'Cancel',
        onCancel: () => setState(() => _inPageConfirmation = null),
        onConfirm: () async {
          setState(() {
            _inPageConfirmation = null;
            _selectedBatchForDetails = null;
            _isLoading = true;
          });
          try {
            // 1. Cascade delete child assignments, hogs, and requests to prevent foreign key violations
            try {
              final assignmentsRes = await _supabase.from('assignments').select('assignment_id').eq('batch_id', batchId);
              final assignmentIds = (assignmentsRes as List).map((a) => a['assignment_id']).toList();

              for (var aId in assignmentIds) {
                try {
                  await _supabase.from('stock_requests').delete().eq('assignment_id', aId);
                } catch (_) {}
                try {
                  await _supabase.from('hogs').delete().eq('assignment_id', aId);
                } catch (_) {}
              }
              await _supabase.from('assignments').delete().eq('batch_id', batchId);
            } catch (cascadeErr) {
              debugPrint('Cascade cleanup assignments warning: $cascadeErr');
            }

            // 2. Cascade delete investment records
            try {
              await _supabase.from('investment_records').delete().eq('batch_id', batchId);
            } catch (_) {}
            try {
              await _supabase.from('investments').delete().eq('batch_id', batchId);
            } catch (_) {}

            // 3. Delete from batches
            try {
              await _supabase.from('batches').delete().eq('batch_id', batchId);
            } catch (_) {
              await _supabase.from('batches').delete().eq('id', batchId);
            }

            _showThemedSnackBar('Batch "$batchName" deleted successfully from database.');
            await _loadData();
          } catch (e) {
            _showThemedSnackBar('Delete failed: $e', isError: true);
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      );
    });
  }
}
