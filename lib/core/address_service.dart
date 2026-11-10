import 'dart:convert';

import 'account_storage.dart';
import '../models/address_model.dart';

class AddressService {
  static const String _storageKey = 'saved_addresses_v1';

  static Future<List<AddressModel>> getAddresses() async {
    final storage = AccountStorage.current;
    if (storage == null) return [];

    final rawJson = await storage.readString(_storageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      // Fallback: nếu chưa có danh sách, kiểm tra xem có saved_address dạng text cũ không
      final oldSaved = await storage.readString('saved_address');
      if (oldSaved != null && oldSaved.trim().isNotEmpty) {
        final initial = AddressModel(
          id: 'initial_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Nhà riêng',
          recipientName: '',
          phoneNumber: '',
          fullAddress: oldSaved.trim(),
          isDefault: true,
        );
        await saveAddress(initial);
        return [initial];
      }
      return [];
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => AddressModel.fromJson(item))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  static Future<void> saveAddress(AddressModel address) async {
    final storage = AccountStorage.current;
    if (storage == null) return;

    final currentList = await getAddresses();
    final index = currentList.indexWhere((a) => a.id == address.id);

    List<AddressModel> updatedList = List.from(currentList);

    // Nếu đây là địa chỉ mặc định, bỏ cờ isDefault của các địa chỉ khác
    if (address.isDefault || updatedList.isEmpty) {
      updatedList = updatedList
          .map((a) => a.copyWith(isDefault: a.id == address.id))
          .toList();
      address = address.copyWith(isDefault: true);
    }

    if (index >= 0) {
      updatedList[index] = address;
    } else {
      updatedList.add(address);
    }

    await _persist(storage, updatedList);

    // Giữ tương thích với saved_address chuỗi cũ
    if (address.isDefault) {
      await storage.writeString('saved_address', address.fullAddress);
    }
  }

  static Future<void> deleteAddress(String id) async {
    final storage = AccountStorage.current;
    if (storage == null) return;

    final currentList = await getAddresses();
    final itemToDelete = currentList.firstWhere(
      (a) => a.id == id,
      orElse: () => const AddressModel(
        id: '',
        label: '',
        recipientName: '',
        phoneNumber: '',
        fullAddress: '',
      ),
    );

    final updatedList = currentList.where((a) => a.id != id).toList();

    // Nếu xóa mất địa chỉ mặc định và còn địa chỉ khác, chọn địa chỉ đầu tiên làm mặc định
    if (itemToDelete.isDefault && updatedList.isNotEmpty) {
      updatedList[0] = updatedList[0].copyWith(isDefault: true);
      await storage.writeString('saved_address', updatedList[0].fullAddress);
    } else if (updatedList.isEmpty) {
      await storage.writeString('saved_address', '');
    }

    await _persist(storage, updatedList);
  }

  static Future<void> setDefaultAddress(String id) async {
    final storage = AccountStorage.current;
    if (storage == null) return;

    final currentList = await getAddresses();
    String newDefaultAddress = '';

    final updatedList = currentList.map((a) {
      final isDef = a.id == id;
      if (isDef) newDefaultAddress = a.fullAddress;
      return a.copyWith(isDefault: isDef);
    }).toList();

    await _persist(storage, updatedList);
    if (newDefaultAddress.isNotEmpty) {
      await storage.writeString('saved_address', newDefaultAddress);
    }
  }

  static Future<AddressModel?> getDefaultAddress() async {
    final addresses = await getAddresses();
    if (addresses.isEmpty) return null;
    return addresses.firstWhere(
      (a) => a.isDefault,
      orElse: () => addresses.first,
    );
  }

  static Future<void> _persist(
    AccountStorage storage,
    List<AddressModel> list,
  ) async {
    final encoded = jsonEncode(list.map((a) => a.toJson()).toList());
    await storage.writeString(_storageKey, encoded);
  }
}
