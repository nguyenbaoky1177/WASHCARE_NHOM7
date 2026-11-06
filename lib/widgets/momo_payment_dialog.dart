import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/momo_payment_service.dart';
import '../core/supabase_client.dart';

class MomoPaymentDialog extends StatefulWidget {
  const MomoPaymentDialog({
    super.key,
    required this.orderId,
    required this.amount,
    this.allowPayment = true,
    this.legacyDemo = false,
  });

  final int orderId;
  final double amount;
  final bool allowPayment;
  final bool legacyDemo;

  static Future<bool?> show({
    required BuildContext context,
    required int orderId,
    required double amount,
    bool allowPayment = true,
    bool legacyDemo = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MomoPaymentDialog(
        orderId: orderId,
        amount: amount,
        allowPayment: allowPayment,
        legacyDemo: legacyDemo,
      ),
    );
  }

  @override
  State<MomoPaymentDialog> createState() => _MomoPaymentDialogState();
}

class _MomoPaymentDialogState extends State<MomoPaymentDialog>
    with WidgetsBindingObserver {
  static const _momoColor = Color(0xFFA50064);

  late double _amount;
  bool _busy = false;
  bool _loaded = false;
  bool _cancelled = false;
  String _status = 'unpaid';
  String? _error;

  bool get _paid => _status == 'paid';

  @override
  void initState() {
    super.initState();
    _amount = widget.amount;
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !widget.legacyDemo && !_busy) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await supabase
          .from('orders')
          .select(
            widget.legacyDemo
                ? 'total_price, demo_payment_status, status'
                : 'total_price, momo_payment_status, status',
          )
          .eq('id', widget.orderId)
          .single()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      var status = widget.legacyDemo
          ? (order['demo_payment_status'] == 'succeeded' ? 'paid' : 'unpaid')
          : order['momo_payment_status']?.toString() ?? 'unpaid';
      setState(() {
        _amount = (order['total_price'] as num).toDouble();
        _cancelled = order['status'] == 'cancelled';
        _status = status;
        _loaded = true;
      });
      if (!widget.legacyDemo) {
        final result = await MomoPaymentService.request(
          'check',
          orderId: widget.orderId,
        );
        status = result['payment_status'] as String;
      }
      if (!mounted) return;
      setState(() {
        _amount = (order['total_price'] as num).toDouble();
        _cancelled = order['status'] == 'cancelled';
        _status = status;
        _loaded = true;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is MomoPaymentException
              ? error.message
              : 'Không tải được thanh toán. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPayment() async {
    if (_busy || !_loaded || _paid || _cancelled || widget.legacyDemo) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await MomoPaymentService.request(
        'create',
        orderId: widget.orderId,
      );
      if (!mounted) return;
      setState(() => _status = result['payment_status'] as String);
      final value = result['pay_url'];
      if (value != null) {
        final url = Uri.parse(value as String);
        if (url.scheme != 'https' ||
            url.host != 'test-payment.momo.vn' ||
            url.userInfo.isNotEmpty ||
            url.hasPort) {
          throw const MomoPaymentException(
            'Địa chỉ thanh toán Sandbox không hợp lệ.',
          );
        }
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          throw const MomoPaymentException(
            'Không mở được trình duyệt thanh toán.',
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is MomoPaymentException
              ? error.message
              : 'Không tải được thanh toán. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _statusLabel {
    if (widget.legacyDemo) {
      return _paid
          ? 'Đã mô phỏng thành công (dữ liệu cũ)'
          : 'Chưa hoàn tất mô phỏng';
    }
    return switch (_status) {
      'paid' => 'MoMo đã xác nhận thanh toán thành công',
      'pending' => 'Đang chờ kết quả từ MoMo',
      'failed' => 'Giao dịch chưa thành công. Bạn có thể thử lại.',
      'review_required' => 'Cần cửa hàng kiểm tra giao dịch này',
      _ => 'Chưa thanh toán',
    };
  }

  @override
  Widget build(BuildContext context) {
    final amount = _amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          widget.legacyDemo ? 'MoMo mô phỏng (đơn cũ)' : 'MoMo Sandbox',
        ),
        scrollable: true,
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: _paid ? Colors.green : _momoColor,
                child: _paid
                    ? const Icon(Icons.check, color: Colors.white, size: 38)
                    : const Text(
                        'MoMo',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.legacyDemo
                    ? 'Kết quả mô phỏng của phiên bản trước'
                    : 'Môi trường thử nghiệm chính thức của MoMo',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _momoColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (!widget.legacyDemo)
                const Text(
                  'Thanh toán trên trang MoMo Sandbox, sau đó quay lại WashCare '
                  'và kiểm tra trạng thái.',
                  textAlign: TextAlign.center,
                ),
              const Divider(height: 28),
              Text('Đơn hàng #${widget.orderId}'),
              const SizedBox(height: 6),
              Text(
                '$amount đ',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_busy)
                const CircularProgressIndicator()
              else if (_loaded)
                Text(_statusLabel, textAlign: TextAlign.center),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, _paid),
            child: const Text('Đóng'),
          ),
          if (!widget.legacyDemo)
            TextButton(
              onPressed: _busy ? null : _loadStatus,
              child: const Text('Kiểm tra trạng thái'),
            ),
          if (!widget.legacyDemo &&
              widget.allowPayment &&
              !_cancelled &&
              _loaded &&
              !_paid &&
              _status != 'review_required')
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _momoColor),
              onPressed: _busy ? null : _openPayment,
              child: const Text('Mở MoMo Sandbox'),
            ),
        ],
      ),
    );
  }
}
