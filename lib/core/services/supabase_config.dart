import 'package:supabase_flutter/supabase_flutter.dart';

/// Safe accessor for Supabase client.
/// Prevents crashes when Supabase isn't initialized (demo mode).
class SupabaseConfig {
  SupabaseConfig._();

  /// Whether Supabase has been successfully initialized
  static bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns the Supabase client if initialized, null otherwise
  static SupabaseClient? get clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Returns the Supabase client — throws if not initialized
  static SupabaseClient get client => Supabase.instance.client;

  /// Whether the current user is authenticated
  static bool get isAuthenticated {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  /// Current user ID, or null
  static String? get currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }
}
