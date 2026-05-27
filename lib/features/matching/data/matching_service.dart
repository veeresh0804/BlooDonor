import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/donor_profile.dart';
import '../../../shared/models/blood_request.dart';

class MatchingService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Find compatible donors via the Supabase RPC function
  Future<List<DonorProfile>> findCompatibleDonors({
    required BloodGroup bloodGroup,
    required RhFactor rhFactor,
    required double hospitalLat,
    required double hospitalLng,
    int radiusKm = 10,
  }) async {
    try {
      final response = await _client.rpc(
        'find_compatible_donors',
        params: {
          'recipient_blood_group': bloodGroup.name,
          'recipient_rh_factor': rhFactor.name,
          'hospital_lat': hospitalLat,
          'hospital_lng': hospitalLng,
          'radius_km': radiusKm,
        },
      );

      return (response as List)
          .map((json) => DonorProfile.fromJson(json))
          .toList();
    } catch (e) {
      throw ServerException('Failed to find compatible donors: $e');
    }
  }

  /// Find cooldown donors (Tier 2) via the Supabase RPC function
  Future<List<DonorProfile>> findCooldownDonors({
    required BloodGroup bloodGroup,
    required RhFactor rhFactor,
    required double hospitalLat,
    required double hospitalLng,
    int radiusKm = 10,
  }) async {
    try {
      final response = await _client.rpc(
        'find_cooldown_donors',
        params: {
          'recipient_blood_group': bloodGroup.name,
          'recipient_rh_factor': rhFactor.name,
          'hospital_lat': hospitalLat,
          'hospital_lng': hospitalLng,
          'radius_km': radiusKm,
        },
      );

      return (response as List)
          .map((json) => DonorProfile.fromJson(json))
          .toList();
    } catch (e) {
      throw ServerException('Failed to find cooldown donors: $e');
    }
  }

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

  /// Notify matched donors via Edge Function
  Future<int> notifyDonors({
    required String requestId,
    required List<String> donorIds,
  }) async {
    try {
      await _client.functions.invoke(
        'send-emergency-notification',
        body: {
          'request_id': requestId,
          'donor_ids': donorIds,
        },
      );
      return donorIds.length;
    } catch (e) {
      throw ServerException('Failed to notify donors: $e');
    }
  }
}
