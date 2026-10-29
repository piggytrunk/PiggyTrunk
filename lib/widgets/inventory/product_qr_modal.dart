import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_toast.dart';

class ProductQrModal extends StatelessWidget {
  final Product product;

  const ProductQrModal({
    super.key,
    required this.product,
  });

  static void show(BuildContext context, Product product) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => ProductQrModal(product: product),
    );
  }

  String get _displayBarcode {
    if (product.barcode != null && product.barcode!.trim().isNotEmpty) {
      return product.barcode!.trim();
    }
    // Fallback if product has no custom barcode: deterministic short format
    final cleanId = product.id.replaceAll('-', '');
    final shortId = cleanId.length > 8 ? cleanId.substring(0, 8).toUpperCase() : cleanId.toUpperCase();
    return 'PIG-$shortId';
  }

  Future<void> _printBarcodeLabel(BuildContext context) async {
    try {
      final doc = pw.Document();
      final barcodeCode = _displayBarcode;
      final productName = product.name;
      final priceStr = 'PHP ${product.price.toStringAsFixed(2)}';

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, 40 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm),
          build: (pw.Context ctx) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'PIGGY TRUNK INVENTORY',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    productName,
                    maxLines: 1,
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 3),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: barcodeCode,
                    width: 46 * PdfPageFormat.mm,
                    height: 16 * PdfPageFormat.mm,
                    drawText: true,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    priceStr,
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Barcode_${product.name.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, 'Failed to print label: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final titleColor = isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText;
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

    final barcodeData = _displayBarcode;

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
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: PiggyTrunkTheme.ptPrimary.withValues(alpha: isDark ? 0.3 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        size: 20,
                        color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Product Barcode Label',
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

            // 1D Barcode Display with White High-Contrast Background
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: BarcodeWidget(
                barcode: Barcode.code128(),
                data: barcodeData,
                height: 84,
                drawText: true,
                color: const Color(0xFF0F172A),
                style: GoogleFonts.sourceCodePro(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Product Details Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2940) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Category: ${product.category}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'PHP ${product.price.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: PiggyTrunkTheme.ptSuccess,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Stock: ${product.units} units',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: mutedColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'ID: $barcodeData',
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 11,
                          color: mutedColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _printBarcodeLabel(context),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: Text(
                      'Print Barcode',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                      side: BorderSide(color: cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                      foregroundColor: isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Done',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
