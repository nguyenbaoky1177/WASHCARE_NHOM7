import 'dart:convert';

import 'account_storage.dart';
import '../models/address_model.dart';

class AddressService {
  static const _storageKey = 'saved_addresses_v1';

  static Future<List<AddressModel>> getAddresses() async {
    final storage = AccountStorage.current;
    if (storage == null) return [];
    final raw = await storage.readString(_storageKey);
    if (raw != null && raw.isNotEmpty) return _decode(raw);
    final legacy = await storage.readString('saved_address');
    if (legacy == null || legacy.trim().isEmpty) return [];
    return _change(storage, (_) {});
  }

  static Future<void> saveAddress(AddressModel address) async {
    final storage = AccountStorage.current;
    if (storage == null) return;
    await _change(storage, (addresses) {
      final index = addresses.indexWhere((item) => item.id == address.id);
      final useAsDefault =
          address.isDefault || (index >= 0 && addresses[index].isDefault);
      if (useAsDefault) _setDefault(addresses, address.id);
      final updated = address.copyWith(isDefault: useAsDefault);
      if (index >= 0) {
        addresses[index] = updated;
      } else {
        addresses.add(updated);
      }
    });
  }

  static Future<void> deleteAddress(String id) async {
    final storage = AccountStorage.current;
    if (storage == null) return;
    await _change(storage, (addresses) {
      addresses.removeWhere((address) => address.id == id);
    });
  }

  static Future<void> setDefaultAddress(String id) async {
    final storage = AccountStorage.current;
    if (storage == null) return;
    await _change(storage, (addresses) {
      if (addresses.any((address) => address.id == id)) {
        _setDefault(addresses, id);
      }
    });
  }

  static Future<AddressModel?> getDefaultAddress() async {
    final addresses = await getAddresses();
    if (addresses.isEmpty) return null;
    return addresses.firstWhere(
      (address) => address.isDefault,
      orElse: () => addresses.first,
    );
  }

  static Future<List<AddressModel>> _change(
    AccountStorage storage,
    void Function(List<AddressModel>) update,
  ) async {
    final legacy = (await storage.readString('saved_address'))?.trim() ?? '';
    late List<AddressModel> addresses;
    await storage.updateString(_storageKey, (raw) {
      addresses = _decode(raw);
      if ((raw == null || raw.isEmpty) && legacy.isNotEmpty) {
        addresses.add(
          AddressModel(
            id: 'legacy',
            label: 'Nhà riêng',
            recipientName: '',
            phoneNumber: '',
            fullAddress: legacy,
            isDefault: true,
          ),
        );
      }
      update(addresses);
      if (addresses.isNotEmpty && !addresses.any((item) => item.isDefault)) {
        _setDefault(addresses, addresses.first.id);
      }
      return jsonEncode(addresses.map((item) => item.toJson()).toList());
    });
    return addresses;
  }

  static List<AddressModel> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(AddressModel.fromJson)
            .toList();
      }
    } on FormatException {
      return [];
    }
    return [];
  }

  static void _setDefault(List<AddressModel> addresses, String id) {
    for (var index = 0; index < addresses.length; index++) {
      final item = addresses[index];
      addresses[index] = item.copyWith(isDefault: item.id == id);
    }
  }
}
