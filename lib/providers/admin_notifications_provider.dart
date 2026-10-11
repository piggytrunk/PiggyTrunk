import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_notification_model.dart';

/// Stream Provider that listens to real-time additions/modifications in the admin_notifications table
final adminNotificationsProvider = StreamProvider<List<AdminNotification>>((ref) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('admin_notifications')
      .stream(primaryKey: ['notification_id'])
      .map((rows) {
        final rawList = rows.map((row) => AdminNotification.fromJson(row)).toList();
        // Sort descending by created_at so newest notifications are first
        rawList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Deduplicate and filter out sensitive personal actions (password resets) and internal sync records
        final seenIds = <int>{};
        final seenSignatures = <String>{};
        final uniqueList = <AdminNotification>[];

        for (final notif in rawList) {
          final titleLower = notif.title.trim().toLowerCase();
          final msgLower = notif.message.trim().toLowerCase();
          final typeLower = notif.type.trim().toLowerCase();

          // 1. Exclude personal user password resets (sensitive personal credential events)
          if (titleLower.contains('password reset') ||
              msgLower.contains('reset their password') ||
              typeLower.contains('password_reset')) {
            continue;
          }

          // 2. Exclude internal backend synchronization records (e.g. cashier profile sync)
          if (typeLower == 'cashier_profile') {
            continue;
          }

          if (seenIds.contains(notif.notificationId)) continue;

          final sig = '${titleLower}_$msgLower';
          if (seenSignatures.contains(sig)) continue;

          seenIds.add(notif.notificationId);
          seenSignatures.add(sig);
          uniqueList.add(notif);
        }

        return uniqueList;
      });
});

/// Service class containing operations to manage notifications
class AdminNotificationService {
  static final _supabase = Supabase.instance.client;

  /// Marks a specific notification as read
  static Future<void> markAsRead(int notificationId) async {
    try {
      await _supabase
          .from('admin_notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId);
    } catch (_) {
      // Silently catch database failures or offline states
    }
  }

  /// Marks all unread notifications as read
  static Future<void> markAllAsRead() async {
    try {
      await _supabase
          .from('admin_notifications')
          .update({'is_read': true})
          .eq('is_read', false);
    } catch (_) {
      // Silently catch database failures or offline states
    }
  }

  /// Deletes a specific notification
  static Future<void> deleteNotification(int notificationId) async {
    try {
      await _supabase
          .from('admin_notifications')
          .delete()
          .eq('notification_id', notificationId);
    } catch (_) {
      // Silently catch database failures or offline states
    }
  }

  /// Deletes all notifications (clears list)
  static Future<void> clearAll() async {
    try {
      await _supabase
          .from('admin_notifications')
          .delete()
          .neq('notification_id', 0);
    } catch (_) {
      // Silently catch database failures or offline states
    }
  }

  /// Quick approve a user directly from notifications
  static Future<bool> quickApproveUser({
    required int userId,
    required String role,
  }) async {
    try {
      await _supabase
          .from('app_users')
          .update({'status': 'Active'})
          .eq('user_id', userId);

      if (role == 'hog_raiser' || role == 'raiser') {
        await _supabase
            .from('hog_raisers')
            .update({'status': 'Active', 'account_status': 'Active'})
            .eq('user_id', userId);
      } else if (role == 'partner') {
        await _supabase
            .from('partner_investors')
            .update({'status': 'Active'})
            .eq('user_id', userId);
      } else if (role == 'cashier') {
        await _supabase
            .from('cashiers')
            .update({'status': 'Active'})
            .eq('user_id', userId);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Quick approve an investment directly from notifications
  static Future<bool> quickApproveInvestment(int investmentId) async {
    try {
      await _supabase
          .from('investments')
          .update({'status': 'active'})
          .eq('investment_id', investmentId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Quick reject an investment directly from notifications
  static Future<bool> quickRejectInvestment(int investmentId) async {
    try {
      await _supabase
          .from('investments')
          .update({'status': 'rejected'})
          .eq('investment_id', investmentId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
