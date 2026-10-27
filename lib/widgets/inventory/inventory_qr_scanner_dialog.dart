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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnimCtrl.dispose();
    _manualCodeCtrl.dispose();
    super.dispose();
  }

  void _processScannedCode(String rawCode) {
    final clean = rawCode.trim();
    if (clean.isEmpty) return;

    // Support both standardized prefix 'PIGGYTRUNK:PRODUCT:<id>' and direct product IDs
    String targetId = clean;
    if (clean.startsWith('PIGGYTRUNK:PRODUCT:')) {
      targetId = clean.replaceFirst('PIGGYTRUNK:PRODUCT:', '');
    }

    Product? matched;
    try {
      matched = widget.products.firstWhere(
        (p) =>
            p.id.toLowerCase() == targetId.toLowerCase() ||
            p.name.toLowerCase() == clean.toLowerCase(),
      );
    } catch (_) {
      matched = null;
    }

    if (matched != null) {
      Navigator.of(context).pop();
      AppToast.success(context, 'Scanned: ${matched.name}');
      widget.onProductScanned(matched);
    } else {
      setState(() {
        _errorMessage = 'No product found matching code: "$clean"';
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
        width: 380,
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
                      'Scan Product QR Code',
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
            const SizedBox(height: 20),

            // Animated Scanner Viewport
            Container(
              width: 240,
              height: 220,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1724) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Corner target indicators
                  Positioned(
                    top: 24,
                    left: 24,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: PiggyTrunkTheme.ptSuccess, width: 3),
                          left: BorderSide(color: PiggyTrunkTheme.ptSuccess, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 24,
                    right: 24,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: PiggyTrunkTheme.ptSuccess, width: 3),
                          right: BorderSide(color: PiggyTrunkTheme.ptSuccess, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 24,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: PiggyTrunkTheme.ptSuccess, width: 3),
                          left: BorderSide(color: PiggyTrunkTheme.ptSuccess, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: PiggyTrunkTheme.ptSuccess, width: 3),
                          right: BorderSide(color: PiggyTrunkTheme.ptSuccess, width: 3),
                        ),
                      ),
                    ),
                  ),

                  // Center QR Icon
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),

                  // Animated Scanning Laser Line
                  AnimatedBuilder(
                    animation: _laserAnimCtrl,
                    builder: (context, child) {
                      return Positioned(
                        top: 30 + (_laserAnimCtrl.value * 140),
                        left: 28,
                        right: 28,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: PiggyTrunkTheme.ptSuccess,
                            boxShadow: [
                              BoxShadow(
                                color: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  Positioned(
                    bottom: 12,
                    child: Text(
                      'Ready to scan product barcode or QR',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Simulator / Barcode Input for Localhost & Manual Entry
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Or Enter/Paste Product Code:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualCodeCtrl,
                        onSubmitted: _processScannedCode,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: titleColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. paste QR code or product name...',
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Find',
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
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: PiggyTrunkTheme.ptAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Quick Demo Buttons for existing items on Localhost
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.products.take(3).map((p) {
                return ActionChip(
                  label: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11),
                  ),
                  avatar: const Icon(Icons.qr_code_2_rounded, size: 14),
                  onPressed: () => _processScannedCode(p.id),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
