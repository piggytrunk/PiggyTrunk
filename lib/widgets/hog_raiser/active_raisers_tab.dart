import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../common/shimmer_loading.dart';

class ActiveRaisersTab extends StatelessWidget {
  final List<Map<String, dynamic>> raisers;
  final int currentTab;
  final TextEditingController searchCtrl;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final void Function(String value) onSearch;
  final void Function(Map<String, dynamic> row) onShowDetails;
  final void Function(Map<String, dynamic> row) onArchiveRaiser;
  final void Function(Map<String, dynamic> row) onRestoreRaiser;
  final void Function(Map<String, dynamic> row) onDeleteRaiser;
  final void Function(Map<String, dynamic> row) onApproveRaiser;

  const ActiveRaisersTab({
    super.key,
    required this.raisers,
    required this.currentTab,
    required this.searchCtrl,
    this.onRefresh,
    this.isRefreshing = false,
    required this.onSearch,
    required this.onShowDetails,
    required this.onArchiveRaiser,
    required this.onRestoreRaiser,
    required this.onDeleteRaiser,
    required this.onApproveRaiser,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);

    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
    final titleColor = isDark ? Colors.white : const Color(0xFF18314F);
    final hintText = isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
    final fieldBg = isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
    final fieldBorder = isDark ? const Color(0xFF28405D) : const Color(0xFFC9D8EC);
    final fieldFocus = isDark ? const Color(0xFF88A7CE) : const Color(0xFF315C8F);
    final fieldText = isDark ? Colors.white : const Color(0xFF18314F);

    // Sort raisers newest-first (latest created at the top, oldest at the bottom)
    final sortedRaisers = List<Map<String, dynamic>>.from(raisers);
    sortedRaisers.sort((a, b) {
      final idA = int.tryParse((a['hog_raiser_id'] ?? a['id'] ?? '0').toString()) ?? 0;
      final idB = int.tryParse((b['hog_raiser_id'] ?? b['id'] ?? '0').toString()) ?? 0;
      return idB.compareTo(idA);
    });

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: searchCtrl,
                    onSubmitted: onSearch,
                    style: GoogleFonts.plusJakartaSans(color: fieldText, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search raisers...',
                      hintStyle: GoogleFonts.plusJakartaSans(color: hintText, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: hintText, size: 20),
                      filled: true,
                      fillColor: fieldBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: fieldBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: fieldFocus, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => onSearch(searchCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E3A5F) : PiggyTrunkTheme.ptPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text('Search', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (onRefresh != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isRefreshing ? null : onRefresh,
                  icon: isRefreshing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                          ),
                        )
                      : Icon(
                          Icons.refresh_rounded,
                          color: isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                          size: 22,
                        ),
                  tooltip: 'Refresh Raisers',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E2F47) : const Color(0xFFEEF4FD),
                    minimumSize: const Size(46, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          if (isRefreshing)
            TableSkeletonLoader(
              isDark: isDark,
              minWidth: 820,
              cardBg: cardBg,
              cardBorder: cardBorder,
              headerBg: isDark ? const Color(0xFF1B2E48) : const Color(0xFFEDF4FC),
              headers: const ['NAME', 'ADDRESS', 'PHONE NUMBER', 'STATUS', 'ACTIONS'],
              columnFlexes: const [3, 2, 2, 2, 2],
              actionButtonCount: currentTab == 0 ? 2 : 3,
              rowCount: 5,
              borderRadius: 8,
            )
          else if (sortedRaisers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Text(
                searchCtrl.text.trim().isNotEmpty
                    ? 'No raisers matching "${searchCtrl.text.trim()}" found.'
                    : (currentTab == 1
                        ? 'No pending raisers found.'
                        : (currentTab == 2
                            ? 'No archived raisers found.'
                            : 'No active raisers found.')),
                style: GoogleFonts.plusJakartaSans(color: hintText, fontSize: 14),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth > 820 ? constraints.maxWidth : 820.0;

                return Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _tableHeader(isDark, cardBorder, hintText),
                          ...sortedRaisers.map((row) => _tableRow(row, isDark, cardBorder, titleColor)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _tableHeader(bool isDark, Color cardBorder, Color hintText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2E48) : const Color(0xFFEDF4FC),
        border: Border(bottom: BorderSide(color: cardBorder, width: 1.2)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('NAME', style: AppTextStyles.tableHeader(hintText)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('ADDRESS', style: AppTextStyles.tableHeader(hintText)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('PHONE NUMBER', style: AppTextStyles.tableHeader(hintText)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('STATUS', style: AppTextStyles.tableHeader(hintText)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text('ACTIONS', style: AppTextStyles.tableHeader(hintText)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> row, bool isDark, Color cardBorder, Color titleColor) {
    final statusVal = (row['status'] ?? '').toString().toLowerCase();
    final accStatusVal = (row['account_status'] ?? '').toString().toLowerCase();
    final isArchived = statusVal == 'archived' || accStatusVal == 'archived';
    final isPending = !isArchived && (statusVal == 'pending' || accStatusVal == 'pending');

    final String statusText = isArchived ? 'ARCHIVED' : (isPending ? 'PENDING' : 'ACTIVE');
    final Color statusColor = isArchived
        ? const Color(0xFF94A3B8)
        : (isPending ? const Color(0xFFFFAA00) : PiggyTrunkTheme.ptSuccess);

    final dangerColor = const Color(0xFFFF758C);
    final dangerBg = dangerColor.withValues(alpha: 0.1);
    final dangerBorder = dangerColor.withValues(alpha: 0.35);

    final successColor = isDark ? PiggyTrunkTheme.ptSuccessDark : PiggyTrunkTheme.ptSuccess;
    final successBg = successColor.withValues(alpha: 0.1);
    final successBorder = successColor.withValues(alpha: 0.35);

    final neutralColor = isDark ? Colors.white : PiggyTrunkTheme.ptPrimary;
    final neutralBg = neutralColor.withValues(alpha: 0.08);
    final neutralBorder = neutralColor.withValues(alpha: 0.22);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cardBorder.withValues(alpha: 0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                (row['name'] ?? '').toString(),
                style: AppTextStyles.body(titleColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                (row['address'] ?? '').toString(),
                style: AppTextStyles.body(titleColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                (row['phone'] ?? '').toString(),
                style: AppTextStyles.body(titleColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        maxLines: 1,
                        softWrap: false,
                        style: GoogleFonts.plusJakartaSans(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: isPending
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionButton(
                            icon: Icons.visibility_outlined,
                            tooltip: 'View Raiser Profile',
                            color: neutralColor,
                            bgColor: neutralBg,
                            borderColor: neutralBorder,
                            onTap: () => onShowDetails(row),
                          ),
                          const SizedBox(width: 6),
                          _buildActionButton(
                            icon: Icons.check_circle_outline_rounded,
                            tooltip: 'Approve Raiser',
                            color: successColor,
                            bgColor: successBg,
                            borderColor: successBorder,
                            onTap: () => onApproveRaiser(row),
                          ),
                          const SizedBox(width: 6),
                          _buildActionButton(
                            icon: Icons.cancel_outlined,
                            tooltip: 'Reject Raiser',
                            color: dangerColor,
                            bgColor: dangerBg,
                            borderColor: dangerBorder,
                            onTap: () => onDeleteRaiser(row),
                          ),
                        ],
                      )
                    : (isArchived
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildActionButton(
                                icon: Icons.visibility_outlined,
                                tooltip: 'View Raiser Profile',
                                color: neutralColor,
                                bgColor: neutralBg,
                                borderColor: neutralBorder,
                                onTap: () => onShowDetails(row),
                              ),
                              const SizedBox(width: 6),
                              _buildActionButton(
                                icon: Icons.unarchive_outlined,
                                tooltip: 'Restore Raiser',
                                color: successColor,
                                bgColor: successBg,
                                borderColor: successBorder,
                                onTap: () => onRestoreRaiser(row),
                              ),
                              const SizedBox(width: 6),
                              _buildActionButton(
                                icon: Icons.delete_outline_rounded,
                                tooltip: 'Delete Raiser',
                                color: dangerColor,
                                bgColor: dangerBg,
                                borderColor: dangerBorder,
                                onTap: () => onDeleteRaiser(row),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildActionButton(
                                icon: Icons.visibility_outlined,
                                tooltip: 'View Raiser Profile',
                                color: neutralColor,
                                bgColor: neutralBg,
                                borderColor: neutralBorder,
                                onTap: () => onShowDetails(row),
                              ),
                              const SizedBox(width: 6),
                              _buildActionButton(
                                icon: Icons.archive_outlined,
                                tooltip: 'Archive Raiser',
                                color: dangerColor,
                                bgColor: dangerBg,
                                borderColor: dangerBorder,
                                onTap: () => onArchiveRaiser(row),
                              ),
                            ],
                          )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 16,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
