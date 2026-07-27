// lib/core/services/fcm_service.dart

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Background handler — must be top-level, outside any class ─────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
}

// ── FCMService ────────────────────────────────────────────────────────────────

class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  final FirebaseMessaging              _messaging  = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'lamhoai_high_importance',
    'LAMHOAI-RMS Notifications',
    description: 'HOA dues reminders, announcements and complaint updates.',
    importance: Importance.high,
    playSound: true,
  );

  // ── Initialize ───────────────────────────────────────────────────────────────

  Future<void> initialize({
    required void Function(RemoteMessage message) onMessageTap,
  }) async {
    await _requestPermission();
    await _setupLocalNotifications();

    // Background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground message — show local notification
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // App in background — user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen(onMessageTap);

    // App was terminated — user taps notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) onMessageTap(initial);

    // Android foreground presentation
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ── Permission ────────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert:         true,
      badge:         true,
      sound:         true,
      announcement:  false,
      carPlay:       false,
      criticalAlert: false,
      provisional:   false,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');
  }

  // ── Local notifications ───────────────────────────────────────────────────────

  Future<void> _setupLocalNotifications() async {
    if (kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotif.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    if (Platform.isAndroid) {
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kIsWeb) return;
    final notif = message.notification;
    if (notif == null) return;

    await _localNotif.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority:   Priority.high,
          icon:       '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            notif.body ?? '',
            contentTitle: notif.title,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['type'],
    );
  }

  // ── Token management ──────────────────────────────────────────────────────────

  Future<String?> getToken({String? vapidKey}) async {
    try {
      return kIsWeb
          ? await _messaging.getToken(vapidKey: vapidKey)
          : await _messaging.getToken();
    } catch (e) {
      debugPrint('FCM getToken error: $e');
      return null;
    }
  }

  Future<void> saveTokenToFirestore(String uid, {String? vapidKey}) async {
    try {
      final token = await getToken(vapidKey: vapidKey);
      if (token == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});
      debugPrint('FCM token saved for $uid');
    } catch (e) {
      debugPrint('FCM token save error: $e');
    }
  }

  void listenToTokenRefresh(String uid) {
    _messaging.onTokenRefresh.listen((newToken) async {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'fcmToken': newToken});
        debugPrint('FCM token refreshed for $uid');
      } catch (e) {
        debugPrint('FCM token refresh error: $e');
      }
    });
  }
}