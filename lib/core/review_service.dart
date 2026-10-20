import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/review_model.dart';
import 'supabase_client.dart';

class ReviewService {
  static const String _prefKey = 'washcare_order_reviews_v1';

  /// Lấy đánh giá của một đơn hàng theo ID
  static Future<ReviewModel?> getReviewForOrder(int orderId) async {
    try {
      // 1. Kiểm tra cache local SharedPreferences trước
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        if (decoded.containsKey(orderId.toString())) {
          return ReviewModel.fromJson(
            Map<String, dynamic>.from(decoded[orderId.toString()] as Map),
          );
        }
      }

      // 2. Thử truy vấn bảng reviews trên Supabase với timeout ngắn 2s
      final response = await supabase
          .from('reviews')
          .select()
          .eq('order_id', orderId)
          .maybeSingle()
          .timeout(const Duration(seconds: 2));

      if (response != null) {
        final review = ReviewModel.fromJson(response);
        // Lưu ngược lại cache local
        await _saveToLocalCache(review);
        return review;
      }
    } catch (e) {
      debugPrint('ReviewService.getReviewForOrder error: $e');
    }
    return null;
  }

  /// Lưu hoặc cập nhật đánh giá
  static Future<bool> saveReview(ReviewModel review) async {
    // 1. Lưu vào cache SharedPreferences trước để luôn sẵn sàng
    await _saveToLocalCache(review);

    // 2. Thử lưu vào Supabase
    try {
      await supabase.from('reviews').upsert(
        review.toJson(),
        onConflict: 'order_id',
      );
    } catch (e) {
      debugPrint('ReviewService: Supabase reviews table upsert failed (using local cache): $e');
    }

    return true;
  }

  /// Lấy danh sách tất cả đánh giá đã lưu
  static Future<Map<int, ReviewModel>> getAllReviews() async {
    final Map<int, ReviewModel> result = {};

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        decoded.forEach((key, value) {
          final orderId = int.tryParse(key);
          if (orderId != null && value is Map) {
            result[orderId] = ReviewModel.fromJson(Map<String, dynamic>.from(value));
          }
        });
      }
    } catch (e) {
      debugPrint('ReviewService.getAllReviews cache error: $e');
    }

    try {
      final response = await supabase
          .from('reviews')
          .select()
          .timeout(const Duration(seconds: 2));
      for (final item in response) {
        final review = ReviewModel.fromJson(Map<String, dynamic>.from(item));
        result[review.orderId] = review;
      }
    } catch (_) {}

    return result;
  }

  /// Điểm đánh giá trung bình (CSAT)
  static Future<double> getAverageRating() async {
    final all = await getAllReviews();
    if (all.isEmpty) return 4.9; // Giá trị tiêu chuẩn uy tín mặc định ban đầu
    final total = all.values.fold<int>(0, (sum, r) => sum + r.rating);
    return (total / all.length);
  }

  /// Tổng số lượt đánh giá
  static Future<int> getReviewCount() async {
    final all = await getAllReviews();
    return all.length;
  }

  static Future<void> _saveToLocalCache(ReviewModel review) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      Map<String, dynamic> map = {};
      if (raw != null) {
        map = Map<String, dynamic>.from(jsonDecode(raw));
      }
      map[review.orderId.toString()] = review.toJson();
      await prefs.setString(_prefKey, jsonEncode(map));
    } catch (e) {
      debugPrint('ReviewService._saveToLocalCache error: $e');
    }
  }
}
