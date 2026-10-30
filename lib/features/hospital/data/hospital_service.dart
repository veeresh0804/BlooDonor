import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/blood_request.dart';
import '../../../shared/models/hospital_profile.dart';
import '../../../shared/models/parse_utils.dart';

class HospitalService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get all leads for a request
  Future<List<Map<String, dynamic>>> getLeads(String requestId) async {
    try {
      final response = await _client
          .from('leads')
          .select()
          .eq('request_id', requestId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw ServerException('Failed to get leads: $e');
    }
  }

  /// Confirm a donation is complete via RPC
  Future<void> confirmDonation({
    required String requestId,
    required String donorId,
    required DonationType donationType,
    required int units,
  }) async {
    try {
      await _client.rpc(
        'confirm_donation_complete',
        params: {
          'p_request_id': requestId,
          'p_donor_id': donorId,
          'p_donation_type': donationType.name,
          'p_units_donated': units,
        },
      );
    } catch (e) {
      throw ServerException('Failed to confirm donation: $e');
    }
  }

  /// Create or update hospital profile
  Future<void> saveHospitalProfile({
    required String userId,
    required String hospitalName,
    required String address,
    required double lat,
    required double lng,
  }) async {
    try {
      // Requires a UNIQUE(user_id) constraint (migration 009/011). `verified`
      // is intentionally omitted: new rows get the column default (false) and
      // edits no longer un-verify an already-verified hospital.
      await _client.from('hospitals').upsert(
        {
          'user_id': userId,
          'hospital_name': hospitalName,
          'address': address,
          'city': 'Hyderabad',
          'lat': lat,
          'lng': lng,
        },
        onConflict: 'user_id',
      );
    } catch (e) {
      throw ServerException('Failed to save hospital profile: $e');
    }
  }

  /// Get hospital profile for current user
  Future<HospitalProfile?> getHospitalProfile(String userId) async {
    try {
      final response = await _client
          .from('hospitals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return HospitalProfile.fromJson(response);
    } catch (e) {
      throw ServerException('Failed to get hospital profile: $e');
    }
  }

  /// Create a blood request
  Future<BloodRequest> createBloodRequest({
    required String hospitalId,
    required BloodGroup bloodGroup,
    required RhFactor rhFactor,
    required int units,
    required Urgency urgency,
    String? patientStory,
    String? description,
    double? lat,
    double? lng,
  }) async {
    try {
      final response = await _client
          .from('blood_requests')
          .insert({
            'hospital_id': hospitalId,
            'blood_group': bloodGroup.name,
            'rh_factor': rhFactor.name,
            'units': units,
            'urgency': urgency.name,
            'status': 'active',
            'city': 'Hyderabad',
            'lat': lat,
            'lng': lng,
            'patient_story': patientStory,
            'description': description,
            'current_radius_km': 10,
            'donors_notified': 0,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return BloodRequest.fromJson(response);
    } catch (e) {
      throw ServerException('Failed to create blood request: $e');
    }
  }

  /// Get all requests for a hospital
  Future<List<BloodRequest>> getHospitalRequests(String hospitalId) async {
    try {
      final response = await _client
          .from('blood_requests')
          .select()
          .eq('hospital_id', hospitalId)
          .order('created_at', ascending: false);

      return parseRows(
        response as List,
        BloodRequest.fromJson,
        label: 'blood request',
      );
    } catch (e) {
      throw ServerException('Failed to get requests: $e');
    }
  }

  /// Cancel a blood request
  Future<void> cancelRequest(String requestId, String reason) async {
    try {
      await _client
          .from('blood_requests')
          .update({
            'status': 'cancelled',
            'cancel_reason': reason,
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
    } catch (e) {
      throw ServerException('Failed to cancel request: $e');
    }
  }

  /// Mark request as fulfilled
  Future<void> fulfillRequest(String requestId) async {
    try {
      await _client
          .from('blood_requests')
          .update({
            'status': 'fulfilled',
            'fulfilled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
    } catch (e) {
      throw ServerException('Failed to fulfill request: $e');
    }
  }
}
