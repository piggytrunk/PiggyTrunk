import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class ProductRestockForm extends StatefulWidget {
  final Product product;
  final VoidCallback onCancel;
  final VoidCallback onRestocked;
  final Future<void> Function({
    required String? productId,
    required String productName,
    required String action,
    required double price,
    required int units,
    String? details,
  }) onInsertLog;
  final void Function(String msg, {Color? backgroundColor}) onShowSnackBar;
  final VoidCallback? onViewHistory;

  const ProductRestockForm({
    super.key,
    required this.product,
    required this.onCancel,
    required this.onRestocked,
    required this.onInsertLog,
    required this.onShowSnackBar,
    this.onViewHistory,
  });

  @override
  State<ProductRestockForm> createState() => _ProductRestockFormState();
}

class _ProductRestockFormState extends State<ProductRestockForm> {
  final TextEditingController _quantityCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _restockError;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => _isDark ? const Color(0xFF132238) : Colors.white;
  Color get _cardBorder => _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _mutedColor => _isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
  Color get _fieldBg => _isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
  Color get _fieldText => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _fieldBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);
  Color get _panelStart => _isDark ? const Color(0xFF1A2940) : Colors.white;
  Color get _panelEnd => _isDark ? const Color(0xFF0F1C2F) : Colors.white;
  Color get _panelBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);
  Color get _infoCardBg => _isDark ? const Color(0xFF1A2B44) : const Color(0xFFF0F6FF);

  @override
  void dispose() {
    _quantityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRestock() async {
    final addUnits = int.tryParse(_quantityCtrl.text.trim());
    if (addUnits == null || addUnits <= 0) {
      setState(() {
        _restockError = 'Please enter a valid quantity greater than 0.';
      });
      return;
    }

    setState(() {
      _restockError = null;
      _isSubmitting = true;
    });

    try {
      final newUnits = widget.product.units + addUnits;

      await Supabase.instance.client
          .from('inventory_products')
          .update({'units': newUnits})
          .eq('id', widget.product.id);

      await widget.onInsertLog(
        productId: widget.product.id,
        productName: widget.product.name,
        action: 'RESTOCK',
        price: widget.product.price,
        units: addUnits,
        details: 'Added $addUnits units to stock. Total is now $newUnits units.',
      );

      if (!mounted) return;
      widget.onRestocked();
      widget.onShowSnackBar(
        'Successfully added $addUnits units to "${widget.product.name}". Total: $newUnits units.',
        backgroundColor: PiggyTrunkTheme.ptSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _restockError = 'Restock failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final addUnits = int.tryParse(_quantityCtrl.text.trim()) ?? 0;
    final projectedStock = widget.product.units + addUnits;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_panelStart, _panelEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: _panelBorder, width: 1),
          borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 24,
          vertical: isMobile ? 16 : 26,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with Title & History
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Restock Product',
                          style: GoogleFonts.plusJakartaSans(
                            color: _titleColor,
                            fontSize: isMobile ? 20 : 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Add stock units to warehouse inventory',
                          style: GoogleFonts.plusJakartaSans(
                            color: _mutedColor,
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onViewHistory != null)
                    Tooltip(
                      message: 'View Product Activity Logs',
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : widget.onViewHistory,
                        icon: Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                        ),
                        label: isMobile
                            ? const SizedBox.shrink()
                            : Text(
                                'Activity Logs',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                ),
                              ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _panelBorder, width: 1.2),
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 10 : 16,
                            vertical: isMobile ? 10 : 12,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Restock Card Container
              Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  border: Border.all(color: _cardBorder, width: 1),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(isMobile ? 16 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Summary Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _infoCardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _cardBorder, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          if (widget.product.image != null && widget.product.image!.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                widget.product.image!,
                                width: 54,
                                height: 54,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  width: 54,
                                  height: 54,
                                  color: _fieldBg,
                                  child: Icon(Icons.inventory_2_outlined, color: _mutedColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _isDark ? const Color(0xFF1E2F47) : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _isDark ? const Color(0xFF28405D) : const Color(0xFFBFDBFE),
                                        ),
                                      ),
                                      child: Text(
                                        widget.product.category,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _isDark ? const Color(0x3343CB89) : const Color(0x2243CB89),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _isDark ? const Color(0x5543CB89) : const Color(0x4443CB89),
                                        ),
                                      ),
                                      child: Text(
                                        'Current Stock: ${widget.product.units} units',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: _isDark ? const Color(0xFF43CB89) : const Color(0xFF166534),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.product.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _titleColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₱${widget.product.price.toStringAsFixed(2)} / unit',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _mutedColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quantity Input Label
                    Text(
                      'ADD QUANTITY (UNITS) *',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _mutedColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _quantityCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) {
                        setState(() {
                          if (_restockError != null) _restockError = null;
                        });
                      },
                      style: GoogleFonts.plusJakartaSans(
                        color: _fieldText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.add_circle_outline, color: _mutedColor, size: 20),
                        hintText: 'e.g., 50',
                        hintStyle: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 14),
                        filled: true,
                        fillColor: _fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _restockError != null ? const Color(0xFFE53E3E) : _fieldBorder,
                            width: _restockError != null ? 1.5 : 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _restockError != null ? const Color(0xFFE53E3E) : PiggyTrunkTheme.ptPrimary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (_restockError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _restockError!,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFE53E3E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Projected Stock Calculation Card
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: addUnits > 0
                            ? (_isDark ? const Color(0xFF142B28) : const Color(0xFFF0FDF4))
                            : (_isDark ? const Color(0xFF16253B) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: addUnits > 0
                              ? (_isDark ? const Color(0xFF1D5C43) : const Color(0xFFBBF7D0))
                              : _fieldBorder,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                addUnits > 0 ? Icons.trending_up_rounded : Icons.info_outline_rounded,
                                color: addUnits > 0
                                    ? (_isDark ? const Color(0xFF43CB89) : const Color(0xFF16A34A))
                                    : _mutedColor,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Projected Total Stock:',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: _titleColor,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$projectedStock units',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: addUnits > 0
                                  ? (_isDark ? const Color(0xFF43CB89) : const Color(0xFF16A34A))
                                  : _titleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _isSubmitting ? null : widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            side: BorderSide(color: _cardBorder, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              color: _mutedColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitRestock,
                          icon: _isSubmitting
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                ),
                          label: Text(
                            _isSubmitting ? 'Saving...' : 'Confirm Restock',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            foregroundColor: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            elevation: 0,
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
      );
  }
}
