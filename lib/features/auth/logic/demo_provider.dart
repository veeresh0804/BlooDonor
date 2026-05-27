import 'package:flutter/material.dart';
import '../../../shared/models/enums.dart';

/// Lightweight provider for tracking demo mode state.
/// When Supabase isn't configured, this tracks which role
/// the user chose so that screens can show appropriate seed data.
class DemoProvider extends ChangeNotifier {
  bool _isDemoMode = false;
  UserRole? _demoRole;

  bool get isDemoMode => _isDemoMode;
  UserRole? get demoRole => _demoRole;

  void enterDemoMode({required UserRole role}) {
    _isDemoMode = true;
    _demoRole = role;
    notifyListeners();
  }

  void exitDemoMode() {
    _isDemoMode = false;
    _demoRole = null;
    notifyListeners();
  }
}
