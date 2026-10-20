import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service_model.dart';
import 'supabase_client.dart';

class ServiceCache {
  static const String _prefKey = 'washcare_services_cache_v1';
  static List<ServiceModel>? _memoryCache;

  /// Lấy danh sách dịch vụ với cơ chế Cache-First (0ms), tải nền và cập nhật
  static Future<List<ServiceModel>> getServices({bool forceNetwork = false}) async {
    // 1. Nếu đã có trong memory cache và không bắt buộc tải mạng, trả về ngay 0ms
    if (_memoryCache != null && _memoryCache!.isNotEmpty && !forceNetwork) {
      _fetchAndUpdateFromNetwork(); // background refresh
      return _memoryCache!;
    }

    // 2. Kiểm tra SharedPreferences cache
    if (!forceNetwork) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_prefKey);
        if (raw != null) {
          final List list = jsonDecode(raw);
          final cached = list
              .whereType<Map<String, dynamic>>()
              .map((e) => ServiceModel.fromJson(e))
              .toList();
          if (cached.isNotEmpty) {
            _memoryCache = cached;
            _fetchAndUpdateFromNetwork(); // background refresh
            return cached;
          }
        }
      } catch (e) {
        debugPrint('ServiceCache read error: $e');
      }
    }

    // 3. Nếu chưa có cache, tải từ Supabase với timeout ngắn 4s
    try {
      final services = await _fetchFromSupabase();
      if (services.isNotEmpty) {
        _memoryCache = services;
        _saveToCache(services);
        return services;
      }
    } catch (e) {
      debugPrint('ServiceCache Supabase error: $e');
    }

    // 4. Nếu lỗi mạng hoặc timeout và chưa có gì, trả về dịch vụ mặc định tiêu chuẩn để app không bao giờ bị trắng/đơ!
    final fallback = _defaultServices();
    _memoryCache = fallback;
    return fallback;
  }

  static Future<List<ServiceModel>> _fetchFromSupabase() async {
    final response = await supabase
        .from('services')
        .select('id, name, description, price, unit, icon, is_active')
        .eq('is_active', true)
        .order('id')
        .timeout(const Duration(seconds: 4));

    return (response as List)
        .whereType<Map<String, dynamic>>()
        .map((e) => ServiceModel.fromJson(e))
        .toList();
  }

  static void _fetchAndUpdateFromNetwork() {
    _fetchFromSupabase().then((services) {
      if (services.isNotEmpty) {
        _memoryCache = services;
        _saveToCache(services);
      }
    }).catchError((e) {
      debugPrint('ServiceCache background update ignored: $e');
    });
  }

  static Future<void> _saveToCache(List<ServiceModel> services) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = services.map((s) => s.toJson()).toList();
      await prefs.setString(_prefKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  static List<ServiceModel> _defaultServices() {
    return const [
      ServiceModel(
        id: 1,
        name: 'Giặt sấy tiêu chuẩn',
        description: 'Phân loại đồ trắng/màu, giặt sạch sâu, sấy khô thơm ngát',
        price: 25000,
        unit: 'kg',
        icon: 'local_laundry_service',
        isActive: true,
      ),
      ServiceModel(
        id: 2,
        name: 'Giặt sấy nhanh (Lấy trong 2h)',
        description: 'Ưu tiên lồng giặt riêng, sấy cấp tốc giao ngay trong 2 giờ',
        price: 35000,
        unit: 'kg',
        icon: 'flash_on',
        isActive: true,
      ),
      ServiceModel(
        id: 3,
        name: 'Giặt sấy chăn ga gối mền',
        description: 'Lồng giặt lớn tải trọng cao, tiệt trùng sạch sâu vi khuẩn ẩm mốc',
        price: 50000,
        unit: 'chiếc',
        icon: 'bed',
        isActive: true,
      ),
      ServiceModel(
        id: 4,
        name: 'Giặt hấp Vest & Áo sơ mi cao cấp',
        description: 'Dung môi chuyên dụng giữ form dáng chuẩn tiệm',
        price: 60000,
        unit: 'bộ',
        icon: 'checkroom',
        isActive: true,
      ),
      ServiceModel(
        id: 5,
        name: 'Giặt hấp Đầm dạ hội / Váy cưới',
        description: 'Chăm sóc thủ công đính kết ren đá tinh xảo',
        price: 80000,
        unit: 'chiếc',
        icon: 'dry_cleaning',
        isActive: true,
      ),
      ServiceModel(
        id: 6,
        name: 'Vệ sinh & Khử khuẩn giày hiệu',
        description: 'Vệ sinh thân giày, tẩy ố đế và sấy tia UV diệt khuẩn',
        price: 45000,
        unit: 'đôi',
        icon: 'sports_gymnastics',
        isActive: true,
      ),
    ];
  }
}
