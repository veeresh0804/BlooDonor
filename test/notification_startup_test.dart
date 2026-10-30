import 'package:bloodonor/features/notifications/logic/notification_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing Firebase is reported without throwing during startup', () async {
    final provider = NotificationProvider();
    addTearDown(provider.dispose);
    await provider.initialize();
    expect(provider.isInitialized, isFalse);
    expect(provider.error, isNotNull);
    final error = provider.error;
    await provider.initialize();
    expect(provider.error, error);
  });
}
