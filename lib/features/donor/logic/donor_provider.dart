import 'package:flutter/material.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/donor_profile.dart';
import '../data/donor_service.dart';

class DonorProvider extends ChangeNotifier {
  final DonorService _service = DonorService();

  DonorProfile? _profile;
  bool _isLoading = false;
  String? _error;

  DonorProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfile => _profile != null;
  bool get isAvailable => _profile?.availability ?? false;
  bool get isDnd => _profile?.dndMode ?? false;
  bool get isInCooldown => _profile?.cooldownActive ?? false;

  /// Load donor profile
  Future<void> loadProfile(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _profile = await _service.getDonorProfile(userId);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Save donor profile
  Future<bool> saveProfile({
    required String userId,
    required BloodGroup bloodGroup,
    required RhFactor rhFactor,
    required double lat,
    required double lng,
    int radiusKm = 10,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.saveDonorProfile(
        userId: userId,
        bloodGroup: bloodGroup,
        rhFactor: rhFactor,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
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

  /// Toggle availability
  Future<void> toggleAvailability() async {
    if (_profile == null) return;
    final newValue = !_profile!.availability;
    await _service.toggleAvailability(_profile!.id, newValue);
    _profile = DonorProfile(
      id: _profile!.id,
      userId: _profile!.userId,
      bloodGroup: _profile!.bloodGroup,
      rhFactor: _profile!.rhFactor,
      city: _profile!.city,
      lat: _profile!.lat,
      lng: _profile!.lng,
      radiusKm: _profile!.radiusKm,
      availability: newValue,
      dndMode: _profile!.dndMode,
      lastDonationDate: _profile!.lastDonationDate,
      donationTypeLast: _profile!.donationTypeLast,
      cooldownEndDate: _profile!.cooldownEndDate,
      cooldownActive: _profile!.cooldownActive,
      emergencyContactName: _profile!.emergencyContactName,
      emergencyContactPhone: _profile!.emergencyContactPhone,
      points: _profile!.points,
    );
    notifyListeners();
  }

  /// Toggle DND mode
  Future<void> toggleDndMode() async {
    if (_profile == null) return;
    final newValue = !_profile!.dndMode;
    await _service.toggleDndMode(_profile!.id, newValue);
    _profile = DonorProfile(
      id: _profile!.id,
      userId: _profile!.userId,
      bloodGroup: _profile!.bloodGroup,
      rhFactor: _profile!.rhFactor,
      city: _profile!.city,
      lat: _profile!.lat,
      lng: _profile!.lng,
      radiusKm: _profile!.radiusKm,
      availability: _profile!.availability,
      dndMode: newValue,
      lastDonationDate: _profile!.lastDonationDate,
      donationTypeLast: _profile!.donationTypeLast,
      cooldownEndDate: _profile!.cooldownEndDate,
      cooldownActive: _profile!.cooldownActive,
      emergencyContactName: _profile!.emergencyContactName,
      emergencyContactPhone: _profile!.emergencyContactPhone,
      points: _profile!.points,
    );
    notifyListeners();
  }
}
