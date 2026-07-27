// lib/core/services/notification_handler.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../routing/app_router.dart';

class NotificationHandler {
  NotificationHandler._();

  static void handleMessage(RemoteMessage message, GoRouter router) {
    final type      = message.data['type']      as String? ?? '';
    final paymentId = message.data['paymentId'] as String?;

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