import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/services/app_update_service.dart';
import '../utils/app_strings.dart';

class CheckForUpdatesTile extends StatefulWidget {
  final bool isDark;
  final Color labelColor;
  final Color subtitleColor;
  final BorderRadius? borderRadius;
  final double? horizontalPadding;
  final double? verticalPadding;

  const CheckForUpdatesTile({
    super.key,
    required this.isDark,
    required this.labelColor,
    required this.subtitleColor,
    this.borderRadius,
    this.horizontalPadding,
    this.verticalPadding,
  });

  @override
  State<CheckForUpdatesTile> createState() => _CheckForUpdatesTileState();
}

class _CheckForUpdatesTileState extends State<CheckForUpdatesTile> {
  bool _isChecking = false;
  String _currentVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final v = await AppUpdateService.instance.getCurrentVersion();
    if (mounted) {
      setState(() {
        _currentVersion = v;
      });
    }
  }

  Future<void> _handleCheck() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
    });

    try {
      await AppUpdateService.instance.promptUpdateIfAvailable(
        context,
        isManualCheck: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    const brandColor = Color(0xFF18314F);
    final hPad = widget.horizontalPadding ?? 16.0;
    final vPad = widget.verticalPadding ?? 14.0;
    final radius = widget.borderRadius ?? const BorderRadius.vertical(bottom: Radius.circular(18));

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: _isChecking ? null : _handleCheck,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Row(
            children: [
              // Icon Box
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.09)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : const Color(0xFFDBEAFE),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.system_update_rounded,
                    color: widget.isDark ? Colors.white : brandColor,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.checkForUpdates,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: widget.labelColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isChecking
                          ? strings.checkingForUpdates
                          : '${strings.versionLabel} $_currentVersion',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: widget.subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Trailing action / badge / spinner
              if (_isChecking)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isDark ? Colors.white70 : brandColor,
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'v$_currentVersion',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: widget.subtitleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: widget.subtitleColor,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
