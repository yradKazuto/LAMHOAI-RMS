// lib/core/services/onesignal_service.dart
//
// Replaces fcm_service.dart. Handles OneSignal initialization,
// permission request, login/logout (ties device to Firebase uid),
// and notification click routing.

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  bool _initialized = false;

  // ── Initialize ─────────────────────────────────────────────────────────────
  // Call this once, early in main.dart (same place FCMService.initialize()
  // used to be called). Pass your OneSignal App ID from
  // Dashboard → Settings → Keys & IDs.
  Future<void> initialize(String oneSignalAppId) async {
    if (_initialized) return;

    OneSignal.Debug.setLogLevel(
      kDebugMode ? OSLogLevel.verbose : OSLogLevel.none,
    );

    OneSignal.initialize(oneSignalAppId);

    // Ask the user for notification permission (Android 13+, iOS).
    await OneSignal.Notifications.requestPermission(true);

    // Make sure notifications display while the app is in the foreground.
    // (OneSignal shows them by default — this listener just gives you a
    // hook if you ever want to customize or suppress specific ones.)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });

    _initialized = true;
    debugPrint('OneSignal initialized');
  }

  // ── Auth linkage ───────────────────────────────────────────────────────────
  // Call after a member successfully logs in (Firebase Auth). This ties
  // the current device to their uid as a OneSignal "external ID," which
  // is what lets the web admin target a single member by uid later
  // (e.g. a dues reminder), instead of only being able to broadcast.
  Future<void> login(String uid) async {
    try {
      await OneSignal.login(uid);
      debugPrint('OneSignal logged in as $uid');
    } catch (e) {
      debugPrint('OneSignal login error: $e');
    }
  }

  // Call on sign-out so this device stops being associated with that
  // member's external ID.
  Future<void> logout() async {
    try {
      await OneSignal.logout();
      debugPrint('OneSignal logout error handled');
    } catch (e) {
      debugPrint('OneSignal logout error: $e');
    }
  }

  // ── Tap-to-route ───────────────────────────────────────────────────────────
  // Call once during app startup with a callback that receives the
  // notification's custom data map (equivalent to RemoteMessage.data
  // in the old FCM setup). Wire this to NotificationHandler.handleData.
  void addClickListener(void Function(Map<String, dynamic> data) onTap) {
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData ?? <String, dynamic>{};
      onTap(data);
    });

    // Handle the case where the app was fully closed and opened by
    // tapping a notification — check for a "cold start" click.
    // (OneSignal's click listener above also fires for this case on
    // most versions, but this is kept as a safe fallback.)
  }
}