import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/capitalization_formatters.dart';

class ProductEditForm extends StatefulWidget {
  final Product product;
  final VoidCallback onCancel;
  final VoidCallback onProductUpdated;
  final Future<String?> Function(Uint8List bytes, String filename) onUploadImage;
  final Future<void> Function({
    required String? productId,
    required String productName,
    required String action,
    required double price,
    required int units,
    String? details,
  }) onInsertLog;
  final void Function(String msg, {Color? backgroundColor}) onShowSnackBar;
  final VoidCallback? onViewHistory;

  const ProductEditForm({
    super.key,
    required this.product,
    required this.onCancel,
    required this.onProductUpdated,
    required this.onUploadImage,
    required this.onInsertLog,
    required this.onShowSnackBar,
    this.onViewHistory,
  });

  @override
  State<ProductEditForm> createState() => _ProductEditFormState();
}

class _ProductEditFormState extends State<ProductEditForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _kiloPriceCtrl;
  late final TextEditingController _descriptionCtrl;
  late String _selectedCategory;

  Uint8List? _localImageBytes;
  String? _localImageName;
  final ImagePicker _imagePicker = ImagePicker();

  String? _nameError;
  String? _priceError;
  bool _isSaving = false;

  static const List<String> _categoryOptions = <String>[
    'Feeds',
    'Vitamins',
    'Medicines',
    'Others',
  ];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => _isDark ? const Color(0xFF132238) : Colors.white;
  Color get _cardBorder => _isDark ? const Color(0xFF28405D) : const Color(0xFFD7E3F3);
  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _mutedColor => _isDark ? const Color(0xFF9AB1CB) : const Color(0xFF6F8096);
  Color get _fieldBg => _isDark ? const Color(0xFF1A2B44) : const Color(0xFFF5F8FE);
  Color get _fieldText => _isDark ? Colors.white : const Color(0xFF18314F);
  Color get _fieldBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);
  Color get _panelStart => _isDark ? const Color(0xFF1A2940) : Colors.white;
  Color get _panelEnd => _isDark ? const Color(0xFF0F1C2F) : Colors.white;
  Color get _panelBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);


  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product.name);
    _barcodeCtrl = TextEditingController(text: widget.product.barcode ?? '');
    _selectedCategory = widget.product.category.isNotEmpty ? widget.product.category : 'Feeds';
    final priceStr = widget.product.price % 1 == 0
        ? widget.product.price.toInt().toString()
        : widget.product.price.toStringAsFixed(2);
    _priceCtrl = TextEditingController(text: priceStr);
    final kp = widget.product.kiloPrice;
    final kiloStr = (kp != null && kp > 0)
        ? (kp % 1 == 0 ? kp.toInt().toString() : kp.toStringAsFixed(2))
        : '';
    _kiloPriceCtrl = TextEditingController(text: kiloStr);
    _descriptionCtrl = TextEditingController(text: widget.product.description);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _kiloPriceCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _localImageBytes = bytes;
          _localImageName = file.name;
        });
      }
    } catch (e) {
      widget.onShowSnackBar('Failed to select image: $e', backgroundColor: Colors.redAccent);
    }
  }

  Future<void> _submitSave() async {
    final name = _nameCtrl.text.trim();
    final barcode = _barcodeCtrl.text.trim();
    final priceVal = double.tryParse(_priceCtrl.text.trim());
    if (name.isEmpty) {
      setState(() => _nameError = 'Product name is required.');
      return;
    }
    if (priceVal == null || priceVal <= 0) {
      setState(() => _priceError = 'Please enter a valid price greater than 0.');
      return;
    }

    setState(() {
      _nameError = null;
      _priceError = null;
      _isSaving = true;
    });

    try {
      String? imageUrl = widget.product.image;
      if (_localImageBytes != null && _localImageName != null) {
        imageUrl = await widget.onUploadImage(_localImageBytes!, _localImageName!);
      }

      final kiloPriceVal = double.tryParse(_kiloPriceCtrl.text.trim());
      final catLower = _selectedCategory.trim().toLowerCase();
      final isFeed = catLower == 'feeds' || catLower == 'feed';
      final isMedicine = catLower == 'medicines' || catLower == 'medicine';
      final supportsSubUnitPrice = isFeed || isMedicine;

      final payload = {
        'name': name,
        'category_id': _selectedCategory.toLowerCase().replaceAll(' ', '_'),
        'category': _selectedCategory,
        'description': _descriptionCtrl.text.trim(),
        'barcode': barcode.isNotEmpty ? barcode : null,
        'price': priceVal,
        'image': imageUrl,
        if (supportsSubUnitPrice) 'kilo_price': (kiloPriceVal != null && kiloPriceVal > 0) ? kiloPriceVal : null,
      };

      try {
        await Supabase.instance.client
            .from('inventory_products')
            .update(payload)
            .eq('id', widget.product.id);
      } catch (e) {
        if (e.toString().contains('kilo_price')) {
          // If Supabase table has not had kilo_price added yet, update without it
          final fallbackPayload = Map<String, dynamic>.from(payload)..remove('kilo_price');
          await Supabase.instance.client
              .from('inventory_products')
              .update(fallbackPayload)
              .eq('id', widget.product.id);
        } else {
          rethrow;
        }
      }

      List<String> changes = [];
      if (widget.product.name != name) changes.add('Name: "${widget.product.name}" → "$name"');
      if (widget.product.category != _selectedCategory) {
        changes.add('Category: "${widget.product.category}" → "$_selectedCategory"');
      }
      if ((widget.product.price - priceVal).abs() > 0.001) {
        changes.add('Price: ₱${widget.product.price.toStringAsFixed(2)} → ₱${priceVal.toStringAsFixed(2)}');
      }
      final double oldKilo = widget.product.kiloPrice ?? 0.0;
      final double newKilo = kiloPriceVal ?? 0.0;
      if ((oldKilo - newKilo).abs() > 0.001) {
        final subLabel = isMedicine ? 'Tablet Price' : 'Kilo Price';
        changes.add('$subLabel: ₱${oldKilo.toStringAsFixed(2)} → ₱${newKilo.toStringAsFixed(2)}');
      }
      if (widget.product.description != _descriptionCtrl.text.trim()) changes.add('Description updated');
      if (imageUrl != widget.product.image) changes.add('Photo updated');

      final detailsStr = changes.isEmpty ? 'No field changes' : changes.join(' • ');
      final bool priceChanged = (widget.product.price - priceVal).abs() > 0.001;
      final String logAction = (priceChanged && changes.length == 1) ? 'PRICE UPDATE' : 'UPDATE';

      await widget.onInsertLog(
        productId: widget.product.id,
        productName: name,
        action: logAction,
        price: priceVal,
        units: widget.product.units,
        details: detailsStr,
      );

      if (!mounted) return;
      widget.onProductUpdated();
      widget.onShowSnackBar(
        'Product "$name" updated successfully.',
        backgroundColor: PiggyTrunkTheme.ptSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().toLowerCase();
      String cleanMsg = 'Unable to update product. Please check your connection and try again.';
      if (raw.contains('kilo_price')) {
        cleanMsg = 'Note: Per-kilo price column is not configured in database yet.';
      } else if (raw.contains('unique') || raw.contains('duplicate')) {
        cleanMsg = 'A product with this name already exists.';
      }
      setState(() {
        _isSaving = false;
        _nameError = cleanMsg;
      });
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
          horizontal: isMobile ? 14 : 24,
          vertical: isMobile ? 16 : 26,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with Title & History
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Product Details',
                          style: GoogleFonts.plusJakartaSans(
                            color: _titleColor,
                            fontSize: isMobile ? 20 : 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Update photo, pricing, and information for "${widget.product.name}"',
                          style: GoogleFonts.plusJakartaSans(
                            color: _mutedColor,
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.onViewHistory != null)
                    Tooltip(
                      message: 'View Product Activity Logs',
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : widget.onViewHistory,
                        icon: Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                        ),
                        label: isMobile
                            ? const SizedBox.shrink()
                            : Text(
                                'Activity Logs',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                ),
                              ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _panelBorder, width: 1.2),
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 10 : 16,
                            vertical: isMobile ? 10 : 12,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Form Card Container
              Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  border: Border.all(color: _cardBorder, width: 1),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(isMobile ? 16 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Photo Avatar with picker
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: _fieldBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _panelBorder, width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _localImageBytes != null
                                  ? Image.memory(
                                      _localImageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : (widget.product.image != null && widget.product.image!.isNotEmpty
                                      ? Image.network(
                                          widget.product.image!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Center(
                                            child: Icon(Icons.broken_image_outlined, color: _mutedColor, size: 36),
                                          ),
                                        )
                                      : Center(
                                          child: Icon(Icons.image_outlined, color: _mutedColor, size: 40),
                                        )),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: InkWell(
                              onTap: _isSaving ? null : _pickImage,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _isDark ? const Color(0xFF132238) : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  color: _isDark ? const Color(0xFF132238) : Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Product Name Field
                    Text(
                      'PRODUCT NAME *',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _mutedColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: const [CapitalizeWordsInputFormatter()],
                      onChanged: (_) {
                        if (_nameError != null) setState(() => _nameError = null);
                      },
                      style: GoogleFonts.plusJakartaSans(
                        color: _fieldText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Premium Booster Feeds',
                        hintStyle: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 14),
                        filled: true,
                        fillColor: _fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _nameError != null ? const Color(0xFFE53E3E) : _fieldBorder,
                            width: _nameError != null ? 1.5 : 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _nameError != null ? const Color(0xFFE53E3E) : PiggyTrunkTheme.ptPrimary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (_nameError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _nameError!,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFE53E3E),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    // Barcode / Unique ID Field
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BARCODE / UNIQUE ID',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: _mutedColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            final gen = 'PIG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                            _barcodeCtrl.text = gen;
                          },
                          icon: const Icon(Icons.auto_awesome, size: 14),
                          label: Text(
                            'Auto-Generate',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: PiggyTrunkTheme.ptSuccess,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _barcodeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.plusJakartaSans(
                        color: _fieldText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. 480016624912 or FEED-001',
                        hintStyle: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 13),
                        filled: true,
                        fillColor: _fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _fieldBorder, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: PiggyTrunkTheme.ptPrimary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SizedBox(height: 18),

                    // Row: Category & Unit Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CATEGORY *',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: _mutedColor,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: _fieldBg,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: _fieldBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: PiggyTrunkTheme.ptPrimary, width: 1.5),
                                  ),
                                ),
                                dropdownColor: _fieldBg,
                                borderRadius: BorderRadius.circular(12),
                                style: GoogleFonts.plusJakartaSans(
                                  color: _fieldText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                items: _categoryOptions.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(c),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedCategory = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'UNIT PRICE (PHP) *',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: _mutedColor,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _priceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                onChanged: (_) {
                                  if (_priceError != null) setState(() => _priceError = null);
                                },
                                style: GoogleFonts.plusJakartaSans(
                                  color: _fieldText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  prefixText: '₱ ',
                                  prefixStyle: GoogleFonts.plusJakartaSans(
                                    color: _fieldText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  hintText: '0.00',
                                  hintStyle: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 14),
                                  filled: true,
                                  fillColor: _fieldBg,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: _priceError != null ? const Color(0xFFE53E3E) : _fieldBorder,
                                      width: _priceError != null ? 1.5 : 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: _priceError != null ? const Color(0xFFE53E3E) : PiggyTrunkTheme.ptPrimary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              if (_priceError != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _priceError!,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFE53E3E),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Price per Kilo (Feeds) or Price per Tablet (Medicines) - optional
                    if (_selectedCategory.trim().toLowerCase() == 'feeds' ||
                        _selectedCategory.trim().toLowerCase() == 'medicines' ||
                        _selectedCategory.trim().toLowerCase() == 'medicine') ...[
                      Text(
                        _selectedCategory.trim().toLowerCase() == 'feeds'
                            ? 'PRICE PER KILO (PHP) - OPTIONAL'
                            : 'PRICE PER TABLET (PHP) - OPTIONAL',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _mutedColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedCategory.trim().toLowerCase() == 'feeds'
                            ? 'Leave blank if this feed is exclusively sold as whole sacks.'
                            : 'Leave blank if this medicine is exclusively sold as whole boxes/packs.',
                        style: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _kiloPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        style: GoogleFonts.plusJakartaSans(
                          color: _fieldText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          prefixText: '₱ ',
                          prefixStyle: GoogleFonts.plusJakartaSans(
                            color: _fieldText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          hintText: '0.00',
                          hintStyle: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 14),
                          filled: true,
                          fillColor: _fieldBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: PiggyTrunkTheme.ptPrimary, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Description Field
                    Text(
                      'DESCRIPTION',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _mutedColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descriptionCtrl,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: const [CapitalizeSentencesInputFormatter()],
                      style: GoogleFonts.plusJakartaSans(color: _fieldText, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Enter optional product description...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 13),
                        filled: true,
                        fillColor: _fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _fieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: PiggyTrunkTheme.ptPrimary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Action Buttons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _isSaving ? null : widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            side: BorderSide(color: _cardBorder, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              color: _mutedColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _submitSave,
                          icon: _isSaving
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                ),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Changes',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            foregroundColor: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}
