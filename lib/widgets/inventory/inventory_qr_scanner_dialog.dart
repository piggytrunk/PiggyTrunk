// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Standard Flutter Web interop
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

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

  // Web Camera Scanner State
  static int _viewIdCounter = 0;
  late final String _viewType;
  late final String _containerDivId;
  bool _isCameraActive = false;
  bool _isCameraStarting = false;
  String? _cameraStatusMessage;

  @override
  void initState() {
    super.initState();
    _viewIdCounter++;
    _containerDivId = 'qr-reader-$_viewIdCounter';
    _viewType = 'web-barcode-scanner-$_viewIdCounter';

    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (kIsWeb) {
      _registerWebView();
    }

    // Auto-focus input for USB scanner / keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  void _registerWebView() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final div = html.DivElement()
        ..id = _containerDivId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#0f172a'
        ..style.borderRadius = '14px'
        ..style.overflow = 'hidden';
      return div;
    });
  }

  void _startWebCamera() {
    if (!kIsWeb) return;
    setState(() {
      _isCameraStarting = true;
      _cameraStatusMessage = 'Requesting camera access...';
    });

    try {
      // Register callbacks on window
      js.context['__onBarcodeScannedDart'] = (String text) {
        _stopWebCamera();
        _processScannedCode(text);
      };

      js.context['__onCameraStartedDart'] = () {
        if (mounted) {
          setState(() {
            _isCameraStarting = false;
            _isCameraActive = true;
            _cameraStatusMessage = null;
          });
        }
      };

      js.context['__onCameraErrorDart'] = (String error) {
        if (mounted) {
          setState(() {
            _isCameraStarting = false;
            _isCameraActive = false;
            _cameraStatusMessage = 'Camera error or permission denied: $error';
          });
        }
      };

      // JS Launcher
      final script = '''
        (function() {
          if (typeof Html5Qrcode === 'undefined') {
            console.error('Html5Qrcode library not found');
            if (window.__onCameraErrorDart) {
              window.__onCameraErrorDart('Library not loaded. Please reload page.');
            }
            return;
          }

          try {
            if (window._currentScanner) {
              window._currentScanner.stop().catch(function(){}).finally(function() {
                window._currentScanner.clear();
              });
            }
          } catch(e) {}

          var scanner = new Html5Qrcode("$_containerDivId");
          window._currentScanner = scanner;

          var config = {
            fps: 15,
            qrbox: { width: 260, height: 160 },
            formatsToSupport: [
              Html5QrcodeSupportedFormats.CODE_128,
              Html5QrcodeSupportedFormats.EAN_13,
              Html5QrcodeSupportedFormats.EAN_8,
              Html5QrcodeSupportedFormats.UPC_A,
              Html5QrcodeSupportedFormats.UPC_E,
              Html5QrcodeSupportedFormats.CODE_39,
              Html5QrcodeSupportedFormats.QR_CODE
            ]
          };

          scanner.start(
            { facingMode: "environment" },
            config,
            function onScanSuccess(decodedText) {
              if (window.__onBarcodeScannedDart) {
                window.__onBarcodeScannedDart(decodedText);
              }
            },
            function onScanFailure(error) {
              // Ignore frame decode errors
            }
          ).then(function() {
            if (window.__onCameraStartedDart) {
              window.__onCameraStartedDart();
            }
          }).catch(function(err) {
            console.error("Camera start error: ", err);
            if (window.__onCameraErrorDart) {
              window.__onCameraErrorDart(err ? err.toString() : 'Camera access denied');
            }
          });
        })();
      ''';

      js.context.callMethod('eval', [script]);
    } catch (e) {
      setState(() {
        _isCameraStarting = false;
        _cameraStatusMessage = 'Failed to start camera: $e';
      });
    }
  }

  void _stopWebCamera() {
    if (!kIsWeb) return;
    try {
      final script = '''
        if (window._currentScanner) {
          window._currentScanner.stop().catch(function(){}).finally(function() {
            window._currentScanner.clear();
            window._currentScanner = null;
          });
        }
      ''';
      js.context.callMethod('eval', [script]);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isCameraActive = false;
        _isCameraStarting = false;
      });
    }
  }

  @override
  void dispose() {
    _stopWebCamera();
    _laserAnimCtrl.dispose();
    _manualCodeCtrl.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _processScannedCode(String rawCode) {
    final clean = rawCode.trim();
    if (clean.isEmpty) return;

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
        width: 440,
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
        padding: const EdgeInsets.all(22),
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
                      'Product Barcode Scanner',
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
            const SizedBox(height: 14),

            // Live Camera Viewfinder or Simulated Laser Preview
            Container(
              height: 210,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isCameraActive ? PiggyTrunkTheme.ptSuccess : const Color(0xFF334155),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The Real Live Web Camera Stream View (HTML5 Element)
                    if (kIsWeb)
                      Positioned.fill(
                        child: HtmlElementView(viewType: _viewType),
                      ),

                    // Placeholder graphic when camera is off
                    if (!_isCameraActive) ...[
                      Opacity(
                        opacity: 0.3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(28, (i) {
                            final isThick = i % 3 == 0;
                            return Container(
                              width: isThick ? 4.5 : 2.0,
                              height: 80,
                              margin: const EdgeInsets.symmetric(horizontal: 2.2),
                              color: Colors.white,
                            );
                          }),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isCameraStarting) ...[
                              const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              const SizedBox(height: 10),
                              Text(
                                _cameraStatusMessage ?? 'Starting Camera...',
                                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                              ),
                            ] else ...[
                              ElevatedButton.icon(
                                onPressed: _startWebCamera,
                                icon: const Icon(Icons.videocam_rounded, size: 18),
                                label: const Text('Turn On Camera'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PiggyTrunkTheme.ptSuccess,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Or use hardware USB scanner / type below',
                                style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Red Laser Animation Line
                    AnimatedBuilder(
                      animation: _laserAnimCtrl,
                      builder: (context, child) {
                        return Positioned(
                          top: 25 + (_laserAnimCtrl.value * 155),
                          left: 16,
                          right: 16,
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

                    // Camera Controls Overlay
                    if (_isCameraActive)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: InkWell(
                          onTap: _stopWebCamera,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'Stop Camera',
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

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
                      'Auto-detects USB scanner',
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
              const SizedBox(height: 8),
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

            const SizedBox(height: 12),
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
