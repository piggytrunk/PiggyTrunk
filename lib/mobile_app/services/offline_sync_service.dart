import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'connectivity_service.dart';

/// Service to handle offline caching and background synchronization of user profile updates
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _keyPendingProfileUpdate = 'pt_offline_pending_profile_update';
  static const String _prefixCachedProfile = 'pt_cached_profile_';

  bool _isSyncing = false;

  /// Cache current active profile for offline persistence across app restarts
  Future<void> cacheProfile({
    required String role,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefixCachedProfile${role.toLowerCase().trim()}';
      await prefs.setString(key, jsonEncode(profileData));
    } catch (e) {
      debugPrint('[OfflineSyncService] Error caching profile: $e');
    }
  }

  /// Retrieve cached profile data when offline or during initial startup
  Future<Map<String, dynamic>?> getCachedProfile(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefixCachedProfile${role.toLowerCase().trim()}';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } catch (e) {
      debugPrint('[OfflineSyncService] Error reading cached profile: $e');
    }
    return null;
  }


  /// Get currently pending profile update payload if any
  Future<Map<String, dynamic>?> getPendingProfileUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyPendingProfileUpdate);
      if (raw != null && raw.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } catch (e) {
      debugPrint('[OfflineSyncService] Error getting pending profile update: $e');
    }
    return null;
  }

  /// Clear the pending profile update queue
  Future<void> clearPendingProfileUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPendingProfileUpdate);
    } catch (e) {
      debugPrint('[OfflineSyncService] Error clearing pending profile update: $e');
    }
  }

  /// Synchronize any pending offline profile updates to Supabase
  Future<bool> syncPendingProfileUpdates() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final payload = await getPendingProfileUpdate();
      if (payload == null) {
        _isSyncing = false;
        return true;
      }

      final hasNet = await ConnectivityService.hasInternet();
      if (!hasNet) {
        debugPrint('[OfflineSyncService] Still offline, deferring sync.');
        _isSyncing = false;
        return false;
      }

      debugPrint('[OfflineSyncService] Syncing pending offline profile update to Supabase...');

      final role = (payload['role'] ?? '').toString();
      final name = (payload['name'] ?? '').toString();
      final phone = (payload['phone'] ?? '').toString();
      final address = (payload['address'] ?? '').toString();
      final email = payload['email']?.toString();
      final userId = payload['user_id'] is int ? payload['user_id'] as int : int.tryParse(payload['user_id']?.toString() ?? '');
      final supabaseUserId = payload['supabase_user_id']?.toString() ?? Supabase.instance.client.auth.currentUser?.id;
      final firstName = payload['first_name']?.toString();
      final middleInitial = payload['middle_initial']?.toString();
      final lastName = payload['last_name']?.toString();
      final roleSpecificId = payload['role_specific_id'] is int ? payload['role_specific_id'] as int : int.tryParse(payload['role_specific_id']?.toString() ?? '');

      final supabase = Supabase.instance.client;

      // 1. Update public.app_users
      try {
        final updateMap = <String, dynamic>{};
        if (name.isNotEmpty) updateMap['name'] = name;
        if (phone.isNotEmpty && phone != 'N/A') updateMap['phone'] = phone;
        if (address.isNotEmpty && address != 'N/A') updateMap['address'] = address;

        if (updateMap.isNotEmpty) {
          if (supabaseUserId != null && supabaseUserId.isNotEmpty) {
            await supabase.from('app_users').update(updateMap).eq('supabase_user_id', supabaseUserId);
          } else if (userId != null && userId > 0) {
            await supabase.from('app_users').update(updateMap).eq('user_id', userId);
          } else if (email != null && email.isNotEmpty) {
            await supabase.from('app_users').update(updateMap).eq('email', email);
          }
        }
      } catch (e) {
        debugPrint('[OfflineSyncService] Notice updating app_users: $e');
      }

      // 2. Update role-specific table
      try {
        if (role.contains('partner') || role.contains('investor')) {
          final partnerMap = <String, dynamic>{
            if (phone.isNotEmpty && phone != 'N/A') 'contact_number': phone,
            if (address.isNotEmpty && address != 'N/A') 'address': address,
          };
          if (partnerMap.isNotEmpty) {
            if (roleSpecificId != null && roleSpecificId > 0) {
              await supabase.from('partner_investors').update(partnerMap).eq('partner_investor_id', roleSpecificId);
            } else if (userId != null && userId > 0) {
              await supabase.from('partner_investors').update(partnerMap).eq('user_id', userId);
            }
          }
        } else if (role.contains('raiser')) {
          final raiserMap = <String, dynamic>{
            if (name.isNotEmpty) 'name': name,
            if (phone.isNotEmpty && phone != 'N/A') 'phone': phone,
            if (address.isNotEmpty && address != 'N/A') 'address': address,
          };
          if (raiserMap.isNotEmpty) {
            if (roleSpecificId != null && roleSpecificId > 0) {
              await supabase.from('hog_raisers').update(raiserMap).eq('hog_raiser_id', roleSpecificId);
            } else if (userId != null && userId > 0) {
              await supabase.from('hog_raisers').update(raiserMap).eq('user_id', userId);
            }
          }
        } else if (role.contains('cashier')) {
          final cashierMap = <String, dynamic>{
            if (phone.isNotEmpty && phone != 'N/A') 'contact_number': phone,
            if (phone.isNotEmpty && phone != 'N/A') 'phone': phone,
            if (address.isNotEmpty && address != 'N/A') 'address': address,
            if (address.isNotEmpty && address != 'N/A') 'store_address': address,
          };
          if (cashierMap.isNotEmpty) {
            if (roleSpecificId != null && roleSpecificId > 0) {
              await supabase.from('cashiers').update(cashierMap).eq('cashier_id', roleSpecificId);
            } else if (userId != null && userId > 0) {
              await supabase.from('cashiers').update(cashierMap).eq('user_id', userId);
            }
          }
        }
      } catch (e) {
        debugPrint('[OfflineSyncService] Notice updating role table: $e');
      }

      // 3. Keep Supabase auth user metadata synchronized
      if (firstName != null || lastName != null || name.isNotEmpty) {
        try {
          await supabase.auth.updateUser(
            UserAttributes(
              data: {
                'first_name': ?firstName,
                'middle_initial': ?middleInitial,
                'last_name': ?lastName,
                if (name.isNotEmpty) 'full_name': name,
                if (name.isNotEmpty) 'name': name,
              },
            ),
          );
        } catch (_) {}
      }

      // Sync successful - clear pending queue
      await clearPendingProfileUpdate();
      debugPrint('[OfflineSyncService] Pending profile update successfully synced to Supabase!');
      _isSyncing = false;
      return true;
    } catch (e) {
      debugPrint('[OfflineSyncService] Failed to sync pending profile update: $e');
      _isSyncing = false;
      return false;
    }
  }
}
