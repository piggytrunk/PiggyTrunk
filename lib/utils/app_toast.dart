import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ToastType { success, error, warning, info }

/// Modern, sleek Top-Right Floating Toast notification system for Admin Web.
class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Show a floating toast with custom message, title, and type.
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.info,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    _dismissCurrent();

    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        title: title,
        type: type,
        duration: duration,
        onDismiss: () {
          if (_currentEntry == entry) {
            _dismissCurrent();
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration + const Duration(milliseconds: 350), () {
      if (_currentEntry == entry) {
        _dismissCurrent();
      }
    });
  }

  static void success(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.success,
      duration: duration ?? const Duration(milliseconds: 3000),
    );
  }

  static void error(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.error,
      duration: duration ?? const Duration(milliseconds: 4200),
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.warning,
      duration: duration ?? const Duration(milliseconds: 3500),
    );
  }

  static void info(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.info,
      duration: duration ?? const Duration(milliseconds: 3000),
    );
  }

  static void _dismissCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    this.title,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.25, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _controller.forward();

    Timer(widget.duration, () {
      if (mounted) {
        _handleDismiss();
      }
    });
  }

  void _handleDismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getAccentColor() {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF10B981);
      case ToastType.error:
        return const Color(0xFFEF4444);
      case ToastType.warning:
        return const Color(0xFFF59E0B);
      case ToastType.info:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_outline_rounded;
      case ToastType.warning:
        return Icons.warning_amber_rounded;
      case ToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  String _getDefaultTitle() {
    switch (widget.type) {
      case ToastType.success:
        return 'Success';
      case ToastType.error:
        return 'Error';
      case ToastType.warning:
        return 'Warning';
      case ToastType.info:
        return 'Notice';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final topPadding = mediaQuery.padding.top;
    final isMobile = screenWidth < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _getAccentColor();

    final bgColor = isDark ? const Color(0xFF1A2638) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3F58) : const Color(0xFFE2E8F0);
    final textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final resolvedTitle = widget.title ?? _getDefaultTitle();
    final topOffset = topPadding + (isMobile ? 12.0 : 20.0);

    return Positioned(
      top: topOffset,
      right: isMobile ? 16 : 24,
      left: isMobile ? 16 : null,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: isMobile
              ? Tween<Offset>(begin: const Offset(0.0, -0.4), end: Offset.zero)
                  .animate(_fadeAnimation)
              : _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 400,
                minWidth: isMobile ? 0 : 320,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Left Accent Color Bar
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: Container(color: accentColor),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getIcon(),
                              size: 18,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  resolvedTitle,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.message,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: subtitleColor,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: _handleDismiss,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: subtitleColor,
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
          ),
        ),
      ),
    );
  }
}
