import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/review_model.dart';
import 'account_storage.dart';
import 'request_timeout.dart';
import 'supabase_client.dart';

class ReviewService {
  static Map<int, ReviewModel> _decode(String? raw) {
    if (raw == null) return {};
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final reviews = <int, ReviewModel>{};
    for (final value in json.values.whereType<Map>()) {
      final review = ReviewModel.fromJson(Map<String, dynamic>.from(value));
      reviews[review.orderId] = review;
    }
    return reviews;
  }

  static Future<Map<int, ReviewModel>> _readCache(
    AccountStorage storage,
  ) async {
    try {
      return _decode(await storage.readString('order_reviews'));
    } catch (error) {
      debugPrint('Review cache read failed: $error');
      return {};
    }
  }

  static String _encode(Map<int, ReviewModel> reviews) => jsonEncode({
    for (final entry in reviews.entries)
      entry.key.toString(): entry.value.toJson(),
  });

  static Future<ReviewModel?> getReviewForOrder(int orderId) async {
    final storage = AccountStorage.current;
    if (storage == null) return null;
    final reviews = await _readCache(storage);
    if (!storage.isCurrent) return null;
    try {
      final row = await supabase
          .from('reviews')
          .select()
          .eq('order_id', orderId)
          .maybeSingle()
          .timeout(supabaseRequestTimeout);
      if (!storage.isCurrent) return null;
      final review = row == null ? null : ReviewModel.fromJson(row);
      await storage.updateString('order_reviews', (raw) {
        final cache = _decode(raw);
        if (review == null) {
          cache.remove(orderId);
        } else {
          cache[orderId] = review;
        }
        return _encode(cache);
      });
      return review;
    } catch (error) {
      debugPrint('Review fetch failed: $error');
      return storage.isCurrent ? reviews[orderId] : null;
    }
  }

  static Future<bool> saveReview(ReviewModel review) async {
    final storage = AccountStorage.current;
    if (storage == null || storage.userId != review.userId) return false;
    try {
      await supabase
          .from('reviews')
          .upsert(review.toJson(), onConflict: 'order_id')
          .timeout(supabaseRequestTimeout);
    } catch (error) {
      debugPrint('Review save failed: $error');
      return false;
    }
    if (!storage.isCurrent) return false;
    try {
      await storage.updateString('order_reviews', (raw) {
        final cache = _decode(raw);
        cache[review.orderId] = review;
        return _encode(cache);
      });
    } catch (error) {
      debugPrint('Review cache write failed: $error');
    }
    return true;
  }

  static Future<Map<int, ReviewModel>> getAllReviews() async {
    final storage = AccountStorage.current;
    if (storage == null) return {};
    final cached = await _readCache(storage);
    if (!storage.isCurrent) return {};
    try {
      final rows = await supabase
          .from('reviews')
          .select()
          .timeout(supabaseRequestTimeout);
      if (!storage.isCurrent) return {};
      final reviews = {
        for (final row in rows)
          (row['order_id'] as num).toInt(): ReviewModel.fromJson(row),
      };
      try {
        await storage.writeString('order_reviews', _encode(reviews));
      } catch (error) {
        debugPrint('Review cache write failed: $error');
      }
      return reviews;
    } catch (error) {
      debugPrint('Review list failed: $error');
      return storage.isCurrent ? cached : {};
    }
  }

  static Future<double> getAverageRating() async {
    final reviews = await getAllReviews();
    if (reviews.isEmpty) return 0;
    return reviews.values.fold<int>(0, (sum, review) => sum + review.rating) /
        reviews.length;
  }

  static Future<int> getReviewCount() async => (await getAllReviews()).length;
}
