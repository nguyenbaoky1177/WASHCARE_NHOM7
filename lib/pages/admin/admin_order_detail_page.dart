import '../../core/request_timeout.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/order_status_badge.dart';
import '../../core/app_colors.dart';
import '../../core/supabase_client.dart';
import '../../widgets/momo_payment_card.dart';
import '../../models/models.dart';

class AdminOrderDetailPage extends StatefulWidget {
  final OrderModel order;

  const AdminOrderDetailPage({super.key, required this.order});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  late OrderModel _order;
  bool _updating = false;
  RealtimeChannel? _detailChannel;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _setupRealtime();
  }

  @override
  void dispose() {
    if (_detailChannel != null) {
      supabase.removeChannel(_detailChannel!);
    }
    super.dispose();
  }

  void _setupRealtime() {
    final channelName =
        'admin_detail_${_order.id}_${DateTime.now().millisecondsSinceEpoch}';
    _detailChannel = supabase.channel(channelName);

    _detailChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _order.id,
          ),
          callback: (_) async {
            if (!mounted) return;
            try {
              await _reloadOrder();
            } catch (error) {
              debugPrint('Admin realtime reload failed: $error');
            }
          },
        )
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed && mounted) {
            try {
              await _reloadOrder();
            } catch (error) {
              debugPrint('Admin reconnect reload failed: $error');
            }
          }
        });
  }

  Future<void> _reloadOrder() async {
    final refreshed = await supabase
        .from('orders')
        .select('*, order_items(*, services(name, unit))')
        .eq('id', _order.id)
        .maybeSingle()
        .timeout(supabaseRequestTimeout);

    if (refreshed != null && mounted) {
      setState(() {
        _order = OrderModel.fromJson(refreshed);
      });
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _updateStatus(String newStatus, String actionName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xác nhận $actionName'),
        content: Text(
          'Bạn có chắc muốn chuyển trạng thái đơn #${_order.id} sang "$actionName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _updating = true);

    try {
      await supabase.rpc(
        'admin_update_order_status',
        params: {
          'p_order_id': _order.id,
          'p_new_status': newStatus,
          'p_note': actionName,
        },
      );

      if (!mounted) return;

      _showMessage('Đã chuyển đơn sang: $actionName');
      await _reloadOrder();
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('admin') ||
          errStr.contains('permission') ||
          errStr.contains('42501')) {
        _showMessage(
          'Lỗi: Bạn cần được cấp role="admin" trong bảng profiles để cập nhật đơn.',
        );
      } else {
        _showMessage('Cập nhật thất bại: $e');
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _manualChangeStatus() async {
    const statusOptions = [
      ('pending', 'Chờ xác nhận (pending)', Color(0xFFED8B00)),
      ('confirmed', 'Đã tiếp nhận (confirmed)', primaryBlue),
      ('washing', 'Đang giặt sấy (washing)', Color(0xFF7952B3)),
      ('delivering', 'Đang giao hàng', Colors.teal),
      ('completed', 'Hoàn thành & Giao đồ (completed)', Color(0xFF16845B)),
      ('cancelled', 'Đã hủy / Từ chối (cancelled)', Color(0xFFD64545)),
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text(
          'Chọn trạng thái cập nhật',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: statusOptions
            .where((opt) {
              return switch (_order.status) {
                'pending' => ['confirmed', 'cancelled'].contains(opt.$1),
                'confirmed' => opt.$1 == 'washing',
                'washing' => opt.$1 == 'delivering',
                'delivering' => opt.$1 == 'completed',
                _ => false,
              };
            })
            .map((opt) {
              final isCurrent = _order.status == opt.$1;
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, opt.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: opt.$3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          opt.$2,
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrent ? opt.$3 : Colors.black87,
                          ),
                        ),
                      ),
                      if (isCurrent)
                        const Icon(Icons.check, size: 18, color: Colors.green),
                    ],
                  ),
                ),
              );
            })
            .toList(),
      ),
    );

    if (selected != null && selected != _order.status && mounted) {
      final label = statusOptions.firstWhere((e) => e.$1 == selected).$2;
      await _updateStatus(selected, label);
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showMessage('Không thể thực hiện cuộc gọi tới $phone');
      }
    } catch (e) {
      _showMessage('Lỗi mở ứng dụng gọi điện: $e');
    }
  }

  Future<void> _openMap(String address) async {
    if (address.isEmpty) return;
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showMessage('Không thể mở bản đồ');
      }
    } catch (e) {
      _showMessage('Lỗi mở bản đồ: $e');
    }
  }

  Widget _infoRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Chưa có thông tin' : value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text('Quản trị đơn #${_order.id}'),
        backgroundColor: darkBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE4ECF5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TRẠNG THÁI HIỆN TẠI',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      OrderStatusBadge(
                        order: _order,
                        showIcon: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        backgroundAlpha: 0.12,
                        fontSize: 13,
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  const Text(
                    'THAO TÁC XỬ LÝ ĐƠN HÀNG',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_updating)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    if (_order.status == 'pending') ...[
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _updateStatus('confirmed', 'Tiếp nhận đơn'),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Tiếp nhận đơn'),
                              style: FilledButton.styleFrom(
                                backgroundColor: primaryBlue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _updateStatus('cancelled', 'Hủy đơn hàng'),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Từ chối'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_order.status == 'confirmed') ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              _updateStatus('washing', 'Bắt đầu giặt sấy'),
                          icon: const Icon(Icons.local_laundry_service),
                          label: const Text('Bắt đầu giặt sấy'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7952B3),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ] else if (_order.status == 'washing') ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              _updateStatus('delivering', 'Bắt đầu giao hàng'),
                          icon: const Icon(Icons.task_alt),
                          label: const Text('Bắt đầu giao hàng'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF16845B),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ] else if (_order.status == 'delivering') ...[
                      FilledButton.icon(
                        onPressed: () =>
                            _updateStatus('completed', 'Đã giao hàng'),
                        icon: const Icon(Icons.task_alt),
                        label: const Text('Xác nhận đã giao'),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _order.status == 'completed'
                              ? '✓ Đơn hàng đã hoàn thành trọn vẹn.'
                              : '✕ Đơn hàng đã bị hủy.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        onPressed: _manualChangeStatus,
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text(
                          'Đổi trạng thái tùy chọn...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE4ECF5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THÔNG TIN KHÁCH HÀNG & GIAO NHẬN',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _infoRow('Khách hàng', _order.customerName),
                  _infoRow(
                    'Số điện thoại',
                    _order.phone,
                    trailing: IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      tooltip: 'Gọi cho khách',
                      onPressed: () => _makePhoneCall(_order.phone),
                    ),
                  ),
                  _infoRow(
                    'Địa chỉ',
                    _order.address,
                    trailing: IconButton(
                      icon: const Icon(Icons.map_outlined, color: primaryBlue),
                      tooltip: 'Mở bản đồ',
                      onPressed: () => _openMap(_order.address),
                    ),
                  ),
                  _infoRow('Ngày đặt', _order.formattedCreatedAt),
                  _infoRow('Hẹn lấy đồ', _order.formattedPickupTime),
                  if ((_order.note ?? '').isNotEmpty)
                    _infoRow('Ghi chú của khách', _order.note!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE4ECF5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DỊCH VỤ ĐÃ ĐẶT',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_order.items.isEmpty)
                    const Text('Không có thông tin chi tiết dịch vụ.')
                  else
                    ..._order.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.checkroom_outlined,
                              color: primaryBlue,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.serviceName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${item.formattedQuantity} ${item.serviceUnit}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (item.subtotal > 0) ...[
                              const SizedBox(width: 12),
                              Text(
                                item.formattedSubtotal,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng tiền thanh toán',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _order.formattedTotalPrice,
                        style: const TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  if (['momo', 'momo_demo'].contains(_order.paymentMethod) &&
                      !_order.isCancelled) ...[
                    const SizedBox(height: 16),
                    MomoPaymentCard(order: _order, allowPayment: false),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
