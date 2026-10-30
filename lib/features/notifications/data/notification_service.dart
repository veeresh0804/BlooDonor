import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
  debugPrint('Background message: ${message.messageId}');
}

class NotificationService {
  /// Must match SOS_TOPIC in supabase/functions/send-community-sos.
  static const String communitySosTopic = 'hyderabad_donors';

  StreamSubscription<String>? _tokenRefreshSub;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseClient _client = Supabase.instance.client;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true, // For emergency notifications
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      throw NotificationException('Notification permission denied');
    }

    // Get FCM token
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToServer(token);
    }

    // Listen for token refresh (cancel any previous listener first)
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _fcm.onTokenRefresh.listen(_saveTokenToServer);

    // Community SOS is broadcast to this topic. subscribeToTopic is not
    // supported on web; Firebase is not initialised there anyway.
    try {
      await _fcm.subscribeToTopic(communitySosTopic);
    } catch (e) {
      debugPrint('Topic subscribe failed: $e');
    }

    // Configure foreground presentation
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Save FCM token to Supabase for targeted notifications
  Future<void> _saveTokenToServer(String token) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from('users').update({'fcm_token': token}).eq('id', userId);
    } catch (e) {
      debugPrint('FCM token save failed: $e');
    }
  }

  /// Listen for foreground messages
  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  /// Listen for message tap (opens app)
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  /// Check if app was opened from a notification
  Future<RemoteMessage?> getInitialMessage() async {
    return await _fcm.getInitialMessage();
  }
}
