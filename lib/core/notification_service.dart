import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

class NotificationService {
  static const String _prefKey = 'washcare_notifications_v1';

  /// Lấy danh sách thông báo (kèm seed mẫu ban đầu nếu trống)
  static Future<List<NotificationModel>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final List list = jsonDecode(raw);
        return list
            .whereType<Map<String, dynamic>>()
            .map((item) => NotificationModel.fromJson(item))
            .toList();
      } else {
        // Khởi tạo các thông báo chào mừng & ưu đãi ban đầu
        final initial = _initialNotifications();
        await _saveNotifications(initial);
        return initial;
      }
    } catch (e) {
      debugPrint('NotificationService.getNotifications error: $e');
      return _initialNotifications();
    }
  }

  /// Thêm thông báo mới
  static Future<void> addNotification(NotificationModel notification) async {
    try {
      final list = await getNotifications();
      // Tránh trùng lặp nếu cùng id
      list.removeWhere((item) => item.id == notification.id);
      list.insert(0, notification);

      // Giới hạn tối đa 50 thông báo gần nhất
      final trimmed = list.take(50).toList();
      await _saveNotifications(trimmed);
    } catch (e) {
      debugPrint('NotificationService.addNotification error: $e');
    }
  }

  /// Đánh dấu một thông báo đã đọc
  static Future<void> markAsRead(String id) async {
    try {
      final list = await getNotifications();
      final updated = list.map((item) {
        if (item.id == id) {
          return item.copyWith(isRead: true);
        }
        return item;
      }).toList();
      await _saveNotifications(updated);
    } catch (e) {
      debugPrint('NotificationService.markAsRead error: $e');
    }
  }

  /// Đánh dấu tất cả thông báo đã đọc
  static Future<void> markAllAsRead() async {
    try {
      final list = await getNotifications();
      final updated = list.map((item) => item.copyWith(isRead: true)).toList();
      await _saveNotifications(updated);
    } catch (e) {
      debugPrint('NotificationService.markAllAsRead error: $e');
    }
  }

  /// Xóa toàn bộ thông báo
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (e) {
      debugPrint('NotificationService.clearAll error: $e');
    }
  }

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
  static Future<void> notifyOrderStatusChange(int orderId, String newStatus) async {
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
      case 'processing':
        title = 'Đơn hàng #$orderId đang giặt sấy';
        message = 'Trang phục của bạn đang được giặt tiệt trùng và sấy thơm.';
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

  static Future<void> _saveNotifications(List<NotificationModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_prefKey, jsonString);
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
