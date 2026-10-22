import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/models/pos_model.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  static const Color _brandNavy = Color(0xFF18314F);

  String _customerType = 'Walk-in'; // 'Walk-in' or 'Hog Raiser'
  String _selectedPaymentMethod = 'Cash'; // 'Cash' or 'GCash'
  final TextEditingController _walkInNameCtrl = TextEditingController(text: 'Walk-in Customer');

  List<Map<String, dynamic>> _hogRaisers = [];
  Map<String, dynamic>? _selectedHogRaiser;
  bool _isLoadingRaisers = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchHogRaisers();
  }

  @override
  void dispose() {
    _walkInNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchHogRaisers() async {
    setState(() => _isLoadingRaisers = true);
    try {
      final res = await Supabase.instance.client
          .from('hog_raisers')
          .select('hog_raiser_id, name, email, avatar_url')
          .order('name', ascending: true);
      if (mounted) {
        setState(() {
          _hogRaisers = List<Map<String, dynamic>>.from(res);
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

    setState(() => _isSubmitting = true);
    try {
      await widget.onConfirmCheckout(
        customerName: finalCustomerName,
        customerType: _customerType,
        paymentMethod: _selectedPaymentMethod,
        tenderedAmount: widget.currentOrder.total,
        changeAmount: 0.0,
        order: widget.currentOrder,
      );
      if (mounted) {
        Navigator.pop(context, true);
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

    final modalBg = isDark ? const Color(0xFF151F2E) : Colors.white;
    final titleColor = isDark ? Colors.white : _brandNavy;
    final subtitleColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final cardBorder = isDark ? const Color(0xFF28354A) : const Color(0xFFE2E8F0);
    final fieldBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
    final fieldBorder = isDark ? const Color(0xFF2E456B) : const Color(0xFFD7E3F3);

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
                              ? [const Color(0xFF1E3A8A), const Color(0xFF1E293B)]
                              : [_brandNavy, const Color(0xFF2A4A70)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black38 : _brandNavy.withValues(alpha: 0.22),
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
                          hintText: 'Customer Name / Note',
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
                          : DropdownButtonFormField<Map<String, dynamic>?>(
                              initialValue: _selectedHogRaiser,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: titleColor),
                              hint: Text(
                                'Unassigned (Select Hog Raiser)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              decoration: InputDecoration(
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
                              items: [
                                DropdownMenuItem<Map<String, dynamic>?>(
                                  value: null,
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_outline_rounded, size: 16, color: subtitleColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Unassigned (General Raiser)',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: subtitleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ..._hogRaisers.map((r) {
                                  return DropdownMenuItem<Map<String, dynamic>?>(
                                    value: r,
                                    child: Row(
                                      children: [
                                        Icon(Icons.pets_rounded, size: 15, color: isDark ? const Color(0xFF38BDF8) : _brandNavy),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            r['name'] ?? 'Hog Raiser #${r['hog_raiser_id']}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: titleColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedHogRaiser = val);
                              },
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
}
