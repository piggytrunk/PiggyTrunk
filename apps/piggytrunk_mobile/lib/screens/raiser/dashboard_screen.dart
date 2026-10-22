import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:piggytrunk/services/notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_session_service.dart';
import '../../services/location_service.dart';
import '../../utils/capitalization_formatters.dart';
import '../../utils/app_strings.dart';
import '../../widgets/piggy_toast.dart';

import 'tabs/raiser_home_tab.dart';
import 'tabs/raiser_request_tab.dart';
import 'tabs/raiser_hogs_tab.dart';
import 'tabs/raiser_profile_tab.dart';
import 'widgets/raiser_dashboard_skeleton.dart';

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
          .channel('public:dashboard_assignments_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'assignments',
            callback: (payload) {
              debugPrint('Dashboard realtime: assignments updated, refreshing silently...');
              if (mounted) _fetchRaiserData(showLoading: false);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'batches',
            callback: (payload) {
              debugPrint('Dashboard realtime: batches updated, refreshing silently...');
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
          Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
        }
        return;
      }
      debugPrint('DEBUG INFO: Logged in user Auth ID: ${user.id}, Email: ${user.email}');

      // Initialize native notification listener for Hog Raiser
      NotificationService().requestPermission();
      NotificationService().startRoleRealtimeListener(role: 'raiser', userId: user.id);

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
      final fallbackName = (appUser['name'] ?? user.email ?? 'Hog Raiser') as String;

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

      // 3. Fetch total capital invested and total hogs from investment_records
      List<dynamic> capitalRes = [];
      try {
        capitalRes = await Supabase.instance.client
            .from('investment_records')
            .select('initial_capital, total_hog, hog_type, batch_id, batch_name, stage')
            .eq('hog_raiser_id', raiserId.toString());
      } catch (_) {
        try {
          capitalRes = await Supabase.instance.client
              .from('investment_records')
              .select('initial_capital, total_hog, hog_type')
              .eq('hog_raiser_id', raiserId.toString());
        } catch (_) {}
      }

      final invRows = List<Map<String, dynamic>>.from(capitalRes);
      double totalCapital = 0.0;
      for (var row in invRows) {
        totalCapital += (row['initial_capital'] as num?)?.toDouble() ?? 0.0;
      }

      // 4. Fetch assignments with flexible status matching
      List<dynamic> assignmentsRes = [];
      try {
        assignmentsRes = await Supabase.instance.client
            .from('assignments')
            .select('*, hog_types(*), batches(*)')
            .eq('hog_raiser_id', raiserId)
            .or('status.eq.active,status.eq.Active,status.eq.assigned');
      } catch (_) {
        try {
          assignmentsRes = await Supabase.instance.client
              .from('assignments')
              .select('*')
              .eq('hog_raiser_id', raiserId);
        } catch (_) {}
      }

      List<dynamic> allBatchesRaw = [];
      try {
        allBatchesRaw = await Supabase.instance.client.from('batches').select('*');
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
        } else if (a['batches'] is List && (a['batches'] as List).isNotEmpty && (a['batches'] as List).first is Map) {
          b = Map<String, dynamic>.from((a['batches'] as List).first as Map);
        }
        if (b == null && a['batch_id'] != null) {
          b = allBatchesMap[a['batch_id'].toString()];
          if (b != null) a['batches'] = b;
        }

        final bStatus = (b?['status'] ?? b?['batch_status'] ?? 'Active').toString().toLowerCase();
        if (bStatus != 'archived' && bStatus != 'deleted') {
          assignments.add(a);
        }
      }

      // Self-healing: If assignments is empty but investment_records has batch info for this raiser
      if (assignments.isEmpty && invRows.isNotEmpty) {
        final latestInvWithBatch = invRows.reversed.firstWhere(
          (inv) => (inv['batch_name'] ?? '').toString().trim().isNotEmpty && inv['batch_name'] != 'Unassigned',
          orElse: () => invRows.last,
        );
        final bName = (latestInvWithBatch['batch_name'] ?? 'Active Batch').toString();
        final bId = latestInvWithBatch['batch_id'];
        assignments.add({
          'assignment_id': null,
          'batch_id': bId,
          'batch_name': bName,
          'status': 'active',
          'is_cycle_completed': false,
          'batches': {
            'batch_id': bId,
            'batch_name': bName,
            'status': 'Active',
          },
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
              .inFilter('assignment_id', activeAssignmentIds)
              .eq('status', 'active');
        } catch (_) {
          try {
            hogsRes = await Supabase.instance.client
                .from('hogs')
                .select('*, assignments!inner(*)')
                .eq('assignments.hog_raiser_id', raiserId)
                .eq('status', 'active');
          } catch (_) {}
        }
      }

      if (hogsRes.isEmpty) {
        try {
          final fallbackHogs = await Supabase.instance.client
              .from('hogs')
              .select('*, assignments!inner(*)')
              .eq('assignments.hog_raiser_id', raiserId)
              .eq('status', 'active');
          if (fallbackHogs.isNotEmpty) {
            hogsRes = fallbackHogs;
          }
        } catch (_) {}
      }

      var hogs = List<Map<String, dynamic>>.from(hogsRes)
          .where((h) => (h['health_status'] ?? '').toString().toLowerCase() != 'dead')
          .toList();

      hogs.sort((a, b) {
        final aId = a['hog_id'] as num? ?? 0;
        final bId = b['hog_id'] as num? ?? 0;
        return aId.compareTo(bId);
      });

      // Ensure any orphan hogs for this raiser are associated with the active assignment
      if (assignments.isNotEmpty && hogs.isNotEmpty) {
        final validAssignIds = assignments.map((a) => (a['assignment_id'] ?? a['id'])?.toString()).whereType<String>().toSet();
        final defaultAssignId = assignments.first['assignment_id'] ?? assignments.first['id'];
        for (var h in hogs) {
          final hAId = h['assignment_id']?.toString();
          if (hAId == null || !validAssignIds.contains(hAId)) {
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
          hog['pig_type'] = assignedBatchType.toLowerCase().contains('sow') || assignedBatchType.toLowerCase().contains('breed')
              ? 'Sow'
              : 'Fattening';
        } else {
          final rawHogType = (hog['pig_type'] ?? hog['type_name'] ?? hog['type'] ?? '').toString().trim();
          if (rawHogType.isNotEmpty && rawHogType != 'null' && rawHogType != 'None' && rawHogType != 'N/A') {
            hog['pig_type'] = rawHogType.toLowerCase().contains('sow') || rawHogType.toLowerCase().contains('breed')
                ? 'Sow'
                : 'Fattening';
          } else {
            hog['pig_type'] = 'Fattening';
          }
        }
      }

      // 6. Fetch stock requests & calculate distributed stocks spend
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
          if (pCat.isNotEmpty && pPrice > 0 && !productPriceMap.containsKey(pCat)) {
            productPriceMap[pCat] = pPrice;
          }
        }
      } catch (pErr) {
        debugPrint('Notice fetching product prices from inventory_products: $pErr');
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
            if (pCat.isNotEmpty && pPrice > 0 && !productPriceMap.containsKey(pCat)) {
              productPriceMap[pCat] = pPrice;
            }
          }
        } catch (pErr2) {
          debugPrint('Notice fetching product prices from products: $pErr2');
        }
      }

      const double defaultFeedPrice = 1650.0;
      double totalStocksSpend = 0.0;
      final List<Map<String, dynamic>> providedStocks = [];

      for (var req in requests) {
        final status = (req['status'] ?? '').toString().toLowerCase();
        if (status == 'approved' || status == 'completed' || status == 'distributed') {
          final qty = (req['quantity'] as num?)?.toDouble() ?? 1.0;
          final fType = (req['feed_type'] ?? '').toString().trim();
          final cat = (req['category'] ?? '').toString().trim();
          final fTypeLower = fType.toLowerCase();
          final catLower = cat.toLowerCase();

          double unitPrice = productPriceMap[fTypeLower] ?? productPriceMap[catLower] ?? 0.0;
          if (unitPrice == 0.0 && fTypeLower.isNotEmpty) {
            for (var entry in productPriceMap.entries) {
              if (entry.key.isNotEmpty &&
                  (fTypeLower.contains(entry.key) || entry.key.contains(fTypeLower))) {
                unitPrice = entry.value;
                break;
              }
            }
          }
          if (unitPrice == 0.0) {
            unitPrice = defaultFeedPrice;
          }

          final totalAmount = qty * unitPrice;
          totalStocksSpend += totalAmount;

          providedStocks.add({
            'request_id': req['request_id'],
            'product_name': fType.isNotEmpty ? fType : (cat.isNotEmpty ? cat : 'Feeds / Supplies'),
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

      // Option B: Deductive / Remaining Capital Budget model (Pabawas)
      // Initial Capital is the allocated budget; approved stock requests deduct from this budget.
      final double combinedInvestedAmount = totalCapital > 0
          ? (totalCapital - totalStocksSpend).clamp(0.0, double.infinity)
          : 0.0;

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
        return t.contains('Stock Request Approved') || t.contains('Kahilingan ng Stock');
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
        final type = (n['type'] ?? n['category'] ?? '').toString().trim().toLowerCase();

        // 1. Suppress redundant stock trigger item if approved stock exists
        final isTriggerDuplicate = (title == 'Stock Request Update') &&
            (msg.contains('Feeds has been') ||
                msg.contains('Medicines has been') ||
                msg.contains('Vitamins has been') ||
                msg.contains('supplies has been'));
        if (isTriggerDuplicate && hasApprovedStockNotif) {
          if (notifId != null) duplicateIdsToDelete.add(notifId);
          continue;
        }

        // 2. Batch assignment duplicate check (same batch assigned triggers multiple times for multi-hog types)
        final batchId = (n['metadata'] is Map ? (n['metadata']['batch_id'] ?? '') : '').toString().trim();
        final isBatchNotif = type == 'batch_assigned' ||
            title.toLowerCase().contains('batch') ||
            msg.toLowerCase().contains('batch');

        final String dedupKey;
        if (isBatchNotif && batchId.isNotEmpty) {
          dedupKey = 'batch_$batchId';
        } else if (isBatchNotif) {
          final batchMatch = RegExp(r'(batch[\w\s\-]+)', caseSensitive: false).firstMatch(msg);
          final extractedBatch = batchMatch != null ? batchMatch.group(1)?.toLowerCase().trim() : '';
          dedupKey = extractedBatch != null && extractedBatch.isNotEmpty ? 'batch_$extractedBatch' : '$title|$msg';
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
      final resolvedEmail = (raiser['email'] != null &&
              raiser['email'].toString().trim().isNotEmpty &&
              raiser['email'] != 'N/A')
          ? raiser['email'].toString().trim()
          : ((appUser['email'] != null && appUser['email'].toString().trim().isNotEmpty)
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
        if (s != null && s.isNotEmpty && s != 'N/A' && s != 'null' && !isGoogleAvatar(s)) {
          resolvedAvatar = s;
          break;
        }
      }

      // 2. Check Supabase Storage profile_pictures/avatars bucket for uploaded avatar
      if (resolvedAvatar == null) {
        try {
          final storageFiles = await Supabase.instance.client.storage.from('profile_pictures').list(path: 'avatars');
          final rIdStr = raiserId.toString();
          final uIdStr = userId.toString();
          for (final file in storageFiles) {
            final fname = file.name;
            final match = RegExp(r'^avatar-(\d+)-').firstMatch(fname);
            if (match != null) {
              final matchedId = match.group(1)!;
              if (matchedId == rIdStr || matchedId == uIdStr) {
                resolvedAvatar = Supabase.instance.client.storage.from('profile_pictures').getPublicUrl('avatars/$fname');
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
        final List<String> activeTypes = [];
        for (var a in assignments) {
          final tName = (a['hog_types'] is Map
                  ? a['hog_types']['type_name']
                  : (a['hog_types'] is List && (a['hog_types'] as List).isNotEmpty
                      ? (a['hog_types'] as List).first['type_name']
                      : null)) ??
              a['pig_type'];
          if (tName != null && tName.toString().trim().isNotEmpty) {
            activeTypes.add(tName.toString().trim());
          }
        }

        if (activeTypes.isNotEmpty) {
          final hasSow = activeTypes.any((t) => t.toLowerCase().contains('sow') || t.toLowerCase().contains('breed'));
          final hasFattening = activeTypes.any((t) => t.toLowerCase().contains('fatten'));
          if (hasSow && hasFattening) {
            resolvedPigType = 'Sow & Fattening';
          } else if (hasSow) {
            resolvedPigType = 'Sow';
          } else {
            resolvedPigType = 'Fattening';
          }
        } else {
          resolvedPigType = 'Fattening';
        }

        resolvedStage = assignments[0]['lifecycle_stage']?.toString() ??
            assignments[0]['current_stage']?.toString() ??
            (raiser['lifecycle_stage'] != null &&
                    raiser['lifecycle_stage'].toString().trim().isNotEmpty &&
                    raiser['lifecycle_stage'] != 'N/A'
                ? raiser['lifecycle_stage'].toString().trim()
                : 'Active Cycle');
      }

      final Map<String, dynamic> combinedRaiserData = Map<String, dynamic>.from(raiser);
      combinedRaiserData['email'] = resolvedEmail;
      combinedRaiserData['avatar_url'] = resolvedAvatar;
      combinedRaiserData['pig_type'] = resolvedPigType;
      combinedRaiserData['lifecycle_stage'] = resolvedStage;

      // Sort assignments:
      // 1. Active (non-completed) batches first, completed batches last
      // 2. Pig Type: Fattening (0) ALWAYS first, Sow/Breeding (1) ALWAYS second
      // 3. Natural order: earliest assignment_id first
      assignments.sort((a, b) {
        final aDone = a['is_cycle_completed'] == true;
        final bDone = b['is_cycle_completed'] == true;
        if (!aDone && bDone) return -1;
        if (aDone && !bDone) return 1;

        final aType = (a['hog_types'] is Map
                ? a['hog_types']['type_name']
                : (a['hog_types'] is List && (a['hog_types'] as List).isNotEmpty
                    ? (a['hog_types'] as List).first['type_name']
                    : null)) ??
            a['pig_type'] ??
            '';
        final bType = (b['hog_types'] is Map
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

        final aId = a['assignment_id'] is num ? (a['assignment_id'] as num).toInt() : 0;
        final bId = b['assignment_id'] is num ? (b['assignment_id'] as num).toInt() : 0;
        return aId.compareTo(bId);
      });

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
                    (a) => BigInt.from(a['assignment_id'] as num) == _selectedAssignmentId,
                    orElse: () => {},
                  )
                : <String, dynamic>{};
            final isCurrentCompleted = currentSelected.isNotEmpty && currentSelected['is_cycle_completed'] == true;
            final hasNonCompleted = _activeAssignments.any((a) => a['is_cycle_completed'] != true);
            final currentIsFattening = currentSelected.isNotEmpty &&
                (currentSelected['hog_types']?['type_name'] ?? currentSelected['pig_type'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains('fatten');
            final hasFattening = _activeAssignments.any((a) {
              final t = (a['hog_types']?['type_name'] ?? a['pig_type'] ?? '').toString().toLowerCase();
              return t.contains('fatten') && a['is_cycle_completed'] != true;
            });

            if (currentSelected.isEmpty || (isCurrentCompleted && hasNonCompleted) || (hasFattening && !currentIsFattening)) {
              _selectedAssignmentId = BigInt.from(_activeAssignments[0]['assignment_id'] as num);
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

  Future<void> _updateLifecycleStage(String targetStage) async {
    final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];
    if (raiserId == null) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('hog_raisers')
          .update({'lifecycle_stage': targetStage})
          .eq('hog_raiser_id', raiserId);

      await _fetchRaiserData();

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

  Future<void> _submitHogReport(BigInt hogId, String reportType, String notes) async {
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

      final batchId = _activeAssignments.isNotEmpty ? _activeAssignments[0]['batch_id'] : null;

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
      if (reportType == 'Sick' || reportType == 'Food Poisoning' || reportType == 'Fever' || reportType == 'Diarrhea') {
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
        PiggyToast.showError(
          context,
          'Error: ${e.toString()}',
        );
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
      Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];
    if (raiserId == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 300,
        maxHeight: 300,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      final fileName = 'avatar-$raiserId-${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = 'avatars/$fileName';

      await Supabase.instance.client.storage.from('profile_pictures').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      final publicUrl = Supabase.instance.client.storage.from('profile_pictures').getPublicUrl(filePath);

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
        await Supabase.instance.client.from('hog_raisers').update({
          'avatar_url': publicUrl,
        }).eq('hog_raiser_id', raiserId);
      } catch (dbErr) {
        debugPrint('DB hog_raisers column update notice: $dbErr');
      }

      final userId = _raiserData['user_id'];
      if (userId != null) {
        try {
          await Supabase.instance.client.from('app_users').update({
            'avatar_url': publicUrl,
          }).eq('user_id', userId);
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
        PiggyToast.showError(
          context,
          'Error uploading image: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restoreDefaultAvatar() async {
    final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];
    if (raiserId == null) return;

    // Show Tagalog Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                child: const Icon(Icons.refresh_rounded, color: Color(0xFFD97706), size: 20),
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
                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        await Supabase.instance.client.from('hog_raisers').update({
          'avatar_url': null,
        }).eq('hog_raiser_id', raiserId);
      } catch (_) {}

      final userId = _raiserData['user_id'];
      if (userId != null) {
        try {
          await Supabase.instance.client.from('app_users').update({
            'avatar_url': null,
          }).eq('user_id', userId);
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
        PiggyToast.showError(
          context,
          'Error restoring image: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEditProfileDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentName = _raiserData['name'] ?? '';
    final currentPhone = _raiserData['phone'] ?? '';
    final currentAddress = _raiserData['address'] ?? '';

    final nameController = TextEditingController(text: currentName == 'N/A' ? '' : currentName);
    final phoneController = TextEditingController(text: currentPhone == 'N/A' ? '' : currentPhone);
    final addressController = TextEditingController(text: currentAddress == 'N/A' ? '' : currentAddress);

    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final titleColor = isDark ? Colors.white : _brandColor;
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final hintColor = isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted;
    final fieldIconColor = isDark ? Colors.white70 : hintColor;
    final actionColor = isDark ? Colors.white : _brandColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final strings = AppStrings.of(ctx);
        bool isDetectingGps = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> autoDetectGps() async {
              setModalState(() => isDetectingGps = true);
              final result = await LocationService.instance.getCurrentAddress(requestPermission: true);
              setModalState(() => isDetectingGps = false);

              if (result.success && result.address != null && result.address!.trim().isNotEmpty) {
                addressController.text = result.address!.trim();
                if (ctx.mounted) {
                  PiggyToast.showSuccess(ctx, '${strings.locationDetectedToast} ${result.address}');
                }
              } else if (result.isPermanentlyDenied) {
                if (ctx.mounted) {
                  showDialog(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: Row(
                        children: [
                          const Icon(Icons.location_off_rounded, color: Color(0xFFF59E0B), size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.locationDisabledTitle,
                              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        strings.locationDisabledDesc,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                          height: 1.45,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: Text(strings.cancel, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dCtx);
                            LocationService.instance.openAppSettings();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(strings.openSettings, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  );
                }
              } else if (ctx.mounted) {
                PiggyToast.showWarning(
                  ctx,
                  result.errorMessage ?? 'Could not detect location. You can type it manually.',
                );
              }
            }
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
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
                          color: isDark ? const Color(0xFF475569) : Colors.grey[300],
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
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
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
                          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : hintColor, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: borderColor, height: 1),
                    const SizedBox(height: 18),

                    // 1. Pangalan
                    Text(
                      strings.fullName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: const [CapitalizeWordsInputFormatter()],
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: titleColor, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: strings.enterFullNameHint,
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: hintColor),
                        prefixIcon: Icon(Icons.badge_outlined, color: fieldIconColor, size: 20),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: actionColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Phone Number (Numerical Only!)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.phoneLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        Text(
                          strings.numbersOnlyNotice,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : hintColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: titleColor, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: '09XXXXXXXXX',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: hintColor),
                        prefixIcon: Icon(Icons.phone_iphone_rounded, color: fieldIconColor, size: 20),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: actionColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Address
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          strings.address,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        InkWell(
                          onTap: isDetectingGps ? null : autoDetectGps,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                                  isDetectingGps ? strings.detectingGps : strings.autoDetectLocation,
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
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: addressController,
                      readOnly: false,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: titleColor, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: strings.enterAddressHint,
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: hintColor),
                        prefixIcon: Icon(Icons.location_on_outlined, color: fieldIconColor, size: 20),
                        suffixIcon: isDetectingGps
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: actionColor),
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  Icons.my_location_rounded,
                                  color: actionColor,
                                  size: 18,
                                ),
                                tooltip: strings.autoDetectLocation,
                                onPressed: isDetectingGps ? null : autoDetectGps,
                              ),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: actionColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isDark ? const Color(0xFF334155) : borderColor, width: 1.2),
                              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                              final newName = nameController.text.trim();
                              final newPhone = phoneController.text.trim();
                              final newAddr = addressController.text.trim();

                              if (newName.isEmpty) {
                                PiggyToast.showWarning(
                                  context,
                                  strings.pleaseEnterFullName,
                                );
                                return;
                              }

                              if (newPhone.isNotEmpty && (newPhone.length != 11 || !newPhone.startsWith('09'))) {
                                PiggyToast.showWarning(
                                  context,
                                  strings.invalidPhoneNumber,
                                );
                                return;
                              }

                              Navigator.pop(ctx);
                              await _updateProfile(
                                newName,
                                newPhone,
                                newAddr,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : _brandColor,
                              foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<void> _updateProfile(String newName, String newPhone, String newAddress) async {
    final raiserId = _raiserData['hog_raiser_id'] ?? _raiserData['id'];
    if (raiserId == null) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.from('hog_raisers').update({
        'name': newName,
        'phone': newPhone,
        'address': newAddress,
      }).eq('hog_raiser_id', raiserId);

      final userId = _raiserData['user_id'];
      if (userId != null) {
        try {
          await Supabase.instance.client.from('app_users').update({
            'name': newName,
          }).eq('user_id', userId);
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
        PiggyToast.showError(
          context,
          'Error: ${e.toString()}',
        );
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
    final bool hasValidAddress = currentAddress.isNotEmpty &&
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
      final result = await LocationService.instance.getCurrentAddress(requestPermission: true);

      // Save prompt flag so we don't prompt repeatedly on every screen load
      await prefs.setBool(promptKey, true);

      if (result.success && result.address != null && result.address!.trim().isNotEmpty) {
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
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
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
          final strings = AppStrings.of(context);
          final scaffoldBg = isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
          final navBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
          final navSelectedColor = isDark ? Colors.white : _brandColor;
          final navUnselectedColor = isDark ? PiggyTrunkTheme.ptMutedDark : const Color(0xffa0aec0);

          final rawAddress = (_raiserData['address'] ?? '').toString().trim();
          final bool isAddressMissing = rawAddress.isEmpty ||
              rawAddress == 'N/A' ||
              rawAddress == 'null' ||
              rawAddress == 'Not Set' ||
              rawAddress == 'Farm Location Not Set';

          return Scaffold(
            backgroundColor: scaffoldBg,
            body: _isLoading
                ? SafeArea(
                    child: RaiserDashboardSkeleton(
                      currentIndex: _currentIndex,
                    ),
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
                          onNavigateToTab: (index) => setState(() => _currentIndex = index),
                          onMarkNotificationAsRead: _markNotificationAsRead,
                          onMarkAllRead: _markAllRead,
                          onUpdateLifecycleStage: _updateLifecycleStage,
                        ),
                        RaiserRequestTab(
                          activeAssignments: _activeAssignments,
                          raiserData: _raiserData,
                          requestsList: _requestsList,
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
                          onShowEditProfileDialog: _showEditProfileDialog,
                          onHandleSignOut: _handleSignOut,
                        ),
                      ],
                    ),
                  ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                    width: 1,
                  ),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                type: BottomNavigationBarType.fixed,
                backgroundColor: navBg,
                selectedItemColor: navSelectedColor,
                unselectedItemColor: navUnselectedColor,
                selectedLabelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                items: [
                  BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      'assets/icons/sidebar/dashboard.svg',
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(navUnselectedColor, BlendMode.srcIn),
                    ),
                    activeIcon: SvgPicture.asset(
                      'assets/icons/sidebar/dashboard.svg',
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(navSelectedColor, BlendMode.srcIn),
                    ),
                    label: strings.navDashboard,
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.description_outlined),
                    label: strings.navRequest,
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.pets),
                    label: strings.navHogs,
                  ),
                  BottomNavigationBarItem(
                    icon: Badge(
                      isLabelVisible: isAddressMissing,
                      backgroundColor: const Color(0xFFDC2626),
                      smallSize: 8,
                      child: const Icon(Icons.person_outline_rounded),
                    ),
                    activeIcon: Badge(
                      isLabelVisible: isAddressMissing,
                      backgroundColor: const Color(0xFFDC2626),
                      smallSize: 8,
                      child: const Icon(Icons.person_rounded),
                    ),
                    label: strings.navProfile,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
