import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/services/email_service.dart';

class AdminMobilePendingHogRaisersScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const AdminMobilePendingHogRaisersScreen({
    super.key,
    this.onBackToDashboard,
  });

  @override
  State<AdminMobilePendingHogRaisersScreen> createState() =>
      _AdminMobilePendingHogRaisersScreenState();
}

class _AdminMobilePendingHogRaisersScreenState
    extends State<AdminMobilePendingHogRaisersScreen> {
  // Brand Color Tokens (Aligned with Piggy Trunk Design System)
  static const Color _brandNavy = Color(0xFF18314F);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _textMuted = Color(0xFF6F8096);
  static const Color _criticalRed = Color(0xFFDC2626);
  static const Color _emeraldGreen = Color(0xFF16A34A);

  final int _selectedTabIndex = 2; // Investment Tab
  bool _isLoading = false;

  List<Map<String, dynamic>> _pendingRaisers = [];

  @override
  void initState() {
    super.initState();
    _fetchLivePendingRaisers();
  }

  Future<void> _fetchLivePendingRaisers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final res = await Supabase.instance.client
          .from('hog_raisers')
          .select('hog_raiser_id, name, address, phone, account_status, app_users(name, email, status)')
          .order('hog_raiser_id', ascending: false)
          .limit(20);

      if (res.isNotEmpty && mounted) {
        List<Map<String, dynamic>> parsed = [];

        for (var r in res) {
          final user = r['app_users'] as Map<String, dynamic>? ?? {};
          final String userStatus = (user['status'] as String?) ?? 'pending';
          final String accStatus = (r['account_status'] as String?) ?? 'pending';

          // Only show pending applications
          if (accStatus.toLowerCase() == 'pending' || userStatus.toLowerCase() == 'pending') {
            final String rName = (r['name'] as String?) ?? (user['name'] as String?) ?? (user['email'] as String?) ?? 'Pending Raiser';
            final String rAddress = (r['address'] as String?) ?? 'Location not specified';
            final String rPhone = (r['phone'] as String?) ?? 'No contact number';

            parsed.add({
              'id': r['hog_raiser_id']?.toString() ?? '',
              'name': rName,
              'email': (user['email'] ?? r['email'] ?? '').toString(),
              'location': rAddress.toUpperCase(),
              'contact': rPhone,
              'appliedDate': DateTime.now().toLocal().toString().split(' ')[0],
            });
          }
        }

        setState(() => _pendingRaisers = parsed);
      } else if (mounted) {
        setState(() => _pendingRaisers = []);
      }
    } catch (e) {
      debugPrint('Error fetching pending raisers: $e');
      if (mounted) setState(() => _pendingRaisers = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleApprove(Map<String, dynamic> raiser) async {
    final String raiserId = raiser['id'] as String;
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (raiserId.isNotEmpty) {
        await Supabase.instance.client
            .from('hog_raisers')
            .update({'account_status': 'active', 'status': 'Active'})
            .eq('hog_raiser_id', raiserId);
      }
    } catch (e) {
      debugPrint('Raiser approval fallback: $e');
    }

    if (mounted) {
      setState(() {
        _pendingRaisers.removeWhere((item) => item['id'] == raiserId);
      });

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Approved ${raiser['name']}! Raiser can now log in and receive hog assignments.',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: _emeraldGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleReject(Map<String, dynamic> raiser) async {
    final String raiserId = raiser['id'] as String;
    final String email = (raiser['email'] ?? '').toString();
    final String name = (raiser['name'] ?? 'Hog Raiser').toString();
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (raiserId.isNotEmpty) {
        await Supabase.instance.client
            .from('hog_raisers')
            .update({'account_status': 'rejected', 'status': 'rejected'})
            .eq('hog_raiser_id', raiserId);
      }
      if (email.isNotEmpty) {
        await Supabase.instance.client
            .from('app_users')
            .update({'status': 'rejected'})
            .eq('email', email);

        EmailService().sendAccountRejectionEmail(
          recipientEmail: email,
          recipientName: name,
          role: 'Hog Raiser',
        );
      }
    } catch (e) {
      debugPrint('Raiser rejection fallback: $e');
    }

    if (mounted) {
      setState(() {
        _pendingRaisers.removeWhere((item) => item['id'] == raiserId);
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text('Application rejected for ${raiser['name']}.'),
          backgroundColor: _criticalRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmReject(Map<String, dynamic> raiser) async {
    final name = (raiser['name'] ?? 'Hog Raiser').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _criticalRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: _criticalRed, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reject Application?',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  color: _brandNavy,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to reject the application for "$name"?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: const Color(0xFF334155),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _criticalRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Yes, Reject',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleReject(raiser);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          color: _brandNavy,
          onRefresh: _fetchLivePendingRaisers,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading) ...[
                  const LinearProgressIndicator(
                    minHeight: 2.5,
                    color: _brandNavy,
                    backgroundColor: Colors.transparent,
                  ),
                  const SizedBox(height: 12),
                ],

                // Pending Raiser Cards List or Clean Empty State
                _buildPendingRaisersList(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // 1. Top App Bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: _brandNavy, size: 24),
        onPressed: widget.onBackToDashboard ?? () => Navigator.pop(context),
      ),
      title: Text(
        'Pending Hog Raisers',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: _brandNavy,
          letterSpacing: -0.4,
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              color: _brandNavy, size: 22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (val) {
            if (val == 'refresh') _fetchLivePendingRaisers();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh_rounded, size: 18, color: _brandNavy),
                  SizedBox(width: 10),
                  Text('Refresh List'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // 2. Pending Raisers List (or Clean Empty State)
  Widget _buildPendingRaisersList() {
    if (_pendingRaisers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _brandNavy.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.how_to_reg_outlined,
                  size: 32, color: _emeraldGreen),
            ),
            const SizedBox(height: 14),
            Text(
              'No Pending Hog Raisers',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: _brandNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'When new hog raisers register from their mobile app, their farm verification applications will appear here.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                color: _textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pendingRaisers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final raiser = _pendingRaisers[index];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFFDE8E8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Profile Row (Avatar, Name, Location)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar Box with Farmer Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: const Icon(
                      Icons.agriculture_rounded,
                      color: _brandNavy,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name & Location Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          raiser['name'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18.5,
                            fontWeight: FontWeight.w900,
                            color: _brandNavy,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          raiser['location'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Divider Line
              const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
              const SizedBox(height: 14),

              // Contact Number Row
              Text(
                'CONTACT NUMBER:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: _brandNavy,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                raiser['contact'] as String,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),

              // Applied Date Row
              Text(
                'APPLIED ON',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: _brandNavy,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                raiser['appliedDate'] as String,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 20),

              // Divider Line
              const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
              const SizedBox(height: 16),

              // Dual Action Buttons: [ APPROVE ] and [ REJECT ]
              Row(
                children: [
                  // APPROVE Button (Solid Green)
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _emeraldGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _handleApprove(raiser),
                        child: Text(
                          'APPROVE',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // REJECT Button (Outlined Coral)
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(
                              color: Color(0xFFFCA5A5), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _confirmReject(raiser),
                        child: Text(
                          'REJECT',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. Bottom Navigation Bar (5 Dedicated Tabs matching screenshot)
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          if (index != 2) {
            Navigator.pop(context);
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFC73F57), // Active Red
        unselectedItemColor: const Color(0xFF64748B),
        selectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded, size: 24),
            activeIcon: Icon(Icons.dashboard_rounded, size: 24),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined, size: 24),
            activeIcon: Icon(Icons.inventory_2_rounded, size: 24),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined, size: 24),
            activeIcon: Icon(Icons.assignment_rounded, size: 24),
            label: 'Investment',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_outlined, size: 24),
            activeIcon: Icon(Icons.point_of_sale_rounded, size: 24),
            label: 'POS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded, size: 24),
            activeIcon: Icon(Icons.person_rounded, size: 24),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
