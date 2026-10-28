import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_toast.dart';

class InventoryQrScannerDialog extends StatefulWidget {
  final List<Product> products;
  final ValueChanged<Product> onProductScanned;

  const InventoryQrScannerDialog({
    super.key,
    required this.products,
    required this.onProductScanned,
  });

  static void show(
    BuildContext context, {
    required List<Product> products,
    required ValueChanged<Product> onProductScanned,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => InventoryQrScannerDialog(
        products: products,
        onProductScanned: onProductScanned,
      ),
    );
  }

  @override
  State<InventoryQrScannerDialog> createState() => _InventoryQrScannerDialogState();
}

class _InventoryQrScannerDialogState extends State<InventoryQrScannerDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserAnimCtrl;
  final TextEditingController _manualCodeCtrl = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Auto-focus the input text field so a USB barcode scanner immediately inputs here
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _laserAnimCtrl.dispose();
    _manualCodeCtrl.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _processScannedCode(String rawCode) {
    final clean = rawCode.trim();
    if (clean.isEmpty) return;

    // Support both standardized prefix 'PIGGYTRUNK:PRODUCT:<id>' and direct product IDs / Barcodes
    String targetId = clean;
    if (clean.startsWith('PIGGYTRUNK:PRODUCT:')) {
      targetId = clean.replaceFirst('PIGGYTRUNK:PRODUCT:', '');
    }

    Product? matched;
    try {
      matched = widget.products.firstWhere(
        (p) =>
            (p.barcode != null && p.barcode!.toLowerCase() == targetId.toLowerCase()) ||
            p.id.toLowerCase() == targetId.toLowerCase() ||
            p.name.toLowerCase() == clean.toLowerCase() ||
            // Also match if clean starts with 'PIG-'
            (p.barcode != null && p.barcode!.toLowerCase() == clean.toLowerCase()),
      );
    } catch (_) {
      matched = null;
    }

    if (matched != null) {
      Navigator.of(context).pop();
      AppToast.success(context, 'Identified Product: ${matched.name}');
      widget.onProductScanned(matched);
    } else {
      setState(() {
        _errorMessage = 'No product found with Barcode/ID: "$clean"';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final titleColor = isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText;
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: PiggyTrunkTheme.ptSuccess.withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 20,
                        color: PiggyTrunkTheme.ptSuccess,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Scan Product Barcode / ID',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: mutedColor),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Barcode Laser Scanner Viewfinder Animation
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155), width: 1.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Stylized 1D Barcode Graphic
                  Opacity(
                    opacity: 0.35,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(28, (i) {
                        final isThick = i % 3 == 0;
                        return Container(
                          width: isThick ? 4.5 : 2.0,
                          height: 70,
                          margin: const EdgeInsets.symmetric(horizontal: 2.2),
                          color: Colors.white,
                        );
                      }),
                    ),
                  ),

                  // Red Laser Line Animation
                  AnimatedBuilder(
                    animation: _laserAnimCtrl,
                    builder: (context, child) {
                      return Positioned(
                        top: 25 + (_laserAnimCtrl.value * 95),
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: PiggyTrunkTheme.ptAccent,
                            boxShadow: [
                              BoxShadow(
                                color: PiggyTrunkTheme.ptAccent.withValues(alpha: 0.85),
                                blurRadius: 10,
                                spreadRadius: 1.5,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Helper text on bottom of viewfinder
                  Positioned(
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Point USB Barcode Scanner or Camera',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Barcode Input Box (Ready for Hardware Scanner or Keyboard Entry)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scan or Enter Barcode / Product ID:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      'Auto-listens to scanner',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: PiggyTrunkTheme.ptSuccess,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualCodeCtrl,
                        focusNode: _inputFocusNode,
                        autofocus: true,
                        onSubmitted: _processScannedCode,
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.barcode_reader, size: 20),
                          hintText: 'e.g. 480016624912 or PIG-FEED-01...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: mutedColor,
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E2F47) : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: PiggyTrunkTheme.ptPrimary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _processScannedCode(_manualCodeCtrl.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                        foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Identify',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: PiggyTrunkTheme.ptAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: PiggyTrunkTheme.ptAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Quick Demo Chips for testing on localhost
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Quick Test on Localhost:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.products.take(4).map((p) {
                final codeToUse = p.barcode ?? p.id;
                return ActionChip(
                  label: Text(
                    p.barcode != null ? '${p.name} (${p.barcode})' : p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11),
                  ),
                  avatar: const Icon(Icons.qr_code_scanner_rounded, size: 14),
                  onPressed: () => _processScannedCode(codeToUse),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
