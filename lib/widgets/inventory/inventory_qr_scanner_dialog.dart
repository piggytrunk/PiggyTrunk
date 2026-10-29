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
  final ValueChanged<String>? onNewBarcodeScanned;

  const InventoryQrScannerDialog({
    super.key,
    required this.products,
    required this.onProductScanned,
    this.onNewBarcodeScanned,
  });

  static void show(
    BuildContext context, {
    required List<Product> products,
    required ValueChanged<Product> onProductScanned,
    ValueChanged<String>? onNewBarcodeScanned,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => InventoryQrScannerDialog(
        products: products,
        onProductScanned: onProductScanned,
        onNewBarcodeScanned: onNewBarcodeScanned,
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
  html.EventListener? _barcodeEventListener;
  html.EventListener? _cameraStartedListener;
  html.EventListener? _cameraErrorListener;
  bool _isCameraActive = false;
  bool _isCameraStarting = false;
  String? _cameraStatusMessage;
  String? _activeCameraLabel;
  int _availableCameraCount = 0;

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

      _barcodeEventListener = (html.Event event) {
        if (event is html.CustomEvent && event.detail != null) {
          final code = event.detail.toString().trim();
          if (code.isNotEmpty && mounted) {
            _stopWebCamera();
            _processScannedCode(code);
          }
        }
      };

      _cameraStartedListener = (html.Event event) {
        if (!mounted) return;
        String label = 'Laptop Camera';
        int count = 1;
        if (event is html.CustomEvent && event.detail != null) {
          final detail = event.detail.toString();
          final parts = detail.split('||');
          if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
            label = parts[0].trim();
          }
          if (parts.length > 1) {
            count = int.tryParse(parts[1]) ?? 1;
          }
        }
        setState(() {
          _isCameraStarting = false;
          _isCameraActive = true;
          _cameraStatusMessage = null;
          _activeCameraLabel = label;
          _availableCameraCount = count;
        });
      };

      _cameraErrorListener = (html.Event event) {
        if (!mounted) return;
        String err = 'Camera permission denied or unavailable.';
        if (event is html.CustomEvent && event.detail != null) {
          err = event.detail.toString();
        }
        setState(() {
          _isCameraStarting = false;
          _isCameraActive = false;
          _cameraStatusMessage = err;
        });
      };

      html.window.addEventListener('pt-barcode-scanned', _barcodeEventListener);
      html.window.addEventListener('pt-camera-started', _cameraStartedListener);
      html.window.addEventListener('pt-camera-error', _cameraErrorListener);
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

  void _startWebCamera({bool switchNext = false}) {
    if (!kIsWeb) return;
    setState(() {
      _isCameraStarting = true;
      _cameraStatusMessage = switchNext ? 'Switching camera...' : 'Starting laptop camera...';
      _errorMessage = null;
    });

    try {
      final doSwitch = switchNext ? 'true' : 'false';
      final script = '''
        (function() {
          // 1. Bridge document.getElementById into Flutter Web's Shadow DOM so Html5Qrcode finds the viewfinder div
          if (!window.__ptPatchedGetElementById) {
            window.__ptPatchedGetElementById = true;
            var origGetById = document.getElementById.bind(document);
            document.getElementById = function(id) {
              var el = origGetById(id);
              if (el) return el;
              var fv = document.querySelector('flutter-view');
              if (fv && fv.shadowRoot) {
                el = fv.shadowRoot.getElementById(id);
                if (el) return el;
              }
              var pvs = document.querySelectorAll('flt-platform-view');
              for (var i = 0; i < pvs.length; i++) {
                if (pvs[i].shadowRoot) {
                  el = pvs[i].shadowRoot.getElementById(id);
                  if (el) return el;
                }
              }
              return null;
            };
          }

          function ensureScannerLibrary() {
            if (typeof Html5Qrcode !== 'undefined') {
              return Promise.resolve();
            }
            return new Promise(function(resolve, reject) {
              var s = document.createElement('script');
              s.src = 'html5-qrcode.min.js';
              s.onload = function() {
                if (typeof Html5Qrcode !== 'undefined') {
                  resolve();
                } else {
                  reject(new Error('Library unavailable'));
                }
              };
              s.onerror = function() {
                var s2 = document.createElement('script');
                s2.src = 'https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js';
                s2.onload = function() { resolve(); };
                s2.onerror = function() { reject(new Error('Failed to load scanner library')); };
                document.head.appendChild(s2);
              };
              document.head.appendChild(s);
            });
          }

          function isLaptopBuiltInCam(label) {
            var l = (label || '').toLowerCase();
            return l.indexOf('integrated') !== -1 ||
                   l.indexOf('webcam') !== -1 ||
                   l.indexOf('uvc') !== -1 ||
                   l.indexOf('user facing') !== -1 ||
                   l.indexOf('front') !== -1 ||
                   l.indexOf('hd camera') !== -1 ||
                   l.indexOf('usb') !== -1 ||
                   l.indexOf('realtek') !== -1 ||
                   l.indexOf('chicony') !== -1 ||
                   l.indexOf('sunplus') !== -1 ||
                   l.indexOf('bison') !== -1;
          }

          function isPhoneOrVirtualCam(label) {
            var l = (label || '').toLowerCase();
            return l.indexOf('poco') !== -1 ||
                   l.indexOf('redmi') !== -1 ||
                   l.indexOf('xiaomi') !== -1 ||
                   l.indexOf('samsung') !== -1 ||
                   l.indexOf('galaxy') !== -1 ||
                   l.indexOf('iphone') !== -1 ||
                   l.indexOf('realme') !== -1 ||
                   l.indexOf('oppo') !== -1 ||
                   l.indexOf('vivo') !== -1 ||
                   l.indexOf('infinix') !== -1 ||
                   l.indexOf('tecno') !== -1 ||
                   l.indexOf('huawei') !== -1 ||
                   l.indexOf('honor') !== -1 ||
                   l.indexOf('pixel') !== -1 ||
                   l.indexOf('oneplus') !== -1 ||
                   l.indexOf('5g') !== -1 ||
                   l.indexOf('phone') !== -1 ||
                   l.indexOf('link to windows') !== -1 ||
                   l.indexOf('windows virtual') !== -1 ||
                   l.indexOf('virtual') !== -1 ||
                   l.indexOf('droidcam') !== -1 ||
                   l.indexOf('iriun') !== -1 ||
                   l.indexOf('epoccam') !== -1 ||
                   l.indexOf('continuity') !== -1 ||
                   l.indexOf('mobile') !== -1;
          }

          function getLaptopCamerasOnly() {
            return navigator.mediaDevices.enumerateDevices().then(function(allDevices) {
              var videoInputs = allDevices.filter(function(d) {
                return d.kind === 'videoinput';
              });
              var hasLabels = videoInputs.some(function(d) {
                return d.label && d.label.trim().length > 0;
              });

              if (hasLabels) {
                // Totally remove any Phone Link / mobile / virtual cameras
                var laptopOnly = videoInputs.filter(function(d) {
                  return !isPhoneOrVirtualCam(d.label);
                });
                return laptopOnly.map(function(d) {
                  return { id: d.deviceId, label: d.label };
                });
              }

              // If labels are hidden before permission, request front/user camera (laptop webcam)
              // instead of generic {video: true} so Windows does not trigger Phone Link
              return navigator.mediaDevices.getUserMedia({
                video: { facingMode: 'user' },
                audio: false
              }).then(function(stream) {
                stream.getTracks().forEach(function(t) { t.stop(); });
                return navigator.mediaDevices.enumerateDevices();
              }).then(function(unlockedDevices) {
                var laptopOnly = unlockedDevices.filter(function(d) {
                  return d.kind === 'videoinput' && !isPhoneOrVirtualCam(d.label);
                });
                return laptopOnly.map(function(d) {
                  return { id: d.deviceId, label: d.label };
                });
              });
            });
          }

          function stopCurrentScanner() {
            if (window.__ptNativeTimer) {
              clearInterval(window.__ptNativeTimer);
              window.__ptNativeTimer = null;
            }
            if (window._currentScanner) {
              var old = window._currentScanner;
              window._currentScanner = null;
              try {
                return old.stop().catch(function(){}).then(function() {
                  try { old.clear(); } catch (_) {}
                });
              } catch (e) {}
            }
            return Promise.resolve();
          }

          ensureScannerLibrary().then(function() {
            return stopCurrentScanner();
          }).then(function() {
            return getLaptopCamerasOnly();
          }).then(function(devices) {
            if (!devices || devices.length === 0) {
              window.dispatchEvent(new CustomEvent('pt-camera-error', {
                detail: 'No built-in laptop webcam found (Phone camera disabled). Check if your laptop webcam is enabled.'
              }));
              return;
            }

            // Sort remaining laptop/USB cameras so Integrated Webcam is first
            var sorted = devices.slice().sort(function(a, b) {
              var aScore = isLaptopBuiltInCam(a.label) ? 0 : 1;
              var bScore = isLaptopBuiltInCam(b.label) ? 0 : 1;
              return aScore - bScore;
            });

            if (typeof window.__ptCamIndex !== 'number') {
              window.__ptCamIndex = 0;
            }
            if ($doSwitch) {
              window.__ptCamIndex = (window.__ptCamIndex + 1) % sorted.length;
            } else {
              window.__ptCamIndex = 0;
            }

            var chosen = sorted[window.__ptCamIndex] || sorted[0];
            var chosenLabel = chosen.label || ('Camera ' + (window.__ptCamIndex + 1));

            var container = document.getElementById("$_containerDivId");
            if (!container) {
              window.dispatchEvent(new CustomEvent('pt-camera-error', {
                detail: 'Camera view initializing. Please click Turn On Camera again.'
              }));
              return;
            }

            var scanner = new Html5Qrcode("$_containerDivId");
            window._currentScanner = scanner;

            var config = {
              fps: 20,
              disableFlip: false,
              experimentalFeatures: {
                useBarCodeDetectorIfSupported: true
              },
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
              { deviceId: { exact: chosen.id } },
              config,
              function onScanSuccess(decodedText) {
                if (decodedText) {
                  window.dispatchEvent(new CustomEvent('pt-barcode-scanned', {
                    detail: decodedText
                  }));
                }
              },
              function onScanFailure(_) {}
            ).then(function() {
              // Style the internal video so it fills the viewfinder cleanly
              var videoEl = container.querySelector('video');
              if (videoEl) {
                videoEl.style.width = '100%';
                videoEl.style.height = '100%';
                videoEl.style.objectFit = 'cover';
              }

              // Also run native BarcodeDetector in parallel if supported by browser
              if ('BarcodeDetector' in window && videoEl) {
                try {
                  var detector = new BarcodeDetector({
                    formats: ['code_128', 'ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_39', 'qr_code']
                  });
                  window.__ptNativeTimer = setInterval(function() {
                    if (!videoEl || videoEl.readyState < 2) return;
                    detector.detect(videoEl).then(function(codes) {
                      if (codes && codes.length > 0 && codes[0].rawValue) {
                        window.dispatchEvent(new CustomEvent('pt-barcode-scanned', {
                          detail: codes[0].rawValue
                        }));
                      }
                    }).catch(function(){});
                  }, 200);
                } catch (_) {}
              }

              window.dispatchEvent(new CustomEvent('pt-camera-started', {
                detail: chosenLabel + '||' + sorted.length
              }));
            }).catch(function(err) {
              window.dispatchEvent(new CustomEvent('pt-camera-error', {
                detail: 'Could not start ' + chosenLabel + ': ' + (err && err.message ? err.message : String(err))
              }));
            });
          }).catch(function(err) {
            window.dispatchEvent(new CustomEvent('pt-camera-error', {
              detail: 'Camera permission denied or unavailable.'
            }));
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

  void _stopMediaTracksOnly() {
    try {
      final script = '''
        (function() {
          if (window.__ptNativeTimer) {
            clearInterval(window.__ptNativeTimer);
            window.__ptNativeTimer = null;
          }
          if (window._currentScanner) {
            var old = window._currentScanner;
            window._currentScanner = null;
            try {
              old.stop().catch(function(){}).finally(function() {
                try { old.clear(); } catch (_) {}
              });
            } catch (e) {}
          }
        })();
      ''';
      js.context.callMethod('eval', [script]);
    } catch (_) {}
  }

  void _stopWebCamera() {
    if (!kIsWeb) return;
    _stopMediaTracksOnly();
    if (mounted) {
      setState(() {
        _isCameraActive = false;
        _isCameraStarting = false;
      });
    }
  }

  void _scanFromImageFile() {
    if (!kIsWeb) return;
    setState(() {
      _errorMessage = null;
      _cameraStatusMessage = null;
    });

    try {
      final script = '''
        (function() {
          function ensureScannerLibrary() {
            if (typeof Html5Qrcode !== 'undefined') {
              return Promise.resolve();
            }
            return new Promise(function(resolve, reject) {
              var s = document.createElement('script');
              s.src = 'html5-qrcode.min.js';
              s.onload = function() { resolve(); };
              s.onerror = function() {
                var s2 = document.createElement('script');
                s2.src = 'https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js';
                s2.onload = function() { resolve(); };
                s2.onerror = function() { reject(new Error('Failed to load scanner library')); };
                document.head.appendChild(s2);
              };
              document.head.appendChild(s);
            });
          }

          var input = document.createElement('input');
          input.type = 'file';
          input.accept = 'image/*';
          input.onchange = function(e) {
            var file = e.target.files && e.target.files[0];
            if (!file) return;

            ensureScannerLibrary().then(function() {
              // 1. Try native BarcodeDetector on ImageBitmap first if available
              if ('BarcodeDetector' in window && typeof createImageBitmap === 'function') {
                createImageBitmap(file).then(function(bmp) {
                  var detector = new BarcodeDetector({
                    formats: ['code_128', 'ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_39', 'qr_code']
                  });
                  return detector.detect(bmp);
                }).then(function(codes) {
                  if (codes && codes.length > 0 && codes[0].rawValue) {
                    window.dispatchEvent(new CustomEvent('pt-barcode-scanned', {
                      detail: codes[0].rawValue
                    }));
                    return;
                  }
                  scanFileWithHtml5Qr(file);
                }).catch(function() {
                  scanFileWithHtml5Qr(file);
                });
              } else {
                scanFileWithHtml5Qr(file);
              }
            }).catch(function(err) {
              window.dispatchEvent(new CustomEvent('pt-camera-error', {
                detail: 'Could not read image file: ' + (err && err.message ? err.message : String(err))
              }));
            });
          };
          input.click();

          function scanFileWithHtml5Qr(file) {
            var workerId = '__pt_file_qr_worker';
            var workerDiv = document.getElementById(workerId);
            if (!workerDiv) {
              workerDiv = document.createElement('div');
              workerDiv.id = workerId;
              workerDiv.style.position = 'fixed';
              workerDiv.style.left = '-9999px';
              workerDiv.style.top = '-9999px';
              workerDiv.style.width = '800px';
              workerDiv.style.height = '600px';
              document.body.appendChild(workerDiv);
            }
            var fileScanner = new Html5Qrcode(workerId);
            fileScanner.scanFile(file, false).then(function(decodedText) {
              if (decodedText) {
                window.dispatchEvent(new CustomEvent('pt-barcode-scanned', {
                  detail: decodedText
                }));
              }
            }).catch(function() {
              window.dispatchEvent(new CustomEvent('pt-camera-error', {
                detail: 'No valid barcode or QR code found in the selected image.'
              }));
            });
          }
        })();
      ''';
      js.context.callMethod('eval', [script]);
    } catch (e) {
      setState(() {
        _cameraStatusMessage = 'Failed to scan image: $e';
      });
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      if (_barcodeEventListener != null) {
        html.window.removeEventListener('pt-barcode-scanned', _barcodeEventListener);
      }
      if (_cameraStartedListener != null) {
        html.window.removeEventListener('pt-camera-started', _cameraStartedListener);
      }
      if (_cameraErrorListener != null) {
        html.window.removeEventListener('pt-camera-error', _cameraErrorListener);
      }
    }
    _stopMediaTracksOnly();
    _laserAnimCtrl.dispose();
    _manualCodeCtrl.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  String _fallbackBarcodeForProduct(Product p) {
    if (p.barcode != null && p.barcode!.trim().isNotEmpty) {
      return p.barcode!.trim();
    }
    final cleanId = p.id.replaceAll('-', '');
    final shortId = cleanId.length > 8 ? cleanId.substring(0, 8).toUpperCase() : cleanId.toUpperCase();
    return 'PIG-$shortId';
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
      matched = widget.products.firstWhere((p) {
        final fallbackCode = _fallbackBarcodeForProduct(p).toLowerCase();
        return (p.barcode != null && p.barcode!.toLowerCase() == targetId.toLowerCase()) ||
            fallbackCode == targetId.toLowerCase() ||
            fallbackCode == clean.toLowerCase() ||
            p.id.toLowerCase() == targetId.toLowerCase() ||
            p.name.toLowerCase() == clean.toLowerCase() ||
            (p.barcode != null && p.barcode!.toLowerCase() == clean.toLowerCase());
      });
    } catch (_) {
      matched = null;
    }

    if (matched != null) {
      Navigator.of(context).pop();
      AppToast.success(context, 'Identified Product: ${matched.name}');
      widget.onProductScanned(matched);
    } else if (widget.onNewBarcodeScanned != null) {
      Navigator.of(context).pop();
      AppToast.info(
        context,
        'New Barcode Scanned ($targetId) — Fill in details to add this product!',
      );
      widget.onNewBarcodeScanned!(targetId);
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
                    // Wrapped in IgnorePointer so it never intercepts clicks on Flutter overlay buttons
                    if (kIsWeb)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: _isCameraActive ? 1.0 : 0.01,
                            child: HtmlElementView(viewType: _viewType),
                          ),
                        ),
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
                      if (_isCameraStarting || _cameraStatusMessage != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isCameraStarting) ...[
                                  const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  const SizedBox(height: 10),
                                  Text(
                                    _cameraStatusMessage ?? 'Starting Camera...',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                                  ),
                                ] else if (_cameraStatusMessage != null) ...[
                                  Text(
                                    _cameraStatusMessage!,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: PiggyTrunkTheme.ptAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
                        left: 10,
                        right: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Active Camera Label / Switch Camera Button
                            Flexible(
                              child: InkWell(
                                onTap: _availableCameraCount > 1
                                    ? () => _startWebCamera(switchNext: true)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _availableCameraCount > 1
                                            ? Icons.cameraswitch_rounded
                                            : Icons.videocam_rounded,
                                        size: 14,
                                        color: PiggyTrunkTheme.ptSuccess,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          _availableCameraCount > 1
                                              ? '${_activeCameraLabel ?? "Laptop Camera"} (Switch)'
                                              : (_activeCameraLabel ?? 'Laptop Camera'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Stop Camera Button
                            InkWell(
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
                          ],
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
                Text(
                  'Scan or Enter Barcode:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
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
                          hintText: 'e.g. 480016624912',
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isCameraActive ? _stopWebCamera : _startWebCamera,
                        icon: Icon(
                          _isCameraActive ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _isCameraActive ? 'Stop Camera' : 'Turn On Camera',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCameraActive
                              ? PiggyTrunkTheme.ptAccent
                              : PiggyTrunkTheme.ptSuccess,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _scanFromImageFile,
                        icon: const Icon(Icons.image_search_rounded, size: 17),
                        label: Text(
                          'Scan Image',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                          side: BorderSide(color: cardBorder, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
          ],
        ),
      ),
    );
  }
}
