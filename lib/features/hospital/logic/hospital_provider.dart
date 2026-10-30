import 'package:flutter/material.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/blood_request.dart';
import '../../../shared/models/hospital_profile.dart';
import '../data/hospital_service.dart';

class HospitalProvider extends ChangeNotifier {
  final HospitalService _service = HospitalService();

  HospitalProfile? _profile;
  List<BloodRequest> _requests = [];
  bool _isLoading = false;
  String? _error;

  HospitalProfile? get profile => _profile;
  List<BloodRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfile => _profile != null;

  List<BloodRequest> get activeRequests => _requests
      .where((r) =>
          r.status == RequestStatus.active ||
          r.status == RequestStatus.escalating)
      .toList();

  List<BloodRequest> get pastRequests =>
      _requests.where((r) => r.status != RequestStatus.active).toList();

  /// Get all leads for a request
  Future<List<Map<String, dynamic>>> getLeads(String requestId) async {
    // Deliberately does NOT touch _isLoading / notifyListeners: this is a pure
    // fetch for LeadsScreen, and notifying rebuilt every watcher (and could
    // re-trigger the fetch).
    try {
      return await _service.getLeads(requestId);
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  /// Confirm a donation is complete
  Future<bool> confirmDonation({
    required String requestId,
    required String donorId,
    required DonationType donationType,
    required int units,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.confirmDonation(
        requestId: requestId,
        donorId: donorId,
        donationType: donationType,
        units: units,
      );
      final hospitalId = _profile?.id;
      if (hospitalId != null) await loadRequests(hospitalId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Load hospital profile
  Future<void> loadProfile(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _profile = await _service.getHospitalProfile(userId);
      if (_profile != null) {
        await loadRequests(_profile!.id);
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Save hospital profile
  Future<bool> saveProfile({
    required String userId,
    required String hospitalName,
    required String address,
    required double lat,
    required double lng,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.saveHospitalProfile(
        userId: userId,
        hospitalName: hospitalName,
        address: address,
        lat: lat,
        lng: lng,
      );
      await loadProfile(userId);
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Load all requests for this hospital
  Future<void> loadRequests(String hospitalId) async {
    try {
      _requests = await _service.getHospitalRequests(hospitalId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Create a new blood request
  Future<bool> createRequest({
    required BloodGroup bloodGroup,
    required RhFactor rhFactor,
    required int units,
    required Urgency urgency,
    String? patientStory,
    String? description,
  }) async {
    if (_profile == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.createBloodRequest(
        hospitalId: _profile!.id,
        bloodGroup: bloodGroup,
        rhFactor: rhFactor,
        units: units,
        urgency: urgency,
        patientStory: patientStory,
        description: description,
        lat: _profile!.lat,
        lng: _profile!.lng,
      );
      await loadRequests(_profile!.id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancel a request
  Future<void> cancelRequest(String requestId, String reason) async {
    try {
      await _service.cancelRequest(requestId, reason);
      if (_profile != null) await loadRequests(_profile!.id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Fulfill a request
  Future<void> fulfillRequest(String requestId) async {
    try {
      await _service.fulfillRequest(requestId);
      if (_profile != null) await loadRequests(_profile!.id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
