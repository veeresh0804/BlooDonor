import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/models/enums.dart';

class DonorJourneyService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Submit a lead for an unregistered donor
  Future<void> submitLead({
    required String requestId,
    required String referredByDonorId,
    required String name,
    required String phone,
  }) async {
    try {
      await _client.from('leads').insert({
        'request_id': requestId,
        'referred_by_donor_id': referredByDonorId,
        'referred_name': name,
        'referred_phone': phone,
        'status': 'pending',
      });
    } catch (e) {
      throw ServerException('Failed to submit lead: $e');
    }
  }

  /// Send SMS via Edge Function
  Future<void> sendSms({required String to, required String body}) async {
    try {
      await _client.functions.invoke(
        'send-sms',
        body: {'to': to, 'body': body},
      );
    } catch (e) {
      throw ServerException('Failed to send SMS: $e');
    }
  }

  /// Update the status of a donor response
  Future<void> updateResponseStatus({
    required String requestId,
    required String donorId,
    required DonorResponseStatus status,
    bool healthCheckPassed = false,
    bool isCooldownOverride = false,
  }) async {
    try {
      // Update the donor response record
      await _client
          .from('donor_responses')
          .update({
            'status': status.name,
            'health_check_passed': healthCheckPassed,
            'is_cooldown_override': isCooldownOverride,
            'accepted_at': status == DonorResponseStatus.accepted
                ? DateTime.now().toIso8601String()
                : null,
            'arrived_at': status == DonorResponseStatus.arrived
                ? DateTime.now().toIso8601String()
                : null,
          })
          .eq('request_id', requestId)
          .eq('donor_id', donorId);
    } catch (e) {
      throw ServerException('Failed to update donor response: $e');
    }
  }

  /// Let donor step back (cancel)
  Future<void> stepBack({
    required String requestId,
    required String donorId,
  }) async {
    try {
      await _client
          .from('donor_responses')
          .update({'status': DonorResponseStatus.stepped_back.name})
          .eq('request_id', requestId)
          .eq('donor_id', donorId);
    } catch (e) {
      throw ServerException('Failed to step back from request: $e');
    }
  }
}
