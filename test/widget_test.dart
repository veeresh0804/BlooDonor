import 'package:flutter_test/flutter_test.dart';
import 'package:bloodonor/core/utils/phone_utils.dart';
import 'package:bloodonor/shared/models/blood_request.dart';
import 'package:bloodonor/shared/models/enums.dart';
import 'package:bloodonor/shared/models/parse_utils.dart';

Map<String, dynamic> requestRow({
  String id = 'req-1',
  String bloodGroup = 'a',
  String urgency = 'critical',
  String status = 'active',
  int? units = 2,
}) {
  return {
    'id': id,
    'hospital_id': 'hosp-1',
    'blood_group': bloodGroup,
    'rh_factor': 'positive',
    'units': units,
    'units_fulfilled': 0,
    'urgency': urgency,
    'status': status,
    'city': 'Hyderabad',
    'created_at': '2026-01-01T00:00:00.000Z',
  };
}

void main() {
  group('phone_utils (India +91 flow)', () {
    test('plain 10-digit number passes through', () {
      expect(indianNationalNumber('9876543210'), '9876543210');
    });

    test('+91 with spaces and symbols is stripped', () {
      expect(indianNationalNumber('+91 98765 43210'), '9876543210');
    });

    test('91-prefixed 12-digit input drops the country code', () {
      expect(indianNationalNumber('919876543210'), '9876543210');
    });

    test('0-prefixed 11-digit trunk input drops the zero', () {
      expect(indianNationalNumber('09876543210'), '9876543210');
    });

    test('too-short input is rejected', () {
      expect(indianNationalNumber('12345'), isNull);
      expect(indianNationalNumber(''), isNull);
    });

    test('double-prefixed input is rejected, not mangled', () {
      // "+91 91..." = 14 digits: must fail validation rather than
      // produce a wrong number (the old code prepended +91 blindly).
      expect(indianNationalNumber('+91 919876543210'), isNull);
    });

    test('normalizeIndianPhone produces E.164', () {
      expect(normalizeIndianPhone('987 654 3210'), '+919876543210');
    });

    test('validateIndianPhone accepts valid, rejects the rest', () {
      expect(validateIndianPhone('9876543210'), isNull);
      expect(validateIndianPhone(null), isNotNull);
      expect(validateIndianPhone('123'), isNotNull);
      expect(validateIndianPhone('+91 919876543210'), isNotNull);
    });
  });

  group('parse_utils', () {
    test('parseEnumOr returns the match, else the fallback', () {
      expect(
        parseEnumOr(Urgency.values, 'critical', Urgency.urgent),
        Urgency.critical,
      );
      expect(
        parseEnumOr(Urgency.values, 'bogus', Urgency.urgent),
        Urgency.urgent,
      );
      expect(parseEnumOr(Urgency.values, null, Urgency.urgent), Urgency.urgent);
    });

    test('tryParseEnum yields null for null/unknown input', () {
      expect(tryParseEnum(BloodGroup.values, 'a'), BloodGroup.a);
      expect(tryParseEnum(BloodGroup.values, 'X'), isNull);
      expect(tryParseEnum(BloodGroup.values, null), isNull);
      expect(tryParseEnum(BloodGroup.values, 42), isNull);
    });
  });

  group('BloodRequest.fromJson (lenient where safe, strict on blood type)',
      () {
    test('unknown urgency falls back to urgent', () {
      final req = BloodRequest.fromJson(requestRow(urgency: 'super-urgent'));
      expect(req.urgency, Urgency.urgent);
    });

    test('unknown status falls back to active so the row stays visible', () {
      final req = BloodRequest.fromJson(requestRow(status: 'limbo'));
      expect(req.status, RequestStatus.active);
    });

    test('null units default to 1', () {
      expect(BloodRequest.fromJson(requestRow(units: null)).units, 1);
    });

    test('unknown blood_group throws instead of guessing', () {
      // Enum.byName raises ArgumentError (not StateError) on no match.
      expect(
        () => BloodRequest.fromJson(requestRow(bloodGroup: 'X')),
        throwsArgumentError,
      );
    });

    test('parseRows skips the bad row and keeps the good ones', () {
      final rows = [
        requestRow(id: 'good-1'),
        requestRow(id: 'bad', bloodGroup: 'X'),
        requestRow(id: 'good-2'),
      ];
      final parsed = parseRows(rows, BloodRequest.fromJson, label: 'test');
      expect(parsed.map((r) => r.id), ['good-1', 'good-2']);
    });
  });
}
