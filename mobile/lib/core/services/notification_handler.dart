// lib/core/services/notification_handler.dart
//
// Handles tap-to-route for both push systems in use:
//   - Mobile (Android/iOS): OneSignal → handleData(Map)
//   - Web: FCM → handleMessage(RemoteMessage)
//
// Both funnel into the same private _route() so the switch/case logic
// only lives in one place.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';

class NotificationHandler {
  NotificationHandler._();

  /// Mobile (OneSignal) — [data] is the notification's additionalData map,
  /// e.g. { "type": "announcement" } or { "type": "payment", "paymentId": "..." }
  static void handleData(Map<String, dynamic> data, GoRouter router) {
    _route(
      type: data['type'] as String? ?? '',
      paymentId: data['paymentId'] as String?,
      router: router,
    );
  }

  /// Web (FCM) — kept for the web build, which still uses
  /// firebase_messaging directly.
  static void handleMessage(RemoteMessage message, GoRouter router) {
    _route(
      type: message.data['type'] as String? ?? '',
      paymentId: message.data['paymentId'] as String?,
      router: router,
    );
  }

  // ── Shared routing logic ────────────────────────────────────────────────
  static void _route({
    required String type,
    required String? paymentId,
    required GoRouter router,
  }) {
    debugPrint('Notification tapped — type: $type');

    switch (type) {
      case 'dues':
        router.go(Routes.payments);
        break;
      case 'payment':
        if (paymentId != null && paymentId.isNotEmpty) {
          router.go('${Routes.payments}/$paymentId');
        } else {
          router.go(Routes.payments);
        }
        break;
      case 'announcement':
        router.go(Routes.announcements);
        break;
      case 'complaint':
        router.go(Routes.complaints);
        break;
      default:
        router.go(Routes.notifications);
        break;
    }
  }
}