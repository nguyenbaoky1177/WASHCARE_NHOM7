import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/app_settings.dart';
import '../core/request_timeout.dart';
import '../core/review_service.dart';
import '../core/supabase_client.dart';
import '../models/models.dart';
import '../widgets/order_review_dialog.dart';
import '../widgets/order_status_badge.dart';
import '../core/vietqr_helper.dart';

class CustomerOrderDetailPage extends StatefulWidget {
  final OrderModel order;

  const CustomerOrderDetailPage({super.key, required this.order});

  @override
  State<CustomerOrderDetailPage> createState() =>
      _CustomerOrderDetailPageState();
}

class _CustomerOrderDetailPageState extends State<CustomerOrderDetailPage> {
  late OrderModel _order;
  ReviewModel? _review;
  bool _isLoadingReview = true;
  bool _isCancelling = false;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _setupRealtime();
    _loadReview();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _setupRealtime() {
    final channelName =
        'customer_order_detail_${_order.id}_${DateTime.now().millisecondsSinceEpoch}';
    _realtimeChannel = supabase.channel(channelName);

    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _order.id,
          ),
          callback: (payload) {
            _reloadOrder();
          },
        )
        .subscribe();
  }

  Future<void> _reloadOrder() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await supabase
          .from('orders')
          .select('*, order_items(*, services(name, unit))')
          .eq('id', _order.id)
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(supabaseRequestTimeout);

      if (res != null && mounted && supabase.auth.currentUser?.id == userId) {
        setState(() {
          _order = OrderModel.fromJson(res);
        });
        if (_order.isCompleted) {
          _loadReview();
        }
      }
    } catch (e) {
      debugPrint('CustomerOrderDetailPage reload error: $e');
    }
  }

  Future<void> _loadReview() async {
    try {
      final review = await ReviewService.getReviewForOrder(_order.id);
      if (mounted) {
        setState(() {
          _review = review;
          _isLoadingReview = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingReview = false);
      }
    }
  }

  Future<void> _callHotline() async {
    final uri = Uri.parse('tel:19001234');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppSettings.text(context, 'Xác nhận hủy đơn', 'Cancel this order?')),
        content: Text(
          AppSettings.text(context, 'Bạn có chắc chắn muốn hủy đơn hàng #${_order.id} không?', 'Cancel order #${_order.id}?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppSettings.text(context, 'Không', 'Keep order')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppSettings.text(context, 'Hủy đơn', 'Cancel order')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Bạn chưa đăng nhập.');

      final updated = await supabase
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', _order.id)
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .select('id');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isEmpty
                ? AppSettings.text(context, 'Không thể hủy đơn. Trạng thái đơn có thể đã thay đổi.', 'Could not cancel this order. Its status may have changed.')
                : AppSettings.text(context, 'Đã hủy đơn hàng thành công', 'Order cancelled'),
          ),
        ),
      );

      await _reloadOrder();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hủy đơn thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _openReviewDialog() async {
    final result = await OrderReviewDialog.show(
      context,
      order: _order,
      initialReview: _review,
    );

    if (result != null) {
      _loadReview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageSurface,
      appBar: AppBar(
        title: Text(
          AppSettings.text(context, 'Chi tiết đơn #${_order.id}', 'Order #${_order.id}'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: darkBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppSettings.text(context, 'Làm mới', 'Refresh'),
            onPressed: _reloadOrder,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(),
      body: RefreshIndicator(
        onRefresh: _reloadOrder,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // 1. Trạng thái & Tiến trình xử lý
            _buildStatusHeaderCard(),
            const SizedBox(height: 16),

            // 2. Timeline Tiến trình các bước
            if (!_order.isCancelled) ...[
              _buildTimelineCard(),
              const SizedBox(height: 16),
            ],

            // 3. Thông tin người nhận và lịch hẹn
            _buildDeliveryInfoCard(),
            const SizedBox(height: 16),

            // 4. Danh sách dịch vụ
            _buildItemsListCard(),
            const SizedBox(height: 16),

            // 5. Tóm tắt chi phí & Thanh toán
            _buildPaymentSummaryCard(),
            const SizedBox(height: 16),

            // 6. Đánh giá dịch vụ (nếu đơn đã hoàn thành)
            if (_order.isCompleted) ...[
              _buildReviewSectionCard(),
              const SizedBox(height: 16),
            ],

            // 7. Cần trợ giúp?
            _buildSupportBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeaderCard() {
    return Card(
      elevation: 1,
      color: context.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _order.statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _order.statusIcon,
                color: _order.statusColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppSettings.text(context, 'Đơn hàng #${_order.id}', 'Order #${_order.id}'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.headingColor,
                        ),
                      ),
                      OrderStatusBadge(order: _order),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppSettings.text(context, 'Đặt lúc: ${_order.formattedCreatedAt}', 'Placed: ${_order.formattedCreatedAt}'),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.mutedColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    String text(String vi, String en) => AppSettings.text(context, vi, en);
    final stages = [
      {
        'key': 'pending',
        'title': text('Chờ xác nhận', 'Awaiting confirmation'),
        'desc': text('Tiệm đang tiếp nhận đơn', 'The laundry is reviewing your order'),
      },
      {
        'key': 'confirmed',
        'title': text('Đã xác nhận', 'Confirmed'),
        'desc': text('Tài xế nhận lịch lấy đồ', 'Pickup has been scheduled'),
      },
      {
        'key': 'washing',
        'title': text('Đang xử lý', 'Washing'),
        'desc': text('Đang phân loại và giặt sấy', 'Your laundry is being sorted and washed'),
      },
      {
        'key': 'delivering',
        'title': text('Đang giao', 'Out for delivery'),
        'desc': text('Đang trên đường giao trả đồ', 'Your laundry is on its way back'),
      },
      {
        'key': 'completed',
        'title': text('Hoàn thành', 'Completed'),
        'desc': text('Đã hoàn tất đơn hàng', 'Your order is complete'),
      },
    ];

    int currentStep = 0;
    switch (_order.status) {
      case 'pending':
        currentStep = 0;
        break;
      case 'confirmed':
        currentStep = 1;
        break;
      case 'washing':
        currentStep = 2;
        break;
      case 'delivering':
        currentStep = 3;
        break;
      case 'completed':
        currentStep = 4;
        break;
      default:
        currentStep = 0;
    }

    return Card(
      elevation: 1,
      color: context.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_outlined, color: context.accentColor, size: 20),
                SizedBox(width: 8),
                Text(
                  AppSettings.text(context, 'Tiến trình xử lý', 'Order progress'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.headingColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < stages.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= currentStep ? primaryBlue : Colors.grey.shade300,
                        ),
                        child: Icon(
                          i < currentStep
                              ? Icons.check
                              : (i == currentStep ? Icons.circle : Icons.circle_outlined),
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      if (i < stages.length - 1)
                        Container(
                          width: 2,
                          height: 36,
                          color: i < currentStep ? primaryBlue : Colors.grey.shade300,
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stages[i]['title']!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: i == currentStep
                                  ? FontWeight.bold
                                  : (i < currentStep
                                      ? FontWeight.w600
                                      : FontWeight.normal),
                              color: i <= currentStep ? context.headingColor : context.mutedColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stages[i]['desc']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: i == currentStep
                                  ? primaryBlue
                                  : context.mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoCard() {
    return Card(
      elevation: 1,
      color: context.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: context.accentColor, size: 20),
                SizedBox(width: 8),
                Text(
                  AppSettings.text(context, 'Thông tin giao nhận đồ', 'Pickup and delivery'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.headingColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              label: AppSettings.text(context, 'Thời gian lấy đồ hẹn trước', 'Scheduled pickup'),
              value: _order.formattedPickupTime,
              highlight: true,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.person_outline,
              label: AppSettings.text(context, 'Khách hàng', 'Customer'),
              value: '${_order.customerName} • ${_order.phone}',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.location_on_outlined,
              label: AppSettings.text(context, 'Địa chỉ lấy & giao đồ', 'Pickup and delivery address'),
              value: _order.address,
            ),
            if (_order.note != null && _order.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.edit_note,
                label: AppSettings.text(context, 'Ghi chú cho tiệm', 'Notes for the laundry'),
                value: _order.note!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: highlight ? context.accentColor : context.mutedColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: context.mutedColor),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
                  color: highlight ? context.accentColor : context.detailColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsListCard() {
    return Card(
      elevation: 1,
      color: context.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.dry_cleaning_outlined, color: context.accentColor, size: 20),
                    SizedBox(width: 8),
                    Text(
                      AppSettings.text(context, 'Dịch vụ đã chọn', 'Selected services'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.headingColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  AppSettings.text(
                    context,
                    '${_order.items.length} món',
                    '${_order.items.length} items',
                  ),
                  style: TextStyle(fontSize: 13, color: context.mutedColor),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_order.items.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(AppSettings.text(context, 'Không có thông tin chi tiết dịch vụ', 'No service details')),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _order.items.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final item = _order.items[index];
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.accentSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.local_laundry_service,
                          size: 18,
                          color: context.accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.serviceName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: context.headingColor,
                              ),
                            ),
                            Text(
                              AppSettings.text(context, 'Số lượng: ${item.formattedQuantity} ${item.serviceUnit}', 'Quantity: ${item.formattedQuantity} ${item.serviceUnit}'),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        item.formattedSubtotal,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.headingColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSummaryCard() {
    final isVietQr = _order.paymentMethod == 'vietqr' || (_order.note?.contains('VIETQR') == true);
    final isCod = _order.paymentMethod == 'cod' && !isVietQr;
    final isMomo = ['momo', 'momo_demo'].contains(_order.paymentMethod);
    final isPaid = _order.isCodCollected ||
        (isMomo && _order.momoPaymentStatus == 'paid');
    String text(String vi, String en) => AppSettings.text(context, vi, en);

    final method = isVietQr
        ? text('Chuyển khoản (VietQR)', 'Bank transfer (VietQR)')
        : switch (_order.paymentMethod) {
            'cod' => text('Tiền mặt (COD)', 'Cash on delivery'),
            'momo' => 'MoMo Sandbox',
            'momo_demo' => text('MoMo mô phỏng', 'MoMo simulation'),
            'vietqr' => text('Chuyển khoản (VietQR)', 'Bank transfer (VietQR)'),
            _ => text('Phương thức cũ', 'Legacy method'),
          };
    final status = switch ((_order.isCancelled, isVietQr, isCod, isPaid, _order.isCompleted)) {
      (_, _, _, true, _) => text('Đã ghi nhận thanh toán', 'Payment recorded'),
      (true, _, _, _, _) => text('Đơn đã hủy', 'Order cancelled'),
      (_, true, _, _, _) => text('Chờ chuyển khoản VietQR', 'Awaiting VietQR transfer'),
      (_, _, true, _, true) => text('Chưa có xác nhận thu tiền', 'Collection not recorded'),
      (_, _, true, _, _) => text('Thanh toán khi nhận đồ', 'Pay on delivery'),
      _ => text('Liên hệ hỗ trợ để kiểm tra', 'Contact support to verify'),
    };

    return Card(
      elevation: 1,
      color: context.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_outlined, color: context.accentColor, size: 20),
                SizedBox(width: 8),
                Text(
                  text('Chi tiết thanh toán', 'Payment details'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.headingColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: isCod ? Icons.payments_outlined : Icons.receipt_outlined,
              label: text('Phương thức thanh toán', 'Payment method'),
              value: method,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.info_outline,
              label: text('Trạng thái thanh toán', 'Payment status'),
              value: status,
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  text('Tổng cộng', 'Total'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.headingColor,
                  ),
                ),
                Text(
                  _order.formattedTotalPrice,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD64545),
                  ),
                ),
              ],
            ),
            if (isVietQr && !isPaid && !_order.isCancelled) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.accentColor,
                    side: BorderSide(color: context.accentColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.qr_code_2, size: 20),
                  label: Text(
                    text('Xem mã QR thanh toán (VietQR)', 'View VietQR payment code'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    VietQrHelper.showPaymentDialog(
                      context: context,
                      orderId: _order.id,
                      amount: _order.totalPrice,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSectionCard() {
    if (_isLoadingReview) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      elevation: 1,
      color: context.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rate_rounded, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Text(
                      AppSettings.text(context, 'Đánh giá của bạn', 'Your review'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.headingColor,
                      ),
                    ),
                  ],
                ),
                if (_review != null)
                  TextButton.icon(
                    onPressed: _openReviewDialog,
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(AppSettings.text(context, 'Sửa', 'Edit')),
                  ),
              ],
            ),
            const Divider(height: 20),
            if (_review == null) ...[
              Text(
                AppSettings.text(context, 'Bạn hài lòng với dịch vụ của WashCare chứ? Hãy để lại đánh giá nhé!', 'How was your WashCare experience? Leave a review.'),
                style: TextStyle(fontSize: 13, color: context.mutedColor),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.accentColor,
                    side: BorderSide(color: context.accentColor),
                  ),
                  onPressed: _openReviewDialog,
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(AppSettings.text(context, 'Viết đánh giá', 'Write a review')),
                ),
              ),
            ] else ...[
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < _review!.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 20,
                  );
                }),
              ),
              if (_review!.comment.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _review!.comment,
                  style: TextStyle(fontSize: 13, color: context.detailColor),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSupportBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.accentSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0E1F4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.cardSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.headset_mic_outlined, color: context.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppSettings.text(context, 'Cần hỗ trợ về đơn hàng này?', 'Need help with this order?'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.headingColor,
                  ),
                ),
                Text(
                  'Hotline 1900 1234 (08:00 - 21:00)',
                  style: TextStyle(fontSize: 11, color: context.mutedColor),
                ),
              ],
            ),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.call, size: 18),
            onPressed: _callHotline,
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomActionBar() {
    if (!_order.canCancel) return null;

    return Container(
      color: context.cardSurface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        top: false,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isCancelling ? null : _cancelOrder,
          icon: _isCancelling
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cancel_outlined, size: 18),
          label: Text(_isCancelling ? AppSettings.text(context, 'Đang hủy...', 'Cancelling…') : AppSettings.text(context, 'Hủy đơn hàng', 'Cancel order')),
        ),
      ),
    );
  }
}
