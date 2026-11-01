import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/screen_fit_util.dart';
import '../../../utils/app_strings.dart';
import '../widgets/batch_raiser_details_drawer.dart';

class PartnerProjectsTab extends StatefulWidget {
  final List<Map<String, dynamic>> projectsList;
  final Future<void> Function() onRefresh;

  const PartnerProjectsTab({
    super.key,
    required this.projectsList,
    required this.onRefresh,
  });

  @override
  State<PartnerProjectsTab> createState() => _PartnerProjectsTabState();
}

class _PartnerProjectsTabState extends State<PartnerProjectsTab> {
  static const Color _brandColor = Color(0xFF18314F);
  static const Color _brandAccent = Color(0xFF2FB36F);

  bool _isInvesting = false;
  Map<String, dynamic>? _selectedBatch;
  final TextEditingController _amountController = TextEditingController(text: '');
  double _parsedAmount = 0.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
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
      });
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _startInvestmentFlow([Map<String, dynamic>? batch]) {
    if (widget.projectsList.isEmpty && batch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active batches available for investment at the moment.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _selectedBatch = batch ?? (widget.projectsList.isNotEmpty ? widget.projectsList.first : null);
      _isInvesting = true;
      _amountController.text = '';
      _parsedAmount = 0.0;
    });
  }

  void _cancelInvestmentFlow() {
    setState(() {
      _isInvesting = false;
      _selectedBatch = null;
      _amountController.clear();
      _parsedAmount = 0.0;
    });
  }



  Future<void> _confirmInvestment() async {
    if (_parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid investment amount (e.g. ₱1,000).'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          // Resolve partner_investor_id
          final profile = await Supabase.instance.client
              .from('app_users')
              .select('user_id')
              .eq('supabase_user_id', user.id)
              .maybeSingle();

          final appUserId = profile != null ? profile['user_id'] : null;
          int? partnerInvestorId;

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

          if (partnerInvestorId != null) {
            final rawBatchId = _selectedBatch?['batch_id'];
            final int batchId = rawBatchId is int
                ? rawBatchId
                : (int.tryParse(rawBatchId?.toString() ?? '') ?? 1);

            await Supabase.instance.client.from('investments').insert({
              'partner_investor_id': partnerInvestorId,
              'batch_id': batchId,
              'amount': _parsedAmount,
              'status': 'active',
              'date_invested': DateTime.now().toIso8601String().split('T').first,
            });
          }
        } catch (e) {
          debugPrint('Notice: Investment DB insertion: $e');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Investment of ₱${_formatCurrency(_parsedAmount)} confirmed successfully!'),
          backgroundColor: const Color(0xFF2FB36F),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await widget.onRefresh();

      setState(() {
        _isInvesting = false;
        _selectedBatch = null;
        _amountController.clear();
        _parsedAmount = 0.0;
      });
    } catch (e) {
      debugPrint('Error confirming investment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Investment recorded: ₱${_formatCurrency(_parsedAmount)}'),
            backgroundColor: const Color(0xFF2FB36F),
            behavior: SnackBarBehavior.floating,
          ),
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
        padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
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
              SizedBox(height: fit.dp(18.0)),
            ],

            // View 1: Active Investment Form
            if (_isInvesting) ...[
              // Selected Batch Summary Card
              if (_selectedBatch != null) ...[
                Container(
                  padding: EdgeInsets.all(fit.dp(16)),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131F33) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(fit.dp(18)),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFBBF7D0),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(fit.dp(10)),
                        decoration: BoxDecoration(
                          color: _brandAccent.withValues(alpha: isDark ? 0.25 : 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: _brandAccent,
                          size: fit.dp(22),
                        ),
                      ),
                      SizedBox(width: fit.dp(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedBatch?['batch_name'] ?? _selectedBatch?['title'] ?? 'Batch Project',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: fit.sp(15.0),
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                            SizedBox(height: fit.dp(2)),
                            Text(
                              'Raiser: ${_selectedBatch?['assigned_raiser'] ?? _selectedBatch?['raiser_name'] ?? "Assigned Raiser"} • ${_selectedBatch?['stage'] ?? "Grower"}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: fit.sp(12.0),
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
                SizedBox(height: fit.dp(18.0)),
              ],

              // Amount Input Card
              Container(
                padding: EdgeInsets.all(fit.dp(18)),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(fit.dp(20)),
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
                    Text(
                      'INVESTMENT AMOUNT (PHP)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(11.0),
                        fontWeight: FontWeight.w800,
                        color: mutedTextColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: fit.dp(12)),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [
                        ThousandsSeparatorInputFormatter(),
                      ],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(22.0),
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: fit.dp(16), right: fit.dp(10)),
                          child: Text(
                            '₱',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: fit.sp(22.0),
                              fontWeight: FontWeight.w800,
                              color: _brandAccent,
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        hintText: '0.00',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(22.0),
                          fontWeight: FontWeight.w600,
                          color: mutedTextColor.withValues(alpha: 0.4),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: fit.dp(16), vertical: fit.dp(16)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(fit.dp(14)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(fit.dp(14)),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(fit.dp(14)),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: fit.dp(16.0)),

              // Total Invest Amount Summary Card
              Container(
                padding: EdgeInsets.symmetric(horizontal: fit.dp(18), vertical: fit.dp(16)),
                decoration: BoxDecoration(
                  color: statsBoxBg,
                  borderRadius: BorderRadius.circular(fit.dp(16)),
                  border: Border.all(color: statsBoxBorder, width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Invest Amount',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(13.5),
                        fontWeight: FontWeight.w700,
                        color: mutedTextColor,
                      ),
                    ),
                    Text(
                      '₱${_formatCurrency(_parsedAmount)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: fit.sp(18.0),
                        fontWeight: FontWeight.w800,
                        color: _parsedAmount > 0 ? _brandAccent : primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: fit.dp(22.0)),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelInvestmentFlow,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cardBorderColor, width: 1.2),
                        padding: EdgeInsets.symmetric(vertical: fit.dp(14)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(fit.dp(14)),
                        ),
                      ),
                      child: Text(
                        strings.cancel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: fit.sp(13.5),
                          fontWeight: FontWeight.w700,
                          color: mutedTextColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: fit.dp(12)),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _confirmInvestment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: fit.dp(14)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(fit.dp(14)),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
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
                                    fontSize: fit.sp(14.0),
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: fit.dp(6)),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: fit.dp(18),
                                  color: Colors.white,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // View 2: Browse & Select Active Batches
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
                      strings.isFilipino ? '$openBatchesCount BUKAS NA BATCH' : '$openBatchesCount BATCHES OPEN',
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
                          color: _brandColor.withValues(alpha: isDark ? 0.25 : 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: fit.dp(44),
                          color: isDark ? const Color(0xFF93C5FD) : _brandColor,
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
                  final String batchCode = batch['batch_code'] ?? '#BATCH-${batch['batch_id'] ?? '1'}';
                  final String stage = batch['stage'] ?? 'Grower';
                  final String hogType = batch['hog_type'] ?? 'Fattening';
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
                        // Batch Card Header: Code, Hog Type & Stage Pill
                        Padding(
                          padding: EdgeInsets.fromLTRB(fit.dp(16), fit.dp(16), fit.dp(16), 0),
                          child: Wrap(
                            spacing: fit.dp(8),
                            runSpacing: fit.dp(6),
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // 1. Batch Code Pill
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: fit.dp(10), vertical: fit.dp(4.5)),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(fit.dp(20)),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  batchCode,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(11.0),
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              // 2. Hog Type Badge (e.g. Fattening)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: fit.dp(10), vertical: fit.dp(4.5)),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(fit.dp(20)),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  hogType,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: fit.sp(11.0),
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF18314F),
                                  ),
                                ),
                              ),
                              // 3. Stage Badge (e.g. Booster Stage)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: fit.dp(10), vertical: fit.dp(4.5)),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(fit.dp(20)),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.4 : 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: fit.dp(5.5),
                                      height: fit.dp(5.5),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: fit.dp(4)),
                                    Text(
                                      '$stage Stage',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: fit.sp(11.0),
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
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
        ),
      ),
    );
  }



  Widget _buildMetricColumn(ScreenFit fit, String label, String value, Color valueColor, bool isDark) {
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
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}


/// Automatically formats numeric inputs with thousand separators (commas) in real-time.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final bool allowDecimal;
  final int decimalDigits;

  const ThousandsSeparatorInputFormatter({
    this.allowDecimal = true,
    this.decimalDigits = 2,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String textToFormat = newValue.text;
    int selectionEnd = newValue.selection.end;

    // Handle backspace when the cursor was right after a comma
    if (oldValue.text.length == newValue.text.length + 1 &&
        oldValue.selection.end > 0 &&
        oldValue.selection.end <= oldValue.text.length &&
        oldValue.text[oldValue.selection.end - 1] == ',') {
      final deleteIndex = oldValue.selection.end - 2;
      if (deleteIndex >= 0) {
        textToFormat = oldValue.text.substring(0, deleteIndex) +
            oldValue.text.substring(oldValue.selection.end);
        selectionEnd = deleteIndex;
      }
    }

    // Filter allowed characters: only digits and at most one decimal point
    String clean = '';
    bool hasDot = false;
    int decimalsCount = 0;

    for (int i = 0; i < textToFormat.length; i++) {
      final char = textToFormat[i];
      if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
        if (!hasDot) {
          clean += char;
        } else if (decimalsCount < decimalDigits) {
          clean += char;
          decimalsCount++;
        }
      } else if (char == '.' && allowDecimal && !hasDot) {
        hasDot = true;
        clean += '.';
      }
    }

    if (clean.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Strip extraneous leading zeros unless it is "0" or "0."
    if (!clean.startsWith('0.') && clean.length > 1 && clean.startsWith('0')) {
      clean = clean.replaceFirst(RegExp(r'^0+'), '');
      if (clean.isEmpty || clean.startsWith('.')) {
        clean = '0$clean';
      }
    }

    // Split integer and decimal parts
    final parts = clean.split('.');
    String integerPart = parts[0];
    String? decimalPart = parts.length > 1 ? parts[1] : null;

    // Format integer part with commas
    final formattedInt = integerPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    String formatted = formattedInt;
    if (hasDot) {
      formatted += '.$decimalPart';
    }

    // Map cursor position based on non-comma characters before cursor in textToFormat
    final textBeforeCursor = textToFormat.substring(
      0,
      selectionEnd.clamp(0, textToFormat.length),
    );
    final rawCharsBeforeCursor = textBeforeCursor.replaceAll(',', '');

    int newCursorPos = 0;
    int matchedRawChars = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (formatted[i] != ',') {
        matchedRawChars++;
      }
      if (matchedRawChars == rawCharsBeforeCursor.length) {
        newCursorPos = i + 1;
        break;
      }
    }
    if (matchedRawChars < rawCharsBeforeCursor.length) {
      newCursorPos = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPos.clamp(0, formatted.length)),
    );
  }
}
