import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'order_item_model.dart';

class OrderModel {
  final int id;
  final String userId;
  final String customerName;
  final String phone;
  final String address;
  final String? note;
  final DateTime? pickupTime;
  final String status;
  final double totalPrice;
  final DateTime? createdAt;
  final List<OrderItemModel> items;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.customerName,
    required this.phone,
    required this.address,
    this.note,
    this.pickupTime,
    required this.status,
    required this.totalPrice,
    this.createdAt,
    this.items = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['order_items'];
    List<OrderItemModel> itemsList = [];
    if (rawItems is List) {
      itemsList = rawItems
          .whereType<Map<String, dynamic>>()
          .map((item) => OrderItemModel.fromJson(item))
          .toList();
    }

    return OrderModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: json['user_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      note: json['note']?.toString(),
      pickupTime: json['pickup_time'] != null
          ? DateTime.tryParse(json['pickup_time'].toString())?.toLocal()
          : null,
      status: json['status']?.toString() ?? 'pending',
      totalPrice:
          double.tryParse(json['total_price']?.toString() ?? '') ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : null,
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'customer_name': customerName,
      'phone': phone,
      'address': address,
      'note': note,
      'pickup_time': pickupTime?.toUtc().toIso8601String(),
      'status': status,
      'total_price': totalPrice,
    };
  }

  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'processing':
        return 'Đang xử lý';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFED8B00);
      case 'confirmed':
        return primaryBlue;
      case 'processing':
        return const Color(0xFF7952B3);
      case 'completed':
        return const Color(0xFF16845B);
      case 'cancelled':
        return const Color(0xFFD64545);
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'processing':
        return Icons.local_laundry_service_outlined;
      case 'completed':
        return Icons.task_alt;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Chưa có thông tin';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String get formattedCreatedAt => _formatDateTime(createdAt);

  String get formattedPickupTime => _formatDateTime(pickupTime);

  String get formattedTotalPrice {
    return '${totalPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    )} đ';
  }

  bool get isPending => status == 'pending';
  bool get isActive => ['pending', 'confirmed', 'processing'].contains(status);
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
}
