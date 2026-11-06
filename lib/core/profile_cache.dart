import 'request_timeout.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_model.dart';
import 'supabase_client.dart';

class ProfileCache {
  static const String _prefKey = 'washcare_profile_cache_v1';
  static ProfileModel? _memoryProfile;

  /// Lấy thông tin tài khoản hiện tại: Đọc từ cache ngay lập tức (0ms)
  static Future<ProfileModel?> getProfile({bool forceNetwork = false}) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _memoryProfile = null;
      return null;
    }

    // 1. Kiểm tra memory cache
    if (_memoryProfile != null && _memoryProfile!.id == user.id && !forceNetwork) {
      _fetchAndUpdateInBackground(user.id);
      return _memoryProfile;
    }

    // 2. Kiểm tra SharedPreferences cache
    if (!forceNetwork) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('${_prefKey}_${user.id}');
        if (raw != null) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final profile = ProfileModel.fromJson(decoded);
          if (profile.id != user.id || supabase.auth.currentUser?.id != user.id) return null;
          _memoryProfile = profile;
          _fetchAndUpdateInBackground(user.id);
          return profile;
        }
      } catch (_) {}
    }

    // 3. Tải từ Supabase với timeout 4s
    return await _fetchFromSupabase(user.id);
  }

  static Future<ProfileModel?> _fetchFromSupabase(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('id, full_name, phone, role, created_at')
          .eq('id', userId)
          .maybeSingle()
          .timeout(supabaseRequestTimeout);

      if (response != null) {
        final profile = ProfileModel.fromJson(response);
        if (supabase.auth.currentUser?.id != userId) return null;
        _memoryProfile = profile;
        _saveToCache(profile);
        return profile;
      }
    } catch (e) {
      debugPrint('ProfileCache fetch error: $e');
    }
    return _memoryProfile?.id == userId ? _memoryProfile : null;
  }

  static void _fetchAndUpdateInBackground(String userId) {
    _fetchFromSupabase(userId)
        .then((profile) {
          if (profile != null && supabase.auth.currentUser?.id == userId) {
            _memoryProfile = profile;
          }
        })
        .catchError((_) {});
  }

  static Future<void> updateCache(ProfileModel profile) async {
    _memoryProfile = profile;
    await _saveToCache(profile);
  }

  static Future<void> clear() async {
    _memoryProfile = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = supabase.auth.currentUser;
      if (user != null) {
        await prefs.remove('${_prefKey}_${user.id}');
      }
    } catch (_) {}
  }

  static Future<void> _saveToCache(ProfileModel profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_prefKey}_${profile.id}',
        jsonEncode(profile.toJson()),
      );
    } catch (_) {}
  }
}
