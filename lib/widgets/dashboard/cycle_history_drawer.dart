import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class CycleHistoryDrawer {
  static void show({
    required BuildContext context,
    required List<Map<String, dynamic>> completedRaisers,
    VoidCallback? onNavigateToBatches,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    if (isMobile) {
      _showBottomSheet(context, completedRaisers, onNavigateToBatches);
    } else {
      _showSideDrawer(context, completedRaisers, onNavigateToBatches);
    }
  }

  static void _showBottomSheet(
    BuildContext context,
    List<Map<String, dynamic>> completedRaisers,
    VoidCallback? onNavigateToBatches,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? PiggyTrunkTheme.ptSurfaceDark : Colors.white;
    final cardBorder = isDark
        ? PiggyTrunkTheme.ptBorderDark
        : PiggyTrunkTheme.ptBorder;
    final titleColor = isDark
        ? PiggyTrunkTheme.ptTextDark
        : PiggyTrunkTheme.ptText;
    final hintText = isDark
        ? PiggyTrunkTheme.ptMutedDark
        : PiggyTrunkTheme.ptMuted;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: cardBorder, width: 1.2)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: hintText.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                            : const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: isDark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Finished Lifecycles',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          Text(
                            'Batches that completed all feeding stages',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: hintText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: Icon(
                        Icons.close_rounded,
                        color: hintText,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Divider(color: cardBorder.withValues(alpha: 0.5), height: 1),
              Flexible(
                child: _buildDrawerContent(
                  context: sheetContext,
                  completedRaisers: completedRaisers,
                  isDark: isDark,
                  cardBorder: cardBorder,
                  titleColor: titleColor,
                  hintText: hintText,
                  onNavigateToBatches: () {
                    Navigator.pop(sheetContext);
                    onNavigateToBatches?.call();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showSideDrawer(
    BuildContext context,
    List<Map<String, dynamic>> completedRaisers,
    VoidCallback? onNavigateToBatches,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBorder = isDark
        ? PiggyTrunkTheme.ptBorderDark
        : PiggyTrunkTheme.ptBorder;
    final titleColor = isDark
        ? PiggyTrunkTheme.ptTextDark
        : PiggyTrunkTheme.ptText;
    final hintText = isDark
        ? PiggyTrunkTheme.ptMutedDark
        : PiggyTrunkTheme.ptMuted;
    final size = MediaQuery.of(context).size;
    final modalWidth = (size.width > 1200) ? 960.0 : (size.width > 800 ? 820.0 : size.width * 0.95);
    final modalHeight = size.height * 0.88;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CycleHistoryDrawer',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          const SizedBox.shrink(),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: modalWidth,
                  height: modalHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [const Color(0xFF1A2940), const Color(0xFF0F1C2F)]
                          : [Colors.white, const Color(0xFFF8FAFC)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                        blurRadius: 36,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 18,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                                      : const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.verified_rounded,
                                  size: 20,
                                  color: isDark
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFF1E40AF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Finished Lifecycles',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: titleColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Batches that completed all feeding stages',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: hintText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: hintText,
                                  size: 22,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Close panel',
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          color: cardBorder.withValues(alpha: 0.5),
                          height: 1,
                        ),
                        Expanded(
                          child: _buildDrawerContent(
                            context: dialogContext,
                            completedRaisers: completedRaisers,
                            isDark: isDark,
                            cardBorder: cardBorder,
                            titleColor: titleColor,
                            hintText: hintText,
                            onNavigateToBatches: () {
                              Navigator.pop(dialogContext);
                              onNavigateToBatches?.call();
                            },
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
      },
    );
  }

  static Widget _buildDrawerContent({
    required BuildContext context,
    required List<Map<String, dynamic>> completedRaisers,
    required bool isDark,
    required Color cardBorder,
    required Color titleColor,
    required Color hintText,
    VoidCallback? onNavigateToBatches,
  }) {
    if (completedRaisers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.archive_outlined,
                size: 48,
                color: hintText.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No Finished Lifecycles Yet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Hog raisers whose assigned batches reach the final selling/harvest stage will automatically be archived here.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: hintText,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: completedRaisers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final raiser = completedRaisers[index];
        final name = (raiser['name'] ?? 'Hog Raiser').toString();
        final batchName = (raiser['batch_name'] ?? 'Batch').toString();
        final raiserHogs = (raiser['hogs'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? PiggyTrunkTheme.ptSurfaceSoftDark
                : PiggyTrunkTheme.ptSurfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? PiggyTrunkTheme.ptBorderDark
                  : PiggyTrunkTheme.ptBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Raiser Name & Batch Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark
                            ? PiggyTrunkTheme.ptBorderDark
                            : const Color(0xFFCBD5E1),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      batchName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? PiggyTrunkTheme.ptMutedDark
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Completion summary notice
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                      : const Color(0xFFDBEAFE).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                        : const Color(0xFF93C5FD).withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1E40AF),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All ${raiserHogs.isNotEmpty ? raiserHogs.length : ""} hogs in this batch have completed their lifecycle (Selling / Harvest stage reached).'
                            .replaceAll('  ', ' '),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Hogs lifecycle map items
              if (raiserHogs.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: raiserHogs.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final h = entry.value;
                    final tag = h['tag_number'] ?? '#${idx + 1}';
                    final rawHType = (h['pig_type'] ?? '').toString().trim();
                    final hType = rawHType.isNotEmpty ? rawHType : 'Fattening';
                    final hIsBreed =
                        hType.toLowerCase().contains('sow') ||
                        hType.toLowerCase().contains('breed');
                    final ptKey = hIsBreed ? 'sow' : 'fattening';
                    final stageForHog = _resolveStageName(
                      h['stage_id'] ?? h['lifecycle_stage'],
                      hIsBreed,
                    );
                    final isHogTerminal = stageForHog.toLowerCase() == 'selling' ||
                        stageForHog.toLowerCase() == 'lactation' ||
                        stageForHog.toLowerCase() == 'completed' ||
                        (int.tryParse(h['stage_id']?.toString() ?? '') ?? 0) >= 6;

                    return Container(
                      margin: EdgeInsets.only(top: idx > 0 ? 12 : 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? PiggyTrunkTheme.ptSurfaceDark
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? PiggyTrunkTheme.ptBorderDark
                              : PiggyTrunkTheme.ptBorder,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.pets_rounded,
                                    size: 13,
                                    color: isDark
                                        ? Colors.white
                                        : PiggyTrunkTheme.ptPrimary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Hog $tag',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      ptKey == 'sow' ? 'SOW' : 'FATTENING',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: hintText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isHogTerminal
                                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDEF7EC))
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isHogTerminal) ...[
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 10,
                                        color: isDark
                                            ? const Color(0xFFA7F3D0)
                                            : const Color(0xFF03543F),
                                      ),
                                      const SizedBox(width: 3.5),
                                    ],
                                    Text(
                                      isHogTerminal ? 'COMPLETE' : stageForHog.toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: isHogTerminal
                                            ? (isDark
                                                ? const Color(0xFFA7F3D0)
                                                : const Color(0xFF03543F))
                                            : (isDark
                                                ? PiggyTrunkTheme.ptMutedDark
                                                : const Color(0xFF475569)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildDrawerLifecycleMap(
                            currentStage: stageForHog,
                            pigType: ptKey,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _resolveStageName(dynamic stageVal, bool isBreeding) {
    final fatteningStages = const [
      'Booster',
      'Pre-Starter',
      'Starter',
      'Grower',
      'Finisher',
      'Selling',
    ];
    final sowStages = const [
      'Booster',
      'Pre-Starter',
      'Starter',
      'Grower',
      'Breeder',
      'Lactation',
    ];
    final list = isBreeding ? sowStages : fatteningStages;

    final id = int.tryParse(stageVal?.toString() ?? '');
    if (id != null && id >= 1 && id <= list.length) {
      return list[id - 1];
    }
    final s = stageVal?.toString().trim() ?? '';
    if (s.isNotEmpty && s != 'null' && s != 'N/A' && int.tryParse(s) == null) {
      return s;
    }
    return 'Booster';
  }

  static Widget _buildDrawerLifecycleMap({
    required String currentStage,
    required String pigType,
    required bool isDark,
  }) {
    final List<String> stages = pigType.toLowerCase() == 'sow'
        ? [
            'Booster',
            'Pre-Starter',
            'Starter',
            'Grower',
            'Breeder',
            'Lactation',
          ]
        : [
            'Booster',
            'Pre-Starter',
            'Starter',
            'Grower',
            'Finisher',
            'Selling',
          ];

    int currentIdx = stages.indexWhere(
      (s) => s.toLowerCase() == currentStage.trim().toLowerCase(),
    );
    if (currentIdx == -1) {
      final s = currentStage.toLowerCase();
      if (s == 'completed' || s == 'sold' || s == 'archived') {
        currentIdx = stages.length - 1;
      } else {
        currentIdx = 0;
      }
    }

    const circleSize = 22.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final stepWidth = totalWidth / stages.length;

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            // Smooth continuous connector line placed behind and centered through the circles
            Positioned(
              top: (circleSize / 2) - 1.25,
              left: stepWidth / 2,
              right: stepWidth / 2,
              child: Container(
                height: 2.5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Reached connector line
            if (currentIdx > 0)
              Positioned(
                top: (circleSize / 2) - 1.25,
                left: stepWidth / 2,
                width: stepWidth * currentIdx,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            // Uniformly spaced nodes across the available width
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(stages.length, (index) {
                final stage = stages[index];
                final bool isCompleted = index < currentIdx || (index == currentIdx && currentIdx == stages.length - 1);
                final bool isCurrent = index == currentIdx && currentIdx < stages.length - 1;

                Color circleBg;
                Widget iconChild;

                if (isCompleted) {
                  circleBg = const Color(0xFF10B981);
                  iconChild = const Center(
                    child: Icon(
                      Icons.check,
                      size: 11,
                      color: Colors.white,
                    ),
                  );
                } else if (isCurrent) {
                  circleBg = isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A);
                  iconChild = const Center(
                    child: Icon(
                      Icons.priority_high_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  );
                } else {
                  circleBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
                  iconChild = const SizedBox();
                }

                return SizedBox(
                  width: stepWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: circleSize,
                        height: circleSize,
                        decoration: BoxDecoration(
                          color: circleBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF151F2E)
                                : Colors.white,
                            width: 2,
                          ),
                          boxShadow: isCompleted
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: iconChild,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        stage,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? const Color(0xFF10B981)
                              : (isCurrent
                                  ? (isDark ? Colors.white : PiggyTrunkTheme.ptPrimary)
                                  : (isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B))),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}
