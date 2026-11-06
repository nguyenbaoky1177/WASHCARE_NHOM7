import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washcare/core/account_storage.dart';
import 'package:washcare/core/profile_cache.dart';
import 'package:washcare/core/review_service.dart';
import 'package:washcare/core/service_cache.dart';
import 'package:washcare/models/models.dart';

import 'test_supabase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var serviceRows = <Map<String, dynamic>>[];
  var failServices = false;
  var failReviews = false;

  setUpAll(() async {
    await initializeTestSupabase(
      handler: (request) async {
        if (request.url.path.endsWith('/services')) {
          if (failServices) throw Exception('offline');
          return http.Response(jsonEncode(serviceRows), 200);
        }
        if (request.url.path.endsWith('/reviews')) {
          if (failReviews) throw Exception('offline');
          return http.Response('[]', 200);
        }
        return http.Response('{}', 200);
      },
    );
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    failReviews = false;
    await signInTestUser('customer-a');
  });

  test('network errors never produce a fabricated service catalog', () async {
    failServices = true;
    await expectLater(
      ServiceCache.getServices(forceNetwork: true),
      throwsException,
    );
    failServices = false;
  });

  test(
    'an empty server catalog replaces old active services in cache',
    () async {
      serviceRows = [
        {
          'id': 1,
          'name': 'Real service',
          'price': 80000,
          'unit': 'kg',
          'is_active': true,
        },
      ];
      expect(
        (await ServiceCache.getServices(forceNetwork: true)).single.price,
        80000,
      );
      serviceRows = [];
      expect(await ServiceCache.getServices(forceNetwork: true), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('washcare_services_cache_v2'), '[]');
    },
  );

  test(
    'addresses remain account-scoped during sign-in changes and late writes',
    () async {
      final first = AccountStorage.current!;
      await first.writeString('saved_address', 'Address A');
      await signInTestUser('customer-b');
      final second = AccountStorage.current!;
      expect(await second.readString('saved_address'), isNull);
      await first.writeString('saved_address', 'Late address A');
      expect(await second.readString('saved_address'), isNull);
      await second.writeString('saved_address', 'Address B');
      await signInTestUser('customer-a');
      expect(
        await AccountStorage.current!.readString('saved_address'),
        'Late address A',
      );
    },
  );

  test(
    'review fallback never exposes another account or legacy shared cache',
    () async {
      failReviews = true;
      final review = ReviewModel(
        orderId: 42,
        userId: 'customer-a',
        rating: 5,
        comment: 'Private A',
        createdAt: DateTime.now(),
      );
      final raw = jsonEncode({'42': review.toJson()});
      await AccountStorage.current!.writeString('order_reviews', raw);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('washcare_order_reviews_v1', raw);
      expect((await ReviewService.getAllReviews())[42]?.comment, 'Private A');
      await signInTestUser('customer-b');
      expect(await ReviewService.getAllReviews(), isEmpty);
      failReviews = false;
    },
  );

  test(
    'successful empty review response removes obsolete cached records',
    () async {
      final review = ReviewModel(
        orderId: 1,
        userId: 'customer-a',
        rating: 5,
        comment: 'Old',
        createdAt: DateTime.now(),
      );
      await AccountStorage.current!.writeString(
        'order_reviews',
        jsonEncode({'1': review.toJson()}),
      );
      expect(await ReviewService.getAllReviews(), isEmpty);
      failReviews = true;
      expect(await ReviewService.getAllReviews(), isEmpty);
      failReviews = false;
    },
  );

  test('profile cache uses the profile owner ID', () async {
    const profile = ProfileModel(id: 'customer-a', fullName: 'Customer A');
    await ProfileCache.updateCache(profile);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('washcare_profile_cache_v1_customer-a'), isTrue);
  });
}
