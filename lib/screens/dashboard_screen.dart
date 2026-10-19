import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/common/shimmer_loading.dart';
import '../widgets/dashboard/cycle_history_drawer.dart';
import '../utils/responsive.dart';
import '../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;

  // KPI values
  int _activeRaisers = 0;
  int _batchCount = 0;
  double _totalCapital = 0;

  // Allocation values
  double _fatteningCapital = 0;
  double _sowCapital = 0;
  List<Map<String, dynamic>> _activeRaisersList = [];

  // Theme-aware color getters
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgDark =>
      _isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
  Color get _surfaceDark =>
      _isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface;
  Color get _surfaceSoftDark => _isDark
      ? PiggyTrunkTheme.ptSurfaceSoftDark
      : PiggyTrunkTheme.ptSurfaceSoft;
  Color get _borderDark =>
      _isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
  Color get _textDark =>
      _isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText;
  Color get _mutedDark =>
      _isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

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
    isInitialLaunch = false;
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load active raisers safely (do NOT select created_at which does not exist in hog_raisers)
      List<dynamic> raisersRes = [];
      try {
        raisersRes = await _supabase
            .from('hog_raisers')
            .select('hog_raiser_id, name, pig_type, status, account_status, lifecycle_stage, user_id, app_users!hog_raisers_user_id_fkey(name, email)')
            .order('hog_raiser_id', ascending: false);
      } catch (_) {
        try {
          raisersRes = await _supabase
              .from('hog_raisers')
              .select('hog_raiser_id, name, pig_type, status, account_status, lifecycle_stage, user_id')
              .order('hog_raiser_id', ascending: false);
        } catch (rErr) {
          debugPrint('Notice loading hog_raisers: $rErr');
          try {
            raisersRes = await _supabase.from('hog_raisers').select('*');
          } catch (_) {
            raisersRes = [];
          }
        }
      }

      // 2. Fetch Batches directly for accurate batch count & name mapping
      List<dynamic> batchesRaw = [];
      try {
        batchesRaw = await _supabase.from('batches').select('batch_id, batch_name');
      } catch (bErr) {
        debugPrint('Notice loading batches: $bErr');
        try {
          batchesRaw = await _supabase.from('batches').select('*');
        } catch (_) {
          batchesRaw = [];
        }
      }

      final Map<String, String> batchesMap = {
        for (var b in batchesRaw)
          (b['batch_id'] ?? b['id'] ?? '').toString(): (b['batch_name'] ?? 'Batch #${b['batch_id']}').toString()
      };

      // 3. Load investment records to compute Admin Initial Capital
      List<dynamic> invList = [];
      try {
        invList = await _supabase
            .from('investment_records')
            .select('*')
            .order('investment_date', ascending: false);
      } catch (invErr) {
        debugPrint('Notice loading investment_records with order: $invErr');
        try {
          invList = await _supabase.from('investment_records').select('*');
        } catch (_) {
          invList = [];
        }
      }

      double calculatedInitialCapital = 0;
      double calculatedFatteningInitialCapital = 0;
      double calculatedSowInitialCapital = 0;
      final Map<String, Set<String>> raiserInvestmentTypesMap = {};
      final Map<String, DateTime> raiserLatestInvestmentDate = {};
      final Map<String, String> raiserBatchNameMap = {};

      for (var inv in invList) {
        if (inv is! Map) continue;
        final rawCap = inv['initial_capital'];
        final amt = rawCap is num
            ? rawCap.toDouble()
            : double.tryParse(rawCap?.toString() ?? '0') ?? 0;
        calculatedInitialCapital += amt;

        final ht = (inv['hog_type'] ?? '').toString().toLowerCase();
        if (ht.contains('sow') || ht.contains('inahin')) {
          calculatedSowInitialCapital += amt;
        } else {
          calculatedFatteningInitialCapital += amt;
        }

        final rId = inv['hog_raiser_id']?.toString() ?? '';
        final rawHt = (inv['hog_type'] ?? '').toString().trim();
        // Collect ALL distinct pig types per raiser (not just first)
        if (rId.isNotEmpty && rawHt.isNotEmpty) {
          raiserInvestmentTypesMap.putIfAbsent(rId, () => {}).add(rawHt);
        }

        final invDateStr = (inv['investment_date'] ?? '').toString();
        final dt = DateTime.tryParse(invDateStr);
        if (rId.isNotEmpty && dt != null) {
          if (!raiserLatestInvestmentDate.containsKey(rId) || dt.isAfter(raiserLatestInvestmentDate[rId]!)) {
            raiserLatestInvestmentDate[rId] = dt;
          }
        }

        final bName = (inv['batch_name'] ?? '').toString().trim();
        if (rId.isNotEmpty && bName.isNotEmpty && !raiserBatchNameMap.containsKey(rId)) {
          raiserBatchNameMap[rId] = bName;
        }
      }

      // Also check partner investments in `investments` (and admin_notifications fallback)
      try {
        final partnerInvRes = await _supabase.from('investments').select('amount, status');
        double partnerAmt = 0;
        for (var p in (partnerInvRes as List? ?? [])) {
          if (p is! Map) continue;
          final st = (p['status'] ?? '').toString().toLowerCase();
          if (st == 'archived' || st == 'cancelled') continue;
          partnerAmt += (p['amount'] as num?)?.toDouble() ?? 0.0;
        }

        // If direct investments table returned zero, check investment notifications
        if (partnerAmt == 0) {
          try {
            final notifsRes = await _supabase
                .from('admin_notifications')
                .select('metadata')
                .eq('type', 'investment');
            for (var n in (notifsRes as List? ?? [])) {
              if (n is! Map) continue;
              final meta = n['metadata'] as Map<String, dynamic>? ?? {};
              partnerAmt += (meta['amount'] as num?)?.toDouble() ?? 0.0;
            }
          } catch (_) {}
        }

        if (calculatedInitialCapital == 0 && partnerAmt > 0) {
          calculatedInitialCapital = partnerAmt;
          calculatedFatteningInitialCapital = partnerAmt * 0.5;
          calculatedSowInitialCapital = partnerAmt * 0.5;
        }
      } catch (piErr) {
        debugPrint('Notice loading partner investments: $piErr');
      }

      // 4. Fetch assignments and active hogs to reflect actual active batch and stage
      final Map<String, dynamic> raiserLatestAssignmentMap = {};
      final Map<String, int> raiserLatestStageIdMap = {};
      final Map<String, int> raiserSowStageIdMap = {};
      final Map<String, int> raiserFatteningStageIdMap = {};
      final Map<String, List<Map<String, dynamic>>> raiserHogsMap = {};

      try {
        List<dynamic> assignmentsRes = [];
        try {
          assignmentsRes = await _supabase
              .from('assignments')
              .select('assignment_id, batch_id, hog_raiser_id, status, assigned_date, hog_types(type_name)')
              .order('assigned_date', ascending: false);
        } catch (_) {
          assignmentsRes = await _supabase.from('assignments').select('*');
        }

        final hogsRes = await _supabase
            .from('hogs')
            .select('*')
            .eq('status', 'active');

        final Map<String, List<Map<String, dynamic>>> assignHogsMap = {};
        final Map<String, String> assignmentTypeMap = {};
        for (final assignment in assignmentsRes) {
          if (assignment is! Map) continue;
          final assignmentId = (assignment['assignment_id'] ?? assignment['id'] ?? '').toString();
          final linkedType = assignment['hog_types'];
          final typeName = linkedType is Map
              ? linkedType['type_name']?.toString().trim()
              : (linkedType is List && linkedType.isNotEmpty && linkedType.first is Map
                  ? linkedType.first['type_name']?.toString().trim()
                  : null);
          if (assignmentId.isNotEmpty && typeName != null && typeName.isNotEmpty) {
            assignmentTypeMap[assignmentId] = typeName;
          }
        }

        for (var h in (hogsRes as List? ?? [])) {
          if (h is! Map) continue;
          final aId = (h['assignment_id'] ?? '').toString();
          assignHogsMap.putIfAbsent(aId, () => []).add(Map<String, dynamic>.from(h));
        }

        for (var a in assignmentsRes) {
          if (a is! Map) continue;
          final rId = (a['hog_raiser_id'] ?? '').toString();
          if (rId.isEmpty) continue;

          final bId = (a['batch_id'] ?? '').toString();
          if (!raiserBatchNameMap.containsKey(rId) && batchesMap.containsKey(bId)) {
            raiserBatchNameMap[rId] = batchesMap[bId]!;
          }

          if (!raiserLatestAssignmentMap.containsKey(rId)) {
            raiserLatestAssignmentMap[rId] = a;

            // Gather all hogs across all assignments for this raiser
            final allRaiserHogs = <Map<String, dynamic>>[];
            for (var asgn in assignmentsRes) {
              if (asgn is! Map) continue;
              if ((asgn['hog_raiser_id'] ?? '').toString() == rId) {
                final asgnId = (asgn['assignment_id'] ?? '').toString();
                final assignmentType = assignmentTypeMap[asgnId];
                for (final rawHog in assignHogsMap[asgnId] ?? <Map<String, dynamic>>[]) {
                  final hog = Map<String, dynamic>.from(rawHog);
                  final hogType = (hog['pig_type'] ?? '').toString().trim();
                  if (hogType.isEmpty && assignmentType != null) {
                    hog['pig_type'] = assignmentType;
                  }
                  allRaiserHogs.add(hog);
                }
              }
            }

            if (allRaiserHogs.isNotEmpty) {
              allRaiserHogs.sort((x, y) => ((x['hog_id'] as num?)?.toInt() ?? 0).compareTo((y['hog_id'] as num?)?.toInt() ?? 0));
              int maxStage = 1;

              int maxSow = 1;
              int maxFat = 1;
              bool hasSow = false;
              bool hasFat = false;

              for (final hog in allRaiserHogs) {
                final sId = int.tryParse((hog['stage_id'] ?? '1').toString()) ?? 1;
                if (sId > maxStage) maxStage = sId;

                String pType = (hog['pig_type'] ?? '').toString().trim();

                if (pType.isEmpty) pType = 'Fattening';

                if (pType.toLowerCase().contains('sow') || pType.toLowerCase().contains('breed')) {
                  hasSow = true;
                  if (sId > maxSow) maxSow = sId;
                } else {
                  hasFat = true;
                  if (sId > maxFat) maxFat = sId;
                }
              }

              raiserLatestStageIdMap[rId] = maxStage;
              if (hasSow) raiserSowStageIdMap[rId] = maxSow;
              if (hasFat) raiserFatteningStageIdMap[rId] = maxFat;
              raiserHogsMap[rId] = allRaiserHogs;
            }
          }
        }
      } catch (assignErr) {
        debugPrint('Notice loading assignments & hogs for dashboard: $assignErr');
      }

      // 5. Load product prices to price stock requests accurately
      final Map<String, double> productPriceMap = {};
      try {
        final productsRes = await _supabase
            .from('inventory_products')
            .select('id, name, price, category');
        for (var p in (productsRes as List? ?? [])) {
          if (p is! Map) continue;
          final pName = (p['name'] ?? '').toString().trim().toLowerCase();
          final pCat = (p['category'] ?? '').toString().trim().toLowerCase();
          final pPrice = (p['price'] as num?)?.toDouble() ?? 0.0;
          if (pName.isNotEmpty && pPrice > 0) productPriceMap[pName] = pPrice;
          if (pCat.isNotEmpty && pPrice > 0 && !productPriceMap.containsKey(pCat)) {
            productPriceMap[pCat] = pPrice;
          }
        }
      } catch (pErr) {
        debugPrint('Notice loading product prices for dashboard: $pErr');
      }

      const double defaultFeedPrice = 1650.0;
      double calculatedStocksProvided = 0;
      double calculatedFatteningStocks = 0;
      double calculatedSowStocks = 0;

      // 6. Load approved stock requests (Stocks provided for Hog Raisers)
      try {
        final stockReqRes = await _supabase
            .from('stock_requests')
            .select('request_id, hog_raiser_id, category, quantity, feed_type, status')
            .eq('status', 'approved');

        for (var req in (stockReqRes as List? ?? [])) {
          if (req is! Map) continue;
          final qty = (req['quantity'] as num?)?.toDouble() ?? 1.0;
          final fType = (req['feed_type'] ?? '').toString().trim().toLowerCase();
          final cat = (req['category'] ?? '').toString().trim().toLowerCase();
          final rId = (req['hog_raiser_id'] ?? '').toString();

          final unitPrice = productPriceMap[fType] ??
              productPriceMap[cat] ??
              defaultFeedPrice;

          final totalReqValue = qty * unitPrice;
          calculatedStocksProvided += totalReqValue;

          final raiserTypes = raiserInvestmentTypesMap[rId] ?? {};
          final raiserTypeStr = raiserTypes.join(' ').toLowerCase();
          if (raiserTypeStr.contains('sow') || raiserTypeStr.contains('inahin')) {
            calculatedSowStocks += totalReqValue;
          } else {
            calculatedFatteningStocks += totalReqValue;
          }
        }
      } catch (sErr) {
        debugPrint('Notice loading stock requests for dashboard: $sErr');
      }

      // 7. Also include sales marked as raiser_distribution if any
      try {
        final distSalesRes = await _supabase
            .from('sales')
            .select('total_amount, hog_raiser_id, type')
            .eq('type', 'raiser_distribution');

        for (var s in (distSalesRes as List? ?? [])) {
          if (s is! Map) continue;
          final amt = (s['total_amount'] as num?)?.toDouble() ?? 0.0;
          final rId = (s['hog_raiser_id'] ?? '').toString();
          calculatedStocksProvided += amt;
          final raiserTypes = raiserInvestmentTypesMap[rId] ?? {};
          final raiserTypeStr = raiserTypes.join(' ').toLowerCase();
          if (raiserTypeStr.contains('sow') || raiserTypeStr.contains('inahin')) {
            calculatedSowStocks += amt;
          } else {
            calculatedFatteningStocks += amt;
          }
        }
      } catch (salesErr) {
        debugPrint('Notice loading distribution sales for dashboard: $salesErr');
      }

      final double calculatedTotalCapital = calculatedInitialCapital + calculatedStocksProvided;
      final double calculatedFatteningCapital = calculatedFatteningInitialCapital + calculatedFatteningStocks;
      final double calculatedSowCapital = calculatedSowInitialCapital + calculatedSowStocks;

      // Filter active raisers accurately matching Hog Raiser screen
      final allRaiserMaps = (raisersRes as List? ?? []).whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList();
      final activeList = allRaiserMaps.where((r) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        final accStatus = (r['account_status'] ?? '').toString().toLowerCase();
        if (status == 'archived' || accStatus == 'archived') return false;
        if (status == 'pending' || accStatus == 'pending') return false;
        return status == 'active' || accStatus == 'active' || accStatus == 'approved';
      }).toList();

      final displayRaisers = activeList.isNotEmpty ? activeList : allRaiserMaps.where((r) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        return status != 'archived';
      }).toList();

      if (mounted) {
        final list = displayRaisers.map((r) {
          final copy = Map<String, dynamic>.from(r);
          final idStr = (copy['hog_raiser_id'] ?? '').toString();

          // Resolve display name: Prioritize profile full name in hog_raisers (e.g. "Rosario, Mark Rejie J.")
          // over Google OAuth / Gmail account name (e.g. "rej")
          final appUsers = copy['app_users'] as Map<String, dynamic>?;
          final gName = (appUsers?['name'] ?? '').toString().trim();
          final rName = (copy['name'] ?? '').toString().trim();
          final fName = (copy['first_name'] ?? '').toString().trim();
          final lName = (copy['last_name'] ?? '').toString().trim();
          final combinedName = [fName, lName].where((s) => s.isNotEmpty).join(' ').trim();

          if (rName.isNotEmpty &&
              rName.toLowerCase() != 'hog raiser' &&
              rName.toUpperCase() != 'N/A') {
            copy['name'] = rName;
          } else if (combinedName.isNotEmpty) {
            copy['name'] = combinedName;
          } else if (gName.isNotEmpty &&
              gName.toLowerCase() != 'hog raiser' &&
              gName.toUpperCase() != 'N/A') {
            copy['name'] = gName;
          } else if (rName.isNotEmpty) {
            copy['name'] = rName;
          } else {
            copy['name'] = 'Hog Raiser';
          }

          // Merge hog_raisers.pig_type with ALL investment hog_types for this raiser
          final dbPigType = (copy['pig_type'] ?? '').toString().trim();
          final combinedTypeSet = <String>{};
          // 1. Add types from hog_raisers.pig_type
          if (dbPigType.isNotEmpty && dbPigType.toUpperCase() != 'N/A') {
            combinedTypeSet.addAll(
              dbPigType.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty),
            );
          }
          // 2. Add ALL types from investment_records
          if (raiserInvestmentTypesMap.containsKey(idStr)) {
            combinedTypeSet.addAll(raiserInvestmentTypesMap[idStr]!);
          }
          final rawType = combinedTypeSet.join(', ');

          final cleanParts = rawType
              .split(RegExp(r'[,;]'))
              .map((p) => p.trim())
              .where((p) =>
                  p.isNotEmpty &&
                  p.toUpperCase() != 'N/A' &&
                  p.toLowerCase() != 'null' &&
                  p.toUpperCase() != 'NONE' &&
                  p.toUpperCase() != 'UNASSIGNED')
              .map((s) {
                final l = s.toLowerCase();
                if (l.contains('sow') || l.contains('breed')) return 'Sow';
                if (l.contains('fatten')) return 'Fattening';
                return s;
              })
              .toSet()
              .toList();

          final cleanedType = cleanParts.isEmpty ? 'N/A' : cleanParts.join(', ');
          copy['pig_type'] = cleanedType;
          final isBreeding = cleanedType.toLowerCase().contains('sow');

          // Attach actual current stage if active hogs exist
          if (raiserLatestStageIdMap.containsKey(idStr)) {
            copy['lifecycle_stage'] = _resolveStageName(raiserLatestStageIdMap[idStr], isBreeding);
          }
          if (raiserSowStageIdMap.containsKey(idStr)) {
            copy['sow_lifecycle_stage'] = _resolveStageName(raiserSowStageIdMap[idStr], true);
          }
          if (raiserFatteningStageIdMap.containsKey(idStr)) {
            copy['fattening_lifecycle_stage'] = _resolveStageName(raiserFatteningStageIdMap[idStr], false);
          }
          copy['hogs'] = raiserHogsMap[idStr] ?? [];

          // Attach batch name (align with mobile app fallback if batches table is empty)
          if (raiserBatchNameMap.containsKey(idStr)) {
            copy['batch_name'] = raiserBatchNameMap[idStr];
          } else if (raiserLatestAssignmentMap.containsKey(idStr)) {
            final aMap = raiserLatestAssignmentMap[idStr];
            final bId = (aMap?['batch_id'] ?? '').toString();
            copy['batch_name'] = batchesMap[bId] ?? (bId.isNotEmpty ? 'Batch #$bId' : 'Batch ${copy['name']}');
          } else {
            copy['batch_name'] = 'Unassigned';
          }

          // Calculate recency date for sorting (latest first)
          DateTime? recencyDate = raiserLatestInvestmentDate[idStr];
          if (recencyDate == null && raiserLatestAssignmentMap.containsKey(idStr)) {
            final aDate = (raiserLatestAssignmentMap[idStr]?['assigned_date'] ?? '').toString();
            recencyDate = DateTime.tryParse(aDate);
          }
          copy['_recency_date'] = recencyDate;

          return copy;
        }).toList();

        // Sort: Current / newest at the top (nasa una), earlier at the bottom (nasa last)
        list.sort((a, b) {
          final DateTime? dateA = a['_recency_date'];
          final DateTime? dateB = b['_recency_date'];

          if (dateA != null && dateB != null) {
            final cmp = dateB.compareTo(dateA); // newest first
            if (cmp != 0) return cmp;
          } else if (dateA != null) {
            return -1;
          } else if (dateB != null) {
            return 1;
          }

          final idA = int.tryParse((a['hog_raiser_id'] ?? '0').toString()) ?? 0;
          final idB = int.tryParse((b['hog_raiser_id'] ?? '0').toString()) ?? 0;
          return idB.compareTo(idA);
        });

        // Align with mobile app: if batches table is empty, each active raiser represents an active batch
        final calculatedBatchCount = batchesRaw.isNotEmpty
            ? batchesRaw.length
            : (invList.isNotEmpty ? invList.length : list.length);

        setState(() {
          _activeRaisers = list.length;
          _batchCount = calculatedBatchCount;
          _totalCapital = calculatedTotalCapital;
          _fatteningCapital = calculatedFatteningCapital;
          _sowCapital = calculatedSowCapital;
          _activeRaisersList = list;
        });
      }
    } catch (e) {
      debugPrint('Notice loading dashboard data: $e. Using fallback...');
      await _loadDashboardFallback();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Fallback: query each table individually with maximum safety
  Future<void> _loadDashboardFallback() async {
    try {
      List<dynamic> raisers = [];
      try {
        raisers = await _supabase.from('hog_raisers').select('hog_raiser_id, name, pig_type, status, account_status, lifecycle_stage');
      } catch (_) {
        raisers = [];
      }

      List<dynamic> batches = [];
      try {
        batches = await _supabase.from('batches').select('batch_id, batch_name');
      } catch (_) {
        batches = [];
      }

      List<dynamic> investmentRows = [];
      try {
        investmentRows = await _supabase.from('investment_records').select('*');
      } catch (_) {
        investmentRows = [];
      }

      if (!mounted) return;

      final activeRaisers = raisers.whereType<Map>().where((r) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        final accStatus = (r['account_status'] ?? '').toString().toLowerCase();
        if (status == 'archived' || accStatus == 'archived') return false;
        return status == 'active' || accStatus == 'active' || accStatus == 'approved';
      }).toList();

      double initialCapital = 0;
      double fatteningInitialCapital = 0;
      double sowInitialCapital = 0;
      final Map<String, Set<String>> raiserInvestmentTypeMap = {};

      for (final row in investmentRows) {
        if (row is! Map) continue;
        final rawCap = row['initial_capital'];
        final amt = rawCap is num
            ? rawCap.toDouble()
            : double.tryParse(rawCap?.toString() ?? '0') ?? 0;
        initialCapital += amt;
        final ht = (row['hog_type'] ?? '').toString().toLowerCase();
        if (ht.contains('sow') || ht.contains('inahin')) {
          sowInitialCapital += amt;
        } else {
          fatteningInitialCapital += amt;
        }

        final rId = row['hog_raiser_id']?.toString() ?? '';
        final rawHt = (row['hog_type'] ?? '').toString().trim();
        if (rId.isNotEmpty && rawHt.isNotEmpty) {
          raiserInvestmentTypeMap.putIfAbsent(rId, () => {}).add(rawHt);
        }
      }

      double stocksProvided = 0;
      double fatteningStocks = 0;
      double sowStocks = 0;

      try {
        final stockReqRes = await _supabase
            .from('stock_requests')
            .select('hog_raiser_id, category, quantity, feed_type, status')
            .eq('status', 'approved');

        for (var req in (stockReqRes as List? ?? [])) {
          if (req is! Map) continue;
          final qty = (req['quantity'] as num?)?.toDouble() ?? 1.0;
          final val = qty * 1650.0;
          stocksProvided += val;
          final rId = (req['hog_raiser_id'] ?? '').toString();
          final raiserTypes = raiserInvestmentTypeMap[rId] ?? {};
          final raiserTypeStr = raiserTypes.join(' ').toLowerCase();
          if (raiserTypeStr.contains('sow') || raiserTypeStr.contains('inahin')) {
            sowStocks += val;
          } else {
            fatteningStocks += val;
          }
        }
      } catch (_) {}

      final double totalCapital = initialCapital + stocksProvided;
      final double fatteningCapital = fatteningInitialCapital + fatteningStocks;
      final double sowCapital = sowInitialCapital + sowStocks;

      final cleanedActiveRaisers = (activeRaisers.isNotEmpty ? activeRaisers : raisers.whereType<Map>().toList()).map((r) {
        final copy = Map<String, dynamic>.from(r);
        final rawType = (copy['pig_type'] ?? '').toString().trim();
        final cleanParts = rawType
            .split(RegExp(r'[,;]'))
            .map((p) => p.trim())
            .where((p) =>
                p.isNotEmpty &&
                p.toUpperCase() != 'N/A' &&
                p.toLowerCase() != 'null' &&
                p.toUpperCase() != 'NONE' &&
                p.toUpperCase() != 'UNASSIGNED')
            .map((s) {
              final l = s.toLowerCase();
              if (l.contains('sow') || l.contains('breed')) return 'Sow';
              if (l.contains('fatten')) return 'Fattening';
              return s;
            })
            .toSet()
            .toList();
        final cleanedType = cleanParts.isEmpty ? 'N/A' : cleanParts.join(', ');
        copy['pig_type'] = cleanedType;
        copy['batch_name'] = 'Batch ${copy['name']}';
        return copy;
      }).toList();

      // Sort newest / current first in fallback too
      cleanedActiveRaisers.sort((a, b) {
        final idA = int.tryParse((a['hog_raiser_id'] ?? '0').toString()) ?? 0;
        final idB = int.tryParse((b['hog_raiser_id'] ?? '0').toString()) ?? 0;
        return idB.compareTo(idA);
      });

      final calculatedFallbackBatches = batches.isNotEmpty
          ? batches.length
          : (investmentRows.isNotEmpty ? investmentRows.length : cleanedActiveRaisers.length);

      setState(() {
        _activeRaisers = cleanedActiveRaisers.length;
        _batchCount = calculatedFallbackBatches;
        _totalCapital = totalCapital;
        _fatteningCapital = fatteningCapital;
        _sowCapital = sowCapital;
        _activeRaisersList = cleanedActiveRaisers;
      });
    } catch (_) {
      // Leave defaults at 0 if fallback also fails
    }
  }

  String _formatCurrency(double value) {
    if (value == 0) return '₱0';
    final formatted = value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '₱$formatted';
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = Responsive.isSmallScreen(context);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: _bgDark,
      drawer: isSmall
          ? Drawer(
              backgroundColor: _surfaceDark,
              child: AdminSidebar(
                currentRoute: '/dashboard',
                onLogout: () =>
                    Navigator.of(context).pushReplacementNamed('/login'),
                isDrawer: true,
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// REUSABLE TOP BAR
          const ScreenTopBar(),
          Expanded(
            child: Row(
              children: [
                if (!isSmall)
                  AdminSidebar(
                    currentRoute: '/dashboard',
                    onLogout: () =>
                        Navigator.of(context).pushReplacementNamed('/login'),
                  ),

                /// MAIN DASHBOARD CONTENT
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 14 : 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final contentWidth = constraints.maxWidth > 1400
                            ? 1400.0
                            : constraints.maxWidth;
                        return Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: contentWidth,
                            decoration: isMobile
                                ? null
                                : BoxDecoration(
                                    color: _surfaceDark.withValues(alpha: 0.5),
                                    border: Border.all(
                                      color: _borderDark,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                            padding: EdgeInsets.all(isMobile ? 0 : 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /// Dashboard Title + Refresh (Steady Header)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Dashboard',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: isMobile ? 22 : 30,
                                        fontWeight: FontWeight.w800,
                                        color: _textDark,
                                        letterSpacing: -0.04,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _loadDashboardData,
                                      icon: _isLoading
                                          ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: _isDark
                                                    ? Colors.white
                                                    : PiggyTrunkTheme.ptPrimary,
                                              ),
                                            )
                                          : Icon(
                                              Icons.refresh_rounded,
                                              color: _mutedDark,
                                            ),
                                      tooltip: 'Refresh',
                                    ),
                                  ],
                                ),
                                SizedBox(height: isMobile ? 14 : 24),

                                if (_isLoading)
                                  _buildDashboardSkeletonContent(isMobile)
                                else ...[
                                  /// KPI CARDS ROW
                                  _buildKpiCardsRow(),
                                  SizedBox(height: isMobile ? 20 : 32),

                                  /// INVESTMENT ALLOCATION SECTION
                                  _buildInvestmentAllocationSection(),
                                  SizedBox(height: isMobile ? 20 : 32),

                                  /// ACTIVE HOG RAISERS PROGRESS SECTION
                                  _buildActiveRaisersSection(),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
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

  /// KPI CARDS ROW — driven by live Supabase data (Admin Capital + Stocks Provided)
  Widget _buildKpiCardsRow() {
    final isMobile = Responsive.isMobile(context);
    final kpiData = [
      {'label': 'NUMBER OF HOG BATCH', 'value': _batchCount.toString()},
      {
        'label': 'TOTAL CURRENT INVESTMENT',
        'value': _formatCurrency(_totalCapital),
      },
    ];

    final isVeryNarrow = MediaQuery.of(context).size.width < 500;

    if (isVeryNarrow) {
      return Column(
        children: [
          _buildKpiCard(
            label: kpiData[0]['label'] as String,
            value: kpiData[0]['value'] as String,
            isMobile: isMobile,
          ),
          const SizedBox(height: 12),
          _buildKpiCard(
            label: kpiData[1]['label'] as String,
            value: kpiData[1]['value'] as String,
            isMobile: isMobile,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            label: kpiData[0]['label'] as String,
            value: kpiData[0]['value'] as String,
            isMobile: isMobile,
          ),
        ),
        SizedBox(width: isMobile ? 12 : 20),
        Expanded(
          child: _buildKpiCard(
            label: kpiData[1]['label'] as String,
            value: kpiData[1]['value'] as String,
            isMobile: isMobile,
          ),
        ),
      ],
    );
  }

  /// Individual KPI Card
  Widget _buildKpiCard({
    required String label,
    required String value,
    bool isMobile = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: _surfaceDark,
        border: Border.all(color: _borderDark, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isMobile ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: _mutedDark,
              letterSpacing: 0.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isMobile ? 8 : 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isMobile ? 22 : 28,
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// INVESTMENT ALLOCATION SECTION — driven by live Admin investment + stocks data
  Widget _buildInvestmentAllocationSection() {
    final isMobile = Responsive.isMobile(context);
    final isVeryNarrow = MediaQuery.of(context).size.width < 500;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 32),
      decoration: BoxDecoration(
        color: _surfaceDark.withValues(alpha: 0.2),
        border: Border.all(color: _borderDark, width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'INVESTMENT ALLOCATION',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Total: ${_formatCurrency(_totalCapital)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 11 : 13,
                  fontWeight: FontWeight.w600,
                  color: _mutedDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$_activeRaisers active raiser${_activeRaisers == 1 ? '' : 's'}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.w500,
              color: _mutedDark,
            ),
          ),
          SizedBox(height: isMobile ? 14 : 20),
          if (isVeryNarrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAllocationCard(
                  title: 'FATTENING',
                  amount: _formatCurrency(_fatteningCapital),
                  isMobile: isMobile,
                ),
                const SizedBox(height: 12),
                _buildAllocationCard(
                  title: 'SOW',
                  amount: _formatCurrency(_sowCapital),
                  isMobile: isMobile,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildAllocationCard(
                    title: 'FATTENING',
                    amount: _formatCurrency(_fatteningCapital),
                    isMobile: isMobile,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 24),
                Expanded(
                  child: _buildAllocationCard(
                    title: 'SOW',
                    amount: _formatCurrency(_sowCapital),
                    isMobile: isMobile,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Individual Allocation Card with Top Border Accent
  Widget _buildAllocationCard({
    required String title,
    required String amount,
    double? width,
    bool isMobile = false,
  }) {
    return Container(
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _surfaceDark,
        border: Border.all(color: _borderDark, width: 1),
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isMobile ? 11 : 14,
              fontWeight: FontWeight.w700,
              color: _mutedDark,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isMobile ? 20 : 26,
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isRaiserCycleCompleted(Map<String, dynamic> raiser) {
    final raiserHogs = (raiser['hogs'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    if (raiserHogs.isNotEmpty) {
      return raiserHogs.every((h) {
        final rawHType = (h['pig_type'] ?? '').toString().trim();
        final hIsBreed = rawHType.toLowerCase().contains('sow') || rawHType.toLowerCase().contains('breed');
        final stage = _resolveStageName(h['stage_id'] ?? h['lifecycle_stage'], hIsBreed).toLowerCase();
        return stage == 'selling' || stage == 'lactation' || stage == 'completed';
      });
    }
    final rawType = (raiser['pig_type'] ?? '').toString().trim();
    final isBreed = rawType.toLowerCase().contains('sow') || rawType.toLowerCase().contains('breed');
    final currentStage = _resolveStageName(raiser['lifecycle_stage'], isBreed).toLowerCase();
    return currentStage == 'selling' || currentStage == 'lactation' || currentStage == 'completed';
  }

  bool _isRaiserAssignedToBatch(Map<String, dynamic> raiser) {
    final raiserHogs = (raiser['hogs'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    if (raiserHogs.isNotEmpty) return true;

    final batchName = (raiser['batch_name'] ?? '').toString().trim().toLowerCase();
    final bool hasValidBatch = batchName.isNotEmpty &&
        batchName != 'unassigned' &&
        batchName != 'no batch' &&
        batchName != 'none' &&
        !batchName.startsWith('batch ${raiser['name']?.toString().toLowerCase()}');

    final rawType = (raiser['pig_type'] ?? '').toString().trim().toLowerCase();
    final bool hasValidType = rawType.isNotEmpty &&
        rawType != 'n/a' &&
        rawType != 'null' &&
        rawType != 'none' &&
        rawType != 'unassigned';

    return hasValidBatch && hasValidType;
  }

  /// ACTIVE HOG RAISERS PROGRESS SECTION - Displays ongoing feeding cycles with Cycle History drawer trigger
  Widget _buildActiveRaisersSection() {
    final isMobile = Responsive.isMobile(context);
    final assignedRaisers = _activeRaisersList.where(_isRaiserAssignedToBatch).toList();
    final inProgressRaisers = assignedRaisers.where((r) => !_isRaiserCycleCompleted(r)).toList();
    final completedRaisers = assignedRaisers.where((r) => _isRaiserCycleCompleted(r)).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      decoration: BoxDecoration(
        color: _surfaceDark,
        border: Border.all(color: _borderDark, width: 1),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ACTIVE HOG RAISERS PROGRESS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monitor ongoing feeding cycles for all active raisers',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.w500,
                        color: _mutedDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => CycleHistoryDrawer.show(
                  context: context,
                  completedRaisers: completedRaisers,
                  onNavigateToBatches: () => Navigator.of(context).pushNamed('/batches'),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 13,
                    vertical: isMobile ? 6 : 7.5,
                  ),
                  decoration: BoxDecoration(
                    color: _isDark
                        ? PiggyTrunkTheme.ptSurfaceSoftDark
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isDark
                          ? PiggyTrunkTheme.ptBorderDark
                          : const Color(0xFFDDE3EC),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: _isDark ? 0.15 : 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: isMobile ? 14 : 16,
                        color: _isDark
                            ? PiggyTrunkTheme.ptTextDark
                            : PiggyTrunkTheme.ptPrimary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Finished Lifecycles',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 11.5 : 12.5,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      if (completedRaisers.isNotEmpty) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _isDark
                                ? const Color(0xFF064E3B)
                                : const Color(0xFFDEF7EC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isDark
                                  ? const Color(0xFF059669).withValues(alpha: 0.4)
                                  : const Color(0xFF31C48D).withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            completedRaisers.length.toString(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _isDark
                                  ? const Color(0xFFA7F3D0)
                                  : const Color(0xFF03543F),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(
            color: _borderDark.withValues(alpha: 0.6),
            height: 1,
            thickness: 1,
          ),
          const SizedBox(height: 24),
          if (inProgressRaisers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 40,
                      color: const Color(0xFF10B981).withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All Batches Currently Finished',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'All approved raisers have completed their lifecycles and are archived.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _mutedDark,
                      ),
                    ),
                    if (completedRaisers.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => CycleHistoryDrawer.show(
                          context: context,
                          completedRaisers: completedRaisers,
                          onNavigateToBatches: () => Navigator.of(context).pushNamed('/batches'),
                        ),
                        icon: const Icon(Icons.history_rounded, size: 15),
                        label: Text('View Finished Lifecycles (${completedRaisers.length})'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: inProgressRaisers.length,
              separatorBuilder: (context, index) => Divider(
                color: _borderDark.withValues(alpha: 0.5),
                height: 32,
              ),
              itemBuilder: (context, index) {
                final raiser = inProgressRaisers[index];
                final name = (raiser['name'] ?? 'Hog Raiser').toString();
                final rawPigType = (raiser['pig_type'] ?? '').toString().trim();
                final cleanList = rawPigType
                    .split(RegExp(r'[,;]'))
                    .map((s) => s.trim())
                    .where(
                      (s) =>
                          s.isNotEmpty &&
                          s.toUpperCase() != 'N/A' &&
                          s.toLowerCase() != 'null' &&
                          s.toUpperCase() != 'NONE' &&
                          s.toUpperCase() != 'UNASSIGNED',
                    )
                    .map((s) {
                      final l = s.toLowerCase();
                      if (l.contains('sow') || l.contains('breed')) {
                        return 'SOW';
                      }
                      if (l.contains('fatten')) {
                        return 'FATTENING';
                      }
                      return s.toUpperCase();
                    })
                    .toSet()
                    .toList();
                final bool isUnassigned = cleanList.isEmpty;
                final currentStage = isUnassigned
                    ? 'Unassigned'
                    : (raiser['lifecycle_stage'] ?? 'Booster').toString();

                final batchName = (raiser['batch_name'] ?? '')
                    .toString()
                    .trim();

                final raiserHogs = (raiser['hogs'] as List? ?? []).whereType<Map<String, dynamic>>().toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (batchName.isNotEmpty &&
                            batchName != 'Unassigned')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: _isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFCBD5E1),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              batchName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (raiserHogs.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: raiserHogs.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final h = entry.value;
                          final tag = h['tag_number'] ?? '#${idx + 1}';
                          final rawHType = (h['pig_type'] ?? '').toString().trim();
                          final hType = rawHType.isNotEmpty ? rawHType : 'Fattening';
                          final hIsBreed = hType.toLowerCase().contains('sow') || hType.toLowerCase().contains('breed');
                          final ptKey = hIsBreed ? 'sow' : 'fattening';
                          final stageForHog = _resolveStageName(h['stage_id'] ?? h['lifecycle_stage'], hIsBreed);
                          final isHogDone = stageForHog.toLowerCase() == 'selling' || stageForHog.toLowerCase() == 'lactation';

                          return Container(
                            margin: EdgeInsets.only(top: idx > 0 ? 18 : 0),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _isDark ? const Color(0xFF26354A) : const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.pets_rounded,
                                          size: 15,
                                          color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          'Hog $tag',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: _textDark,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: _isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            ptKey == 'sow' ? 'SOW / BREEDING' : 'FATTENING',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isHogDone)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: _isDark ? 0.22 : 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFF10B981).withValues(alpha: _isDark ? 0.6 : 0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF10B981)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'COMPLETE',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF10B981),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _buildLifecycleMap(
                                  stageForHog,
                                  ptKey,
                                  isUnassigned: false,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: () {
                          // Determine which pig types to show lifecycles for
                          final types = cleanList.isNotEmpty
                              ? cleanList
                              : ['FATTENING'];
                          final widgets = <Widget>[];
                          for (int i = 0; i < types.length; i++) {
                            final pt = types[i];
                            final ptKey = pt.toLowerCase().contains('sow') ||
                                    pt.toLowerCase().contains('breed')
                                ? 'sow'
                                : 'fattening';
                            if (i > 0) {
                              widgets.add(const SizedBox(height: 16));
                            }
                            // Always show pig type label above lifecycle
                            {
                              widgets.add(
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _isDark
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: _isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFCBD5E1),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          ptKey == 'sow'
                                              ? 'SOW / BREEDING'
                                              : 'FATTENING',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: _isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            widgets.add(
                              _buildLifecycleMap(
                                currentStage,
                                ptKey,
                                isUnassigned: false,
                              ),
                            );
                          }
                          return widgets;
                        }(),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  String pigTypeString(String raw) {
    if (raw.toLowerCase().contains('sow')) return 'sow';
    return 'fattening';
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

  Widget _buildLifecycleMap(
    String currentStage,
    String pigType, {
    bool isUnassigned = false,
  }) {
    final List<String> lifecycleStages = pigType.toLowerCase() == 'sow'
        ? [
            'Booster',
            'Pre-Starter',
            'Starter',
            'Grower',
            'Breeder',
            'Lactation',
          ]
        : [
            'Booster',
            'Pre-Starter',
            'Starter',
            'Grower',
            'Finisher',
            'Selling',
          ];
    final activeIndex = isUnassigned
        ? -1
        : lifecycleStages.indexWhere(
            (stage) => stage.toLowerCase() == currentStage.toLowerCase(),
          );
    final normalizedIndex = isUnassigned
        ? -1
        : (activeIndex < 0 ? 0 : activeIndex);
    final bool isLastStageReached = !isUnassigned && normalizedIndex == lifecycleStages.length - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        Widget buildStepContent(int index) {
          final stage = lifecycleStages[index];
          final isDone = !isUnassigned && (index < normalizedIndex || isLastStageReached);
          final isCurrent = !isUnassigned && index == normalizedIndex && !isLastStageReached;

          Color bgColor;
          Color fgColor;
          IconData icon;
          if (isDone) {
            bgColor = const Color(0xFF10B981);
            fgColor = Colors.white;
            icon = Icons.check;
          } else if (isCurrent) {
            bgColor = _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;
            fgColor = _isDark ? const Color(0xFF0F172A) : Colors.white;
            icon = Icons.priority_high_rounded;
          } else {
            bgColor = _isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFE2E8F0);
            fgColor = _isDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B);
            icon = isUnassigned
                ? Icons.lock_outline_rounded
                : Icons.radio_button_unchecked;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(
                          color: _isDark
                              ? Colors.white
                              : PiggyTrunkTheme.ptPrimary,
                          width: 2,
                        )
                      : null,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color:
                                (_isDark
                                        ? Colors.white
                                        : PiggyTrunkTheme.ptPrimary)
                                    .withValues(alpha: 0.25),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Center(child: Icon(icon, size: 20, color: fgColor)),
              ),
              const SizedBox(height: 8),
              Text(
                stage,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: isCurrent
                      ? FontWeight.w800
                      : (isDone ? FontWeight.w700 : FontWeight.w600),
                  color: isCurrent
                      ? (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
                      : (isDone ? _textDark : _mutedDark),
                ),
              ),
            ],
          );
        }

        if (isMobile) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(lifecycleStages.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == lifecycleStages.length - 1 ? 0 : 20,
                  ),
                  child: SizedBox(width: 76, child: buildStepContent(index)),
                );
              }),
            ),
          );
        }

        // On Desktop: Evenly spaced across the card with connecting line
        final totalWidth = constraints.maxWidth;
        final stepWidth = totalWidth / lifecycleStages.length;

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            // Connecting line positioned at vertical center of 44px circles (top: 21)
            Positioned(
              top: 21,
              left: stepWidth / 2,
              right: stepWidth / 2,
              child: Row(
                children: List.generate(lifecycleStages.length - 1, (index) {
                  final isPassed = !isUnassigned && (index < normalizedIndex || isLastStageReached);
                  return Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: isPassed
                            ? const Color(0xFF10B981)
                            : (_isDark ? const Color(0xFF334A66) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Step nodes
            Row(
              children: List.generate(lifecycleStages.length, (index) {
                return Expanded(child: Center(child: buildStepContent(index)));
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardSkeletonContent(bool isMobile) {
    final isVeryNarrow = MediaQuery.of(context).size.width < 500;

    return ShimmerProvider(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2 Real KPI Cards (NUMBER OF HOG BATCH & TOTAL CURRENT INVESTMENT)
          if (isVeryNarrow)
            Column(
              children: [
                _buildSkeletonKpiCard(isMobile, 'NUMBER OF HOG BATCH', 60),
                const SizedBox(height: 12),
                _buildSkeletonKpiCard(
                  isMobile,
                  'TOTAL CURRENT INVESTMENT',
                  120,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildSkeletonKpiCard(
                    isMobile,
                    'NUMBER OF HOG BATCH',
                    60,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 20),
                Expanded(
                  child: _buildSkeletonKpiCard(
                    isMobile,
                    'TOTAL CURRENT INVESTMENT',
                    120,
                  ),
                ),
              ],
            ),
          SizedBox(height: isMobile ? 20 : 32),

          // Real Investment Allocation Card (FATTENING & SOW)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 14 : 32),
            decoration: BoxDecoration(
              color: _surfaceDark,
              border: Border.all(color: _borderDark, width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INVESTMENT ALLOCATION',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: _mutedDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ShimmerBox(
                          width: 85,
                          height: 11,
                          borderRadius: BorderRadius.circular(3),
                          isDark: _isDark,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Total: ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isMobile ? 12 : 14,
                            color: _mutedDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ShimmerBox(
                          width: 70,
                          height: 14,
                          borderRadius: BorderRadius.circular(4),
                          isDark: _isDark,
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 16 : 28),
                if (isVeryNarrow)
                  Column(
                    children: [
                      _buildSkeletonSubCard('FATTENING', 120, isMobile),
                      const SizedBox(height: 12),
                      _buildSkeletonSubCard('SOW', 60, isMobile),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildSkeletonSubCard(
                          'FATTENING',
                          120,
                          isMobile,
                        ),
                      ),
                      SizedBox(width: isMobile ? 12 : 20),
                      Expanded(
                        child: _buildSkeletonSubCard('SOW', 60, isMobile),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 20 : 32),

          // Active Hog Raisers Progress Skeleton Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 16 : 32),
            decoration: BoxDecoration(
              color: _surfaceDark,
              border: Border.all(color: _borderDark, width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ACTIVE HOG RAISERS PROGRESS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.bold,
                        color: _mutedDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    ShimmerBox(
                      width: 100,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                      isDark: _isDark,
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 18 : 28),
                Row(
                  children: List.generate(isMobile ? 3 : 5, (index) {
                    return Expanded(
                      child: Column(
                        children: [
                          ShimmerBox(
                            width: 44,
                            height: 44,
                            shape: BoxShape.circle,
                            isDark: _isDark,
                          ),
                          const SizedBox(height: 8),
                          ShimmerBox(
                            width: 50,
                            height: 12,
                            borderRadius: BorderRadius.circular(4),
                            isDark: _isDark,
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonKpiCard(bool isMobile, String label, double valueWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: _surfaceDark,
        border: Border.all(color: _borderDark, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isMobile ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: _mutedDark,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: isMobile ? 8 : 16),
          ShimmerBox(
            width: valueWidth,
            height: isMobile ? 22 : 28,
            borderRadius: BorderRadius.circular(6),
            isDark: _isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonSubCard(String label, double valueWidth, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: _surfaceSoftDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isMobile ? 10 : 12,
              fontWeight: FontWeight.bold,
              color: _mutedDark,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          ShimmerBox(
            width: valueWidth,
            height: isMobile ? 20 : 26,
            borderRadius: BorderRadius.circular(6),
            isDark: _isDark,
          ),
        ],
      ),
    );
  }
}
