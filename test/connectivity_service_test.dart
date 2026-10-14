import 'package:flutter_test/flutter_test.dart';
import 'package:tap_and_dodge/services/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ConnectivityService starts with optimistic online flag', () {
    final service = ConnectivityService();
    expect(service.hasInternet.value, isTrue);
    service.dispose();
  });
}
