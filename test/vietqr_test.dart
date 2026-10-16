import 'package:flutter_test/flutter_test.dart';
import 'package:washcare/core/vietqr_helper.dart';

void main() {
  group('VietQrHelper Tests', () {
    test('generateQrUrl creates valid VietQR URL with parameters', () {
      final url = VietQrHelper.generateQrUrl(
        amount: 80000,
        orderId: 9,
      );

      expect(url, contains('https://img.vietqr.io/image/'));
      expect(url, contains('amount=80000'));
      expect(url, contains('WASHCARE%20DON%209'));
    });

    test('generateQrUrl formats custom bank details correctly', () {
      final url = VietQrHelper.generateQrUrl(
        amount: 150000,
        orderId: 12,
        bankId: 'VCB',
        accountNo: '1234567890',
        accountName: 'TEST SHOP',
      );

      expect(url, contains('/VCB-1234567890-compact2.png'));
      expect(url, contains('amount=150000'));
      expect(url, contains('WASHCARE%20DON%2012'));
      expect(url, contains('accountName=TEST%20SHOP'));
    });
  });
}
