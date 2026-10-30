import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/models/blood_request.dart';

/// Donor matching and fan-out notification are done server-side by the
/// `handle_new_blood_request` database trigger. The client only needs to load
/// a request when a push notification is tapped.
class MatchingService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get a single blood request by ID
  Future<BloodRequest?> getBloodRequestById(String requestId) async {
    try {
      final response = await _client
          .from('blood_requests')
          .select()
          .eq('id', requestId)
          .maybeSingle();

      if (response == null) return null;
      return BloodRequest.fromJson(response);
    } catch (e) {
      throw ServerException('Failed to get blood request: $e');
    }
  }
}
