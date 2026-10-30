import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import '../../../core/services/navigation_service.dart';
import '../../donor/presentation/emergency_card_screen.dart';
import '../../donor/presentation/cooldown_override_screen.dart';
import '../../matching/logic/matching_provider.dart';
import '../data/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  // Construct inside initialize's try/catch when Firebase may be unavailable.
  late final NotificationService _service = NotificationService();

  RemoteMessage? _lastMessage;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _attempted = false;
  String? _error;

  RemoteMessage? get lastMessage => _lastMessage;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  /// Initialize notification system
  Future<void> initialize() async {
    // Idempotent: AuthGate may call this on every rebuild.
    if (_isInitialized || _isInitializing || _attempted) return;
    _isInitializing = true;
    _attempted = true; // one attempt per app session; avoids re-prompt loops
    try {
      await _service.initialize();
      _isInitialized = true;

      // Listen for foreground messages
      _service.onForegroundMessage.listen((message) {
        _lastMessage = message;
        notifyListeners();
        _handleMessage(message, isBackground: false);
      });

      // Listen for message tap
      _service.onMessageOpenedApp.listen((message) {
        _lastMessage = message;
        notifyListeners();
        _handleMessage(message, isBackground: true);
      });

      // Check if app opened from notification
      final initialMessage = await _service.getInitialMessage();
      if (initialMessage != null) {
        _lastMessage = initialMessage;
        notifyListeners();
        _handleMessage(initialMessage, isBackground: true);
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isInitializing = false;
    }
  }

  void _handleMessage(
    RemoteMessage message, {
    bool isBackground = false,
  }) async {
    final data = message.data;
    final type = data['type'];

    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case 'emergency_request':
        final requestId = data['request_id'];
        final hospitalName = data['hospital_name'];
        final distanceKm = int.tryParse(data['distance_km'] ?? '0') ?? 0;

        if (requestId == null) return;

        final request = await context
            .read<MatchingProvider>()
            .getBloodRequestById(requestId);

        if (request != null) {
          NavigationService.navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => EmergencyCardScreen(
                request: request,
                hospitalName: hospitalName,
                distanceKm: distanceKm,
              ),
              fullscreenDialog: true,
            ),
          );
        }
        break;

      case 'cooldown_override_request':
        final requestId = data['request_id'];
        final hospitalName = data['hospital_name'];
        final cooldownDays =
            int.tryParse(data['cooldown_days_remaining'] ?? '0') ?? 0;

        if (requestId == null) return;

        final request = await context
            .read<MatchingProvider>()
            .getBloodRequestById(requestId);

        if (request != null) {
          NavigationService.navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => CooldownOverrideScreen(
                request: request,
                hospitalName: hospitalName,
                distanceKm: 0,
                cooldownDaysRemaining: cooldownDays,
              ),
              fullscreenDialog: true,
            ),
          );
        }
        break;

      case 'emergency_resolved':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An emergency was resolved. Thank you!'),
            backgroundColor: Colors.green,
          ),
        );
        break;
      case 'cooldown_ended':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are now eligible to donate again!'),
            backgroundColor: Colors.blue,
          ),
        );
        break;
      case 'thank_you':
        // TODO: Navigate to a thank you screen or show a special dialog
        break;
    }
  }

  void clearLastMessage() {
    _lastMessage = null;
    notifyListeners();
  }
}
