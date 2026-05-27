import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart' as app;
import '../../../shared/models/enums.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Register with phone + OTP
  Future<void> registerWithPhone(String phone) async {
    try {
      await _client.auth.signInWithOtp(phone: phone);
    } on AuthException catch (e) {
      throw app.AuthException(e.message);
    } catch (e) {
      throw app.AuthException('Failed to send OTP: $e');
    }
  }

  /// Verify OTP
  Future<AuthResponse> verifyOtp(String phone, String token) async {
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      return response;
    } on AuthException catch (e) {
      throw app.AuthException(e.message);
    } catch (e) {
      throw app.AuthException('Invalid OTP: $e');
    }
  }

  /// Create user profile in the users table
  Future<void> createUserProfile({
    required String name,
    required String phone,
    required UserRole role,
    String? email,
  }) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw app.AuthException('Not authenticated');

      await _client.from('users').upsert({
        'id': userId,
        'name': name,
        'phone': phone,
        'email': email,
        'role': role.name,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw app.ServerException('Failed to create profile: $e');
    }
  }

  /// Get user role from the users table
  Future<UserRole?> getUserRole() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserRole.values.byName(response['role']);
    } catch (e) {
      return null;
    }
  }

  /// Check if user profile exists
  Future<bool> userProfileExists() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return false;

      final response = await _client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
