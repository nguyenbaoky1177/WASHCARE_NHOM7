import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washcare/core/app_colors.dart';
import 'package:washcare/models/models.dart';

void main() {
  group('ProfileModel Tests', () {
    test('fromJson & roleDisplayName test', () {
      final json = {
        'id': 'usr-123',
        'full_name': 'Nguyễn Văn A',
        'phone': '0901234567',
        'role': 'admin',
        'created_at': '2026-10-15T12:00:00Z',
      };

      final profile = ProfileModel.fromJson(json);

      expect(profile.id, 'usr-123');
      expect(profile.fullName, 'Nguyễn Văn A');
      expect(profile.phone, '0901234567');
      expect(profile.roleDisplayName, 'Quản trị viên');
      expect(profile.formattedCreatedAt, isNotEmpty);
    });

    test('roleDisplayName default fallback', () {
      const profile = ProfileModel(id: '1', fullName: 'Test', role: 'customer');
      expect(profile.roleDisplayName, 'Khách hàng');
    });
  });

  group('ServiceModel Tests', () {
    test('fromJson and formattedPrice', () {
      final json = {
        'id': 1,
        'name': 'Giặt sấy tiêu chuẩn',
        'description': 'Giặt sạch sấy khô thơm tho',
        'price': 25000,
        'unit': 'kg',
        'icon': 'local_laundry_service',
        'is_active': true,
      };

      final service = ServiceModel.fromJson(json);

      expect(service.id, 1);
      expect(service.name, 'Giặt sấy tiêu chuẩn');
      expect(service.formattedPrice, '25.000');
      expect(service.iconData, Icons.local_laundry_service);
    });
  });

  group('OrderItemModel Tests', () {
    test('fromJson with joined services', () {
      final json = {
        'id': 10,
        'order_id': 100,
        'service_id': 1,
        'quantity': 3.5,
        'subtotal': 87500,
        'services': {
          'name': 'Giặt sấy',
          'unit': 'kg',
        },
      };

      final item = OrderItemModel.fromJson(json);

      expect(item.serviceName, 'Giặt sấy');
      expect(item.serviceUnit, 'kg');
      expect(item.formattedQuantity, '3.5');
      expect(item.formattedSubtotal, '87.500 đ');
    });
  });

  group('OrderModel Tests', () {
    test('fromJson and status helpers', () {
      final json = {
        'id': 55,
        'user_id': 'user-1',
        'customer_name': 'Trần Thị B',
        'phone': '0987654321',
        'address': '123 Lê Lợi, Q1',
        'note': 'Giao trước 5h chiều',
        'pickup_time': '2026-10-17T09:00:00Z',
        'status': 'pending',
        'total_price': 150000,
        'created_at': '2026-10-16T08:00:00Z',
        'order_items': [
          {
            'id': 1,
            'quantity': 2,
            'subtotal': 150000,
            'services': {'name': 'Giặt hấp', 'unit': 'chiếc'},
          }
        ],
      };

      final order = OrderModel.fromJson(json);

      expect(order.id, 55);
      expect(order.isPending, isTrue);
      expect(order.isActive, isTrue);
      expect(order.isCompleted, isFalse);
      expect(order.statusDisplayName, 'Chờ xác nhận');
      expect(order.formattedTotalPrice, '150.000 đ');
      expect(order.items.length, 1);
      expect(order.items.first.serviceName, 'Giặt hấp');
    });

    test('status colors match app design', () {
      const orderPending = OrderModel(
        id: 1,
        userId: 'u',
        customerName: 'C',
        phone: 'P',
        address: 'A',
        status: 'pending',
        totalPrice: 0,
      );
      const orderConfirmed = OrderModel(
        id: 2,
        userId: 'u',
        customerName: 'C',
        phone: 'P',
        address: 'A',
        status: 'confirmed',
        totalPrice: 0,
      );

      expect(orderPending.statusColor, const Color(0xFFED8B00));
      expect(orderConfirmed.statusColor, primaryBlue);
    });
  });
}
