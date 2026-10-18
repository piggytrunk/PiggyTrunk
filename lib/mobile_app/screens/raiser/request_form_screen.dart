import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:piggytrunk/models/pos_model.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:piggytrunk/utils/inventory_data_adapter.dart';
import '../../../widgets/common/shimmer_loading.dart';
import '../../utils/app_strings.dart';
import '../../widgets/piggy_toast.dart';

class RequestFormScreen extends StatefulWidget {
  final List<Map<String, dynamic>> activeAssignments;
  final Map<String, dynamic> raiserData;
  final double investedAmount;
  final double initialCapital;
  final double stocksSpendAmount;
  final String initialCategory;
  final bool showBackButton;
  final VoidCallback onBack;
  final VoidCallback onSuccess;
  final VoidCallback onViewHistory;

  const RequestFormScreen({
    super.key,
    required this.activeAssignments,
    required this.raiserData,
    this.investedAmount = 0.0,
    this.initialCapital = 0.0,
    this.stocksSpendAmount = 0.0,
    this.initialCategory = 'All',
    this.showBackButton = true,
    required this.onBack,
    required this.onSuccess,
    required this.onViewHistory,
  });

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<POSProduct> _products = [];
  bool _isLoadingProducts = true;
  String _errorMessage = '';

  late String _selectedCategory;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _generalNotesController = TextEditingController();

  /// Map of product_id -> quantity selected
  final Map<String, int> _cart = {};

  BigInt? _selectedAssignmentId;
  bool _isSubmitting = false;

  static const Color _brandColor = Color(0xFF18314F);
  static const Color _successGreen = Color(0xFF10B981);
  static const Color _warningAmber = Color(0xFFF59E0B);
  static const Color _dangerRed = Color(0xFFFF758C);

  late List<Map<String, dynamic>> _assignments;
  RealtimeChannel? _assignmentsChannel;

  String _resolveAssignmentPigType(Map<String, dynamic> a) {
    final htData = a['hog_types'];
    String raw = '';
    if (htData is Map) {
      raw = htData['type_name']?.toString() ?? '';
    } else if (htData is List && htData.isNotEmpty && htData.first is Map) {
      raw = htData.first['type_name']?.toString() ?? '';
    }
    if (raw.isEmpty) {
      raw = a['pig_type']?.toString() ??
          widget.raiserData['pig_type']?.toString() ??
          '';
    }
    return raw;
  }

  int _compareAssignments(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aDone = a['is_cycle_completed'] == true;
    final bDone = b['is_cycle_completed'] == true;
    if (!aDone && bDone) return -1;
    if (aDone && !bDone) return 1;

    final aType = _resolveAssignmentPigType(a).toLowerCase();
    final bType = _resolveAssignmentPigType(b).toLowerCase();
    final aIsFat = aType.contains('fatten');
    final bIsFat = bType.contains('fatten');
    if (aIsFat && !bIsFat) return -1;
    if (!aIsFat && bIsFat) return 1;

    final aId = a['assignment_id'] is num ? (a['assignment_id'] as num).toInt() : 0;
    final bId = b['assignment_id'] is num ? (b['assignment_id'] as num).toInt() : 0;
    return bId.compareTo(aId);
  }

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory.isNotEmpty ? widget.initialCategory : 'All';
    _assignments = List<Map<String, dynamic>>.from(widget.activeAssignments);
    _assignments.sort(_compareAssignments);

    if (_assignments.isNotEmpty) {
      final firstActive = _assignments.firstWhere(
        (a) => a['is_cycle_completed'] != true,
        orElse: () => _assignments[0],
      );
      _selectedAssignmentId = BigInt.from(firstActive['assignment_id'] as num);
    }

    _loadInventoryProducts();
    _refreshAssignments();
    _subscribeToRealtime();
  }

  @override
  void didUpdateWidget(covariant RequestFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeAssignments != oldWidget.activeAssignments) {
      setState(() {
        _assignments = List<Map<String, dynamic>>.from(widget.activeAssignments);
        _assignments.sort(_compareAssignments);
        final currentSelected = _selectedAssignmentId != null
            ? _assignments.firstWhere(
                (a) => BigInt.from(a['assignment_id'] as num) == _selectedAssignmentId,
                orElse: () => {},
              )
            : <String, dynamic>{};
        final isCurrentCompleted = currentSelected.isNotEmpty && currentSelected['is_cycle_completed'] == true;
        final hasNonCompleted = _assignments.any((a) => a['is_cycle_completed'] != true);

        if (_selectedAssignmentId == null ||
            !_assignments.any((a) => BigInt.from(a['assignment_id'] as num) == _selectedAssignmentId) ||
            (isCurrentCompleted && hasNonCompleted)) {
          final firstActive = _assignments.firstWhere(
            (a) => a['is_cycle_completed'] != true,
            orElse: () => _assignments.isNotEmpty ? _assignments[0] : <String, dynamic>{},
          );
          _selectedAssignmentId = firstActive.isNotEmpty
              ? BigInt.from(firstActive['assignment_id'] as num)
              : null;
        }
      });
    }
  }

  void _subscribeToRealtime() {
    try {
      _assignmentsChannel = _supabase
          .channel('public:request_form_assignments_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'assignments',
            callback: (payload) {
              debugPrint('Realtime: assignments changed, refreshing batch assignments...');
              if (mounted) _refreshAssignments();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'batches',
            callback: (payload) {
              debugPrint('Realtime: batches changed, refreshing batch assignments...');
              if (mounted) _refreshAssignments();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to assignments channel: $e');
    }
  }

  Future<void> _refreshAssignments() async {
    final raiserId = widget.raiserData['hog_raiser_id'] ?? widget.raiserData['id'];
    if (raiserId == null) return;
    try {
      final res = await _supabase
          .from('assignments')
          .select('*, hog_types(*), batches(*)')
          .eq('hog_raiser_id', raiserId)
          .or('status.eq.active,status.eq.Active,status.eq.assigned');
      final list = List<Map<String, dynamic>>.from(res);

      List<dynamic> allBatchesRaw = [];
      try {
        allBatchesRaw = await _supabase.from('batches').select('*');
      } catch (_) {}
      final Map<String, Map<String, dynamic>> allBatchesMap = {};
      for (var bRow in allBatchesRaw) {
        if (bRow is Map) {
          final id = (bRow['batch_id'] ?? bRow['id'])?.toString();
          if (id != null) allBatchesMap[id] = Map<String, dynamic>.from(bRow);
        }
      }

      final activeList = <Map<String, dynamic>>[];
      for (var a in list) {
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
          activeList.add(a);
        }
      }

      final activeAssignmentIds = activeList
          .map((a) => a['assignment_id'] ?? a['id'])
          .where((id) => id != null)
          .toList();

      List<dynamic> hogsRes = [];
      if (activeAssignmentIds.isNotEmpty) {
        try {
          hogsRes = await _supabase
              .from('hogs')
              .select('*')
              .inFilter('assignment_id', activeAssignmentIds);
        } catch (_) {}
      }
      final hogs = List<Map<String, dynamic>>.from(hogsRes)
          .where((h) => (h['health_status'] ?? '').toString().toLowerCase() != 'dead')
          .toList();

      for (var a in activeList) {
        final aIdStr = (a['assignment_id'] ?? a['id'])?.toString();
        final b = a['batches'] is Map ? a['batches'] as Map : null;
        final bStatus = (b?['status'] ?? b?['batch_status'] ?? '').toString().toLowerCase();
        final isExplicitlyCompleted = bStatus == 'completed' ||
            bStatus == 'sold' ||
            bStatus == 'finished' ||
            bStatus == 'harvested' ||
            (a['status'] ?? '').toString().toLowerCase() == 'completed' ||
            (a['status'] ?? '').toString().toLowerCase() == 'finished';

        final assignHogs = hogs.where((h) => h['assignment_id']?.toString() == aIdStr).toList();
        final rawHogType = (a['hog_types']?['type_name'] ?? a['pig_type'] ?? '').toString().toLowerCase();
        final isSow = rawHogType.contains('sow') || rawHogType.contains('breed');

        if (isExplicitlyCompleted) {
          a['is_cycle_completed'] = true;
        } else if (assignHogs.isNotEmpty) {
          final allHogsAtFinalStage = assignHogs.every((h) {
            final hStatus = (h['status'] ?? '').toString().trim().toLowerCase();
            final s = (h['stage_id'] ?? h['lifecycle_stage'] ?? h['stage'] ?? '').toString().trim().toLowerCase();
            return hStatus == 'completed' || (isSow
                ? (s == 'lactation' || s == '6' || s.contains('lactat'))
                : (s == 'selling' || s == 'sold' || s == '6' || s.contains('sell')));
          });
          a['is_cycle_completed'] = allHogsAtFinalStage;
        } else {
          final assignStage = (a['lifecycle_stage'] ?? a['current_stage'] ?? '').toString().trim().toLowerCase();
          bool stageCompleted = false;
          if (isSow && (assignStage == 'lactation' || assignStage.contains('lactat'))) {
            stageCompleted = true;
          } else if (!isSow && (assignStage == 'selling' || assignStage == 'sold' || assignStage.contains('sell'))) {
            stageCompleted = true;
          }
          a['is_cycle_completed'] = stageCompleted;
        }

        // Carry over per-batch capital isolation from widget.activeAssignments
        final matchWidget = widget.activeAssignments.firstWhere(
          (w) => (w['assignment_id'] ?? w['id'])?.toString() == aIdStr,
          orElse: () => <String, dynamic>{},
        );
        if (matchWidget.isNotEmpty) {
          a['initial_capital'] = matchWidget['initial_capital'];
          a['stocks_spend'] = matchWidget['stocks_spend'];
          a['remaining_capital'] = matchWidget['remaining_capital'];
          a['provided_stocks'] = matchWidget['provided_stocks'];
          a['is_investment_depleted'] = matchWidget['is_investment_depleted'];
        }
      }

      activeList.sort(_compareAssignments);

      if (mounted) {
        setState(() {
          _assignments = activeList;
          if (_assignments.isEmpty) {
            _selectedAssignmentId = null;
          } else {
            final currentSelected = _selectedAssignmentId != null
                ? _assignments.firstWhere(
                    (a) => BigInt.from(a['assignment_id'] as num) == _selectedAssignmentId,
                    orElse: () => {},
                  )
                : <String, dynamic>{};
            final isCurrentCompleted = currentSelected.isNotEmpty && currentSelected['is_cycle_completed'] == true;
            final hasNonCompleted = _assignments.any((a) => a['is_cycle_completed'] != true);

            if (currentSelected.isEmpty || (isCurrentCompleted && hasNonCompleted)) {
              _selectedAssignmentId = BigInt.from(_assignments[0]['assignment_id'] as num);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error refreshing assignments: $e');
    }
  }

  Map<String, dynamic> get _selectedAssignment {
    if (_assignments.isEmpty) return {};
    return _assignments.firstWhere(
      (a) => _selectedAssignmentId != null && BigInt.from(a['assignment_id'] as num) == _selectedAssignmentId,
      orElse: () => _assignments.first,
    );
  }

  bool get _isCurrentBatchCompleted {
    final a = _selectedAssignment;
    return a['is_cycle_completed'] == true;
  }

  double get _currentBatchInitialCapital {
    final a = _selectedAssignment;
    final cap = (a['initial_capital'] as num?)?.toDouble();
    if (cap != null && cap > 0) return cap;
    return widget.initialCapital;
  }

  double get _currentBatchStocksSpend {
    final a = _selectedAssignment;
    final spend = (a['stocks_spend'] as num?)?.toDouble();
    if (spend != null) return spend;
    return widget.stocksSpendAmount;
  }

  double get _currentBatchInvestedAmount {
    final a = _selectedAssignment;
    final rem = (a['remaining_capital'] as num?)?.toDouble();
    if (rem != null) return rem;
    return widget.investedAmount;
  }

  bool get _isInvestmentDepleted {
    return _currentBatchInvestedAmount <= 0 && (_currentBatchInitialCapital > 0 || _currentBatchStocksSpend > 0);
  }

  @override
  void dispose() {
    if (_assignmentsChannel != null) {
      _supabase.removeChannel(_assignmentsChannel!);
    }
    _searchCtrl.dispose();
    _generalNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _errorMessage = '';
    });

    try {
      List<dynamic> rows = [];
      String sourceTable = 'inventory_products';

      try {
        rows = await _supabase
            .from('inventory_products')
            .select()
            .eq('is_archived', false)
            .order('created_at', ascending: false);
      } catch (err) {
        debugPrint('Fallback to products table: $err');
        rows = await _supabase
            .from('products')
            .select()
            .eq('is_archived', false)
            .order('created_at', ascending: false);
        sourceTable = 'products';
      }

      final normalized = normalizeInventoryRows(rows, sourceTable: sourceTable);
      final parsed = normalized.map((r) => POSProduct.fromJson(r)).toList();

      if (mounted) {
        setState(() {
          _products = parsed;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading inventory products: $e');
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  int get _totalCartItems => _cart.values.fold(0, (sum, q) => sum + q);

  double get _totalCartEstimatedCost {
    double total = 0.0;
    for (final entry in _cart.entries) {
      final p = _products.firstWhere((prod) => prod.id == entry.key, orElse: () => _fallbackProduct(entry.key));
      total += p.price * entry.value;
    }
    return total;
  }

  POSProduct _fallbackProduct(String id) {
    return POSProduct(
      id: id,
      name: 'Product',
      categoryId: 'others',
      category: 'Others',
      description: '',
      price: 0.0,
      units: 0,
      sold: 0,
    );
  }

  String _formatAssignmentLabel(Map<String, dynamic> a) {
    final bData = a['batches'];
    String rawBatchName = '';
    if (bData is Map) {
      rawBatchName = bData['batch_name']?.toString() ?? '';
    } else if (bData is List && bData.isNotEmpty && bData.first is Map) {
      rawBatchName = bData.first['batch_name']?.toString() ?? '';
    }
    if (rawBatchName.isEmpty) {
      rawBatchName = (a['batch_name'] ?? (a['assignment_id'] != null ? 'Batch #${a['assignment_id']}' : 'No Batch')).toString();
    }
    String displayBatchName = rawBatchName;
    if (rawBatchName.contains(' (')) {
      final parts = rawBatchName.split(' (');
      if (parts.last.endsWith(')')) {
        displayBatchName = parts.sublist(0, parts.length - 1).join(' (');
      }
    }
    final htData = a['hog_types'];
    String rawHogType = '';
    if (htData is Map) {
      rawHogType = htData['type_name']?.toString() ?? '';
    } else if (htData is List && htData.isNotEmpty && htData.first is Map) {
      rawHogType = htData.first['type_name']?.toString() ?? '';
    }
    if (rawHogType.isEmpty) {
      rawHogType = a['pig_type']?.toString() ??
          widget.raiserData['pig_type']?.toString() ??
          '';
    }
    return '$displayBatchName${rawHogType.isNotEmpty ? " ($rawHogType)" : ""}';
  }

  void _addToCart(POSProduct product) {
    final strings = AppStrings.of(context);
    if (_assignments.isEmpty) {
      PiggyToast.showWarning(
        context,
        strings.isFilipino
            ? 'Hindi makakapagdagdag. Kailangan muna ng aktibong batch bago makahiling ng supply.'
            : 'Cannot add items. An active batch assignment is required to request supplies.',
      );
      return;
    }
    if (_isCurrentBatchCompleted) {
      PiggyToast.showWarning(
        context,
        strings.isFilipino
            ? 'Tapos na ang siklo ng batch na ito. Bawal nang humiling ng karagdagang supply. Mangyaring maghintay sa susunod na batch mula sa Farm Admin.'
            : 'This batch cycle is completed. Supplies can no longer be requested for this batch. Please wait for Farm Admin to assign your next batch.',
        title: strings.isFilipino ? 'Tapos na ang Siklo' : 'Cycle Completed',
        duration: const Duration(seconds: 4),
      );
      return;
    }
    if (product.units <= 0) {
      PiggyToast.showWarning(
        context,
        strings.isFilipino
            ? 'Ang produktong ito ay kasalukuyang ubos na.'
            : 'This product is currently out of stock.',
      );
      return;
    }
    final currentQty = _cart[product.id] ?? 0;
    if (currentQty >= product.units) {
      PiggyToast.showWarning(
        context,
        strings.isFilipino
            ? 'Hindi na makakapagdagdag. Ang natitirang stock ay ${product.units} piraso.'
            : 'Cannot add more. Available stock is ${product.units} units.',
      );
      return;
    }
    setState(() {
      _cart[product.id] = currentQty + 1;
    });
  }

  void _decrementCart(POSProduct product) {
    final currentQty = _cart[product.id] ?? 0;
    if (currentQty <= 1) {
      setState(() {
        _cart.remove(product.id);
      });
    } else {
      setState(() {
        _cart[product.id] = currentQty - 1;
      });
    }
  }

  int _categoryRank(String category) {
    final cat = category.toLowerCase().trim();
    if (cat.contains('feed')) return 0;
    if (cat.contains('med')) return 1;
    if (cat.contains('vit')) return 2;
    return 3;
  }

  List<POSProduct> get _filteredProducts {
    final query = _searchCtrl.text.trim().toLowerCase();
    final list = _products.where((p) {
      // Category filter
      if (_selectedCategory != 'All') {
        final cat = p.category.trim().toLowerCase();
        final selected = _selectedCategory.toLowerCase();
        if (selected == 'feeds' && !cat.contains('feed')) return false;
        if (selected == 'medicine' && !cat.contains('med')) return false;
        if (selected == 'vitamins' && !cat.contains('vit')) return false;
        if (selected == 'others' && (cat.contains('feed') || cat.contains('med') || cat.contains('vit'))) return false;
      }

      // Search query
      if (query.isNotEmpty) {
        final name = p.name.toLowerCase();
        final desc = p.description.toLowerCase();
        final cat = p.category.toLowerCase();
        if (!name.contains(query) && !desc.contains(query) && !cat.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Map each product to its original POS index so the sequence matches POS exactly
    final posIndexMap = <String, int>{};
    for (int i = 0; i < _products.length; i++) {
      posIndexMap[_products[i].id] = i;
    }

    // Sort: Category priority (Feeds -> Medicine -> Vitamins -> Others),
    // and within each category, preserve the exact POS order!
    list.sort((a, b) {
      final rankA = _categoryRank(a.category);
      final rankB = _categoryRank(b.category);
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      final idxA = posIndexMap[a.id] ?? 999999;
      final idxB = posIndexMap[b.id] ?? 999999;
      return idxA.compareTo(idxB);
    });

    return list;
  }

  Future<void> _submitRequest() async {
    final strings = AppStrings.of(context);

    if (widget.activeAssignments.isEmpty) {
      PiggyToast.showWarning(
        context,
        strings.batchRequiredMessage,
        title: strings.batchRequiredTitle,
        duration: const Duration(milliseconds: 4000),
      );
      return;
    }

    if (_selectedAssignmentId == null) {
      PiggyToast.showWarning(context, strings.pleaseSelectBatch);
      return;
    }

    if (_cart.isEmpty) {
      PiggyToast.showWarning(
        context,
        strings.isFilipino
            ? 'Pumili ng kahit 1 produkto na hihilingin.'
            : 'Please select at least 1 item to request.',
      );
      return;
    }

    if (_isCurrentBatchCompleted) {
      PiggyToast.showWarning(
        context,
        strings.isFilipino
            ? 'Tapos na ang siklo ng batch na ito. Bawal nang humiling ng karagdagang supply. Mangyaring maghintay sa susunod na batch mula sa Farm Admin.'
            : 'This batch cycle is completed. Supplies can no longer be requested for this batch. Please wait for Farm Admin to assign your next batch.',
        title: strings.isFilipino ? 'Batch Natapos Na' : 'Batch Cycle Completed',
        duration: const Duration(seconds: 4),
      );
      return;
    }

    if (_isInvestmentDepleted) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.isFilipino ? 'Naubos na ang Puhunan' : 'Investment Depleted',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            strings.isFilipino
                ? 'Paalala: Naubos na ang inyong natitirang puhunan (₱0.00). Ang kahilingang ito ay mangangailangan ng espesyal na pag-apruba mula sa Farm Admin. Nais mo bang magpatuloy?'
                : 'Notice: Your remaining investment budget is ₱0.00. This supply request exceeds your remaining capital and will require special Farm Admin review. Do you want to submit anyway for admin approval?',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.isFilipino ? 'Kanselahin' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(strings.isFilipino ? 'Isumite Pa Rin' : 'Submit for Review'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final raiserId = widget.raiserData['hog_raiser_id'] ?? widget.raiserData['id'];
      if (raiserId == null) throw Exception('Raiser profile is not available.');

      final now = DateTime.now();
      final nowIso = now.toUtc().toIso8601String();
      final today = now.toIso8601String().split('T').first;
      final generalNotes = _generalNotesController.text.trim();

      final isRealAssignment = _selectedAssignmentId != null &&
          _selectedAssignmentId! < BigInt.from(900000);
      final int? validAssignmentId = isRealAssignment ? _selectedAssignmentId!.toInt() : null;

      // Keep only clean raiser notes without injecting any automated tags
      final String? cleanNotes = generalNotes.isNotEmpty ? generalNotes : null;

      final List<Map<String, dynamic>> requestsToInsert = [];
      final List<String> descriptions = [];

      for (final entry in _cart.entries) {
        final prod = _products.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => _fallbackProduct(entry.key),
        );
        final qty = entry.value;

        final Map<String, dynamic> reqItem = {
          'hog_raiser_id': raiserId,
          'status': 'pending',
          'request_date': today,
          'category': prod.category.isNotEmpty ? prod.category : 'Feeds',
          'quantity': qty,
          'feed_type': prod.name,
          'notes': cleanNotes,
          'created_at': nowIso,
        };
        if (validAssignmentId != null) {
          reqItem['assignment_id'] = validAssignmentId;
        }

        requestsToInsert.add(reqItem);
        descriptions.add('$qty x ${prod.name}');
      }

      if (requestsToInsert.isEmpty) {
        throw Exception('No valid items to request.');
      }

      try {
        await _supabase.from('stock_requests').insert(requestsToInsert);
      } catch (insertErr) {
        final errStr = insertErr.toString().toLowerCase();
        debugPrint('Notice: stock_requests insert failed: $insertErr');

        final bool isFkError = errStr.contains('stock_requests_assignment_id_fkey') ||
            errStr.contains('23503') ||
            errStr.contains('foreign key constraint');

        final fallbackList = requestsToInsert.map((r) {
          final m = Map<String, dynamic>.from(r);
          m.remove('created_at');
          if (isFkError) {
            m.remove('assignment_id');
          }
          return m;
        }).toList();

        try {
          await _supabase.from('stock_requests').insert(fallbackList);
        } catch (retryErr) {
          final retryErrStr = retryErr.toString().toLowerCase();
          if (retryErrStr.contains('stock_requests_assignment_id_fkey') ||
              retryErrStr.contains('23503') ||
              retryErrStr.contains('foreign key constraint')) {
            final noAssignList = fallbackList.map((r) {
              final m = Map<String, dynamic>.from(r);
              m.remove('assignment_id');
              return m;
            }).toList();
            await _supabase.from('stock_requests').insert(noAssignList);
          } else {
            rethrow;
          }
        }
      }

      final raiserName = widget.raiserData['name'] ?? 'Hog Raiser';
      final itemsSummary = descriptions.join(', ');
      final notifMessage = generalNotes.isNotEmpty
          ? '$raiserName requested $itemsSummary.\nNotes: "$generalNotes"'
          : '$raiserName requested $itemsSummary.';

      try {
        await _supabase.from('admin_notifications').insert({
          'title': 'New Stock Request',
          'message': notifMessage,
          'type': 'stock_request',
          'is_read': false,
        });
      } catch (_) {}

      if (mounted) {
        PiggyToast.showSuccess(
          context,
          strings.requestSuccessToast,
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        PiggyToast.showError(
          context,
          '${strings.requestFailedToast}: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showProductImagePreview(POSProduct p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final isOutOfStock = p.units <= 0;
    final isLowStock = p.units > 0 && p.units <= 10;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final currentQty = _cart[p.id] ?? 0;
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with Image and close button
                      Stack(
                        children: [
                          Container(
                            height: 280,
                            width: double.infinity,
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            child: p.image != null && p.image!.isNotEmpty
                                ? InteractiveViewer(
                                    minScale: 0.8,
                                    maxScale: 4.0,
                                    child: Image.network(
                                      p.image!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => Center(
                                        child: Icon(
                                          _getCategoryIcon(p.category),
                                          color: PiggyTrunkTheme.ptMuted.withValues(alpha: 0.6),
                                          size: 64,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      _getCategoryIcon(p.category),
                                      color: PiggyTrunkTheme.ptMuted.withValues(alpha: 0.6),
                                      size: 64,
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(dialogCtx),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                p.category.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          if (p.image != null && p.image!.isNotEmpty)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Pinch to zoom',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : _brandColor,
                                height: 1.3,
                              ),
                            ),
                            if (p.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                p.description,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '₱${p.price.toStringAsFixed(2)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : _brandColor,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isOutOfStock
                                                ? _dangerRed
                                                : isLowStock
                                                    ? _warningAmber
                                                    : _successGreen,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isOutOfStock
                                              ? (strings.isFilipino ? 'Ubos na' : 'Out of Stock')
                                              : isLowStock
                                                  ? (strings.isFilipino ? 'Kakaunti: ${p.units}' : 'Low Stock: ${p.units}')
                                                  : (strings.isFilipino ? 'Tira: ${p.units}' : 'Stock: ${p.units}'),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isOutOfStock
                                                ? _dangerRed
                                                : isLowStock
                                                    ? _warningAmber
                                                    : _successGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (!isOutOfStock && widget.activeAssignments.isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _addToCart(p);
                                      setDialogState(() {});
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: Text(
                                      currentQty > 0
                                          ? (strings.isFilipino ? 'Dagdag ($currentQty)' : 'Add More ($currentQty)')
                                          : (strings.isFilipino ? 'Magdagdag' : 'Add to Request'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _brandColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openKioskCartModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final textColor = isDark ? Colors.white : _brandColor;
            final surfaceBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
            final borderColor = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
            final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: surfaceBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle indicator
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: mutedColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _brandColor.withValues(alpha: isDark ? 0.25 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.inventory_2_rounded, color: isDark ? Colors.white : _brandColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.isFilipino ? 'Buod ng Kahilingan' : 'Request Summary',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                '${_cart.length} ${strings.isFilipino ? "produkto" : "item(s)"} • $_totalCartItems ${strings.isFilipino ? "piraso ang napili" : "unit(s) selected"}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_cart.isNotEmpty)
                          InkWell(
                            onTap: () {
                              setState(() => _cart.clear());
                              setModalState(() {});
                              Navigator.pop(modalCtx);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 15,
                                    color: _dangerRed,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    strings.isFilipino ? 'Alisin Lahat' : 'Clear All',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: _dangerRed,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: textColor, size: 22),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),

                  // Content
                  Expanded(
                    child: _cart.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shopping_basket_outlined, size: 54, color: mutedColor.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  strings.isFilipino ? 'Walang napiling supply.' : 'No supplies selected.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: mutedColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  strings.isFilipino ? 'Pumili muna ng mga produkto sa listahan.' : 'Select products from the supply list.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: mutedColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 108),
                            children: [
                              // Active Batch Selection
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    strings.selectBatchHogs,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                  if (widget.activeAssignments.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: _isCurrentBatchCompleted
                                            ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFECFDF5))
                                            : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5)),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _isCurrentBatchCompleted
                                              ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFFA7F3D0))
                                              : (isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0)),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 12,
                                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _isCurrentBatchCompleted
                                                ? (strings.isFilipino ? 'Tapos Na' : 'Cycle Completed')
                                                : (strings.isFilipino ? 'Aktibo' : 'Active'),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              widget.activeAssignments.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: _warningAmber.withValues(alpha: isDark ? 0.15 : 0.08),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: _warningAmber.withValues(alpha: 0.35)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: _warningAmber, size: 22),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              strings.noActiveBatchAssigned,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.amber[200] : const Color(0xFFB45309),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : _buildModalBatchSelector(
                                      isDark: isDark,
                                      textColor: textColor,
                                      mutedColor: mutedColor,
                                      strings: strings,
                                      setModalState: setModalState,
                                    ),
                              const SizedBox(height: 18),

                              // Items in cart
                              Text(
                                strings.isFilipino ? 'MGA NAPILING PRODUKTO' : 'SELECTED SUPPLIES',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: mutedColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),

                              ..._cart.entries.map((entry) {
                                final prod = _products.firstWhere(
                                  (p) => p.id == entry.key,
                                  orElse: () => _fallbackProduct(entry.key),
                                );
                                final qty = entry.value;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      // Image
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                          child: prod.image != null && prod.image!.isNotEmpty
                                              ? Image.network(
                                                  prod.image!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) => Icon(
                                                    _getCategoryIcon(prod.category),
                                                    color: mutedColor,
                                                    size: 24,
                                                  ),
                                                )
                                              : Icon(
                                                  _getCategoryIcon(prod.category),
                                                  color: mutedColor,
                                                  size: 24,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              prod.name,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: textColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '₱${prod.price.toStringAsFixed(2)} • ${prod.category}',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w500,
                                                color: mutedColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Stepper
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              _decrementCart(prod);
                                              setModalState(() {});
                                              setState(() {});
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                                size: 16,
                                                color: qty <= 1 ? _dangerRed : textColor,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: Text(
                                              '$qty',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              _addToCart(prod);
                                              setModalState(() {});
                                              setState(() {});
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: _brandColor,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.add_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),

                              const SizedBox(height: 12),

                              // Notes
                              Text(
                                strings.isFilipino ? 'MGA TALA (OPSYONAL)' : 'NOTES (OPTIONAL)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: mutedColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _generalNotesController,
                                maxLines: 2,
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textColor),
                                decoration: InputDecoration(
                                  hintText: strings.isFilipino
                                      ? 'hal. Para sa feeding schedule o pickup sa opisina...'
                                      : 'e.g., For scheduled feeding or pickup from the farm office...',
                                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: mutedColor),
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  filled: true,
                                  contentPadding: const EdgeInsets.all(12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: BoxDecoration(
                      color: surfaceBg,
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              strings.isFilipino ? 'Tinatayang Halaga' : 'Estimated Value',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: mutedColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '₱${_totalCartEstimatedCost.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_cart.isEmpty || _isSubmitting || _isCurrentBatchCompleted)
                                ? null
                                : () async {
                                    Navigator.pop(modalCtx);
                                    await _submitRequest();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : _brandColor,
                              foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              disabledBackgroundColor: mutedColor.withValues(alpha: 0.15),
                              disabledForegroundColor: mutedColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _isCurrentBatchCompleted
                                            ? (strings.isFilipino ? 'Tapos na ang Siklo ng Batch' : 'Batch Cycle Completed')
                                            : (strings.isFilipino ? 'Isumite ang Kahilingan' : 'Submit Request'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (!_isCurrentBatchCompleted) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.arrow_forward_rounded, size: 18),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('feed')) return Icons.grass_rounded;
    if (cat.contains('med')) return Icons.medical_services_rounded;
    if (cat.contains('vit')) return Icons.medication_liquid_rounded;
    return Icons.inventory_2_rounded;
  }

  Widget _buildModalBatchSelector({
    required bool isDark,
    required Color textColor,
    required Color mutedColor,
    required AppStrings strings,
    required StateSetter setModalState,
  }) {
    final selectedAssignment = _assignments.firstWhere(
      (a) => BigInt.from(a['assignment_id'] as num) == _selectedAssignmentId,
      orElse: () => _assignments.isNotEmpty ? _assignments.first : {},
    );
    final bData = selectedAssignment['batches'];
    String rawBatchName = '';
    if (bData is Map) {
      rawBatchName = bData['batch_name']?.toString() ?? '';
    } else if (bData is List && bData.isNotEmpty && bData.first is Map) {
      rawBatchName = bData.first['batch_name']?.toString() ?? '';
    }
    if (rawBatchName.isEmpty) {
      rawBatchName = (selectedAssignment['batch_name'] ??
          (selectedAssignment['assignment_id'] != null ? 'Batch #${selectedAssignment['assignment_id']}' : 'No Batch')).toString();
    }
    String displayBatchName = rawBatchName;
    if (rawBatchName.contains(' (')) {
      final parts = rawBatchName.split(' (');
      if (parts.last.endsWith(')')) {
        displayBatchName = parts.sublist(0, parts.length - 1).join(' (');
      }
    }
    final htData = selectedAssignment['hog_types'];
    String rawHogType = '';
    if (htData is Map) {
      rawHogType = htData['type_name']?.toString() ?? '';
    } else if (htData is List && htData.isNotEmpty && htData.first is Map) {
      rawHogType = htData.first['type_name']?.toString() ?? '';
    }
    if (rawHogType.isEmpty) {
      rawHogType = selectedAssignment['pig_type']?.toString() ??
          widget.raiserData['pig_type']?.toString() ??
          'Fattening';
    }


    final hasMultipleBatches = _assignments.length > 1;

    return InkWell(
      onTap: hasMultipleBatches ? () => _showBatchPickerModal(context, setModalState) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                      : const Color(0xFFBFDBFE),
                ),
              ),
              child: Icon(
                Icons.pets_rounded,
                color: isDark ? const Color(0xFF38BDF8) : _brandColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.isFilipino ? 'NAKA-ASSIGN NA BATCH' : 'ASSIGNED BATCH',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: mutedColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayBatchName.isNotEmpty
                        ? displayBatchName
                        : (strings.isFilipino ? 'Pumili ng Batch' : 'Select Batch'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          rawHogType,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : _brandColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasMultipleBatches) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.isFilipino ? 'Palitan' : 'Change',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF38BDF8) : _brandColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.unfold_more_rounded,
                      size: 15,
                      color: isDark ? const Color(0xFF38BDF8) : _brandColor,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBatchPickerModal(BuildContext parentContext, [StateSetter? modalStateSetter]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : _brandColor;
    final surfaceBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final borderColor = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final strings = AppStrings.of(context);

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: surfaceBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mutedColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _brandColor.withValues(alpha: isDark ? 0.25 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.pets_rounded, color: isDark ? const Color(0xFF38BDF8) : _brandColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.isFilipino ? 'Piliin ang Batch ng Alaga' : 'Select Batch of Hogs',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            Text(
                              strings.isFilipino
                                  ? 'Piliin kung aling batch ilalaan ang mga supply na ito'
                                  : 'Choose which batch will receive these supplies',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textColor, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: borderColor),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: _assignments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final sortedList = List<Map<String, dynamic>>.from(_assignments)..sort(_compareAssignments);
                      final a = sortedList[index];
                      final aId = BigInt.from(a['assignment_id'] as num);
                      final isSelected = aId == _selectedAssignmentId;

                      final bData = a['batches'];
                      String rawBatchName = '';
                      if (bData is Map) {
                        rawBatchName = bData['batch_name']?.toString() ?? '';
                      } else if (bData is List && bData.isNotEmpty && bData.first is Map) {
                        rawBatchName = bData.first['batch_name']?.toString() ?? '';
                      }
                      if (rawBatchName.isEmpty) {
                        rawBatchName = (a['batch_name'] ?? 'Assignment #${a['assignment_id']}').toString();
                      }
                      String displayBatchName = rawBatchName;
                      if (rawBatchName.contains(' (')) {
                        final parts = rawBatchName.split(' (');
                        if (parts.last.endsWith(')')) {
                          displayBatchName = parts.sublist(0, parts.length - 1).join(' (');
                        }
                      }
                      final htData = a['hog_types'];
                      String rawHogType = '';
                      if (htData is Map) {
                        rawHogType = htData['type_name']?.toString() ?? '';
                      } else if (htData is List && htData.isNotEmpty && htData.first is Map) {
                        rawHogType = htData.first['type_name']?.toString() ?? '';
                      }
                      if (rawHogType.isEmpty) {
                        rawHogType = a['pig_type']?.toString() ??
                            widget.raiserData['pig_type']?.toString() ??
                            'Fattening';
                      }


                      final isCompleted = a['is_cycle_completed'] == true;

                      return Opacity(
                        opacity: isCompleted ? 0.6 : 1.0,
                        child: InkWell(
                          onTap: () {
                            if (isCompleted) {
                              PiggyToast.showWarning(
                                context,
                                strings.isFilipino
                                    ? 'Nasa history na ang batch na ito at tapos na ang siklo. Bawal nang mag-request ng supply dito.'
                                    : 'This batch cycle is completed and archived in history. You cannot request supplies for a completed batch.',
                                title: strings.isFilipino ? 'Tapos na ang Siklo' : 'Cycle Completed',
                              );
                              return;
                            }
                            setState(() => _selectedAssignmentId = aId);
                            if (modalStateSetter != null) {
                              modalStateSetter(() {});
                            }
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF))
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF38BDF8) : _brandColor)
                                    : borderColor,
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.2) : _brandColor.withValues(alpha: 0.1))
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isCompleted ? Icons.history_rounded : Icons.pets_rounded,
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF38BDF8) : _brandColor)
                                        : mutedColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayBatchName,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected
                                              ? (isDark ? Colors.white : _brandColor)
                                              : textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              rawHogType,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white70 : _brandColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (isCompleted)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.lock_rounded, size: 10, color: mutedColor),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    strings.isFilipino ? 'Tapos na • Naka-lock' : 'Concluded • Locked',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: mutedColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                strings.isFilipino ? 'Aktibo' : 'Active',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF10B981),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isCompleted)
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color: mutedColor.withValues(alpha: 0.6),
                                    size: 20,
                                  )
                                else if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF10B981),
                                    size: 22,
                                  )
                                else
                                  Icon(
                                    Icons.radio_button_unchecked_rounded,
                                    color: mutedColor.withValues(alpha: 0.6),
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveBatchBanner(
    bool isDark,
    Color textColor,
    Color surfaceBg,
    Color borderColor,
    Color mutedColor,
    AppStrings strings,
  ) {
    if (_assignments.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(18, 2, 18, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _warningAmber.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _warningAmber.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: _warningAmber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.isFilipino ? 'Walang Aktibong Batch' : 'No Active Batch Assigned',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.amber[200] : const Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.isFilipino
                        ? 'Kailangan muna ng aktibong batch bago makahiling ng supply. Makipag-ugnayan sa Farm Admin.'
                        : 'An active batch is required to request supplies. Please contact Farm Admin to assign one.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark ? Colors.amber[100]!.withValues(alpha: 0.85) : const Color(0xFF92400E),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final hasMultipleBatches = _assignments.length > 1;

    final selectedAssignment = _assignments.firstWhere(
      (a) => BigInt.from(a['assignment_id'] as num) == _selectedAssignmentId,
      orElse: () => _assignments.first,
    );

    final isConcluded = selectedAssignment['is_cycle_completed'] == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(18, 2, 18, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: surfaceBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: InkWell(
            onTap: hasMultipleBatches ? () => _showBatchPickerModal(context) : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _brandColor.withValues(alpha: isDark ? 0.25 : 0.08),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.pets_rounded, size: 14, color: isDark ? Colors.white : _brandColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Batch:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: mutedColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatAssignmentLabel(selectedAssignment),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isConcluded) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 10.5, color: mutedColor),
                          const SizedBox(width: 3.5),
                          Text(
                            strings.isFilipino ? 'Tapos Na • Naka-lock' : 'Concluded • Locked',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (hasMultipleBatches) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            strings.isFilipino ? 'Palitan' : 'Change',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF38BDF8) : _brandColor,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.unfold_more_rounded,
                            size: 14,
                            color: isDark ? const Color(0xFF38BDF8) : _brandColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (isConcluded) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_rounded, color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.isFilipino
                        ? 'Naitapos na ang siklo ng batch na ito. Naka-lock na ang paghingi ng supply hanggang sa mag-assign ng panibagong batch ang Farm Admin.'
                        : 'This batch cycle is completed. Supply requests are locked until Farm Admin assigns your next batch.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : _brandColor;
    final surfaceBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final borderColor = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final strings = AppStrings.of(context);

    final filteredProducts = _filteredProducts;

    return Scaffold(
      backgroundColor: isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Action Bar with Segmented Toggle & Cart Quick-Access Button (No Header)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                  child: Row(
                    children: [
                      if (widget.showBackButton) ...[
                        IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: textColor),
                          onPressed: widget.onBack,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inventory_2_rounded, size: 16, color: isDark ? Colors.white : _brandColor),
                                        const SizedBox(width: 6),
                                        Text(
                                          strings.isFilipino ? 'Humiling ng Supply' : 'Request Supplies',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : _brandColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: InkWell(
                                  onTap: widget.onViewHistory,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.receipt_long_rounded, size: 16, color: mutedColor),
                                        const SizedBox(width: 6),
                                        Text(
                                          strings.isFilipino ? 'Aking Requests' : 'My Requests',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: mutedColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Active Batch Banner / Selector
              _buildActiveBatchBanner(isDark, textColor, surfaceBg, borderColor, mutedColor, strings),
              if (_isCurrentBatchCompleted || _isInvestmentDepleted)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isDark ? PiggyTrunkTheme.ptSurfaceDark : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? PiggyTrunkTheme.ptBorderDark : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: (_isCurrentBatchCompleted
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF64748B))
                                .withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            _isCurrentBatchCompleted
                                ? Icons.task_alt_rounded
                                : Icons.account_balance_wallet_outlined,
                            size: 18,
                            color: _isCurrentBatchCompleted
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                : (isDark ? const Color(0xFF94A3B8) : _brandColor),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isCurrentBatchCompleted
                                    ? (strings.isFilipino ? 'Tapos na ang Siklo ng Batch' : 'Batch Cycle Completed')
                                    : (strings.isFilipino ? 'Puhunan ay Naubos Na' : 'Investment Budget Concluded'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2.5),
                              Text(
                                _isCurrentBatchCompleted
                                    ? (strings.isFilipino
                                        ? 'Nakatapos na ang siklo ng batch na ito. Pansamantalang sarado ang supply requests habang hinihintay ang susunod na batch mula sa Farm Admin.'
                                        : 'This batch has completed its cycle. Supply requests are paused until your next batch assignment from Farm Admin.')
                                    : (strings.isFilipino
                                        ? 'Naubos na ang natitirang puhunan (₱0.00). Makipag-ugnayan sa Farm Admin para sa replenishment o adjustment.'
                                        : 'Remaining investment budget is ₱0.00. Please coordinate with Farm Admin for replenishment or adjustments.'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: mutedColor,
                                  height: 1.35,
                                ),
                              ),
                              if (_isCurrentBatchCompleted && _isInvestmentDepleted) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: mutedColor.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      strings.isFilipino
                                          ? 'Natitirang Puhunan: ₱0.00 • Naisara na ang alokasyon'
                                          : 'Remaining Budget: ₱0.00 • Investment capital concluded',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: mutedColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      color: textColor,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: strings.isFilipino
                          ? 'Maghanap ng produkto (hal. Pigrolac, Amoxicillin)...'
                          : 'Search products (e.g. Pigrolac, Amoxicillin)...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: mutedColor),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: mutedColor),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, size: 18, color: mutedColor),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              // Category Pills
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  children: [
                    _buildCategoryPill('All', strings.isFilipino ? 'Lahat' : 'All', Icons.grid_view_rounded, isDark),
                    const SizedBox(width: 8),
                    _buildCategoryPill('Feeds', strings.isFilipino ? 'Pakain' : 'Feeds', Icons.grass_rounded, isDark),
                    const SizedBox(width: 8),
                    _buildCategoryPill('Medicine', strings.isFilipino ? 'Gamot' : 'Medicine', Icons.medical_services_rounded, isDark),
                    const SizedBox(width: 8),
                    _buildCategoryPill('Vitamins', strings.isFilipino ? 'Bitamina' : 'Vitamins', Icons.medication_liquid_rounded, isDark),
                    const SizedBox(width: 8),
                    _buildCategoryPill('Others', strings.isFilipino ? 'Iba pa' : 'Others', Icons.inventory_2_rounded, isDark),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Products Catalog Grid
              Expanded(
                child: _isLoadingProducts
                    ? _buildShimmerGrid(isDark)
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline_rounded, size: 48, color: _dangerRed),
                                  const SizedBox(height: 12),
                                  Text(
                                    strings.isFilipino ? 'Bigo sa pag-load ng mga produkto' : 'Failed to load products',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _errorMessage,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: mutedColor),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadInventoryProducts,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _brandColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(strings.isFilipino ? 'Subukan Muli' : 'Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : filteredProducts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 52, color: mutedColor.withValues(alpha: 0.5)),
                                    const SizedBox(height: 12),
                                    Text(
                                      strings.isFilipino ? 'Walang nahanap na produkto.' : 'No products found.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: mutedColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      strings.isFilipino
                                          ? 'Subukang pumili ng ibang kategorya o burahin ang search.'
                                          : 'Try selecting another category or clear search.',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: mutedColor),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadInventoryProducts,
                                child: GridView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                    18,
                                    8,
                                    18,
                                    _cart.isNotEmpty ? 100 : 24,
                                  ),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 14,
                                    childAspectRatio: 0.58,
                                  ),
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (context, index) {
                                    final p = filteredProducts[index];
                                    return _buildKioskProductCard(p, isDark, textColor, surfaceBg, borderColor, mutedColor);
                                  },
                                ),
                              ),
              ),
            ],
          ),

          // Floating Bottom Request Bar
          if (_cart.isNotEmpty && !_isCurrentBatchCompleted)
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: SafeArea(
                child: GestureDetector(
                  onTap: _openKioskCartModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : _brandColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_cart.length} ${strings.isFilipino ? "produkto ang napili" : "item(s) selected"}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '$_totalCartItems units • ₱${_totalCartEstimatedCost.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                strings.isFilipino ? 'Suriin ang Request' : 'Review Request',
                                style: GoogleFonts.plusJakartaSans(
                                  color: _brandColor,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 14, color: _brandColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildCategoryPill(String key, String label, IconData icon, bool isDark) {
    final isSelected = _selectedCategory == key;
    final activeBg = isDark ? Colors.white : _brandColor;
    final activeText = isDark ? _brandColor : Colors.white;
    final inactiveBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final inactiveText = isDark ? Colors.white70 : const Color(0xFF475569);
    final borderColor = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = key),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? activeBg : borderColor),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeBg.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeText : inactiveText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeText : inactiveText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKioskProductCard(
    POSProduct p,
    bool isDark,
    Color textColor,
    Color surfaceBg,
    Color borderColor,
    Color mutedColor,
  ) {
    final strings = AppStrings.of(context);
    final inCartQty = _cart[p.id] ?? 0;
    final isOutOfStock = p.units <= 0;
    final isLowStock = p.units > 0 && p.units <= 10;

    return Container(
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inCartQty > 0 ? _brandColor : borderColor,
          width: inCartQty > 0 ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Container (Clickable to preview)
          Expanded(
            child: GestureDetector(
              onTap: () => _showProductImagePreview(p),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      child: p.image != null && p.image!.isNotEmpty
                          ? Image.network(
                              p.image!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Icon(
                                  _getCategoryIcon(p.category),
                                  color: mutedColor.withValues(alpha: 0.6),
                                  size: 36,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                _getCategoryIcon(p.category),
                                color: mutedColor.withValues(alpha: 0.6),
                                size: 36,
                              ),
                            ),
                    ),
                  ),
                  // Category Pill on Image
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.category.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  // Zoom hint icon
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                  // In-cart quantity badge on image
                  if (inCartQty > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, color: Colors.white, size: 10),
                            const SizedBox(width: 2),
                            Text(
                              '$inCartQty',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Details & Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name
                Text(
                  p.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),

                // Stock Badge
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOutOfStock
                            ? _dangerRed
                            : isLowStock
                                ? _warningAmber
                                : _successGreen,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        isOutOfStock
                            ? (strings.isFilipino ? 'Ubos na' : 'Out of Stock')
                            : isLowStock
                                ? (strings.isFilipino ? 'Kakaunti: ${p.units}' : 'Low Stock: ${p.units}')
                                : (strings.isFilipino ? 'Tira: ${p.units}' : 'Stock: ${p.units}'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isOutOfStock
                              ? _dangerRed
                              : isLowStock
                                  ? _warningAmber
                                  : _successGreen,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Price & Stepper
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '₱${p.price.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : _brandColor,
                      ),
                    ),

                    // Action Button
                    if (isOutOfStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                        decoration: BoxDecoration(
                          color: mutedColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          strings.isFilipino ? 'Wala' : 'Out',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: mutedColor,
                          ),
                        ),
                      )
                    else if (widget.activeAssignments.isEmpty || _isCurrentBatchCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7.5),
                        decoration: BoxDecoration(
                          color: mutedColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_isCurrentBatchCompleted ? Icons.check_circle_outline_rounded : Icons.lock_outline_rounded, size: 14, color: mutedColor),
                            const SizedBox(width: 4),
                            Text(
                              _isCurrentBatchCompleted
                                  ? (strings.isFilipino ? 'Tapos Na' : 'Completed')
                                  : (strings.isFilipino ? 'Bawal' : 'Locked'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      InkWell(
                        onTap: () => _addToCart(p),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : _brandColor,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? Colors.white : _brandColor).withValues(alpha: 0.22),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 17,
                                color: isDark ? _brandColor : Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                strings.isFilipino ? 'Magdagdag' : 'Add',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? _brandColor : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid(bool isDark) {
    return ShimmerProvider(
      child: GridView.builder(
        padding: const EdgeInsets.all(18),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.58,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ShimmerBox(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.circular(16),
                  isDark: isDark,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 90, height: 12, borderRadius: BorderRadius.circular(4), isDark: isDark),
                    const SizedBox(height: 6),
                    ShimmerBox(width: 50, height: 10, borderRadius: BorderRadius.circular(4), isDark: isDark),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 40, height: 14, borderRadius: BorderRadius.circular(4), isDark: isDark),
                        ShimmerBox(width: 45, height: 22, borderRadius: BorderRadius.circular(6), isDark: isDark),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
