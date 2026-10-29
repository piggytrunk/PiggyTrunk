import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/capitalization_formatters.dart';

class ProductAddForm extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onProductAdded;
  final Future<String?> Function(Uint8List bytes, String fileName) onUploadImage;
  final Future<void> Function({
    required String? productId,
    required String productName,
    required String action,
    required double price,
    required int units,
    String? details,
  }) onInsertLog;
  final void Function(String msg, {Color? backgroundColor}) onShowSnackBar;
  final String? initialBarcode;
  final int nextSortNumber;

  const ProductAddForm({
    super.key,
    required this.onCancel,
    required this.onProductAdded,
    required this.onUploadImage,
    required this.onInsertLog,
    required this.onShowSnackBar,
    this.initialBarcode,
    this.nextSortNumber = 1,
  });

  @override
  State<ProductAddForm> createState() => _ProductAddFormState();
}

class _ProductAddFormState extends State<ProductAddForm> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _barcodeCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController(text: 'Feeds');
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _kiloPriceCtrl = TextEditingController();
  final TextEditingController _unitsCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isSubmitting = false;

  String? _productNameError;
  String? _productCategoryError;
  String? _productStockError;
  String? _productPriceError;

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null && widget.initialBarcode!.trim().isNotEmpty) {
      _barcodeCtrl.text = widget.initialBarcode!.trim();
    }
  }

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
  Color get _fieldFocus => _isDark ? const Color(0xFF88A7CE) : const Color(0xFF315C8F);
  Color get _panelStart => _isDark ? const Color(0xFF1A2940) : Colors.white;
  Color get _panelEnd => _isDark ? const Color(0xFF0F1C2F) : Colors.white;
  Color get _panelBorder => _isDark ? const Color(0xFF2A3E5B) : const Color(0xFFC9D8EC);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _categoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _kiloPriceCtrl.dispose();
    _unitsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProductImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
      });
    } catch (e) {
      widget.onShowSnackBar('Image pick error: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> _submitAddProduct() async {
    if (_isSubmitting) return;
    final name = _nameCtrl.text.trim();
    final barcode = _barcodeCtrl.text.trim();
    final category = _categoryCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final priceInt = int.tryParse(_priceCtrl.text.trim());
    final units = int.tryParse(_unitsCtrl.text.trim());

    String? nameErr;
    String? categoryErr;
    String? priceErr;
    String? stockErr;

    if (name.isEmpty) {
      nameErr = 'Product name is required.';
    }
    if (category.isEmpty) {
      categoryErr = 'Please select a category.';
    }
    if (units == null) {
      stockErr = 'Please enter stock quantity.';
    } else if (units < 0) {
      stockErr = 'Stock cannot be negative.';
    }
    if (priceInt == null) {
      priceErr = 'Please enter product price.';
    } else if (priceInt <= 0) {
      priceErr = 'Price must be greater than 0.';
    }

    if (nameErr != null || categoryErr != null || priceErr != null || stockErr != null) {
      setState(() {
        _productNameError = nameErr;
        _productCategoryError = categoryErr;
        _productPriceError = priceErr;
        _productStockError = stockErr;
      });
      return;
    }

    final validatedPrice = priceInt!;
    final validatedUnits = units!;

    setState(() {
      _productNameError = null;
      _productCategoryError = null;
      _productPriceError = null;
      _productStockError = null;
      _isSubmitting = true;
    });

    try {
      String? imageUrl;
      if (_selectedImageBytes != null && _selectedImageName != null) {
        imageUrl = await widget.onUploadImage(_selectedImageBytes!, _selectedImageName!);
      }

      final kiloPriceVal = double.tryParse(_kiloPriceCtrl.text.trim());
      final catLower = category.toLowerCase();
      final supportsSubUnitPrice = catLower == 'feeds' || catLower == 'feed' || catLower == 'medicines' || catLower == 'medicine';

      final payload = {
        'name': name,
        'category_id': category.toLowerCase().replaceAll(' ', '_'),
        'category': category,
        'description': description,
        'barcode': barcode.isNotEmpty ? barcode : null,
        'price': validatedPrice.toDouble(),
        'units': validatedUnits,
        'image': imageUrl,
        'sold': 0,
        'is_archived': false,
        if (supportsSubUnitPrice && kiloPriceVal != null && kiloPriceVal > 0)
          'kilo_price': kiloPriceVal,
      };

      Map<String, dynamic> inserted;
      try {
        inserted = await _supabase.from('inventory_products').insert(payload).select().single();
      } catch (e) {
        if (e.toString().contains('kilo_price')) {
          final fallbackPayload = Map<String, dynamic>.from(payload)..remove('kilo_price');
          inserted = await _supabase.from('inventory_products').insert(fallbackPayload).select().single();
        } else {
          rethrow;
        }
      }
      final insertedId = inserted['id']?.toString();

      await widget.onInsertLog(
        productId: insertedId,
        productName: name,
        action: 'ADD',
        price: validatedPrice.toDouble(),
        units: validatedUnits,
        details: 'Initial stock of $validatedUnits units at ₱$validatedPrice.00',
      );

      if (!mounted) return;
      widget.onShowSnackBar(
        'Product "$name" added successfully.',
        backgroundColor: PiggyTrunkTheme.ptSuccess,
      );
      widget.onProductAdded();
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().toLowerCase();
      String cleanMsg = 'Unable to create product. Please check your connection and try again.';
      if (raw.contains('kilo_price')) {
        cleanMsg = 'Note: Per-kilo price column is not configured in database yet.';
      } else if (raw.contains('unique') || raw.contains('duplicate')) {
        cleanMsg = 'A product with this name already exists.';
      }
      widget.onShowSnackBar(
        cleanMsg,
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _formLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: _titleColor,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    double minHeight = 0,
    bool withBottomPadding = true,
    bool enabled = true,
    bool hasError = false,
    ValueChanged<String>? onChanged,
  }) {
    final borderSide = hasError
        ? const BorderSide(color: Color(0xFFE53E3E), width: 1.5)
        : BorderSide(color: _cardBorder);
    final focusedBorderSide = hasError
        ? const BorderSide(color: Color(0xFFE53E3E), width: 1.5)
        : BorderSide(color: _fieldFocus);

    return Padding(
      padding: EdgeInsets.only(bottom: withBottomPadding ? 12 : 0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: GoogleFonts.plusJakartaSans(
          color: enabled ? _fieldText : _mutedColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: GoogleFonts.plusJakartaSans(
            color: _mutedColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: enabled ? _fieldBg : _fieldBg.withAlpha(100),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          constraints: minHeight > 0 ? BoxConstraints(minHeight: minHeight) : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: borderSide,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _cardBorder.withAlpha(80)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: focusedBorderSide,
          ),
        ),
      ),
    );
  }

  Widget _buildInlineError(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: Color(0xFFE53E3E),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE53E3E),
              ),
            ),
          ),
        ],
      ),
    );
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
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Product',
                          style: GoogleFonts.plusJakartaSans(
                            color: _titleColor,
                            fontSize: isMobile ? 22 : 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fill in the product details to add it to your inventory.',
                          style: GoogleFonts.plusJakartaSans(
                            color: _mutedColor,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Form Container
              Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  border: Border.all(color: _cardBorder, width: 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: EdgeInsets.all(isMobile ? 14 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Photo
                        Expanded(
                          flex: isMobile ? 12 : 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _formLabel('PRODUCT PHOTO'),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _isSubmitting ? null : _pickProductImage,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 170,
                                  decoration: BoxDecoration(
                                    color: _fieldBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _cardBorder),
                                  ),
                                  child: _selectedImageBytes != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(11),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                                              Positioned(
                                                right: 8,
                                                top: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.55),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'Change',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.add_photo_alternate_outlined, color: _mutedColor, size: 38),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Upload Image',
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: _mutedColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                              if (_selectedImageName != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _selectedImageName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Right: Inputs
                        Expanded(
                          flex: isMobile ? 12 : 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _formLabel('PRODUCT NAME *'),
                              const SizedBox(height: 8),
                              _buildInput(
                                _nameCtrl,
                                'e.g., Premium Hog Feed',
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: const [CapitalizeWordsInputFormatter()],
                                hasError: _productNameError != null,
                                onChanged: (val) {
                                  setState(() {
                                    if (_productNameError != null) _productNameError = null;
                                    _barcodeCtrl.text = val.trim().isEmpty
                                        ? ''
                                        : Product.formatAcronymId(val, sortNumber: widget.nextSortNumber);
                                  });
                                },
                              ),
                              if (_productNameError != null) _buildInlineError(_productNameError!),
                                const SizedBox(height: 12),
                                _formLabel('PRODUCT ID / BARCODE (AUTO-GENERATED ACRONYM)'),
                              const SizedBox(height: 8),
                              _buildInput(
                                _barcodeCtrl,
                                'Auto-generated from product name (e.g., PHF-001)',
                                  textCapitalization: TextCapitalization.characters, enabled: false,
                                ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _formLabel('CATEGORY *'),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String>(
                                          initialValue: _categoryCtrl.text.isEmpty ? 'Feeds' : _categoryCtrl.text,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: _fieldBg,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                            constraints: const BoxConstraints(minHeight: 50),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(
                                                color: _productCategoryError != null ? const Color(0xFFE53E3E) : _cardBorder,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(
                                                color: _productCategoryError != null ? const Color(0xFFE53E3E) : _fieldFocus,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                          dropdownColor: _fieldBg,
                                          borderRadius: BorderRadius.circular(12),
                                          style: GoogleFonts.plusJakartaSans(
                                            color: _fieldText,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          items: _categoryOptions
                                              .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                                              .toList(),
                                          onChanged: (value) {
                                            if (value == null) return;
                                            setState(() {
                                              _categoryCtrl.text = value;
                                              _productCategoryError = null;
                                            });
                                          },
                                        ),
                                        if (_productCategoryError != null) _buildInlineError(_productCategoryError!),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _formLabel('STOCK *'),
                                        const SizedBox(height: 8),
                                        _buildInput(
                                          _unitsCtrl,
                                          '0',
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          minHeight: 50,
                                          withBottomPadding: false,
                                          hasError: _productStockError != null,
                                          onChanged: (_) {
                                            if (_productStockError != null) setState(() => _productStockError = null);
                                          },
                                        ),
                                        if (_productStockError != null) _buildInlineError(_productStockError!),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Price
                    _formLabel('PRICE (PHP) *'),
                    const SizedBox(height: 8),
                    _buildInput(
                      _priceCtrl,
                      '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      hasError: _productPriceError != null,
                      onChanged: (_) {
                        if (_productPriceError != null) setState(() => _productPriceError = null);
                      },
                    ),
                    if (_productPriceError != null) _buildInlineError(_productPriceError!),
                    const SizedBox(height: 12),

                    // Price per Kilo (Feeds) or Price per Tablet (Medicines) - optional
                    if (_categoryCtrl.text.trim().toLowerCase() == 'feeds' ||
                        _categoryCtrl.text.trim().toLowerCase() == 'medicines' ||
                        _categoryCtrl.text.trim().toLowerCase() == 'medicine') ...[
                      _formLabel(
                        _categoryCtrl.text.trim().toLowerCase() == 'feeds'
                            ? 'PRICE PER KILO (PHP) - OPTIONAL'
                            : 'PRICE PER TABLET (PHP) - OPTIONAL',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _categoryCtrl.text.trim().toLowerCase() == 'feeds'
                            ? 'Leave blank if this feed is exclusively sold as whole sacks.'
                            : 'Leave blank if this medicine is exclusively sold as whole boxes/packs.',
                        style: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      _buildInput(
                        _kiloPriceCtrl,
                        _categoryCtrl.text.trim().toLowerCase() == 'feeds'
                            ? 'e.g., 38.00'
                            : 'e.g., 15.00',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Description
                    _formLabel('DESCRIPTION'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionCtrl,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: const [CapitalizeSentencesInputFormatter()],
                      style: GoogleFonts.plusJakartaSans(color: _fieldText, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Add product details, usage instructions, or benefits...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: _mutedColor, fontSize: 14),
                        filled: true,
                        fillColor: _fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _fieldFocus),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _isSubmitting ? null : widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 48),
                            side: BorderSide(color: _cardBorder, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              color: _titleColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitAddProduct,
                          icon: _isSubmitting
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            _isSubmitting ? 'Saving...' : 'Add Product',
                            style: GoogleFonts.plusJakartaSans(
                              color: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDark ? Colors.white : PiggyTrunkTheme.ptPrimary,
                            foregroundColor: _isDark ? PiggyTrunkTheme.ptPrimary : Colors.white,
                            minimumSize: const Size(150, 48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
