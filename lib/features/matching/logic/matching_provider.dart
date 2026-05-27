import 'package:flutter/material.dart';
import '../../../shared/models/blood_request.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/donor_profile.dart';
import '../data/matching_service.dart';

class MatchingProvider extends ChangeNotifier {
  final MatchingService _service = MatchingService();

  List<DonorProfile> _matchedDonors = [];
  bool _isLoading = false;
  String? _error;

  List<DonorProfile> get matchedDonors => _matchedDonors;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get a single blood request by its ID
  Future<BloodRequest?> getBloodRequestById(String requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = await _service.getBloodRequestById(requestId);
      _isLoading = false;
      notifyListeners();
      return request;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Find compatible donors for a request
  Future<void> findDonors({
    required BloodGroup bloodGroup,
    required RhFactor rhFactor,
    required double hospitalLat,
    required double hospitalLng,
    int radiusKm = 10,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _matchedDonors = await _service.findCompatibleDonors(
        bloodGroup: bloodGroup,
        rhFactor: rhFactor,
        hospitalLat: hospitalLat,
        hospitalLng: hospitalLng,
        radiusKm: radiusKm,
      );
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Notify matched donors
  Future<int> notifyDonors({
    required String requestId,
    required List<String> donorIds,
  }) async {
    try {
      final count = await _service.notifyDonors(
        requestId: requestId,
        donorIds: donorIds,
      );
      return count;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }

  void clear() {
    _matchedDonors = [];
    _error = null;
    notifyListeners();
  }
}
