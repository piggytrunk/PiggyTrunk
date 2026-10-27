import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/capitalization_formatters.dart';

class BatchFormView extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onBatchSaved;
  final Map<String, dynamic>? existingBatch;
  final List<Map<String, dynamic>>? activeRaisers;
  final void Function(String msg, {bool isError}) onShowSnackBar;

  const BatchFormView({
    super.key,
    required this.onCancel,
    required this.onBatchSaved,
    this.existingBatch,
    this.activeRaisers,
    required this.onShowSnackBar,
  });

  @override
  State<BatchFormView> createState() => _BatchFormViewState();
}

class _BatchFormViewState extends State<BatchFormView> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late final TextEditingController _batchNameCtrl;
  String? _batchNameError;
  bool _isSubmitting = false;

  bool get _isEdit => widget.existingBatch != null;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _panelStart => _isDark ? const Color(0xFF1A2940) : Colors.white;
  Color get _panelEnd => _isDark ? const Color(0xFF0F1C2F) : Colors.white;
  Color get _panelBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);
  Color get _cardBg => _isDark ? const Color(0xFF132238) : Colors.white;
  Color get _cardBorder => _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _mutedColor => _isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
  Color get _fieldBg => _isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
  Color get _fieldText => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _fieldBorder => _isDark ? const Color(0xFF28405D) : const Color(0xFFC9D8EC);
  Color get _fieldFocus => _isDark ? const Color(0xFF88A7CE) : const Color(0xFF315C8F);

  @override
  void initState() {
    super.initState();
    _batchNameCtrl = TextEditingController(
      text: _isEdit ? widget.existingBatch!['batch_name']?.toString() ?? '' : '',
    );
  }

  @override
  void dispose() {
    _batchNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;
    final batchName = _batchNameCtrl.text.trim();

    if (batchName.isEmpty) {
      setState(() => _batchNameError = 'Please enter a batch name or code.');
      return;
    }

    setState(() {
      _batchNameError = null;
      _isSubmitting = true;
    });

    try {
      if (_isEdit) {
        final batchId = widget.existingBatch!['batch_id'] ?? widget.existingBatch!['id'];
        await _supabase.from('batches').update({
          'batch_name': batchName,
        }).eq(widget.existingBatch!['batch_id'] != null ? 'batch_id' : 'id', batchId);
      } else {
        try {
          await _supabase.from('batches').insert({
            'batch_name': batchName,
            'date_created': DateTime.now().toIso8601String().split('T').first,
            'status': 'Active',
          });
        } catch (bErr) {
          debugPrint('Batch insert with date_created fallback: $bErr');
          await _supabase.from('batches').insert({
            'batch_name': batchName,
          });
        }
      }

      if (!mounted) return;
      widget.onShowSnackBar(_isEdit ? 'Batch updated successfully.' : 'Batch created successfully.');
      widget.onBatchSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      widget.onShowSnackBar('Operation failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_panelStart, _panelEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: _panelBorder, width: 1),
          borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 34,
          vertical: isMobile ? 16 : 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit Hog Batch' : 'Create New Hog Batch',
                          style: GoogleFonts.plusJakartaSans(
                            color: _titleColor,
                            fontSize: isMobile ? 22 : 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEdit
                              ? 'Update batch name and code identifier.'
                              : 'Define batch code identifier for farm grouping.',
                          style: GoogleFonts.plusJakartaSans(
                            color: _mutedColor,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: Icon(Icons.close_rounded, color: _titleColor, size: isMobile ? 24 : 28),
                    tooltip: 'Back to batches',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Form Body Container
              Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                  border: Border.all(color: _cardBorder),
                ),
                padding: EdgeInsets.all(isMobile ? 16 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Batch Name
                    Text(
                      'BATCH NAME / CODE *',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _mutedColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _batchNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: const [CapitalizeWordsInputFormatter()],
                      onChanged: (_) {
                        if (_batchNameError != null) setState(() => _batchNameError = null);
                      },
                      style: GoogleFonts.plusJakartaSans(
                        color: _fieldText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. BATCH-2026-01',
                        hintStyle: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 14),
                        filled: true,
                        fillColor: _fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _batchNameError != null ? const Color(0xFFE53E3E) : _fieldBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _batchNameError != null ? const Color(0xFFE53E3E) : _fieldFocus,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (_batchNameError != null) ...[
                      const SizedBox(height: 4),
                      Text(_batchNameError!, style: const TextStyle(color: Color(0xFFE53E3E), fontSize: 11.5)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Responsive Action Buttons (Cancel / Submit)
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitForm,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                          label: Text(
                            _isSubmitting ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Batch'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            foregroundColor: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _isSubmitting ? null : widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: _fieldBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              color: _fieldText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _isSubmitting ? null : widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            side: BorderSide(color: _fieldBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              color: _fieldText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitForm,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                          label: Text(
                            _isSubmitting ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Batch'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            foregroundColor: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      );
  }
}
