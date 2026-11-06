import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'account_storage.dart';
import '../models/notification_model.dart';

class NotificationService {
  static List<NotificationModel> _decode(String? raw) {
    if (raw == null) return _initialNotifications();
    return (jsonDecode(raw) as List)
        .whereType<Map<String, dynamic>>()
        .map(NotificationModel.fromJson)
        .toList();
  }

  static Future<List<NotificationModel>> getNotifications() async {
    final storage = AccountStorage.current;
    if (storage == null) return [];
    try {
      await storage.updateString(
        'notifications',
        (raw) =>
            raw ??
            jsonEncode(
              _initialNotifications().map((item) => item.toJson()).toList(),
            ),
      );
      return _decode(await storage.readString('notifications'));
    } catch (error) {
      debugPrint('Notification read failed: $error');
      return [];
    }
  }

  static Future<void> _update(
    List<NotificationModel> Function(List<NotificationModel>) update,
  ) async {
    final storage = AccountStorage.current;
    if (storage == null) return;
    try {
      await storage.updateString('notifications', (raw) {
        final updated = update(_decode(raw));
        return jsonEncode(updated.map((item) => item.toJson()).toList());
      });
    } catch (error) {
      debugPrint('Notification update failed: $error');
    }
  }

  static Future<void> addNotification(NotificationModel notification) {
    return _update((list) {
      list.removeWhere((item) => item.id == notification.id);
      list.insert(0, notification);
      return list.take(50).toList();
    });
  }

  static Future<void> markAsRead(String id) {
    return _update(
      (list) => list
          .map((item) => item.id == id ? item.copyWith(isRead: true) : item)
          .toList(),
    );
  }

  static Future<void> markAllAsRead() {
    return _update(
      (list) => list.map((item) => item.copyWith(isRead: true)).toList(),
    );
  }

  static Future<void> clearAll() => _update((_) => []);

  /// Đếm số thông báo chưa đọc
  static Future<int> getUnreadCount() async {
    try {
      final list = await getNotifications();
      return list.where((n) => !n.isRead).length;
    } catch (_) {
      return 0;
    }
  }

  /// Tạo thông báo cập nhật trạng thái đơn hàng
  static Future<void> notifyOrderStatusChange(
    int orderId,
    String newStatus,
  ) async {
    String title = 'Cập nhật đơn hàng #$orderId';
    String message = 'Đơn hàng của bạn có tiến trình mới.';

    switch (newStatus.toLowerCase()) {
      case 'pending':
        title = 'Đơn hàng #$orderId đã tạo thành công';
        message = 'Cửa hàng đã ghi nhận đơn và đang chuẩn bị tiếp nhận.';
        break;
      case 'confirmed':
        title = 'Đơn hàng #$orderId đã được xác nhận';
        message = 'Nhân viên WashCare đang chuẩn bị lấy đồ theo lịch hẹn.';
        break;
      case 'washing':
        title = 'Đơn hàng #$orderId đang giặt sấy';
        message = 'Trang phục của bạn đang được giặt tiệt trùng và sấy thơm.';
        break;
      case 'delivering':
        title = 'Đơn hàng #$orderId đang giao đến bạn';
        message = 'Đồ giặt đã sẵn sàng và đang được giao đến địa chỉ của bạn.';
        break;
      case 'completed':
        title = 'Đơn hàng #$orderId đã hoàn tất!';
        message = 'Đơn hàng đã được giao đến bạn. Hãy chia sẻ cảm nhận và đánh giá nhé!';
        break;
      case 'cancelled':
        title = 'Đơn hàng #$orderId đã hủy';
        message = 'Đơn hàng đã được hủy theo yêu cầu.';
        break;
    }

    final notif = NotificationModel(
      id: 'ord_${orderId}_${newStatus}_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: 'order_update',
      orderId: orderId,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await addNotification(notif);
  }

  static List<NotificationModel> _initialNotifications() {
    final now = DateTime.now();
    return [
      NotificationModel(
        id: 'seed_welcome',
        title: 'Chào mừng bạn đến với WashCare! 🧺',
        message: 'Dịch vụ giặt sấy tận nơi tiện lợi, giao nhận nhanh chóng và thơm ngát.',
        type: 'system',
        createdAt: now.subtract(const Duration(minutes: 5)),
        isRead: false,
      ),
      NotificationModel(
        id: 'seed_promo',
        title: 'Ưu đãi bạn mới: Giảm 20.000đ 🎁',
        message: 'Nhập mã WASHCARE20 khi đặt đơn để nhận ưu đãi cho đơn giặt đầu tiên!',
        type: 'promo',
        createdAt: now.subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      NotificationModel(
        id: 'seed_tip',
        title: 'Mẹo giữ quần áo bền màu & thơm lâu 💡',
        message: 'WashCare sử dụng tinh dầu xả hương tự nhiên giúp trang phục giữ mùi thơm suốt ngày dài.',
        type: 'system',
        createdAt: now.subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];
  }
}
