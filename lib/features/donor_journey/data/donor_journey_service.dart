import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/models/enums.dart';

class DonorJourneyService {
  late final SupabaseClient _client = Supabase.instance.client;

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

  /// Send SMS via Edge Function.
  /// NOTE: intentionally unwired — no UI calls this until the send-sms
  /// function stops being a mock (Twilio send is commented out there).
  /// Reconnect the journey-screen family button only after that lands.
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
    // Nullable = "don't touch". Passing false would overwrite a true value
    // set by an earlier transition (e.g. accepted -> on_the_way clearing
    // health_check_passed), so callers omit what they don't own.
    bool? healthCheckPassed,
    bool? isCooldownOverride,
  }) async {
    try {
      // Update the donor response record. Timestamps are stamped only on
      // entry into their state and flags only when explicitly passed —
      // never nulled by later transitions (that used to erase history).
      final update = <String, dynamic>{'status': status.name};
      if (healthCheckPassed != null) {
        update['health_check_passed'] = healthCheckPassed;
      }
      if (isCooldownOverride != null) {
        update['is_cooldown_override'] = isCooldownOverride;
      }
      if (status == DonorResponseStatus.accepted) {
        update['accepted_at'] = DateTime.now().toIso8601String();
      } else if (status == DonorResponseStatus.arrived) {
        update['arrived_at'] = DateTime.now().toIso8601String();
      }
      await _client
          .from('donor_responses')
          .update(update)
          .eq('request_id', requestId)
          .eq('donor_id', donorId)
          .select('id')
          .single();
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
