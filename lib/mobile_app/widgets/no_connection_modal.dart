import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../services/connectivity_service.dart';

bool _isModalOpen = false;

/// Shows a branded "No Internet Connection" bottom sheet.
/// [onRetry] runs after "Try Again" confirms the connection is back.
Future<void> showNoConnectionModal(BuildContext context, {VoidCallback? onRetry}) async {
  if (_isModalOpen) return;
  _isModalOpen = true;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    constraints: const BoxConstraints(maxWidth: 480),
    barrierColor: PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.45),
    builder: (ctx) => _NoConnectionDialog(onRetry: onRetry),
  );
  _isModalOpen = false;
}

class _NoConnectionDialog extends StatefulWidget {
  const _NoConnectionDialog({this.onRetry});
  final VoidCallback? onRetry;

  @override
  State<_NoConnectionDialog> createState() => _NoConnectionDialogState();
}

class _NoConnectionDialogState extends State<_NoConnectionDialog> {
  bool _checking = false;
  bool _stillOffline = false;

  Future<void> _retry() async {
    setState(() {
      _checking = true;
      _stillOffline = false;
    });
    final online = await ConnectivityService.refresh();
    if (!mounted) return;
    if (online) {
      Navigator.of(context).pop();
      widget.onRetry?.call();
    } else {
      setState(() {
        _checking = false;
        _stillOffline = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface;
    final border = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final text = isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText;
    final muted = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final accent = isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent;
    final primaryBtn = isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptPrimary;
    final secondaryText = isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptPrimary;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 10, 24, 20 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.10),
                      border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.5),
                    ),
                    child: Icon(Icons.wifi_off_rounded, size: 34, color: accent),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No Internet Connection',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.04,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your Wi-Fi or mobile data and try again.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      color: muted,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    child: _stillOffline
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Still offline. Please reconnect and try again.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _checking ? null : _retry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBtn,
                        disabledBackgroundColor: primaryBtn.withValues(alpha: 0.7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
                      label: Text(
                        _checking ? 'Checking...' : 'Try Again',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _checking ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: border, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: secondaryText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
