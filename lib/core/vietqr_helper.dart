import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_settings.dart';

class VietQrHelper {
  // Cấu hình tài khoản ngân hàng nhận tiền của tiệm WashCare
  static const String defaultBankId = 'MB'; // MB Bank (Napas 970422)
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
          backgroundColor: ctx.cardSurface,
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
                            color: ctx.accentSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.qr_code_2, color: ctx.accentColor, size: 24),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          AppSettings.text(context, 'Thanh toán VietQR', 'VietQR Payment'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ctx.headingColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: ctx.mutedColor),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  AppSettings.text(
                    context,
                    'Quét mã bằng app ngân hàng bất kỳ để tự động điền số tiền & nội dung chuyển khoản.',
                    'Scan with any banking app to automatically fill amount & memo.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: ctx.mutedColor),
                ),
                const SizedBox(height: 16),

                // QR Code Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ctx.cardOutline, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      qrUrl,
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          width: 240,
                          height: 240,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 240,
                          height: 240,
                          color: Colors.grey[100],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(
                                AppSettings.text(context, 'Mã QR thanh toán', 'Payment QR'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedAmount,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: ctx.accentColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Bank Info Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ctx.insetSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ctx.cardOutline),
                  ),
                  child: Column(
                    children: [
                      _buildCopyableRow(
                        context: ctx,
                        label: AppSettings.text(context, 'Ngân hàng', 'Bank'),
                        value: bankName,
                        copyValue: bankName,
                      ),
                      const Divider(height: 16),
                      _buildCopyableRow(
                        context: ctx,
                        label: AppSettings.text(context, 'Số tài khoản', 'Account No'),
                        value: accountNo,
                        copyValue: accountNo,
                        isBold: true,
                        valueColor: ctx.accentColor,
                      ),
                      const Divider(height: 16),
                      _buildCopyableRow(
                        context: ctx,
                        label: AppSettings.text(context, 'Chủ tài khoản', 'Account Name'),
                        value: accountName,
                        copyValue: accountName,
                      ),
                      const Divider(height: 16),
                      _buildCopyableRow(
                        context: ctx,
                        label: AppSettings.text(context, 'Số tiền', 'Amount'),
                        value: formattedAmount,
                        copyValue: amount.toStringAsFixed(0),
                        isBold: true,
                        valueColor: const Color(0xFF16845B),
                      ),
                      const Divider(height: 16),
                      _buildCopyableRow(
                        context: ctx,
                        label: AppSettings.text(context, 'Nội dung CK', 'Transfer memo'),
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
                      backgroundColor: ctx.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppSettings.text(
                              context,
                              'Cảm ơn bạn! Tiệm sẽ xác nhận thanh toán khi nhận được tiền.',
                              'Thank you! The store will confirm once payment is received.',
                            ),
                          ),
                          backgroundColor: const Color(0xFF16845B),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      AppSettings.text(
                        context,
                        'Tôi đã chuyển khoản thành công',
                        'I have completed the transfer',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
            style: TextStyle(fontSize: 12, color: context.mutedColor),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? context.detailColor,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Clipboard.setData(ClipboardData(text: copyValue));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppSettings.text(
                    context,
                    'Đã sao chép "$copyValue" vào bộ nhớ tạm',
                    'Copied "$copyValue" to clipboard',
                  ),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy, size: 14, color: context.accentColor),
                const SizedBox(width: 3),
                Text(
                  AppSettings.text(context, 'Chép', 'Copy'),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
