import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washcare/models/models.dart';

void main() {
  group('ReviewModel Tests', () {
    test('fromJson & toJson roundtrip with list tags', () {
      final json = {
        'id': 1,
        'order_id': 42,
        'user_id': 'user-123',
        'rating': 5,
        'comment': 'Dịch vụ rất tốt, quần áo thơm tho',
        'tags': ['Giặt rất sạch', 'Thơm ngát'],
        'created_at': '2026-10-20T10:00:00.000Z',
      };

      final review = ReviewModel.fromJson(json);

      expect(review.id, 1);
      expect(review.orderId, 42);
      expect(review.userId, 'user-123');
      expect(review.rating, 5);
      expect(review.comment, 'Dịch vụ rất tốt, quần áo thơm tho');
      expect(review.tags, ['Giặt rất sạch', 'Thơm ngát']);
      expect(review.ratingLabel, 'Tuyệt vời');
      expect(review.ratingColor, isA<Color>());

      final backToJson = review.toJson();
      expect(backToJson['order_id'], 42);
      expect(backToJson['rating'], 5);
      expect(backToJson['comment'], 'Dịch vụ rất tốt, quần áo thơm tho');
    });

    test('fromJson parses comma-separated string tags', () {
      final json = {
        'order_id': 99,
        'user_id': 'u1',
        'rating': 4,
        'comment': 'Hài lòng',
        'tags': 'Nhanh, Sạch, Thơm',
      };

      final review = ReviewModel.fromJson(json);
      expect(review.tags, ['Nhanh', 'Sạch', 'Thơm']);
      expect(review.ratingLabel, 'Hài lòng');
    });

    test('rating labels and colors for different star values', () {
      final now = DateTime(2026, 1, 1);
      final r5 = ReviewModel(orderId: 1, userId: 'u', rating: 5, comment: '', createdAt: now);
      final r4 = ReviewModel(orderId: 1, userId: 'u', rating: 4, comment: '', createdAt: now);
      final r3 = ReviewModel(orderId: 1, userId: 'u', rating: 3, comment: '', createdAt: now);
      final r2 = ReviewModel(orderId: 1, userId: 'u', rating: 2, comment: '', createdAt: now);
      final r1 = ReviewModel(orderId: 1, userId: 'u', rating: 1, comment: '', createdAt: now);

      expect(r5.ratingLabel, 'Tuyệt vời');
      expect(r4.ratingLabel, 'Hài lòng');
      expect(r3.ratingLabel, 'Bình thường');
      expect(r2.ratingLabel, 'Chưa hài lòng');
      expect(r1.ratingLabel, 'Rất tệ');
    });
  });
}
