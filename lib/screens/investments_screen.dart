import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/investment_model.dart';
import '../theme/app_theme.dart';
import '../utils/app_toast.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/slide_over_confirmation_drawer.dart';
import '../utils/responsive.dart';
import '../widgets/common/shimmer_loading.dart';
import '../widgets/investment/investment_form_view.dart';
import '../widgets/investment/investment_table_view.dart';
import '../widgets/investment/investment_detail_modal.dart';
import '../widgets/investment/investment_add_allocation_dialog.dart';
import '../main.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Investment> investments = [];
  List<Map<String, dynamic>> partnerInvestments = [];
  bool _isLoading = true;
  bool _isTableRefreshing = false;
  bool _showInvestmentForm = false;
  Investment? _editingInvestment;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgDark => _isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
  Color get _panelStart => _isDark ? const Color(0xFF1A2940) : Colors.white;
  Color get _panelEnd => _isDark ? const Color(0xFF0F1C2F) : Colors.white;
  Color get _panelBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);

  bool _hasCheckedRouteArgs = false;
  String? _initialViewMode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == 'partner' ||
        args == 'PARTNER' ||
        (args is Map && (args['tab'] == 'partner' || args['tab'] == 'PARTNER' || args['view'] == 'partner' || args['view'] == 'PARTNER'))) {
      if (_initialViewMode != 'PARTNER') {
        setState(() {
          _initialViewMode = 'PARTNER';
        });
      }
    }
    if (!_hasCheckedRouteArgs) {
      _hasCheckedRouteArgs = true;
      if (args is Map<String, dynamic>) {
        final targetBatchId = args['batch_id']?.toString();
        final targetBatchName = (args['batch_name'] ?? '').toString().toLowerCase();
        final targetRaiserName = (args['raiser_name'] ?? '').toString().toLowerCase();

        _loadInvestments().then((_) {
          if (mounted && investments.isNotEmpty) {
            Investment? match;
            for (var inv in investments) {
              if (targetBatchId != null && inv.batchId?.toString() == targetBatchId) {
                match = inv;
                break;
              }
              if (targetBatchName.isNotEmpty && (inv.batchName ?? '').toLowerCase().contains(targetBatchName)) {
                match = inv;
                break;
              }
              if (targetRaiserName.isNotEmpty && inv.raiserName.toLowerCase().contains(targetRaiserName)) {
                match = inv;
                break;
              }
            }
            if (match != null) {
              InvestmentDetailModal.show(context: context, investment: match);
            }
          }
        });
      }
    }
  }

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
    _loadInvestments();
  }

  String _cleanBatchName(String raw) {
    final clean = raw.trim();
    final uuidRegex = RegExp(r'\s*\([0-9a-fA-F-]{10,}\)\s*$');
    if (uuidRegex.hasMatch(clean)) {
      return clean.replaceAll(uuidRegex, '').trim();
    }
    return clean;
  }

  Future<void> _loadInvestments({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() => _isTableRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }
    try {
      // 1. Fetch Batches
      List<dynamic> batchesRaw = [];
      try {
        batchesRaw = await _supabase.from('batches').select('batch_id, batch_name, date_created');
      } catch (bErr) {
        debugPrint('Error fetching batches: $bErr');
      }

      final Map<String, String> batchesMap = {
        for (var b in batchesRaw)
          (b['batch_id'] ?? b['id'] ?? '').toString(): _cleanBatchName((b['batch_name'] ?? 'Batch #${b['batch_id']}').toString())
      };

      // 2. Fetch Assignments
      List<dynamic> assignmentsRaw = [];
      try {
        assignmentsRaw = await _supabase.from('assignments').select('assignment_id, batch_id, hog_raiser_id, status, assigned_date');
      } catch (aErr) {
        debugPrint('Error fetching assignments: $aErr');
      }

      // 3. Fetch Product Prices
      final Map<String, double> productPriceMap = {};
      try {
        final productsRes = await _supabase.from('inventory_products').select('name, price, category');
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
        debugPrint('Error fetching product prices: $pErr');
      }

      // 4. Fetch Approved Stock Requests
      List<dynamic> approvedStockRequests = [];
      try {
        approvedStockRequests = await _supabase
            .from('stock_requests')
            .select('*')
            .eq('status', 'approved')
            .order('request_date', ascending: false);
      } catch (sErr) {
        debugPrint('Error fetching approved stock requests: $sErr');
      }

      // 4b. Fetch Hog Reports for Health Updates
      List<dynamic> allHogReports = [];
      try {
        allHogReports = await _supabase
            .from('hog_reports')
            .select('*')
            .order('created_at', ascending: false);
      } catch (hrErr) {
        debugPrint('Error fetching hog reports: $hrErr');
      }

      const double defaultFeedPrice = 1650.0;

      // 5. Fetch Direct Investment Records directly (ordered newest first)
      dynamic response;
      try {
        response = await _supabase
            .from('investment_records')
            .select('*')
            .order('investment_date', ascending: false);
      } catch (e) {
        debugPrint('Error fetching investment_records with order: $e');
        try {
          response = await _supabase.from('investment_records').select('*');
        } catch (_) {
          response = [];
        }
      }

      final List<Investment> loaded = [];
      final allInvRows = (response as List? ?? []);

      for (var row in allInvRows) {
        final rMap = Map<String, dynamic>.from(row as Map);
        final raiser = rMap['hog_raisers'] as Map<String, dynamic>?;
        final appUsers = raiser?['app_users'] as Map<String, dynamic>?;
        final appName = appUsers?['name']?.toString().trim();
        final raiserName = raiser?['name']?.toString().trim();

        if (appName != null && appName.isNotEmpty && appName.toLowerCase() != 'hog raiser') {
          rMap['raiser_name'] = appName;
        } else if (raiserName != null && raiserName.isNotEmpty) {
          rMap['raiser_name'] = raiserName;
        }

        final recId = (rMap['id'] ?? '').toString();
        final raiserId = (rMap['hog_raiser_id'] ?? '').toString();
        final invDate = (rMap['investment_date'] ?? '').toString();

        String? matchedBatchName;
        String? matchedBatchId;
        String? matchedAssignmentId;

        // A. Direct batch_name / batch_id
        if (rMap['batch_name'] != null && rMap['batch_name'].toString().isNotEmpty) {
          matchedBatchName = _cleanBatchName(rMap['batch_name'].toString());
        }
        if (rMap['batch_id'] != null && rMap['batch_id'].toString().isNotEmpty) {
          matchedBatchId = rMap['batch_id'].toString();
          matchedBatchName ??= batchesMap[matchedBatchId];
        }

        // B. Auto-generated batch matching record UUID
        if (matchedBatchName == null && recId.isNotEmpty) {
          for (var b in batchesRaw) {
            final bName = (b['batch_name'] ?? '').toString();
            if (bName.contains('($recId)')) {
              matchedBatchName = _cleanBatchName(bName);
              matchedBatchId = (b['batch_id'] ?? b['id'])?.toString();
              break;
            }
          }
        }

        // C. Match from assignments for this raiser
        if (raiserId.isNotEmpty) {
          Map<String, dynamic>? bestAssign;
          for (var a in assignmentsRaw) {
            if (a is! Map) continue;
            final aRaiserId = (a['hog_raiser_id'] ?? '').toString();
            final aBatchId = (a['batch_id'] ?? '').toString();
            if (aRaiserId == raiserId) {
              if (matchedBatchId != null && aBatchId == matchedBatchId) {
                bestAssign = Map<String, dynamic>.from(a);
                break;
              }
              final aDate = (a['assigned_date'] ?? '').toString();
              if (invDate.isNotEmpty && aDate.startsWith(invDate.split('T').first)) {
                bestAssign = Map<String, dynamic>.from(a);
                break;
              }
              bestAssign ??= Map<String, dynamic>.from(a);
            }
          }

          if (bestAssign != null) {
            final bId = (bestAssign['batch_id'] ?? '').toString();
            matchedAssignmentId = (bestAssign['assignment_id'] ?? bestAssign['id'])?.toString();
            matchedBatchId ??= bId;
            matchedBatchName ??= batchesMap[bId];
          }
        }

        rMap['batch_name'] = matchedBatchName ?? 'Unassigned';
        rMap['batch_id'] = matchedBatchId;
        rMap['assignment_id'] = matchedAssignmentId;

        final batchAssignmentIds = <String>{};
        if (matchedBatchId != null && matchedBatchId.isNotEmpty) {
          for (var a in assignmentsRaw) {
            if (a is Map && (a['batch_id'] ?? '').toString() == matchedBatchId) {
              final aId = (a['assignment_id'] ?? a['id'])?.toString();
              if (aId != null && aId.isNotEmpty) batchAssignmentIds.add(aId);
            }
          }
        }
        if (matchedAssignmentId != null && matchedAssignmentId.isNotEmpty) {
          batchAssignmentIds.add(matchedAssignmentId);
        }

        // D. Calculate stocks spend and itemized history for this batch
        final List<Map<String, dynamic>> providedStocksList = [];
        double batchStocksSpend = 0.0;

        // Find raiser's total batch count to split shared requests if needed
        final raiserBatchesCount = allInvRows.where((r) => (r['hog_raiser_id'] ?? '').toString() == raiserId).length;

        for (var req in approvedStockRequests) {
          if (req is! Map) continue;
          final reqRaiserId = (req['hog_raiser_id'] ?? '').toString();
          final reqAssignmentId = (req['assignment_id'] ?? '').toString();

          bool isMatch = false;
          if (batchAssignmentIds.isNotEmpty && reqAssignmentId.isNotEmpty) {
            isMatch = batchAssignmentIds.contains(reqAssignmentId);
          } else if (matchedAssignmentId != null && reqAssignmentId.isNotEmpty) {
            isMatch = (reqAssignmentId == matchedAssignmentId);
          } else if (reqRaiserId == raiserId) {
            isMatch = true;
          }

          if (isMatch) {
            final qty = (req['quantity'] as num?)?.toDouble() ?? 1.0;
            final fType = (req['feed_type'] ?? '').toString().trim();
            final cat = (req['category'] ?? '').toString().trim();
            final unitPrice = productPriceMap[fType.toLowerCase()] ??
                productPriceMap[cat.toLowerCase()] ??
                defaultFeedPrice;

            final totalReqVal = qty * unitPrice;

            // If matched solely on raiserId and raiser has multiple batches without distinct assignmentIds,
            // allocate to each batch cleanly.
            final effectiveVal = (matchedAssignmentId == null && raiserBatchesCount > 1)
                ? (totalReqVal / raiserBatchesCount)
                : totalReqVal;

            batchStocksSpend += effectiveVal;

            providedStocksList.add({
              'request_id': req['request_id'],
              'product_name': fType.isNotEmpty ? fType : (cat.isNotEmpty ? cat : 'Feeds / Supplies'),
              'category': cat.isNotEmpty ? cat : 'Feeds',
              'quantity': qty.toInt(),
              'unit_price': unitPrice,
              'total_amount': totalReqVal,
              'request_date': req['request_date'] ?? req['created_at'],
              'decision_date': req['decision_date'],
              'status': req['status'] ?? 'approved',
              'notes': req['notes'] ?? '',
            });
          }
        }

        rMap['stocks_value'] = batchStocksSpend;
        rMap['provided_stocks'] = providedStocksList;

        // E. Collect hog health reports for this raiser
        final List<Map<String, dynamic>> raiserHealthReports = [];
        for (var hr in allHogReports) {
          if (hr is! Map) continue;
          final hrRaiserId = (hr['hog_raiser_id'] ?? '').toString();
          if (hrRaiserId.isNotEmpty && hrRaiserId == raiserId) {
            raiserHealthReports.add(Map<String, dynamic>.from(hr));
          }
        }
        rMap['health_reports'] = raiserHealthReports;

        loaded.add(Investment.fromJson(rMap));
      }

      // Sort newest investments at the top
      loaded.sort((a, b) {
        final dateCmp = b.investmentDate.compareTo(a.investmentDate);
        if (dateCmp != 0) return dateCmp;
        return b.id.compareTo(a.id);
      });

      // Fetch partner investor submissions from `investments` table with resilient lookup
      List<Map<String, dynamic>> loadedPartnerInv = [];
      try {
        final rawInvestments = await _supabase
            .from('investments')
            .select('*')
            .order('date_invested', ascending: false);

        List<dynamic> partnerInvestorsRaw = [];
        try {
          partnerInvestorsRaw = await _supabase.from('partner_investors').select('*');
        } catch (_) {}

        List<dynamic> appUsersRaw = [];
        try {
          appUsersRaw = await _supabase.from('app_users').select('user_id, name, email');
        } catch (_) {}

        final Map<String, Map<String, dynamic>> usersMap = {
          for (var u in appUsersRaw)
            (u['user_id'] ?? '').toString(): Map<String, dynamic>.from(u)
        };

        final Map<String, Map<String, dynamic>> partnersMap = {
          for (var p in partnerInvestorsRaw)
            (p['partner_investor_id'] ?? p['id'] ?? '').toString(): Map<String, dynamic>.from(p)
        };

        for (var row in (rawInvestments as List? ?? [])) {
          final pMap = Map<String, dynamic>.from(row as Map);
          final pInvId = (pMap['partner_investor_id'] ?? '').toString();
          final bId = (pMap['batch_id'] ?? '').toString();

          final partnerRec = partnersMap[pInvId];
          final userId = (partnerRec?['user_id'] ?? '').toString();
          final userRec = usersMap[userId];

          final partnerName = (userRec?['name'] ?? userRec?['email'] ?? 'Partner Investor #$pInvId').toString();
          final batchName = batchesMap[bId] ?? 'Batch #$bId';

          pMap['partner_name'] = partnerName;
          pMap['batch_name'] = batchName;
          loadedPartnerInv.add(pMap);
        }

        // Fetch supplemental / fallback partner investments from admin_notifications
        try {
          final notifsRes = await _supabase
              .from('admin_notifications')
              .select('*')
              .eq('type', 'investment')
              .order('created_at', ascending: false);

          for (var notif in (notifsRes as List? ?? [])) {
            if (notif is! Map) continue;
            final meta = notif['metadata'] as Map<String, dynamic>? ?? {};
            final nAmt = (meta['amount'] as num?)?.toDouble() ?? 0.0;
            if (nAmt <= 0) continue;

            final nBatchId = (meta['batch_id'] ?? '').toString();
            final nPartnerId = (meta['partner_investor_id'] ?? '').toString();
            final nPartnerName = (meta['partner_name'] ?? 'Partner Investor').toString();
            final nBatchName = (meta['batch_name'] ?? batchesMap[nBatchId] ?? 'Batch #$nBatchId').toString();
            final nCreatedAt = notif['created_at']?.toString() ?? DateTime.now().toIso8601String();
            final nDate = nCreatedAt.split('T').first;
            final nNotifId = notif['notification_id'];

            // Check if this investment is already in loadedPartnerInv
            final alreadyLoaded = loadedPartnerInv.any((existing) {
              final eBatch = (existing['batch_id'] ?? '').toString();
              final ePartner = (existing['partner_investor_id'] ?? '').toString();
              final eAmt = (existing['amount'] as num?)?.toDouble() ?? 0.0;
              final eDate = (existing['date_invested'] ?? existing['created_at'] ?? '').toString().split('T').first;
              return (eBatch == nBatchId && ePartner == nPartnerId && (eAmt - nAmt).abs() < 0.01 && eDate == nDate);
            });

            if (!alreadyLoaded) {
              loadedPartnerInv.add({
                'investment_id': nNotifId,
                'notification_id': nNotifId,
                'is_notification_sourced': true,
                'partner_investor_id': nPartnerId,
                'batch_id': nBatchId,
                'amount': nAmt,
                'status': 'active',
                'date_invested': nDate,
                'created_at': nCreatedAt,
                'partner_name': nPartnerName,
                'batch_name': nBatchName,
              });

              // Attempt background reconciliation into investments table (succeeds once trigger is dropped)
              try {
                final pInt = int.tryParse(nPartnerId);
                final bInt = int.tryParse(nBatchId);
                if (pInt != null && bInt != null) {
                  _supabase.from('investments').insert({
                    'partner_investor_id': pInt,
                    'batch_id': bInt,
                    'amount': nAmt,
                    'status': 'active',
                    'date_invested': nDate,
                  }).then((_) {}).catchError((_) {});
                }
              } catch (_) {}
            }
          }
        } catch (nErr) {
          debugPrint('Notice loading investment notifications fallback: $nErr');
        }
      } catch (pErr) {
        debugPrint('Error loading partner investments: $pErr');
      }

      if (!mounted) return;
      setState(() {
        investments = loaded;
        partnerInvestments = loadedPartnerInv;
      });
    } catch (e) {
      debugPrint('Error loading investments: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isTableRefreshing = false;
        });
      }
    }
  }

  Future<void> _approvePartnerInvestment(int investmentId) async {
    try {
      await _supabase
          .from('investments')
          .update({'status': 'active'})
          .eq('investment_id', investmentId);

      // Notify Partner Investor
      try {
        final inv = partnerInvestments.firstWhere(
          (p) => (p['investment_id'] ?? p['id'])?.toString() == investmentId.toString(),
          orElse: () => <String, dynamic>{},
        );
        final rawPId = inv['partner_investor_id'];
        final int? pId = rawPId is int ? rawPId : int.tryParse(rawPId?.toString() ?? '');
        final bName = inv['batch_name'] ?? 'your funded batch';
        if (pId != null) {
          await _supabase.from('partner_notifications').insert({
            'partner_investor_id': pId,
            'title': 'Investment Approved!',
            'message': 'Admin has approved and activated your investment for $bName.',
            'type': 'investment',
            'is_read': false,
          });
        }
      } catch (notifErr) {
        debugPrint('Notice dispatching approval notification: $notifErr');
      }

      _showThemedSnackBar('Partner Investment approved and activated!');
      _loadInvestments();
    } catch (e) {
      _showThemedSnackBar('Approval failed: $e', isError: true);
    }
  }

  Future<void> _rejectPartnerInvestment(int investmentId) async {
    try {
      await _supabase
          .from('investments')
          .update({'status': 'rejected'})
          .eq('investment_id', investmentId);

      // Notify Partner Investor
      try {
        final inv = partnerInvestments.firstWhere(
          (p) => (p['investment_id'] ?? p['id'])?.toString() == investmentId.toString(),
          orElse: () => <String, dynamic>{},
        );
        final rawPId = inv['partner_investor_id'];
        final int? pId = rawPId is int ? rawPId : int.tryParse(rawPId?.toString() ?? '');
        final bName = inv['batch_name'] ?? 'your funded batch';
        if (pId != null) {
          await _supabase.from('partner_notifications').insert({
            'partner_investor_id': pId,
            'title': 'Investment Declined',
            'message': 'Your investment request for $bName was declined by Admin.',
            'type': 'investment',
            'is_read': false,
          });
        }
      } catch (notifErr) {
        debugPrint('Notice dispatching decline notification: $notifErr');
      }

      _showThemedSnackBar('Partner Investment declined.');
      _loadInvestments();
    } catch (e) {
      _showThemedSnackBar('Decline failed: $e', isError: true);
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
                currentRoute: '/investments',
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
                    currentRoute: '/investments',
                    onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
                  ),
                Expanded(
                  child: _showInvestmentForm
                          ? InvestmentFormView(
                              onCancel: () => setState(() {
                                _showInvestmentForm = false;
                                _editingInvestment = null;
                              }),
                              onSaved: () {
                                setState(() {
                                  _showInvestmentForm = false;
                                  _editingInvestment = null;
                                });
                                _loadInvestments();
                              },
                              existingInvestment: _editingInvestment,
                              onShowSnackBar: _showThemedSnackBar,
                            )
                          : SingleChildScrollView(
                              padding: EdgeInsets.all(isMobile ? 12 : 20),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final contentWidth = constraints.maxWidth > 1350
                                      ? 1350.0
                                      : constraints.maxWidth;
                                  return Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      width: contentWidth,
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
                                        horizontal: isMobile ? 14 : 26,
                                        vertical: isMobile ? 16 : 28,
                                      ),
                                      child: _isLoading
                                          ? _buildFullSkeletonLoader(isMobile)
                                          : InvestmentTableView(
                                              investments: investments,
                                              partnerInvestments: partnerInvestments,
                                              initialViewMode: _initialViewMode,
                                              onRefresh: () => _loadInvestments(isRefresh: true),
                                              isRefreshing: _isTableRefreshing,
                                              onAddInvestment: () => setState(() {
                                                _showInvestmentForm = true;
                                                _editingInvestment = null;
                                              }),
                                              onEditInvestment: (item) => setState(() {
                                                _showInvestmentForm = true;
                                                _editingInvestment = item;
                                              }),
                                              onCompleteInvestment: _completeInvestment,
                                              onAddAllocation: _addAllocation,
                                              onArchiveInvestment: _archiveInvestment,
                                              onRestoreInvestment: _restoreInvestment,
                                              onDeleteInvestment: _deleteInvestment,
                                              onApprovePartnerInvestment: _approvePartnerInvestment,
                                              onRejectPartnerInvestment: _rejectPartnerInvestment,
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

  /// Full-page shimmer skeleton that mirrors the Investment Management layout.
  Widget _buildFullSkeletonLoader(bool isMobile) {
    final cardBg = _isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final headerBg = _isDark ? const Color(0xFF1B2E48) : const Color(0xFFEDF4FC);

    return ShimmerProvider(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Metric Cards Skeleton ──
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                (
                  'Total Capital',
                  Icons.monetization_on_rounded,
                  _isDark ? const Color(0xFF60A5FA) : PiggyTrunkTheme.ptPrimary,
                ),
                (
                  'Stocks Spend',
                  Icons.inventory_2_rounded,
                  const Color(0xFF38BDF8),
                ),
                (
                  'Total Heads',
                  Icons.pets_rounded,
                  const Color(0xFFFFAA00),
                ),
                (
                  'Active Allocations',
                  Icons.check_circle_rounded,
                  PiggyTrunkTheme.ptSuccess,
                ),
              ];

              final use2x2 = isMobile || constraints.maxWidth < 780;
              if (use2x2) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildMetricCardSkeleton(cards[0].$1, cards[0].$2, cards[0].$3, isMobile, cardBg, cardBorder)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildMetricCardSkeleton(cards[1].$1, cards[1].$2, cards[1].$3, isMobile, cardBg, cardBorder)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildMetricCardSkeleton(cards[2].$1, cards[2].$2, cards[2].$3, isMobile, cardBg, cardBorder)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildMetricCardSkeleton(cards[3].$1, cards[3].$2, cards[3].$3, isMobile, cardBg, cardBorder)),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildMetricCardSkeleton(cards[0].$1, cards[0].$2, cards[0].$3, isMobile, cardBg, cardBorder)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildMetricCardSkeleton(cards[1].$1, cards[1].$2, cards[1].$3, isMobile, cardBg, cardBorder)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildMetricCardSkeleton(cards[2].$1, cards[2].$2, cards[2].$3, isMobile, cardBg, cardBorder)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildMetricCardSkeleton(cards[3].$1, cards[3].$2, cards[3].$3, isMobile, cardBg, cardBorder)),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Main Table Card Skeleton ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardBg,
              border: Border.all(color: cardBorder, width: 1),
              borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
            ),
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Button shimmer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(
                          width: isMobile ? 180 : 260,
                          height: isMobile ? 20 : 26,
                          borderRadius: BorderRadius.circular(6),
                          isDark: _isDark,
                        ),
                        const SizedBox(height: 8),
                        ShimmerBox(
                          width: isMobile ? 220 : 380,
                          height: 12,
                          borderRadius: BorderRadius.circular(4),
                          isDark: _isDark,
                        ),
                      ],
                    ),
                    if (!isMobile)
                      ShimmerBox(
                        width: 160,
                        height: 44,
                        borderRadius: BorderRadius.circular(10),
                        isDark: _isDark,
                      ),
                  ],
                ),
                if (isMobile) ...[
                  const SizedBox(height: 14),
                  ShimmerBox(
                    width: double.infinity,
                    height: 44,
                    borderRadius: BorderRadius.circular(10),
                    isDark: _isDark,
                  ),
                ],
                const SizedBox(height: 20),

                // View Mode Toggle skeleton
                Container(
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xFF16253B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isDark ? const Color(0xFF28405D) : const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      if (isMobile)
                        Expanded(
                          child: ShimmerBox(
                            height: 38,
                            borderRadius: BorderRadius.circular(9),
                            isDark: _isDark,
                          ),
                        )
                      else
                        ShimmerBox(
                          width: 180,
                          height: 38,
                          borderRadius: BorderRadius.circular(9),
                          isDark: _isDark,
                        ),
                      const SizedBox(width: 4),
                      if (isMobile)
                        Expanded(
                          child: ShimmerBox(
                            height: 38,
                            borderRadius: BorderRadius.circular(9),
                            isDark: _isDark,
                          ),
                        )
                      else
                        ShimmerBox(
                          width: 180,
                          height: 38,
                          borderRadius: BorderRadius.circular(9),
                          isDark: _isDark,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Search + Filter Chips skeleton
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = isMobile || constraints.maxWidth < 750;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ShimmerBox(
                                  height: 42,
                                  borderRadius: BorderRadius.circular(10),
                                  isDark: _isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ShimmerBox(
                                width: 42,
                                height: 42,
                                borderRadius: BorderRadius.circular(10),
                                isDark: _isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: List.generate(4, (i) => Padding(
                              padding: EdgeInsets.only(right: i < 3 ? 8.0 : 0),
                              child: ShimmerBox(
                                width: 70,
                                height: 34,
                                borderRadius: BorderRadius.circular(10),
                                isDark: _isDark,
                              ),
                            )),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: ShimmerBox(
                            height: 42,
                            borderRadius: BorderRadius.circular(10),
                            isDark: _isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ...List.generate(5, (i) => Padding(
                          padding: EdgeInsets.only(right: i < 4 ? 8.0 : 0),
                          child: ShimmerBox(
                            width: 80,
                            height: 42,
                            borderRadius: BorderRadius.circular(10),
                            isDark: _isDark,
                          ),
                        )),
                        const SizedBox(width: 10),
                        ShimmerBox(
                          width: 42,
                          height: 42,
                          borderRadius: BorderRadius.circular(10),
                          isDark: _isDark,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Table skeleton
                TableSkeletonLoader(
                  isDark: _isDark,
                  minWidth: 800,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  headerBg: headerBg,
                  headers: const ['HOG RAISER', 'BATCH ASSIGN', 'CAPITAL', 'STOCKS SPEND', 'HOG TYPE', 'HEADS', 'DATE', 'ACTIONS'],
                  columnFlexes: const [4, 3, 2, 3, 3, 2, 3, 4],
                  actionButtonCount: 4,
                  rowCount: 6,
                  borderRadius: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Individual metric card skeleton matching the real metric card layout,
  /// displaying static icon & label and only shimmering the value number.
  Widget _buildMetricCardSkeleton(
    String label,
    IconData icon,
    Color iconColor,
    bool isMobile,
    Color cardBg,
    Color cardBorder,
  ) {
    final hintText = _isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: cardBorder, width: 1),
        borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 12 : 14,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: _isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: isMobile ? 18 : 22),
          ),
          SizedBox(width: isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: hintText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                ShimmerBox(
                  width: isMobile ? 50 : 70,
                  height: isMobile ? 15 : 18,
                  borderRadius: BorderRadius.circular(4),
                  isDark: _isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _completeInvestment(Investment item) async {
    final confirmed = await SlideOverConfirmationDrawer.show(
      context: context,
      title: 'Complete Investment',
      message: 'Are you sure you want to mark the investment lifecycle for "${item.raiserName}" as completed?',
      confirmButtonText: 'Complete Investment',
      actionType: SlideOverActionType.success,
      customIcon: Icons.check_circle_outline_rounded,
    );

    if (confirmed == true) {
      try {
        await _supabase.from('investment_records').update({'stage': 'completed'}).eq('id', item.id);
        _showThemedSnackBar('Investment marked as completed.');
        _loadInvestments();
      } catch (e) {
        _showThemedSnackBar('Completion failed: $e', isError: true);
      }
    }
  }

  void _addAllocation(Investment item) {
    InvestmentAddAllocationDialog.show(
      context: context,
      investment: item,
      onSuccess: () => _loadInvestments(isRefresh: true),
    );
  }

  void _archiveInvestment(Investment item) async {
    final confirmed = await SlideOverConfirmationDrawer.show(
      context: context,
      title: 'Archive Investment',
      message: 'Are you sure you want to archive the investment record for "${item.raiserName}"?',
      confirmButtonText: 'Archive',
      actionType: SlideOverActionType.warning,
      customIcon: Icons.archive_outlined,
    );

    if (confirmed == true) {
      try {
        await _supabase.from('investment_records').update({'stage': 'archived'}).eq('id', item.id);
        _showThemedSnackBar('Investment archived successfully.');
        _loadInvestments();
      } catch (e) {
        _showThemedSnackBar('Archive failed: $e', isError: true);
      }
    }
  }

  void _restoreInvestment(Investment item) async {
    final confirmed = await SlideOverConfirmationDrawer.show(
      context: context,
      title: 'Restore Investment',
      message: 'Are you sure you want to restore the investment record for "${item.raiserName}" back to active?',
      confirmButtonText: 'Restore',
      actionType: SlideOverActionType.success,
      customIcon: Icons.unarchive_outlined,
    );

    if (confirmed == true) {
      try {
        await _supabase.from('investment_records').update({'stage': 'active'}).eq('id', item.id);
        _showThemedSnackBar('Investment restored to active.');
        _loadInvestments();
      } catch (e) {
        _showThemedSnackBar('Restore failed: $e', isError: true);
      }
    }
  }

  void _deleteInvestment(Investment item) async {
    final confirmed = await SlideOverConfirmationDrawer.show(
      context: context,
      title: 'Delete Investment',
      message: 'Are you sure you want to permanently delete this investment record for "${item.raiserName}"?',
      confirmButtonText: 'Delete Permanently',
      actionType: SlideOverActionType.danger,
      customIcon: Icons.delete_outline_rounded,
    );

    if (confirmed == true) {
      try {
        await _supabase.from('investment_records').delete().eq('id', item.id);
        _showThemedSnackBar('Investment deleted.');
        _loadInvestments();
      } catch (e) {
        _showThemedSnackBar('Delete failed: $e', isError: true);
      }
    }
  }
}
