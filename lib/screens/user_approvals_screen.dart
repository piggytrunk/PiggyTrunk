import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_toast.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/users/user_profile_view.dart';
import '../widgets/common/in_page_confirmation_view.dart';
import '../services/email_service.dart';
import '../utils/responsive.dart';
import '../widgets/common/shimmer_loading.dart';
import '../main.dart';

class UserApprovalsScreen extends StatefulWidget {
  const UserApprovalsScreen({super.key});

  @override
  State<UserApprovalsScreen> createState() => _UserApprovalsScreenState();
}

class _UserApprovalsScreenState extends State<UserApprovalsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _selectedUserForProfile;
  Widget? _inPageConfirmation;
  bool _isLoading = true;
  bool _isTableRefreshing = false;
  int _currentTab = 0; // 0 = Active Partners, 1 = Pending Partners, 2 = Active Cashiers, 3 = Pending Cashiers
  String? _loadErrorMessage;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgDark => _isDark ? PiggyTrunkTheme.ptBgDark : PiggyTrunkTheme.ptBg;
  Color get _panelStart => _isDark ? const Color(0xFF1A2940) : Colors.white;
  Color get _panelEnd => _isDark ? const Color(0xFF0F1C2F) : Colors.white;
  Color get _panelBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFE3EAF3);
  Color get _cardBg => _isDark ? const Color(0xFF132238) : Colors.white;
  Color get _cardBorder => _isDark ? const Color(0xFF27405F) : const Color(0xFFC6D8EF);
  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _fieldBg => _isDark ? const Color(0xFF1A2B44) : const Color(0xFFEEF4FD);
  Color get _fieldBorder => _isDark ? const Color(0xFF28405D) : const Color(0xFFB4C9E6);
  Color get _fieldFocus => _isDark ? const Color(0xFF88A7CE) : const Color(0xFF315C8F);
  Color get _fieldText => _isDark ? const Color(0xFFE6F1FF) : const Color(0xFF18314F);
  Color get _hintText => _isDark ? const Color(0xFF8FA7C4) : const Color(0xFF5D7391);

  RealtimeChannel? _appUsersChannel;
  RealtimeChannel? _notifsChannel;
  bool _hasCheckedRouteArgs = false;

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
    _loadUsers();
    _subscribeToAppUsers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedRouteArgs) {
      _hasCheckedRouteArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      String? targetTab;
      String? searchKeyword;

      if (args is String) {
        targetTab = args;
      } else if (args is Map) {
        targetTab = args['tab']?.toString();
        // Only set searchKeyword if explicitly passed under 'search', not falling back to name/email
        searchKeyword = args['search']?.toString();
      }

      // Also support direct query parameters on Flutter Web
      if (kIsWeb && targetTab == null) {
        final uri = Uri.base;
        if (uri.queryParameters.containsKey('tab')) {
          targetTab = uri.queryParameters['tab'];
        } else if (uri.queryParameters['role'] == 'cashier') {
          targetTab = uri.queryParameters['status'] == 'active' ? 'active_cashier' : 'pending_cashier';
        } else if (uri.queryParameters['role'] == 'partner') {
          targetTab = uri.queryParameters['status'] == 'active' ? 'active_partner' : 'pending_partner';
        }
        if (uri.queryParameters.containsKey('search')) {
          searchKeyword = uri.queryParameters['search'];
        }
      }

      if (targetTab == 'pending_cashier') {
        setState(() => _currentTab = 3);
      } else if (targetTab == 'active_cashier' || targetTab == 'cashier') {
        setState(() => _currentTab = 2);
      } else if (targetTab == 'pending_partner' || targetTab == 'pending') {
        setState(() => _currentTab = 1);
      } else if (targetTab == 'active_partner' || targetTab == 'partner') {
        setState(() => _currentTab = 0);
      }

      if (searchKeyword != null && searchKeyword.trim().isNotEmpty) {
        _searchCtrl.text = searchKeyword.trim();
        _loadUsers(keyword: searchKeyword.trim());
      }
    }
  }

  void _subscribeToAppUsers() {
    _appUsersChannel = _supabase
        .channel('public:app_users_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_users',
          callback: (payload) {
            if (mounted) {
              _loadUsers(keyword: _searchCtrl.text);
            }
          },
        )
        .subscribe();

    _notifsChannel = _supabase
        .channel('public:user_approvals_notifs_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'admin_notifications',
          callback: (payload) {
            if (mounted) {
              _loadUsers(keyword: _searchCtrl.text);
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _appUsersChannel?.unsubscribe();
    _notifsChannel?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({String keyword = '', bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() => _isTableRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }
    try {
      dynamic query = _supabase
          .from('app_users')
          .select('*');

      if (keyword.trim().isNotEmpty) {
        query = query.or('name.ilike.%$keyword%,email.ilike.%$keyword%');
      }

      final dynamic response = await query.order('user_id', ascending: false);
      final List<Map<String, dynamic>> list = [];
      if (response is List) {
        for (var item in response) {
          if (item is Map) {
            list.add(Map<String, dynamic>.from(item));
          }
        }
      }

      // Fetch partner_investors and hog_raisers in parallel to enrich phone, address, and avatar safely
      try {
        final dynamic partnersRes = await _supabase.from('partner_investors').select('*');
        final Map<int, Map<String, dynamic>> partnerMap = {};
        if (partnersRes is List) {
          for (var p in partnersRes) {
            if (p is Map) {
              final uid = (p['user_id'] as num?)?.toInt();
              if (uid != null) partnerMap[uid] = Map<String, dynamic>.from(p);
            }
          }
        }

        final dynamic raisersRes = await _supabase.from('hog_raisers').select('*');
        final Map<int, Map<String, dynamic>> raiserMap = {};
        if (raisersRes is List) {
          for (var r in raisersRes) {
            if (r is Map) {
              final uid = (r['user_id'] as num?)?.toInt();
              if (uid != null) raiserMap[uid] = Map<String, dynamic>.from(r);
            }
          }
        }

        final dynamic cashiersRes = await _supabase.from('cashiers').select('*');
        final Map<int, Map<String, dynamic>> cashierMap = {};
        if (cashiersRes is List) {
          for (var c in cashiersRes) {
            if (c is Map) {
              final uid = (c['user_id'] as num?)?.toInt();
              if (uid != null) cashierMap[uid] = Map<String, dynamic>.from(c);
            }
          }
        }

        // Fetch admin_notifications for cashier_profile and user_registration to enrich cashier profile phone & address
        final Map<dynamic, Map<String, dynamic>> notifMap = {};
        try {
          final dynamic notifsRes = await _supabase
              .from('admin_notifications')
              .select('metadata, created_at')
              .inFilter('type', ['cashier_profile', 'user_registration'])
              .order('created_at', ascending: true);
          if (notifsRes is List) {
            for (var n in notifsRes) {
              if (n is Map && n['metadata'] is Map) {
                final m = Map<String, dynamic>.from(n['metadata'] as Map);
                final uid = (m['user_id'] as num?)?.toInt();
                final email = m['email']?.toString().toLowerCase().trim();
                if (uid != null) notifMap[uid] = m;
                if (email != null && email.isNotEmpty) notifMap[email] = m;
              }
            }
          }
        } catch (notifErr) {
          debugPrint('Notice enriching user from admin_notifications: $notifErr');
        }

        for (var u in list) {
          final uid = (u['user_id'] as num?)?.toInt();
          final email = u['email']?.toString().toLowerCase().trim() ?? '';
          final role = u['role']?.toString().toLowerCase() ?? '';
          if (uid != null) {
            if (partnerMap.containsKey(uid)) {
              u['contact_number'] = partnerMap[uid]?['contact_number'];
              u['address'] = partnerMap[uid]?['address'];
              final pAvatar = partnerMap[uid]?['avatar_url']?.toString().trim();
              if (pAvatar != null && pAvatar.isNotEmpty && pAvatar != 'null') {
                u['avatar_url'] = pAvatar;
              }
            } else if (raiserMap.containsKey(uid)) {
              u['phone'] = raiserMap[uid]?['phone'];
              u['address'] = raiserMap[uid]?['address'];
              final rAvatar = raiserMap[uid]?['avatar_url']?.toString().trim();
              if (rAvatar != null && rAvatar.isNotEmpty && rAvatar != 'null') {
                u['avatar_url'] = rAvatar;
              }
            } else if (cashierMap.containsKey(uid) || role.contains('cashier')) {
              final cAvatar = cashierMap[uid]?['avatar_url']?.toString().trim();
              if (cAvatar != null && cAvatar.isNotEmpty && cAvatar != 'null') {
                u['avatar_url'] = cAvatar;
              }
              final meta = notifMap[uid] ?? (email.isNotEmpty ? notifMap[email] : null);
              if (meta != null) {
                final nPhone = (meta['phone'] ?? meta['contact_number'] ?? meta['phone_number'])?.toString().trim();
                if (nPhone != null && nPhone.isNotEmpty && nPhone != 'null') {
                  u['phone'] = nPhone;
                  u['contact_number'] = nPhone;
                }
                final nAddr = (meta['address'] ?? meta['store_address'] ?? meta['branch_address'])?.toString().trim();
                if (nAddr != null && nAddr.isNotEmpty && nAddr != 'null') {
                  u['address'] = nAddr;
                }
                final nAv = meta['avatar_url']?.toString().trim();
                if (u['avatar_url'] == null && nAv != null && nAv.isNotEmpty && nAv != 'null') {
                  u['avatar_url'] = nAv;
                }
              }
            }
          }
        }
      } catch (enrichErr) {
        debugPrint('Notice enriching user phone/address/avatar: $enrichErr');
      }

      debugPrint('UserApprovalsScreen loaded ${list.length} app_users: $list');

      if (mounted) {
        setState(() {
          _users = list.where((u) {
            final r = u['role']?.toString().toLowerCase() ?? '';
            return r != 'admin';
          }).toList();
          _loadErrorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('UserApprovalsScreen _loadUsers error: $e');
      if (mounted) {
        setState(() {
          _loadErrorMessage = 'Load failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isTableRefreshing = false;
        });
      }
    }
  }

  void _approveUser(int userId, String name, {String? email, String? role}) {
    final targetUser = _users.firstWhere((u) => u['user_id'] == userId, orElse: () => <String, dynamic>{});
    final userEmail = email ?? targetUser['email']?.toString() ?? '';
    final userRole = role ?? targetUser['role']?.toString() ?? 'User';
    final avatarUrl = _getAvatarUrl(targetUser);

    setState(() {
      _inPageConfirmation = InPageConfirmationView(
        title: 'Confirm Approval',
        subtitle: 'Approve $name as $userRole',
        message: 'Are you sure you want to approve the account for "$name"? They will receive an activation email immediately and will be granted system access.',
        actionType: InPageActionType.success,
        userName: name,
        userEmail: userEmail,
        userRole: userRole,
        avatarUrl: avatarUrl,
        confirmButtonText: 'Yes, Approve',
        cancelButtonText: 'Cancel',
        onCancel: () => setState(() => _inPageConfirmation = null),
        onConfirm: () async {
          setState(() {
            _inPageConfirmation = null;
            _selectedUserForProfile = null;
            _isLoading = true;
          });
          try {
            await _supabase
                .from('app_users')
                .update({'status': 'active'})
                .eq('user_id', userId);

            try {
              await _supabase
                  .from('cashiers')
                  .update({'status': 'active'})
                  .eq('user_id', userId);
            } catch (_) {}

            try {
              await _supabase
                  .from('partner_investors')
                  .update({'status': 'active'})
                  .eq('user_id', userId);
            } catch (_) {}

            try {
              await _supabase
                  .from('hog_raisers')
                  .update({'account_status': 'active', 'status': 'Active'})
                  .eq('user_id', userId);
            } catch (_) {}

            // Trigger Account Approval Email
            try {
              if (userEmail.isNotEmpty) {
                debugPrint("[UserApprovals] Sending approval email to $userEmail ($userRole)...");
                final sent = await EmailService().sendAccountApprovalEmail(
                  recipientEmail: userEmail,
                  recipientName: name,
                  role: userRole,
                );
                if (sent) {
                  debugPrint("[UserApprovals] Approval email delivered successfully to $userEmail");
                } else {
                  debugPrint("[UserApprovals] Warning: Approval email could not be delivered to $userEmail");
                }
              }
            } catch (e) {
              debugPrint("[UserApprovals] Notice: Failed to send approval email: $e");
            }

            // Transition registration notification to Approved state
            try {
              if (userEmail.isNotEmpty) {
                final roleDisplay = userRole.toLowerCase().contains('raiser')
                    ? 'Hog Raiser'
                    : (userRole.toLowerCase().contains('partner')
                        ? 'Partner Investor'
                        : (userRole.toLowerCase().contains('cashier') ? 'Cashier' : 'User'));

                await _supabase
                    .from('admin_notifications')
                    .update({
                      'is_read': true,
                      'title': 'Account Approved for $roleDisplay',
                      'message': 'User $name ($userEmail) was approved as $roleDisplay.',
                    })
                    .eq('metadata->>email', userEmail)
                    .inFilter('type', ['user_registration', 'approval_email']);
              }
            } catch (_) {}

            await _loadUsers(keyword: _searchCtrl.text);

            if (!mounted) return;
            AppToast.success(context, 'User "$name" approved successfully.');
          } catch (e) {
            if (!mounted) return;
            AppToast.error(context, 'Approval failed: $e');
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      );
    });
  }

  void _rejectUser(int userId, String name, {String? email, String? role}) {
    final targetUser = _users.firstWhere((u) => u['user_id'] == userId, orElse: () => <String, dynamic>{});
    final userEmail = email ?? targetUser['email']?.toString() ?? '';
    final userRole = role ?? targetUser['role']?.toString() ?? 'User';
    final avatarUrl = _getAvatarUrl(targetUser);

    setState(() {
      _inPageConfirmation = InPageConfirmationView(
        title: 'Confirm Rejection',
        subtitle: 'Reject registration for $name',
        message: 'Are you sure you want to reject the registration for "$name"? This user will not be able to log in.',
        actionType: InPageActionType.danger,
        userName: name,
        userEmail: userEmail,
        userRole: userRole,
        avatarUrl: avatarUrl,
        confirmButtonText: 'Yes, Reject',
        cancelButtonText: 'Cancel',
        onCancel: () => setState(() => _inPageConfirmation = null),
        onConfirm: () async {
          setState(() {
            _inPageConfirmation = null;
            _selectedUserForProfile = null;
            _isLoading = true;
          });
          try {
            await _supabase
                .from('app_users')
                .update({'status': 'rejected'})
                .eq('user_id', userId);

            try {
              if (userEmail.isNotEmpty) {
                await _supabase
                    .from('admin_notifications')
                    .update({
                      'is_read': true,
                      'title': 'Registration Rejected',
                      'message': 'Registration for "$name" ($userEmail) was rejected.',
                    })
                    .eq('metadata->>email', userEmail)
                    .eq('type', 'user_registration');
              }
            } catch (_) {}

            await _loadUsers(keyword: _searchCtrl.text);

            if (!mounted) return;
            AppToast.success(context, 'Registration for "$name" rejected successfully.');
          } catch (e) {
            if (!mounted) return;
            AppToast.error(context, 'Rejection failed: $e');
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      );
    });
  }

  void _suspendUser(int userId, String name, {String? email, String? role}) {
    final targetUser = _users.firstWhere((u) => u['user_id'] == userId, orElse: () => <String, dynamic>{});
    final userEmail = email ?? targetUser['email']?.toString() ?? '';
    final userRole = role ?? targetUser['role']?.toString() ?? 'User';
    final avatarUrl = _getAvatarUrl(targetUser);

    setState(() {
      _inPageConfirmation = InPageConfirmationView(
        title: 'Confirm Suspension',
        subtitle: 'Suspend account for $name',
        message: 'Are you sure you want to suspend the account for "$name"? They will be blocked from logging in.',
        actionType: InPageActionType.danger,
        userName: name,
        userEmail: userEmail,
        userRole: userRole,
        avatarUrl: avatarUrl,
        confirmButtonText: 'Yes, Suspend',
        cancelButtonText: 'Cancel',
        onCancel: () => setState(() => _inPageConfirmation = null),
        onConfirm: () async {
          setState(() {
            _inPageConfirmation = null;
            _selectedUserForProfile = null;
            _isLoading = true;
          });
          try {
            await _supabase
                .from('app_users')
                .update({'status': 'suspended'})
                .eq('user_id', userId);

            await _loadUsers(keyword: _searchCtrl.text);

            if (!mounted) return;
            AppToast.success(context, 'User "$name" suspended successfully.');
          } catch (e) {
            if (!mounted) return;
            AppToast.error(context, 'Suspend failed: $e');
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      );
    });
  }

  void _activateUser(int userId, String name, {String? email, String? role}) {
    final targetUser = _users.firstWhere((u) => u['user_id'] == userId, orElse: () => <String, dynamic>{});
    final userEmail = email ?? targetUser['email']?.toString() ?? '';
    final userRole = role ?? targetUser['role']?.toString() ?? 'User';
    final avatarUrl = _getAvatarUrl(targetUser);

    setState(() {
      _inPageConfirmation = InPageConfirmationView(
        title: 'Confirm Activation',
        subtitle: 'Reactivate account for $name',
        message: 'Are you sure you want to reactivate the account for "$name"? Their login privileges and system access will be restored.',
        actionType: InPageActionType.success,
        userName: name,
        userEmail: userEmail,
        userRole: userRole,
        avatarUrl: avatarUrl,
        confirmButtonText: 'Yes, Activate',
        cancelButtonText: 'Cancel',
        onCancel: () => setState(() => _inPageConfirmation = null),
        onConfirm: () async {
          setState(() {
            _inPageConfirmation = null;
            _selectedUserForProfile = null;
            _isLoading = true;
          });
          try {
            await _supabase
                .from('app_users')
                .update({'status': 'active'})
                .eq('user_id', userId);

            try {
              await _supabase
                  .from('cashiers')
                  .update({'status': 'active'})
                  .eq('user_id', userId);
            } catch (_) {}

            try {
              await _supabase
                  .from('partner_investors')
                  .update({'status': 'active'})
                  .eq('user_id', userId);
            } catch (_) {}

            await _loadUsers(keyword: _searchCtrl.text);

            if (!mounted) return;
            AppToast.success(context, 'User "$name" activated successfully.');
          } catch (e) {
            if (!mounted) return;
            AppToast.error(context, 'Activation failed: $e');
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      );
    });
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
                currentRoute: '/users',
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
                    currentRoute: '/users',
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
                            child: _buildListView(),
                          ),
                        ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildListView() {
    if (_inPageConfirmation != null) {
      return _inPageConfirmation!;
    }

    if (_selectedUserForProfile != null) {
      return UserProfileView(
        row: _selectedUserForProfile!,
        onCancel: () => setState(() => _selectedUserForProfile = null),
        onApprove: (row) {
          final userId = int.tryParse(row['user_id'].toString()) ?? 0;
          final name = (row['name'] ?? 'User').toString();
          final email = (row['email'] ?? '').toString();
          final role = (row['role'] ?? '').toString();
          _approveUser(userId, name, email: email, role: role);
        },
        onReject: (row) {
          final userId = int.tryParse(row['user_id'].toString()) ?? 0;
          final name = (row['name'] ?? 'User').toString();
          final email = (row['email'] ?? '').toString();
          final role = (row['role'] ?? '').toString();
          _rejectUser(userId, name, email: email, role: role);
        },
        onSuspend: (row) {
          final userId = int.tryParse(row['user_id'].toString()) ?? 0;
          final name = (row['name'] ?? 'User').toString();
          final email = (row['email'] ?? '').toString();
          final role = (row['role'] ?? '').toString();
          _suspendUser(userId, name, email: email, role: role);
        },
        onActivate: (row) {
          final userId = int.tryParse(row['user_id'].toString()) ?? 0;
          final name = (row['name'] ?? 'User').toString();
          final email = (row['email'] ?? '').toString();
          final role = (row['role'] ?? '').toString();
          _activateUser(userId, name, email: email, role: role);
        },
      );
    }

    final isMobile = Responsive.isMobile(context);

    // Counts for tabs
    final activePartnersCount = _users.where((u) {
      final r = u['role']?.toString().toLowerCase() ?? '';
      final s = u['status']?.toString().toLowerCase() ?? '';
      return (r.contains('partner') || r == 'investor') && (s == 'active' || s == 'approved');
    }).length;

    final pendingPartnersCount = _users.where((u) {
      final r = u['role']?.toString().toLowerCase() ?? '';
      final s = u['status']?.toString().toLowerCase() ?? '';
      return (r.contains('partner') || r == 'investor') && (s == 'pending');
    }).length;

    final activeCashiersCount = _users.where((u) {
      final r = u['role']?.toString().toLowerCase() ?? '';
      final s = u['status']?.toString().toLowerCase() ?? '';
      return r.contains('cashier') && (s == 'active' || s == 'approved');
    }).length;

    final pendingCashiersCount = _users.where((u) {
      final r = u['role']?.toString().toLowerCase() ?? '';
      final s = u['status']?.toString().toLowerCase() ?? '';
      return r.contains('cashier') && (s == 'pending');
    }).length;

    // Filter list by selected tab
    final filtered = _users.where((u) {
      final r = u['role']?.toString().toLowerCase() ?? '';
      final s = u['status']?.toString().toLowerCase() ?? '';
      
      if (_currentTab == 0) return (r.contains('partner') || r == 'investor') && (s == 'active' || s == 'approved');
      if (_currentTab == 1) return (r.contains('partner') || r == 'investor') && s == 'pending';
      if (_currentTab == 2) return r.contains('cashier') && (s == 'active' || s == 'approved');
      return r.contains('cashier') && s == 'pending';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Management',
          style: AppTextStyles.pageTitle(_titleColor),
        ),
        if (_loadErrorMessage != null) ...[
          const SizedBox(height: 10),
          _buildErrorBanner(_loadErrorMessage!),
        ],
        const SizedBox(height: 20),
        // Tab selectors
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTabButton(0, 'Active Partner Investors', activePartnersCount),
              const SizedBox(width: 12),
              _buildTabButton(1, 'Pending Partner Investors', pendingPartnersCount),
              const SizedBox(width: 12),
              _buildTabButton(2, 'Active Cashiers', activeCashiersCount),
              const SizedBox(width: 12),
              _buildTabButton(3, 'Pending Cashiers', pendingCashiersCount),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
            border: Border.all(color: _cardBorder),
          ),
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          child: Column(
            children: [
              // Search controls
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: AppTextStyles.body(_fieldText),
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        hintStyle: AppTextStyles.body(_hintText),
                        prefixIcon: Icon(Icons.search, color: _hintText),
                        filled: true,
                        fillColor: _fieldBg,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _fieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _fieldFocus),
                        ),
                      ),
                      onSubmitted: (value) => _loadUsers(keyword: value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _loadUsers(keyword: _searchCtrl.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDark ? PiggyTrunkTheme.ptSurface : PiggyTrunkTheme.ptPrimary,
                      foregroundColor: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                      minimumSize: const Size(90, 48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(
                      'Search',
                      style: AppTextStyles.button(_isDark ? PiggyTrunkTheme.ptPrimary : Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: (_isLoading || _isTableRefreshing) ? null : () => _loadUsers(keyword: _searchCtrl.text, isRefresh: true),
                    icon: (_isLoading || _isTableRefreshing)
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            ),
                          )
                        : Icon(Icons.refresh_rounded, color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary, size: 24),
                    tooltip: 'Refresh Users List',
                    style: IconButton.styleFrom(
                      backgroundColor: _isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD),
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_isLoading || _isTableRefreshing)
                TableSkeletonLoader(
                  isDark: _isDark,
                  minWidth: 850,
                  cardBg: _cardBg,
                  cardBorder: _cardBorder,
                  headerBg: _isDark ? const Color(0xFF1B2E48) : const Color(0xFFEDF4FC),
                  headers: const ['FULL NAME', 'EMAIL ADDRESS', 'ROLE TYPE', 'STATUS', 'ACTIONS'],
                  columnFlexes: const [3, 4, 2, 2, 4],
                  rowCount: 6,
                  borderRadius: 8,
                )
              else
                LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = constraints.maxWidth > 850 ? constraints.maxWidth : 850.0;
                  return Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _tableHeader(),
                          const SizedBox(height: 4),
                          if (filtered.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 50),
                              child: Center(
                                child: Text(
                                  _currentTab == 0 || _currentTab == 2
                                      ? 'No active users found'
                                      : 'No pending approvals',
                                  style: AppTextStyles.jakarta(size: 20, weight: FontWeight.w700, color: _titleColor),
                                ),
                              ),
                            )
                          else
                            ...filtered.map((u) => _tableRow(u)),
                        ],
                      ),
                    ),
                  ),
                );
              },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, int count) {
    final isSelected = _currentTab == index;
    final textStyle = AppTextStyles.jakarta(
      size: 14,
      weight: isSelected ? FontWeight.w800 : FontWeight.w600,
      color: isSelected 
          ? (_isDark ? PiggyTrunkTheme.ptPrimary : Colors.white) 
          : _hintText,
    );
    return ElevatedButton(
      onPressed: () => setState(() {
        _currentTab = index;
        _selectedUserForProfile = null;
        _inPageConfirmation = null;
      }),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected 
            ? (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary) 
            : (_isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD)),
        foregroundColor: isSelected 
            ? (_isDark ? PiggyTrunkTheme.ptPrimary : Colors.white) 
            : _titleColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(185, 48),
      ),
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
                        height: 13,
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
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1B2E48) : const Color(0xFFEDF4FC),
        border: Border(bottom: BorderSide(color: _cardBorder, width: 1.2)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('FULL NAME', style: AppTextStyles.tableHeader(_hintText)),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('EMAIL ADDRESS', style: AppTextStyles.tableHeader(_hintText)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('ROLE TYPE', style: AppTextStyles.tableHeader(_hintText)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('STATUS', style: AppTextStyles.tableHeader(_hintText)),
            ),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: Text('ACTIONS', style: AppTextStyles.tableHeader(_hintText)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> row) {
    final userId = int.tryParse(row['user_id'].toString()) ?? 0;
    final name = (row['name']?.toString() ?? '').trim();
    final email = row['email']?.toString() ?? '';
    final roleRaw = (row['role'] ?? 'User').toString();
    final role = roleRaw.toLowerCase() == 'partner'
        ? 'Partner Investor'
        : (roleRaw.toLowerCase() == 'cashier'
            ? 'Cashier'
            : (roleRaw.toLowerCase().contains('raiser') ? 'Hog Raiser' : roleRaw));
    final status = row['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final Color statusColor = (status == 'ACTIVE' || status == 'APPROVED')
        ? PiggyTrunkTheme.ptSuccess
        : (status == 'PENDING'
            ? const Color(0xFFFFAA00)
            : const Color(0xFFFF758C));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _cardBorder.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                name.isEmpty ? 'User' : name,
                style: AppTextStyles.body(_titleColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                email,
                style: AppTextStyles.body(_titleColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                role,
                style: AppTextStyles.body(_titleColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Details Action Button
                    _buildSquareIconButton(
                      icon: Icons.visibility_outlined,
                      iconColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                      bgColor: (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: _isDark ? 0.08 : 0.1),
                      borderColor: (_isDark ? Colors.white : PiggyTrunkTheme.ptPrimary).withValues(alpha: _isDark ? 0.22 : 0.3),
                      tooltip: 'View User Details',
                      onTap: () => _showUserDetails(row),
                    ),

                    if (status == 'PENDING') ...[
                      const SizedBox(width: 6),
                      // 2. Approve Action Button
                      _buildSquareIconButton(
                        icon: Icons.check_rounded,
                        iconColor: PiggyTrunkTheme.ptSuccess,
                        bgColor: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.1),
                        borderColor: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.35),
                        tooltip: 'Approve User',
                        onTap: () => _approveUser(userId, name, email: email, role: role),
                      ),
                      const SizedBox(width: 6),

                      // 3. Reject Action Button
                      _buildSquareIconButton(
                        icon: Icons.close_rounded,
                        iconColor: const Color(0xFFEF4444),
                        bgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderColor: const Color(0xFFEF4444).withValues(alpha: 0.35),
                        tooltip: 'Reject User',
                        onTap: () => _rejectUser(userId, name, email: email, role: role),
                      ),
                    ] else if (status == 'ACTIVE') ...[
                      const SizedBox(width: 6),
                      // Suspend Action Button
                      _buildSquareIconButton(
                        icon: Icons.block_rounded,
                        iconColor: const Color(0xFFEF4444),
                        bgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderColor: const Color(0xFFEF4444).withValues(alpha: 0.35),
                        tooltip: 'Suspend User',
                        onTap: () => _suspendUser(userId, name, email: email, role: role),
                      ),
                    ] else if (status == 'SUSPENDED') ...[
                      const SizedBox(width: 6),
                      // Activate Action Button
                      _buildSquareIconButton(
                        icon: Icons.lock_open_rounded,
                        iconColor: PiggyTrunkTheme.ptSuccess,
                        bgColor: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.1),
                        borderColor: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.35),
                        tooltip: 'Activate User',
                        onTap: () => _activateUser(userId, name, email: email, role: role),
                      ),
                    ],
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildSquareIconButton({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 16,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> row) {
    setState(() {
      _inPageConfirmation = null;
      _selectedUserForProfile = row;
    });
  }

  String? _getAvatarUrl(Map<String, dynamic> row) {
    final appUsers = row['app_users'] as Map<String, dynamic>?;
    final metadata = row['raw_user_meta_data'] as Map<String, dynamic>?;
    final dynamic candidate = row['profile_picture'] ??
        row['avatar_url'] ??
        row['photo_url'] ??
        row['image_url'] ??
        row['profile_image'] ??
        row['picture'] ??
        appUsers?['profile_picture'] ??
        appUsers?['avatar_url'] ??
        appUsers?['photo_url'] ??
        appUsers?['image_url'] ??
        appUsers?['profile_image'] ??
        appUsers?['picture'] ??
        metadata?['avatar_url'] ??
        metadata?['picture'] ??
        metadata?['profile_picture'];

    if (candidate != null) {
      final str = candidate.toString().trim();
      if (str.startsWith('http://') || str.startsWith('https://')) {
        return str;
      }
    }
    return null;
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.bold),
      ),
    );
  }
}
