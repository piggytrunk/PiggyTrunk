import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';

enum ToastType { success, error, info, warning }

class PiggyToast {
  static OverlayEntry? _currentEntry;
  static _PiggyToastState? _currentState;

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.info,
    Duration duration = const Duration(milliseconds: 3000),
    VoidCallback? onTap,
  }) {
    // Dismiss any existing toast immediately
    dismiss();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _PiggyToastWidget(
        key: GlobalKey<_PiggyToastState>(),
        message: message,
        title: title,
        type: type,
        duration: duration,
        onTap: onTap,
        onDismissed: () {
          if (_currentEntry == entry) {
            _currentEntry?.remove();
            _currentEntry = null;
            _currentState = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.success,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.error,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.info,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.warning,
      duration: duration,
    );
  }

  static void dismiss() {
    _currentState?.dismiss();
    _currentEntry?.remove();
    _currentEntry = null;
    _currentState = null;
  }
}

class _PiggyToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final ToastType type;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback onDismissed;

  const _PiggyToastWidget({
    super.key,
    required this.message,
    this.title,
    required this.type,
    required this.duration,
    this.onTap,
    required this.onDismissed,
  });

  @override
  State<_PiggyToastWidget> createState() => _PiggyToastState();
}

class _PiggyToastState extends State<_PiggyToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    PiggyToast._currentState = this;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 280),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        dismiss();
      }
    });
  }

  void dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    // Toast Type Styling Tokens
    Color accentColor;
    Color iconBgColor;
    IconData iconData;

    switch (widget.type) {
      case ToastType.success:
        accentColor = isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess;
        iconBgColor = isDark
            ? PiggyTrunkTheme.ptSuccessDark.withValues(alpha: 0.18)
            : PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.12);
        iconData = Icons.check_circle_rounded;
        break;
      case ToastType.error:
        accentColor = isDark ? PiggyTrunkTheme.ptAccentDark : PiggyTrunkTheme.ptAccent;
        iconBgColor = isDark
            ? PiggyTrunkTheme.ptAccentDark.withValues(alpha: 0.18)
            : PiggyTrunkTheme.ptAccent.withValues(alpha: 0.12);
        iconData = Icons.error_rounded;
        break;
      case ToastType.warning:
        accentColor = isDark ? PiggyTrunkTheme.ptInProgressDark : PiggyTrunkTheme.ptInProgress;
        iconBgColor = isDark
            ? PiggyTrunkTheme.ptInProgressDark.withValues(alpha: 0.18)
            : PiggyTrunkTheme.ptInProgress.withValues(alpha: 0.12);
        iconData = Icons.warning_amber_rounded;
        break;
      case ToastType.info:
        accentColor = isDark ? const Color(0xFF5BA4E5) : PiggyTrunkTheme.ptPrimary;
        iconBgColor = isDark
            ? const Color(0xFF5BA4E5).withValues(alpha: 0.18)
            : PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.10);
        iconData = Icons.info_outline_rounded;
        break;
    }

    final cardBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : PiggyTrunkTheme.ptSurface;
    final cardBorder = isDark ? PiggyTrunkTheme.ptBorderDark : PiggyTrunkTheme.ptBorder;
    final titleTextColor = isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText;
    final messageTextColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return SlideTransition(
              position: _offsetAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: child,
                ),
              ),
            );
          },
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -5) {
                dismiss();
              }
            },
            onTap: () {
              if (widget.onTap != null) {
                widget.onTap!();
              }
              dismiss();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                    blurRadius: 18,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: accentColor.withValues(alpha: isDark ? 0.15 : 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Floating Island Icon Badge
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(alpha: isDark ? 0.4 : 0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        iconData,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content (Title & Message)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.title != null && widget.title!.isNotEmpty) ...[
                          Text(
                            widget.title!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: titleTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          widget.message,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: (widget.title != null && widget.title!.isNotEmpty) ? 12 : 13,
                            fontWeight: (widget.title != null && widget.title!.isNotEmpty)
                                ? FontWeight.w500
                                : FontWeight.w600,
                            color: (widget.title != null && widget.title!.isNotEmpty)
                                ? messageTextColor
                                : titleTextColor,
                            height: 1.25,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Close Button
                  GestureDetector(
                    onTap: dismiss,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : PiggyTrunkTheme.ptBorder.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
