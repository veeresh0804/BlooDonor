import 'package:flutter/material.dart';
import '../../../shared/models/donor_profile.dart';
import '../../../shared/models/enums.dart';
import '../data/donor_journey_service.dart';

class DonorJourneyProvider extends ChangeNotifier {
  final DonorJourneyService _service = DonorJourneyService();

  DonorResponseStatus _currentStatus = DonorResponseStatus.accepted;
  bool _isLoading = false;
  String? _error;

  DonorResponseStatus get currentStatus => _currentStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Submit a lead for an unregistered donor
  Future<bool> submitLead({
    required String requestId,
    required String referredByDonorId,
    required String name,
    required String phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.submitLead(
        requestId: requestId,
        referredByDonorId: referredByDonorId,
        name: name,
        phone: phone,
      );
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

  /// Notify family via SMS
  Future<void> notifyFamily({
    required DonorProfile donor,
    required String hospitalName,
  }) async {
    final contactPhone = donor.emergencyContactPhone;
    if (contactPhone == null) return;

    final message =
        "${donor.emergencyContactName} is going to donate blood at $hospitalName. Proud of me!";

    try {
      await _service.sendSms(to: contactPhone, body: message);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Accept a request after passing health check
  Future<bool> acceptRequest({
    required String requestId,
    required String donorId,
    bool isCooldownOverride = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.updateResponseStatus(
        requestId: requestId,
        donorId: donorId,
        status: DonorResponseStatus.accepted,
        healthCheckPassed: true,
        isCooldownOverride: isCooldownOverride,
      );
      _currentStatus = DonorResponseStatus.accepted;
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

  /// Cancel acceptance within the time window
  Future<bool> cancelAcceptance({
    required String requestId,
    required String donorId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.stepBack(requestId: requestId, donorId: donorId);
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

  /// Update journey status
  Future<void> updateStatus({
    required String requestId,
    required String donorId,
    required DonorResponseStatus status,
  }) async {
    _currentStatus = status;
    notifyListeners();
    try {
      await _service.updateResponseStatus(
        requestId: requestId,
        donorId: donorId,
        status: status,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
