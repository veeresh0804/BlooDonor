import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';

class DonorAchievementsService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get donor achievements
  Future<Map<String, dynamic>?> getAchievements(String donorId) async {
    try {
      final response = await _client
          .from('donor_achievements')
          .select()
          .eq('donor_id', donorId)
          .maybeSingle();
      return response;
    } catch (e) {
      throw ServerException('Failed to get achievements: $e');
    }
  }

  /// Get donation history for a donor
  Future<List<Map<String, dynamic>>> getDonationHistory(
      String donorId) async {
    try {
      final response = await _client
          .from('donor_responses')
          .select('*, blood_requests(*)')
          .eq('donor_id', donorId)
          .eq('status', 'donated')
          .order('accepted_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw ServerException('Failed to get donation history: $e');
    }
  }

  /// Get donation certificates for a donor
  Future<List<Map<String, dynamic>>> getCertificates(String donorId) async {
    try {
      final response = await _client
          .from('donation_certificates')
          .select()
          .eq('donor_id', donorId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw ServerException('Failed to get certificates: $e');
    }
  }

  /// Get donor ratings
  Future<List<Map<String, dynamic>>> getRatings(String donorId) async {
    try {
      final response = await _client
          .from('donor_ratings')
          .select()
          .eq('donor_id', donorId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw ServerException('Failed to get ratings: $e');
    }
  }

  /// Get today's heroes (donors who donated today) — city-wide
  Future<List<Map<String, dynamic>>> getTodaysHeroes() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final response = await _client
          .from('donor_responses')
          .select('donor_id, accepted_at, blood_requests(blood_group, rh_factor)')
          .eq('status', 'donated')
          .gte('accepted_at', startOfDay.toIso8601String())
          .order('accepted_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Silently return empty on failure
      return [];
    }
  }
}
