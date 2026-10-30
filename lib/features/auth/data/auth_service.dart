import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart' as app;
import '../../../shared/models/enums.dart';
import '../../../shared/models/parse_utils.dart';

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

  /// Phone of the signed-in user in +E.164 form (Supabase stores it without '+').
  String? get currentPhone {
    final raw = currentUser?.phone;
    if (raw == null || raw.isEmpty) return null;
    return raw.startsWith('+') ? raw : '+$raw';
  }

  /// Get user role from the users table.
  ///
  /// Returns null ONLY when the user has no profile row yet. Network/DB errors
  /// and unrecognised role values throw, so callers can offer a retry instead
  /// of treating a transient failure as "no profile" (which used to bounce
  /// signed-in users back to the login screen).
  Future<UserRole?> getUserRole() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      final role = tryParseEnum(UserRole.values, response['role']);
      if (role == null) {
        throw app.AuthException('Unrecognised account role');
      }
      return role;
    } on app.AuthException {
      rethrow;
    } catch (e) {
      throw app.ServerException('Failed to load your account: $e');
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
