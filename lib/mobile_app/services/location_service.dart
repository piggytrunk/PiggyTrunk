import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Represents an address suggestion candidate returned from OpenStreetMap search autocomplete
class AddressSuggestion {
  final String fullAddress;
  final String? houseNumber;
  final String? street;
  final String? barangay;
  final String? municipality;
  final String? province;
  final double? latitude;
  final double? longitude;

  AddressSuggestion({
    required this.fullAddress,
    this.houseNumber,
    this.street,
    this.barangay,
    this.municipality,
    this.province,
    this.latitude,
    this.longitude,
  });

  /// Short primary label for display in suggestion list (e.g. "#124 Roxas Blvd, Brgy. Cacaritan" or "Brgy. Cacaritan")
  String get primaryText {
    final parts = <String>[];
    if (houseNumber != null && houseNumber!.isNotEmpty && street != null && street!.isNotEmpty) {
      parts.add('$houseNumber $street');
    } else if (street != null && street!.isNotEmpty) {
      parts.add(street!);
    } else if (houseNumber != null && houseNumber!.isNotEmpty) {
      parts.add(houseNumber!);
    }

    if (barangay != null && barangay!.isNotEmpty) {
      parts.add(barangay!);
    }

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }
    if (municipality != null && municipality!.isNotEmpty) {
      return municipality!;
    }
    return fullAddress;
  }

  /// Secondary subtitle for display in suggestion list (e.g. "San Carlos City, Pangasinan")
  String get secondaryText {
    final parts = <String>[];
    if (municipality != null && municipality!.isNotEmpty) {
      parts.add(municipality!);
    }
    if (province != null && province!.isNotEmpty && province != municipality) {
      parts.add(province!);
    }
    return parts.join(', ');
  }
}

class LocationResult {
  final bool success;
  final String? address;
  final String? street;
  final String? barangay;
  final String? municipality;
  final String? province;
  final double? latitude;
  final double? longitude;
  final String? errorMessage;
  final bool isPermanentlyDenied;

  LocationResult({
    required this.success,
    this.address,
    this.street,
    this.barangay,
    this.municipality,
    this.province,
    this.latitude,
    this.longitude,
    this.errorMessage,
    this.isPermanentlyDenied = false,
  });
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const String _osmUserAgent = 'PiggyTrunkApp/1.0 (piggytrunk.app@gmail.com)';

  /// Opens the device App Settings screen so the user can enable location permission
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('[LocationService] Error opening app settings: $e');
      return false;
    }
  }

  /// Explicitly requests location permission upfront (e.g. on first app launch after install).
  /// Returns true if permission is granted (whileInUse or always).
  Future<bool> requestPermissionUpfront() async {
    if (kIsWeb) return false;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('[LocationService] Error requesting upfront location permission: $e');
      return false;
    }
  }

  /// Requests permission (if needed), fetches the device GPS position with highest accuracy
  /// using Fused Location Provider on Android, and reverse-geocodes it via OpenStreetMap Nominatim.
  /// Formats cleanly as:
  /// - With House #: "#123 Street, Brgy. Name, City/Town, Province"
  /// - With Road only: "Street, Brgy. Name, City/Town, Province"
  /// - If no House # and no Road: "Brgy. Name, City/Town, Province"
  Future<LocationResult> getCurrentAddress({bool requestPermission = true}) async {
    try {
      // 1. Check if location services are enabled on the device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          success: false,
          errorMessage: 'Location services (GPS) are turned off on your device. Please turn them on.',
        );
      }

      // 2. Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!requestPermission) {
          return LocationResult(
            success: false,
            errorMessage: 'Location permission was denied.',
          );
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            success: false,
            errorMessage: 'Location permission was denied.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          success: false,
          isPermanentlyDenied: true,
          errorMessage: 'Location permissions are permanently denied. Please enable them in your device Settings.',
        );
      }

      // 3. Get device coordinates with maximum navigation-grade hardware accuracy
      Position? position;
      try {
        LocationSettings locationSettings;
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
            forceLocationManager: false, // Uses Google Play Services Fused Location Provider for accurate tower/Wi-Fi/GPS triangulation
            intervalDuration: const Duration(seconds: 1),
            timeLimit: const Duration(seconds: 15),
          );
        } else {
          locationSettings = const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
            timeLimit: Duration(seconds: 15),
          );
        }

        position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings,
        );
      } catch (e) {
        debugPrint('[LocationService] getCurrentPosition timeout/error, trying last known position: $e');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        return LocationResult(
          success: false,
          errorMessage: 'Unable to get GPS location. Please check your GPS signal.',
        );
      }

      final lat = position.latitude;
      final lng = position.longitude;
      debugPrint('[LocationService] Detected GPS: lat=$lat, lng=$lng');

      // 4. Reverse Geocode via OpenStreetMap Nominatim API (Headless - no map required)
      // Dual-zoom strategy:
      // - zoom 18 retrieves exact street/road and house number if available
      // - zoom 14 retrieves authoritative administrative barangay/village boundary polygon
      LocationResult? osmDetailed = await _reverseGeocodeNominatim(lat, lng, zoom: 18);
      LocationResult? osmBoundary = await _reverseGeocodeNominatim(lat, lng, zoom: 14);

      // The barangay from zoom 14 corresponds to the true administrative polygon,
      // preventing borderline roads (e.g. boundary between Balococ and Talang) from misidentifying the barangay.
      final canonicalBrgy = osmBoundary?.barangay ?? osmDetailed?.barangay;
      final canonicalStreet = osmDetailed?.street ?? osmBoundary?.street;
      final canonicalCity = osmDetailed?.municipality ?? osmBoundary?.municipality;
      final canonicalProvince = osmDetailed?.province ?? osmBoundary?.province;

      if (canonicalBrgy != null && canonicalBrgy.isNotEmpty) {
        final parts = <String>[];
        if (canonicalStreet != null && canonicalStreet.isNotEmpty) parts.add(canonicalStreet);
        parts.add(canonicalBrgy);
        if (canonicalCity != null && canonicalCity.isNotEmpty) parts.add(canonicalCity);
        if (canonicalProvince != null && canonicalProvince.isNotEmpty) parts.add(canonicalProvince);

        return LocationResult(
          success: true,
          address: parts.join(', '),
          street: canonicalStreet,
          barangay: canonicalBrgy,
          municipality: canonicalCity,
          province: canonicalProvince,
          latitude: lat,
          longitude: lng,
        );
      }

      if (osmDetailed != null && osmDetailed.success && osmDetailed.address != null && osmDetailed.address!.isNotEmpty) {
        return osmDetailed;
      }
      if (osmBoundary != null && osmBoundary.success && osmBoundary.address != null && osmBoundary.address!.isNotEmpty) {
        return osmBoundary;
      }

      // Tier 2 Fallback: Native OS Geocoder (Google Play Services / Apple CoreLocation)
      if (!kIsWeb) {
        final nativeResult = await _reverseGeocodeNative(lat, lng);
        if (nativeResult != null && nativeResult.success) {
          return nativeResult;
        }
      }

      // Tier 3 Fallback: Raw GPS Coordinates
      return LocationResult(
        success: true,
        address: 'Lat: ${lat.toStringAsFixed(4)}, Long: ${lng.toStringAsFixed(4)}',
        latitude: lat,
        longitude: lng,
      );
    } on MissingPluginException catch (e) {
      debugPrint('[LocationService] MissingPluginException: $e');
      return LocationResult(
        success: false,
        errorMessage: 'The new GPS plugin requires a full app restart. Please re-run the app.',
      );
    } on PlatformException catch (e) {
      debugPrint('[LocationService] PlatformException: $e');
      return LocationResult(
        success: false,
        errorMessage: e.message ?? 'Location permission error.',
      );
    } catch (e) {
      debugPrint('[LocationService] General error: $e');
      return LocationResult(
        success: false,
        errorMessage: 'Failed to detect location: ${e.toString()}',
      );
    }
  }

  /// OpenStreetMap Nominatim reverse geocoding (Headless REST API)
  Future<LocationResult?> _reverseGeocodeNominatim(double lat, double lon, {int zoom = 18}) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=$zoom&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': _osmUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final parsed = parsePhilippineAddress(
            addressDetails: address,
            fallbackDisplayName: data['display_name']?.toString(),
          );

          if (parsed.fullAddress.isNotEmpty) {
            return LocationResult(
              success: true,
              address: parsed.fullAddress,
              street: parsed.street,
              barangay: parsed.barangay,
              municipality: parsed.municipality,
              province: parsed.province,
              latitude: lat,
              longitude: lon,
            );
          }
        }

        if (data['display_name'] != null) {
          final displayName = data['display_name'].toString();
          return LocationResult(
            success: true,
            address: displayName,
            latitude: lat,
            longitude: lon,
          );
        }
      }
    } catch (e) {
      debugPrint('[LocationService] OSM Nominatim reverse error: $e');
    }
    return null;
  }

  /// Sanitizes user typed queries for Philippine OpenStreetMap Nominatim search:
  /// - Strips house numbers / lot prefixes (preserves them separately for display)
  /// - Strips administrative noise keywords ('city', 'lungsod', 'brgy', 'barangay', 'bgy', 'province', 'prov', 'region')
  ///   because OpenStreetMap indexes nodes without administrative suffixes (e.g. "San Carlos" not "San Carlos City").
  /// - Removes commas, hyphens, and multiple spaces
  static String sanitizePhilippineSearchQuery(String raw) {
    var s = raw.trim();

    // 1. Remove house plate prefix if present
    final houseMatch = RegExp(
      r'^([#№]?[0-9]+[A-Za-z]?(?:\s*-\s*[0-9]+)?|[Bb]lock\s*\d+\s*[Ll]ot\s*\d+|[Uu]nit\s*[A-Za-z0-9]+)\b',
    ).firstMatch(s);
    if (houseMatch != null) {
      s = s.substring(houseMatch.end).trim();
    }

    // 2. Strip Philippine administrative prefixes and suffixes that break OpenStreetMap text search
    s = s.replaceAll(
      RegExp(
        r'\b(brgy\.?|barangay|bgy\.?|city|lungsod|province|prov\.?|region|reg\.?)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // 3. Strip special punctuation and normalize spaces
    s = s.replaceAll(RegExp(r'[,.\-#]+'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  /// Searches OpenStreetMap for address suggestions based on user typing.
  /// Intelligently sanitizes queries (e.g. "balococ San Carlos City pangasinan" -> "balococ San Carlos pangasinan")
  /// so OpenStreetMap returns instant, accurate matches for Philippine barangays and cities.
  /// Extracts and preserves house number plates (e.g. "#124", "124-B", "Unit 3", "Block 4 Lot 10").
  Future<List<AddressSuggestion>> searchAddressSuggestions(String query, {double? lat, double? lon}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    // Extract house/unit/lot number prefix if user typed one
    final houseMatch = RegExp(
      r'^([#№]?[0-9]+[A-Za-z]?(?:\s*-\s*[0-9]+)?|[Bb]lock\s*\d+\s*[Ll]ot\s*\d+|[Uu]nit\s*[A-Za-z0-9]+)\b',
    ).firstMatch(trimmed);

    final typedPrefix = houseMatch?.group(1)?.trim();

    // Clean query by removing administrative noise words (City, Brgy, etc.)
    final cleanedQuery = sanitizePhilippineSearchQuery(trimmed);

    // Build priority list of query candidates to maximize match rate:
    // 1. Cleaned query without noise words (e.g. "balococ San Carlos pangasinan")
    // 2. Fallback: First 2 significant tokens (e.g. "balococ San Carlos")
    // 3. Fallback: Single primary token if different (e.g. "balococ")
    // 4. Fallback: Raw query as typed by user
    final queriesToTry = <String>[];
    if (cleanedQuery.isNotEmpty) {
      queriesToTry.add(cleanedQuery);
      final tokens = cleanedQuery.split(' ').where((t) => t.isNotEmpty).toList();
      if (tokens.length > 2) {
        queriesToTry.add('${tokens[0]} ${tokens[1]}');
      }
      if (tokens.isNotEmpty && tokens[0] != cleanedQuery && tokens[0].length >= 3) {
        queriesToTry.add(tokens[0]);
      }
    }
    if (!queriesToTry.contains(trimmed)) {
      queriesToTry.add(trimmed);
    }

    for (final q in queriesToTry) {
      if (q.trim().length < 2) continue;
      // 1. Try OpenStreetMap Nominatim search
      var results = await _executeOsmSearch(q, userTypedPrefix: typedPrefix);
      if (results.isNotEmpty) {
        debugPrint('[LocationService] OSM Nominatim matched "$q" -> ${results.length} results');
        return results;
      }

      // 2. Fallback to OpenStreetMap Photon autocomplete engine (Komoot)
      results = await _executePhotonSearch(q, userTypedPrefix: typedPrefix);
      if (results.isNotEmpty) {
        debugPrint('[LocationService] OSM Photon matched "$q" -> ${results.length} results');
        return results;
      }
    }

    return [];
  }

  /// Internal OpenStreetMap Nominatim search executor
  Future<List<AddressSuggestion>> _executeOsmSearch(String q, {String? userTypedPrefix}) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=jsonv2&addressdetails=1&countrycodes=ph&limit=6',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': _osmUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        final suggestions = <AddressSuggestion>[];
        final seenAddresses = <String>{};

        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final addr = item['address'] as Map<String, dynamic>? ?? {};
            final parsed = parsePhilippineAddress(
              userTypedPrefix: userTypedPrefix,
              addressDetails: addr,
              fallbackDisplayName: item['display_name']?.toString(),
            );

            if (parsed.fullAddress.isNotEmpty && !seenAddresses.contains(parsed.fullAddress)) {
              seenAddresses.add(parsed.fullAddress);
              suggestions.add(
                AddressSuggestion(
                  fullAddress: parsed.fullAddress,
                  houseNumber: parsed.houseNumber,
                  street: parsed.street,
                  barangay: parsed.barangay,
                  municipality: parsed.municipality,
                  province: parsed.province,
                  latitude: double.tryParse(item['lat']?.toString() ?? ''),
                  longitude: double.tryParse(item['lon']?.toString() ?? ''),
                ),
              );
            }
          }
        }
        return suggestions;
      }
    } catch (e) {
      debugPrint('[LocationService] OSM Nominatim query "$q" error: $e');
    }
    return [];
  }

  /// Internal OpenStreetMap Photon autocomplete executor (Fast type-ahead fallback)
  Future<List<AddressSuggestion>> _executePhotonSearch(String q, {String? userTypedPrefix}) async {
    try {
      final url = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(q)}&limit=6',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': _osmUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        final suggestions = <AddressSuggestion>[];
        final seenAddresses = <String>{};

        for (final item in features) {
          if (item is Map<String, dynamic>) {
            final props = item['properties'] as Map<String, dynamic>? ?? {};
            final country = props['country']?.toString().toLowerCase();
            final countryCode = props['countrycode']?.toString().toUpperCase();

            // Filter to Philippines
            if (countryCode != null && countryCode != 'PH') continue;
            if (country != null && !country.contains('philippine') && countryCode == null) continue;

            final geom = item['geometry'] as Map<String, dynamic>? ?? {};
            final coords = geom['coordinates'] as List<dynamic>?;
            final double? lon = coords != null && coords.isNotEmpty ? double.tryParse(coords[0].toString()) : null;
            final double? lat = coords != null && coords.length > 1 ? double.tryParse(coords[1].toString()) : null;

            final parsed = parsePhotonAddress(
              userTypedPrefix: userTypedPrefix,
              properties: props,
            );

            if (parsed.fullAddress.isNotEmpty && !seenAddresses.contains(parsed.fullAddress)) {
              seenAddresses.add(parsed.fullAddress);
              suggestions.add(
                AddressSuggestion(
                  fullAddress: parsed.fullAddress,
                  houseNumber: parsed.houseNumber,
                  street: parsed.street,
                  barangay: parsed.barangay,
                  municipality: parsed.municipality,
                  province: parsed.province,
                  latitude: lat,
                  longitude: lon,
                ),
              );
            }
          }
        }
        return suggestions;
      }
    } catch (e) {
      debugPrint('[LocationService] OSM Photon query "$q" error: $e');
    }
    return [];
  }

  /// Parses Photon OpenStreetMap GeoJSON feature into Philippine address format
  static ({
    String fullAddress,
    String? houseNumber,
    String? street,
    String? barangay,
    String? municipality,
    String? province,
  }) parsePhotonAddress({
    String? userTypedPrefix,
    required Map<String, dynamic> properties,
  }) {
    String? houseNum = userTypedPrefix?.trim() ?? properties['housenumber']?.toString().trim();
    if (houseNum != null && houseNum.isNotEmpty && !houseNum.startsWith('#') && RegExp(r'^\d').hasMatch(houseNum)) {
      houseNum = '#$houseNum';
    }

    final type = properties['type']?.toString().toLowerCase();
    final osmValue = properties['osm_value']?.toString().toLowerCase();

    // Barangay / District
    String? rawBrgy = properties['district']?.toString().trim() ??
        properties['locality']?.toString().trim();

    if ((rawBrgy == null || rawBrgy.isEmpty) && (osmValue == 'village' || type == 'district')) {
      rawBrgy = properties['name']?.toString().trim();
    }

    String? formattedBrgy;
    if (rawBrgy != null && rawBrgy.isNotEmpty) {
      final clean = rawBrgy.replaceFirst(RegExp(r'^(Brgy\.?|Barangay)\s*', caseSensitive: false), '').trim();
      if (clean.isNotEmpty) {
        formattedBrgy = 'Brgy. $clean';
      }
    }

    // Street
    String? streetPart;
    if (properties['street'] != null && properties['street'].toString().isNotEmpty) {
      final st = properties['street'].toString().trim();
      streetPart = (houseNum != null && houseNum.isNotEmpty) ? '$houseNum $st' : st;
    } else if (houseNum != null && houseNum.isNotEmpty) {
      streetPart = houseNum;
    }

    // Municipality / City
    final rawCity = (properties['city'] ?? properties['town'] ?? properties['county'])?.toString().trim();
    String? municipality;
    if (rawCity != null && rawCity.isNotEmpty) {
      if (rawCity.toLowerCase() == 'san carlos' && !rawCity.toLowerCase().contains('city')) {
        municipality = '$rawCity City';
      } else {
        municipality = rawCity;
      }
    }

    // Province
    final rawState = properties['state']?.toString().trim();
    String? province;
    if (rawState != null && rawState.isNotEmpty && !rawState.toLowerCase().contains('region')) {
      province = rawState;
    }

    final parts = <String>[];
    if (streetPart != null && streetPart.isNotEmpty) parts.add(streetPart);
    if (formattedBrgy != null && formattedBrgy.isNotEmpty) parts.add(formattedBrgy);
    if (municipality != null && municipality.isNotEmpty) parts.add(municipality);
    if (province != null && province.isNotEmpty) parts.add(province);

    return (
      fullAddress: parts.isNotEmpty ? parts.join(', ') : (properties['name']?.toString() ?? ''),
      houseNumber: houseNum,
      street: streetPart,
      barangay: formattedBrgy,
      municipality: municipality,
      province: province,
    );
  }

  /// Parses an OpenStreetMap address dictionary into standard Philippine format:
  /// - With House #: "#123 Rizal St., Brgy. Cacaritan, San Carlos City, Pangasinan"
  /// - With Road only: "Roxas Boulevard, Brgy. Cacaritan, San Carlos City, Pangasinan"
  /// - Without House # and Road: "Brgy. Cacaritan, San Carlos City, Pangasinan"
  static ({
    String fullAddress,
    String? houseNumber,
    String? street,
    String? barangay,
    String? municipality,
    String? province,
  }) parsePhilippineAddress({
    String? userTypedPrefix,
    Map<String, dynamic>? addressDetails,
    String? fallbackDisplayName,
  }) {
    if (addressDetails == null || addressDetails.isEmpty) {
      return (
        fullAddress: fallbackDisplayName?.trim() ?? '',
        houseNumber: userTypedPrefix,
        street: null,
        barangay: null,
        municipality: null,
        province: null,
      );
    }

    // 1. House Number
    String? houseNum = userTypedPrefix?.trim();
    if (houseNum == null || houseNum.isEmpty) {
      houseNum = addressDetails['house_number']?.toString().trim();
    }
    if (houseNum != null && houseNum.isNotEmpty && !houseNum.startsWith('#') && RegExp(r'^\d').hasMatch(houseNum)) {
      houseNum = '#$houseNum';
    }

    // 2. Road / Street / Thoroughfare
    var road = (addressDetails['road'] ??
            addressDetails['street'] ??
            addressDetails['highway'] ??
            addressDetails['pedestrian'] ??
            addressDetails['path'])
        ?.toString()
        .trim();

    final quarter = addressDetails['quarter']?.toString().trim();
    if ((road == null || road.isEmpty) && quarter != null && quarter.isNotEmpty) {
      if (RegExp(r'\b(blvd|boulevard|st|street|ave|avenue|road|rd|dr|drive|hwy|highway|lane|way)\b', caseSensitive: false).hasMatch(quarter)) {
        road = quarter;
      }
    }

    // Discard ignorable road names like 'unnamed' or Plus Codes
    if (road != null && (road.toLowerCase().contains('unnamed') || RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,}', caseSensitive: false).hasMatch(road))) {
      road = null;
    }

    String? streetPart;
    if (houseNum != null && houseNum.isNotEmpty && road != null && road.isNotEmpty) {
      streetPart = '$houseNum $road';
    } else if (houseNum != null && houseNum.isNotEmpty) {
      streetPart = houseNum;
    } else if (road != null && road.isNotEmpty) {
      streetPart = road;
    }

    // 3. Barangay
    final rawBrgy = (addressDetails['village'] ??
            addressDetails['barangay'] ??
            addressDetails['suburb'] ??
            addressDetails['residential'] ??
            addressDetails['city_district'] ??
            addressDetails['subdistrict'])
        ?.toString()
        .trim();

    String? formattedBrgy;
    if (rawBrgy != null && rawBrgy.isNotEmpty) {
      final clean = rawBrgy.replaceFirst(RegExp(r'^(Brgy\.?|Barangay)\s*', caseSensitive: false), '').trim();
      if (clean.isNotEmpty) {
        formattedBrgy = 'Brgy. $clean';
      }
    } else if (quarter != null && quarter.isNotEmpty && (road == null || !quarter.toLowerCase().contains(road.toLowerCase()))) {
      final clean = quarter.replaceFirst(RegExp(r'^(Brgy\.?|Barangay)\s*', caseSensitive: false), '').trim();
      formattedBrgy = 'Brgy. $clean';
    } else if (fallbackDisplayName != null) {
      final match = RegExp(r'(?:Brgy\.?|Barangay)\s+([A-Za-z0-9\s\-]+?)(?:,|$)', caseSensitive: false).firstMatch(fallbackDisplayName);
      if (match != null && match.group(1) != null) {
        formattedBrgy = 'Brgy. ${match.group(1)!.trim()}';
      }
    }

    // 4. Municipality / City
    final rawCity = (addressDetails['city'] ?? addressDetails['town'] ?? addressDetails['municipality'] ?? addressDetails['county'])?.toString().trim();
    String? municipality;
    if (rawCity != null && rawCity.isNotEmpty) {
      if (rawCity.toLowerCase() == 'san carlos' && !rawCity.toLowerCase().contains('city')) {
        municipality = '$rawCity City';
      } else {
        municipality = rawCity;
      }
    }

    // 5. Province
    final rawState = (addressDetails['state'] ?? addressDetails['province'])?.toString().trim();
    String? province;
    if (rawState != null && rawState.isNotEmpty && !rawState.toLowerCase().contains('region')) {
      province = rawState;
    }

    final parts = <String>[];
    if (streetPart != null && streetPart.isNotEmpty) parts.add(streetPart);
    if (formattedBrgy != null && formattedBrgy.isNotEmpty) parts.add(formattedBrgy);
    if (municipality != null && municipality.isNotEmpty) parts.add(municipality);
    if (province != null && province.isNotEmpty) parts.add(province);

    return (
      fullAddress: parts.isNotEmpty ? parts.join(', ') : (fallbackDisplayName ?? ''),
      houseNumber: houseNum,
      street: streetPart,
      barangay: formattedBrgy,
      municipality: municipality,
      province: province,
    );
  }

  /// Tier 2 Native Android / iOS Geocoder (Google Play Services / Apple CoreLocation)
  Future<LocationResult?> _reverseGeocodeNative(double lat, double lon) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        bool isIgnorable(String? s) {
          if (s == null || s.trim().isEmpty) return true;
          final lower = s.trim().toLowerCase();
          if (lower.contains('unnamed')) return true;
          if (RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,}', caseSensitive: false).hasMatch(s)) return true;
          return false;
        }

        final rawSubLocality = p.subLocality?.trim();
        final rawStreet = p.street?.trim();
        final rawThoroughfare = p.thoroughfare?.trim();
        final rawSubThoroughfare = p.subThoroughfare?.trim();
        final rawName = p.name?.trim();

        String? exactStreet;
        if (rawStreet != null &&
            !isIgnorable(rawStreet) &&
            (rawSubLocality == null || !rawStreet.toLowerCase().contains(rawSubLocality.toLowerCase()))) {
          exactStreet = rawStreet;
        } else if (rawThoroughfare != null && !isIgnorable(rawThoroughfare)) {
          if (rawSubThoroughfare != null && rawSubThoroughfare.isNotEmpty) {
            exactStreet = '$rawSubThoroughfare $rawThoroughfare';
          } else {
            exactStreet = rawThoroughfare;
          }
        } else if (rawName != null &&
            !isIgnorable(rawName) &&
            (rawSubLocality == null || !rawName.toLowerCase().contains(rawSubLocality.toLowerCase())) &&
            !rawName.toLowerCase().contains('brgy') &&
            !rawName.toLowerCase().contains('barangay')) {
          exactStreet = rawName;
        }

        String? formattedBrgy;
        for (final pl in placemarks) {
          if (pl.subLocality != null && pl.subLocality!.trim().isNotEmpty) {
            final clean = pl.subLocality!.trim().replaceFirst(RegExp(r'^(Brgy\.?|Barangay)\s*', caseSensitive: false), '');
            formattedBrgy = 'Brgy. $clean';
            break;
          }
        }
        if (formattedBrgy == null) {
          for (final pl in placemarks) {
            final nm = pl.name?.trim();
            if (nm != null && (nm.toLowerCase().contains('brgy') || nm.toLowerCase().contains('barangay'))) {
              final clean = nm.replaceFirst(RegExp(r'^(Brgy\.?|Barangay)\s*', caseSensitive: false), '');
              formattedBrgy = 'Brgy. $clean';
              break;
            }
          }
        }

        String? municipality;
        if (p.locality != null && p.locality!.trim().isNotEmpty) {
          final c = p.locality!.trim();
          municipality = c.toLowerCase().endsWith('city') ? c : (c.toLowerCase() == 'san carlos' ? '$c City' : c);
        } else if (p.subAdministrativeArea != null && p.subAdministrativeArea!.trim().isNotEmpty) {
          municipality = p.subAdministrativeArea!.trim();
        }

        String? province;
        if (p.subAdministrativeArea != null && p.subAdministrativeArea!.trim().isNotEmpty && p.subAdministrativeArea != municipality) {
          province = p.subAdministrativeArea!.trim();
        } else if (p.administrativeArea != null && p.administrativeArea!.trim().isNotEmpty) {
          province = p.administrativeArea!.trim();
        }

        final parts = <String>[];
        if (exactStreet != null && exactStreet.isNotEmpty) parts.add(exactStreet);
        if (formattedBrgy != null && formattedBrgy.isNotEmpty) parts.add(formattedBrgy);
        if (municipality != null && municipality.isNotEmpty) parts.add(municipality);
        if (province != null && province.isNotEmpty) parts.add(province);

        if (parts.isNotEmpty) {
          return LocationResult(
            success: true,
            address: parts.join(', '),
            street: exactStreet,
            barangay: formattedBrgy,
            municipality: municipality,
            province: province,
            latitude: lat,
            longitude: lon,
          );
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Native Geocoder failed: $e');
    }
    return null;
  }
}
