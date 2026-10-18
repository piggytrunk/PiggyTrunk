/// Formats backend database IDs (UUIDs, timestamps, raw strings, sequences)
/// into clean, 3-digit padded retail store sale IDs (e.g., `#SALE-001`, `#SALE-002`).
class SaleIdFormatter {
  /// Converts any raw ID or UUID into a clean 3-digit store sale ID (starting from #SALE-001).
  /// Example: 1 -> '#SALE-001'
  /// Example: 'ec6362b6-0a41-4bc7-b67b-e18964063dcd' -> '#SALE-001' (via sequence or stable hash)
  static String format(dynamic rawId, {int? index, int? totalCount}) {
    // 1. If chronological sequence info is available (newest-first list)
    if (index != null) {
      final int seqNum;
      if (totalCount != null && totalCount > 0) {
        seqNum = (totalCount - index).clamp(1, 999999);
      } else {
        seqNum = (index + 1).clamp(1, 999999);
      }
      return '#SALE-${seqNum.toString().padLeft(3, '0')}';
    }

    if (rawId == null || rawId.toString().trim().isEmpty) {
      return '#SALE-001';
    }

    final str = rawId.toString().trim();

    // 2. If it's already a clean store code like '#SALE-001' or 'SALE-01'
    final match = RegExp(r'^#?(SALE|ORD|RCP|REC)-(\d+)$', caseSensitive: false).firstMatch(str);
    if (match != null) {
      final numPart = match.group(2) ?? '1';
      final intVal = int.tryParse(numPart) ?? 1;
      return '#SALE-${intVal.toString().padLeft(3, '0')}';
    }

    // 3. If it's an integer ID (e.g. database sale_id = 1, 2, 3...)
    final asInt = int.tryParse(str);
    if (asInt != null) {
      if (asInt < 100000) {
        return '#SALE-${asInt.toString().padLeft(3, '0')}';
      }
      // If it's a millisecond timestamp, extract a clean 3-digit number
      final last3 = (asInt % 1000);
      final safeVal = last3 == 0 ? 1 : last3;
      return '#SALE-${safeVal.toString().padLeft(3, '0')}';
    }

    // 4. If it's a UUID (e.g. ec6362b6-0a41-4bc7-b67b-e18964063dcd)
    // Derive a stable, deterministic 3-digit store code between 001 and 999
    final stableNum = (str.hashCode.abs() % 999) + 1;
    return '#SALE-${stableNum.toString().padLeft(3, '0')}';
  }

  /// Extracts just the numeric sequence for receipt modal headers (e.g. '001', '002').
  static String toReceiptNumber(dynamic rawId, {int? index, int? totalCount}) {
    final formatted = format(rawId, index: index, totalCount: totalCount);
    return formatted.replaceAll(RegExp(r'[^\d]'), '');
  }
}
