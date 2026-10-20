import 'package:flutter/material.dart';

class ReviewModel {
  final int? id;
  final int orderId;
  final String userId;
  final int rating; // 1 to 5 stars
  final String comment;
  final List<String> tags;
  final DateTime createdAt;

  const ReviewModel({
    this.id,
    required this.orderId,
    required this.userId,
    required this.rating,
    required this.comment,
    this.tags = const [],
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];
    if (json['tags'] is List) {
      parsedTags = (json['tags'] as List).map((e) => e.toString()).toList();
    } else if (json['tags'] is String && (json['tags'] as String).isNotEmpty) {
      parsedTags = (json['tags'] as String).split(',').map((e) => e.trim()).toList();
    }

    return ReviewModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      orderId: json['order_id'] is int
          ? json['order_id'] as int
          : int.tryParse(json['order_id']?.toString() ?? '') ?? 0,
      userId: json['user_id']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      comment: json['comment']?.toString() ?? '',
      tags: parsedTags,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'user_id': userId,
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  String get formattedDate {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(createdAt.day)}/${two(createdAt.month)}/${createdAt.year}';
  }

  String get ratingLabel {
    switch (rating) {
      case 5:
        return 'Tuyệt vời';
      case 4:
        return 'Hài lòng';
      case 3:
        return 'Bình thường';
      case 2:
        return 'Chưa hài lòng';
      case 1:
        return 'Rất tệ';
      default:
        return 'Đánh giá $rating★';
    }
  }

  Color get ratingColor {
    if (rating >= 4) return Colors.amber[700]!;
    if (rating == 3) return Colors.orange;
    return Colors.red;
  }
}
