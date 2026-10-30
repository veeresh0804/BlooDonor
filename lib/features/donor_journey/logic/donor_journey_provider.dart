import 'package:flutter/material.dart';
import '../../../shared/models/enums.dart';
import '../data/donor_journey_service.dart';

class DonorJourneyProvider extends ChangeNotifier {
  DonorJourneyProvider({DonorJourneyService? service})
    : _service = service ?? DonorJourneyService();

  final DonorJourneyService _service;

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
  Future<bool> updateStatus({
    required String requestId,
    required String donorId,
    required DonorResponseStatus status,
  }) async {
    if (_isLoading) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.updateResponseStatus(
        requestId: requestId,
        donorId: donorId,
        status: status,
      );
      _currentStatus = status;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
