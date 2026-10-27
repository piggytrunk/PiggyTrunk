import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/product_model.dart';
import '../utils/web_file_downloader.dart';

class InventoryExportService {
  /// Exports products list to CSV file and initiates browser download
  static Future<void> exportToCsv(
    List<Product> products, {
    String filenamePrefix = 'inventory_catalog',
  }) async {
    final List<List<dynamic>> rows = [];

    // Header row
    rows.add([
      'Product Name',
      'Category',
      'Unit Price (PHP)',
      'Current Stock',
      'Units Sold',
      'Inventory Value (PHP)',
      'Status',
      'Description',
      'Created Date',
    ]);

    // Data rows
    for (final p in products) {
      final totalValue = p.price * p.units;
      String status;
      if (p.isArchived) {
        status = 'Archived';
      } else if (p.units <= 0) {
        status = 'Out of Stock';
      } else if (p.units <= 10) {
        status = 'Low Stock';
      } else {
        status = 'In Stock';
      }

      final dateStr =
          '${p.createdAt.year}-${p.createdAt.month.toString().padLeft(2, '0')}-${p.createdAt.day.toString().padLeft(2, '0')}';

      rows.add([
        p.name,
        p.category,
        p.price.toStringAsFixed(2),
        p.units,
        p.sold,
        totalValue.toStringAsFixed(2),
        status,
        p.description.replaceAll('\n', ' ').trim(),
        dateStr,
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    // Add UTF-8 BOM (0xEF, 0xBB, 0xBF) so Excel & Sheets open accents / formatting cleanly
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csvString)]);

    final now = DateTime.now();
    final dateSuffix =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final filename = '${filenamePrefix}_$dateSuffix.csv';

    WebFileDownloader.downloadBytes(
      bytes: bytes,
      filename: filename,
      mimeType: 'text/csv;charset=utf-8;',
    );
  }

  /// Exports products list to clean, professional branded PDF report
  static Future<void> exportToPdf(
    List<Product> products, {
    String filenamePrefix = 'inventory_catalog_report',
    String? adminEmail,
  }) async {
    final pdf = pw.Document();

    // Summary calculations
    final totalProducts = products.length;
    final totalUnits = products.fold<int>(0, (sum, p) => sum + p.units);
    final totalValuation = products.fold<double>(0.0, (sum, p) => sum + (p.price * p.units));
    final lowStockCount = products.where((p) => !p.isArchived && p.units > 0 && p.units <= 10).length;
    final outOfStockCount = products.where((p) => !p.isArchived && p.units <= 0).length;

    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Theme colors matching Piggy Trunk
    final primaryColor = PdfColor.fromHex('243B53');
    final accentColor = PdfColor.fromHex('EF5B6C');
    final successColor = PdfColor.fromHex('2FB36F');
    final warningColor = PdfColor.fromHex('FFA566');
    final darkTextColor = PdfColor.fromHex('18314F');
    final lightBgColor = PdfColor.fromHex('F8FAFC');
    final tableBorderColor = PdfColor.fromHex('E2E8F0');

    // Build multi-page document with automated pagination
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (context) {
          // Simple, clean header without subtitle
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Piggy Trunk - Inventory Report',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.Text(
                  'Generated: $formattedDate',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('64748B'),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: tableBorderColor, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  adminEmail != null && adminEmail.isNotEmpty
                      ? 'Exported by: $adminEmail'
                      : 'Piggy Trunk Swine Management System',
                  style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('94A3B8')),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('64748B'),
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) => [
          pw.SizedBox(height: 10),
          // Metric Summary Cards
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: lightBgColor,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: tableBorderColor),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildPdfMetricItem('Total Products', '$totalProducts Products', primaryColor),
                _buildPdfMetricItem('Total Units in Stock', '$totalUnits units', primaryColor),
                _buildPdfMetricItem(
                  'Total Valuation',
                  'PHP ${totalValuation.toStringAsFixed(2)}',
                  successColor,
                ),
                _buildPdfMetricItem('Low Stock Alert', '$lowStockCount items', warningColor),
                _buildPdfMetricItem('Out of Stock', '$outOfStockCount items', accentColor),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Inventory Table
          pw.TableHelper.fromTextArray(
            headers: [
              '#',
              'Product Name',
              'Category',
              'Unit Price',
              'Stock',
              'Sold',
              'Total Value',
              'Status',
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.center,
            },
            headerAlignments: {
              0: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.center,
            },
            cellStyle: pw.TextStyle(fontSize: 8.5, color: darkTextColor),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
            oddRowDecoration: pw.BoxDecoration(color: lightBgColor),
            data: List<List<dynamic>>.generate(products.length, (index) {
              final p = products[index];
              final totalValue = p.price * p.units;
              String status;
              if (p.isArchived) {
                status = 'Archived';
              } else if (p.units <= 0) {
                status = 'Out of Stock';
              } else if (p.units <= 10) {
                status = 'Low Stock';
              } else {
                status = 'In Stock';
              }

              return [
                (index + 1).toString(),
                p.name,
                p.category,
                'PHP ${p.price.toStringAsFixed(2)}',
                p.units.toString(),
                p.sold.toString(),
                'PHP ${totalValue.toStringAsFixed(2)}',
                status,
              ];
            }),
          ),
        ],
      ),
    );

    final pdfBytes = await pdf.save();
    final dateSuffix =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final filename = '${filenamePrefix}_$dateSuffix.pdf';

    WebFileDownloader.downloadBytes(
      bytes: pdfBytes,
      filename: filename,
      mimeType: 'application/pdf',
    );
  }

  static pw.Widget _buildPdfMetricItem(String label, String value, PdfColor valueColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColor.fromHex('64748B'),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
