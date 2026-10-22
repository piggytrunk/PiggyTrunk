import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import 'cashier_empty_state.dart';

class StockRequestsModal extends StatelessWidget {
  final List<Map<String, dynamic>> pendingRequests;
  final Future<void> Function(int requestId, String status) onProcessRequest;

  const StockRequestsModal({
    super.key,
    required this.pendingRequests,
    required this.onProcessRequest,
  });

  static void show(
    BuildContext context, {
    required List<Map<String, dynamic>> pendingRequests,
    required Future<void> Function(int requestId, String status) onProcessRequest,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StockRequestsModal(
        pendingRequests: pendingRequests,
        onProcessRequest: onProcessRequest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: PiggyTrunkTheme.ptBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Raiser Stock Requests',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF18314F),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          Expanded(
            child: pendingRequests.isEmpty
                ? const CashierEmptyState(
                    message: 'No pending stock requests at this time',
                    icon: Icons.assignment_outlined,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: pendingRequests.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final req = pendingRequests[index];
                      final prodName = req['product']?['name'] ?? 'Product';
                      final raiserName = req['raiser']?['name'] ?? 'Raiser';
                      final int qty = req['quantity'] as int;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PiggyTrunkTheme.ptBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PiggyTrunkTheme.ptBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prodName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF18314F),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Raiser: $raiserName',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: PiggyTrunkTheme.ptMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Quantity: $qty units',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: PiggyTrunkTheme.ptMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: PiggyTrunkTheme.ptSuccess,
                                    size: 28,
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await onProcessRequest(req['request_id'] as int, 'Approved');
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                    size: 28,
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await onProcessRequest(req['request_id'] as int, 'Rejected');
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}
