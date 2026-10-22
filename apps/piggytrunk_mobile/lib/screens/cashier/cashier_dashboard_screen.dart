import 'dart:async';
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
      final savedList = prefs.getStringList('cashier_read_notifications') ?? [];
      if (mounted) {
        setState(() {
          _readNotificationIds.addAll(savedList);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveReadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cashier_read_notifications', _readNotificationIds.toList());
    } catch (_) {}
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

      _cashierEmail = effectiveEmail;

      // Extract Google Metadata if available
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
              .select('user_id, name, email, phone, address, avatar_url')
              .eq('supabase_user_id', user.id)
              .maybeSingle();
        } catch (_) {}
      }

      if (profile == null && effectiveEmail.isNotEmpty) {
        try {
          profile = await _supabase
              .from('app_users')
              .select('user_id, name, email, phone, address, avatar_url')
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

      Map<String, dynamic>? cashierRow;
      if (effectiveEmail.isNotEmpty) {
        try {
          cashierRow = await _supabase
              .from('cashiers')
              .select('cashier_id, name, email, phone, address, avatar_url')
              .ilike('email', effectiveEmail)
              .maybeSingle();
        } catch (_) {}
      }

      String resolvedName = "";
      String resolvedPhone = "Not set";
      String resolvedAddress = "Not set";
      String? resolvedAvatar;

      if (profile != null) {
        final dbName = profile['name']?.toString().trim() ?? '';
        if (dbName.isNotEmpty && dbName != 'Cashier Staff' && dbName != 'N/A') {
          resolvedName = dbName;
        }
        if (profile['phone']?.toString().trim().isNotEmpty == true &&
            profile['phone'] != 'N/A') {
          resolvedPhone = profile['phone'];
        }
        if (profile['address']?.toString().trim().isNotEmpty == true &&
            profile['address'] != 'N/A') {
          resolvedAddress = profile['address'];
        }
        final pAv = profile['avatar_url']?.toString().trim();
        if (pAv != null &&
            pAv.isNotEmpty &&
            !pAv.toLowerCase().contains('googleusercontent.com') &&
            !pAv.toLowerCase().contains('ggpht.com')) {
          resolvedAvatar = pAv;
        }
      }

      if (cashierRow != null) {
        final cName = cashierRow['name']?.toString().trim() ?? '';
        if (resolvedName.isEmpty &&
            cName.isNotEmpty &&
            cName != 'Cashier Staff' &&
            cName != 'N/A') {
          resolvedName = cName;
        }
        if ((resolvedPhone == 'Not set' || resolvedPhone == 'N/A') &&
            cashierRow['phone']?.toString().trim().isNotEmpty == true &&
            cashierRow['phone'] != 'N/A') {
          resolvedPhone = cashierRow['phone'];
        }
        if ((resolvedAddress == 'Not set' || resolvedAddress == 'N/A') &&
            cashierRow['address']?.toString().trim().isNotEmpty == true &&
            cashierRow['address'] != 'N/A') {
          resolvedAddress = cashierRow['address'];
        }
        final cAv = cashierRow['avatar_url']?.toString().trim();
        if (resolvedAvatar == null &&
            cAv != null &&
            cAv.isNotEmpty &&
            !cAv.toLowerCase().contains('googleusercontent.com') &&
            !cAv.toLowerCase().contains('ggpht.com')) {
          resolvedAvatar = cAv;
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

      // Auto-sync resolved details to database if profile exists
      if (profile != null &&
          resolvedName.isNotEmpty &&
          resolvedName != 'Cashier Staff') {
        try {
          await _supabase
              .from('app_users')
              .update({'name': resolvedName})
              .eq('user_id', profile['user_id']);
          await _supabase
              .from('cashiers')
              .update({'name': resolvedName})
              .eq('user_id', profile['user_id']);
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

      // Sync across Auth User Metadata, app_users, and cashiers table for Admin Web
      try {
        await _supabase.auth.updateUser(
          UserAttributes(data: {'avatar_url': avatarUrl, 'picture': avatarUrl}),
        );
      } catch (_) {}

      try {
        await _supabase
            .from('app_users')
            .update({'avatar_url': avatarUrl})
            .or('supabase_user_id.eq.${user.id},email.eq.${user.email}');
      } catch (_) {}

      try {
        await _supabase
            .from('cashiers')
            .update({'avatar_url': avatarUrl})
            .eq('email', user.email!);
      } catch (_) {}

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

      try {
        await _supabase
            .from('app_users')
            .update({'avatar_url': null})
            .or('supabase_user_id.eq.${user.id},email.eq.${user.email}');
      } catch (_) {}

      try {
        await _supabase
            .from('cashiers')
            .update({'avatar_url': null})
            .eq('email', user.email!);
      } catch (_) {}

      setState(() => _cashierAvatarUrl = null);
      _showSnackBar('Profile picture restored to default successfully!');
      await _fetchProfile();
    } catch (e) {
      _showSnackBar('Error restoring default picture: $e', isError: true);
    }
  }

  void _showEditProfileDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentName = _cashierName == 'Cashier Staff' ? '' : _cashierName;
    final currentPhone = _cashierPhone == 'N/A' || _cashierPhone == 'Not set'
        ? ''
        : _cashierPhone;
    final currentAddress =
        _cashierAddress == 'N/A' || _cashierAddress == 'Not set'
        ? ''
        : _cashierAddress;

    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);
    final addressController = TextEditingController(text: currentAddress);

    final sheetBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final titleColor = isDark ? const Color(0xFFECF2FF) : _brandColor;
    final inputBg = isDark ? const Color(0xFF1B2A3F) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? const Color(0xFF2A3C55)
        : const Color(0xFFE2E8F0);
    final hintColor = isDark
        ? const Color(0xFF8A9FB8)
        : PiggyTrunkTheme.ptMuted;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final strings = AppStrings.of(ctx);
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
                    // Top Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Sheet Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.editProfileTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, size: 20),
                          color: hintColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Full Name Field
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: titleColor,
                      ),
                      decoration: InputDecoration(
                        hintText: strings.enterFullNameHint,
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: hintColor,
                        ),
                        filled: true,
                        fillColor: inputBg,
                        prefixIcon: Icon(
                          Icons.person_outline,
                          size: 20,
                          color: hintColor,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _brandColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone Number Field
                    Text(
                      '${strings.phoneLabel} (${strings.numbersOnlyNotice})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: titleColor,
                      ),
                      decoration: InputDecoration(
                        hintText: '09XXXXXXXXX',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: hintColor,
                        ),
                        filled: true,
                        fillColor: inputBg,
                        prefixIcon: Icon(
                          Icons.phone_iphone,
                          size: 20,
                          color: hintColor,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _brandColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Address / Branch Field
                    Text(
                      strings.address,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: addressController,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: const [CapitalizeWordsInputFormatter()],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: titleColor,
                      ),
                      decoration: InputDecoration(
                        hintText: strings.enterAddressHint,
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: hintColor,
                        ),
                        filled: true,
                        fillColor: inputBg,
                        prefixIcon: Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: hintColor,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _brandColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final newName = nameController.text.trim();
                          final newPhone = phoneController.text.trim();
                          final newAddress = addressController.text.trim();

                          if (newName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(strings.pleaseEnterFullName),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (newPhone.isNotEmpty && (newPhone.length != 11 || !newPhone.startsWith('09'))) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(strings.invalidPhoneNumber),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          final user = _supabase.auth.currentUser;
                          if (user == null) return;

                          try {
                            // 1. Update Auth User Metadata
                            try {
                              await _supabase.auth.updateUser(
                                UserAttributes(
                                  data: {'full_name': newName, 'name': newName},
                                ),
                              );
                            } catch (_) {}

                            // 2. Update app_users table (visible on Admin Web)
                            await _supabase
                                .from('app_users')
                                .update({
                                  'name': newName,
                                  'phone': newPhone.isNotEmpty ? newPhone : null,
                                  'address': newAddress.isNotEmpty
                                      ? newAddress
                                      : null,
                                })
                                .or(
                                  'supabase_user_id.eq.${user.id},email.eq.${user.email}',
                                );

                            // 3. Update cashiers table if exists (visible on Admin Web)
                            if (user.email != null) {
                              try {
                                await _supabase
                                    .from('cashiers')
                                    .update({
                                      'name': newName,
                                      'phone': newPhone.isNotEmpty
                                          ? newPhone
                                          : null,
                                      'address': newAddress.isNotEmpty
                                          ? newAddress
                                          : null,
                                    })
                                    .eq('email', user.email!);
                              } catch (_) {}
                            }

                            await _fetchProfile();
                            _showSnackBar(strings.profileUpdateSuccess);
                          } catch (e) {
                            _showSnackBar(
                              'Error updating profile: $e',
                              isError: true,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          strings.saveChanges,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    try {
      await AuthSessionService().clearSession();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
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
                      onNavigateToPOS: () => setState(() => _currentIndex = 3),
                      onNavigateToInventory: () =>
                          setState(() => _currentIndex = 2),
                      onNavigateToRequests: () =>
                          setState(() => _currentIndex = 1),
                      onShowRequestsDialog: _showRequestsDialog,
                      onShowSalesHistory: _openSalesHistoryModal,
                      onMarkAllAsRead: () {
                        setState(() {
                          for (final req in _pendingRequests) {
                            _readNotificationIds.add('req_${req['id'] ?? req['request_id']}');
                          }
                          for (final p in _lowStockProducts) {
                            _readNotificationIds.add('stock_${p.id}');
                          }
                          for (final sale in _salesLogs) {
                            _readNotificationIds.add('sale_${sale['id']}');
                          }
                        });
                        _saveReadNotifications();
                      },
                      onMarkAsRead: (id) {
                        setState(() {
                          _readNotificationIds.add(id);
                        });
                        _saveReadNotifications();
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
