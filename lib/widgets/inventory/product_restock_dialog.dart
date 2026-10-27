import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class ProductRestockDialog {
  static void show({
    required BuildContext context,
    required List<Product> products,
    Product? initialProduct,
    int? initialQuantity,
    required Future<void> Function({
      required String? productId,
      required String productName,
      required String action,
      required double price,
      required int units,
      String? details,
    }) onInsertLog,
    required VoidCallback onProductsReload,
    required void Function(String msg, {Color? backgroundColor}) onShowSnackBar,
  }) {
    if (products.isEmpty) {
      onShowSnackBar(
        'No products available in inventory to restock.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    Product selectedProduct = initialProduct != null && products.any((p) => p.id == initialProduct.id)
        ? products.firstWhere((p) => p.id == initialProduct.id)
        : products.first;

    final isSpecificProduct = initialProduct != null;
    final quantityCtrl = TextEditingController(text: '');
    bool isSubmittingRestock = false;
    String? restockError;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: isSpecificProduct ? 'Restock Product' : 'Restock Inventory',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogCtx, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (dialogCtx, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        final isMobile = Responsive.isMobile(dialogCtx);
        final screenHeight = MediaQuery.of(dialogCtx).size.height;
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark || Theme.of(context).brightness == Brightness.dark;
        final drawerBg = isDark ? const Color(0xFF132238) : Colors.white;
        final borderColor = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
        final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
        final mutedColor = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
        final fieldBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
        final fieldBorder = isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);
        final cardBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF0F6FF);
        final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFC9D8EC);

        final dialogBody = Center(
          child: Material(
            color: Colors.transparent,
            child: StatefulBuilder(
              builder: (stfCtx, setDialogState) {
                final addUnits = int.tryParse(quantityCtrl.text.trim()) ?? 0;
                final projectedStock = selectedProduct.units + addUnits;

                return Container(
                  width: isMobile ? double.infinity : (MediaQuery.of(dialogCtx).size.width > 900 ? 760.0 : MediaQuery.of(dialogCtx).size.width * 0.92),
                  height: isMobile ? screenHeight * 0.88 : screenHeight * 0.85,
                  margin: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [const Color(0xFF1A2940), const Color(0xFF0F1C2F)]
                          : [Colors.white, const Color(0xFFF8FAFC)],
                    ),
                    borderRadius: isMobile
                        ? const BorderRadius.vertical(top: Radius.circular(24))
                        : BorderRadius.circular(28),
                    border: isMobile
                        ? Border(top: BorderSide(color: borderColor, width: 1.2))
                        : Border.all(color: borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
                        blurRadius: 32,
                        offset: isMobile ? const Offset(0, -4) : const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: isMobile
                        ? const BorderRadius.vertical(top: Radius.circular(24))
                        : BorderRadius.circular(28),
                    child: SafeArea(
                      top: !isMobile,
                      bottom: !isMobile,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMobile) ...[
                            // Top Drag Handle for mobile only
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(top: 12, bottom: 6),
                                width: 44,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],

                          // Top Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.add_shopping_cart_rounded,
                                    color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isSpecificProduct ? 'Restock Product' : 'Restock Inventory',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: titleColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Add stock units to warehouse',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: mutedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close_rounded, color: mutedColor, size: 20),
                                  splashRadius: 20,
                                  onPressed: isSubmittingRestock ? null : () => Navigator.of(dialogCtx).pop(),
                                ),
                              ],
                            ),
                          ),

                          // Drawer Body
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isSpecificProduct) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: cardBorder, width: 1.2),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF1E2F47) : const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: isDark ? const Color(0xFF28405D) : const Color(0xFFBFDBFE),
                                                  ),
                                                ),
                                                child: Text(
                                                  selectedProduct.category,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0x3343CB89) : const Color(0x2243CB89),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: isDark ? const Color(0x5543CB89) : const Color(0x4443CB89),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Stock: ${selectedProduct.units} units',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? const Color(0xFF43CB89) : const Color(0xFF166534),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            selectedProduct.name,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: titleColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '₱${selectedProduct.price.toStringAsFixed(2)} / unit',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: mutedColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      'SELECT PRODUCT *',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: mutedColor,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<Product>(
                                      initialValue: selectedProduct,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: fieldBg,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: fieldBorder),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: PiggyTrunkTheme.ptPrimary, width: 1.5),
                                        ),
                                      ),
                                      dropdownColor: fieldBg,
                                      borderRadius: BorderRadius.circular(12),
                                      style: GoogleFonts.plusJakartaSans(
                                        color: titleColor,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      items: products.map((prod) {
                                        return DropdownMenuItem<Product>(
                                          value: prod,
                                          child: Text(
                                            '[${prod.category}] ${prod.name} (${prod.units} units)',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedProduct = val);
                                        }
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 20),

                                  // Add Quantity
                                  Text(
                                    'ADD QUANTITY (UNITS) *',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: mutedColor,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: quantityCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (_) {
                                      setDialogState(() {
                                        if (restockError != null) restockError = null;
                                      });
                                    },
                                    style: GoogleFonts.plusJakartaSans(
                                      color: titleColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'e.g., 50',
                                      hintStyle: GoogleFonts.plusJakartaSans(color: mutedColor, fontSize: 14),
                                      prefixIcon: Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 18,
                                        color: isDark ? Colors.white : mutedColor,
                                      ),
                                      filled: true,
                                      fillColor: fieldBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: restockError != null ? const Color(0xFFE53E3E) : fieldBorder,
                                          width: restockError != null ? 1.5 : 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: restockError != null ? const Color(0xFFE53E3E) : PiggyTrunkTheme.ptPrimary,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (restockError != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      restockError!,
                                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE53E3E), fontSize: 11.5, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                  const SizedBox(height: 20),

                                  // Live Projection Card
                                  if (addUnits > 0) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: PiggyTrunkTheme.ptSuccess.withValues(alpha: isDark ? 0.15 : 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.trending_up_rounded, color: PiggyTrunkTheme.ptSuccess, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Current: ${selectedProduct.units}  →  New Total: $projectedStock units',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // Docked Footer Buttons
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: drawerBg,
                              border: Border(top: BorderSide(color: borderColor, width: 1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isSubmittingRestock ? null : () => Navigator.of(dialogCtx).pop(),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(color: borderColor, width: 1.2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: mutedColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: isSubmittingRestock
                                        ? null
                                        : () async {
                                            final addUnits = int.tryParse(quantityCtrl.text.trim());
                                            if (addUnits == null || addUnits <= 0) {
                                              setDialogState(() {
                                                restockError = 'Please enter a valid quantity greater than 0.';
                                              });
                                              return;
                                            }

                                            setDialogState(() {
                                              restockError = null;
                                              isSubmittingRestock = true;
                                            });

                                            try {
                                              final newUnits = selectedProduct.units + addUnits;

                                              await Supabase.instance.client
                                                  .from('inventory_products')
                                                  .update({'units': newUnits})
                                                  .eq('id', selectedProduct.id);

                                              await onInsertLog(
                                                productId: selectedProduct.id,
                                                productName: selectedProduct.name,
                                                action: 'RESTOCK',
                                                price: selectedProduct.price,
                                                units: addUnits,
                                                details: 'Added $addUnits units to stock. Total is now $newUnits units.',
                                              );

                                              if (!dialogCtx.mounted) return;
                                              Navigator.of(dialogCtx).pop();
                                              onProductsReload();

                                              onShowSnackBar(
                                                'Successfully added $addUnits units to "${selectedProduct.name}".',
                                                backgroundColor: PiggyTrunkTheme.ptSuccess,
                                              );
                                            } catch (e) {
                                              setDialogState(() {
                                                isSubmittingRestock = false;
                                                restockError = 'Restock failed: $e';
                                              });
                                            }
                                          },
                                    icon: isSubmittingRestock
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            Icons.check_rounded,
                                            size: 18,
                                            color: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                          ),
                                    label: Text(
                                      isSubmittingRestock ? 'Saving...' : 'Confirm Restock',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                      foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
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
                  ),
                );
              },
            ),
          ),
        );

        if (isMobile) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: dialogBody,
            ),
          );
        }

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curvedAnimation),
            child: dialogBody,
          ),
        );
      },
    );
  }
}
