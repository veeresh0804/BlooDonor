import '../../shared/models/blood_request.dart';
import '../../shared/models/donor_profile.dart';
import '../../shared/models/enums.dart';

/// Mock data for demo mode. Contains Hyderabad-based hospitals
/// and diverse donor profiles for testing the full UI.
class SeedData {
  SeedData._();

  // ─── Hyderabad Hospitals ────────────────────────────────────────
  static const hospitals = [
    {
      'id': 'hosp-001',
      'hospital_name': 'KIMS Hospital, Secunderabad',
      'address': 'Minister Road, Secunderabad 500003',
      'city': 'Hyderabad',
      'lat': 17.4399,
      'lng': 78.4983,
      'verified': true,
    },
    {
      'id': 'hosp-002',
      'hospital_name': 'Apollo Hospitals, Jubilee Hills',
      'address': 'Jubilee Hills, Hyderabad 500033',
      'city': 'Hyderabad',
      'lat': 17.4326,
      'lng': 78.4071,
      'verified': true,
    },
    {
      'id': 'hosp-003',
      'hospital_name': 'Yashoda Hospitals, Somajiguda',
      'address': 'Raj Bhavan Road, Somajiguda 500082',
      'city': 'Hyderabad',
      'lat': 17.4239,
      'lng': 78.4738,
      'verified': true,
    },
    {
      'id': 'hosp-004',
      'hospital_name': 'Care Hospitals, Banjara Hills',
      'address': 'Road No 1, Banjara Hills 500034',
      'city': 'Hyderabad',
      'lat': 17.4116,
      'lng': 78.4410,
      'verified': true,
    },
  ];

  // ─── Mock Donors ────────────────────────────────────────
  static List<DonorProfile> get donors => [
        DonorProfile(
          id: 'donor-001',
          userId: 'user-001',
          bloodGroup: BloodGroup.o,
          rhFactor: RhFactor.positive,
          city: 'Hyderabad',
          lat: 17.4400,
          lng: 78.4950,
          radiusKm: 10,
          availability: true,
          dndMode: false,
          points: 150,
          emergencyContactName: 'Suresh Kumar',
          emergencyContactPhone: '+919876543210',
        ),
        DonorProfile(
          id: 'donor-002',
          userId: 'user-002',
          bloodGroup: BloodGroup.a,
          rhFactor: RhFactor.positive,
          city: 'Hyderabad',
          lat: 17.4350,
          lng: 78.4080,
          radiusKm: 15,
          availability: true,
          dndMode: false,
          points: 280,
          lastDonationDate: DateTime.now().subtract(const Duration(days: 120)),
        ),
        DonorProfile(
          id: 'donor-003',
          userId: 'user-003',
          bloodGroup: BloodGroup.b,
          rhFactor: RhFactor.negative,
          city: 'Hyderabad',
          lat: 17.4100,
          lng: 78.4430,
          radiusKm: 10,
          availability: true,
          dndMode: false,
          points: 50,
        ),
        DonorProfile(
          id: 'donor-004',
          userId: 'user-004',
          bloodGroup: BloodGroup.ab,
          rhFactor: RhFactor.positive,
          city: 'Hyderabad',
          lat: 17.4200,
          lng: 78.4700,
          radiusKm: 20,
          availability: false,
          dndMode: true,
          cooldownActive: true,
          cooldownEndDate: DateTime.now().add(const Duration(days: 45)),
          lastDonationDate: DateTime.now().subtract(const Duration(days: 45)),
          donationTypeLast: DonationType.whole_blood,
          points: 420,
          emergencyContactName: 'Priya Reddy',
          emergencyContactPhone: '+919876543211',
        ),
        DonorProfile(
          id: 'donor-005',
          userId: 'user-005',
          bloodGroup: BloodGroup.o,
          rhFactor: RhFactor.negative,
          city: 'Hyderabad',
          lat: 17.3850,
          lng: 78.4867,
          radiusKm: 10,
          availability: true,
          dndMode: false,
          points: 80,
        ),
      ];

  // ─── Active Blood Requests ────────────────────────────────────────
  static List<BloodRequest> get activeRequests => [
        BloodRequest(
          id: 'req-001',
          hospitalId: 'hosp-001',
          bloodGroup: BloodGroup.o,
          rhFactor: RhFactor.positive,
          units: 2,
          urgency: Urgency.critical,
          status: RequestStatus.active,
          city: 'Hyderabad',
          lat: 17.4399,
          lng: 78.4983,
          patientStory:
              'A 6-year-old girl named Ananya is fighting thalassemia. She needs regular blood transfusions to survive. Today, her hemoglobin dropped dangerously low.',
          description: 'Pediatric ward — Thalassemia patient',
          currentRadiusKm: 10,
          donorsNotified: 12,
          createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        ),
        BloodRequest(
          id: 'req-002',
          hospitalId: 'hosp-002',
          bloodGroup: BloodGroup.ab,
          rhFactor: RhFactor.negative,
          units: 1,
          urgency: Urgency.urgent,
          status: RequestStatus.active,
          city: 'Hyderabad',
          lat: 17.4326,
          lng: 78.4071,
          patientStory:
              'A young mother, Meera (28), is undergoing an emergency C-section. She has AB- blood, which is extremely rare. Every minute matters.',
          description: 'Emergency C-section — rare blood type',
          currentRadiusKm: 20,
          donorsNotified: 3,
          createdAt: DateTime.now().subtract(const Duration(minutes: 42)),
        ),
        BloodRequest(
          id: 'req-003',
          hospitalId: 'hosp-003',
          bloodGroup: BloodGroup.b,
          rhFactor: RhFactor.positive,
          units: 3,
          urgency: Urgency.normal,
          status: RequestStatus.active,
          city: 'Hyderabad',
          lat: 17.4239,
          lng: 78.4738,
          patientStory:
              'Scheduled surgery for an elderly gentleman tomorrow morning. Building blood reserve.',
          description: 'Pre-surgery blood reserve',
          currentRadiusKm: 10,
          donorsNotified: 8,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];

  // ─── Completed Requests (for history) ────────────────────────────
  static List<BloodRequest> get fulfilledRequests => [
        BloodRequest(
          id: 'req-past-001',
          hospitalId: 'hosp-001',
          bloodGroup: BloodGroup.a,
          rhFactor: RhFactor.positive,
          units: 1,
          urgency: Urgency.critical,
          status: RequestStatus.fulfilled,
          city: 'Hyderabad',
          lat: 17.4399,
          lng: 78.4983,
          patientStory: 'Road accident victim, 32M',
          currentRadiusKm: 10,
          donorsNotified: 5,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        BloodRequest(
          id: 'req-past-002',
          hospitalId: 'hosp-004',
          bloodGroup: BloodGroup.o,
          rhFactor: RhFactor.positive,
          units: 2,
          urgency: Urgency.urgent,
          status: RequestStatus.fulfilled,
          city: 'Hyderabad',
          lat: 17.4116,
          lng: 78.4410,
          patientStory: 'Dengue patient with low platelet count',
          currentRadiusKm: 15,
          donorsNotified: 10,
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
      ];

  /// Hospital name lookup
  static String hospitalName(String hospitalId) {
    final hospital = hospitals.firstWhere(
      (h) => h['id'] == hospitalId,
      orElse: () => {'hospital_name': 'Unknown Hospital'},
    );
    return hospital['hospital_name'] as String;
  }

  /// Get a demo donor profile (for donor demo mode)
  static DonorProfile get demoDonor => donors.first;

  /// Get all requests (active + fulfilled) for hospital demo
  static List<BloodRequest> get allRequests =>
      [...activeRequests, ...fulfilledRequests];
}
