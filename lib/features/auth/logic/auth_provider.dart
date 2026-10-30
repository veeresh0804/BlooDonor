import 'package:flutter/material.dart';
import '../../../shared/models/enums.dart';
import '../data/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _error;
  UserRole? _selectedRole;
  String? _phone;

  bool get isLoading => _isLoading;
  String? get error => _error;
  UserRole? get selectedRole => _selectedRole;
  bool get isAuthenticated => _authService.isAuthenticated;

  void setRole(UserRole role) {
    _selectedRole = role;
    notifyListeners();
  }

  void setPhone(String phone) {
    _phone = phone;
  }

  /// Send OTP to phone
  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _phone = phone;
      await _authService.registerWithPhone(phone);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify OTP
  Future<bool> verifyOtp(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final phone = _phone;
    if (phone == null) {
      _error = 'Please request a code first.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      await _authService.verifyOtp(phone, token);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Complete registration (create profile)
  Future<bool> completeRegistration(String name, {String? email}) async {
    if (_selectedRole == null || _phone == null) {
      _error = 'Please select a role and verify your phone';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.createUserProfile(
        name: name,
        phone: _phone!,
        role: _selectedRole!,
        email: email,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Create the profile for a user who is already signed in (OTP verified)
  /// but has no `users` row — e.g. they used Login instead of Register.
  Future<bool> completeProfileForCurrentUser({
    required String name,
    required UserRole role,
    String? email,
  }) async {
    final phone = _authService.currentPhone;
    if (phone == null) {
      _error = 'Could not read your phone number. Please sign out and sign in again.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.createUserProfile(
        name: name,
        phone: phone,
        role: role,
        email: email,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get user role for routing
  Future<UserRole?> getUserRole() async {
    return await _authService.getUserRole();
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _selectedRole = null;
    _phone = null;
    notifyListeners();
  }
}
