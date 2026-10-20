import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washcare/core/profile_cache.dart';
import 'package:washcare/core/service_cache.dart';
import 'package:washcare/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ServiceCache Tests', () {
    test('getServices returns standard catalog immediately', () async {
      final services = await ServiceCache.getServices();
      expect(services, isNotEmpty);
      expect(services.length, greaterThanOrEqualTo(5));
      expect(services.first.name, contains('Giặt sấy'));
    });
  });

  group('ProfileCache Tests', () {
    test('updateCache and memory retrieval', () async {
      const p = ProfileModel(
        id: 'user_test_999',
        fullName: 'Nguyễn Văn Test',
        phone: '0909999888',
        role: 'customer',
      );

      await ProfileCache.updateCache(p);
      // Verify cache was saved
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('washcare_profile_cache_v1_user_test_999'), isTrue);
    });
  });
}
