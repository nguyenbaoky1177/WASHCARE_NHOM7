import 'package:flutter_test/flutter_test.dart';
import 'package:washcare/core/vietqr_helper.dart';

void main() {
  group('VietQrHelper', () {
    test('generateQrUrl generates correct standard Napas URL with defaults', () {
      final url = VietQrHelper.generateQrUrl(
        amount: 85000,
        orderId: 105,
      );

      expect(url, contains('https://img.vietqr.io/image/MB-0987654321-compact2.png'));
      expect(url, contains('amount=85000'));
      expect(url, contains('addInfo=WASHCARE%20DON%20105'));
      expect(url, contains('accountName=TIEM%20GIAT%20SAY%20WASHCARE'));
    });

    test('generateQrUrl generates correct URL with custom bank details', () {
      final url = VietQrHelper.generateQrUrl(
        amount: 150000.5,
        orderId: 'WC-999',
        bankId: 'VCB',
        accountNo: '1234567890',
        accountName: 'NGUYEN VAN A',
      );

      expect(url, contains('https://img.vietqr.io/image/VCB-1234567890-compact2.png'));
      expect(url, contains('amount=150001'));
      expect(url, contains('addInfo=WASHCARE%20DON%20WC-999'));
      expect(url, contains('accountName=NGUYEN%20VAN%20A'));
    });
  });
}
