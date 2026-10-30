import 'dart:async';

import 'package:bloodonor/features/donor_journey/data/donor_journey_service.dart';
import 'package:bloodonor/features/donor_journey/logic/donor_journey_provider.dart';
import 'package:bloodonor/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingJourneyService extends DonorJourneyService {
  Completer<void> write = Completer<void>();
  int calls = 0;

  @override
  Future<void> updateResponseStatus({
    required String requestId,
    required String donorId,
    required DonorResponseStatus status,
    bool? healthCheckPassed,
    bool? isCooldownOverride,
  }) {
    calls++;
    return write.future;
  }
}

void main() {
  test('status changes only after save; overlapping updates are ignored', () async {
    final service = PendingJourneyService();
    final provider = DonorJourneyProvider(service: service);
    addTearDown(provider.dispose);

    final pending = provider.updateStatus(
      requestId: 'request', donorId: 'donor',
      status: DonorResponseStatus.arrived,
    );
    expect(provider.currentStatus, DonorResponseStatus.accepted);
    expect(provider.isLoading, isTrue);
    expect(await provider.updateStatus(
      requestId: 'request', donorId: 'donor',
      status: DonorResponseStatus.delayed,
    ), isFalse);
    expect(service.calls, 1);

    service.write.complete();
    expect(await pending, isTrue);
    expect(provider.currentStatus, DonorResponseStatus.arrived);
    expect(provider.isLoading, isFalse);
    expect(provider.error, isNull);
  });

  test('failed save preserves status and allows a successful retry', () async {
    final service = PendingJourneyService();
    final provider = DonorJourneyProvider(service: service);
    addTearDown(provider.dispose);
    final pending = provider.updateStatus(
      requestId: 'request', donorId: 'donor',
      status: DonorResponseStatus.stepped_back,
    );
    service.write.completeError(StateError('offline'));
    expect(await pending, isFalse);
    expect(provider.currentStatus, DonorResponseStatus.accepted);
    expect(provider.isLoading, isFalse);
    expect(provider.error, contains('offline'));

    service.write = Completer<void>();
    final retry = provider.updateStatus(
      requestId: 'request', donorId: 'donor',
      status: DonorResponseStatus.stepped_back,
    );
    expect(provider.error, isNull);
    service.write.complete();
    expect(await retry, isTrue);
    expect(provider.currentStatus, DonorResponseStatus.stepped_back);
  });
}
