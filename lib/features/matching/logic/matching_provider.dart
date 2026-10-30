import 'package:flutter/material.dart';
import '../../../shared/models/blood_request.dart';
import '../data/matching_service.dart';

class MatchingProvider extends ChangeNotifier {
  final MatchingService _service = MatchingService();

  bool _isLoading = false;
  String? _error;

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
}
