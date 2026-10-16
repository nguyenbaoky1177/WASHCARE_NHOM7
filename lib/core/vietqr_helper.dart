import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

class VietQrHelper {
  // Cấu hình tài khoản ngân hàng nhận tiền của tiệm WashCare
  static const String defaultBankId = 'MB'; // MB Bank
  static const String defaultBankName = 'MB Bank (Quân Đội)';
  static const String defaultAccountNo = '0987654321';
  static const String defaultAccountName = 'TIEM GIAT SAY WASHCARE';

  /// Sinh link ảnh mã VietQR chuẩn Napas 247
  static String generateQrUrl({
    required double amount,
    required dynamic orderId,
    String bankId = defaultBankId,
    String accountNo = defaultAccountNo,
    String accountName = defaultAccountName,
  }) {
    final cleanAmount = amount.toStringAsFixed(0);
    final addInfo = Uri.encodeComponent('WASHCARE DON $orderId');
    final encodedName = Uri.encodeComponent(accountName);
    return 'https://img.vietqr.io/image/$bankId-$accountNo-compact2.png?amount=$cleanAmount&addInfo=$addInfo&accountName=$encodedName';
  }

  /// Hiển thị Modal/Dialog quét mã VietQR thanh toán
  static Future<void> showPaymentDialog({
    required BuildContext context,
    required dynamic orderId,
    required double amount,
    String bankId = defaultBankId,
    String bankName = defaultBankName,
    String accountNo = defaultAccountNo,
    String accountName = defaultAccountName,
  }) async {
    final qrUrl = generateQrUrl(
      amount: amount,
      orderId: orderId,
      bankId: bankId,
      accountNo: accountNo,
      accountName: accountName,
    );

    final formattedAmount = '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    )} đ';

    final transferContent = 'WASHCARE DON $orderId';

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: paleBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.qr_code_2, color: primaryBlue, size: 24),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Thanh toán VietQR',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Quét mã bằng app ngân hàng bất kỳ để tự động điền số tiền & nội dung chuyển khoản.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),

                // QR Code Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      qrUrl,
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          width: 250,
                          height: 250,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 250,
                          height: 250,
                          color: const Color(0xFFF8FAFC),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image, color: Colors.grey, size: 40),
                                SizedBox(height: 8),
                                Text(
                                  'Không tải được mã QR.\nVui lòng chuyển khoản theo thông tin bên dưới.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, color: Colors.black45),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Bank details breakdown with 1-tap copy
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildCopyableRow(
                        context: ctx,
                        label: 'Ngân hàng',
                        value: bankName,
                        copyValue: bankName,
                      ),
                      const Divider(height: 16),
                      _buildCopyableRow(
                        context: ctx,
                        label: 'Số tài khoản',
                        value: accountNo,
                        copyValue: accountNo,
                        isBold: true,
                        valueColor: primaryBlue,
                      ),
                      const Divider(height: 16),
                      _buildCopyableRow(
                        context: ctx,
                        label: 'Chủ tài khoản',
                        value: accountName,
                        copyValue: accountName,
                      ),
                      const Divider(height: 16),
                      _buildCopyableRow(
                        context: ctx,
                        label: 'Số tiền',
                        value: formattedAmount,
                        copyValue: amount.toStringAsFixed(0),
                        isBold: true,
                        valueColor: const Color(0xFF16845B),
                      ),
                      const Divider(height: 16),
                      _buildCopyableRow(
                        context: ctx,
                        label: 'Nội dung CK',
                        value: transferContent,
                        copyValue: transferContent,
                        isBold: true,
                        valueColor: Colors.deepOrange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cảm ơn bạn! Tiệm sẽ xác nhận thanh toán khi nhận được tiền.'),
                          backgroundColor: Color(0xFF16845B),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Tôi đã chuyển khoản thành công', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildCopyableRow({
    required BuildContext context,
    required String label,
    required String value,
    required String copyValue,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Clipboard.setData(ClipboardData(text: copyValue));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã sao chép "$copyValue" vào bộ nhớ tạm'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy, size: 14, color: primaryBlue),
                SizedBox(width: 3),
                Text(
                  'Chép',
                  style: TextStyle(fontSize: 11, color: primaryBlue, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
