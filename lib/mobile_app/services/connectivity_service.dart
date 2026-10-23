import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline_sync_service.dart';

/// Tracks a *real* internet connection (not just "Wi-Fi is on").
/// - `connectivity_plus` gives instant Wi-Fi/data toggle events.
/// - A ping to the Supabase auth health endpoint confirms internet works.
class ConnectivityService {
  static final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  static StreamSubscription<List<ConnectivityResult>>? _sub;
  static Timer? _retryTimer;
  static bool _started = false;

  /// Starts listening. Safe to call multiple times.
  static void start() {
    if (_started) return;
    _started = true;
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.every((r) => r == ConnectivityResult.none)) {
        _setOnline(false);
      } else {
        refresh();
      }
    });
    refresh();
  }

  /// Re-checks via ping and updates [isOnline].
  static Future<bool> refresh() async {
    final online = await hasInternet();
    _setOnline(online);
    return online;
  }

  static void _setOnline(bool online) {
    final bool wasOffline = !isOnline.value;
    isOnline.value = online;
    _retryTimer?.cancel();
    // While offline, keep re-checking in case the OS doesn't fire an event.
    if (!online) {
      _retryTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (await hasInternet()) _setOnline(true);
      });
    } else if (wasOffline) {
      // Device transitioned back online: automatically sync any queued offline changes
      OfflineSyncService().syncPendingProfileUpdates();
    }
  }

  static Future<bool> hasInternet({Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final rest = Supabase.instance.client.rest;
      final base = rest.url.replaceFirst(RegExp(r'/rest/v1/?$'), '');
      await http
          .get(Uri.parse('$base/auth/v1/health'), headers: rest.headers)
          .timeout(timeout);
      // Any HTTP response at all means the device reached the server.
      return true;
    } catch (_) {
      return false;
    }
  }

  /// True when an exception looks like a dropped / missing connection.
  static bool isNetworkError(Object e) {
    final s = e.toString().toLowerCase();
    return e is TimeoutException ||
        e is http.ClientException ||
        s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('network is unreachable') ||
        s.contains('connection refused') ||
        s.contains('connection closed') ||
        s.contains('xmlhttprequest error') ||
        s.contains('failed to fetch');
  }

  @visibleForTesting
  static void dispose() {
    _sub?.cancel();
    _retryTimer?.cancel();
    _started = false;
  }
}
