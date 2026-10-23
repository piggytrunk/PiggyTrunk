import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:piggytrunk/theme/app_theme.dart';
import '../services/location_service.dart';
import 'osm_map_picker_sheet.dart';

/// A sleek, typable address field with debounced OpenStreetMap live suggestions,
/// house number plate support, interactive pin map picker, and one-tap GPS auto-detection.
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onAutoDetect;
  final VoidCallback? onPickOnMap;
  final bool enableMapPicker;
  final bool isDetectingGps;
  final ValueChanged<AddressSuggestion>? onAddressSelected;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final bool hasError;
  final String? errorText;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.onAutoDetect,
    this.onPickOnMap,
    this.enableMapPicker = true,
    this.isDetectingGps = false,
    this.onAddressSelected,
    this.onChanged,
    this.hintText,
    this.hasError = false,
    this.errorText,
  });

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  List<AddressSuggestion> _suggestions = [];
  bool _isSearching = false;
  String _lastQueried = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Delay closing suggestions so taps on suggestion rows register cleanly
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() {
            _suggestions = [];
            _isSearching = false;
          });
        }
      });
    }
  }

  void _onTextChanged(String text) {
    widget.onChanged?.call(text);
    _debounceTimer?.cancel();

    final query = text.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _lastQueried = '';
      });
      return;
    }

    if (query == _lastQueried) return;

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      _lastQueried = query;

      final results = await LocationService.instance.searchAddressSuggestions(query);
      debugPrint('[AddressAutocomplete] "$query" -> ${results.length} suggestions');
      if (mounted && _lastQueried == query) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
        if (results.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _focusNode.hasFocus) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 250),
                alignment: 0.5,
              );
            }
          });
        }
      }
    });
  }

  void _selectSuggestion(AddressSuggestion suggestion) {
    widget.controller.text = suggestion.fullAddress;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.fullAddress.length),
    );
    setState(() {
      _suggestions = [];
      _isSearching = false;
      _lastQueried = suggestion.fullAddress;
    });
    _focusNode.unfocus();
    widget.onAddressSelected?.call(suggestion);
    widget.onChanged?.call(suggestion.fullAddress);
  }

  void _clearField() {
    widget.controller.clear();
    setState(() {
      _suggestions = [];
      _isSearching = false;
      _lastQueried = '';
    });
    widget.onChanged?.call('');
  }

  Future<void> _handlePickOnMap() async {
    _focusNode.unfocus();
    if (widget.onPickOnMap != null) {
      widget.onPickOnMap!();
      return;
    }
    final currentText = widget.controller.text.trim();
    final prefixInfo = LocationService.extractPhilippinePrefix(currentText);
    final result = await OsmMapPickerSheet.show(
      context,
      initialPrefix: prefixInfo?.prefix,
      initialAddress: currentText,
    );
    if (result != null && result.fullAddress.isNotEmpty) {
      widget.controller.text = result.fullAddress;
      widget.onChanged?.call(result.fullAddress);
      if (widget.onAddressSelected != null) {
        widget.onAddressSelected!(
          AddressSuggestion(
            fullAddress: result.fullAddress,
            houseNumber: result.houseOrPurok,
            street: result.street,
            barangay: result.barangay,
            municipality: result.municipality,
            province: result.province,
            latitude: result.latitude,
            longitude: result.longitude,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor = PiggyTrunkTheme.ptPrimary;
    final actionColor = isDark ? Colors.white : brandColor;
    final errorBorderColor = const Color(0xFFEF4444);
    final normalBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fieldFillColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final titleTextColor = isDark ? Colors.white : PiggyTrunkTheme.ptText;
    final hintTextColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Typable Text Field
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          readOnly: widget.isDetectingGps,
          keyboardType: TextInputType.streetAddress,
          textCapitalization: TextCapitalization.words,
          onChanged: _onTextChanged,
          style: GoogleFonts.plusJakartaSans(
            color: titleTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: widget.isDetectingGps
                ? 'Detecting location via GPS...'
                : (widget.hintText ?? 'Type house #, street, or barangay...'),
            hintStyle: GoogleFonts.plusJakartaSans(
              color: hintTextColor,
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
            ),
            prefixIcon: Icon(
              Icons.location_on_outlined,
              size: 20,
              color: widget.hasError
                  ? errorBorderColor
                  : (isDark ? Colors.white70 : brandColor),
            ),
            suffixIcon: widget.isDetectingGps
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: actionColor,
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.controller.text.trim().isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          tooltip: 'Clear',
                          onPressed: _clearField,
                        ),
                      if (widget.enableMapPicker)
                        IconButton(
                          icon: Icon(
                            Icons.map_outlined,
                            size: 19,
                            color: actionColor,
                          ),
                          tooltip: 'Pick on Map',
                          onPressed: _handlePickOnMap,
                        ),
                      if (widget.onAutoDetect != null)
                        IconButton(
                          icon: Icon(
                            Icons.my_location_rounded,
                            size: 19,
                            color: actionColor,
                          ),
                          tooltip: 'Auto-Detect Location',
                          onPressed: widget.onAutoDetect,
                        ),
                    ],
                  ),
            filled: true,
            fillColor: fieldFillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.hasError ? errorBorderColor : normalBorderColor,
                width: widget.hasError ? 1.4 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.hasError ? errorBorderColor : actionColor,
                width: 1.5,
              ),
            ),
          ),
        ),

        // Linear Searching Progress
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                color: brandColor,
              ),
            ),
          ),

        // Live OpenStreetMap Suggestions Dropdown Card
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                ),
                itemBuilder: (ctx, idx) {
                  final s = _suggestions[idx];
                  return InkWell(
                    onTap: () => _selectSuggestion(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFEFF6FF),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.place_rounded,
                                  size: 15,
                                  color: isDark ? Colors.white70 : brandColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.primaryText,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: titleTextColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (s.secondaryText.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        s.secondaryText,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : PiggyTrunkTheme.ptMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.north_west_rounded,
                                size: 14,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

        // Helpful guidance note when query yields 0 results while typing
        if (!_isSearching && _suggestions.isEmpty && widget.controller.text.trim().length >= 3 && _focusNode.hasFocus)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Type your barangay, street, or town, or tap Auto-Detect Location.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : PiggyTrunkTheme.ptMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Inline Error Text
        if (widget.errorText != null && widget.errorText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 13,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.errorText!,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFEF4444),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
