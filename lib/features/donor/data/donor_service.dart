import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/donor_profile.dart';

class DonorService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Create or update donor profile
  Future<void> saveDonorProfile({
    required String userId,
    required BloodGroup bloodGroup,
    required RhFactor rhFactor,
    required double lat,
    required double lng,
    int radiusKm = 10,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    try {
      await _client.from('donor_profiles').upsert(
        {
          'user_id': userId,
          'blood_group': bloodGroup.name,
          'rh_factor': rhFactor.name,
          'city': 'Hyderabad',
          'lat': lat,
          'lng': lng,
          'radius_km': radiusKm,
          'availability': true,
          'dnd_mode': false,
          'cooldown_active': false,
          'emergency_contact_name': emergencyContactName,
          'emergency_contact_phone': emergencyContactPhone,
          // NOTE: never write 'points' here — donor_profiles.points is a
          // cached copy synced from donor_achievements by the database
          // (see 009_security_hardening.sql). Sending 0 reset it on save.
        },
        onConflict: 'user_id', // requires UNIQUE(user_id), added in 009
      );
    } catch (e) {
      throw ServerException('Failed to save donor profile: $e');
    }
  }

  /// Get donor profile for current user
  Future<DonorProfile?> getDonorProfile(String userId) async {
    try {
      final response = await _client
          .from('donor_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return DonorProfile.fromJson(response);
    } catch (e) {
      throw ServerException('Failed to get donor profile: $e');
    }
  }

  /// Toggle availability
  Future<void> toggleAvailability(String profileId, bool available) async {
    try {
      await _client
          .from('donor_profiles')
          .update({'availability': available})
          .eq('id', profileId);
    } catch (e) {
      throw ServerException('Failed to update availability: $e');
    }
  }

  /// Toggle DND mode
  Future<void> toggleDndMode(String profileId, bool dnd) async {
    try {
      await _client
          .from('donor_profiles')
          .update({'dnd_mode': dnd})
          .eq('id', profileId);
    } catch (e) {
      throw ServerException('Failed to update DND mode: $e');
    }
  }

  /// Update location
  Future<void> updateLocation(String profileId, double lat, double lng) async {
    try {
      await _client
          .from('donor_profiles')
          .update({'lat': lat, 'lng': lng})
          .eq('id', profileId);
    } catch (e) {
      throw ServerException('Failed to update location: $e');
    }
  }

  /// Update radius preference
  Future<void> updateRadius(String profileId, int radiusKm) async {
    try {
      await _client
          .from('donor_profiles')
          .update({'radius_km': radiusKm})
          .eq('id', profileId);
    } catch (e) {
      throw ServerException('Failed to update radius: $e');
    }
  }
}
