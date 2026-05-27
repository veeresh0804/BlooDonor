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

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_saveTokenToServer);

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
      // Silent fail — token will be refreshed
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

  /// Send emergency notification via Supabase Edge Function
  Future<void> sendEmergencyNotification({
    required String requestId,
    required String donorId,
    required String bloodGroup,
    required String hospitalName,
    required String patientStory,
    required int distanceKm,
  }) async {
    try {
      await _client.functions.invoke(
        'send-emergency-notification',
        body: {
          'request_id': requestId,
          'donor_id': donorId,
          'blood_group': bloodGroup,
          'hospital_name': hospitalName,
          'patient_story': patientStory,
          'distance_km': distanceKm,
        },
      );
    } catch (e) {
      throw NotificationException('Failed to send notification: $e');
    }
  }

  /// Send resolved notification to all notified donors
  Future<void> sendResolvedNotification({
    required String requestId,
    required List<String> donorIds,
  }) async {
    try {
      await _client.functions.invoke(
        'send-resolved-notification',
        body: {'request_id': requestId, 'donor_ids': donorIds},
      );
    } catch (e) {
      throw NotificationException('Failed to send resolved notification: $e');
    }
  }
}
