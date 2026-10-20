import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type; // 'order_update', 'promo', 'system'
  final int? orderId;
  final DateTime createdAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.orderId,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'system',
      orderId: json['order_id'] is int
          ? json['order_id'] as int
          : int.tryParse(json['order_id']?.toString() ?? ''),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      isRead: json['is_read'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      if (orderId != null) 'order_id': orderId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'is_read': isRead,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    int? orderId,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      orderId: orderId ?? this.orderId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      final d = createdAt;
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
  }

  IconData get iconData {
    switch (type) {
      case 'order_update':
        return Icons.local_laundry_service_outlined;
      case 'promo':
        return Icons.card_giftcard_rounded;
      case 'system':
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color get typeColor {
    switch (type) {
      case 'order_update':
        return primaryBlue;
      case 'promo':
        return Colors.deepOrange;
      case 'system':
      default:
        return const Color(0xFF16845B);
    }
  }
}
