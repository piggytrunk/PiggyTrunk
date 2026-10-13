import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/models/pos_model.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cashier_receipt_modal.dart';
import '../../../utils/app_strings.dart';
import '../../../utils/capitalization_formatters.dart';

class CashierCheckoutModal extends StatefulWidget {
  final Order currentOrder;
  final String cashierName;
  final Future<void> Function({
    required String customerName,
    required String customerType,
    required String paymentMethod,
    required double tenderedAmount,
    required double changeAmount,
    required Order order,
  }) onConfirmCheckout;

  const CashierCheckoutModal({
    super.key,
    required this.currentOrder,
    required this.cashierName,
    required this.onConfirmCheckout,
  });

  @override
  State<CashierCheckoutModal> createState() => _CashierCheckoutModalState();
}

class _CashierCheckoutModalState extends State<CashierCheckoutModal> {
  static const Color _brandNavy = PiggyTrunkTheme.ptPrimary;

  String _customerType = 'Walk-in'; // 'Walk-in' or 'Hog Raiser'
  String _selectedPaymentMethod = 'Cash'; // 'Cash' or 'GCash'
  final TextEditingController _walkInNameCtrl = TextEditingController();
  final TextEditingController _raiserSearchCtrl = TextEditingController();
  String _raiserSearchQuery = '';

  List<Map<String, dynamic>> _hogRaisers = [];
  Map<String, dynamic>? _selectedHogRaiser;
  bool _isLoadingRaisers = false;
  bool _isSubmitting = false;

  bool _isSuccess = false;
  String _successCustomerName = '';
  String _successPaymentMethod = '';
  double _successTotal = 0.0;
  List<OrderItem> _successItems = [];
  DateTime _successTimestamp = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchHogRaisers();
  }

  @override
  void dispose() {
    _walkInNameCtrl.dispose();
    _raiserSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchHogRaisers() async {
    setState(() => _isLoadingRaisers = true);
    try {
      dynamic res;
      try {
        res = await Supabase.instance.client
            .from('hog_raisers')
            .select('hog_raiser_id, name, email, avatar_url')
            .order('hog_raiser_id', ascending: false);
      } catch (_) {
        res = await Supabase.instance.client
            .from('hog_raisers')
            .select('hog_raiser_id, name, email, avatar_url');
      }
      if (mounted) {
        final raiserList = List<Map<String, dynamic>>.from(res);
        raiserList.sort((a, b) {
          final idA = int.tryParse(a['hog_raiser_id']?.toString() ?? '0') ?? 0;
          final idB = int.tryParse(b['hog_raiser_id']?.toString() ?? '0') ?? 0;
          return idB.compareTo(idA); // Higher ID (newest) first, lower ID (oldest) last
        });
        setState(() {
          _hogRaisers = raiserList;
        });
      }
    } catch (e) {
      debugPrint('Error fetching hog raisers for checkout: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRaisers = false);
    }
  }

  Future<void> _handleConfirm() async {
    final String finalCustomerName = _customerType == 'Walk-in'
        ? (_walkInNameCtrl.text.trim().isNotEmpty ? _walkInNameCtrl.text.trim() : 'Walk-in Customer')
        : (_selectedHogRaiser?['name'] ?? 'Unassigned Raiser');
    final double snapshotTotal = widget.currentOrder.total;
    final List<OrderItem> snapshotItems = List<OrderItem>.from(widget.currentOrder.items);
    final String snapshotPayment = _selectedPaymentMethod;

    setState(() => _isSubmitting = true);
    try {
      await widget.onConfirmCheckout(
        customerName: finalCustomerName,
        customerType: _customerType,
        paymentMethod: _selectedPaymentMethod,
        tenderedAmount: snapshotTotal,
        changeAmount: 0.0,
        order: widget.currentOrder,
      );
      if (mounted) {
        setState(() {
          _isSuccess = true;
          _successCustomerName = finalCustomerName;
          _successPaymentMethod = snapshotPayment;
          _successTotal = snapshotTotal;
          _successItems = snapshotItems;
          _successTimestamp = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final total = widget.currentOrder.total;

    final modalBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface;
    final titleColor = isDark ? PiggyTrunkTheme.ptTextDark : _brandNavy;
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final fieldBg = isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft;
    final fieldBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;

    if (_isSuccess) {
      return _buildSuccessView(
        context: context,
        isDark: isDark,
        titleColor: titleColor,
        subtitleColor: subtitleColor,
        cardBorder: cardBorder,
        modalBg: modalBg,
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Drag Handle & Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 20, 12),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment & Checkout',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: subtitleColor),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cardBorder),

            // Body Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Due Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [PiggyTrunkTheme.ptPrimary, const Color(0xFF16253B)]
                              : [PiggyTrunkTheme.ptPrimary, const Color(0xFF18314F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: isDark ? PiggyTrunkTheme.ptBorderDark : const Color(0xFF324D6E),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black38 : PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL AMOUNT DUE',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₱${total.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${widget.currentOrder.totalItems} Items',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Customer Type Selector
                    Text(
                      'Customer Type',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _customerType = 'Walk-in'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _customerType == 'Walk-in'
                                    ? (isDark ? Colors.white : _brandNavy)
                                    : fieldBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _customerType == 'Walk-in'
                                      ? (isDark ? Colors.white : _brandNavy)
                                      : fieldBorder,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 18,
                                    color: _customerType == 'Walk-in'
                                        ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                        : (isDark ? Colors.white70 : _brandNavy),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Walk-in Customer',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _customerType == 'Walk-in'
                                          ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                          : (isDark ? Colors.white : _brandNavy),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _customerType = 'Hog Raiser'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _customerType == 'Hog Raiser'
                                    ? (isDark ? Colors.white : _brandNavy)
                                    : fieldBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _customerType == 'Hog Raiser'
                                      ? (isDark ? Colors.white : _brandNavy)
                                      : fieldBorder,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.pets_rounded,
                                    size: 18,
                                    color: _customerType == 'Hog Raiser'
                                        ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                        : (isDark ? Colors.white70 : _brandNavy),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hog Raiser',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _customerType == 'Hog Raiser'
                                          ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                          : (isDark ? Colors.white : _brandNavy),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Customer Name Input or Hog Raiser Dropdown
                    if (_customerType == 'Walk-in') ...[
                      TextField(
                        controller: _walkInNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: const [CapitalizeWordsInputFormatter()],
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: titleColor),
                        decoration: InputDecoration(
                          hintText: 'Customer name (optional)',
                          hintStyle: GoogleFonts.plusJakartaSans(color: subtitleColor),
                          filled: true,
                          fillColor: fieldBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: fieldBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.white : _brandNavy, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ] else ...[
                      _isLoadingRaisers
                          ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : _brandNavy))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Live Raiser Search Bar
                                Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: fieldBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: fieldBorder),
                                  ),
                                  child: TextField(
                                    controller: _raiserSearchCtrl,
                                    onChanged: (val) => setState(() => _raiserSearchQuery = val.trim().toLowerCase()),
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: titleColor),
                                    decoration: InputDecoration(
                                      hintText: 'Search raiser by name or email...',
                                      hintStyle: GoogleFonts.plusJakartaSans(color: subtitleColor, fontSize: 12.5),
                                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: subtitleColor),
                                      suffixIcon: _raiserSearchCtrl.text.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(Icons.clear_rounded, size: 16, color: subtitleColor),
                                              onPressed: () {
                                                _raiserSearchCtrl.clear();
                                                setState(() => _raiserSearchQuery = '');
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Scrollable Filtered Raisers List
                                Builder(
                                  builder: (context) {
                                    final query = _raiserSearchQuery;
                                    final filteredRaisers = _hogRaisers.where((r) {
                                      if (query.isEmpty) return true;
                                      final name = (r['name'] ?? '').toString().toLowerCase();
                                      final email = (r['email'] ?? '').toString().toLowerCase();
                                      final id = (r['hog_raiser_id'] ?? '').toString();
                                      return name.contains(query) || email.contains(query) || id.contains(query);
                                    }).toList();

                                    return Container(
                                      constraints: const BoxConstraints(maxHeight: 190),
                                      decoration: BoxDecoration(
                                        color: isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: fieldBorder),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(11),
                                        child: ListView(
                                          shrinkWrap: true,
                                          padding: EdgeInsets.zero,
                                          children: [
                                            // Top Option: Unassigned (General Raiser)
                                            if (query.isEmpty || 'unassigned general raiser'.contains(query))
                                              InkWell(
                                                onTap: () => setState(() => _selectedHogRaiser = null),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                  color: _selectedHogRaiser == null
                                                      ? (isDark ? Colors.white.withValues(alpha: 0.08) : _brandNavy.withValues(alpha: 0.06))
                                                      : Colors.transparent,
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.person_outline_rounded,
                                                        size: 16,
                                                        color: _selectedHogRaiser == null
                                                            ? (isDark ? Colors.white : _brandNavy)
                                                            : subtitleColor,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          'Unassigned (General Raiser)',
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 13,
                                                            fontWeight: _selectedHogRaiser == null ? FontWeight.w800 : FontWeight.w600,
                                                            color: _selectedHogRaiser == null ? titleColor : subtitleColor,
                                                          ),
                                                        ),
                                                      ),
                                                      if (_selectedHogRaiser == null)
                                                        Icon(
                                                          Icons.check_circle_rounded,
                                                          size: 16,
                                                          color: isDark ? Colors.white : _brandNavy,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                            if (filteredRaisers.isEmpty && query.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                                                child: Center(
                                                  child: Text(
                                                    'No raisers found matching "$query"',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12.5,
                                                      color: subtitleColor,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            else
                                              ...filteredRaisers.map((r) {
                                                final isSelected = _selectedHogRaiser?['hog_raiser_id'] == r['hog_raiser_id'];
                                                final rName = r['name'] ?? 'Hog Raiser';
                                                final rEmail = r['email']?.toString() ?? '';

                                                return InkWell(
                                                  onTap: () => setState(() => _selectedHogRaiser = r),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? (isDark ? Colors.white.withValues(alpha: 0.08) : _brandNavy.withValues(alpha: 0.06))
                                                          : Colors.transparent,
                                                      border: Border(
                                                        top: BorderSide(
                                                          color: isDark
                                                              ? PiggyTrunkTheme.ptBorderDark.withValues(alpha: 0.5)
                                                              : const Color(0xFFF1F5F9),
                                                          width: 0.8,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.pets_rounded,
                                                          size: 14,
                                                          color: isDark ? PiggyTrunkTheme.ptSuccessDark : _brandNavy,
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                rName,
                                                                style: GoogleFonts.plusJakartaSans(
                                                                  fontSize: 13,
                                                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                                                  color: titleColor,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              if (rEmail.isNotEmpty)
                                                                Text(
                                                                  rEmail,
                                                                  style: GoogleFonts.plusJakartaSans(
                                                                    fontSize: 10.5,
                                                                    color: subtitleColor,
                                                                  ),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (isSelected)
                                                          Icon(
                                                            Icons.check_circle_rounded,
                                                            size: 16,
                                                            color: isDark ? Colors.white : _brandNavy,
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                    ],
                    const SizedBox(height: 22),

                    // Payment Method (Only Cash & GCash)
                    Text(
                      'Payment Method',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Cash', 'GCash'].map((method) {
                        final isSelected = _selectedPaymentMethod == method;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setState(() => _selectedPaymentMethod = method),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? Colors.white : _brandNavy)
                                      : fieldBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? Colors.white : _brandNavy)
                                        : fieldBorder,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  method,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                        : titleColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: modalBg,
                border: Border(top: BorderSide(color: cardBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cardBorder, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        strings.cancel,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: subtitleColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : _brandNavy,
                        foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Complete Transaction',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView({
    required BuildContext context,
    required bool isDark,
    required Color titleColor,
    required Color subtitleColor,
    required Color cardBorder,
    required Color modalBg,
  }) {
    final successColor = isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Drag Handle & Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 20, 12),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaction Completed',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, true),
                        icon: Icon(Icons.close_rounded, color: subtitleColor),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cardBorder),

            // Success Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: successColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: successColor.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 52,
                          color: successColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment Successful!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₱${_successTotal.toStringAsFixed(2)} received via $_successPaymentMethod',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Order Summary Breakdown Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? PiggyTrunkTheme.ptSurfaceSoftDark : PiggyTrunkTheme.ptSurfaceSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        children: [
                          _buildSuccessRow('Customer', _successCustomerName, titleColor, subtitleColor),
                          Divider(height: 20, thickness: 0.8, color: cardBorder),
                          _buildSuccessRow('Payment Method', _successPaymentMethod, titleColor, subtitleColor),
                          Divider(height: 20, thickness: 0.8, color: cardBorder),
                          _buildSuccessRow(
                            'Items Purchased',
                            '${_successItems.fold<int>(0, (s, i) => s + i.quantity)} units (${_successItems.length} products)',
                            titleColor,
                            subtitleColor,
                          ),
                          Divider(height: 20, thickness: 0.8, color: cardBorder),
                          _buildSuccessRow(
                            'Total Amount Paid',
                            '₱${_successTotal.toStringAsFixed(2)}',
                            successColor,
                            subtitleColor,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions: View Receipt & Done
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: modalBg,
                border: Border(top: BorderSide(color: cardBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (ctx) => CashierReceiptModal(
                            receiptNumber: DateTime.now().millisecondsSinceEpoch.toString().substring(5),
                            customerName: _successCustomerName,
                            cashierName: widget.cashierName,
                            timestamp: _successTimestamp,
                            items: _successItems,
                            totalAmount: _successTotal,
                            paymentMethod: _successPaymentMethod,
                            tenderedAmount: _successTotal,
                            changeAmount: 0.0,
                            onDone: () => Navigator.pop(ctx),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: Text(
                        'View Receipt',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cardBorder, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        foregroundColor: titleColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : _brandNavy,
                        foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Done (New Sale)',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessRow(String label, String value, Color titleColor, Color subtitleColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: subtitleColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: titleColor,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
