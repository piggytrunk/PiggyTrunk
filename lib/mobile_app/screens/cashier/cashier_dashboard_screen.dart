import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:piggytrunk/models/pos_model.dart';
import 'package:piggytrunk/utils/inventory_data_adapter.dart';

import 'tabs/cashier_home_tab.dart';
import 'tabs/cashier_requests_tab.dart';
import 'tabs/cashier_inventory_tab.dart';
import 'tabs/cashier_pos_tab.dart';
import 'tabs/cashier_profile_tab.dart';
import 'widgets/stock_requests_modal.dart';
import 'widgets/cashier_empty_state.dart';
import 'widgets/cashier_dashboard_skeleton.dart';
import '../../services/auth_session_service.dart';
import '../../utils/capitalization_formatters.dart';
import '../../utils/app_strings.dart';
import '../../services/location_service.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:piggytrunk/services/notification_service.dart';
import '../../widgets/piggy_toast.dart';

class CashierDashboardScreen extends StatefulWidget {
  const CashierDashboardScreen({super.key});

  @override
  State<CashierDashboardScreen> createState() => _CashierDashboardScreenState();
}

class _CashierDashboardScreenState extends State<CashierDashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  int _currentIndex = 0;
  bool _isLoading = false;

  // Realtime & Auto-Refresh State
  RealtimeChannel? _requestsChannel;
  RealtimeChannel? _inventoryChannel;
  Timer? _refreshTimer;

  // Profile State
  int? _appUserId;
  String _cashierName = "Cashier Staff";
  String _cashierEmail = "";
  String _cashierPhone = "N/A";
  String _cashierAddress = "N/A";
  String? _cashierAvatarUrl;
  static const Color _brandColor = Color(0xFF18314F);
  DateTime? _lastBackPressTime;

  // Real Database Data
  List<POSProduct> _allProducts = [];
  List<POSProduct> _lowStockProducts = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  final Set<String> _readNotificationIds = {};
  DateTime? _lastMarkAllReadTime;

  // Sales History State
  final bool _showSalesHistory = false;
  List<Map<String, dynamic>> _salesLogs = [];
  bool _isLoadingSales = false;

  // POS Cart State
  final Order _currentOrder = Order(items: []);
  int _orderItemCounter = 0;

  // Search & Filter State
  String _selectedCategory = "All";
  final List<String> _categories = [
    "All",
    "Feeds",
    "Medicines",
    "Vitamins",
    "Others",
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subscribeToRealtime();
    // Auto-refresh every 10 seconds for real-time safety
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _fetchPendingRequests();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _requestsChannel?.unsubscribe();
    _inventoryChannel?.unsubscribe();
    NotificationService().stopListener();
    super.dispose();
  }

  void _subscribeToRealtime() {
    try {
      _requestsChannel = _supabase
          .channel('public:stock_requests')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'stock_requests',
            callback: (payload) {
              if (mounted) _fetchPendingRequests();
            },
          )
          .subscribe();

      _inventoryChannel = _supabase
          .channel('public:inventory_products')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'inventory_products',
            callback: (payload) {
              if (mounted) _fetchInventory();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to channels: $e');
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user != null) {
      NotificationService().requestPermission();
      NotificationService().startRoleRealtimeListener(role: 'cashier', userId: user.id);
    }
    await _loadReadNotifications();
    await _fetchProfile();
    await _fetchInventory();
    await _fetchPendingRequests();
    await _fetchSalesLogs();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList('cashier_read_notifications');
      final savedTimeStr = prefs.getString('cashier_last_mark_all_read_time');

      final secureTimeStr = await AuthSessionService().readKey('cashier_last_mark_all_read_time');
      final secureIdsStr = await AuthSessionService().readKey('cashier_read_notifications');

      final effectiveTimeStr = savedTimeStr ?? secureTimeStr;
      DateTime? parsedTime;
      if (effectiveTimeStr != null && effectiveTimeStr.isNotEmpty) {
        parsedTime = DateTime.tryParse(effectiveTimeStr);
      }

      final Set<String> loadedIds = {};
      if (savedList != null) {
        loadedIds.addAll(savedList);
      }
      if (secureIdsStr != null && secureIdsStr.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(secureIdsStr);
          loadedIds.addAll(decoded.map((e) => e.toString()));
        } catch (_) {
          loadedIds.addAll(secureIdsStr.split(',').where((s) => s.isNotEmpty));
        }
      }

      if (mounted) {
        setState(() {
          _readNotificationIds.addAll(loadedIds);
          if (parsedTime != null) {
            _lastMarkAllReadTime = parsedTime;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading cashier read notifications: $e');
    }
  }

  Future<void> _saveReadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idList = _readNotificationIds.toList();
      await prefs.setStringList('cashier_read_notifications', idList);
      await AuthSessionService().writeKey('cashier_read_notifications', jsonEncode(idList));
      if (_lastMarkAllReadTime != null) {
        final iso = _lastMarkAllReadTime!.toIso8601String();
        await prefs.setString('cashier_last_mark_all_read_time', iso);
        await AuthSessionService().writeKey('cashier_last_mark_all_read_time', iso);
      }
    } catch (e) {
      debugPrint('Error saving cashier read notifications: $e');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      String effectiveEmail = user?.email ?? "";
      if (effectiveEmail.isEmpty) {
        final saved = await AuthSessionService().getSavedEmail();
        if (saved != null && saved.isNotEmpty) {
          effectiveEmail = saved;
        }
      }

      if (user == null && effectiveEmail.isEmpty) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
        }
        return;
      }

      _cashierEmail = effectiveEmail;

      // Extract Auth Metadata if available
      final meta = user?.userMetadata;
      String? googleName;
      if (meta != null) {
        googleName = (meta['full_name'] ?? meta['name'] ?? meta['displayName'])
            ?.toString()
            .trim();
      }

      Map<String, dynamic>? profile;
      if (user != null) {
        try {
          profile = await _supabase
              .from('app_users')
              .select('user_id, name, email, role, status, supabase_user_id')
              .eq('supabase_user_id', user.id)
              .maybeSingle();
        } catch (_) {}
      }

      if (profile == null && effectiveEmail.isNotEmpty) {
        try {
          profile = await _supabase
              .from('app_users')
              .select('user_id, name, email, role, status, supabase_user_id')
              .ilike('email', effectiveEmail)
              .maybeSingle();
          if (profile != null && user != null) {
            try {
              await _supabase
                  .from('app_users')
                  .update({'supabase_user_id': user.id})
                  .eq('user_id', profile['user_id']);
            } catch (_) {}
          }
        } catch (_) {}
      }

      if (profile != null) {
        _appUserId = (profile['user_id'] as num?)?.toInt();
      }

      Map<String, dynamic>? cashierRow;
      if (_appUserId != null) {
        try {
          cashierRow = await _supabase
              .from('cashiers')
              .select('cashier_id, user_id, date_hired, avatar_url')
              .eq('user_id', _appUserId!)
              .maybeSingle();
        } catch (_) {}
      }

      String resolvedName = "";
      String resolvedPhone = "Not set";
      String resolvedAddress = "Not set";
      String? resolvedAvatar;

      // 1. Resolve Name from app_users
      if (profile != null) {
        final dbName = profile['name']?.toString().trim() ?? '';
        if (dbName.isNotEmpty && dbName != 'Cashier Staff' && dbName != 'N/A') {
          resolvedName = dbName;
        }
      }

      if (resolvedName.isEmpty && googleName != null && googleName.isNotEmpty) {
        resolvedName = googleName;
      }

      if (resolvedName.isEmpty && effectiveEmail.isNotEmpty) {
        final prefix = effectiveEmail.split('@').first;
        final parts = prefix.replaceAll(RegExp(r'[._-]'), ' ').split(' ');
        resolvedName = parts.where((p) => p.isNotEmpty).map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
      }

      // 2. Resolve Phone & Address from user metadata
      final metaPhone = (meta?['phone'] ?? meta?['phone_number'] ?? meta?['contact_number'])?.toString().trim();
      if (metaPhone != null && metaPhone.isNotEmpty && metaPhone != 'null') {
        resolvedPhone = metaPhone;
      }
      final metaAddress = (meta?['address'] ?? meta?['store_address'] ?? meta?['branch_address'])?.toString().trim();
      if (metaAddress != null && metaAddress.isNotEmpty && metaAddress != 'null') {
        resolvedAddress = metaAddress;
      }

      // 3. Resolve Phone & Address from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final keyPhone = 'cashier_phone_${user?.id ?? effectiveEmail}';
        final keyAddr = 'cashier_address_${user?.id ?? effectiveEmail}';
        final localPhone = prefs.getString(keyPhone)?.trim();
        final localAddr = prefs.getString(keyAddr)?.trim();
        if ((resolvedPhone == 'Not set' || resolvedPhone == 'N/A') && localPhone != null && localPhone.isNotEmpty) {
          resolvedPhone = localPhone;
        }
        if ((resolvedAddress == 'Not set' || resolvedAddress == 'N/A') && localAddr != null && localAddr.isNotEmpty) {
          resolvedAddress = localAddr;
        }
      } catch (_) {}

      // 4. Resolve Phone & Address from admin_notifications if still not set
      if ((resolvedPhone == 'Not set' || resolvedPhone == 'N/A' || resolvedAddress == 'Not set' || resolvedAddress == 'N/A') && effectiveEmail.isNotEmpty) {
        try {
          final notifs = await _supabase
              .from('admin_notifications')
              .select('metadata')
              .inFilter('type', ['cashier_profile', 'user_registration'])
              .order('created_at', ascending: false)
              .limit(10);
          for (final n in notifs) {
            final m = n['metadata'];
            if (m is Map) {
              final mEmail = m['email']?.toString().toLowerCase().trim();
              final mUid = m['user_id']?.toString();
              if (mEmail == effectiveEmail.toLowerCase() || (_appUserId != null && mUid == _appUserId.toString())) {
                if (resolvedPhone == 'Not set' || resolvedPhone == 'N/A') {
                  final nPhone = (m['phone'] ?? m['contact_number'] ?? m['phone_number'])?.toString().trim();
                  if (nPhone != null && nPhone.isNotEmpty && nPhone != 'null') {
                    resolvedPhone = nPhone;
                  }
                }
                if (resolvedAddress == 'Not set' || resolvedAddress == 'N/A') {
                  final nAddr = (m['address'] ?? m['store_address'] ?? m['branch_address'])?.toString().trim();
                  if (nAddr != null && nAddr.isNotEmpty && nAddr != 'null') {
                    resolvedAddress = nAddr;
                  }
                }
                break;
              }
            }
          }
        } catch (_) {}
      }

      // 5. Resolve Avatar
      final cAv = cashierRow?['avatar_url']?.toString().trim();
      if (cAv != null &&
          cAv.isNotEmpty &&
          cAv != 'null' &&
          !cAv.toLowerCase().contains('googleusercontent.com') &&
          !cAv.toLowerCase().contains('ggpht.com')) {
        resolvedAvatar = cAv;
      }
      if (resolvedAvatar == null) {
        final metaAv = (meta?['avatar_url'] ?? meta?['picture'])?.toString().trim();
        if (metaAv != null &&
            metaAv.isNotEmpty &&
            metaAv != 'null' &&
            !metaAv.toLowerCase().contains('googleusercontent.com') &&
            !metaAv.toLowerCase().contains('ggpht.com')) {
          resolvedAvatar = metaAv;
        }
      }

      // Auto-sync resolved name to app_users if needed
      if (_appUserId != null &&
          resolvedName.isNotEmpty &&
          resolvedName != 'Cashier Staff') {
        try {
          await _supabase
              .from('app_users')
              .update({'name': resolvedName})
              .eq('user_id', _appUserId!);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _cashierName = resolvedName.isNotEmpty
              ? resolvedName
              : "Cashier Staff";
          _cashierPhone = resolvedPhone;
          _cashierAddress = resolvedAddress;
          _cashierAvatarUrl = resolvedAvatar;
        });
      }
    } catch (e) {
      debugPrint('Error loading cashier profile: $e');
    }
  }

  Future<void> _fetchInventory() async {
    try {
      List<dynamic> rows = [];
      String source = 'inventory_products';
      try {
        rows = await _supabase
            .from('inventory_products')
            .select()
            .order('name', ascending: true);
      } catch (_) {
        try {
          rows = await _supabase
              .from('products')
              .select()
              .order('name', ascending: true);
          source = 'products';
        } catch (_) {}
      }

      final normalized = normalizeInventoryRows(rows, sourceTable: source);
      final List<POSProduct> products = normalized
          .map((r) => POSProduct.fromJson(r))
          .toList();

      if (mounted) {
        setState(() {
          _allProducts = products;
          _lowStockProducts = products
              .where((p) => p.stock <= 10 && !p.isArchived)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching inventory: $e');
    }
  }

  Future<void> _fetchPendingRequests() async {
    try {
      List<dynamic> res = [];
      try {
        res = await _supabase
            .from('stock_requests')
            .select(
              '*, hog_raisers(name, avatar_url, hog_raiser_id, user_id, app_users!hog_raisers_user_id_fkey(name, email))',
            )
            .order('created_at', ascending: false);
      } catch (_) {
        try {
          res = await _supabase
              .from('stock_requests')
              .select('*, hog_raisers(name, avatar_url)')
              .order('created_at', ascending: false);
        } catch (_) {
          try {
            res = await _supabase
                .from('stock_requests')
                .select()
                .order('request_date', ascending: false);
          } catch (_) {
            res = await _supabase.from('stock_requests').select();
          }
        }
      }

      if (mounted) {
        setState(() {
          _pendingRequests = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('Error fetching pending requests: $e');
    }
  }

  Future<void> _fetchSalesLogs() async {
    if (!mounted) return;
    setState(() => _isLoadingSales = true);
    final List<Map<String, dynamic>> combined = [];

    // 1. Fetch from inventory_logs (Action: 'SALE')
    try {
      final invLogs = await _supabase
          .from('inventory_logs')
          .select()
          .eq('action', 'SALE')
          .order('created_at', ascending: false)
          .limit(100);

      for (final raw in (invLogs as List)) {
        final log = Map<String, dynamic>.from(raw as Map);
        final details = (log['details'] ?? '').toString();

        String customer = 'Walk-in Customer';
        if (details.contains('POS Sale to ')) {
          final afterTo = details.split('POS Sale to ').last;
          customer = afterTo.split(' (').first.trim();
        }

        String payment = 'Cash';
        if (details.contains('(') && details.contains(')')) {
          final paren = details.split('(').last.split(')').first.trim();
          if (paren.isNotEmpty) payment = paren;
        }

        combined.add({
          'id': log['id'],
          'product_name': log['product_name'] ?? 'Product',
          'total_amount': (log['price'] as num?)?.toDouble() ?? 0.0,
          'quantity': (log['units'] as num?)?.toInt() ?? 1,
          'sale_date': log['created_at'],
          'created_at': log['created_at'],
          'cashier_name': log['performed_by'] ?? _cashierName,
          'customer_name': customer,
          'payment_method': payment,
        });
      }
    } catch (e) {
      debugPrint('Error fetching inventory_logs for sales: $e');
    }

    // 2. Fetch from sales table
    try {
      final salesRes = await _supabase
          .from('sales')
          .select()
          .order('sale_date', ascending: false)
          .limit(100);

      for (final raw in (salesRes as List)) {
        final s = Map<String, dynamic>.from(raw as Map);
        final saleId = s['sale_id'] ?? s['id'];
        final exists = combined.any((c) => c['id'] == saleId);
        if (!exists) {
          combined.add({
            'id': saleId,
            'product_name': s['product_name'] ?? 'Inventory Sale',
            'total_amount': (s['total_amount'] as num?)?.toDouble() ?? 0.0,
            'quantity': (s['quantity'] as num?)?.toInt() ?? 1,
            'sale_date': s['sale_date'] ?? s['created_at'],
            'created_at': s['sale_date'] ?? s['created_at'],
            'cashier_name': s['cashier_name'] ?? _cashierName,
            'customer_name': s['customer_name'] ?? 'Walk-in Customer',
            'payment_method': s['payment_method'] ?? 'Cash',
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching sales table: $e');
    }

    // Sort descending by date
    combined.sort((a, b) {
      final dtA = DateTime.tryParse((a['sale_date'] ?? a['created_at'] ?? '').toString()) ?? DateTime(2000);
      final dtB = DateTime.tryParse((b['sale_date'] ?? b['created_at'] ?? '').toString()) ?? DateTime(2000);
      return dtB.compareTo(dtA);
    });

    if (mounted) {
      setState(() {
        _salesLogs = combined;
        _isLoadingSales = false;
      });
    }
  }

  // ===================== PROFILE ACTIONS =====================

  Future<void> _pickAndUploadAvatar() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 300,
        maxHeight: 300,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final path =
          'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      await _supabase.storage
          .from('profile_pictures')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      final avatarUrl = _supabase.storage
          .from('profile_pictures')
          .getPublicUrl(path);

      // Sync across Auth User Metadata and cashiers table for Admin Web
      try {
        await _supabase.auth.updateUser(
          UserAttributes(data: {'avatar_url': avatarUrl, 'picture': avatarUrl}),
        );
      } catch (_) {}

      if (_appUserId != null) {
        try {
          await _supabase
              .from('cashiers')
              .update({'avatar_url': avatarUrl})
              .eq('user_id', _appUserId!);
        } catch (_) {}
      }

      setState(() => _cashierAvatarUrl = avatarUrl);
      _showSnackBar('Profile picture updated successfully!');
      await _fetchProfile();
    } catch (e) {
      _showSnackBar('Error updating profile picture: $e', isError: true);
    }
  }

  Future<void> _restoreDefaultAvatar() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final titleColor = isDark ? const Color(0xFFECF2FF) : const Color(0xFF18314F);
    final mutedTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          surfaceTintColor: dialogBg,
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
                  'Reset Profile Picture?',
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
            'Are you sure you want to restore your profile picture to the default PiggyTrunk logo?',
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
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      'Cancel',
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
                      backgroundColor: const Color(0xFF18314F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      'Yes, Reset',
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

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      try {
        await _supabase.auth.updateUser(
          UserAttributes(data: {'avatar_url': null, 'picture': null}),
        );
      } catch (_) {}

      if (_appUserId != null) {
        try {
          await _supabase
              .from('cashiers')
              .update({'avatar_url': null})
              .eq('user_id', _appUserId!);
        } catch (_) {}
      }

      setState(() => _cashierAvatarUrl = null);
      _showSnackBar('Profile picture restored to default successfully!');
      await _fetchProfile();
    } catch (e) {
      _showSnackBar('Error restoring default picture: $e', isError: true);
    }
  }

  Future<void> _resetProfileToDefault() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final dialogBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final titleColor = isDark ? const Color(0xFFECF2FF) : const Color(0xFF18314F);
    final mutedTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          surfaceTintColor: dialogBg,
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
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      backgroundColor: const Color(0xFF18314F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    try {
      final user = _supabase.auth.currentUser;
      final emailToUse = _cashierEmail.isNotEmpty ? _cashierEmail : (user?.email ?? '');

      String defaultName = "";
      if (user != null) {
        final meta = user.userMetadata ?? {};
        final reg = (meta['registered_name'] ?? meta['original_name'] ?? meta['initial_name'])?.toString().trim();
        if (reg != null && reg.isNotEmpty && reg.toLowerCase() != 'cashier staff') {
          defaultName = reg;
        }
      }

      if (defaultName.isEmpty && emailToUse.isNotEmpty) {
        try {
          final notif = await _supabase
              .from('admin_notifications')
              .select('metadata')
              .eq('type', 'user_registration')
              .filter('metadata->>email', 'eq', emailToUse)
              .order('created_at', ascending: true)
              .limit(1)
              .maybeSingle();

          if (notif != null && notif['metadata'] != null) {
            final meta = notif['metadata'];
            if (meta is Map && meta['name'] != null) {
              final n = meta['name'].toString().trim();
              if (n.isNotEmpty && n.toLowerCase() != 'cashier staff') {
                defaultName = n;
              }
            }
          }
        } catch (_) {}
      }

      if (defaultName.isEmpty && emailToUse.contains('@')) {
        final prefix = emailToUse.split('@').first.trim();
        if (prefix.isNotEmpty) {
          final parts = prefix.replaceAll(RegExp(r'[._\-]'), ' ').split(' ');
          defaultName = parts
              .where((p) => p.isNotEmpty)
              .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
              .join(' ');
        }
      }

      if (defaultName.isEmpty) defaultName = "Cashier Staff";

      String defaultFirst = defaultName;
      String defaultLast = "";
      final nameParts = defaultName.trim().replaceAll(RegExp(r'\s+'), ' ').split(' ');
      if (nameParts.length > 1) {
        defaultFirst = nameParts.first;
        defaultLast = nameParts.sublist(1).join(' ');
      }

      if (user != null) {
        try {
          await _supabase.auth.updateUser(
            UserAttributes(
              data: {
                'first_name': defaultFirst,
                'middle_initial': '',
                'last_name': defaultLast,
                'full_name': defaultName,
                'name': defaultName,
                'registered_name': defaultName,
                'phone': null,
                'phone_number': null,
                'address': null,
                'store_address': null,
                'avatar_url': null,
                'picture': null,
              },
            ),
          );
          await _supabase.auth.refreshSession();
        } catch (_) {}
      }

      // Clear local SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cashier_phone_${user?.id ?? emailToUse}');
        await prefs.remove('cashier_address_${user?.id ?? emailToUse}');
      } catch (_) {}

      // Update app_users name
      try {
        if (_appUserId != null) {
          await _supabase
              .from('app_users')
              .update({'name': defaultName})
              .eq('user_id', _appUserId!);
        } else if (user != null) {
          await _supabase
              .from('app_users')
              .update({'name': defaultName})
              .eq('supabase_user_id', user.id);
        } else if (emailToUse.isNotEmpty) {
          await _supabase
              .from('app_users')
              .update({'name': defaultName})
              .ilike('email', emailToUse);
        }
      } catch (_) {}

      // Reset avatar in cashiers table
      if (_appUserId != null) {
        try {
          await _supabase
              .from('cashiers')
              .update({'avatar_url': null})
              .eq('user_id', _appUserId!);
        } catch (_) {}
      }

      setState(() {
        _cashierName = defaultName;
        _cashierPhone = 'Not set';
        _cashierAddress = 'Not set';
        _cashierAvatarUrl = null;
      });

      if (mounted) {
        PiggyToast.showSuccess(context, strings.accountDetailsRestoredSuccess);
      }
      await _fetchProfile();
    } catch (e) {
      if (mounted) {
        PiggyToast.showError(context, 'Error resetting profile: $e');
      }
    }
  }

  void _showEditProfileDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parse First, Middle Initial, and Last Name from the current active _cashierName
    String prefillFirst = '';
    String prefillMiddle = '';
    String prefillLast = '';

    final nameClean = _cashierName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (nameClean.isNotEmpty && nameClean != 'Cashier Staff' && nameClean != 'N/A') {
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

    // Fallback to user metadata only if _cashierName parsing was empty
    if (prefillFirst.isEmpty && prefillLast.isEmpty) {
      final userMeta = _supabase.auth.currentUser?.userMetadata ?? {};
      prefillFirst = (userMeta['first_name'] ?? '').toString().trim();
      prefillMiddle = (userMeta['middle_initial'] ?? userMeta['middle_name'] ?? '').toString().trim();
      prefillLast = (userMeta['last_name'] ?? '').toString().trim();
    }

    final firstNameCtrl = TextEditingController(text: prefillFirst);
    final middleInitialCtrl = TextEditingController(text: prefillMiddle);
    final lastNameCtrl = TextEditingController(text: prefillLast);
    final phoneCtrl = TextEditingController(
      text: (_cashierPhone == 'N/A' || _cashierPhone == 'Not set') ? '' : _cashierPhone,
    );
    final addrCtrl = TextEditingController(
      text: (_cashierAddress == 'N/A' || _cashierAddress == 'Not set') ? '' : _cashierAddress,
    );

    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE6EBF2);
    final hintColor = isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted;
    final actionColor = isDark ? Colors.white : const Color(0xFF18314F);

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
              final result = await LocationService.instance.getCurrentAddress(requestPermission: true);
              setModalState(() => isDetectingGps = false);

              if (result.success && result.address != null && result.address!.trim().isNotEmpty) {
                addrCtrl.text = result.address!.trim();
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
                                    color: isDark ? Colors.white : const Color(0xFF18314F),
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

                        // 1. First Name & Middle Initial Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldHeaderRow(
                                    label: strings.firstNameLabel,
                                    titleColor: titleColor,
                                  ),
                                  _buildDialogInputField(
                                    context,
                                    controller: firstNameCtrl,
                                    hintText: 'e.g. Juan',
                                    icon: Icons.person_outline_rounded,
                                    hasError: firstNameError != null,
                                    inputFormatters: const [NameInputFormatter()],
                                    onChanged: (_) {
                                      if (firstNameError != null) setModalState(() => firstNameError = null);
                                    },
                                  ),
                                  _buildInlineErrorText(firstNameError),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldHeaderRow(
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
                                  _buildDialogInputField(
                                    context,
                                    controller: middleInitialCtrl,
                                    hintText: 'M.',
                                    maxLength: 2,
                                    icon: Icons.edit_note_rounded,
                                    textCapitalization: TextCapitalization.characters,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\u00D1\u00F1]')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 2. Last Name Field
                        _buildFieldHeaderRow(
                          label: strings.lastNameLabel,
                          titleColor: titleColor,
                        ),
                        _buildDialogInputField(
                          context,
                          controller: lastNameCtrl,
                          hintText: 'e.g. Dela Cruz',
                          icon: Icons.badge_outlined,
                          hasError: lastNameError != null,
                          inputFormatters: const [NameInputFormatter()],
                          onChanged: (_) {
                            if (lastNameError != null) setModalState(() => lastNameError = null);
                          },
                        ),
                        _buildInlineErrorText(lastNameError),
                        const SizedBox(height: 14),

                        // 3. Phone Number Field
                        _buildFieldHeaderRow(
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
                        _buildDialogInputField(
                          context,
                          controller: phoneCtrl,
                          hintText: '09XXXXXXXXX',
                          icon: Icons.phone_iphone_rounded,
                          keyboardType: TextInputType.phone,
                          hasError: phoneError != null,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          onChanged: (_) {
                            if (phoneError != null) setModalState(() => phoneError = null);
                          },
                        ),
                        _buildInlineErrorText(phoneError),
                        const SizedBox(height: 14),

                        // 4. Address Field with Auto-Detect Action
                        _buildFieldHeaderRow(
                          label: strings.address,
                          titleColor: titleColor,
                          trailing: InkWell(
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
                        ),
                        _buildDialogInputField(
                          context,
                          controller: addrCtrl,
                          readOnly: true,
                          onTap: isDetectingGps ? null : autoDetectGps,
                          hintText: isDetectingGps ? strings.detectingGps : strings.tapToDetectGpsAddress,
                          icon: Icons.location_on_outlined,
                          suffixIcon: isDetectingGps
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: actionColor,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (addrCtrl.text.trim().isNotEmpty)
                                      IconButton(
                                        icon: Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                        tooltip: strings.cancel,
                                        onPressed: () {
                                          setModalState(() {
                                            addrCtrl.clear();
                                          });
                                        },
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.my_location_rounded,
                                        size: 20,
                                        color: actionColor,
                                      ),
                                      tooltip: strings.autoDetectLocation,
                                      onPressed: autoDetectGps,
                                    ),
                                  ],
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
                                  final first = firstNameCtrl.text.trim();
                                  final middle = middleInitialCtrl.text.trim().replaceAll('.', '').toUpperCase();
                                  final last = lastNameCtrl.text.trim();
                                  final newPhone = phoneCtrl.text.trim();
                                  final newAddr = addrCtrl.text.trim();

                                  // Validate First Name (letters, spaces, accents, ñ/Ñ only)
                                  String? fErr;
                                  if (first.isEmpty) {
                                    fErr = strings.firstNameRequired;
                                  } else if (!RegExp(r"^[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF \-'\.]+$").hasMatch(first)) {
                                    fErr = strings.nameInvalidCharacters;
                                  }

                                  // Validate Last Name (letters, spaces, accents, ñ/Ñ only)
                                  String? lErr;
                                  if (last.isEmpty) {
                                    lErr = strings.lastNameRequired;
                                  } else if (!RegExp(r"^[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF \-'\.]+$").hasMatch(last)) {
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

                                  if (fErr != null || lErr != null || pErr != null) {
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

                                  setState(() {
                                    if (newCombinedName.isNotEmpty) _cashierName = newCombinedName;
                                    _cashierPhone = newPhone.isNotEmpty ? newPhone : 'Not set';
                                    _cashierAddress = newAddr.isNotEmpty ? newAddr : 'Not set';
                                  });

                                  Navigator.pop(ctx);

                                  try {
                                    final user = _supabase.auth.currentUser;
                                    final emailToUse = _cashierEmail.isNotEmpty ? _cashierEmail : (user?.email ?? '');

                                    // 1. Update Supabase auth user metadata so First, Middle, Last names, phone, address stay synchronized
                                    if (user != null) {
                                      try {
                                        final existingMeta = user.userMetadata ?? {};
                                        final regName = (existingMeta['registered_name'] ?? existingMeta['original_name'] ?? _cashierName).toString().trim();
                                        await _supabase.auth.updateUser(
                                          UserAttributes(
                                            data: {
                                              'first_name': first,
                                              'middle_initial': middle,
                                              'last_name': last,
                                              'full_name': newCombinedName,
                                              'name': newCombinedName,
                                              'phone': newPhone,
                                              'phone_number': newPhone,
                                              'address': newAddr,
                                              'store_address': newAddr,
                                              if (regName.isNotEmpty && regName.toLowerCase() != 'cashier staff')
                                                'registered_name': regName,
                                            },
                                          ),
                                        );
                                        await _supabase.auth.refreshSession();
                                      } catch (_) {}
                                    }

                                    // 2. Persist locally to SharedPreferences for instant local sync
                                    try {
                                      final prefs = await SharedPreferences.getInstance();
                                      final keyPhone = 'cashier_phone_${user?.id ?? emailToUse}';
                                      final keyAddr = 'cashier_address_${user?.id ?? emailToUse}';
                                      if (newPhone.isNotEmpty) {
                                        await prefs.setString(keyPhone, newPhone);
                                      } else {
                                        await prefs.remove(keyPhone);
                                      }
                                      if (newAddr.isNotEmpty) {
                                        await prefs.setString(keyAddr, newAddr);
                                      } else {
                                        await prefs.remove(keyAddr);
                                      }
                                    } catch (_) {}

                                    // 3. Update app_users table with valid column (name)
                                    try {
                                      if (_appUserId != null) {
                                        await _supabase
                                            .from('app_users')
                                            .update({'name': newCombinedName})
                                            .eq('user_id', _appUserId!);
                                      } else if (user != null) {
                                        await _supabase
                                            .from('app_users')
                                            .update({'name': newCombinedName})
                                            .eq('supabase_user_id', user.id);
                                      } else if (emailToUse.isNotEmpty) {
                                        await _supabase
                                            .from('app_users')
                                            .update({'name': newCombinedName})
                                            .ilike('email', emailToUse);
                                      }
                                    } catch (appUserErr) {
                                      debugPrint('Error updating app_users: $appUserErr');
                                    }

                                    // 4. Record update in admin_notifications so Admin Web can reflect phone and store address in real time
                                    try {
                                      await _supabase.from('admin_notifications').insert({
                                        'type': 'cashier_profile',
                                        'title': 'Cashier Profile Updated',
                                        'message': '$newCombinedName updated their profile details.',
                                        'metadata': {
                                          'user_id': _appUserId,
                                          'supabase_user_id': user?.id,
                                          'email': emailToUse,
                                          'name': newCombinedName,
                                          'first_name': first,
                                          'middle_initial': middle,
                                          'last_name': last,
                                          'phone': newPhone,
                                          'contact_number': newPhone,
                                          'address': newAddr,
                                          'store_address': newAddr,
                                          'updated_at': DateTime.now().toIso8601String(),
                                        },
                                      });
                                    } catch (notifErr) {
                                      debugPrint('Notice inserting admin notification: $notifErr');
                                    }

                                    await _fetchProfile();
                                    if (mounted) {
                                      PiggyToast.showSuccess(
                                        context,
                                        strings.profileUpdateSuccess,
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      PiggyToast.showError(
                                        context,
                                        'Error updating profile: $e',
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.white : const Color(0xFF18314F),
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

  Widget _buildFieldHeaderRow({
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

  Widget _buildInlineErrorText(String? errorText) {
    if (errorText == null || errorText.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFEF4444)),
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

  Widget _buildDialogInputField(
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
    final effectiveFormatters = inputFormatters ??
        (keyboardType == TextInputType.phone ? null : const [CapitalizeWordsInputFormatter()]);
    final errorBorderColor = const Color(0xFFEF4444);
    final normalBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE6EBF2);

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
        color: isDark ? Colors.white : const Color(0xFF18314F),
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
            ? Icon(icon, size: 20, color: hasError ? errorBorderColor : (isDark ? Colors.white70 : const Color(0xFF18314F)))
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        contentPadding: EdgeInsets.symmetric(horizontal: icon != null ? 14 : 16, vertical: 13),
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
            color: hasError ? errorBorderColor : (isDark ? Colors.white : const Color(0xFF18314F)),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await AuthSessionService().clearSession();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/onboarding', (route) => false);
      }
    } catch (e) {
      _showSnackBar('Error signing out: $e', isError: true);
    }
  }

  // ===================== POS ACTIONS =====================

  void _onAddToCart(POSProduct product) {
    if (product.stock <= 0) {
      _showSnackBar('Product is out of stock', isError: true);
      return;
    }

    setState(() {
      final existingIndex = _currentOrder.items.indexWhere(
        (item) => item.productId == product.id,
      );
      if (existingIndex >= 0) {
        final currentQty = _currentOrder.items[existingIndex].quantity;
        if (currentQty < product.stock) {
          _currentOrder.items[existingIndex] = _currentOrder
              .items[existingIndex]
              .copyWith(quantity: currentQty + 1);
        } else {
          _showSnackBar(
            'Cannot exceed available stock (${product.stock})',
            isError: true,
          );
          return;
        }
      } else {
        _orderItemCounter++;
        _currentOrder.items.add(
          OrderItem(
            id: _orderItemCounter,
            productId: product.id,
            productName: product.name,
            price: product.price,
            quantity: 1,
            image: product.image,
          ),
        );
      }
    });

    _showSnackBar('Added ${product.name} to cart');
  }

  void _onUpdateItemQuantity(OrderItem item, int newQuantity) {
    setState(() {
      final index = _currentOrder.items.indexWhere(
        (i) => i.productId == item.productId,
      );
      if (index >= 0) {
        if (newQuantity <= 0) {
          _currentOrder.items.removeAt(index);
        } else {
          _currentOrder.items[index] = _currentOrder.items[index].copyWith(
            quantity: newQuantity,
          );
        }
      }
    });
  }

  void _onRemoveItem(OrderItem item) {
    setState(() {
      _currentOrder.items.removeWhere((i) => i.productId == item.productId);
    });
    _showSnackBar('Removed ${item.productName} from cart');
  }

  void _onClearCart() {
    setState(() {
      _currentOrder.items.clear();
    });
  }

  Future<void> _handleCompletePOSSale({
    required String customerName,
    required String customerType,
    required String paymentMethod,
    required double tenderedAmount,
    required double changeAmount,
    required Order order,
  }) async {
    final double totalAmount = order.total;
    final int totalUnits = order.items.fold<int>(
      0,
      (sum, i) => sum + i.quantity,
    );
    final nowStr = DateTime.now().toIso8601String();
    final cashierIdentifier = _cashierName.trim().isNotEmpty
        ? _cashierName.trim()
        : (_supabase.auth.currentUser?.email ?? 'Cashier Staff');

    // 1. Insert Sales Record into sales table
    try {
      await _supabase.from('sales').insert({
        'total_amount': totalAmount,
        'quantity': totalUnits,
        'sale_date': nowStr,
        'type': 'pos_cashier',
      });
    } catch (e) {
      debugPrint('Sales table summary insert fallback: $e');
    }

    // 2. Deduct Inventory & Insert Inventory Logs for each item
    for (final item in order.items) {
      final matchingProduct = _allProducts.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => POSProduct(
          id: item.productId,
          name: item.productName,
          categoryId: '',
          category: 'Feeds',
          description: '',
          price: item.price,
          units: 0,
          sold: 0,
        ),
      );

      final newStock = (matchingProduct.stock - item.quantity).clamp(0, 999999);
      final newSold = matchingProduct.sold + item.quantity;

      // Deduct stock in database
      try {
        await _supabase
            .from('inventory_products')
            .update({'units': newStock, 'sold': newSold})
            .eq('id', item.productId);
      } catch (_) {
        try {
          await _supabase
              .from('products')
              .update({'units': newStock, 'sold': newSold})
              .eq('id', item.productId);
        } catch (_) {}
      }

      // Log sale item in inventory_logs
      try {
        final logPayload = <String, dynamic>{
          'product_name': item.productName,
          'action': 'SALE',
          'performed_by': cashierIdentifier,
          'price': item.subtotal,
          'units': item.quantity,
          'details': 'POS Sale to $customerName ($paymentMethod) by $cashierIdentifier • Tendered: ₱${tenderedAmount.toStringAsFixed(2)}, Change: ₱${changeAmount.toStringAsFixed(2)}',
          'created_at': nowStr,
        };

        // If productId is a valid UUID, include it
        if (item.productId.length >= 32) {
          logPayload['product_id'] = item.productId;
        }

        await _supabase.from('inventory_logs').insert(logPayload);
      } catch (e) {
        debugPrint('Inventory logs insert error: $e');
      }

      // Insert item-level sale in pos_sales table for demand forecasting
      try {
        await _supabase.from('pos_sales').insert({
          'order_id': 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}',
          'product_id': item.productId.length >= 32 ? item.productId : null,
          'product_name': item.productName,
          'category': matchingProduct.category.isNotEmpty ? matchingProduct.category : 'Feeds',
          'quantity': item.quantity,
          'unit_price': item.price,
          'total_amount': item.subtotal,
          'sale_date': nowStr,
          'customer_name': customerName,
          'customer_type': customerType,
          'payment_method': paymentMethod,
          'cashier_name': cashierIdentifier,
          'created_at': nowStr,
        });
      } catch (e) {
        debugPrint('pos_sales mobile insert fallback: $e');
      }

      // Also try item-level insert in sales table
      try {
        final numProductId = int.tryParse(item.productId);
        final itemSaleData = <String, dynamic>{
          'total_amount': item.subtotal,
          'quantity': item.quantity,
          'sale_date': nowStr,
          'type': 'pos_cashier',
        };
        if (numProductId != null) itemSaleData['product_id'] = numProductId;
        await _supabase.from('sales').insert(itemSaleData);
      } catch (_) {}
    }

    // Immediately update local sales logs so the receipt is visible right away
    if (mounted) {
      setState(() {
        for (final item in order.items) {
          _salesLogs.insert(0, {
            'id': DateTime.now().millisecondsSinceEpoch,
            'product_name': item.productName,
            'total_amount': item.subtotal,
            'quantity': item.quantity,
            'sale_date': nowStr,
            'created_at': nowStr,
            'cashier_name': cashierIdentifier,
            'customer_name': customerName,
            'payment_method': paymentMethod,
          });
        }
      });
    }

    await _fetchInventory();
    await _fetchSalesLogs();
  }

  // ===================== REQUEST PROCESSING =====================

  Future<void> _processRequest(
    int requestId,
    String status, {
    int? allocatedSacks,
    int? productId,
  }) async {
    try {
      final updateData = {'status': status};
      if (allocatedSacks != null) {
        updateData['allocated_sacks'] = allocatedSacks.toString();
      }

      await _supabase
          .from('stock_requests')
          .update(updateData)
          .eq('request_id', requestId);

      if (status == 'Approved' && allocatedSacks != null && productId != null) {
        try {
          final prod = await _supabase
              .from('inventory_products')
              .select('units, name')
              .eq('id', productId)
              .maybeSingle();
          if (prod != null) {
            final currentStock = prod['units'] as int? ?? 0;
            final newStock = (currentStock - allocatedSacks).clamp(0, 999999);
            await _supabase
                .from('inventory_products')
                .update({'units': newStock})
                .eq('id', productId);

            await _supabase.from('inventory_logs').insert({
              'product_name': prod['name'] ?? 'Feed Product',
              'action': 'OUT',
              'units': allocatedSacks,
              'price': 0,
              'details': 'Stock request #$requestId approved and distributed',
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        } catch (e) {
          debugPrint('Error deducting stock on allocation: $e');
        }
      }

      await _fetchPendingRequests();
      await _fetchInventory();
      _showSnackBar('Request #$requestId marked as $status');
    } catch (e) {
      _showSnackBar('Failed to process request: $e', isError: true);
    }
  }

  void _showRequestsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StockRequestsModal(
        pendingRequests: _pendingRequests,
        onProcessRequest: (id, status) => _processRequest(id, status),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      PiggyToast.showError(context, message);
    } else {
      PiggyToast.showSuccess(context, message);
    }
  }

  void _openSalesHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Sales Receipts',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _brandColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _salesLogs.isEmpty
                    ? const CashierEmptyState(
                        message: 'No sales receipts found',
                        icon: Icons.receipt_long_outlined,
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: _salesLogs.length,
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final sale = _salesLogs[index];
                          final invoice =
                              (sale['invoice_number'] ??
                                      sale['receipt_number'] ??
                                      '#SALE-${sale['id'] ?? index + 1001}')
                                  .toString();
                          final rawTotal =
                              sale['total_amount'] ?? sale['total'] ?? 0;
                          final double total = rawTotal is num
                              ? rawTotal.toDouble()
                              : double.tryParse(rawTotal.toString()) ?? 0.0;
                          final String paymentMethod =
                              (sale['payment_method'] ?? 'Cash').toString();
                          final dateStr =
                              (sale['sale_date'] ?? sale['created_at'])
                                  ?.toString() ??
                              '';

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.receipt_rounded,
                                    color: _brandColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        invoice,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _brandColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '$paymentMethod • $dateStr',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: PiggyTrunkTheme.ptMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₱${total.toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit the app'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? PiggyTrunkTheme.ptBgDark : const Color(0xFFF8FAFC),
        body: SafeArea(
          bottom: false,
          child: _isLoading
              ? CashierDashboardSkeleton(
                  currentIndex: _currentIndex,
                )
              : IndexedStack(
                  index: _currentIndex,
                  children: [
                    // Tab 0: Home
                    CashierHomeTab(
                      cashierName: _cashierName,
                      allProducts: _allProducts,
                      lowStockProducts: _lowStockProducts,
                      pendingRequests: _pendingRequests,
                      salesLogs: _salesLogs,
                      readNotificationIds: _readNotificationIds,
                      lastMarkAllReadTime: _lastMarkAllReadTime,
                      onNavigateToPOS: () => setState(() => _currentIndex = 3),
                      onNavigateToInventory: () =>
                          setState(() => _currentIndex = 2),
                      onNavigateToRequests: () =>
                          setState(() => _currentIndex = 1),
                      onShowRequestsDialog: _showRequestsDialog,
                      onShowSalesHistory: _openSalesHistoryModal,
                      onMarkAllAsRead: () async {
                        setState(() {
                          _lastMarkAllReadTime = DateTime.now();
                          for (final req in _pendingRequests) {
                            final raw = req['request_id'] ?? req['id'];
                            if (raw != null) _readNotificationIds.add('req_$raw');
                            if (req['id'] != null) _readNotificationIds.add('req_${req['id']}');
                            if (req['request_id'] != null) _readNotificationIds.add('req_${req['request_id']}');
                          }
                          for (final p in _lowStockProducts) {
                            _readNotificationIds.add('stock_${p.id}');
                          }
                          for (final sale in _salesLogs) {
                            final raw = sale['sale_id'] ?? sale['id'];
                            if (raw != null) _readNotificationIds.add('sale_$raw');
                            if (sale['id'] != null) _readNotificationIds.add('sale_${sale['id']}');
                            if (sale['sale_id'] != null) _readNotificationIds.add('sale_${sale['sale_id']}');
                          }
                        });
                        await _saveReadNotifications();
                      },
                      onMarkAsRead: (id) async {
                        setState(() {
                          _readNotificationIds.add(id);
                        });
                        await _saveReadNotifications();
                      },
                      onAddToCart: (product) {
                        _onAddToCart(product);
                      },
                      onRefresh: () async {
                        await _fetchProfile();
                        await _fetchInventory();
                        await _fetchPendingRequests();
                        await _fetchSalesLogs();
                      },
                    ),

                    // Tab 1: Requests / Allocation
                    CashierRequestsTab(
                      pendingRequests: _pendingRequests,
                      allProducts: _allProducts,
                      onProcessRequest: _processRequest,
                    ),

                    // Tab 2: Inventory Management (Exact Replica of Admin Inventory UI)
                    CashierInventoryTab(onProductsChanged: _fetchInventory),

                    // Tab 3: POS (Point of Sale Mirrored with Admin UI)
                    CashierPOSTab(
                      allProducts: _allProducts,
                      categories: _categories,
                      selectedCategory: _selectedCategory,
                      currentOrder: _currentOrder,
                      showSalesHistory: _showSalesHistory,
                      salesLogs: _salesLogs,
                      isLoadingSales: _isLoadingSales,
                      cashierName: _cashierName,
                      onCategorySelected: (cat) =>
                          setState(() => _selectedCategory = cat),
                      onAddToCart: _onAddToCart,
                      onShowCartSummary: () {},
                      onUpdateItemQuantity: _onUpdateItemQuantity,
                      onRemoveItem: _onRemoveItem,
                      onClearCart: _onClearCart,
                      onCompleteSale: _handleCompletePOSSale,
                      onRefresh: () async {
                        await _fetchInventory();
                        await _fetchSalesLogs();
                      },
                    ),

                    // Tab 4: Profile
                    CashierProfileTab(
                      cashierName: _cashierName,
                      cashierEmail: _cashierEmail,
                      cashierPhone: _cashierPhone,
                      cashierAddress: _cashierAddress,
                      cashierAvatarUrl: _cashierAvatarUrl,
                      onPickAndUploadAvatar: _pickAndUploadAvatar,
                      onRestoreDefaultAvatar: _restoreDefaultAvatar,
                      onResetProfile: _resetProfileToDefault,
                      onShowEditProfileDialog: _showEditProfileDialog,
                      onHandleLogout: _handleLogout,
                    ),
                  ],
                ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151F2E) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF28354A) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: isDark ? const Color(0xFF151F2E) : Colors.white,
            selectedItemColor: isDark ? Colors.white : _brandColor,
            unselectedItemColor: isDark ? PiggyTrunkTheme.ptMutedDark : const Color(0xFF909BB0),
            selectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            elevation: 0,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home_rounded),
                label: strings.navHome,
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: _pendingRequests
                      .where((r) => r['status'] == 'Pending')
                      .isNotEmpty,
                  label: Text(
                    '${_pendingRequests.where((r) => r['status'] == 'Pending').length}',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.assignment_outlined),
                ),
                activeIcon: const Icon(Icons.assignment_rounded),
                label: strings.navRequest,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.inventory_2_outlined),
                activeIcon: const Icon(Icons.inventory_2_rounded),
                label: strings.navInventory,
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: _currentOrder.items.isNotEmpty,
                  label: Text(
                    '${_currentOrder.totalItems}',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF10B981),
                  child: const Icon(Icons.point_of_sale_outlined),
                ),
                activeIcon: const Icon(Icons.point_of_sale_rounded),
                label: strings.navPOS,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline_rounded),
                activeIcon: const Icon(Icons.person_rounded),
                label: strings.navProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
