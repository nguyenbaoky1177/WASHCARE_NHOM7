import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initializeTestSupabase({
  Future<http.Response> Function(http.Request)? handler,
}) async {
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'https://washcare-test.supabase.co',
    publishableKey: 'test-key',
    debug: false,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: false,
      detectSessionInUri: false,
    ),
    httpClient: MockClient((request) async {
      final response =
          await (handler?.call(request) ??
              Future.value(http.Response('[]', 200)));
      return http.Response(
        response.body,
        response.statusCode,
        request: request,
        headers: {'content-type': 'application/json', ...response.headers},
      );
    }),
  );
}

Future<void> signInTestUser(String id) async {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token =
      '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'sub': id, 'exp': 4102444800})}.test';
  await Supabase.instance.client.auth.setInitialSession(
    jsonEncode({
      'access_token': token,
      'refresh_token': 'test-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': id,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': '$id@example.test',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': {},
        'user_metadata': {},
      },
    }),
  );
}
