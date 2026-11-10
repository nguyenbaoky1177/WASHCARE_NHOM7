import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washcare/core/address_service.dart';
import 'package:washcare/models/models.dart';

import 'test_supabase.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeTestSupabase();
    await signInTestUser('test-user-address');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AddressModel Tests', () {
    test('fromJson and toJson serialization', () {
      final json = {
        'id': 'addr_1',
        'label': 'Nhà riêng',
        'recipient_name': 'Nguyễn Văn A',
        'phone_number': '0901234567',
        'full_address': '123 Đường Số 1, Phường 2, Quận 3, TP.HCM',
        'is_default': true,
      };

      final address = AddressModel.fromJson(json);

      expect(address.id, 'addr_1');
      expect(address.label, 'Nhà riêng');
      expect(address.recipientName, 'Nguyễn Văn A');
      expect(address.phoneNumber, '0901234567');
      expect(address.fullAddress, '123 Đường Số 1, Phường 2, Quận 3, TP.HCM');
      expect(address.isDefault, true);

      final outJson = address.toJson();
      expect(outJson['id'], 'addr_1');
      expect(outJson['label'], 'Nhà riêng');
      expect(outJson['full_address'], '123 Đường Số 1, Phường 2, Quận 3, TP.HCM');
      expect(outJson['is_default'], true);
    });

    test('copyWith works correctly', () {
      const address = AddressModel(
        id: 'addr_1',
        label: 'Văn phòng',
        recipientName: 'Trần B',
        phoneNumber: '0912345678',
        fullAddress: '456 Lê Lợi, Q.1',
        isDefault: false,
      );

      final updated = address.copyWith(
        fullAddress: '789 Nguyễn Huệ, Q.1',
        isDefault: true,
      );

      expect(updated.id, 'addr_1');
      expect(updated.label, 'Văn phòng');
      expect(updated.fullAddress, '789 Nguyễn Huệ, Q.1');
      expect(updated.isDefault, true);
    });
  });

  group('AddressService Tests', () {
    test('getAddresses returns empty when no storage', () async {
      final addresses = await AddressService.getAddresses();
      expect(addresses, isEmpty);
    });

    test('saveAddress, setDefault and deleteAddress', () async {
      final addr1 = AddressModel(
        id: 'a1',
        label: 'Nhà riêng',
        recipientName: 'User A',
        phoneNumber: '0901234567',
        fullAddress: 'Địa chỉ 1',
        isDefault: true,
      );

      final addr2 = AddressModel(
        id: 'a2',
        label: 'Văn phòng',
        recipientName: 'User A',
        phoneNumber: '0901234567',
        fullAddress: 'Địa chỉ 2',
        isDefault: false,
      );

      await AddressService.saveAddress(addr1);
      await AddressService.saveAddress(addr2);

      var list = await AddressService.getAddresses();
      expect(list.length, 2);
      expect(list.firstWhere((a) => a.id == 'a1').isDefault, true);

      // Đổi địa chỉ mặc định sang addr2
      await AddressService.setDefaultAddress('a2');
      list = await AddressService.getAddresses();
      expect(list.firstWhere((a) => a.id == 'a2').isDefault, true);
      expect(list.firstWhere((a) => a.id == 'a1').isDefault, false);

      // Xóa addr1
      await AddressService.deleteAddress('a1');
      list = await AddressService.getAddresses();
      expect(list.length, 1);
      expect(list[0].id, 'a2');
    });
  });
}
