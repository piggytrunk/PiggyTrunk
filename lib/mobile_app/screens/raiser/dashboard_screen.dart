import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:piggytrunk/services/notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_session_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/location_service.dart';
import '../../utils/capitalization_formatters.dart';
import '../../utils/app_strings.dart';
import '../../widgets/piggy_toast.dart';
import '../../widgets/address_autocomplete_field.dart';

import 'tabs/raiser_home_tab.dart';
import 'tabs/raiser_request_tab.dart';
import 'tabs/raiser_hogs_tab.dart';
import 'tabs/raiser_profile_tab.dart';
import 'widgets/raiser_dashboard_skeleton.dart';
import 'widgets/raiser_liquid_bottom_bar.dart';

class MobileDashboardScreen extends StatefulWidget {
  const MobileDashboardScreen({super.key});

  @override
  State<MobileDashboardScreen> createState() => _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends State<MobileDashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic> _raiserData = {};
  double _investedAmount = 0.0;
  double _initialCapital = 0.0;
  double _stocksSpendAmount = 0.0;
  List<Map<String, dynamic>> _providedStocksList = [];
  List<Map<String, dynamic>> _hogsList = [];
  List<Map<String, dynamic>> _requestsList = [];
  List<Map<String, dynamic>> _activeAssignments = [];
  List<Map<String, dynamic>> _reportsList = [];
  List<Map<String, dynamic>> _notificationsList = [];

  BigInt? _selectedAssignmentId;
  String? _errorMessage;
  DateTime? _lastBackPressTime;

  static const Color _brandColor = Color(0xFF18314F);

  RealtimeChannel? _dashboardAssignmentsChannel;

  @override
  void initState() {
    super.initState();
    _fetchRaiserData();
    _subscribeToAssignmentsRealtime();
  }

  void _subscribeToAssignmentsRealtime() {
    try {
      _dashboardAssignmentsChannel = Supabase.instance.client
          .channel(
            'public:dashboard_assignments_${DateTime.now().millisecondsSinceEpoch}',
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'assignments',
            callback: (payload) {
              debugPrint(
                'Dashboard realtime: assignments updated, refreshing silently...',
              );
              if (mounted) _fetchRaiserData(showLoading: false);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'batches',
            callback: (payload) {
              debugPrint(
                'Dashboard realtime: batches updated, refreshing silently...',
              );
              if (mounted) _fetchRaiserData(showLoading: false);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'raiser_notifications',
            callback: (payload) {
              debugPrint(
                'Dashboard realtime: raiser_notifications updated, refreshing silently...',
              );
              if (mounted) _fetchRaiserData(showLoading: false);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'investments',
            callback: (payload) {
              debugPrint(
                'Dashboard realtime: investments updated, refreshing silently...',
              );
              if (mounted) _fetchRaiserData(showLoading: false);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to dashboard assignments realtime: $e');
    }
  }

  @override
  void dispose() {
    if (_dashboardAssignmentsChannel != null) {
      Supabase.instance.client.removeChannel(_dashboardAssignmentsChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchRaiserData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('DEBUG ERROR: No logged in Supabase Auth user.');
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/onboarding',
            (route) => false,
          );
        }
        return;
      }
      debugPrint(
        'DEBUG INFO: Logged in user Auth ID: ${user.id}, Email: ${user.email}',
      );

      // Initialize native notification listener for Hog Raiser
      NotificationService().requestPermission();
      NotificationService().startRoleRealtimeListener(
        role: 'raiser',
        userId: user.id,
      );

      // 1. Fetch user profile from app_users
      var appUser = await Supabase.instance.client
          .from('app_users')
          .select('user_id, name, email')
          .eq('supabase_user_id', user.id)
          .maybeSingle();

      if (appUser == null) {
        final appUserByEmail = await Supabase.instance.client
            .from('app_users')
            .select('user_id, name, email, supabase_user_id')
            .eq('email', user.email!)
            .maybeSingle();

        if (appUserByEmail != null) {
          await Supabase.instance.client
              .from('app_users')
              .update({'supabase_user_id': user.id})
              .eq('user_id', appUserByEmail['user_id']);

          appUser = appUserByEmail;
        } else {
          if (mounted) {
            setState(() {
              _raiserData = {
                'name': 'Account Not Found',
                'email': user.email ?? 'N/A',
                'phone': 'N/A',
                'address': 'N/A',
                'pig_type': 'None',
                'lifecycle_stage': 'None',
              };
              _investedAmount = 0.0;
              _isLoading = false;
            });
          }
          return;
        }
      }

      final userId = appUser['user_id'];
      final fallbackName =
          (appUser['name'] ?? user.email ?? 'Hog Raiser') as String;

      // 2. Fetch raiser profile
      var raiser = await Supabase.instance.client
          .from('hog_raisers')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (raiser == null) {
        final raiserByEmail = await Supabase.instance.client
            .from('hog_raisers')
            .select()
            .eq('email', user.email!)
            .maybeSingle();

        if (raiserByEmail != null) {
          await Supabase.instance.client
              .from('hog_raisers')
              .update({'user_id': userId})
              .eq('hog_raiser_id', raiserByEmail['hog_raiser_id']);

          raiser = await Supabase.instance.client
              .from('hog_raisers')
              .select()
              .eq('user_id', userId)
              .maybeSingle();
        } else {
          if (mounted) {
            setState(() {
              _raiserData = {
                'name': fallbackName,
                'email': user.email ?? 'N/A',
                'phone': 'N/A',
                'address': 'N/A',
                'pig_type': 'None',
                'lifecycle_stage': 'None',
              };
              _investedAmount = 0.0;
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (raiser == null) return;

      final raiserId = raiser['hog_raiser_id'] ?? raiser['id'];
      if (raiserId == null) {
        throw Exception('Raiser ID is null!');
      }

      // Keep native notification listener synced with both Auth UUID and integer hog_raiser_id
      NotificationService().startRoleRealtimeListener(
        role: 'raiser',
        userId: user.id,
        secondaryId: raiserId.toString(),
      );

      // 3. Fetch total capital invested and total hogs from investment_records
      List<dynamic> capitalRes = [];
      try {
        capitalRes = await Supabase.instance.client
            .from('investment_records')
            .select('*')
            .eq('hog_raiser_id', raiserId.toString())
            .order('investment_date', ascending: true);
      } catch (_) {
        try {
          capitalRes = await Supabase.instance.client
              .from('investment_records')
              .select('*')
              .eq('hog_raiser_id', raiserId.toString());
        } catch (_) {
          capitalRes = [];
        }
      }

      final invRows = List<Map<String, dynamic>>.from(capitalRes);
      invRows.sort((a, b) {
        final dateA = (a['investment_date'] ?? a['created_at'] ?? '')
            .toString();
        final dateB = (b['investment_date'] ?? b['created_at'] ?? '')
            .toString();
        final c = dateA.compareTo(dateB);
        if (c != 0) return c;
        final idA = int.tryParse((a['id'] ?? '').toString()) ?? 0;
        final idB = int.tryParse((b['id'] ?? '').toString()) ?? 0;
        return idA.compareTo(idB);
      });

      double totalCapital = 0.0;
      final List<String> investmentHogTypes = [];
      for (var row in invRows) {
        final cap = (row['initial_capital'] as num?)?.toDouble() ?? 0.0;
        final count = (row['total_hog'] as num?)?.toInt() ?? 0;
        final rawHType = (row['hog_type'] ?? 'Fattening').toString().trim();
        final hType =
            rawHType.toLowerCase().contains('sow') ||
                rawHType.toLowerCase().contains('breed')
            ? 'Sow'
            : 'Fattening';
        totalCapital += cap;
        for (int i = 0; i < count; i++) {
          investmentHogTypes.add(hType);
        }
      }

      // 4. Fetch all assignments for this raiser (both active and completed)
      List<dynamic> assignmentsRes = [];
      try {
        assignmentsRes = await Supabase.instance.client
            .from('assignments')
            .select('*, hog_types(*), batches(*)')
            .eq('hog_raiser_id', raiserId);
      } catch (_) {
        try {
          assignmentsRes = await Supabase.instance.client
              .from('assignments')
              .select('*')
              .eq('hog_raiser_id', raiserId);
        } catch (_) {}
      }

      // Pre-fetch all batches safely to avoid losing assignments if relational join returns list or null
      List<dynamic> allBatchesRaw = [];
      try {
        allBatchesRaw = await Supabase.instance.client
            .from('batches')
            .select('*');
      } catch (_) {}
      final Map<String, Map<String, dynamic>> allBatchesMap = {};
      for (var bRow in allBatchesRaw) {
        if (bRow is Map) {
          final id = (bRow['batch_id'] ?? bRow['id'])?.toString();
          if (id != null) allBatchesMap[id] = Map<String, dynamic>.from(bRow);
        }
      }

      final rawAssignments = List<Map<String, dynamic>>.from(assignmentsRes);
      final assignments = <Map<String, dynamic>>[];
      for (var a in rawAssignments) {
        Map<String, dynamic>? b;
        if (a['batches'] is Map) {
          b = Map<String, dynamic>.from(a['batches'] as Map);
        } else if (a['batches'] is List &&
            (a['batches'] as List).isNotEmpty &&
            (a['batches'] as List).first is Map) {
          b = Map<String, dynamic>.from((a['batches'] as List).first as Map);
        }
        if (b == null && a['batch_id'] != null) {
          b = allBatchesMap[a['batch_id'].toString()];
          if (b != null) a['batches'] = b;
        }

        final bStatus = (b?['status'] ?? b?['batch_status'] ?? 'Active')
            .toString()
            .toLowerCase();
        if (bStatus != 'archived' && bStatus != 'deleted') {
          assignments.add(a);
        }
      }

      // Self-healing: If assignments is empty but investment_records has batch info for this raiser
      if (assignments.isEmpty && invRows.isNotEmpty) {
        final latestInvWithBatch = invRows.reversed.firstWhere(
          (inv) =>
              (inv['batch_name'] ?? '').toString().trim().isNotEmpty &&
              inv['batch_name'] != 'Unassigned',
          orElse: () => invRows.last,
        );
        final bName = (latestInvWithBatch['batch_name'] ?? 'Active Batch')
            .toString();
        final bId = latestInvWithBatch['batch_id'];
        assignments.add({
          'assignment_id': null,
          'batch_id': bId,
          'batch_name': bName,
          'status': 'active',
          'is_cycle_completed': false,
          'batches': {'batch_id': bId, 'batch_name': bName, 'status': 'Active'},
          'pig_type': latestInvWithBatch['hog_type'] ?? 'Fattening',
          'lifecycle_stage': latestInvWithBatch['stage'] ?? 'Booster',
        });
      }

      // 5. Fetch hogs strictly for this raiser's active assignments
      List<dynamic> hogsRes = [];
      final activeAssignmentIds = assignments
          .map((a) => a['assignment_id'] ?? a['id'])
          .where((id) => id != null)
          .toList();

      if (activeAssignmentIds.isNotEmpty) {
        try {
          hogsRes = await Supabase.instance.client
              .from('hogs')
              .select('*')
              .inFilter('assignment_id', activeAssignmentIds);
        } catch (_) {
          try {
            hogsRes = await Supabase.instance.client
                .from('hogs')
                .select('*, assignments!inner(*)')
                .eq('assignments.hog_raiser_id', raiserId);
          } catch (_) {}
        }
      }

      if (hogsRes.isEmpty) {
        try {
          final fallbackHogs = await Supabase.instance.client
              .from('hogs')
              .select('*, assignments!inner(*)')
              .eq('assignments.hog_raiser_id', raiserId);
          if (fallbackHogs.isNotEmpty) {
            hogsRes = fallbackHogs;
          }
        } catch (_) {}
      }

      var hogs = List<Map<String, dynamic>>.from(hogsRes)
          .where(
            (h) =>
                (h['health_status'] ?? '').toString().toLowerCase() != 'dead',
          )
          .toList();

      hogs.sort((a, b) {
        final aId = a['hog_id'] as num? ?? 0;
        final bId = b['hog_id'] as num? ?? 0;
        return aId.compareTo(bId);
      });

      // Ensure any orphan hogs for this raiser are associated with an active assignment
      if (assignments.isNotEmpty && hogs.isNotEmpty) {
        final validAssignIds = assignments
            .map((a) => (a['assignment_id'] ?? a['id'])?.toString())
            .whereType<String>()
            .toSet();
        final defaultActiveAssign = assignments.firstWhere(
          (a) =>
              a['is_cycle_completed'] != true &&
              (a['status'] ?? '').toString().toLowerCase() != 'completed',
          orElse: () => assignments.first,
        );
        final defaultAssignId =
            defaultActiveAssign['assignment_id'] ?? defaultActiveAssign['id'];
        for (var h in hogs) {
          final hAId = h['assignment_id']?.toString();
          if (hAId == null ||
              (!validAssignIds.contains(hAId) && defaultAssignId != null)) {
            h['assignment_id'] = defaultAssignId;
          }
        }
      }

      // Create lookup map of assignment_id -> assignment to strictly isolate hog types by their own batch
      final Map<String, Map<String, dynamic>> assignmentMap = {};
      for (var a in assignments) {
        final aId = (a['assignment_id'] ?? a['id'])?.toString();
        if (aId != null) assignmentMap[aId] = a;
      }

      // Assign each hog's pig_type strictly from ITS OWN assigned batch
      for (var hog in hogs) {
        final aId = hog['assignment_id']?.toString();
        final assign = aId != null ? assignmentMap[aId] : null;

        String assignedBatchType = '';
        if (assign != null) {
          final ht = assign['hog_types'];
          if (ht is Map) {
            assignedBatchType = (ht['type_name'] ?? '').toString();
          } else if (ht is List && ht.isNotEmpty && ht.first is Map) {
            assignedBatchType = (ht.first['type_name'] ?? '').toString();
          }
          if (assignedBatchType.isEmpty) {
            assignedBatchType = (assign['pig_type'] ?? '').toString();
          }
        }

        if (assignedBatchType.isNotEmpty) {
          // The batch's assignment is the authoritative type for hogs in that batch!
          hog['pig_type'] =
              assignedBatchType.toLowerCase().contains('sow') ||
                  assignedBatchType.toLowerCase().contains('breed')
              ? 'Sow'
              : 'Fattening';
        } else {
          final rawHogType =
              (hog['pig_type'] ?? hog['type_name'] ?? hog['type'] ?? '')
                  .toString()
                  .trim();
          if (rawHogType.isNotEmpty &&
              rawHogType != 'null' &&
              rawHogType != 'None' &&
              rawHogType != 'N/A') {
            hog['pig_type'] =
                rawHogType.toLowerCase().contains('sow') ||
                    rawHogType.toLowerCase().contains('breed')
                ? 'Sow'
                : 'Fattening';
          } else {
            hog['pig_type'] = 'Fattening';
          }
        }
      }

      // Mark cycle completion for each assignment based on status or terminal hog stages
      for (var a in assignments) {
        final aIdStr = (a['assignment_id'] ?? a['id'])?.toString();
        final b = a['batches'] is Map ? a['batches'] as Map : null;
        final bStatus = (b?['status'] ?? b?['batch_status'] ?? '')
            .toString()
            .toLowerCase();

        final assignHogs = hogs
            .where((h) => h['assignment_id']?.toString() == aIdStr)
            .toList();
        final rawHogType = (a['hog_types']?['type_name'] ?? a['pig_type'] ?? '')
            .toString()
            .toLowerCase();
        final isSow =
            rawHogType.contains('sow') || rawHogType.contains('breed');

        final isExplicitlyCompleted =
            bStatus == 'completed' ||
            bStatus == 'sold' ||
            bStatus == 'finished' ||
            bStatus == 'harvested' ||
            (a['status'] ?? '').toString().toLowerCase() == 'completed' ||
            (a['status'] ?? '').toString().toLowerCase() == 'finished';

        if (isExplicitlyCompleted) {
          a['is_cycle_completed'] = true;
        } else if (assignHogs.isNotEmpty) {
          // If there are hogs in this batch, the cycle is completed if ALL hogs reached final terminal stage or are marked completed!
          final allHogsAtFinalStage = assignHogs.every((h) {
            final hStatus = (h['status'] ?? '').toString().trim().toLowerCase();
            final s =
                (h['stage_id'] ?? h['lifecycle_stage'] ?? h['stage'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
            return hStatus == 'completed' ||
                (isSow
                    ? (s == 'lactation' || s == '6' || s.contains('lactat'))
                    : (s == 'selling' ||
                          s == 'sold' ||
                          s == '6' ||
                          s.contains('sell')));
          });
          a['is_cycle_completed'] = allHogsAtFinalStage;
        } else {
          final assignStage = (a['lifecycle_stage'] ?? a['current_stage'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          bool stageCompleted = false;
          if (isSow &&
              (assignStage == 'lactation' || assignStage.contains('lactat'))) {
            stageCompleted = true;
          } else if (!isSow &&
              (assignStage == 'selling' ||
                  assignStage == 'sold' ||
                  assignStage.contains('sell'))) {
            stageCompleted = true;
          }
          a['is_cycle_completed'] = stageCompleted;
        }
      }

      // 6. Fetch stock requests & product price catalog
      List<dynamic> requestsRes = [];
      try {
        requestsRes = await Supabase.instance.client
            .from('stock_requests')
            .select('*, assignments(*, batches(*))')
            .eq('hog_raiser_id', raiserId)
            .order('request_date', ascending: false)
            .order('request_id', ascending: false);
      } catch (_) {
        try {
          requestsRes = await Supabase.instance.client
              .from('stock_requests')
              .select('*')
              .eq('hog_raiser_id', raiserId)
              .order('request_date', ascending: false)
              .order('request_id', ascending: false);
        } catch (_) {}
      }
      final requests = List<Map<String, dynamic>>.from(requestsRes);
      requests.sort((a, b) {
        final dateA = (a['request_date'] ?? '').toString();
        final dateB = (b['request_date'] ?? '').toString();
        final dateComp = dateB.compareTo(dateA);
        if (dateComp != 0) return dateComp;
        final idA = a['request_id'] is num
            ? (a['request_id'] as num).toInt()
            : (int.tryParse(a['request_id']?.toString() ?? '') ?? 0);
        final idB = b['request_id'] is num
            ? (b['request_id'] as num).toInt()
            : (int.tryParse(b['request_id']?.toString() ?? '') ?? 0);
        return idB.compareTo(idA);
      });

      // Fetch Product Price Catalog for accurate distributed product valuation
      final Map<String, double> productPriceMap = {};
      try {
        final productsRes = await Supabase.instance.client
            .from('inventory_products')
            .select('name, price, category');
        for (var p in (productsRes as List? ?? [])) {
          if (p is! Map) continue;
          final pName = (p['name'] ?? '').toString().trim().toLowerCase();
          final pCat = (p['category'] ?? '').toString().trim().toLowerCase();
          final pPrice = (p['price'] as num?)?.toDouble() ?? 0.0;
          if (pName.isNotEmpty && pPrice > 0) productPriceMap[pName] = pPrice;
          if (pCat.isNotEmpty &&
              pPrice > 0 &&
              !productPriceMap.containsKey(pCat)) {
            productPriceMap[pCat] = pPrice;
          }
        }
      } catch (pErr) {
        debugPrint(
          'Notice fetching product prices from inventory_products: $pErr',
        );
      }

      if (productPriceMap.isEmpty) {
        try {
          final productsRes = await Supabase.instance.client
              .from('products')
              .select('name, price, category');
          for (var p in (productsRes as List? ?? [])) {
            if (p is! Map) continue;
            final pName = (p['name'] ?? '').toString().trim().toLowerCase();
            final pCat = (p['category'] ?? '').toString().trim().toLowerCase();
            final pPrice = (p['price'] as num?)?.toDouble() ?? 0.0;
            if (pName.isNotEmpty && pPrice > 0) productPriceMap[pName] = pPrice;
            if (pCat.isNotEmpty &&
                pPrice > 0 &&
                !productPriceMap.containsKey(pCat)) {
              productPriceMap[pCat] = pPrice;
            }
          }
        } catch (pErr2) {
          debugPrint('Notice fetching product prices from products: $pErr2');
        }
      }

      const double defaultFeedPrice = 1650.0;

      // 7. Calculate Per-Assignment Capital & Stock Spend (Strict Isolation)
      for (var a in assignments) {
        final aId = (a['assignment_id'] ?? a['id'])?.toString();
        final aBatchId = a['batch_id']?.toString();
        final aBatchName =
            (a['batches']?['batch_name'] ?? a['batch_name'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
        final aRawType = (a['hog_types']?['type_name'] ?? a['pig_type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final aIsSow = aRawType.contains('sow') || aRawType.contains('breed');

        // Match investment record(s) for this assignment
        List<Map<String, dynamic>> matchingInvs = invRows.where((row) {
          final bId = row['batch_id']?.toString();
          final bName = (row['batch_name'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          return (aBatchId != null && bId == aBatchId) ||
              (aBatchName.isNotEmpty && bName == aBatchName);
        }).toList();

        // Fallback match by hog type if no direct batch match
        if (matchingInvs.isEmpty && invRows.isNotEmpty) {
          matchingInvs = invRows.where((row) {
            final rawHType = (row['hog_type'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            final rowIsSow =
                rawHType.contains('sow') || rawHType.contains('breed');
            return aIsSow ? rowIsSow : !rowIsSow;
          }).toList();
        }

        // If only 1 assignment exists overall, use all records
        if (matchingInvs.isEmpty && assignments.length == 1) {
          matchingInvs = invRows;
        }

        final assignCapital = matchingInvs.fold<double>(
          0.0,
          (sum, row) =>
              sum + ((row['initial_capital'] as num?)?.toDouble() ?? 0.0),
        );

        // Match requests strictly for this assignment
        double assignSpend = 0.0;
        final List<Map<String, dynamic>> assignProvidedStocks = [];

        for (var req in requests) {
          final reqAssignId =
              (req['assignment_id'] ?? req['assignments']?['assignment_id'])
                  ?.toString();
          final reqBatchId = req['assignments']?['batch_id']?.toString();

          bool belongsToThisAssign = false;
          if (aId != null && reqAssignId != null && reqAssignId == aId) {
            belongsToThisAssign = true;
          } else if (aBatchId != null &&
              reqBatchId != null &&
              reqBatchId == aBatchId) {
            belongsToThisAssign = true;
          } else if (reqAssignId == null && assignments.length == 1) {
            belongsToThisAssign = true;
          } else if (reqAssignId == null &&
              a['is_cycle_completed'] == true &&
              assignments.any((other) => other['is_cycle_completed'] != true)) {
            // Legacy requests without assignment_id belong to completed/historical batch, NOT to the fresh active batch
            belongsToThisAssign = true;
          }

          if (!belongsToThisAssign) continue;

          final status = (req['status'] ?? '').toString().toLowerCase();
          if (status == 'approved' ||
              status == 'completed' ||
              status == 'distributed') {
            final qty = (req['quantity'] as num?)?.toDouble() ?? 1.0;
            final fType = (req['feed_type'] ?? '').toString().trim();
            final cat = (req['category'] ?? '').toString().trim();
            final fTypeLower = fType.toLowerCase();
            final catLower = cat.toLowerCase();

            double unitPrice =
                productPriceMap[fTypeLower] ?? productPriceMap[catLower] ?? 0.0;
            if (unitPrice == 0.0 && fTypeLower.isNotEmpty) {
              for (var entry in productPriceMap.entries) {
                if (entry.key.isNotEmpty &&
                    (fTypeLower.contains(entry.key) ||
                        entry.key.contains(fTypeLower))) {
                  unitPrice = entry.value;
                  break;
                }
              }
            }
            if (unitPrice == 0.0) unitPrice = defaultFeedPrice;

            final totalAmount = qty * unitPrice;
            assignSpend += totalAmount;

            assignProvidedStocks.add({
              'request_id': req['request_id'],
              'product_name': fType.isNotEmpty
                  ? fType
                  : (cat.isNotEmpty ? cat : 'Feeds / Supplies'),
              'category': cat.isNotEmpty ? cat : 'Feeds',
              'quantity': qty.toInt(),
              'unit_price': unitPrice,
              'total_amount': totalAmount,
              'request_date': req['request_date'] ?? req['created_at'],
              'decision_date': req['decision_date'],
              'status': req['status'] ?? 'approved',
              'notes': req['notes'] ?? '',
            });
          }
        }

        final double assignRemaining = assignCapital > 0
            ? (assignCapital - assignSpend).clamp(0.0, double.infinity)
            : 0.0;

        a['initial_capital'] = assignCapital;
        a['stocks_spend'] = assignSpend;
        a['remaining_capital'] = assignRemaining;
        a['provided_stocks'] = assignProvidedStocks;
        a['is_investment_depleted'] =
            assignRemaining <= 0 && (assignCapital > 0 || assignSpend > 0);
      }

      // Sort assignments:
      // 1. Active / non-completed batches first, completed batches last
      // 2. Pig Type: Fattening (0) ALWAYS first, Sow/Breeding (1) ALWAYS second
      // 3. Natural order: earliest assignment_id first (aId.compareTo(bId))
      assignments.sort((a, b) {
        final aDone = a['is_cycle_completed'] == true;
        final bDone = b['is_cycle_completed'] == true;
        if (!aDone && bDone) return -1;
        if (aDone && !bDone) return 1;

        final aType =
            (a['hog_types'] is Map
                ? a['hog_types']['type_name']
                : (a['hog_types'] is List && (a['hog_types'] as List).isNotEmpty
                      ? (a['hog_types'] as List).first['type_name']
                      : null)) ??
            a['pig_type'] ??
            '';
        final bType =
            (b['hog_types'] is Map
                ? b['hog_types']['type_name']
                : (b['hog_types'] is List && (b['hog_types'] as List).isNotEmpty
                      ? (b['hog_types'] as List).first['type_name']
                      : null)) ??
            b['pig_type'] ??
            '';

        int getTypePriority(dynamic t) {
          final s = t.toString().toLowerCase();
          if (s.contains('fatten')) return 0;
          if (s.contains('sow') || s.contains('breed')) return 1;
          return 2;
        }

        final aPrio = getTypePriority(aType);
        final bPrio = getTypePriority(bType);
        if (aPrio != bPrio) return aPrio.compareTo(bPrio);

        final aId = a['assignment_id'] is num
            ? (a['assignment_id'] as num).toInt()
            : 0;
        final bId = b['assignment_id'] is num
            ? (b['assignment_id'] as num).toInt()
            : 0;
        return aId.compareTo(bId);
      });

      // Primary assignment is the first active (non-completed) batch, or first batch if all completed
      final primaryAssign = assignments.isNotEmpty
          ? assignments.firstWhere(
              (a) => a['is_cycle_completed'] != true,
              orElse: () => assignments.first,
            )
          : null;

      final double combinedInvestedAmount =
          (primaryAssign?['remaining_capital'] as num?)?.toDouble() ?? 0.0;
      totalCapital =
          (primaryAssign?['initial_capital'] as num?)?.toDouble() ?? 0.0;
      final double totalStocksSpend =
          (primaryAssign?['stocks_spend'] as num?)?.toDouble() ?? 0.0;
      final List<Map<String, dynamic>> providedStocks =
          List<Map<String, dynamic>>.from(
            primaryAssign?['provided_stocks'] ?? [],
          );

      // 7. Fetch health reports
      final reportsRes = await Supabase.instance.client
          .from('hog_reports')
          .select('*')
          .eq('hog_raiser_id', raiserId)
          .order('created_at', ascending: false);
      final reports = List<Map<String, dynamic>>.from(reportsRes);

      // 8. Fetch Notifications
      final notifRes = await Supabase.instance.client
          .from('raiser_notifications')
          .select('*')
          .eq('hog_raiser_id', raiserId)
          .order('created_at', ascending: false);
      final rawNotifications = List<Map<String, dynamic>>.from(notifRes);

      // Clean up trigger duplicate notifications from DB in the background
      final hasApprovedStockNotif = rawNotifications.any((n) {
        final t = (n['title'] ?? '').toString();
        return t.contains('Stock Request Approved') ||
            t.contains('Kahilingan ng Stock');
      });
      if (hasApprovedStockNotif) {
        try {
          Supabase.instance.client
              .from('raiser_notifications')
              .delete()
              .eq('hog_raiser_id', raiserId)
              .eq('title', 'Stock Request Update')
              .then((_) {}, onError: (_) {});
        } catch (_) {}
      }

      // Deduplicate notifications list so raiser sees exactly 1 notification per event
      final List<Map<String, dynamic>> notifications = [];
      final Set<String> seenNotifKeys = <String>{};
      final List<int> duplicateIdsToDelete = [];

      for (final n in rawNotifications) {
        final notifId = (n['notification_id'] ?? n['id']) as int?;
        final title = (n['title'] ?? '').toString().trim();
        final msg = (n['message'] ?? n['content'] ?? '').toString().trim();
        final type = (n['type'] ?? n['category'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        // 1. Suppress redundant stock trigger item if approved stock exists
        final isTriggerDuplicate =
            (title == 'Stock Request Update') &&
            (msg.contains('Feeds has been') ||
                msg.contains('Medicines has been') ||
                msg.contains('Vitamins has been') ||
                msg.contains('supplies has been'));
        if (isTriggerDuplicate && hasApprovedStockNotif) {
          if (notifId != null) duplicateIdsToDelete.add(notifId);
          continue;
        }

        // 2. Batch assignment duplicate check (only deduplicate batch_assigned triggers)
        final batchId =
            (n['metadata'] is Map ? (n['metadata']['batch_id'] ?? '') : '')
                .toString()
                .trim();
        final isBatchNotif = type == 'batch_assigned';

        final String dedupKey;
        if (isBatchNotif && batchId.isNotEmpty) {
          dedupKey = 'batch_$batchId';
        } else if (isBatchNotif) {
          // Extract batch name from message (e.g. BATCH NI REJIE)
          final batchMatch = RegExp(
            r'(batch[\w\s\-]+)',
            caseSensitive: false,
          ).firstMatch(msg);
          final extractedBatch = batchMatch != null
              ? batchMatch.group(1)?.toLowerCase().trim()
              : '';
          dedupKey = extractedBatch != null && extractedBatch.isNotEmpty
              ? 'batch_$extractedBatch'
              : '$title|$msg';
        } else {
          dedupKey = '$title|$msg';
        }

        if (seenNotifKeys.contains(dedupKey)) {
          if (notifId != null) duplicateIdsToDelete.add(notifId);
          continue;
        }

        seenNotifKeys.add(dedupKey);
        notifications.add(n);
      }

      // Automatically clean up duplicate notification rows from DB in the background
      if (duplicateIdsToDelete.isNotEmpty) {
        for (final dupId in duplicateIdsToDelete) {
          try {
            Supabase.instance.client
                .from('raiser_notifications')
                .delete()
                .eq('notification_id', dupId)
                .then((_) {}, onError: (_) {});
          } catch (_) {}
        }
      }

      // Resolve email, pig type, lifecycle stage and avatar with fallbacks
      final resolvedEmail =
          (raiser['email'] != null &&
              raiser['email'].toString().trim().isNotEmpty &&
              raiser['email'] != 'N/A')
          ? raiser['email'].toString().trim()
          : ((appUser['email'] != null &&
                    appUser['email'].toString().trim().isNotEmpty)
                ? appUser['email'].toString().trim()
                : (user.email ?? 'N/A'));

      String? resolvedAvatar;

      bool isGoogleAvatar(String? url) {
        if (url == null) return false;
        final u = url.toLowerCase().trim();
        return u.contains('googleusercontent.com') ||
            u.contains('ggpht.com') ||
            u.contains('google.com') ||
            u.contains('graph.facebook.com');
      }

      // 1. Check direct database fields in hog_raisers & app_users (excluding Google OAuth avatar URLs)
      final possibleDbUrls = [
        raiser['avatar_url'],
        raiser['picture'],
        raiser['photo_url'],
        appUser['avatar_url'],
        appUser['picture'],
        appUser['photo_url'],
      ];
      for (final u in possibleDbUrls) {
        final s = u?.toString().trim();
        if (s != null &&
            s.isNotEmpty &&
            s != 'N/A' &&
            s != 'null' &&
            !isGoogleAvatar(s)) {
          resolvedAvatar = s;
          break;
        }
      }

      // 2. Check Supabase Storage profile_pictures/avatars bucket for uploaded avatar
      if (resolvedAvatar == null) {
        try {
          final storageFiles = await Supabase.instance.client.storage
              .from('profile_pictures')
              .list(path: 'avatars');
          final rIdStr = raiserId.toString();
          final uIdStr = userId.toString();
          for (final file in storageFiles) {
            final fname = file.name;
            final match = RegExp(r'^avatar-(\d+)-').firstMatch(fname);
            if (match != null) {
              final matchedId = match.group(1)!;
              if (matchedId == rIdStr || matchedId == uIdStr) {
                resolvedAvatar = Supabase.instance.client.storage
                    .from('profile_pictures')
                    .getPublicUrl('avatars/$fname');
                break;
              }
            }
          }
        } catch (sErr) {
          debugPrint('Notice checking storage avatar in mobile: $sErr');
        }
      }

      // 3. Clean up legacy Google avatars if stored in DB
      final dbRaiserAvatar = raiser['avatar_url']?.toString().trim();
      final dbAppUserAvatar = appUser['avatar_url']?.toString().trim();
      if (isGoogleAvatar(dbRaiserAvatar) || isGoogleAvatar(dbAppUserAvatar)) {
        try {
          await Supabase.instance.client
              .from('hog_raisers')
              .update({'avatar_url': null})
              .eq('hog_raiser_id', raiserId);
          await Supabase.instance.client
              .from('app_users')
              .update({'avatar_url': null})
              .eq('user_id', userId);
        } catch (_) {}
      }

      String resolvedPigType = 'None';
      String resolvedStage = 'No Active Batch';

      if (assignments.isNotEmpty) {
        final activeAssignmentsList = assignments
            .where((a) => a['is_cycle_completed'] != true)
            .toList();
        final targetAssignments = activeAssignmentsList.isNotEmpty
            ? activeAssignmentsList
            : assignments;

        final List<String> activeTypes = [];
        for (var a in targetAssignments) {
          final tName =
              (a['hog_types'] is Map
                  ? a['hog_types']['type_name']
                  : (a['hog_types'] is List &&
                            (a['hog_types'] as List).isNotEmpty
                        ? (a['hog_types'] as List).first['type_name']
                        : null)) ??
              a['pig_type'];
          if (tName != null && tName.toString().trim().isNotEmpty) {
            activeTypes.add(tName.toString().trim());
          }
        }

        if (activeTypes.isNotEmpty) {
          final hasSow = activeTypes.any(
            (t) =>
                t.toLowerCase().contains('sow') ||
                t.toLowerCase().contains('breed'),
          );
          final hasFattening = activeTypes.any(
            (t) => t.toLowerCase().contains('fatten'),
          );
          if (hasSow && hasFattening) {
            // Keep the profile's assignment order consistent with the screen:
            // Fattening is shown before Sow / Breeding.
            resolvedPigType = 'Fattening and Sow';
          } else if (hasSow) {
            resolvedPigType = 'Sow';
          } else {
            resolvedPigType = 'Fattening';
          }
        } else if (investmentHogTypes.isNotEmpty) {
          final hasSow = investmentHogTypes.any(
            (t) =>
                t.toLowerCase().contains('sow') ||
                t.toLowerCase().contains('breed'),
          );
          final hasFattening = investmentHogTypes.any(
            (t) => t.toLowerCase().contains('fatten'),
          );
          if (hasSow && hasFattening) {
            // Keep the profile's assignment order consistent with the screen:
            // Fattening is shown before Sow / Breeding.
            resolvedPigType = 'Fattening and Sow';
          } else if (hasSow) {
            resolvedPigType = 'Sow';
          } else {
            resolvedPigType = 'Fattening';
          }
        } else {
          resolvedPigType = 'Fattening';
        }

        final targetAssign = primaryAssign ?? assignments[0];
        final pAssignIdStr =
            (targetAssign['assignment_id'] ?? targetAssign['id'])?.toString();
        final pAssignHogs = hogs
            .where((h) => h['assignment_id']?.toString() == pAssignIdStr)
            .toList();

        final targetAssignType =
            (targetAssign['hog_types'] is Map
                ? targetAssign['hog_types']['type_name']
                : (targetAssign['hog_types'] is List &&
                          (targetAssign['hog_types'] as List).isNotEmpty
                      ? (targetAssign['hog_types'] as List).first['type_name']
                      : null)) ??
            targetAssign['pig_type'] ??
            resolvedPigType;
        final isTargetSow =
            targetAssignType.toString().toLowerCase().contains('sow') ||
            targetAssignType.toString().toLowerCase().contains('breed');

        String mapStageIdToName(dynamic raw, bool isSow) {
          if (raw == null) return 'Booster';
          final s = raw.toString().trim();
          final id = int.tryParse(s);
          if (id != null) {
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
            final list = isSow ? sowStages : fatteningStages;
            if (id >= 1 && id <= list.length) return list[id - 1];
          }
          if (s.isNotEmpty &&
              s != 'null' &&
              s != 'N/A' &&
              int.tryParse(s) == null) {
            return s;
          }
          return 'Booster';
        }

        final hasSow = assignments.any((a) {
          final t = (a['hog_types']?['type_name'] ?? a['pig_type'] ?? '')
              .toString()
              .toLowerCase();
          return t.contains('sow') || t.contains('breed');
        });
        final hasFattening = assignments.any((a) {
          final t = (a['hog_types']?['type_name'] ?? a['pig_type'] ?? '')
              .toString()
              .toLowerCase();
          return t.contains('fatten');
        });

        if (targetAssign['is_cycle_completed'] == true &&
            !assignments.any((a) => a['is_cycle_completed'] != true)) {
          resolvedStage = 'Completed Cycle';
        } else if (hasSow && hasFattening) {
          final fatAssign = assignments.firstWhere((a) {
            final t = (a['hog_types']?['type_name'] ?? a['pig_type'] ?? '')
                .toString()
                .toLowerCase();
            return t.contains('fatten');
          }, orElse: () => assignments.first);
          final sowAssign = assignments.firstWhere((a) {
            final t = (a['hog_types']?['type_name'] ?? a['pig_type'] ?? '')
                .toString()
                .toLowerCase();
            return t.contains('sow') || t.contains('breed');
          }, orElse: () => assignments.last);

          final fatHogs = hogs
              .where(
                (h) =>
                    h['assignment_id']?.toString() ==
                    (fatAssign['assignment_id'] ?? fatAssign['id'])?.toString(),
              )
              .toList();
          final sowHogs = hogs
              .where(
                (h) =>
                    h['assignment_id']?.toString() ==
                    (sowAssign['assignment_id'] ?? sowAssign['id'])?.toString(),
              )
              .toList();

          final fatRaw = fatHogs.isNotEmpty
              ? (fatHogs[0]['stage_id'] ?? fatHogs[0]['lifecycle_stage'])
              : fatAssign['lifecycle_stage'];
          final sowRaw = sowHogs.isNotEmpty
              ? (sowHogs[0]['stage_id'] ?? sowHogs[0]['lifecycle_stage'])
              : sowAssign['lifecycle_stage'];

          final fatStage = mapStageIdToName(fatRaw, false);
          final sowStage = mapStageIdToName(sowRaw, true);

          if (fatStage.toLowerCase() == sowStage.toLowerCase()) {
            resolvedStage = fatStage;
          } else {
            resolvedStage = 'Fattening: $fatStage • Sow: $sowStage';
          }
        } else if (pAssignHogs.isNotEmpty) {
          final dbStage =
              pAssignHogs[0]['stage_id'] ??
              pAssignHogs[0]['lifecycle_stage'] ??
              pAssignHogs[0]['stage'];
          resolvedStage = mapStageIdToName(dbStage, isTargetSow);
        } else {
          final assignStage =
              targetAssign['lifecycle_stage']?.toString() ??
              targetAssign['current_stage']?.toString();
          if (assignStage != null &&
              assignStage.isNotEmpty &&
              assignStage.toLowerCase() != 'lactation' &&
              assignStage.toLowerCase() != 'selling') {
            resolvedStage = mapStageIdToName(assignStage, isTargetSow);
          } else {
            resolvedStage = 'Booster';
          }
        }
      }

      final Map<String, dynamic> combinedRaiserData = Map<String, dynamic>.from(
        raiser,
      );
      combinedRaiserData['email'] = resolvedEmail;
      combinedRaiserData['avatar_url'] = resolvedAvatar;
      combinedRaiserData['pig_type'] = resolvedPigType;
      combinedRaiserData['lifecycle_stage'] = resolvedStage;

      if (mounted) {
        setState(() {
          _raiserData = combinedRaiserData;
          _investedAmount = combinedInvestedAmount;
          _initialCapital = totalCapital;
          _stocksSpendAmount = totalStocksSpend;
          _providedStocksList = providedStocks;
          _activeAssignments = assignments;
          _hogsList = hogs;
          _requestsList = requests;
          _reportsList = reports;
          _notificationsList = notifications;
          if (_activeAssignments.isNotEmpty) {
            final currentSelected = _selectedAssignmentId != null
                ? _activeAssignments.firstWhere(
                    (a) =>
                        BigInt.from(a['assignment_id'] as num) ==
                        _selectedAssignmentId,
                    orElse: () => {},
                  )
                : <String, dynamic>{};
            final isCurrentCompleted =
                currentSelected.isNotEmpty &&
                currentSelected['is_cycle_completed'] == true;
            final hasNonCompleted = _activeAssignments.any(
              (a) => a['is_cycle_completed'] != true,
            );
            final currentIsFattening =
                currentSelected.isNotEmpty &&
                (currentSelected['hog_types']?['type_name'] ??
                        currentSelected['pig_type'] ??
                        '')
                    .toString()
                    .toLowerCase()
                    .contains('fatten');
            final hasFattening = _activeAssignments.any((a) {
              final t = (a['hog_types']?['type_name'] ?? a['pig_type'] ?? '')
                  .toString()
                  .toLowerCase();
              return t.contains('fatten') && a['is_cycle_completed'] != true;
            });

            if (currentSelected.isEmpty ||
                (isCurrentCompleted && hasNonCompleted) ||
                (hasFattening && !currentIsFattening)) {
              _selectedAssignmentId = BigInt.from(
                _activeAssignments[0]['assignment_id'] as num,
              );
            }
          } else {
            _selectedAssignmentId = null;
          }
        });

        // Auto-check if farm location is not set and prompt user to allow GPS access
        if (showLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndPromptLocation();
          });
        }
      }
    } catch (e, stacktrace) {
      debugPrint('DEBUG ERROR in _fetchRaiserData: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '$e\n\nSTACKTRACE:\n$stacktrace';
        });
      }
    } finally {
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markNotificationAsRead(int notificationId) async {
    try {
      await Supabase.instance.client
          .from('raiser_notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId);
      await _fetchRaiserData();
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  Future<void> _markAllRead() async {
    final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];
    if (raiserId != null) {
      try {
        await Supabase.instance.client
            .from('raiser_notifications')
            .update({'is_read': true})
            .eq('hog_raiser_id', raiserId);
        await _fetchRaiserData();
      } catch (e) {
        debugPrint('Error marking all read: $e');
      }
    }
  }

  Future<void> _checkAndNotifyAdminIfFinalStage(
    String targetStage, [
    dynamic targetHogId,
  ]) async {
    final sLower = targetStage.trim().toLowerCase();
    final isFinal = sLower == 'selling' || sLower == 'lactation';
    if (!isFinal) return;

    final raiserName = (_raiserData['name'] ?? 'Hog Raiser').toString().trim();
    final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];

    String pigType = 'Fattening';
    if (targetHogId != null && _hogsList.isNotEmpty) {
      final matchedHog = _hogsList.firstWhere(
        (h) =>
            h['hog_id'] == targetHogId ||
            h['hog_id']?.toString() == targetHogId.toString(),
        orElse: () => <String, dynamic>{},
      );
      if (matchedHog.isNotEmpty) {
        final raw =
            (matchedHog['pig_type'] ??
                    matchedHog['type_name'] ??
                    matchedHog['type'] ??
                    '')
                .toString()
                .trim()
                .toLowerCase();
        if (raw == 'sow' || raw.contains('breed')) {
          pigType = 'Sow';
        }
      }
    }
    if (pigType == 'Fattening' && _activeAssignments.isNotEmpty) {
      final assign = _activeAssignments.first;
      final ht = assign['hog_types'];
      if (ht is Map && ht['type_name'] != null) {
        pigType = ht['type_name'].toString();
      } else if (assign['pig_type'] != null) {
        pigType = assign['pig_type'].toString();
      } else if (_raiserData['pig_type'] != null) {
        pigType = _raiserData['pig_type'].toString();
      }
    }

    String batchName = 'Active Batch';
    dynamic batchId;
    if (_activeAssignments.isNotEmpty) {
      final assign = _activeAssignments.first;
      final b = assign['batches'];
      if (b is Map) {
        batchName = (b['batch_name'] ?? 'Batch #${b['batch_id']}').toString();
        batchId = b['batch_id'] ?? b['id'];
      } else {
        batchId = assign['batch_id'];
        batchName = 'Batch #$batchId';
      }
    }

    final notifTitle = pigType.toLowerCase().contains('sow')
        ? 'Batch Cycle Completed (Sow)'
        : 'Batch Ready for Selling / Harvest (Fattening)';

    final notifMessage = pigType.toLowerCase().contains('sow')
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
        debugPrint(
          'Automatic milestone notification sent to admin: $batchName ($pigType - $targetStage)',
        );

        // Also notify partner investors who funded this batch
        if (batchId != null) {
          try {
            final partnerInvs = await Supabase.instance.client
                .from('investments')
                .select('partner_investor_id')
                .eq('batch_id', batchId);
            for (var inv in partnerInvs) {
              final pId = inv['partner_investor_id'];
              if (pId != null) {
                try {
                  await Supabase.instance.client
                      .from('partner_notifications')
                      .insert({
                        'partner_investor_id': pId,
                        'title': notifTitle,
                        'message':
                            '$batchName has reached $targetStage. Ready for harvest & payout distribution!',
                        'type': 'stage',
                        'is_read': false,
                      });
                } catch (_) {}
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Notice sending milestone notification to admin: $e');
    }
  }

  Future<void> _updateLifecycleStage(
    String targetStage, [
    dynamic targetHogId,
  ]) async {
    final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];
    if (raiserId == null) return;

    setState(() => _isLoading = true);
    try {
      if (targetHogId != null) {
        final sLower = targetStage.trim().toLowerCase();
        int stageNum = 1;
        if (sLower == 'booster') {
          stageNum = 1;
        } else if (sLower == 'pre-starter' || sLower == 'pre starter') {
          stageNum = 2;
        } else if (sLower == 'starter') {
          stageNum = 3;
        } else if (sLower == 'grower') {
          stageNum = 4;
        } else if (sLower == 'finisher' || sLower == 'breeder') {
          stageNum = 5;
        } else if (sLower == 'selling' || sLower == 'lactation') {
          stageNum = 6;
        }

        await Supabase.instance.client
            .from('hogs')
            .update({
              'stage_id': stageNum,
              'last_updated': DateTime.now().toIso8601String(),
            })
            .eq('hog_id', targetHogId);
      } else {
        await Supabase.instance.client
            .from('hog_raisers')
            .update({'lifecycle_stage': targetStage})
            .eq('hog_raiser_id', raiserId);
      }

      await _fetchRaiserData();

      if (targetStage.trim().toLowerCase() == 'selling' ||
          targetStage.trim().toLowerCase() == 'lactation') {
        _checkAndNotifyAdminIfFinalStage(targetStage, targetHogId);
      }

      if (mounted) {
        PiggyToast.showSuccess(
          context,
          AppStrings.of(context).stageUpdatedSuccess(targetStage),
        );
      }
    } catch (e) {
      if (mounted) {
        PiggyToast.showError(
          context,
          'Failed to update stage: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitHogReport(
    BigInt hogId,
    String reportType,
    String notes,
  ) async {
    final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];
    if (raiserId == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Check if the specified hog_id actually exists in public.hogs table to prevent FK constraint error
      int? targetHogId;
      try {
        final existingHog = await Supabase.instance.client
            .from('hogs')
            .select('hog_id')
            .eq('hog_id', hogId.toInt())
            .maybeSingle();
        if (existingHog != null) {
          targetHogId = (existingHog['hog_id'] as num).toInt();
        }
      } catch (_) {}

      // Fallback: If not found by hogId (e.g. temporary/mock index), find the raiser's first real hog in DB
      if (targetHogId == null) {
        try {
          final activeAssignIds = _activeAssignments
              .map((a) => a['assignment_id'] ?? a['id'])
              .where((id) => id != null)
              .toList();
          if (activeAssignIds.isNotEmpty) {
            final firstRealHog = await Supabase.instance.client
                .from('hogs')
                .select('hog_id')
                .inFilter('assignment_id', activeAssignIds)
                .limit(1)
                .maybeSingle();
            if (firstRealHog != null) {
              targetHogId = (firstRealHog['hog_id'] as num).toInt();
            }
          }
        } catch (_) {}
      }

      final batchId = _activeAssignments.isNotEmpty
          ? _activeAssignments[0]['batch_id']
          : null;

      final Map<String, dynamic> reportData = {
        'hog_raiser_id': raiserId,
        'report_type': reportType,
        'description': notes.isNotEmpty ? notes : null,
      };
      if (targetHogId != null) {
        reportData['hog_id'] = targetHogId;
      }
      if (batchId != null) {
        reportData['batch_id'] = batchId;
      }

      await Supabase.instance.client.from('hog_reports').insert(reportData);

      String nextHealth = 'Healthy';
      if (reportType == 'Sick' ||
          reportType == 'Food Poisoning' ||
          reportType == 'Fever' ||
          reportType == 'Diarrhea') {
        nextHealth = 'Sick';
      } else if (reportType == 'Dead') {
        nextHealth = 'Dead';
      }

      if (targetHogId != null) {
        final Map<String, dynamic> updateData = {'health_status': nextHealth};
        if (nextHealth == 'Dead') {
          updateData['status'] = 'dead';
        }

        try {
          await Supabase.instance.client
              .from('hogs')
              .update(updateData)
              .eq('hog_id', targetHogId);
        } catch (_) {}
      }

      if (mounted) {
        PiggyToast.showSuccess(
          context,
          AppStrings.of(context).hogReportSubmittedSuccess,
        );
      }

      await _fetchRaiserData();
    } catch (e) {
      if (mounted) {
        PiggyToast.showError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    await AuthSessionService().clearSession();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/onboarding',
        (route) => false,
      );
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];
    if (raiserId == null) return;

    if (!await ConnectivityService.hasInternet()) {
      _showOfflineProfileUploadToast();
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 300,
        maxHeight: 300,
      );

      if (image == null) return;

      if (!await ConnectivityService.hasInternet()) {
        _showOfflineProfileUploadToast();
        return;
      }

      setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      final fileName =
          'avatar-$raiserId-${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = 'avatars/$fileName';

      await Supabase.instance.client.storage
          .from('profile_pictures')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('profile_pictures')
          .getPublicUrl(filePath);

      // 1. Update Supabase Auth user metadata (always supported)
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'avatar_url': publicUrl, 'picture': publicUrl}),
        );
      } catch (authErr) {
        debugPrint('Auth metadata update notice: $authErr');
      }

      // 2. Update hog_raisers & app_users tables
      try {
        await Supabase.instance.client
            .from('hog_raisers')
            .update({'avatar_url': publicUrl})
            .eq('hog_raiser_id', raiserId);
      } catch (dbErr) {
        debugPrint('DB hog_raisers column update notice: $dbErr');
      }

      final userId = _raiserData['user_id'];
      if (userId != null) {
        try {
          await Supabase.instance.client
              .from('app_users')
              .update({'avatar_url': publicUrl})
              .eq('user_id', userId);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _raiserData['avatar_url'] = publicUrl;
        });
        PiggyToast.showSuccess(
          context,
          AppStrings.of(context).profilePictureUpdatedSuccess,
        );
      }

      await _fetchRaiserData();
    } catch (e) {
      if (mounted) {
        if (ConnectivityService.isNetworkError(e)) {
          _showOfflineProfileUploadToast();
        } else {
          PiggyToast.showError(
            context,
            AppStrings.of(context).profilePictureUploadFailed,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showOfflineProfileUploadToast() {
    if (!mounted) return;
    final strings = AppStrings.of(context);
    PiggyToast.showWarning(
      context,
      strings.profilePictureUploadOffline,
      title: strings.offlineNotificationTitle,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _restoreDefaultAvatar() async {
    final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];
    if (raiserId == null) return;

    if (!await ConnectivityService.hasInternet()) {
      _showOfflineProfileUploadToast();
      return;
    }
    if (raiserId == null) return;

    // Show Tagalog Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.of(ctx).resetProfileConfirmTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: _brandColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            AppStrings.of(ctx).resetProfileConfirmBody,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF475569),
              height: 1.5,
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      AppStrings.of(ctx).no,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      AppStrings.of(ctx).yesReset,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.white,
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

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'avatar_url': null, 'picture': null}),
        );
      } catch (_) {}

      try {
        await Supabase.instance.client
            .from('hog_raisers')
            .update({'avatar_url': null})
            .eq('hog_raiser_id', raiserId);
      } catch (_) {}

      final userId = _raiserData['user_id'];
      if (userId != null) {
        try {
          await Supabase.instance.client
              .from('app_users')
              .update({'avatar_url': null})
              .eq('user_id', userId);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _raiserData.remove('avatar_url');
        });
        PiggyToast.showSuccess(
          context,
          AppStrings.of(context).profileRestoredDefaultSuccess,
        );
      }

      await _fetchRaiserData();
    } catch (e) {
      if (mounted) {
        if (ConnectivityService.isNetworkError(e)) {
          _showOfflineProfileUploadToast();
        } else {
          PiggyToast.showError(
            context,
            AppStrings.of(context).profilePictureUploadFailed,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetProfileToDefault() async {
    if (!await ConnectivityService.hasInternet()) {
      _showOfflineProfileUploadToast();
      return;
    }
    if (!mounted) return;
    final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];
    final userId = _raiserData['user_id'];
    final strings = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final titleColor = isDark ? const Color(0xFFECF2FF) : _brandColor;
    final mutedTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          surfaceTintColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.resetAccountDetailsTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            strings.resetAccountDetailsBody,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: mutedTextColor,
              height: 1.5,
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      strings.cancel,
                      style: GoogleFonts.plusJakartaSans(
                        color: mutedTextColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      strings.yesReset,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white,
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

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final currentEmail = (_raiserData['email'] ?? user?.email ?? '')
          .toString()
          .trim();

      // Resolve registered name
      String defaultName = "";
      if (user != null) {
        final meta = user.userMetadata ?? {};
        final reg =
            (meta['registered_name'] ??
                    meta['original_name'] ??
                    meta['initial_name'])
                ?.toString()
                .trim();
        if (reg != null &&
            reg.isNotEmpty &&
            reg.toLowerCase() != 'hog raiser') {
          defaultName = reg;
        }
      }

      if (defaultName.isEmpty && currentEmail.isNotEmpty) {
        try {
          final notif = await Supabase.instance.client
              .from('admin_notifications')
              .select('metadata')
              .eq('type', 'user_registration')
              .filter('metadata->>email', 'eq', currentEmail)
              .order('created_at', ascending: true)
              .limit(1)
              .maybeSingle();

          if (notif != null && notif['metadata'] != null) {
            final meta = notif['metadata'];
            if (meta is Map && meta['name'] != null) {
              final n = meta['name'].toString().trim();
              if (n.isNotEmpty && n.toLowerCase() != 'hog raiser') {
                defaultName = n;
              }
            }
          }
        } catch (_) {}
      }

      if (defaultName.isEmpty && currentEmail.contains('@')) {
        final prefix = currentEmail.split('@').first.trim();
        if (prefix.isNotEmpty) {
          final parts = prefix.replaceAll(RegExp(r'[._\-]'), ' ').split(' ');
          defaultName = parts
              .where((p) => p.isNotEmpty)
              .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
              .join(' ');
        }
      }

      if (defaultName.isEmpty) defaultName = "Hog Raiser";

      String defaultFirst = defaultName;
      String defaultLast = "";
      final nameParts = defaultName
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ')
          .split(' ');
      if (nameParts.length > 1) {
        defaultFirst = nameParts.first;
        defaultLast = nameParts.sublist(1).join(' ');
      }

      // Update auth user metadata
      if (user != null) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              data: {
                'first_name': defaultFirst,
                'middle_initial': '',
                'last_name': defaultLast,
                'full_name': defaultName,
                'name': defaultName,
                'registered_name': defaultName,
                'avatar_url': null,
                'picture': null,
              },
            ),
          );
        } catch (_) {}
      }

      // Update app_users
      if (userId != null) {
        try {
          await Supabase.instance.client
              .from('app_users')
              .update({'name': defaultName})
              .eq('user_id', userId);
        } catch (_) {}
      }

      // Update hog_raisers
      if (raiserId != null) {
        try {
          await Supabase.instance.client
              .from('hog_raisers')
              .update({
                'name': defaultName,
                'phone': 'N/A',
                'address': 'N/A',
                'avatar_url': null,
              })
              .eq('hog_raiser_id', raiserId);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _raiserData['name'] = defaultName;
          _raiserData['phone'] = 'N/A';
          _raiserData['address'] = 'N/A';
          _raiserData.remove('avatar_url');
        });

        PiggyToast.showSuccess(context, strings.accountDetailsRestoredSuccess);
      }

      await _fetchRaiserData();
    } catch (e) {
      debugPrint('Error resetting raiser profile: $e');
      if (mounted) {
        if (ConnectivityService.isNetworkError(e)) {
          _showOfflineProfileUploadToast();
        } else {
          PiggyToast.showError(
            context,
            AppStrings.of(context).profilePictureUploadFailed,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEditProfileDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentName = (_raiserData['name'] ?? '').toString();
    final currentPhone = (_raiserData['phone'] ?? '').toString();
    final currentAddress = (_raiserData['address'] ?? '').toString();

    // Parse First, Middle Initial, and Last Name from auth metadata or currentName
    final userMeta =
        Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
    String prefillFirst = (userMeta['first_name'] ?? '').toString().trim();
    String prefillMiddle =
        (userMeta['middle_initial'] ?? userMeta['middle_name'] ?? '')
            .toString()
            .trim();
    String prefillLast = (userMeta['last_name'] ?? '').toString().trim();

    if (prefillFirst.isEmpty &&
        prefillLast.isEmpty &&
        currentName.isNotEmpty &&
        currentName != 'Hog Raiser' &&
        currentName != 'N/A') {
      final nameClean = currentName.trim().replaceAll(RegExp(r'\s+'), ' ');
      final parts = nameClean.split(' ');
      if (parts.length == 1) {
        prefillFirst = parts[0];
      } else if (parts.length == 2) {
        prefillFirst = parts[0];
        prefillLast = parts[1];
      } else if (parts.length >= 3) {
        if (parts[1].endsWith('.') || parts[1].length <= 2) {
          prefillFirst = parts[0];
          prefillMiddle = parts[1].replaceAll('.', '');
          prefillLast = parts.sublist(2).join(' ');
        } else {
          prefillFirst = parts.sublist(0, parts.length - 1).join(' ');
          prefillLast = parts.last;
        }
      }
    }

    final firstNameCtrl = TextEditingController(text: prefillFirst);
    final middleInitialCtrl = TextEditingController(text: prefillMiddle);
    final lastNameCtrl = TextEditingController(text: prefillLast);
    final phoneController = TextEditingController(
      text: currentPhone == 'N/A' ? '' : currentPhone,
    );
    final addressController = TextEditingController(
      text: currentAddress == 'N/A' ? '' : currentAddress,
    );

    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final titleColor = isDark ? Colors.white : _brandColor;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final hintColor = isDark
        ? const Color(0xFF94A3B8)
        : PiggyTrunkTheme.ptMuted;
    final actionColor = isDark ? Colors.white : _brandColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final strings = AppStrings.of(ctx);
        bool isDetectingGps = false;
        String? firstNameError;
        String? lastNameError;
        String? phoneError;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> autoDetectGps() async {
              setModalState(() => isDetectingGps = true);
              final result = await LocationService.instance.getCurrentAddress(
                requestPermission: true,
              );
              setModalState(() => isDetectingGps = false);

              if (result.success &&
                  result.address != null &&
                  result.address!.trim().isNotEmpty) {
                // If the user already typed a house/unit/lot number, preserve it with the detected address
                final currentText = addressController.text.trim();
                final houseMatch = RegExp(
                  r'^([#№]?[0-9]+[A-Za-z]?(?:\s*-\s*[0-9]+)?|[Bb]lock\s*\d+\s*[Ll]ot\s*\d+|[Uu]nit\s*[A-Za-z0-9]+)\b',
                ).firstMatch(currentText);

                String finalAddress = result.address!.trim();
                if (houseMatch != null && !finalAddress.startsWith(RegExp(r'[#№0-9]'))) {
                  final prefix = houseMatch.group(1)!.trim();
                  final cleanPrefix = prefix.startsWith('#') || !RegExp(r'^\d').hasMatch(prefix)
                      ? prefix
                      : '#$prefix';
                  finalAddress = '$cleanPrefix $finalAddress';
                }

                addressController.text = finalAddress;
                if (ctx.mounted) {
                  PiggyToast.showSuccess(
                    ctx,
                    '${strings.locationDetectedToast} $finalAddress',
                  );
                }
              } else if (result.isPermanentlyDenied) {
                if (ctx.mounted) {
                  showDialog(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      title: Row(
                        children: [
                          const Icon(
                            Icons.location_off_rounded,
                            color: Color(0xFFF59E0B),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.locationDisabledTitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        strings.locationDisabledDesc,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                          height: 1.45,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: Text(
                            strings.cancel,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dCtx);
                            LocationService.instance.openAppSettings();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            strings.openSettings,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              } else if (ctx.mounted) {
                PiggyToast.showWarning(
                  ctx,
                  result.errorMessage ??
                      'Could not detect location. You can type it manually.',
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.5 : 0.15,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Drag Handle Pill
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF475569)
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFDBEAFE),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    color: isDark ? Colors.white : _brandColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  strings.editProfileTitle,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: titleColor,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark ? Colors.white70 : hintColor,
                                size: 22,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: borderColor, height: 1),
                        const SizedBox(height: 18),

                        // 1. First Name & Middle Initial Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildRaiserFieldHeaderRow(
                                    label: strings.firstNameLabel,
                                    titleColor: titleColor,
                                  ),
                                  _buildRaiserInputField(
                                    context,
                                    controller: firstNameCtrl,
                                    hintText: 'e.g. Juan',
                                    icon: Icons.person_outline_rounded,
                                    hasError: firstNameError != null,
                                    inputFormatters: const [
                                      NameInputFormatter(),
                                    ],
                                    onChanged: (_) {
                                      if (firstNameError != null)
                                        setModalState(
                                          () => firstNameError = null,
                                        );
                                    },
                                  ),
                                  _buildRaiserInlineErrorText(firstNameError),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildRaiserFieldHeaderRow(
                                    label: strings.middleInitialLabel,
                                    titleColor: titleColor,
                                    trailing: Text(
                                      strings.optionalLabel,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: hintColor,
                                      ),
                                    ),
                                  ),
                                  _buildRaiserInputField(
                                    context,
                                    controller: middleInitialCtrl,
                                    hintText: 'M.',
                                    maxLength: 2,
                                    icon: Icons.edit_note_rounded,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z\u00D1\u00F1]'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 2. Last Name Field
                        _buildRaiserFieldHeaderRow(
                          label: strings.lastNameLabel,
                          titleColor: titleColor,
                        ),
                        _buildRaiserInputField(
                          context,
                          controller: lastNameCtrl,
                          hintText: 'e.g. Dela Cruz',
                          icon: Icons.badge_outlined,
                          hasError: lastNameError != null,
                          inputFormatters: const [NameInputFormatter()],
                          onChanged: (_) {
                            if (lastNameError != null)
                              setModalState(() => lastNameError = null);
                          },
                        ),
                        _buildRaiserInlineErrorText(lastNameError),
                        const SizedBox(height: 14),

                        // 3. Phone Number Field
                        _buildRaiserFieldHeaderRow(
                          label: strings.phoneLabel,
                          titleColor: titleColor,
                          trailing: Text(
                            strings.phoneHelperNotice,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hintColor,
                            ),
                          ),
                        ),
                        _buildRaiserInputField(
                          context,
                          controller: phoneController,
                          hintText: '09XXXXXXXXX',
                          icon: Icons.phone_iphone_rounded,
                          keyboardType: TextInputType.phone,
                          hasError: phoneError != null,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          onChanged: (_) {
                            if (phoneError != null)
                              setModalState(() => phoneError = null);
                          },
                        ),
                        _buildRaiserInlineErrorText(phoneError),
                        const SizedBox(height: 14),

                        // 4. Address Field with Auto-Detect Action
                        _buildRaiserFieldHeaderRow(
                          label: strings.address,
                          titleColor: titleColor,
                          trailing: InkWell(
                            onTap: isDetectingGps ? null : autoDetectGps,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDetectingGps)
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                        color: actionColor,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.my_location_rounded,
                                      size: 14,
                                      color: actionColor,
                                    ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isDetectingGps
                                        ? strings.detectingGps
                                        : strings.autoDetectLocation,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: actionColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AddressAutocompleteField(
                          controller: addressController,
                          isDetectingGps: isDetectingGps,
                          onAutoDetect: autoDetectGps,
                          hintText: strings.tapToDetectGpsAddress,
                          onChanged: (_) {
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : borderColor,
                                    width: 1.2,
                                  ),
                                  backgroundColor: isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  strings.cancel,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: isDark ? Colors.white : hintColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final first = firstNameCtrl.text.trim();
                                  final middle = middleInitialCtrl.text
                                      .trim()
                                      .replaceAll('.', '')
                                      .toUpperCase();
                                  final last = lastNameCtrl.text.trim();
                                  final newPhone = phoneController.text.trim();
                                  final newAddr = addressController.text.trim();

                                  // Validate First Name (letters, spaces, accents, ñ/Ñ only)
                                  String? fErr;
                                  if (first.isEmpty) {
                                    fErr = strings.firstNameRequired;
                                  } else if (!RegExp(
                                    r"^[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF \-'\.]+$",
                                  ).hasMatch(first)) {
                                    fErr = strings.nameInvalidCharacters;
                                  }

                                  // Validate Last Name (letters, spaces, accents, ñ/Ñ only)
                                  String? lErr;
                                  if (last.isEmpty) {
                                    lErr = strings.lastNameRequired;
                                  } else if (!RegExp(
                                    r"^[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF \-'\.]+$",
                                  ).hasMatch(last)) {
                                    lErr = strings.nameInvalidCharacters;
                                  }

                                  // Validate Phone (optional, but if provided must start with 09 and be 11 digits)
                                  String? pErr;
                                  if (newPhone.isNotEmpty) {
                                    if (!newPhone.startsWith('09')) {
                                      pErr = strings.phoneMustStart09;
                                    } else if (newPhone.length != 11) {
                                      pErr = strings.phoneMustBe11Digits;
                                    }
                                  }

                                  if (fErr != null ||
                                      lErr != null ||
                                      pErr != null) {
                                    setModalState(() {
                                      firstNameError = fErr;
                                      lastNameError = lErr;
                                      phoneError = pErr;
                                    });
                                    return;
                                  }

                                  final newCombinedName = [
                                    first,
                                    if (middle.isNotEmpty) '$middle.',
                                    last,
                                  ].where((p) => p.isNotEmpty).join(' ');

                                  Navigator.pop(ctx);
                                  await _updateProfile(
                                    newCombinedName,
                                    newPhone,
                                    newAddr,
                                    firstName: first,
                                    middleInitial: middle,
                                    lastName: last,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? Colors.white
                                      : _brandColor,
                                  foregroundColor: isDark
                                      ? const Color(0xFF0F172A)
                                      : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  strings.saveChanges,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRaiserFieldHeaderRow({
    required String label,
    required Color titleColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildRaiserInlineErrorText(String? errorText) {
    if (errorText == null || errorText.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 13,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              errorText,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEF4444),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRaiserInputField(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    Widget? suffixIcon,
    bool hasError = false,
    bool readOnly = false,
    VoidCallback? onTap,
    int? maxLength,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.words,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveFormatters =
        inputFormatters ??
        (keyboardType == TextInputType.phone
            ? null
            : const [CapitalizeWordsInputFormatter()]);
    final errorBorderColor = const Color(0xFFEF4444);
    final normalBorderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return TextField(
      controller: controller,
      readOnly: readOnly,
      enableInteractiveSelection: !readOnly,
      showCursor: !readOnly,
      onTap: onTap,
      keyboardType: readOnly ? TextInputType.none : keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      inputFormatters: effectiveFormatters,
      onChanged: onChanged,
      style: GoogleFonts.plusJakartaSans(
        color: isDark ? Colors.white : _brandColor,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hintText,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          fontWeight: FontWeight.w500,
          fontSize: 13.5,
        ),
        prefixIcon: icon != null
            ? Icon(
                icon,
                size: 20,
                color: hasError
                    ? errorBorderColor
                    : (isDark ? Colors.white70 : _brandColor),
              )
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        contentPadding: EdgeInsets.symmetric(
          horizontal: icon != null ? 14 : 16,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError ? errorBorderColor : normalBorderColor,
            width: hasError ? 1.4 : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError
                ? errorBorderColor
                : (isDark ? Colors.white : _brandColor),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Future<void> _updateProfile(
    String newName,
    String newPhone,
    String newAddress, {
    String? firstName,
    String? middleInitial,
    String? lastName,
  }) async {
    final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];
    if (raiserId == null) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client
          .from('hog_raisers')
          .update({'name': newName, 'phone': newPhone, 'address': newAddress})
          .eq('hog_raiser_id', raiserId);

      final userId = _raiserData['user_id'];
      if (userId != null) {
        try {
          await Supabase.instance.client
              .from('app_users')
              .update({'name': newName})
              .eq('user_id', userId);
        } catch (_) {}
      }

      // Keep Supabase auth user metadata synchronized
      if (firstName != null && lastName != null) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              data: {
                'first_name': firstName,
                'middle_initial': middleInitial ?? '',
                'last_name': lastName,
                'full_name': newName,
                'name': newName,
              },
            ),
          );
        } catch (_) {}
      }

      if (mounted) {
        PiggyToast.showSuccess(
          context,
          AppStrings.of(context).profileUpdateSuccess,
        );
      }

      await _fetchRaiserData();
    } catch (e) {
      if (mounted) {
        PiggyToast.showError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _hasCheckedLocationPrompt = false;

  Future<void> _checkAndPromptLocation() async {
    if (_hasCheckedLocationPrompt || !mounted) return;
    _hasCheckedLocationPrompt = true;

    final currentAddress = (_raiserData['address'] ?? '').toString().trim();
    final bool hasValidAddress =
        currentAddress.isNotEmpty &&
        currentAddress != 'N/A' &&
        currentAddress != 'Not Set' &&
        currentAddress != 'Farm Location Not Set';

    // If user already has a valid address saved, do not prompt
    if (hasValidAddress) return;

    final userId = _raiserData['user_id'] ?? _raiserData['hog_raiser_id'];
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final promptKey = 'prompted_location_$userId';
    if (prefs.getBool(promptKey) == true) return;

    // Option 1: Directly trigger native Android OS location permission dialog
    try {
      final result = await LocationService.instance.getCurrentAddress(
        requestPermission: true,
      );

      // Save prompt flag so we don't prompt repeatedly on every screen load
      await prefs.setBool(promptKey, true);

      if (result.success &&
          result.address != null &&
          result.address!.trim().isNotEmpty) {
        final detectedAddress = result.address!.trim();
        final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];

        if (raiserId != null) {
          try {
            await Supabase.instance.client
                .from('hog_raisers')
                .update({'address': detectedAddress})
                .eq('hog_raiser_id', raiserId);
          } catch (e) {
            debugPrint('Error updating hog_raisers address: $e');
          }
        }

        final uId = _raiserData['user_id'];
        if (uId != null) {
          try {
            await Supabase.instance.client
                .from('app_users')
                .update({'address': detectedAddress})
                .eq('user_id', uId);
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _raiserData['address'] = detectedAddress;
          });
          final strings = AppStrings.of(context);
          PiggyToast.showSuccess(
            context,
            '${strings.locationSavedToast} $detectedAddress',
          );
        }
      }
    } catch (e) {
      debugPrint('[LocationPrompt] Error requesting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If on a sub-tab (Requests, Hogs, Profile), switch to Home tab
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }

        // If on Home tab, require double-tap within 2 seconds to exit app safely
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          PiggyToast.showInfo(
            context,
            AppStrings.of(context).pressBackAgainToExit,
          );
          return;
        }

        // Close the application directly without popping back to login
        SystemNavigator.pop();
      },
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final scaffoldBg = isDark
              ? PiggyTrunkTheme.ptBgDark
              : PiggyTrunkTheme.ptBg;

          final rawAddress = (_raiserData['address'] ?? '').toString().trim();
          final bool isAddressMissing =
              rawAddress.isEmpty ||
              rawAddress == 'N/A' ||
              rawAddress == 'null' ||
              rawAddress == 'Not Set' ||
              rawAddress == 'Farm Location Not Set';

          return Scaffold(
            backgroundColor: scaffoldBg,
            extendBody: true,
            body: _isLoading
                ? SafeArea(
                    child: RaiserDashboardSkeleton(currentIndex: _currentIndex),
                  )
                : SafeArea(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: [
                        RaiserHomeTab(
                          raiserData: _raiserData,
                          investedAmount: _investedAmount,
                          initialCapital: _initialCapital,
                          stocksSpendAmount: _stocksSpendAmount,
                          providedStocksList: _providedStocksList,
                          requestsList: _requestsList,
                          notificationsList: _notificationsList,
                          activeAssignments: _activeAssignments,
                          hogsList: _hogsList,
                          reportsList: _reportsList,
                          errorMessage: _errorMessage,
                          onRefresh: _fetchRaiserData,
                          onNavigateToTab: (index) =>
                              setState(() => _currentIndex = index),
                          onMarkNotificationAsRead: _markNotificationAsRead,
                          onMarkAllRead: _markAllRead,
                          onUpdateLifecycleStage: _updateLifecycleStage,
                        ),
                        RaiserRequestTab(
                          activeAssignments: _activeAssignments,
                          raiserData: _raiserData,
                          requestsList: _requestsList,
                          investedAmount: _investedAmount,
                          initialCapital: _initialCapital,
                          stocksSpendAmount: _stocksSpendAmount,
                          onRefresh: _fetchRaiserData,
                        ),
                        RaiserHogsTab(
                          raiserData: _raiserData,
                          investedAmount: _investedAmount,
                          activeAssignments: _activeAssignments,
                          hogsList: _hogsList,
                          reportsList: _reportsList,
                          notificationsList: _notificationsList,
                          selectedAssignmentId: _selectedAssignmentId,
                          onRefresh: _fetchRaiserData,
                          onMarkNotificationAsRead: _markNotificationAsRead,
                          onMarkAllRead: _markAllRead,
                          onSubmitHogReport: _submitHogReport,
                          onUpdateLifecycleStage: _updateLifecycleStage,
                        ),
                        RaiserProfileTab(
                          raiserData: _raiserData,
                          onPickAndUploadAvatar: _pickAndUploadAvatar,
                          onRestoreDefaultAvatar: _restoreDefaultAvatar,
                          onResetProfile: _resetProfileToDefault,
                          onShowEditProfileDialog: _showEditProfileDialog,
                          onHandleSignOut: _handleSignOut,
                        ),
                      ],
                    ),
                  ),
            bottomNavigationBar: RaiserLiquidBottomBar(
              currentIndex: _currentIndex,
              isAddressMissing: isAddressMissing,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
          );
        },
      ),
    );
  }
}
