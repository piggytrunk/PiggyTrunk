import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/app_toast.dart';
import '../main.dart';
import '../theme/app_text_styles.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/screen_top_bar.dart';
import '../utils/responsive.dart';
import '../widgets/hog_raiser/raiser_profile_view.dart';
import '../widgets/hog_raiser/active_raisers_tab.dart';
import '../widgets/common/in_page_confirmation_view.dart';
import '../widgets/common/shimmer_loading.dart';
import '../services/email_service.dart';

class HogRaiserScreen extends StatefulWidget {
  const HogRaiserScreen({super.key});

  @override
  State<HogRaiserScreen> createState() => _HogRaiserScreenState();
}

class _HogRaiserScreenState extends State<HogRaiserScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _raisers = [];
  bool _isLoading = true;
  bool _isTableRefreshing = false;
  int _currentTab = 0; // 0 = Active, 1 = Pending, 2 = Archived
  String? _loadErrorMessage;
  Map<String, dynamic>? _selectedRaiserForProfile;
  Widget? _inPageConfirmation;

  RealtimeChannel? _raisersSubscription;
  bool _hasCheckedRouteArgs = false;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgDark => _isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
  Color get _accentDark => _isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent;
  Color get _panelStart => _isDark ? const Color(0xFF1A2940) : Colors.white;
  Color get _panelEnd => _isDark ? const Color(0xFF0F1C2F) : Colors.white;
  Color get _panelBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFE3EAF3);
  Color get _cardBg => _isDark ? const Color(0xFF132238) : Colors.white;
  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _hintText => _isDark ? const Color(0xFF8FA7C4) : const Color(0xFF5D7391);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedRouteArgs) {
      _hasCheckedRouteArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      bool isPending = false;
      String targetRaiserName = '';
      String? targetRaiserId;
      String targetEmail = '';

      if (args == 'pending' || args == 'pending_raiser') {
        isPending = true;
      } else if (args is Map) {
        final tab = args['tab']?.toString().toLowerCase();
        final status = args['status']?.toString().toLowerCase();
        isPending = tab == 'pending' || tab == 'pending_raiser' || status == 'pending';
        targetRaiserName = (args['raiser_name'] ?? args['name'] ?? '').toString().trim();
        targetRaiserId = (args['raiser_id'] ?? args['user_id'])?.toString();
        targetEmail = (args['email'] ?? '').toString().trim().toLowerCase();
      }

      // Support direct query parameters on Flutter Web
      if (kIsWeb) {
        final uri = Uri.base;
        if (uri.queryParameters['tab'] == 'pending' || uri.queryParameters['tab'] == 'pending_raiser') {
          isPending = true;
        }
      }

      if (isPending) {
        setState(() => _currentTab = 1);
      }

      // Do NOT set _searchCtrl.text! Keep search empty so all pending raisers are shown.
      // Auto-search is strictly for Inventory product alerts.
      if (targetRaiserName.isNotEmpty || targetRaiserId != null || targetEmail.isNotEmpty) {
        _loadRaisers().then((_) {
          if (mounted && _raisers.isNotEmpty) {
            Map<String, dynamic>? match;
            for (final r in _raisers) {
              final rId = (r['hog_raiser_id'] ?? r['id'] ?? r['user_id'] ?? '').toString();
              if (targetRaiserId != null && targetRaiserId.isNotEmpty && rId == targetRaiserId) {
                match = r;
                break;
              }
              final rEmail = (r['email'] ?? '').toString().toLowerCase();
              if (targetEmail.isNotEmpty && rEmail == targetEmail) {
                match = r;
                break;
              }
              final rName = (r['name'] ?? '').toString().toLowerCase();
              final targetLower = targetRaiserName.toLowerCase();
              if (targetLower.isNotEmpty && (rName == targetLower || rName.contains(targetLower) || targetLower.contains(rName))) {
                match = r;
                break;
              }
            }
            if (match != null) {
              setState(() => _selectedRaiserForProfile = match);
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
    _loadRaisers();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _raisersSubscription = _supabase
        .channel('public:hog_raisers')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'hog_raisers',
          callback: (payload) {
            _loadRaisers(silent: true);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (_raisersSubscription != null) {
      _supabase.removeChannel(_raisersSubscription!);
    }
    super.dispose();
  }

  Future<void> _loadRaisers({String? keyword, bool silent = false, bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isTableRefreshing = true;
        _loadErrorMessage = null;
      });
    } else if (!silent) {
      setState(() {
        _isLoading = true;
        _loadErrorMessage = null;
      });
    }

    try {
      try {
        final pendingAppUsers = await _supabase
            .from('app_users')
            .select('user_id, name, email, status, role')
            .or('role.ilike.%raiser%,role.ilike.%hog_raiser%');

        for (final au in (pendingAppUsers as List)) {
          final uid = au['user_id'];
          final uStatus = (au['status'] ?? 'Pending').toString();
          if (uid != null) {
            final exists = await _supabase
                .from('hog_raisers')
                .select('hog_raiser_id')
                .eq('user_id', uid)
                .maybeSingle();

            if (exists == null) {
              await _supabase.from('hog_raisers').insert({
                'user_id': uid,
                'name': au['name'] ?? au['email']?.toString().split('@').first ?? 'Hog Raiser',
                'phone': 'N/A',
                'address': 'N/A',
                'status': 'Inactive',
                'account_status': uStatus,
                'pig_type': 'N/A',
                'lifecycle_stage': 'N/A',
              });
            }
          }
        }
      } catch (syncErr) {
        debugPrint('Notice during raiser sync: $syncErr');
      }

      final Map<String, String> avatarMap = {};
      try {
        final storageFiles = await _supabase.storage.from('profile_pictures').list(path: 'avatars');
        for (final file in storageFiles) {
          final fname = file.name;
          final match = RegExp(r'^avatar-(\d+)-').firstMatch(fname);
          if (match != null) {
            final id = match.group(1)!;
            final existing = avatarMap[id];
            if (existing == null || fname.compareTo(existing) > 0) {
              avatarMap[id] = fname;
            }
          }
        }
      } catch (_) {}

      dynamic query = _supabase
          .from('hog_raisers')
          .select('hog_raiser_id, name, address, phone, pig_type, status, account_status, lifecycle_stage, user_id, app_users!hog_raisers_user_id_fkey(name, email, supabase_user_id)');
      dynamic response;
      try {
        response = await query.order('hog_raiser_id', ascending: false);
      } catch (_) {
        response = await query.order('name', ascending: true);
      }

      // Fetch active assignments to dynamically determine active pig_types for each raiser
      final Map<String, Set<String>> raiserActivePigTypes = {};
      final Set<String> raisersWithActiveAssignments = {};
      try {
        List<dynamic> activeAssignments = [];
        try {
          activeAssignments = await _supabase
              .from('assignments')
              .select('assignment_id, batch_id, hog_raiser_id, status, hog_types(type_name)');
        } catch (_) {
          try {
            activeAssignments = await _supabase
                .from('assignments')
                .select('assignment_id, batch_id, hog_raiser_id, status');
          } catch (_) {
            try {
              activeAssignments = await _supabase
                  .from('assignments')
                  .select('*');
            } catch (_) {}
          }
        }

        // Also fetch active investments as fallback if hog_types wasn't joined
        List<dynamic> invRecords = [];
        try {
          invRecords = await _supabase
              .from('investment_records')
              .select('hog_raiser_id, batch_name, batch_id, hog_type, status');
        } catch (_) {}

        final Map<String, String> batchToTypeFromInv = {};
        final Map<String, Set<String>> raiserToTypesFromInv = {};
        for (var inv in invRecords) {
          if (inv is! Map) continue;
          final invStatus = (inv['status'] ?? '').toString().toLowerCase();
          if (invStatus == 'archived' || invStatus == 'completed') continue;
          final rId = (inv['hog_raiser_id'] ?? '').toString();
          final bId = (inv['batch_id'] ?? '').toString();
          final hType = (inv['hog_type'] ?? '').toString().trim();
          if (hType.isNotEmpty && hType.toUpperCase() != 'N/A') {
            if (bId.isNotEmpty) batchToTypeFromInv[bId] = hType;
            if (rId.isNotEmpty) {
              raiserToTypesFromInv.putIfAbsent(rId, () => {}).add(hType);
            }
          }
        }

        for (var a in activeAssignments) {
          if (a is! Map) continue;
          final st = (a['status'] ?? 'active').toString().toLowerCase();
          if (st == 'completed' || st == 'archived' || st == 'deleted') continue;

          final rId = (a['hog_raiser_id'] ?? '').toString();
          if (rId.isEmpty) continue;
          raisersWithActiveAssignments.add(rId);

          String? tName;
          final ht = a['hog_types'];
          if (ht is Map) {
            tName = ht['type_name']?.toString();
          } else if (ht is List && ht.isNotEmpty && ht.first is Map) {
            tName = ht.first['type_name']?.toString();
          }

          if (tName == null || tName.isEmpty || tName.toUpperCase() == 'N/A') {
            final bId = (a['batch_id'] ?? '').toString();
            if (bId.isNotEmpty && batchToTypeFromInv.containsKey(bId)) {
              tName = batchToTypeFromInv[bId];
            } else if (a['pig_type'] != null && a['pig_type'].toString().trim().isNotEmpty) {
              tName = a['pig_type'].toString().trim();
            }
          }

          if (tName != null && tName.trim().isNotEmpty && tName.toUpperCase() != 'N/A') {
            raiserActivePigTypes.putIfAbsent(rId, () => {}).add(tName.trim());
          }
        }

        for (var rId in raisersWithActiveAssignments) {
          if (!raiserActivePigTypes.containsKey(rId) || raiserActivePigTypes[rId]!.isEmpty) {
            if (raiserToTypesFromInv.containsKey(rId)) {
              raiserActivePigTypes.putIfAbsent(rId, () => {}).addAll(raiserToTypesFromInv[rId]!);
            }
          }
        }
      } catch (err) {
        debugPrint('Notice resolving raiser active pig types: $err');
      }

      if (!mounted) return;
      setState(() {
        var mappedRaisers = (response as List).cast<Map<String, dynamic>>().map((r) {
          final appUsers = r['app_users'] as Map<String, dynamic>?;
          final googleOrAppName = (appUsers?['name'] ?? '').toString().trim();
          final raiserName = (r['name'] ?? '').toString().trim();
          final resolvedFullName = (raiserName.isNotEmpty &&
                  raiserName.toLowerCase() != 'hog raiser' &&
                  raiserName.toUpperCase() != 'N/A')
              ? raiserName
              : (googleOrAppName.isNotEmpty && googleOrAppName.toLowerCase() != 'hog raiser'
                  ? googleOrAppName
                  : (raiserName.isNotEmpty ? raiserName : 'Hog Raiser'));

          final raiserIdStr = (r['hog_raiser_id'] ?? r['id'] ?? '').toString();
          final userIdStr = (r['user_id'] ?? '').toString();
          String? resolvedAvatarUrl;

          final matchedFile = avatarMap[raiserIdStr] ?? avatarMap[userIdStr];
          if (matchedFile != null) {
            resolvedAvatarUrl = _supabase.storage.from('profile_pictures').getPublicUrl('avatars/$matchedFile');
          }

          final typesSet = raiserActivePigTypes[raiserIdStr] ?? {};
          final bool hasActiveBatch = raisersWithActiveAssignments.contains(raiserIdStr);

          final bool hasSow = typesSet.any((t) {
            final l = t.toLowerCase();
            return l.contains('sow') || l.contains('breed') || l.contains('inahin');
          });
          final bool hasFattening = typesSet.any((t) {
            final l = t.toLowerCase();
            return l.contains('fatten') || l.contains('baboy');
          });

          String resolvedPigType;
          if (hasSow && hasFattening) {
            resolvedPigType = 'Sow and Fattening';
          } else if (hasSow) {
            resolvedPigType = 'Sow';
          } else if (hasFattening) {
            resolvedPigType = 'Fattening';
          } else if (typesSet.isNotEmpty) {
            resolvedPigType = typesSet.join(' and ');
          } else if (hasActiveBatch) {
            final raw = (r['pig_type'] ?? '').toString().trim();
            final l = raw.toLowerCase();
            if (l.contains('sow') && l.contains('fatten')) {
              resolvedPigType = 'Sow and Fattening';
            } else if (l.contains('sow') || l.contains('breed')) {
              resolvedPigType = 'Sow';
            } else if (l.contains('fatten')) {
              resolvedPigType = 'Fattening';
            } else {
              resolvedPigType = 'Fattening';
            }
          } else {
            resolvedPigType = 'Unassigned';
          }

          final currentDbPigType = (r['pig_type'] ?? '').toString().trim();
          if (currentDbPigType != resolvedPigType && raiserIdStr.isNotEmpty && r['hog_raiser_id'] != null) {
            _supabase.from('hog_raisers').update({'pig_type': resolvedPigType}).eq('hog_raiser_id', r['hog_raiser_id']).then((_) {}).catchError((_) {});
          }

          return {
            ...r,
            'name': resolvedFullName,
            'email': appUsers?['email'] ?? '',
            'supabase_user_id': appUsers?['supabase_user_id'],
            'avatar_url': resolvedAvatarUrl ?? r['avatar_url'],
            'pig_type': resolvedPigType,
          };
        }).where((r) => r['supabase_user_id'] != null).toList();

        if (keyword != null && keyword.trim().isNotEmpty) {
          final cleanKw = keyword.trim().toLowerCase();
          final terms = cleanKw
              .split(RegExp(r'[, ]+'))
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();

          mappedRaisers = mappedRaisers.where((r) {
            final rName = (r['name'] ?? '').toString().toLowerCase();
            final rEmail = (r['email'] ?? '').toString().toLowerCase();
            final rPhone = (r['phone'] ?? '').toString().toLowerCase();
            final rAddress = (r['address'] ?? '').toString().toLowerCase();
            final rId = (r['hog_raiser_id'] ?? r['id'] ?? '').toString().toLowerCase();

            // Match exact phrase
            if (rName.contains(cleanKw) ||
                rEmail.contains(cleanKw) ||
                rPhone.contains(cleanKw) ||
                rAddress.contains(cleanKw) ||
                rId == cleanKw) {
              return true;
            }

            // Or match all individual words
            return terms.isNotEmpty &&
                terms.every((t) =>
                    rName.contains(t) ||
                    rEmail.contains(t) ||
                    rPhone.contains(t) ||
                    rAddress.contains(t));
          }).toList();
        }

        _raisers = mappedRaisers;
        _loadErrorMessage = null;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadErrorMessage = 'Load failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isTableRefreshing = false;
        });
      }
    }
  }

  int? _parseId(dynamic rawId) {
    if (rawId == null) return null;
    if (rawId is int) return rawId;
    return int.tryParse(rawId.toString());
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
              backgroundColor: _cardBg,
              child: AdminSidebar(
                currentRoute: '/raisers',
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
                    currentRoute: '/raisers',
                    onLogout: () => Navigator.of(context).pushReplacementNamed('/login'),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(isMobile ? 12 : 20),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [_panelStart, _panelEnd]),
                              border: Border.all(color: _panelBorder, width: 1),
                              borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 14 : 26,
                              vertical: isMobile ? 16 : 26,
                            ),
                            child: _buildMainContent(),
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

  Widget _buildMainContent() {
    final isMobile = Responsive.isMobile(context);
    final activeCount = _raisers.where((r) {
      final status = (r['status'] ?? '').toString().toLowerCase();
      final accStatus = (r['account_status'] ?? '').toString().toLowerCase();
      if (status == 'archived' || accStatus == 'archived') return false;
      if (status == 'pending' || accStatus == 'pending') return false;
      return status == 'active' || accStatus == 'active' || accStatus == 'approved';
    }).length;

    final pendingCount = _raisers.where((r) {
      final status = (r['status'] ?? '').toString().toLowerCase();
      final accStatus = (r['account_status'] ?? '').toString().toLowerCase();
      if (status == 'archived' || accStatus == 'archived') return false;
      return status == 'pending' || accStatus == 'pending';
    }).length;

    final archivedCount = _raisers.where((r) {
      final status = (r['status'] ?? '').toString().toLowerCase();
      final accStatus = (r['account_status'] ?? '').toString().toLowerCase();
      return status == 'archived' || accStatus == 'archived';
    }).length;

    final filteredRaisers = _raisers.where((r) {
      final status = (r['status'] ?? '').toString().toLowerCase();
      final accStatus = (r['account_status'] ?? '').toString().toLowerCase();
      final isArchived = status == 'archived' || accStatus == 'archived';
      final isPending = !isArchived && (status == 'pending' || accStatus == 'pending');
      final isActive = !isArchived && !isPending && (status == 'active' || accStatus == 'active' || accStatus == 'approved');

      if (_currentTab == 0) return isActive;
      if (_currentTab == 1) return isPending;
      return isArchived;
    }).toList();

    if (_inPageConfirmation != null) {
      return _inPageConfirmation!;
    }

    if (_selectedRaiserForProfile != null) {
      return RaiserProfileView(
        row: _selectedRaiserForProfile!,
        onCancel: () => setState(() => _selectedRaiserForProfile = null),
        onApprove: (row) async {
          await _approveRaiserDirectly(row);
          if (mounted) setState(() => _selectedRaiserForProfile = null);
        },
        onDelete: (row) async {
          await _deleteRaiser(row);
          if (mounted) setState(() => _selectedRaiserForProfile = null);
        },
        onArchive: (row) async {
          await _archiveRaiser(row);
          if (mounted) setState(() => _selectedRaiserForProfile = null);
        },
        onRestore: (row) async {
          await _restoreRaiser(row);
          if (mounted) setState(() => _selectedRaiserForProfile = null);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hog Raiser Management',
          style: AppTextStyles.pageTitle(_titleColor),
        ),
        if (_loadErrorMessage != null) ...[
          const SizedBox(height: 10),
          _buildErrorBanner(_loadErrorMessage!),
        ],
        const SizedBox(height: 20),
        isMobile
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton(0, 'Active Raisers', activeCount, isMobile: true),
                    const SizedBox(width: 8),
                    _buildTabButton(1, 'Pending Approvals', pendingCount, isMobile: true),
                    const SizedBox(width: 8),
                    _buildTabButton(2, 'Archived', archivedCount, isMobile: true),
                  ],
                ),
              )
            : Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildTabButton(0, 'Active Raisers', activeCount),
                  _buildTabButton(1, 'Pending Approvals', pendingCount),
                  _buildTabButton(2, 'Archived', archivedCount),
                ],
              ),
        const SizedBox(height: 20),
        ActiveRaisersTab(
          raisers: filteredRaisers,
          currentTab: _currentTab,
          searchCtrl: _searchCtrl,
          onRefresh: () => _loadRaisers(keyword: _searchCtrl.text, isRefresh: true),
          isRefreshing: _isLoading || _isTableRefreshing,
          onSearch: (keyword) => _loadRaisers(keyword: keyword),
          onShowDetails: (row) => setState(() => _selectedRaiserForProfile = row),
          onArchiveRaiser: _archiveRaiser,
          onRestoreRaiser: _restoreRaiser,
          onDeleteRaiser: _deleteRaiser,
          onApproveRaiser: _approveRaiserDirectly,
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, int count, {bool isMobile = false}) {
    final isSelected = _currentTab == index;
    final textStyle = AppTextStyles.jakarta(
      size: isMobile ? 12 : 14,
      weight: isSelected ? FontWeight.w800 : FontWeight.w600,
      color: isSelected 
          ? (_isDark ? PiggyTrunkTheme.ptPrimary : Colors.white) 
          : _hintText,
    );
    return ElevatedButton(
      onPressed: () => setState(() => _currentTab = index),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected 
            ? (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary) 
            : (_isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD)),
        foregroundColor: isSelected 
            ? (_isDark ? PiggyTrunkTheme.ptPrimary : Colors.white) 
            : _titleColor,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 16, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: Size(isMobile ? 0 : 180, isMobile ? 44 : 48),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: (_isLoading || _isTableRefreshing)
            ? Text.rich(
                TextSpan(
                  text: '$label (',
                  style: textStyle,
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: ShimmerBox(
                          width: 14,
                          height: isMobile ? 11 : 13,
                          borderRadius: BorderRadius.circular(3),
                          baseColor: isSelected
                              ? (_isDark ? PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.3))
                              : (_isDark ? const Color(0xFF283D59) : const Color(0xFFD6E2F0)),
                          highlightColor: isSelected
                              ? (_isDark ? PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.65))
                              : (_isDark ? const Color(0xFF385275) : const Color(0xFFEAF1F9)),
                        ),
                      ),
                    ),
                    TextSpan(text: ')', style: textStyle),
                  ],
                ),
                textAlign: TextAlign.center,
              )
            : Text('$label ($count)', style: textStyle),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _accentDark.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accentDark.withValues(alpha: 0.55)),
      ),
      child: Text(
        message,
        style: AppTextStyles.jakarta(
          size: 13,
          weight: FontWeight.w600,
          color: _titleColor,
        ),
      ),
    );
  }

  Future<void> _approveRaiserDirectly(Map<String, dynamic> row) async {
    final id = _parseId(row['id'] ?? row['hog_raiser_id']);
    final userId = _parseId(row['user_id']);
    if (id == null) return;

    final name = (row['name'] ?? '').toString();
    final email = (row['email'] ?? '').toString();
    final avatarUrl = (row['avatar_url'] ?? row['profile_picture'] ?? row['photo_url'] ?? row['image_url'])?.toString();

    setState(() {
      _inPageConfirmation = InPageConfirmationView(
        title: 'Approve Hog Raiser',
        subtitle: 'Activate and approve the raiser account.',
        message: 'Are you sure you want to approve and activate the hog raiser account for "$name"?',
        actionType: InPageActionType.success,
        userName: name,
        userEmail: email.isNotEmpty ? email : null,
        userRole: 'Hog Raiser',
        avatarUrl: avatarUrl,
        confirmButtonText: 'Yes, Approve',
        cancelButtonText: 'Cancel',
        onCancel: () => setState(() => _inPageConfirmation = null),
        onConfirm: () async {
          setState(() {
            _inPageConfirmation = null;
            _selectedRaiserForProfile = null;
            _isLoading = true;
          });
          try {
            final pkCol = row['id'] != null ? 'id' : 'hog_raiser_id';
            final List<Future> updates = [
              _supabase.from('hog_raisers').update({
                'status': 'Active',
                'account_status': 'active',
              }).eq(pkCol, id),
            ];

            if (userId != null) {
              updates.add(
                _supabase.from('app_users').update({
                  'status': 'active',
                }).eq('user_id', userId),
              );
            }

            await Future.wait(updates);

            if (email.isNotEmpty) {
              try {
                await EmailService().sendAccountApprovalEmail(
                  recipientEmail: email,
                  recipientName: name,
                  role: 'hog_raiser',
                );
              } catch (_) {}
            }

            await _loadRaisers(keyword: _searchCtrl.text);
            _showThemedSnackBar('Raiser "$name" approved successfully.');
          } catch (e) {
            _showThemedSnackBar('Approval failed: $e', isError: true);
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      );
    });
  }

  Future<void> _deleteRaiser(Map<String, dynamic> row) async {
    final id = _parseId(row['id'] ?? row['hog_raiser_id']);
    final userId = _parseId(row['user_id']);
    if (id == null) return;
    final name = (row['name'] ?? '').toString();
    final email = (row['email'] ?? '').toString();
    final avatarUrl = (row['avatar_url'] ?? row['profile_picture'] ?? row['photo_url'] ?? row['image_url'])?.toString();

    setState(() {
      _inPageConfirmation = InPageConfirmationView(
        title: 'Reject Hog Raiser',
        subtitle: 'Permanently remove this pending registration.',
        message: 'Are you sure you want to reject the registration for "$name"? This will permanently delete their registration record.',
        actionType: InPageActionType.danger,
        userName: name,
        userEmail: email.isNotEmpty ? email : null,
        userRole: 'Hog Raiser',
        avatarUrl: avatarUrl,
        warningText: 'This action is irreversible. The user registration will be deleted immediately.',
        confirmButtonText: 'Yes, Reject',
        cancelButtonText: 'Cancel',
        onCancel: () => setState(() => _inPageConfirmation = null),
        onConfirm: () async {
          setState(() {
            _inPageConfirmation = null;
            _selectedRaiserForProfile = null;
            _isLoading = true;
          });
          try {
            if (userId != null) {
              await _supabase.from('app_users').delete().eq('user_id', userId);
            } else {
              final pkCol = row['id'] != null ? 'id' : 'hog_raiser_id';
              await _supabase.from('hog_raisers').delete().eq(pkCol, id);
            }
            await _loadRaisers(keyword: _searchCtrl.text);
            _showThemedSnackBar('Raiser registration rejected successfully.');
          } catch (e) {
            _showThemedSnackBar('Rejection failed: $e', isError: true);
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      );
    });
  }

  Future<void> _archiveRaiser(Map<String, dynamic> row) async {
    final id = _parseId(row['id'] ?? row['hog_raiser_id']);
    final userId = _parseId(row['user_id']);
    if (id == null) return;
    final name = (row['name'] ?? '').toString();
    final email = (row['email'] ?? '').toString();
    final avatarUrl = (row['avatar_url'] ?? row['profile_picture'] ?? row['photo_url'] ?? row['image_url'])?.toString();

    setState(() {
      _inPageConfirmation = InPageConfirmationView(
        title: 'Archive Hog Raiser',
        subtitle: 'Move this hog raiser account to archived records.',
        message: 'Are you sure you want to archive the record for "$name"?',
        actionType: InPageActionType.danger,
        customIcon: Icons.archive_outlined,
        userName: name,
        userEmail: email.isNotEmpty ? email : null,
        userRole: 'Hog Raiser',
        avatarUrl: avatarUrl,
        confirmButtonText: 'Yes, Archive',
        cancelButtonText: 'Cancel',
        onCancel: () => setState(() => _inPageConfirmation = null),
        onConfirm: () async {
          setState(() {
            _inPageConfirmation = null;
            _selectedRaiserForProfile = null;
            _isLoading = true;
          });
          try {
            final pkCol = row['id'] != null ? 'id' : 'hog_raiser_id';
            final List<Future> updates = [
              _supabase.from('hog_raisers').update({
                'status': 'Archived',
                'account_status': 'Archived',
              }).eq(pkCol, id),
            ];

            if (userId != null) {
              updates.add(
                _supabase.from('app_users').update({
                  'status': 'archived',
                }).eq('user_id', userId),
              );
            }

            await Future.wait(updates);
            await _loadRaisers(keyword: _searchCtrl.text);
            _showThemedSnackBar('Raiser "$name" archived successfully.');
          } catch (e) {
            _showThemedSnackBar('Archive failed: $e', isError: true);
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      );
    });
  }

  Future<void> _restoreRaiser(Map<String, dynamic> row) async {
    final id = _parseId(row['id'] ?? row['hog_raiser_id']);
    final userId = _parseId(row['user_id']);
    if (id == null) return;
    final name = (row['name'] ?? '').toString();
    final email = (row['email'] ?? '').toString();
    final avatarUrl = (row['avatar_url'] ?? row['profile_picture'] ?? row['photo_url'] ?? row['image_url'])?.toString();

    setState(() {
      _inPageConfirmation = InPageConfirmationView(
        title: 'Restore Hog Raiser',
        subtitle: 'Restore this archived hog raiser account back to active.',
        message: 'Are you sure you want to restore the account for "$name" back to active?',
        actionType: InPageActionType.success,
        customIcon: Icons.unarchive_outlined,
        userName: name,
        userEmail: email.isNotEmpty ? email : null,
        userRole: 'Hog Raiser',
        avatarUrl: avatarUrl,
        confirmButtonText: 'Yes, Restore',
        cancelButtonText: 'Cancel',
        onCancel: () => setState(() => _inPageConfirmation = null),
        onConfirm: () async {
          setState(() {
            _inPageConfirmation = null;
            _selectedRaiserForProfile = null;
            _isLoading = true;
          });
          try {
            final pkCol = row['id'] != null ? 'id' : 'hog_raiser_id';
            final List<Future> updates = [
              _supabase.from('hog_raisers').update({
                'status': 'Active',
                'account_status': 'Approved',
              }).eq(pkCol, id),
            ];

            if (userId != null) {
              updates.add(
                _supabase.from('app_users').update({
                  'status': 'approved',
                }).eq('user_id', userId),
              );
            }

            await Future.wait(updates);
            await _loadRaisers(keyword: _searchCtrl.text);
            _showThemedSnackBar('Raiser "$name" restored successfully.');
          } catch (e) {
            _showThemedSnackBar('Restore failed: $e', isError: true);
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      );
    });
  }
}
