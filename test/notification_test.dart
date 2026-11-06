import 'test_supabase.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:washcare/core/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washcare/core/app_colors.dart';
import 'package:washcare/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeTestSupabase());
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await signInTestUser('customer-a');
  });

  test(
    'notifications are isolated and concurrent writes are preserved',
    () async {
      await NotificationService.clearAll();
      await Future.wait(
        List.generate(
          10,
          (index) => NotificationService.addNotification(
            NotificationModel(
              id: 'private-$index',
              title: 'A',
              message: 'A',
              type: 'system',
              createdAt: DateTime.now(),
            ),
          ),
        ),
      );
      expect((await NotificationService.getNotifications()).length, 10);
      await signInTestUser('customer-b');
      expect(
        (await NotificationService.getNotifications()).where(
          (item) => item.id.startsWith('private-'),
        ),
        isEmpty,
      );
      await signInTestUser('customer-a');
      expect((await NotificationService.getNotifications()).length, 10);
    },
  );

  test('Cleared notifications stay empty after reloading', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await NotificationService.getNotifications(), isNotEmpty);
    await NotificationService.clearAll();
    expect(await NotificationService.getNotifications(), isEmpty);
    expect(await NotificationService.getUnreadCount(), 0);
  });

  group('NotificationModel Tests', () {
    test('fromJson and toJson roundtrip', () {
      final json = {
        'id': 'notif-101',
        'title': 'Đơn hàng #15 đã tiếp nhận',
        'message': 'Nhân viên đang chuẩn bị lấy đồ.',
        'type': 'order_update',
        'order_id': 15,
        'created_at': '2026-10-20T12:00:00.000Z',
        'is_read': false,
      };

      final notif = NotificationModel.fromJson(json);

      expect(notif.id, 'notif-101');
      expect(notif.title, 'Đơn hàng #15 đã tiếp nhận');
      expect(notif.message, 'Nhân viên đang chuẩn bị lấy đồ.');
      expect(notif.type, 'order_update');
      expect(notif.orderId, 15);
      expect(notif.isRead, false);
      expect(notif.iconData, Icons.local_laundry_service_outlined);
      expect(notif.typeColor, primaryBlue);

      final map = notif.toJson();
      expect(map['id'], 'notif-101');
      expect(map['order_id'], 15);
      expect(map['is_read'], false);
    });

    test('copyWith updates isRead and fields', () {
      final notif = NotificationModel(
        id: 'test_1',
        title: 'Title',
        message: 'Msg',
        type: 'promo',
        createdAt: DateTime.now(),
        isRead: false,
      );

      final updated = notif.copyWith(isRead: true, title: 'New Title');

      expect(updated.id, 'test_1');
      expect(updated.isRead, true);
      expect(updated.title, 'New Title');
      expect(updated.typeColor, Colors.deepOrange);
      expect(updated.iconData, Icons.card_giftcard_rounded);
    });

    test('formattedTime handles recent, hours and days', () {
      final now = DateTime.now();

      final justNow = NotificationModel(
        id: '1',
        title: '',
        message: '',
        type: 'system',
        createdAt: now.subtract(const Duration(seconds: 10)),
      );
      expect(justNow.formattedTime, 'Vừa xong');

      final minutesAgo = NotificationModel(
        id: '2',
        title: '',
        message: '',
        type: 'system',
        createdAt: now.subtract(const Duration(minutes: 25)),
      );
      expect(minutesAgo.formattedTime, '25 phút trước');

      final hoursAgo = NotificationModel(
        id: '3',
        title: '',
        message: '',
        type: 'system',
        createdAt: now.subtract(const Duration(hours: 3)),
      );
      expect(hoursAgo.formattedTime, '3 giờ trước');
    });
  });
}
