import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_model.dart';
import 'request_timeout.dart';
import 'supabase_client.dart';

class ServiceCache {
  static const String _prefKey = 'washcare_services_cache_v2';
  static List<ServiceModel>? _memoryCache;
  static Future<List<ServiceModel>>? _request;

  static Future<List<ServiceModel>> getServices({
    bool forceNetwork = false,
  }) async {
    if (!forceNetwork) {
      if (_memoryCache != null) {
        _refreshInBackground();
        return _memoryCache!;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_prefKey);
        if (raw != null) {
          final list = jsonDecode(raw) as List;
          _memoryCache = list
              .whereType<Map<String, dynamic>>()
              .map(ServiceModel.fromJson)
              .toList();
          _refreshInBackground();
          return _memoryCache!;
        }
      } catch (error) {
        debugPrint('Service cache read failed: $error');
      }
    }
    return _refresh();
  }

  static Future<List<ServiceModel>> _refresh() {
    return _request ??= _fetchAndSave().whenComplete(() => _request = null);
  }

  static Future<List<ServiceModel>> _fetchAndSave() async {
    final response = await supabase
        .from('services')
        .select('id, name, description, price, unit, icon, is_active')
        .eq('is_active', true)
        .order('id')
        .timeout(supabaseRequestTimeout);
    final services = response.map(ServiceModel.fromJson).toList();
    _memoryCache = services;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        jsonEncode(services.map((service) => service.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('Service cache write failed: $error');
    }
    return services;
  }

  static void _refreshInBackground() {
    _refresh().catchError((Object error) {
      debugPrint('Service refresh failed: $error');
      return _memoryCache ?? <ServiceModel>[];
    });
  }
}
