import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../core/api_client.dart';
import '../../../core/router.dart';
import '../../auth/services/auth_service.dart';

const _channelId = 'nexus_arena_high';
const _channelName = 'NEXUS ARENA Alerts';

final _localNotifications = FlutterLocalNotificationsPlugin();

/// Initialise the local notifications plugin and the FCM handlers.
/// Must be called after [Firebase.initializeApp] and after [runApp].
Future<void> initializeNotifications() async {
  // ── 1. Local notifications setup ────────────────────────────────────────
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await _localNotifications.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: _onLocalNotificationTap,
  );

  // Create the high-importance Android channel (no-op on iOS).
  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Match alerts, results, and wallet updates',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('default'),
      ));

  // ── 2. FCM permission ────────────────────────────────────────────────────
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // On iOS, also allow foreground display.
  await FirebaseMessaging.instance
      .setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // ── 3. Token registration ────────────────────────────────────────────────
  await registerToken();
  FirebaseMessaging.instance.onTokenRefresh.listen(_registerTokenString);

  // ── 4. FCM handlers ──────────────────────────────────────────────────────

  // Foreground: show a local notification.
  FirebaseMessaging.onMessage.listen(_onForegroundMessage);

  // Background → tapped: navigate.
  FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);

  // Terminated → tapped: navigate.
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) _navigateFromMessage(initial);
}

/// Public — call after successful login so the token is registered immediately.
Future<void> registerToken() async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) await _registerTokenString(token);
}

Future<void> _registerTokenString(String token) async {
  try {
    final jwt = await AuthService.getToken();
    if (jwt == null) return;
    final platform = Platform.isAndroid ? 'android' : 'ios';
    await ApiClient(accessToken: jwt).post(
      '/register-device-token',
      {'token': token, 'platform': platform},
      isFunction: true,
    );
  } catch (_) {
    // Fire-and-forget: token will be registered on next app open.
  }
}

void _onForegroundMessage(RemoteMessage message) {
  final n = message.notification;
  if (n == null) return;
  _localNotifications.show(
    message.hashCode,
    n.title,
    n.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

void _onLocalNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null) return;
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    _navigateFromData(data);
  } catch (_) {}
}

void _navigateFromMessage(RemoteMessage message) =>
    _navigateFromData(message.data);

/// 6 notification types → screen routes (from plan spec).
void _navigateFromData(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  if (type == null) return;
  switch (type) {
    case 'ROOM_OPEN':
    case 'MATCH_REMINDER':
      final matchId = data['match_id'] as String?;
      if (matchId != null) router.push('/match-lobby/$matchId');
    case 'MATCH_CANCELLED':
      router.push('/wallet');
    case 'WIN_ANNOUNCEMENT':
      router.push('/results');
    case 'KYC_APPROVED':
      router.push('/profile');
    case 'WITHDRAWAL_DONE':
      router.push('/wallet');
  }
}
