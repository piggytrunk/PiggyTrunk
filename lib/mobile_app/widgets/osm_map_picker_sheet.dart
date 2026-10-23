import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:piggytrunk/mobile_app/services/location_service.dart';
import 'package:piggytrunk/theme/app_theme.dart';

/// The result returned when a user selects a location using the map picker.
class MapPickerResult {
  final String fullAddress;
  final String? houseOrPurok;
  final String? street;
  final String? barangay;
  final String? municipality;
  final String? province;
  final double latitude;
  final double longitude;

  const MapPickerResult({
    required this.fullAddress,
    this.houseOrPurok,
    this.street,
    this.barangay,
    this.municipality,
    this.province,
    required this.latitude,
    required this.longitude,
  });
}

/// An interactive OpenStreetMap bottom sheet modal that allows users to pinpoint
/// their house, farm, or pig pen on the map and specify an optional house number or purok.
class OsmMapPickerSheet extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialPrefix;
  final String? initialAddress;

  const OsmMapPickerSheet({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialPrefix,
    this.initialAddress,
  });

  /// Helper static method to show the map picker modal bottom sheet
  static Future<MapPickerResult?> show(
    BuildContext context, {
    double? initialLatitude,
    double? initialLongitude,
    String? initialPrefix,
    String? initialAddress,
  }) {
    return showModalBottomSheet<MapPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => OsmMapPickerSheet(
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        initialPrefix: initialPrefix,
        initialAddress: initialAddress,
      ),
    );
  }

  @override
  State<OsmMapPickerSheet> createState() => _OsmMapPickerSheetState();
}

class _OsmMapPickerSheetState extends State<OsmMapPickerSheet> {
  // Default coordinates: Lingayen, Pangasinan (default center for Piggy Trunk if none provided)
  static const double _defaultLat = 16.0210;
  static const double _defaultLng = 120.2325;

  late final MapController _mapController;
  late final TextEditingController _prefixController;
  late LatLng _currentCenter;

  bool _isReverseGeocoding = false;
  bool _isLocatingGps = false;
  LocationResult? _resolvedLocation;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _prefixController = TextEditingController(text: widget.initialPrefix ?? '');

    final lat = widget.initialLatitude ?? _defaultLat;
    final lng = widget.initialLongitude ?? _defaultLng;
    _currentCenter = LatLng(lat, lng);

    // Initial reverse geocode if no coordinates or initial coordinates provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialLatitude != null && widget.initialLongitude != null) {
        _triggerReverseGeocode(_currentCenter.latitude, _currentCenter.longitude);
      } else {
        // Try getting user's current GPS position first
        _locateUserGps();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _prefixController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _locateUserGps() async {
    setState(() => _isLocatingGps = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final newPos = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentCenter = newPos;
          _isLocatingGps = false;
        });
        _mapController.move(newPos, 17.0);
        _triggerReverseGeocode(newPos.latitude, newPos.longitude);
      }
    } catch (e) {
      debugPrint('[OsmMapPickerSheet] GPS error, using current center: $e');
      if (mounted) {
        setState(() => _isLocatingGps = false);
        _triggerReverseGeocode(_currentCenter.latitude, _currentCenter.longitude);
      }
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _currentCenter = camera.center;
    if (hasGesture) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) {
          _triggerReverseGeocode(_currentCenter.latitude, _currentCenter.longitude);
        }
      });
    }
  }

  Future<void> _triggerReverseGeocode(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isReverseGeocoding = true);

    try {
      final res = await LocationService.instance.getAddressFromCoordinates(lat, lng);
      if (mounted) {
        setState(() {
          _resolvedLocation = res;
          _isReverseGeocoding = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReverseGeocoding = false);
      }
    }
  }

  void _confirmSelection() {
    final prefix = _prefixController.text.trim();
    String formattedAddress = '';

    if (_resolvedLocation != null && _resolvedLocation!.address != null) {
      final rawAddress = _resolvedLocation!.address!;
      if (prefix.isNotEmpty) {
        // Avoid duplicate prefix if rawAddress already begins with it
        if (rawAddress.toLowerCase().startsWith(prefix.toLowerCase())) {
          formattedAddress = rawAddress;
        } else {
          formattedAddress = '$prefix, $rawAddress';
        }
      } else {
        formattedAddress = rawAddress;
      }
    } else if (prefix.isNotEmpty) {
      formattedAddress = prefix;
    } else {
      formattedAddress = 'Lat: ${_currentCenter.latitude.toStringAsFixed(5)}, Lng: ${_currentCenter.longitude.toStringAsFixed(5)}';
    }

    final result = MapPickerResult(
      fullAddress: formattedAddress,
      houseOrPurok: prefix.isNotEmpty ? prefix : null,
      street: _resolvedLocation?.street,
      barangay: _resolvedLocation?.barangay,
      municipality: _resolvedLocation?.municipality,
      province: _resolvedLocation?.province,
      latitude: _currentCenter.latitude,
      longitude: _currentCenter.longitude,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final sheetHeight = size.height * 0.90;

    final bgColor = isDark ? PiggyTrunkTheme.ptBgDark : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? PiggyTrunkTheme.ptTextDark : PiggyTrunkTheme.ptText;
    final mutedColor = isDark ? PiggyTrunkTheme.ptMutedDark : PiggyTrunkTheme.ptMuted;
    final borderColor = isDark ? const Color(0xFF334155) : PiggyTrunkTheme.ptBorder;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PiggyTrunkTheme.ptPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: PiggyTrunkTheme.ptPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pinpoint on Map',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Move map to place pin on your house or farm',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: mutedColor),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Map Area with Center Pin Overlay
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentCenter,
                      initialZoom: 16.5,
                      minZoom: 5.0,
                      maxZoom: 18.5,
                      onPositionChanged: _onPositionChanged,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.piggytrunk.app',
                        maxZoom: 19,
                      ),
                    ],
                  ),

                  // Fixed Center Marker Pin
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 38), // Anchor pin tip at exact center
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: PiggyTrunkTheme.ptPrimary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _isReverseGeocoding ? 'Detecting...' : 'Pin Location',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Icon(
                            Icons.location_on_rounded,
                            size: 44,
                            color: PiggyTrunkTheme.ptAccent,
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Floating GPS Recenter & Zoom Controls
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Zoom in
                        FloatingActionButton.small(
                          heroTag: 'map_zoom_in',
                          backgroundColor: cardColor,
                          foregroundColor: textColor,
                          elevation: 3,
                          onPressed: () {
                            final currentZoom = _mapController.camera.zoom;
                            _mapController.move(_currentCenter, currentZoom + 1);
                          },
                          child: const Icon(Icons.add, size: 20),
                        ),
                        const SizedBox(height: 8),
                        // Zoom out
                        FloatingActionButton.small(
                          heroTag: 'map_zoom_out',
                          backgroundColor: cardColor,
                          foregroundColor: textColor,
                          elevation: 3,
                          onPressed: () {
                            final currentZoom = _mapController.camera.zoom;
                            _mapController.move(_currentCenter, currentZoom - 1);
                          },
                          child: const Icon(Icons.remove, size: 20),
                        ),
                        const SizedBox(height: 8),
                        // GPS Recenter Button
                        FloatingActionButton.small(
                          heroTag: 'map_recenter_gps',
                          backgroundColor: cardColor,
                          foregroundColor: PiggyTrunkTheme.ptPrimary,
                          elevation: 4,
                          onPressed: _isLocatingGps ? null : _locateUserGps,
                          child: _isLocatingGps
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: PiggyTrunkTheme.ptPrimary,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Confirmation & Details Sheet
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(top: BorderSide(color: borderColor)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resolved Location Display
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: PiggyTrunkTheme.ptSuccess.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: PiggyTrunkTheme.ptSuccess,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SELECTED LOCATION',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: mutedColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (_isReverseGeocoding)
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Fetching address from OpenStreetMap...',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: mutedColor,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  _resolvedLocation?.address ??
                                      'Lat: ${_currentCenter.latitude.toStringAsFixed(4)}, Lng: ${_currentCenter.longitude.toStringAsFixed(4)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Editable House # / Purok / Landmark input
                    TextField(
                      controller: _prefixController,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'House No. / Purok / Landmark (Optional)',
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: mutedColor,
                        ),
                        hintText: 'e.g. #261 Purok 4, Near Yellow Gate',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: mutedColor.withValues(alpha: 0.6),
                        ),
                        prefixIcon: Icon(
                          Icons.home_work_outlined,
                          size: 18,
                          color: mutedColor,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: PiggyTrunkTheme.ptPrimary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Confirm Location Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isReverseGeocoding ? null : _confirmSelection,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: Text(
                          'Confirm Location',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PiggyTrunkTheme.ptPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
