import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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

  /// Default fallback LocationIQ API key (or set in .env as LOCATIONIQ_API_KEY)
  static const String _defaultLocationIqApiKey = 'pk.236acad53770a6ae910ed6584124beff';

  /// Retrieves the active LocationIQ API key from .env or constant
  String get locationIqApiKey {
    try {
      final envKey = dotenv.env['LOCATIONIQ_API_KEY']?.trim();
      if (envKey != null && envKey.isNotEmpty) return envKey;
    } catch (_) {}
    return _defaultLocationIqApiKey;
  }

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

  /// Requests permission (if needed), fetches the device GPS position with highest accuracy,
  /// and reverse-geocodes it into a precise, human-readable address with maximum zoom (zoom=18)
  /// to pinpoint the exact person/device location (House #, Street/Road, Purok, Brgy, City, Province).
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
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 15),
          ),
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

      // 4. Reverse Geocode (Multi-tiered strategy with maximum zoom 18)
      LocationResult? nativeResult;
      LocationResult? iqResult;
      LocationResult? nominatimResult;

      // Tier 1 (Mobile Native): Google Play Services / Apple CoreLocation
      if (!kIsWeb) {
        nativeResult = await _reverseGeocodeNative(lat, lng);
      }

      // Tier 2: LocationIQ REST API (with zoom=18 for maximum building / rooftop / street level resolution)
      final apiKey = locationIqApiKey;
      if (apiKey.isNotEmpty) {
        iqResult = await _reverseGeocodeLocationIQ(lat, lng, apiKey);
      }

      // Tier 3: OpenStreetMap Nominatim fallback (with zoom=18)
      if (iqResult == null || iqResult.barangay == null || iqResult.barangay!.trim().isEmpty) {
        nominatimResult = await _reverseGeocodeNominatim(lat, lng);
      }

      // Barangay: area-level lookup (zoom=14) matches the barangay boundary that CONTAINS the point.
      // At zoom=18 the result snaps to the nearest road, and roads crossing barangay borders
      // inherit the neighbouring barangay — that's why the next brgy was being detected.
      LocationResult? areaResult;
      if (apiKey.isNotEmpty) {
        areaResult = await _reverseGeocodeLocationIQ(lat, lng, apiKey, zoom: 14);
      }
      if (areaResult?.barangay == null) {
        areaResult = await _reverseGeocodeNominatim(lat, lng, zoom: 14);
      }

      // Select the highest-precision components across all providers
      final bestStreet = iqResult?.street ?? nominatimResult?.street ?? nativeResult?.street;
      final bestBarangay = areaResult?.barangay ?? nativeResult?.barangay ?? iqResult?.barangay ?? nominatimResult?.barangay;
      final bestMunicipality = iqResult?.municipality ?? nominatimResult?.municipality ?? nativeResult?.municipality;

      // Prefer province like "Pangasinan" over region like "Ilocos Region"
      final candidateProvinces = [
        iqResult?.province,
        nominatimResult?.province,
        nativeResult?.province,
      ].where((p) => p != null && p.trim().isNotEmpty).cast<String>().toList();

      String? bestProvince;
      for (final p in candidateProvinces) {
        if (!p.toLowerCase().contains('region')) {
          bestProvince = p;
          break;
        }
      }
      bestProvince ??= candidateProvinces.isNotEmpty ? candidateProvinces.first : null;

      final parts = <String>[];
      if (bestStreet != null && bestStreet.isNotEmpty) parts.add(bestStreet);
      if (bestBarangay != null && bestBarangay.isNotEmpty) parts.add(bestBarangay);
      if (bestMunicipality != null && bestMunicipality.isNotEmpty) parts.add(bestMunicipality);
      if (bestProvince != null && bestProvince.isNotEmpty) parts.add(bestProvince);

      if (parts.isNotEmpty) {
        return LocationResult(
          success: true,
          address: parts.join(', '),
          street: bestStreet,
          barangay: bestBarangay,
          municipality: bestMunicipality,
          province: bestProvince,
          latitude: lat,
          longitude: lng,
        );
      }

      // Tier 4: Fallback to Raw GPS Coordinates
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

  /// Tier 2: LocationIQ REST API (zoom=18 for exact building / house / rooftop level resolution)
  /// Documentation: https://locationiq.com/docs#reverse-geocoding
  Future<LocationResult?> _reverseGeocodeLocationIQ(double lat, double lon, String apiKey, {int zoom = 18}) async {
    try {
      final url = Uri.parse(
        'https://us1.locationiq.com/v1/reverse?key=$apiKey&lat=$lat&lon=$lon&format=json&zoom=$zoom&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'PiggyTrunkApp/1.0',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[LocationService] LocationIQ response: ${data['display_name']}');
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final parts = <String>[];

          // 1. Exact Spot: House Number, Building, Landmark, Amenity, Shop
          final houseNumber = address['house_number']?.toString().trim();
          final building = (address['building'] ??
                  address['house_name'] ??
                  address['amenity'] ??
                  address['shop'] ??
                  address['office'] ??
                  address['tourism'])
              ?.toString()
              .trim();

          // 2. Road / Street / Thoroughfare
          var road = (address['road'] ??
                  address['street'] ??
                  address['pedestrian'] ??
                  address['footway'] ??
                  address['path'] ??
                  address['track'] ??
                  address['highway'])
              ?.toString()
              .trim();

          if ((road == null || road.isEmpty) && address['quarter'] != null) {
            final q = address['quarter'].toString().trim();
            final isStreet = RegExp(r'\b(street|road|st\.?|rd\.?|ave|avenue|hwy|highway|dr|drive|lane|ln|alley)\b', caseSensitive: false).hasMatch(q);
            if (isStreet) {
              road = q;
            }
          }

          // Form exact street string
          String? exactStreet;
          if (houseNumber != null && houseNumber.isNotEmpty && road != null && road.isNotEmpty) {
            exactStreet = '$houseNumber $road';
          } else if (building != null && building.isNotEmpty && road != null && road.isNotEmpty) {
            exactStreet = '$building, $road';
          } else if (road != null && road.isNotEmpty) {
            exactStreet = road;
          } else if (building != null && building.isNotEmpty) {
            exactStreet = building;
          }

          if (exactStreet != null && exactStreet.isNotEmpty) {
            parts.add(exactStreet);
          }

          // 3. Purok / Sitio / Neighbourhood
          final rawNeighbourhood = (address['neighbourhood'] ??
                  address['purok'] ??
                  address['sitio'] ??
                  address['hamlet'] ??
                  address['subdivision'])
              ?.toString()
              .trim();

          // 4. Municipality / City / Town (evaluate first to assist in barangay parsing)
          final rawCity = address['city'] ?? address['town'] ?? address['municipality'] ?? address['county'];
          String? municipality;
          if (rawCity != null && rawCity.toString().trim().isNotEmpty) {
            final c = rawCity.toString().trim();
            municipality = c.toLowerCase().endsWith('city') ? c : (c.toLowerCase() == 'san carlos' ? '$c City' : c);
          }

          // 5. Barangay
          dynamic rawBrgy = address['village'] ??
              address['suburb'] ??
              address['neighbourhood'] ??
              address['hamlet'] ??
              address['residential'] ??
              address['city_district'] ??
              address['subdistrict'] ??
              address['barangay'];

          if (rawBrgy == null && address['quarter'] != null) {
            final q = address['quarter'].toString().trim();
            final isStreet = RegExp(r'\b(street|road|st\.?|rd\.?|ave|avenue|hwy|highway|dr|drive|lane|ln|alley)\b', caseSensitive: false).hasMatch(q);
            if (!isStreet) {
              rawBrgy = q;
            }
          }

          String? formattedBrgy;
          if (rawBrgy != null && rawBrgy.toString().trim().isNotEmpty) {
            final b = rawBrgy.toString().trim();
            final cleanBrgy = b.replaceFirst(RegExp(r'^(Brgy\.?|Barangay)\s*', caseSensitive: false), '');
            formattedBrgy = 'Brgy. $cleanBrgy';
          } else if (data['display_name'] != null) {
            final displayName = data['display_name'].toString();
            final match = RegExp(r'(?:Brgy\.?|Barangay)\s+([A-Za-z0-9\s\-]+?)(?:,|$)', caseSensitive: false).firstMatch(displayName);
            if (match != null && match.group(1) != null) {
              formattedBrgy = 'Brgy. ${match.group(1)!.trim()}';
            } else if (municipality != null && municipality.isNotEmpty) {
              final mLower = municipality.toLowerCase();
              final tokens = displayName.split(',').map((s) => s.trim()).toList();
              final cityIdx = tokens.indexWhere((t) => t.toLowerCase() == mLower || t.toLowerCase() == '$mLower city');
              if (cityIdx > 0) {
                final candidate = tokens[cityIdx - 1];
                final isStreet = RegExp(r'\b(street|road|st\.?|rd\.?|ave|avenue|hwy|highway|dr|drive|lane|ln|alley)\b', caseSensitive: false).hasMatch(candidate);
                if (!isStreet && !candidate.toLowerCase().contains('unnamed') && !candidate.toLowerCase().contains('philippines')) {
                  final clean = candidate.replaceFirst(RegExp(r'^(Brgy\.?|Barangay)\s*', caseSensitive: false), '');
                  formattedBrgy = 'Brgy. $clean';
                }
              }
            }
          }

          // Add neighbourhood / purok if distinct
          if (rawNeighbourhood != null &&
              rawNeighbourhood.isNotEmpty &&
              (formattedBrgy == null || !rawNeighbourhood.toLowerCase().contains(formattedBrgy.toLowerCase())) &&
              (exactStreet == null || !exactStreet.toLowerCase().contains(rawNeighbourhood.toLowerCase()))) {
            parts.add(rawNeighbourhood);
          }

          if (formattedBrgy != null && formattedBrgy.isNotEmpty) {
            parts.add(formattedBrgy);
          }

          if (municipality != null && municipality.isNotEmpty) {
            parts.add(municipality);
          }

          // 6. Province / State (prefer specific province like Pangasinan over Ilocos Region)
          String? province;
          final state = address['province'] ?? address['state'];
          if (state != null && state.toString().trim().isNotEmpty) {
            province = state.toString().trim();
          } else if (address['region'] != null && address['region'].toString().trim().isNotEmpty) {
            province = address['region'].toString().trim();
          }

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
      } else {
        debugPrint('[LocationService] LocationIQ HTTP status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      debugPrint('[LocationService] LocationIQ error: $e');
    }
    return null;
  }

  /// Tier 3: OpenStreetMap Nominatim with zoom=18 for exact building / house / rooftop level resolution
  Future<LocationResult?> _reverseGeocodeNominatim(double lat, double lon, {int zoom = 18}) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=$zoom&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'PiggyTrunkApp/1.0 (piggytrunk.app@gmail.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final parts = <String>[];

          // 1. Exact Spot: House Number, Building, Landmark, Amenity, Shop
          final houseNumber = address['house_number']?.toString().trim();
          final building = (address['building'] ??
                  address['house_name'] ??
                  address['amenity'] ??
                  address['shop'] ??
                  address['office'] ??
                  address['tourism'])
              ?.toString()
              .trim();

          // 2. Road / Street / Thoroughfare
          final road = (address['road'] ??
                  address['street'] ??
                  address['pedestrian'] ??
                  address['footway'] ??
                  address['path'] ??
                  address['track'] ??
                  address['highway'])
              ?.toString()
              .trim();

          // Form exact street string
          String? exactStreet;
          if (houseNumber != null && houseNumber.isNotEmpty && road != null && road.isNotEmpty) {
            exactStreet = '$houseNumber $road';
          } else if (building != null && building.isNotEmpty && road != null && road.isNotEmpty) {
            exactStreet = '$building, $road';
          } else if (road != null && road.isNotEmpty) {
            exactStreet = road;
          } else if (building != null && building.isNotEmpty) {
            exactStreet = building;
          }

          if (exactStreet != null && exactStreet.isNotEmpty) {
            parts.add(exactStreet);
          }

          // 3. Purok / Sitio / Neighbourhood
          final rawNeighbourhood = (address['neighbourhood'] ??
                  address['purok'] ??
                  address['sitio'] ??
                  address['hamlet'] ??
                  address['subdivision'])
              ?.toString()
              .trim();

          // 4. Barangay
          final dynamic rawBrgy = address['village'] ??
              address['suburb'] ??
              address['quarter'] ??
              address['residential'] ??
              address['city_district'] ??
              address['subdistrict'] ??
              address['barangay'];

          String? formattedBrgy;
          if (rawBrgy != null && rawBrgy.toString().trim().isNotEmpty) {
            final b = rawBrgy.toString().trim();
            final cleanBrgy = b.replaceFirst(RegExp(r'^(Brgy\.?|Barangay)\s*', caseSensitive: false), '');
            formattedBrgy = 'Brgy. $cleanBrgy';
          } else if (data['display_name'] != null) {
            final displayName = data['display_name'].toString();
            final match = RegExp(r'(?:Brgy\.?|Barangay)\s+([A-Za-z0-9\s\-]+?)(?:,|$)', caseSensitive: false).firstMatch(displayName);
            if (match != null && match.group(1) != null) {
              formattedBrgy = 'Brgy. ${match.group(1)!.trim()}';
            }
          }

          if (rawNeighbourhood != null &&
              rawNeighbourhood.isNotEmpty &&
              (formattedBrgy == null || !rawNeighbourhood.toLowerCase().contains(formattedBrgy.toLowerCase())) &&
              (exactStreet == null || !exactStreet.toLowerCase().contains(rawNeighbourhood.toLowerCase()))) {
            parts.add(rawNeighbourhood);
          }

          if (formattedBrgy != null && formattedBrgy.isNotEmpty) {
            parts.add(formattedBrgy);
          }

          // 5. Municipality / City / Town
          final city = address['city'] ?? address['town'] ?? address['municipality'] ?? address['county'];
          String? municipality;
          if (city != null && city.toString().trim().isNotEmpty) {
            municipality = city.toString().trim();
            parts.add(municipality);
          }

          // 6. Province / State
          final state = address['state'] ?? address['province'] ?? address['region'];
          String? province;
          if (state != null && state.toString().trim().isNotEmpty) {
            province = state.toString().trim();
            parts.add(province);
          }

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

        // Display name fallback
        if (data['display_name'] != null) {
          final displayName = data['display_name'].toString();
          final split = displayName.split(',');
          if (split.length >= 3) {
            return LocationResult(
              success: true,
              address: split.take(4).map((s) => s.trim()).join(', '),
              latitude: lat,
              longitude: lon,
            );
          }
          return LocationResult(
            success: true,
            address: displayName,
            latitude: lat,
            longitude: lon,
          );
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Nominatim fallback error: $e');
    }
    return null;
  }

  /// Tier 1: Native Android / iOS Geocoder (Google Play Services / Apple CoreLocation)
  Future<LocationResult?> _reverseGeocodeNative(double lat, double lon) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        debugPrint('[LocationService] Native Placemark: subLocality="${p.subLocality}", name="${p.name}", street="${p.street}", thoroughfare="${p.thoroughfare}", subThoroughfare="${p.subThoroughfare}", locality="${p.locality}", subAdmin="${p.subAdministrativeArea}", admin="${p.administrativeArea}"');

        // Helper to check if a string is a Plus Code (e.g. "7Q5G+5W San Carlos") or "Unnamed"
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

        // 1. Exact Street / House / Landmark
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

        // 2. Sub-locality / Barangay (scan all placemarks)
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

        // 3. Locality (City or Municipality)
        String? municipality;
        if (p.locality != null && p.locality!.trim().isNotEmpty) {
          final c = p.locality!.trim();
          municipality = c.toLowerCase().endsWith('city') ? c : (c.toLowerCase() == 'san carlos' ? '$c City' : c);
        } else if (p.subAdministrativeArea != null && p.subAdministrativeArea!.trim().isNotEmpty) {
          municipality = p.subAdministrativeArea!.trim();
        }

        // 4. Administrative Area (Province)
        // Prefer subAdministrativeArea (e.g. Pangasinan) over administrativeArea (e.g. Ilocos Region)
        String? province;
        if (p.subAdministrativeArea != null && p.subAdministrativeArea!.trim().isNotEmpty && p.subAdministrativeArea != municipality) {
          province = p.subAdministrativeArea!.trim();
        } else if (p.administrativeArea != null && p.administrativeArea!.trim().isNotEmpty) {
          province = p.administrativeArea!.trim();
        }

        final parts = <String>[];
        if (exactStreet != null && exactStreet.isNotEmpty) {
          parts.add(exactStreet);
        }
        if (formattedBrgy != null && formattedBrgy.isNotEmpty) {
          parts.add(formattedBrgy);
        }
        if (municipality != null && municipality.isNotEmpty) {
          parts.add(municipality);
        }
        if (province != null && province.isNotEmpty) {
          parts.add(province);
        }

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
