import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  RealtimeChannel? _realtimeChannel;
  bool _isInitialized = false;
  final Map<String, DateTime> _recentNotificationDebounce = {};

  /// Initializes native notification settings and Android notification channel
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification clicked with payload: ${response.payload}");
      },
    );

    // Create High Importance Channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'piggytrunk_alerts',
      'PiggyTrunk Alerts',
      description: 'System alerts and updates for PiggyTrunk app',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _isInitialized = true;
  }

  /// Requests native OS permission for notifications on mobile devices
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    // Check & request permission via Permission Handler
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      status = await Permission.notification.request();
    }

    // Also request platform-specific local notifications permissions
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    final iosImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    return status.isGranted;
  }

  /// Utility to remove emoticons / emojis to keep notification text clean, serious, and professional
  static String cleanText(String text) {
    if (text.isEmpty) return text;
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}'
      r'\u{1FA00}-\u{1FAFF}'
      r'\u{1F600}-\u{1F64F}'
      r'\u{1F680}-\u{1F6FF}'
      r'\u{2600}-\u{26FF}'
      r'\u{2700}-\u{27BF}'
      r'\u{FE00}-\u{FE0F}'
      r'\u{200D}'
      r']+',
      unicode: true,
    );
    return text.replaceAll(emojiRegex, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Translates notification title permanently to English (with comprehensive Tagalog conversion)
  static String localizeTitle(String title, [bool isFilipino = false]) {
    final clean = cleanText(title).trim();
    final lower = clean.toLowerCase();

    if (lower.contains('nakumpirma ang iyong puhunan') || lower.contains('investment confirmed')) {
      return 'Investment Confirmed!';
    }
    if (lower.contains('naaprubahan ang iyong puhunan') || lower.contains('investment approved')) {
      return 'Investment Approved!';
    }
    if (lower.contains('tinanggihan ang iyong puhunan') || lower.contains('investment declined')) {
      return 'Investment Declined';
    }
    if (lower.contains('handa na ang batch para ibenta') || lower.contains('anihin') || lower.contains('ready for selling')) {
      return 'Batch Ready for Selling / Harvest!';
    }
    if (lower.contains('may bagong investment sa iyong batch') || lower.contains('new investment in your batch')) {
      return 'New Investment in Your Batch!';
    }
    if (lower.contains('bagong investment') || lower.contains('investment na na-assign') || lower.contains('investment assigned')) {
      return 'New Investment Assigned to You!';
    }
    if (lower.contains('bagong batch') || lower.contains('batch na na-assign') || lower.contains('batch assigned')) {
      return 'New Batch Assigned to You!';
    }
    if (lower.contains('puhunan inilaan para sa') || lower.contains('pondo ang iyong batch') || lower.contains('pondo para sa iyong batch') || lower.contains('bagong pondo') || lower.contains('funds allocated')) {
      return 'New Funds Allocated for Your Batch!';
    }
    if (lower.contains('nag-restock ng feeds') || lower.contains('bagong stock') || lower.contains('bagong supply') || lower.contains('feeds restocked') || lower.contains('feeds & supplies')) {
      return 'New Feeds & Supplies Available!';
    }
    if (lower.contains('naaprubahan ang iyong request') || lower.contains('naaprubahan') || lower.contains('request approved')) {
      return 'Your Request Has Been Approved!';
    }
    if (lower.contains('tinanggihan ang iyong request') || lower.contains('tinanggihan') || lower.contains('request declined')) {
      return 'Your Request Was Declined';
    }
    if (lower.contains('na-update ang lifecycle') || lower.contains('stage updated') || lower.contains('lifecycle')) {
      return 'Lifecycle Stage Updated';
    }
    if (lower.contains('ulat sa kalusugan') || lower.contains('health report')) {
      return 'Health Report Update';
    }
    if (lower.contains('update sa kahilingan ng stock') || lower.contains('stock request update')) {
      return 'Stock Request Update';
    }
    return clean;
  }

  /// Translates notification message permanently to English
  static String localizeMessage(String message, [bool isFilipino = false]) {
    final clean = cleanText(message).trim();

    // 1. Tagalog Partner Investment with amount, tags and batch:
    // e.g. "Just Rejie nag-invest ng ₱10,000.00 para sa Selected Hogs (HOG-2, HOG-5) sa BATCH TEST 101."
    final partnerInvestTagRegex = RegExp(
      r'(.*?)\s*nag-invest ng\s*([₱\d,.]+)\s*para sa\s*(.*?)\s*sa\s*(.*?)\.?',
      caseSensitive: false,
    );
    final matchPIT = partnerInvestTagRegex.firstMatch(clean);
    if (matchPIT != null) {
      final partner = matchPIT.group(1)?.trim() ?? 'Partner Investor';
      final amount = matchPIT.group(2)?.trim() ?? '';
      final target = matchPIT.group(3)?.trim() ?? 'Selected Hogs';
      final batch = matchPIT.group(4)?.trim() ?? 'Batch';
      return '$partner invested $amount for $target in $batch.';
    }

    // 2. Investment with budget
    final investRegexWithCapitalTag = RegExp(
      r'nag-assign ang admin ng bagong investment na may\s*(\d+)\s*(.*?)\s*na may pondong\s*([₱\d,.]+)\s*para sa iyong pangangalaga\.?',
      caseSensitive: false,
    );
    final match1 = investRegexWithCapitalTag.firstMatch(clean);
    if (match1 != null) {
      final count = match1.group(1) ?? '1';
      final type = match1.group(2)?.trim() ?? 'hog';
      final capital = match1.group(3) ?? '';
      return 'Admin assigned a new investment of $count $type with a budget of $capital for your care.';
    }

    // 3. Simple Investment
    final investRegexSimpleTag = RegExp(
      r'nag-assign ang admin ng bagong investment na may\s*(\d+)\s*(.*?)\s*para sa iyong pangangalaga\.?',
      caseSensitive: false,
    );
    final match2 = investRegexSimpleTag.firstMatch(clean);
    if (match2 != null) {
      final count = match2.group(1) ?? '1';
      final type = match2.group(2)?.trim() ?? 'hog';
      return 'Admin assigned a new investment of $count $type for your care.';
    }

    // 4. Admin budget allocation
    final adminAllocTag = RegExp(
      r'naglaan ang admin ng\s*([₱\d,.]+)\s*na puhunan para sa\s*(.*?)\.\s*(.*?)\.?',
      caseSensitive: false,
    );
    final matchAlloc = adminAllocTag.firstMatch(clean);
    if (matchAlloc != null) {
      final amt = matchAlloc.group(1)?.trim() ?? '';
      final batch = matchAlloc.group(2)?.trim() ?? 'batch';
      return 'Admin allocated $amt in capital for $batch.';
    }

    // 5. Batch assignment
    final batchRegexTag = RegExp(
      r'na-assign sa iyo ng admin ang\s*(.*?)\.\s*maaari mo nang simulan ang pagsubaybay.*?logs\.?',
      caseSensitive: false,
    );
    final match3 = batchRegexTag.firstMatch(clean);
    if (match3 != null) {
      final batchName = match3.group(1)?.trim() ?? 'the batch';
      return 'Admin assigned $batchName to you. You can now start monitoring and updating logs.';
    }

    // 6. Partner funds
    final partnerFundsTag1 = RegExp(
      r'(.*?)\s*ang naglaan ng\s*([₱\d,.]+)\s*na pondo para sa\s*(.*?)\.?',
      caseSensitive: false,
    );
    final matchP1 = partnerFundsTag1.firstMatch(clean);
    if (matchP1 != null) {
      final partner = matchP1.group(1)?.trim() ?? 'A Partner Investor';
      final amount = matchP1.group(2)?.trim() ?? '';
      final batch = matchP1.group(3)?.trim() ?? 'the batch';
      return '$partner allocated $amount in funds for $batch.';
    }

    if (clean.toLowerCase().contains('naglaan ang partner ng karagdagang pondo')) {
      return clean
          .replaceAll(RegExp(r'Naglaan ang partner ng karagdagang pondo', caseSensitive: false), 'Partner allocated additional funds')
          .replaceAll(RegExp(r'para sa iyong batch', caseSensitive: false), 'for your batch');
    }

    // 7. Feed restock
    final restockRegexTag = RegExp(
      r'ang\s*(.*?)\s*ay na-restock na at available na \((.*?) units ang naidagdag\)\.?',
      caseSensitive: false,
    );
    final matchRestock = restockRegexTag.firstMatch(clean);
    if (matchRestock != null) {
      final product = matchRestock.group(1)?.trim() ?? 'Feeds';
      final units = matchRestock.group(2)?.trim() ?? '0';
      return '$product is now restocked and available ($units units added).';
    }

    // 8. Stock requests
    if (clean.toLowerCase().contains('naaprubahan ang iyong request para sa')) {
      return clean
          .replaceAll(RegExp(r'Naaprubahan ang iyong request para sa', caseSensitive: false), 'Your request has been approved for')
          .replaceAll(RegExp(r'Maaari mo na itong kunin sa tindahan\.?', caseSensitive: false), 'You can now claim it from the store.');
    }

    if (clean.toLowerCase().contains('tinanggihan ang iyong request para sa')) {
      return clean
          .replaceAll(RegExp(r'Tinanggihan ang iyong request para sa', caseSensitive: false), 'Your request was declined for');
    }

    // 9. Partner investment confirmations
    final pInvConfTag = RegExp(
      r'matagumpay kang naglaan ng\s*([₱\d,.]+)\s*na pondo para sa\s*(.*?)\.?',
      caseSensitive: false,
    );
    final matchPICTag = pInvConfTag.firstMatch(clean);
    if (matchPICTag != null) {
      final amount = matchPICTag.group(1)?.trim() ?? '';
      final batch = matchPICTag.group(2)?.trim() ?? 'batch';
      return 'You have successfully funded $amount for $batch.';
    }

    final pInvApprTag = RegExp(
      r'inaprubahan at pinagana ng admin ang iyong puhunan para sa\s*(.*?)\.?',
      caseSensitive: false,
    );
    final matchPIATag = pInvApprTag.firstMatch(clean);
    if (matchPIATag != null) {
      final batch = matchPIATag.group(1)?.trim() ?? 'batch';
      return 'Admin has approved and activated your investment for $batch.';
    }

    return clean;
  }

  /// Shows a native OS status bar / lockscreen notification
  Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final String sanitizedTitle = cleanText(title);
    final String sanitizedBody = cleanText(body);

    if (kIsWeb) {
      debugPrint('[Web Notification] $sanitizedTitle: $sanitizedBody');
      return;
    }
    await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'piggytrunk_alerts',
      'PiggyTrunk Alerts',
      channelDescription: 'System alerts and updates for PiggyTrunk app',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _localNotifications.show(
      notificationId,
      sanitizedTitle,
      sanitizedBody,
      details,
      payload: payload,
    );
  }

  /// Starts listening to Supabase Realtime notifications table specific to the user's role
  Future<void> startRoleRealtimeListener({
    required String role,
    required String userId,
    String? secondaryId,
  }) async {
    await stopListener(); // Ensure clean channel state

    final String roleLower = role.toLowerCase();
    String? tableName;

    if (roleLower == 'admin') {
      tableName = 'admin_notifications';
    } else if (roleLower == 'raiser' || roleLower == 'hog_raiser') {
      tableName = 'raiser_notifications';
    } else if (roleLower == 'partner' || roleLower == 'partner_investor') {
      tableName = 'partner_notifications';
    } else if (roleLower == 'cashier') {
      tableName = 'stock_requests';
    } else {
      debugPrint("Realtime notification channel skipped for unhandled role: $role");
      return;
    }

    final channelName = roleLower == 'cashier'
        ? 'public:stock_requests_notifs'
        : 'public:$tableName:user_${userId}_${secondaryId ?? ''}';

    try {
      final client = Supabase.instance.client;
      _realtimeChannel = client
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: tableName,
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isEmpty) return;

              if (roleLower == 'cashier') {
                final qty = newRecord['quantity'] ?? newRecord['sacks'] ?? 1;
                final prodName = newRecord['product_name'] ?? newRecord['item_name'] ?? 'Feed Stock';
                showNotification(
                  title: 'New Stock Request',
                  body: 'A raiser submitted a request for $qty sacks of $prodName.',
                  payload: newRecord.toString(),
                );
                return;
              }

              final notifUserId = newRecord['partner_investor_id']?.toString() ??
                  newRecord['user_id']?.toString() ??
                  newRecord['raiser_id']?.toString() ??
                  newRecord['hog_raiser_id']?.toString();
              
              // If user ID matches or if broadcast/admin/partner notification
              final bool matches = notifUserId == null ||
                  notifUserId == userId ||
                  (secondaryId != null && notifUserId == secondaryId) ||
                  roleLower == 'admin' ||
                  roleLower == 'partner' ||
                  roleLower == 'partner_investor';

              if (matches) {
                final title = newRecord['title']?.toString() ?? 'PiggyTrunk Alert';
                final body = newRecord['message']?.toString() ??
                    newRecord['content']?.toString() ??
                    newRecord['body']?.toString() ??
                    'You have a new update in PiggyTrunk.';

                // Real-time deduplication / debounce to prevent redundant popups
                final dedupeKey = '$roleLower:${title.trim()}:${body.trim()}';
                final now = DateTime.now();
                if (_recentNotificationDebounce.containsKey(dedupeKey)) {
                  final lastSeen = _recentNotificationDebounce[dedupeKey]!;
                  if (now.difference(lastSeen).inSeconds < 8) {
                    debugPrint("Skipping redundant realtime notification popup: $dedupeKey");
                    return;
                  }
                }
                _recentNotificationDebounce[dedupeKey] = now;

                showNotification(
                  title: title,
                  body: body,
                  payload: newRecord.toString(),
                );
              }
            },
          )
          .subscribe();
      
      debugPrint("Subscribed to Realtime notification channel: $channelName for role: $role");
    } catch (e) {
      debugPrint("Error starting realtime notification listener: $e");
    }
  }

  /// Stops and unsubscribes the current Realtime listener channel
  Future<void> stopListener() async {
    if (_realtimeChannel != null) {
      await Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }
}
