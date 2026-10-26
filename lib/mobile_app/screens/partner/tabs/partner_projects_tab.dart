import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/screen_fit_util.dart';
import '../../../utils/app_strings.dart';
import '../widgets/batch_raiser_details_drawer.dart';
import '../../../services/auth_session_service.dart';
import '../../../widgets/piggy_toast.dart';

class PartnerProjectsTab extends StatefulWidget {
  final List<Map<String, dynamic>> projectsList;
  final List<Map<String, dynamic>> fundedProjectsList;
  final double investedAmount;
  final Future<void> Function() onRefresh;
  final VoidCallback? onNavigateToLifecycle;
  final VoidCallback? onNavigateToActivities;

  const PartnerProjectsTab({
    super.key,
    required this.projectsList,
    this.fundedProjectsList = const [],
    this.investedAmount = 0.0,
    required this.onRefresh,
    this.onNavigateToLifecycle,
    this.onNavigateToActivities,
  });

  @override
  State<PartnerProjectsTab> createState() => _PartnerProjectsTabState();
}

class _PartnerProjectsTabState extends State<PartnerProjectsTab> {
  static const Color _brandColor = Color(0xFF18314F);
  static const Color _brandAccent = Color(0xFF2FB36F);

  bool _isInvesting = false;
  int _selectedSubTab = 0; // 0: My Investments, 1: Explore Batches
  Map<String, dynamic>? _selectedBatch;
  final TextEditingController _amountController = TextEditingController(text: '');
  double _parsedAmount = 0.0;
  bool _isSubmitting = false;
  bool _hasAttemptedSubmit = false;

  // Specific Hog / Pig Type Target Allocation State
  String _selectedTargetType = 'ALL'; // 'ALL', 'FATTENING', 'SOW', 'CUSTOM'
  Set<String> _selectedHogTags = {};
  List<Map<String, dynamic>> _currentBatchHogs = [];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    if (widget.fundedProjectsList.isEmpty && widget.projectsList.isNotEmpty) {
      _selectedSubTab = 1;
    }
  }

  @override
  void didUpdateWidget(covariant PartnerProjectsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fundedProjectsList.isEmpty && widget.projectsList.isNotEmpty && _selectedSubTab == 0) {
      _selectedSubTab = 1;
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    final text = _amountController.text.replaceAll(',', '').trim();
    final val = double.tryParse(text) ?? 0.0;
    if (_parsedAmount != val) {
      setState(() {
        _parsedAmount = val;
        if (val > 0) {
          _hasAttemptedSubmit = false;
        }
      });
    }
  }

  void _setPresetAmount(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(0);
      _parsedAmount = amount;
      _hasAttemptedSubmit = false;
    });
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _startInvestmentFlow([Map<String, dynamic>? batch]) {
    if (widget.projectsList.isEmpty && batch == null) {
      PiggyToast.showWarning(
        context,
        'No active batches available for investment at the moment.',
      );
      return;
    }

    final selected = batch ?? (widget.projectsList.isNotEmpty ? widget.projectsList.first : null);
    List<Map<String, dynamic>> rawHogs = [];
    if (selected != null && selected['hogs'] is List) {
      rawHogs = List<Map<String, dynamic>>.from(
        (selected['hogs'] as List).whereType<Map<String, dynamic>>(),
      );
    }
    // Synthesize hogs if batch has empty hogs array
    if (rawHogs.isEmpty && selected != null) {
      final count = (selected['total_hogs'] as num?)?.toInt() ?? 6;
      final rawType = (selected['hog_type'] ?? selected['pig_type'] ?? 'Fattening').toString();
      final half = (count / 2).ceil();
      for (int i = 0; i < count; i++) {
        final isSow = i >= half && (rawType.toLowerCase().contains('sow') || rawType.toLowerCase().contains('breed'));
        rawHogs.add({
          'hog_id': i + 1,
          'tag_number': 'HOG-${i + 1}',
          'pig_type': isSow ? 'Sow / Breeding' : 'Fattening',
          'stage': 'Grower',
          'health_status': 'Healthy',
          'status': 'active',
        });
      }
    }

    setState(() {
      _selectedBatch = selected;
      _isInvesting = true;
      _amountController.text = '';
      _parsedAmount = 0.0;
      _hasAttemptedSubmit = false;
      _currentBatchHogs = rawHogs;
      _selectedHogTags = rawHogs.map((h) => (h['tag_number'] ?? 'HOG-${h['hog_id']}').toString()).toSet();
      _selectedTargetType = 'ALL';
    });
  }

  void _cancelInvestmentFlow() {
    setState(() {
      _isInvesting = false;
      _selectedBatch = null;
      _amountController.clear();
      _parsedAmount = 0.0;
      _hasAttemptedSubmit = false;
      _selectedHogTags.clear();
      _currentBatchHogs.clear();
      _selectedTargetType = 'ALL';
    });
  }

  void _setTargetType(String type) {
    setState(() {
      _selectedTargetType = type;
      if (type == 'ALL') {
        _selectedHogTags = _currentBatchHogs.map((h) => (h['tag_number'] ?? 'HOG-${h['hog_id']}').toString()).toSet();
      } else if (type == 'FATTENING') {
        _selectedHogTags = _currentBatchHogs
            .where((h) => (h['pig_type'] ?? '').toString().toLowerCase().contains('fatten'))
            .map((h) => (h['tag_number'] ?? 'HOG-${h['hog_id']}').toString())
            .toSet();
      } else if (type == 'SOW') {
        _selectedHogTags = _currentBatchHogs
            .where((h) => (h['pig_type'] ?? '').toString().toLowerCase().contains('sow') ||
                          (h['pig_type'] ?? '').toString().toLowerCase().contains('breed'))
            .map((h) => (h['tag_number'] ?? 'HOG-${h['hog_id']}').toString())
            .toSet();
      }
    });
  }

  void _toggleHogTag(String tag) {
    setState(() {
      if (_selectedHogTags.contains(tag)) {
        if (_selectedHogTags.length > 1) {
          _selectedHogTags.remove(tag);
        } else {
          PiggyToast.showWarning(context, 'At least one hog must remain selected for allocation.');
        }
      } else {
        _selectedHogTags.add(tag);
      }

      final allTags = _currentBatchHogs.map((h) => (h['tag_number'] ?? 'HOG-${h['hog_id']}').toString()).toSet();
      final fatTags = _currentBatchHogs
          .where((h) => (h['pig_type'] ?? '').toString().toLowerCase().contains('fatten'))
          .map((h) => (h['tag_number'] ?? 'HOG-${h['hog_id']}').toString())
          .toSet();
      final sowTags = _currentBatchHogs
          .where((h) => (h['pig_type'] ?? '').toString().toLowerCase().contains('sow') ||
                        (h['pig_type'] ?? '').toString().toLowerCase().contains('breed'))
          .map((h) => (h['tag_number'] ?? 'HOG-${h['hog_id']}').toString())
          .toSet();

      if (_selectedHogTags.length == allTags.length) {
        _selectedTargetType = 'ALL';
      } else if (fatTags.isNotEmpty && _selectedHogTags.length == fatTags.length && _selectedHogTags.containsAll(fatTags)) {
        _selectedTargetType = 'FATTENING';
      } else if (sowTags.isNotEmpty && _selectedHogTags.length == sowTags.length && _selectedHogTags.containsAll(sowTags)) {
        _selectedTargetType = 'SOW';
      } else {
        _selectedTargetType = 'CUSTOM';
      }
    });
  }

  String _getAllocationSummaryText(bool isFilipino) {
    if (_selectedHogTags.isEmpty) {
      return isFilipino ? 'Pumili ng kahit isang baboy.' : 'Select at least one hog.';
    }
    final count = _selectedHogTags.length;
    final total = _currentBatchHogs.length;
    if (count == total) {
      return isFilipino
          ? 'Pinopondohan ang lahat ng $count baboy sa buong batch.'
          : 'Funding all $count hogs across this entire batch.';
    }
    if (_selectedTargetType == 'FATTENING') {
      return isFilipino
          ? 'Pinopondohan ang $count baboy na pang-katay.'
          : 'Funding $count selected Fattening hogs.';
    }
    if (_selectedTargetType == 'SOW') {
      return isFilipino
          ? 'Pinopondohan ang $count inahing baboy.'
          : 'Funding $count selected Sow / Breeding hogs.';
    }
    return isFilipino
        ? 'Pinopondohan ang $count piling baboy: ${_selectedHogTags.join(", ")}'
        : 'Funding $count selected hogs: ${_selectedHogTags.join(", ")}';
  }

  Widget _buildTargetTypeChip({
    required ScreenFit fit,
    required bool isDark,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(fit.dp(10)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: fit.dp(6), vertical: fit.dp(6)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : _brandColor)
              : (isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft),
          borderRadius: BorderRadius.circular(fit.dp(10)),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : _brandColor)
                : (isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fit.sp(10.5),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? _brandColor : Colors.white)
                      : (isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: fit.dp(4)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: fit.dp(4), vertical: fit.dp(1)),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? _brandColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.25))
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : _brandColor.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(fit.dp(6)),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fit.sp(9.0),
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? (isDark ? _brandColor : Colors.white)
                      : (isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHogSelectChip({
    required ScreenFit fit,
    required bool isDark,
    required String tag,
    required String typeLabel,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(fit.dp(8)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: fit.dp(7), vertical: fit.dp(3.5)),
        decoration: BoxDecoration(
          color: isSelected
              ? _brandAccent.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft),
          borderRadius: BorderRadius.circular(fit.dp(8)),
          border: Border.all(
            color: isSelected
                ? _brandAccent
                : (isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: fit.dp(11),
              color: isSelected
                  ? _brandAccent
                  : (isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted),
            ),
            SizedBox(width: fit.dp(4)),
            Text(
              tag,
              style: GoogleFonts.plusJakartaSans(
                fontSize: fit.sp(10.5),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : PiggyTrunkTheme.ptText)
                    : (isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted),
              ),
            ),
            SizedBox(width: fit.dp(3)),
            Text(
              '($typeLabel)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: fit.sp(9.0),
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? _brandAccent
                    : (isDark ? PiggyTrunkTheme.ptMutedDark.withValues(alpha: 0.7) : PiggyTrunkTheme.ptMuted.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmInvestment() async {
    if (_parsedAmount <= 0) {
      setState(() {
        _hasAttemptedSubmit = true;
      });
      PiggyToast.showWarning(
        context,
        'Please enter an investment amount greater than ₱0.00.',
      );
      return;
    }

    if (_selectedHogTags.isEmpty) {
      PiggyToast.showWarning(
        context,
        'Please select at least one hog to allocate your investment.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      int? partnerInvestorId;
      String partnerName = user?.userMetadata?['name'] ??
          user?.userMetadata?['full_name'] ??
          user?.email ??
          'Partner Investor';

      // 1. Resolve via Supabase authenticated user if present
      if (user != null) {
        try {
          final profile = await Supabase.instance.client
              .from('app_users')
              .select('user_id, name')
              .eq('supabase_user_id', user.id)
              .maybeSingle();

          if (profile != null && profile['name'] != null && profile['name'].toString().trim().isNotEmpty) {
            partnerName = profile['name'].toString().trim();
          }

          final appUserId = profile != null ? profile['user_id'] : null;

          if (appUserId != null) {
            final partnerRec = await Supabase.instance.client
                .from('partner_investors')
                .select('partner_investor_id')
                .eq('user_id', appUserId)
                .maybeSingle();

            if (partnerRec != null) {
              partnerInvestorId = partnerRec['partner_investor_id'] as int?;
            } else {
              final ins = await Supabase.instance.client
                  .from('partner_investors')
                  .insert({'user_id': appUserId})
                  .select('partner_investor_id')
                  .maybeSingle();
              if (ins != null) {
                partnerInvestorId = ins['partner_investor_id'] as int?;
              }
            }
          }
        } catch (e) {
          debugPrint('Notice resolving user partner: $e');
        }
      }

      // 2. Fallback: Resolve partner from saved email or current authenticated user
      if (partnerInvestorId == null) {
        try {
          final savedEmail = await AuthSessionService().getSavedEmail();
          final searchEmail = (savedEmail != null && savedEmail.isNotEmpty) ? savedEmail : (user?.email ?? '');

          if (searchEmail.isNotEmpty || user != null) {
            final profile = await Supabase.instance.client
                .from('app_users')
                .select('user_id, name')
                .or('email.eq.$searchEmail,supabase_user_id.eq.${user?.id ?? ""}')
                .maybeSingle();

            final appUserId = profile != null ? profile['user_id'] : null;
            if (profile != null && profile['name'] != null && profile['name'].toString().trim().isNotEmpty) {
              partnerName = profile['name'].toString().trim();
            }
            if (appUserId != null) {
              final partnerRec = await Supabase.instance.client
                  .from('partner_investors')
                  .select('partner_investor_id')
                  .eq('user_id', appUserId)
                  .maybeSingle();

              if (partnerRec != null) {
                partnerInvestorId = partnerRec['partner_investor_id'] as int?;
              } else {
                final ins = await Supabase.instance.client
                    .from('partner_investors')
                    .insert({'user_id': appUserId})
                    .select('partner_investor_id')
                    .maybeSingle();
                if (ins != null) {
                  partnerInvestorId = ins['partner_investor_id'] as int?;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Notice on partner resolution: $e');
        }
      }

      final rawBatchId = _selectedBatch?['batch_id'];
      final int batchId = rawBatchId is int
          ? rawBatchId
          : (int.tryParse(rawBatchId?.toString() ?? '') ?? 1);

      // 3. Ensure the batch exists in public.batches table so Foreign Key constraint succeeds!
      try {
        final existingBatch = await Supabase.instance.client
            .from('batches')
            .select('batch_id')
            .eq('batch_id', batchId)
            .maybeSingle();

        if (existingBatch == null) {
          final batchData = <String, dynamic>{
            'batch_id': batchId,
            'batch_name': _selectedBatch?['batch_name'] ?? 'Batch #$batchId',
            'date_created': DateTime.now().toIso8601String().split('T').first,
          };
          await Supabase.instance.client.from('batches').insert(batchData);
        }
      } catch (bErr) {
        debugPrint('Notice ensuring batch in DB: $bErr');
      }

      // 4. Insert into public.investments in Supabase
      bool dbInserted = false;
      try {
        await Supabase.instance.client.from('investments').insert({
          'partner_investor_id': partnerInvestorId,
          'batch_id': batchId,
          'amount': _parsedAmount,
          'status': 'active',
          'date_invested': DateTime.now().toIso8601String().split('T').first,
        });
        dbInserted = true;
        debugPrint('Investment successfully inserted into Supabase investments table!');
      } catch (insErr) {
        debugPrint('Notice: Supabase investment insert (check RLS policies): $insErr');
      }

      // 5. Always dispatch notifications to Admin, Raiser, and Partner
      // (Decoupled so Admin Web notification arrives even if investments RLS is pending)
      try {
        final batchName = _selectedBatch?['batch_name'] ?? 'Batch #$batchId';
        final formattedAmt = _formatCurrency(_parsedAmount);

        final int count = _selectedHogTags.length;
        final int total = _currentBatchHogs.length;
        String targetPigType = 'Entire Batch';
        if (_selectedTargetType == 'FATTENING') {
          targetPigType = 'Fattening';
        } else if (_selectedTargetType == 'SOW') {
          targetPigType = 'Sow / Breeding';
        } else if (count < total) {
          targetPigType = 'Selected Hogs';
        } else {
          targetPigType = (_selectedBatch?['hog_type'] ?? _selectedBatch?['pig_type'] ?? 'Fattening').toString();
        }
        final List<String> tagsList = _selectedHogTags.toList()..sort();
        final String tagsStr = tagsList.join(', ');

        // A. Notify Admin Portal
        try {
          await Supabase.instance.client.from('admin_notifications').insert({
            'title': 'New Partner Investment',
            'message': '$partnerName invested ₱$formattedAmt for $targetPigType ($tagsStr) in $batchName.',
            'type': 'investment',
            'is_read': false,
            'metadata': {
              'partner_investor_id': partnerInvestorId,
              'partner_name': partnerName,
              'batch_id': batchId,
              'batch_name': batchName,
              'amount': _parsedAmount,
              'target_pig_type': targetPigType,
              'target_hog_tags': tagsList,
              'selected_hogs_count': count,
            },
          });
          debugPrint('Successfully dispatched new investment notification to admin_notifications table!');
        } catch (adminErr) {
          debugPrint('Notice dispatching admin notification: $adminErr');
        }

        // B. Notify Assigned Hog Raiser
        int? rId;
        final rawRaiserId = _selectedBatch?['hog_raiser_id'];
        if (rawRaiserId is int) {
          rId = rawRaiserId;
        } else if (rawRaiserId != null) {
          rId = int.tryParse(rawRaiserId.toString());
        }

        // Fallback 1: Query assignments table by batch_id if rId is null
        if (rId == null) {
          try {
            final assignData = await Supabase.instance.client
                .from('assignments')
                .select('hog_raiser_id')
                .eq('batch_id', batchId)
                .maybeSingle();
            if (assignData != null && assignData['hog_raiser_id'] != null) {
              rId = int.tryParse(assignData['hog_raiser_id'].toString());
            }
          } catch (e) {
            debugPrint('Notice resolving raiser ID from assignments: $e');
          }
        }

        // Fallback 2: Query hog_raisers table by assigned_raiser name
        if (rId == null) {
          final raiserNameStr = (_selectedBatch?['assigned_raiser'] ??
                  _selectedBatch?['raiser_name'] ??
                  '')
              .toString()
              .trim();
          if (raiserNameStr.isNotEmpty &&
              !raiserNameStr.toLowerCase().contains('unassigned') &&
              !raiserNameStr.toLowerCase().contains('livestock')) {
            try {
              final raiserRow = await Supabase.instance.client
                  .from('hog_raisers')
                  .select('hog_raiser_id')
                  .ilike('name', '%$raiserNameStr%')
                  .limit(1)
                  .maybeSingle();
              if (raiserRow != null && raiserRow['hog_raiser_id'] != null) {
                rId = int.tryParse(raiserRow['hog_raiser_id'].toString());
              }
            } catch (e) {
              debugPrint('Notice resolving raiser ID from hog_raisers by name: $e');
            }
          }
        }

        if (rId != null) {
          try {
            await Supabase.instance.client.from('raiser_notifications').insert({
              'hog_raiser_id': rId,
              'title': 'New Investment in Your Batch!',
              'message': '$partnerName invested ₱$formattedAmt for $targetPigType ($tagsStr) in $batchName.',
              'type': 'investment',
              'is_read': false,
              'metadata': {
                'batch_id': batchId,
                'batch_name': batchName,
                'amount': _parsedAmount,
                'partner_name': partnerName,
                'partner_investor_id': partnerInvestorId,
                'target_pig_type': targetPigType,
                'target_hog_tags': tagsList,
                'selected_hogs_count': count,
              },
            });
            debugPrint('Successfully dispatched raiser notification to raiser ID: $rId');
          } catch (rNotifErr) {
            debugPrint('Notice dispatching raiser notification: $rNotifErr');
          }
        }

        // C. Notify Partner Investor
        if (partnerInvestorId != null) {
          try {
            await Supabase.instance.client.from('partner_notifications').insert({
              'partner_investor_id': partnerInvestorId,
              'title': 'Investment Confirmed',
              'message': 'You have successfully funded ₱$formattedAmt for $targetPigType ($tagsStr) in $batchName.',
              'type': 'investment',
              'is_read': false,
            });
          } catch (pNotifErr) {
            debugPrint('Notice dispatching partner notification: $pNotifErr');
          }
        }
      } catch (notifErr) {
        debugPrint('Notice dispatching investment notifications: $notifErr');
      }

      // 6. Only persist to local session cache as offline fallback if DB insert failed!
      if (!dbInserted) {
        try {
          final List<String> tagsList = _selectedHogTags.toList()..sort();
          final int count = _selectedHogTags.length;
          final int total = _currentBatchHogs.length;
          String targetPigType = 'Entire Batch';
          if (_selectedTargetType == 'FATTENING') {
            targetPigType = 'Fattening';
          } else if (_selectedTargetType == 'SOW') {
            targetPigType = 'Sow / Breeding';
          } else if (count < total) {
            targetPigType = 'Selected Hogs';
          } else {
            targetPigType = (_selectedBatch?['hog_type'] ?? _selectedBatch?['pig_type'] ?? 'Fattening').toString();
          }

          final localInv = {
            'investment_id': 'local_${DateTime.now().millisecondsSinceEpoch}',
            'amount': _parsedAmount,
            'invested_amount': _parsedAmount,
            'date_invested': DateTime.now().toIso8601String().split('T').first,
            'created_at': DateTime.now().toIso8601String(),
            'status': 'active',
            'batch_id': batchId,
            'partner_investor_id': partnerInvestorId,
            'target_pig_type': targetPigType,
            'target_hog_tags': tagsList,
            'selected_hogs_count': count,
            ...(_selectedBatch ?? {}),
          };
          await AuthSessionService().saveLocalInvestment(localInv);
        } catch (localErr) {
          debugPrint('Notice saving local investment: $localErr');
        }
      }

      if (!mounted) return;

      PiggyToast.showSuccess(
        context,
        dbInserted
            ? 'Investment of ₱${_formatCurrency(_parsedAmount)} confirmed & synced to server!'
            : 'Investment of ₱${_formatCurrency(_parsedAmount)} confirmed in your portfolio!',
      );

      await widget.onRefresh();

      setState(() {
        _isInvesting = false;
        _selectedBatch = null;
        _amountController.clear();
        _parsedAmount = 0.0;
        _selectedHogTags.clear();
        _currentBatchHogs.clear();
        _selectedTargetType = 'ALL';
      });
    } catch (e) {
      debugPrint('Error confirming investment: $e');
      if (mounted) {
        PiggyToast.showError(
          context,
          'Notice: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fit = ScreenFit(context);
    final strings = AppStrings.of(context);
    final double paddingH = fit.dp(20.0);
    final double paddingV = fit.dp(16.0);
    final double titleFontSize = fit.sp(24.0);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : _brandColor;
    final mutedTextColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final cardBgColor = isDark ? const Color(0xff151f2e) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xff28354a) : const Color(0xffe6ebf2);
    final statsBoxBg = isDark ? const Color(0xff1b2638) : const Color(0xfff8fafc);
    final statsBoxBorder = isDark ? const Color(0xff28354a) : const Color(0xffe6ebf2);

    final batchesList = widget.projectsList;
    final int openBatchesCount = batchesList.length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: isDark ? Colors.white : _brandColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(paddingH, paddingV, paddingH, fit.dp(108)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header shown only during active investment flow with back button
            if (_isInvesting) ...[
              Row(
                children: [
                  GestureDetector(
                    onTap: _cancelInvestmentFlow,
                    child: Container(
                      padding: EdgeInsets.all(fit.dp(8)),
                      margin: EdgeInsets.only(right: fit.dp(10)),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: cardBorderColor, width: 1),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: primaryTextColor,
                        size: fit.dp(20),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.fundBatch,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: fit.dp(3)),
                      Text(
                        strings.isFilipino
                            ? 'Piliin ang halagang ipupuhunan sa batch na ito'
                            : 'Select amount to allocate for this hog batch',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(12.5),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: fit.dp(10.0)),
            ],

            // View 1: Active Investment Form
            if (_isInvesting) ...[
              // 1. Compact Batch Header Pill
              if (_selectedBatch != null) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: fit.dp(14), vertical: fit.dp(10)),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131F33) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(fit.dp(14)),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFBBF7D0),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(fit.dp(8)),
                        decoration: BoxDecoration(
                          color: _brandAccent.withValues(alpha: isDark ? 0.25 : 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: _brandAccent,
                          size: fit.dp(18),
                        ),
                      ),
                      SizedBox(width: fit.dp(10)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedBatch?['batch_name'] ?? _selectedBatch?['title'] ?? 'Batch Project',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: fit.sp(14.0),
                                      fontWeight: FontWeight.w800,
                                      color: primaryTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: fit.dp(7), vertical: fit.dp(2.5)),
                                  decoration: BoxDecoration(
                                    color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                                    borderRadius: BorderRadius.circular(fit.dp(6)),
                                    border: Border.all(
                                      color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    _selectedBatch?['hog_type'] ?? _selectedBatch?['pig_type'] ?? 'Fattening',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: fit.sp(9.5),
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: fit.dp(2)),
                            Text(
                              'Raiser: ${_selectedBatch?['assigned_raiser'] ?? _selectedBatch?['raiser_name'] ?? "Assigned Raiser"}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: fit.sp(11.5),
                                fontWeight: FontWeight.w600,
                                color: mutedTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: fit.dp(10.0)),
              ],

              // 2. Unified Investment & Allocation Card
              Builder(
                builder: (context) {
                  final bool isInvalid = _hasAttemptedSubmit || (_amountController.text.isNotEmpty && _parsedAmount <= 0);
                  final bool hasFattening = _currentBatchHogs.any((h) => (h['pig_type'] ?? '').toString().toLowerCase().contains('fatten'));
                  final bool hasSow = _currentBatchHogs.any((h) => (h['pig_type'] ?? '').toString().toLowerCase().contains('sow') ||
                                                                   (h['pig_type'] ?? '').toString().toLowerCase().contains('breed'));

                  return Container(
                    margin: EdgeInsets.only(bottom: fit.dp(14)),
                    padding: EdgeInsets.all(fit.dp(14)),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(fit.dp(16)),
                      border: Border.all(color: cardBorderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Target allocation header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              strings.isFilipino ? 'PILIIN ANG IPUPUHUNAN' : 'ALLOCATION TARGET',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: fit.sp(10.5),
                                fontWeight: FontWeight.w800,
                                color: mutedTextColor,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: fit.dp(7), vertical: fit.dp(2.5)),
                              decoration: BoxDecoration(
                                color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                                borderRadius: BorderRadius.circular(fit.dp(6)),
                                border: Border.all(
                                  color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${_selectedHogTags.length}/${_currentBatchHogs.length} Hogs',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(10.0),
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: fit.dp(8)),

                        // Category Chips Row (Single row, responsive)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTargetTypeChip(
                                fit: fit,
                                isDark: isDark,
                                label: strings.isFilipino ? 'Lahat' : 'All Hogs',
                                count: _currentBatchHogs.length,
                                isSelected: _selectedTargetType == 'ALL',
                                onTap: () => _setTargetType('ALL'),
                              ),
                            ),
                            if (hasFattening) ...[
                              SizedBox(width: fit.dp(6)),
                              Expanded(
                                child: _buildTargetTypeChip(
                                  fit: fit,
                                  isDark: isDark,
                                  label: strings.isFilipino ? 'Pang-katay' : 'Fattening',
                                  count: _currentBatchHogs.where((h) => (h['pig_type'] ?? '').toString().toLowerCase().contains('fatten')).length,
                                  isSelected: _selectedTargetType == 'FATTENING',
                                  onTap: () => _setTargetType('FATTENING'),
                                ),
                              ),
                            ],
                            if (hasSow) ...[
                              SizedBox(width: fit.dp(6)),
                              Expanded(
                                child: _buildTargetTypeChip(
                                  fit: fit,
                                  isDark: isDark,
                                  label: strings.isFilipino ? 'Inahin' : 'Sow / Breed',
                                  count: _currentBatchHogs.where((h) => (h['pig_type'] ?? '').toString().toLowerCase().contains('sow') ||
                                                                       (h['pig_type'] ?? '').toString().toLowerCase().contains('breed')).length,
                                  isSelected: _selectedTargetType == 'SOW',
                                  onTap: () => _setTargetType('SOW'),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: fit.dp(10)),

                        // Specific Hogs In Allocation label
                        Text(
                          strings.isFilipino ? 'MGA TIYAK NA BABOY SA ALLOCATION:' : 'SPECIFIC HOGS IN ALLOCATION:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(10.0),
                            fontWeight: FontWeight.w700,
                            color: mutedTextColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: fit.dp(6)),

                        // Individual Hog Chips
                        Wrap(
                          spacing: fit.dp(5),
                          runSpacing: fit.dp(5),
                          children: _currentBatchHogs.map((hog) {
                            final tag = (hog['tag_number'] ?? 'HOG-${hog['hog_id']}').toString();
                            final isSelected = _selectedHogTags.contains(tag);
                            final pType = (hog['pig_type'] ?? 'Fattening').toString();
                            final isSow = pType.toLowerCase().contains('sow') || pType.toLowerCase().contains('breed');
                            return _buildHogSelectChip(
                              fit: fit,
                              isDark: isDark,
                              tag: tag,
                              typeLabel: isSow ? (strings.isFilipino ? 'Inahin' : 'Sow') : (strings.isFilipino ? 'Katay' : 'Fat'),
                              isSelected: isSelected,
                              onTap: () => _toggleHogTag(tag),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: fit.dp(8)),
                        Text(
                          _getAllocationSummaryText(strings.isFilipino),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(11.0),
                            fontWeight: FontWeight.w600,
                            color: _brandAccent,
                          ),
                        ),

                        // Section Divider
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: fit.dp(10)),
                          child: Divider(color: cardBorderColor, height: 1, thickness: 1),
                        ),

                        // Investment Amount Label
                        Text(
                          strings.isFilipino ? 'HALAGA NG PUHUNAN (PHP)' : 'INVESTMENT AMOUNT (PHP)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(10.5),
                            fontWeight: FontWeight.w800,
                            color: mutedTextColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: fit.dp(8)),

                        // Amount Input TextField with Validation Border
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(20.0),
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isInvalid
                                ? (isDark ? const Color(0xFF2D181A) : const Color(0xFFFFF1F2))
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: fit.dp(14), right: fit.dp(8)),
                              child: Text(
                                '₱',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(20.0),
                                  fontWeight: FontWeight.w800,
                                  color: isInvalid ? PiggyTrunkTheme.ptAccent : _brandAccent,
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            hintText: '0.00',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: fit.sp(20.0),
                              fontWeight: FontWeight.w600,
                              color: mutedTextColor.withValues(alpha: 0.4),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: fit.dp(14), vertical: fit.dp(12)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(fit.dp(12)),
                              borderSide: isInvalid
                                  ? BorderSide(color: PiggyTrunkTheme.ptAccent, width: 1.5)
                                  : BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(fit.dp(12)),
                              borderSide: isInvalid
                                  ? BorderSide(color: PiggyTrunkTheme.ptAccent, width: 1.5)
                                  : BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(fit.dp(12)),
                              borderSide: BorderSide(
                                color: isInvalid ? PiggyTrunkTheme.ptAccent : const Color(0xFF10B981),
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),

                        // Inline validation error or per-hog allocation calculation
                        if (isInvalid) ...[
                          Padding(
                            padding: EdgeInsets.only(top: fit.dp(6)),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, size: fit.dp(13), color: PiggyTrunkTheme.ptAccent),
                                SizedBox(width: fit.dp(4)),
                                Text(
                                  strings.isFilipino
                                      ? 'Kailangang mas mataas sa ₱0.00 ang halaga'
                                      : 'Investment amount must be greater than ₱0.00',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(11.0),
                                    fontWeight: FontWeight.w600,
                                    color: PiggyTrunkTheme.ptAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_parsedAmount > 0 && _selectedHogTags.isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.only(top: fit.dp(6)),
                            child: Text(
                              '≈ ₱${_formatCurrency(_parsedAmount / _selectedHogTags.length)} per selected hog (${_selectedHogTags.length} hogs)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: fit.sp(11.0),
                                fontWeight: FontWeight.w700,
                                color: _brandAccent,
                              ),
                            ),
                          ),
                        ],

                        // Quick Preset Amount Chips
                        SizedBox(height: fit.dp(10)),
                        Row(
                          children: [1000.0, 5000.0, 10000.0, 20000.0].map((preset) {
                            final isPresetSelected = (_parsedAmount == preset);
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: fit.dp(2)),
                                child: InkWell(
                                  onTap: () => _setPresetAmount(preset),
                                  borderRadius: BorderRadius.circular(fit.dp(8)),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: fit.dp(6)),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isPresetSelected
                                          ? _brandAccent.withValues(alpha: isDark ? 0.3 : 0.15)
                                          : (isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft),
                                      borderRadius: BorderRadius.circular(fit.dp(8)),
                                      border: Border.all(
                                        color: isPresetSelected
                                            ? _brandAccent
                                            : (isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder),
                                        width: isPresetSelected ? 1.2 : 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      '₱${preset >= 1000 ? "${(preset / 1000).toInt()}k" : preset.toInt()}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: fit.sp(10.5),
                                        fontWeight: isPresetSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isPresetSelected
                                            ? _brandAccent
                                            : (isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        // Section Divider before total
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: fit.dp(10)),
                          child: Divider(color: cardBorderColor, height: 1, thickness: 1),
                        ),

                        // Integrated Total Invest Amount Row
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: fit.dp(12), vertical: fit.dp(9)),
                          decoration: BoxDecoration(
                            color: statsBoxBg,
                            borderRadius: BorderRadius.circular(fit.dp(10)),
                            border: Border.all(color: statsBoxBorder, width: 1.0),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                strings.isFilipino ? 'Kabuuang Halaga' : 'Total Investment',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(12.0),
                                  fontWeight: FontWeight.w700,
                                  color: mutedTextColor,
                                ),
                              ),
                              Text(
                                '₱${_formatCurrency(_parsedAmount)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(16.0),
                                  fontWeight: FontWeight.w800,
                                  color: _parsedAmount > 0 ? _brandAccent : primaryTextColor,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelInvestmentFlow,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cardBorderColor, width: 1.2),
                        padding: EdgeInsets.symmetric(vertical: fit.dp(12)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(fit.dp(12)),
                        ),
                      ),
                      child: Text(
                        strings.cancel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(13.0),
                          fontWeight: FontWeight.w700,
                          color: mutedTextColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: fit.dp(10)),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              if (_parsedAmount <= 0) {
                                setState(() {
                                  _hasAttemptedSubmit = true;
                                });
                                PiggyToast.showWarning(
                                  context,
                                  strings.isFilipino
                                      ? 'Kailangang mas mataas sa ₱0.00 ang puhunan.'
                                      : 'Please enter an investment amount greater than ₱0.00.',
                                );
                                return;
                              }
                              _confirmInvestment();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _parsedAmount > 0
                            ? _brandColor
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                        foregroundColor: _parsedAmount > 0
                            ? Colors.white
                            : (isDark ? Colors.white38 : Colors.black38),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: fit.dp(12)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(fit.dp(12)),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.0,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  strings.isFilipino ? 'Kumpirmahin ang Puhunan' : 'Confirm Investment',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(13.5),
                                    fontWeight: FontWeight.w800,
                                    color: _parsedAmount > 0
                                        ? Colors.white
                                        : (isDark ? Colors.white38 : Colors.black38),
                                  ),
                                ),
                                SizedBox(width: fit.dp(6)),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: fit.dp(16),
                                  color: _parsedAmount > 0
                                      ? Colors.white
                                      : (isDark ? Colors.white38 : Colors.black38),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // ==================== SUB-TAB SELECTOR (MY INVESTMENTS vs EXPLORE BATCHES) ====================
              if (widget.fundedProjectsList.isNotEmpty) ...[
                Container(
                  margin: EdgeInsets.only(bottom: fit.dp(16)),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(fit.dp(14)),
                    border: Border.all(color: cardBorderColor, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedSubTab = 0),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: fit.dp(9)),
                            decoration: BoxDecoration(
                              color: _selectedSubTab == 0
                                  ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(fit.dp(10)),
                              boxShadow: _selectedSubTab == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: fit.dp(15),
                                  color: _selectedSubTab == 0 ? _brandAccent : mutedTextColor,
                                ),
                                SizedBox(width: fit.dp(6)),
                                Text(
                                  strings.isFilipino
                                      ? 'Aking Puhunan (${widget.fundedProjectsList.length})'
                                      : 'My Investments (${widget.fundedProjectsList.length})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(12.0),
                                    fontWeight: _selectedSubTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                    color: _selectedSubTab == 0 ? primaryTextColor : mutedTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedSubTab = 1),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: fit.dp(9)),
                            decoration: BoxDecoration(
                              color: _selectedSubTab == 1
                                  ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(fit.dp(10)),
                              boxShadow: _selectedSubTab == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.explore_outlined,
                                  size: fit.dp(15),
                                  color: _selectedSubTab == 1 ? (isDark ? Colors.white : _brandColor) : mutedTextColor,
                                ),
                                SizedBox(width: fit.dp(6)),
                                Text(
                                  strings.isFilipino
                                      ? 'Mag-browse (${batchesList.length})'
                                      : 'Explore Batches (${batchesList.length})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(12.0),
                                    fontWeight: _selectedSubTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                    color: _selectedSubTab == 1 ? primaryTextColor : mutedTextColor,
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
              ],

              // ==================== SUB-TAB 0: MY FUNDED BATCHES ====================
              if (widget.fundedProjectsList.isNotEmpty && _selectedSubTab == 0) ...[
                if (widget.fundedProjectsList.length == 1)
                  _buildSoloFundedBatchView(
                    fit,
                    strings,
                    widget.fundedProjectsList.first,
                    isDark,
                    primaryTextColor,
                    mutedTextColor,
                    cardBgColor,
                    cardBorderColor,
                    statsBoxBg,
                    statsBoxBorder,
                    batchesList,
                  )
                else
                  _buildMultipleFundedBatchesView(
                    fit,
                    strings,
                    widget.fundedProjectsList,
                    isDark,
                    primaryTextColor,
                    mutedTextColor,
                    cardBgColor,
                    cardBorderColor,
                    statsBoxBg,
                    statsBoxBorder,
                    batchesList,
                  ),
              ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    strings.investmentOpportunities,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: fit.sp(16.5),
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: fit.dp(10), vertical: fit.dp(4)),
                    decoration: BoxDecoration(
                      color: _brandAccent.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(fit.dp(12)),
                    ),
                    child: Text(
                      openBatchesCount == 1
                          ? (strings.isFilipino ? '1 BUKAS NA BATCH' : '1 BATCH OPEN')
                          : (strings.isFilipino ? '$openBatchesCount BUKAS NA BATCH' : '$openBatchesCount BATCHES OPEN'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(11.0),
                        fontWeight: FontWeight.w800,
                        color: _brandAccent,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: fit.dp(14.0)),

              if (batchesList.isEmpty)
                // Modern Empty State Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: fit.dp(24), vertical: fit.dp(36)),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(fit.dp(24)),
                    border: Border.all(color: cardBorderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(fit.dp(20)),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : _brandColor.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: fit.dp(44),
                          color: isDark ? Colors.white : _brandColor,
                        ),
                      ),
                      SizedBox(height: fit.dp(16)),
                      Text(
                        'No Active Batches Available',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(17.0),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: fit.dp(6)),
                      Text(
                        'There are currently no open batches available for investment. Please check back later or refresh.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(12.5),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: fit.dp(20)),
                      ElevatedButton.icon(
                        onPressed: widget.onRefresh,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(horizontal: fit.dp(20), vertical: fit.dp(12)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(fit.dp(14)),
                          ),
                        ),
                        icon: Icon(Icons.refresh_rounded, size: fit.dp(18), color: Colors.white),
                        label: Text(
                          'Refresh Batches',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: fit.sp(13.0),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...batchesList.map((batch) {
                  final String batchName = batch['batch_name'] ?? batch['title'] ?? 'Batch Project';
                  final String rawHogType = (batch['hog_type'] ?? batch['pig_type'] ?? 'Fattening').toString().trim();
                  final String hogType = (rawHogType.isEmpty || rawHogType.toUpperCase() == 'N/A') ? 'Fattening' : rawHogType;
                  final String raiserName = batch['assigned_raiser'] ?? batch['raiser_name'] ?? 'Assigned Hog Raiser';
                  final int totalRaisers = (batch['total_raisers'] as num?)?.toInt() ?? 1;
                  final int totalHogs = (batch['total_hogs'] as num?)?.toInt() ?? 0;

                  return Container(
                    margin: EdgeInsets.only(bottom: fit.dp(16)),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(fit.dp(22)),
                      border: Border.all(color: cardBorderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Batch Card Header: Pig Type Badge
                        Padding(
                          padding: EdgeInsets.fromLTRB(fit.dp(16), fit.dp(16), fit.dp(16), 0),
                          child: Wrap(
                            spacing: fit.dp(8),
                            runSpacing: fit.dp(6),
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // 1. Hog Type Badge (e.g. Fattening)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: fit.dp(10), vertical: fit.dp(4.5)),
                                decoration: BoxDecoration(
                                  color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                                  borderRadius: BorderRadius.circular(fit.dp(20)),
                                  border: Border.all(
                                    color: isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  hogType,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(11.0),
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Batch Title & Assigned Raiser
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: fit.dp(16), vertical: fit.dp(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                batchName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: fit.sp(18.0),
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: fit.dp(4)),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: fit.dp(14),
                                    color: mutedTextColor,
                                  ),
                                  SizedBox(width: fit.dp(4)),
                                  Text(
                                    'Assigned Raiser: $raiserName',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: fit.sp(12.5),
                                      fontWeight: FontWeight.w600,
                                      color: mutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 3-Column Positive Investment Metrics Grid
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: fit.dp(18)),
                          padding: EdgeInsets.symmetric(vertical: fit.dp(12), horizontal: fit.dp(10)),
                          decoration: BoxDecoration(
                            color: statsBoxBg,
                            borderRadius: BorderRadius.circular(fit.dp(14)),
                            border: Border.all(color: statsBoxBorder, width: 1),
                          ),
                          child: Row(
                            children: [
                              _buildMetricColumn(fit, 'RAISERS', '$totalRaisers', primaryTextColor, isDark),
                              Container(height: fit.dp(26), width: 1, color: statsBoxBorder),
                              _buildMetricColumn(fit, 'TOTAL HOGS', '$totalHogs', primaryTextColor, isDark),
                              Container(height: fit.dp(26), width: 1, color: statsBoxBorder),
                              _buildMetricColumn(
                                fit,
                                'HEALTH STATUS',
                                'Healthy',
                                const Color(0xFF10B981),
                                isDark,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: fit.dp(14)),

                        // Dual Action Buttons: [ View Raiser Info ] & [ Invest Now ]
                        Padding(
                          padding: EdgeInsets.fromLTRB(fit.dp(18), 0, fit.dp(18), fit.dp(16)),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: fit.dp(44),
                                  child: OutlinedButton.icon(
                                    onPressed: () => showBatchRaiserDetailsDrawer(
                                      context: context,
                                      batch: batch,
                                      onInvestNow: () => _startInvestmentFlow(batch),
                                      onViewLifecycle: widget.onNavigateToLifecycle,
                                      onViewActivities: widget.onNavigateToActivities,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: cardBorderColor, width: 1.2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(fit.dp(14)),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: fit.dp(8)),
                                    ),
                                    icon: Icon(
                                      Icons.person_search_rounded,
                                      size: fit.dp(16),
                                      color: primaryTextColor,
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        strings.isFilipino ? 'Impormasyon' : 'Raiser Info',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: fit.sp(12.5),
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: fit.dp(10)),
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: fit.dp(44),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _startInvestmentFlow(batch),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark ? Colors.white : _brandColor,
                                      foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(fit.dp(14)),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: fit.dp(12)),
                                    ),
                                    icon: Icon(
                                      Icons.add_card_rounded,
                                      size: fit.dp(17),
                                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        strings.investNow,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: fit.sp(13.0),
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ==================== SOLO FUNDED BATCH VIEW ====================
  Widget _buildSoloFundedBatchView(
    ScreenFit fit,
    AppStrings strings,
    Map<String, dynamic> singleBatch,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color cardBorderColor,
    Color statsBoxBg,
    Color statsBoxBorder,
    List<Map<String, dynamic>> batchesList,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strings.isFilipino ? 'Iyong Pinondohang Batch' : 'Your Funded Batch',
              style: GoogleFonts.plusJakartaSans(
                fontSize: fit.sp(16.5),
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: fit.dp(10), vertical: fit.dp(4)),
              decoration: BoxDecoration(
                color: _brandAccent.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(fit.dp(12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: fit.dp(6),
                    height: fit.dp(6),
                    decoration: const BoxDecoration(
                      color: _brandAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: fit.dp(5)),
                  Text(
                    '1 ACTIVE BATCH',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: fit.sp(10.5),
                      fontWeight: FontWeight.w800,
                      color: _brandAccent,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: fit.dp(14)),
        _buildFundedBatchCard(
          context: context,
          fit: fit,
          strings: strings,
          batch: singleBatch,
          isDark: isDark,
          primaryTextColor: primaryTextColor,
          mutedTextColor: mutedTextColor,
          cardBgColor: cardBgColor,
          cardBorderColor: cardBorderColor,
          statsBoxBg: statsBoxBg,
          statsBoxBorder: statsBoxBorder,
        ),
        if (batchesList.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: fit.dp(16), vertical: fit.dp(14)),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131F33) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(fit.dp(16)),
              border: Border.all(color: cardBorderColor, width: 1.0),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(fit.dp(8)),
                  decoration: BoxDecoration(
                    color: _brandColor.withValues(alpha: isDark ? 0.35 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.explore_outlined, size: fit.dp(18), color: isDark ? Colors.white : _brandColor),
                ),
                SizedBox(width: fit.dp(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.isFilipino ? 'Gusto pang mag-invest sa ibang batch?' : 'Expand your farm portfolio?',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(12.5),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      SizedBox(height: fit.dp(2)),
                      Text(
                        strings.isFilipino
                            ? 'May ${batchesList.length} bukas na batch para sa investment.'
                            : '${batchesList.length} open batches available to fund.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(11.0),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedSubTab = 1),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: fit.dp(10), vertical: fit.dp(6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.isFilipino ? 'Tingnan' : 'Browse',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(12.5),
                          fontWeight: FontWeight.w800,
                          color: _brandAccent,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: fit.dp(16), color: _brandAccent),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ==================== MULTIPLE FUNDED BATCHES VIEW ====================
  Widget _buildMultipleFundedBatchesView(
    ScreenFit fit,
    AppStrings strings,
    List<Map<String, dynamic>> fundedBatches,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color cardBorderColor,
    Color statsBoxBg,
    Color statsBoxBorder,
    List<Map<String, dynamic>> batchesList,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strings.isFilipino ? 'Aking mga Pinondohang Batch' : 'Your Funded Batches',
              style: GoogleFonts.plusJakartaSans(
                fontSize: fit.sp(16.5),
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: fit.dp(10), vertical: fit.dp(4)),
              decoration: BoxDecoration(
                color: _brandAccent.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(fit.dp(12)),
              ),
              child: Text(
                '${fundedBatches.length} BATCHES',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fit.sp(10.5),
                  fontWeight: FontWeight.w800,
                  color: _brandAccent,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: fit.dp(14)),
        ...fundedBatches.map(
          (batch) => _buildFundedBatchCard(
            context: context,
            fit: fit,
            strings: strings,
            batch: batch,
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            mutedTextColor: mutedTextColor,
            cardBgColor: cardBgColor,
            cardBorderColor: cardBorderColor,
            statsBoxBg: statsBoxBg,
            statsBoxBorder: statsBoxBorder,
          ),
        ),
        if (batchesList.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: fit.dp(16), vertical: fit.dp(14)),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131F33) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(fit.dp(16)),
              border: Border.all(color: cardBorderColor, width: 1.0),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(fit.dp(8)),
                  decoration: BoxDecoration(
                    color: _brandColor.withValues(alpha: isDark ? 0.35 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.explore_outlined, size: fit.dp(18), color: isDark ? Colors.white : _brandColor),
                ),
                SizedBox(width: fit.dp(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.isFilipino ? 'Gusto pang mag-invest sa ibang batch?' : 'Expand your farm portfolio?',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(12.5),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      SizedBox(height: fit.dp(2)),
                      Text(
                        strings.isFilipino
                            ? 'May ${batchesList.length} bukas na batch para sa investment.'
                            : '${batchesList.length} open batches available to fund.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(11.0),
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedSubTab = 1),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: fit.dp(10), vertical: fit.dp(6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.isFilipino ? 'Tingnan' : 'Browse',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(12.5),
                          fontWeight: FontWeight.w800,
                          color: _brandAccent,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: fit.dp(16), color: _brandAccent),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ==================== FUNDED BATCH CARD COMPONENT ====================
  Widget _buildFundedBatchCard({
    required BuildContext context,
    required ScreenFit fit,
    required AppStrings strings,
    required Map<String, dynamic> batch,
    required bool isDark,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required Color cardBgColor,
    required Color cardBorderColor,
    required Color statsBoxBg,
    required Color statsBoxBorder,
  }) {
    final String batchName = batch['batch_name'] ?? batch['title'] ?? 'Batch Project';
    final String rawHogType = (batch['hog_type'] ?? batch['pig_type'] ?? 'Fattening').toString().trim();
    final String hogType = (rawHogType.isEmpty || rawHogType.toUpperCase() == 'N/A') ? 'Fattening' : rawHogType;
    final String raiserName = (batch['assigned_raiser'] ?? batch['raiser_name'] ?? 'Assigned Hog Raiser').toString();
    final String raiserLocation = (batch['address'] ?? batch['location'] ?? '').toString();
    final double capital = (batch['amount'] as num?)?.toDouble() ??
        (batch['invested_amount'] as num?)?.toDouble() ??
        widget.investedAmount;
    final List<String> targetTags = (batch['target_hog_tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final String targetPigType = (batch['target_pig_type'] ?? '').toString();
    final int totalHogs = (batch['total_hogs'] as num?)?.toInt() ?? ((batch['hogs'] as List?)?.length ?? 6);
    final String stage = (batch['stage'] ?? batch['lifecycle_stage'] ?? 'Finisher').toString();

    return Container(
      margin: EdgeInsets.only(bottom: fit.dp(16)),
      padding: EdgeInsets.all(fit.dp(16)),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(fit.dp(22)),
        border: Border.all(color: cardBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon + Batch Name & Raiser + Pig Type Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(fit.dp(10)),
                decoration: BoxDecoration(
                  color: _brandAccent.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(fit.dp(12)),
                  border: Border.all(
                    color: _brandAccent.withValues(alpha: isDark ? 0.4 : 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.pets_rounded,
                  size: fit.dp(20),
                  color: _brandAccent,
                ),
              ),
              SizedBox(width: fit.dp(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batchName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(16.0),
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: fit.dp(2)),
                    Text(
                      'Raiser: $raiserName',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(12.0),
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (raiserLocation.isNotEmpty && raiserLocation != 'null') ...[
                      SizedBox(height: fit.dp(2)),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: fit.dp(11), color: mutedTextColor),
                          SizedBox(width: fit.dp(2)),
                          Expanded(
                            child: Text(
                              raiserLocation,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: fit.sp(11.0),
                                fontWeight: FontWeight.w500,
                                color: mutedTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: fit.dp(9), vertical: fit.dp(4)),
                decoration: BoxDecoration(
                  color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                  borderRadius: BorderRadius.circular(fit.dp(12)),
                  border: Border.all(color: cardBorderColor, width: 0.8),
                ),
                child: Text(
                  hogType,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fit.sp(10.5),
                    fontWeight: FontWeight.w700,
                    color: isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: fit.dp(14)),

          // Row 2: Metrics Box (Capital, Hogs, Stage)
          Container(
            padding: EdgeInsets.symmetric(horizontal: fit.dp(12), vertical: fit.dp(12)),
            decoration: BoxDecoration(
              color: statsBoxBg,
              borderRadius: BorderRadius.circular(fit.dp(14)),
              border: Border.all(color: statsBoxBorder, width: 1),
            ),
            child: Row(
              children: [
                _buildMetricColumn(
                  fit,
                  strings.isFilipino ? 'PUHUNAN' : 'MY CAPITAL',
                  '₱${_formatCurrency(capital)}',
                  _brandAccent,
                  isDark,
                ),
                Container(width: 1, height: fit.dp(28), color: cardBorderColor),
                _buildMetricColumn(
                  fit,
                  strings.isFilipino ? 'MGA BABOY' : 'ALLOCATED HOGS',
                  targetTags.isNotEmpty ? '${targetTags.length} of $totalHogs' : '$totalHogs Total',
                  isDark ? Colors.white : _brandColor,
                  isDark,
                ),
                Container(width: 1, height: fit.dp(28), color: cardBorderColor),
                _buildMetricColumn(
                  fit,
                  strings.isFilipino ? 'STAGE' : 'STAGE',
                  stage,
                  const Color(0xFFFFA566),
                  isDark,
                ),
              ],
            ),
          ),
          SizedBox(height: fit.dp(12)),

          // Row 3: Target Hogs Tag Badge
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: fit.dp(12), vertical: fit.dp(8)),
            decoration: BoxDecoration(
              color: _brandAccent.withValues(alpha: isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(fit.dp(10)),
              border: Border.all(
                color: _brandAccent.withValues(alpha: isDark ? 0.35 : 0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: fit.dp(15), color: _brandAccent),
                SizedBox(width: fit.dp(8)),
                Expanded(
                  child: Text(
                    targetTags.isNotEmpty
                        ? 'Funded Pigs: ${targetTags.join(', ')} • ${targetPigType.isNotEmpty ? targetPigType : 'Selected Hogs'}'
                        : 'Entire Batch Funded • $totalHogs Hogs',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: fit.sp(11.5),
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: fit.dp(14)),

          // Row 4: Action Buttons (Track Lifecycle + Invest More)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: widget.onNavigateToLifecycle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : _brandColor,
                    foregroundColor: isDark ? _brandColor : Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: fit.dp(11)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(fit.dp(12)),
                    ),
                  ),
                  icon: Icon(
                    Icons.insights_rounded,
                    size: fit.dp(16),
                    color: isDark ? _brandColor : Colors.white,
                  ),
                  label: Text(
                    strings.isFilipino ? 'Subaybayan ang Lifecycle' : 'Track Lifecycle',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: fit.sp(12.5),
                      fontWeight: FontWeight.w800,
                      color: isDark ? _brandColor : Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: fit.dp(8)),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _startInvestmentFlow(batch),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                    padding: EdgeInsets.symmetric(vertical: fit.dp(11)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(fit.dp(12)),
                    ),
                  ),
                  icon: Icon(Icons.add_rounded, size: fit.dp(15), color: _brandAccent),
                  label: Text(
                    strings.isFilipino ? 'Magdagdag' : 'Add Capital',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: fit.sp(12.0),
                      fontWeight: FontWeight.w700,
                      color: _brandAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildMetricColumn(ScreenFit fit, String label, String value, Color valueColor, bool isDark) {
    final effectiveColor = (isDark && (valueColor == _brandColor || valueColor == const Color(0xFF18314F)))
        ? Colors.white
        : valueColor;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fit.sp(9.5),
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: fit.dp(3)),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fit.sp(16.0),
              fontWeight: FontWeight.w800,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
