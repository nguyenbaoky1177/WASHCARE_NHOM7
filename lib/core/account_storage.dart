import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_client.dart';

class AccountStorage {
  AccountStorage(this.userId);

  final String userId;
  static final Map<String, Future<void>> _writes = {};

  static AccountStorage? get current {
    final user = supabase.auth.currentUser;
    return user == null ? null : AccountStorage(user.id);
  }

  bool get isCurrent => supabase.auth.currentUser?.id == userId;

  String _key(String name) => 'washcare_${name}_v2_$userId';

  Future<String?> readString(String name) async {
    final key = _key(name);
    await _writes[key];
    return (await SharedPreferences.getInstance()).getString(key);
  }

  Future<void> writeString(String name, String value) {
    return updateString(name, (_) => value);
  }

  Future<void> updateString(
    String name,
    String Function(String?) update,
  ) async {
    final key = _key(name);
    final previous = _writes[key] ?? Future<void>.value();
    final operation = previous.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, update(prefs.getString(key)));
    });
    final barrier = operation.catchError((Object _) {});
    _writes[key] = barrier;
    try {
      await operation;
    } finally {
      if (identical(_writes[key], barrier)) _writes.remove(key);
    }
  }
}
