import '../core/order_status_tracker.dart';
import '../core/request_timeout.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/order_status_badge.dart';
import '../core/app_colors.dart';
import '../core/notification_service.dart';
import '../core/review_service.dart';
import '../core/supabase_client.dart';
import '../widgets/momo_payment_card.dart';
import '../models/models.dart';
import '../widgets/order_review_dialog.dart';
import 'customer_order_detail_page.dart';

class ActiveOrdersPage extends StatefulWidget {
  const ActiveOrdersPage({super.key, this.isVisible = true});

  final bool isVisible;

  @override
  State<ActiveOrdersPage> createState() => _ActiveOrdersPageState();
}

class _ActiveOrdersPageState extends State<ActiveOrdersPage> {
  late Future<List<OrderModel>> _ordersFuture;
  String _selectedFilter = 'all';
  final Set<String> _cancellingOrders = {};
  RealtimeChannel? _ordersChannel;
  Map<int, ReviewModel> _reviews = {};
  final _statusTracker = OrderStatusTracker();
  int _loadGeneration = 0;
  int _eventRevision = 0;

  static const Color _primary = primaryBlue;
  static const Color _background = Color(0xFFF4F7FB);

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
    _setupRealtimeSubscription();
  }

  @override
  void didUpdateWidget(covariant ActiveOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _refreshOrders();
    }
  }

  @override
  void dispose() {
    if (_ordersChannel != null) {
      supabase.removeChannel(_ordersChannel!);
    }
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final channelName =
        'realtime_orders_${user.id}_${DateTime.now().millisecondsSinceEpoch}';
    _ordersChannel = supabase.channel(channelName);

    _ordersChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (!mounted) return;

            _eventRevision++;
            final eventType = payload.eventType;
            final newRecord = payload.newRecord;

            if (eventType == PostgresChangeEvent.update &&
                _statusTracker.recordUpdate(
                  newRecord,
                  oldRecord: payload.oldRecord,
                )) {
              final newStatus = newRecord['status']?.toString() ?? '';
              final orderId = newRecord['id']?.toString() ?? '';

              String statusName = newStatus;
              switch (newStatus) {
                case 'pending':
                  statusName = 'Chờ xác nhận';
                  break;
                case 'confirmed':
                  statusName = 'Đã xác nhận';
                  break;
                case 'washing':
                  statusName = 'Đang xử lý';
                  break;
                case 'delivering':
                  statusName = 'Đang giao hàng';
                  break;
                case 'completed':
                  statusName = 'Hoàn thành';
                  break;
                case 'cancelled':
                  statusName = 'Đã hủy';
                  break;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Đơn hàng #$orderId vừa cập nhật: $statusName',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              final parsedOrderId = int.tryParse(orderId) ?? 0;
              if (parsedOrderId > 0) {
                NotificationService.notifyOrderStatusChange(
                  parsedOrderId,
                  newStatus,
                );
              }
            }

            _refreshOrders();
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed && mounted) {
            _refreshOrders();
          }
        });
  }

  Future<List<OrderModel>> _loadOrders() async {
    final generation = ++_loadGeneration;
    final revision = _eventRevision;
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    try {
      // Chạy song song truy vấn đơn hàng (kèm timeout 5s) và nạp đánh giá
      final ordersFuture = supabase
          .from('orders')
          .select('*, order_items(*, services(name, unit))')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .timeout(supabaseRequestTimeout);

      final reviewsFuture = ReviewService.getAllReviews();

      final results = await Future.wait([ordersFuture, reviewsFuture]);
      final ordersList = (results[0] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => OrderModel.fromJson(item))
          .toList();

      if (mounted && generation == _loadGeneration) {
        _reviews = results[1] as Map<int, ReviewModel>;
        if (revision == _eventRevision) {
          _statusTracker.seed(
            ordersList.map(
              (order) => (id: order.id.toString(), status: order.status),
            ),
          );
        }
      }
      return ordersList;
    } catch (e) {
      debugPrint('ActiveOrdersPage._loadOrders error: $e');
      rethrow;
    }
  }

  Future<void> _openReviewDialog(OrderModel order) async {
    final updated = await OrderReviewDialog.show(
      context,
      order: order,
      initialReview: _reviews[order.id],
    );
    if (updated != null && mounted) {
      setState(() {
        _reviews[order.id] = updated;
      });
    }
  }

  Future<void> _refreshOrders() async {
    if (!mounted) return;

    final future = _loadOrders();

    setState(() {
      _ordersFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder handles displaying error state.
    }
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    switch (_selectedFilter) {
      case 'active':
        return orders.where((o) => o.isActive).toList();
      case 'completed':
        return orders.where((o) => o.isCompleted).toList();
      case 'cancelled':
        return orders.where((o) => o.isCancelled).toList();
      default:
        return orders;
    }
  }

  int _countOrders(List<OrderModel> orders, String filter) {
    switch (filter) {
      case 'active':
        return orders.where((o) => o.isActive).length;
      case 'completed':
        return orders.where((o) => o.isCompleted).length;
      case 'cancelled':
        return orders.where((o) => o.isCancelled).length;
      default:
        return orders.length;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancelOrder(OrderModel order) async {
    if (!order.canCancel) {
      _showMessage(
        'Không thể hủy đơn ở trạng thái hiện tại. Hãy kiểm tra giao dịch MoMo nếu có.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận hủy đơn'),
        content: Text(
          'Bạn có chắc muốn hủy đơn hàng #${order.id} không? '
          'Thao tác này sẽ cập nhật trạng thái đơn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      _showMessage('Phiên đăng nhập đã hết hạn.');
      return;
    }

    final orderId = order.id.toString();

    if (_cancellingOrders.contains(orderId)) return;

    setState(() {
      _cancellingOrders.add(orderId);
    });

    var cancelledSuccessfully = false;

    try {
      final updated = await supabase
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', order.id)
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .select('id');

      if (!mounted) return;

      if (updated.isEmpty) {
        _showMessage(
          'Không thể hủy đơn. Có thể trạng thái đơn đã thay đổi '
          'hoặc bạn không có quyền cập nhật đơn này.',
        );
      } else {
        cancelledSuccessfully = true;
        _showMessage('Đã hủy đơn hàng #$orderId.');
      }
    } catch (e) {
      _showMessage('Hủy đơn thất bại: $e');
    } finally {
      if (mounted) {
        setState(() {
          _cancellingOrders.remove(orderId);
        });
      }
    }

    if (cancelledSuccessfully && mounted) {
      await _refreshOrders();
    }
  }

  Widget _buildFilter(List<OrderModel> orders) {
    const filters = [
      ('all', 'Tất cả'),
      ('active', 'Đang xử lý'),
      ('completed', 'Hoàn thành'),
      ('cancelled', 'Đã hủy'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _selectedFilter == filter.$1;

          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text('${filter.$2} (${_countOrders(orders, filter.$1)})'),
            selectedColor: _primary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? _primary : const Color(0xFFDDE5EF),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF44546A),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
            onSelected: (_) {
              setState(() {
                _selectedFilter = filter.$1;
              });
            },
          );
        },
      ),
    );
  }

  Future<void> _openOrderDetail(OrderModel order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CustomerOrderDetailPage(order: order),
      ),
    );

    if (mounted) {
      await _refreshOrders();
    }
  }

  Widget _buildOrderCard(OrderModel order) {
    final color = order.statusColor;
    final orderId = order.id.toString();
    final cancelling = _cancellingOrders.contains(orderId);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE7EDF5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openOrderDetail(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_laundry_service_outlined,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đơn hàng #${order.id}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF24364B),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          order.formattedCreatedAt,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(order.statusIcon, size: 14, color: color),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              order.statusDisplayName,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              _infoRow(
                Icons.person_outline,
                order.customerName.isNotEmpty
                    ? order.customerName
                    : 'Chưa có tên người nhận',
              ),
              const SizedBox(height: 10),
              _infoRow(
                Icons.location_on_outlined,
                order.address.isNotEmpty ? order.address : 'Chưa có địa chỉ',
              ),
              const SizedBox(height: 16),
              const Text(
                'DỊCH VỤ',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              if (order.items.isEmpty)
                const Text(
                  'Chưa có thông tin dịch vụ.',
                  style: TextStyle(color: Colors.black54),
                )
              else
                ...order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.checkroom_outlined,
                          size: 17,
                          color: _primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.serviceName)),
                        Text(
                          '${item.formattedQuantity} ${item.serviceUnit}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  );
                }),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng thanh toán',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Flexible(
                    child: Text(
                      order.formattedTotalPrice,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _infoRow(
                Icons.access_time,
                'Thời gian nhận: ${order.formattedPickupTime}',
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Nhấn để xem chi tiết  ›',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (order.isCompleted) ...[
                const Divider(height: 24),
                Builder(
                  builder: (context) {
                    final review = _reviews[order.id];
                    if (review != null) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Đã đánh giá: ${review.rating}★ (${review.ratingLabel})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8A5A00),
                                    ),
                                  ),
                                  if (review.comment.isNotEmpty)
                                    Text(
                                      review.comment,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: Colors.amber[900],
                              ),
                              onPressed: () => _openReviewDialog(order),
                              child: const Text('Sửa'),
                            ),
                          ],
                        ),
                      );
                    }
                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openReviewDialog(order),
                        icon: const Icon(Icons.star_outline_rounded, size: 18),
                        label: const Text('Đánh giá chất lượng dịch vụ'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (order.canCancel) ...[
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: cancelling ? null : () => _cancelOrder(order),
                    icon: cancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(cancelling ? 'Đang hủy...' : 'Hủy đơn hàng'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(
          Icons.receipt_long_outlined,
          size: 76,
          color: Colors.blueGrey.shade200,
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'Chưa có đơn hàng phù hợp',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Thử chọn bộ lọc khác hoặc kéo xuống để làm mới.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Đơn hàng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    color: Colors.greenAccent,
                    size: 9,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Realtime',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<OrderModel>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Không tải được danh sách đơn hàng.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vui lòng kiểm tra kết nối Internet và thử lại.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refreshOrders,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];
          final filteredOrders = _filterOrders(orders);

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 16, bottom: 14),
                color: _background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Theo dõi đơn giặt ủi của bạn (cập nhật trực tiếp)',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildFilter(orders),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshOrders,
                  child: filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) =>
                              _buildOrderCard(filteredOrders[index]),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  final OrderModel order;
  final Future<void> Function() onCancel;

  const OrderDetailPage({
    super.key,
    required this.order,
    required this.onCancel,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late OrderModel _order;
  RealtimeChannel? _detailChannel;
  ReviewModel? _review;

  static const Color _primary = primaryBlue;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _setupOrderRealtime();
    _loadReview();
  }

  Future<void> _reloadOrder() async {
    try {
      final row = await supabase
          .from('orders')
          .select('*, order_items(*, services(name, unit))')
          .eq('id', _order.id)
          .single()
          .timeout(supabaseRequestTimeout);
      if (mounted) setState(() => _order = OrderModel.fromJson(row));
    } catch (error) {
      debugPrint('Reload order failed: $error');
    }
  }

  Future<void> _loadReview() async {
    final r = await ReviewService.getReviewForOrder(_order.id);
    if (mounted) {
      setState(() {
        _review = r;
      });
    }
  }

  Future<void> _handleReview() async {
    final res = await OrderReviewDialog.show(
      context,
      order: _order,
      initialReview: _review,
    );
    if (res != null && mounted) {
      setState(() {
        _review = res;
      });
    }
  }

  @override
  void dispose() {
    if (_detailChannel != null) {
      supabase.removeChannel(_detailChannel!);
    }
    super.dispose();
  }

  void _setupOrderRealtime() {
    final channelName =
        'realtime_detail_${_order.id}_${DateTime.now().millisecondsSinceEpoch}';
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
            final oldStatus = _order.status;
            await _reloadOrder();
            if (mounted && oldStatus != _order.status) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Trạng thái đơn hàng vừa cập nhật: ${_order.statusDisplayName}',
                  ),
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed && mounted) {
            _reloadOrder();
          }
        });
  }

  int _currentStepIndex(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'confirmed':
        return 1;
      case 'washing':
        return 2;
      case 'delivering':
        return 3;
      case 'completed':
        return 4;
      default:
        return 0;
    }
  }

  Widget _buildStatusStepper(String status) {
    if (status == 'cancelled') {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDEDED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF5C2C2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel, color: Color(0xFFD64545), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đơn hàng đã hủy',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD64545),
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Đơn hàng này đã bị hủy và không còn được xử lý.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final currentIndex = _currentStepIndex(status);

    const steps = [
      ('Chờ duyệt', Icons.receipt_long),
      ('Tiếp nhận', Icons.check_circle_outline),
      ('Đang giặt', Icons.local_laundry_service),
      ('Đang giao', Icons.local_shipping),
      ('Hoàn thành', Icons.task_alt),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4ECF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TIẾN TRÌNH XỬ LÝ ĐƠN HÀNG',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final stepIndex = i ~/ 2;
                final isDone = stepIndex < currentIndex;
                return Expanded(
                  child: Container(
                    height: 3,
                    color: isDone ? _primary : const Color(0xFFE2E8F0),
                  ),
                );
              }

              final stepIndex = i ~/ 2;
              final isPassed = stepIndex <= currentIndex;
              final isCurrent = stepIndex == currentIndex;

              final (stepTitle, stepIcon) = steps[stepIndex];

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isPassed ? _primary : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: isCurrent
                          ? Border.all(
                              color: _primary.withValues(alpha: 0.4),
                              width: 4,
                            )
                          : null,
                    ),
                    child: Icon(
                      stepIcon,
                      size: 18,
                      color: isPassed ? Colors.white : Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stepTitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent
                          ? _primary
                          : (isPassed ? Colors.black87 : Colors.black45),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(title, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Chưa có thông tin' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Row(
          children: [
            Text('Chi tiết đơn #${_order.id}'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    color: Colors.greenAccent,
                    size: 8,
                  ),
                  SizedBox(width: 3),
                  Text(
                    'Live',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusStepper(_order.status),
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
                    'TRẠNG THÁI ĐƠN HÀNG',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OrderStatusBadge(
                    order: _order,
                    showIcon: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    radius: 22,
                    fontSize: null,
                  ),
                  const Divider(height: 32),
                  _detailRow('Mã đơn', '#${_order.id}'),
                  _detailRow('Ngày đặt', _order.formattedCreatedAt),
                  _detailRow('Thời gian nhận', _order.formattedPickupTime),
                  _detailRow(
                    'Người nhận',
                    _order.customerName.isNotEmpty
                        ? _order.customerName
                        : 'Chưa có tên',
                  ),
                  _detailRow(
                    'Số điện thoại',
                    _order.phone.isNotEmpty ? _order.phone : 'Chưa có số',
                  ),
                  _detailRow(
                    'Địa chỉ',
                    _order.address.isNotEmpty
                        ? _order.address
                        : 'Chưa có địa chỉ',
                  ),
                  if ((_order.note ?? '').isNotEmpty)
                    _detailRow('Ghi chú', _order.note!),
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
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_order.items.isEmpty)
                    const Text('Chưa có thông tin dịch vụ.')
                  else
                    ..._order.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_laundry_service_outlined,
                              color: _primary,
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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  const Divider(height: 28),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tổng thanh toán',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        _order.formattedTotalPrice,
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (['momo', 'momo_demo'].contains(_order.paymentMethod) &&
              !_order.isCancelled) ...[
            const SizedBox(height: 14),
            MomoPaymentCard(order: _order, onClosed: _reloadOrder),
          ],
          if (_order.isCompleted) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _review != null
                      ? Colors.amber.withValues(alpha: 0.3)
                      : const Color(0xFFE4ECF5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.stars_rounded,
                          color: Colors.amber,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _review != null
                                  ? 'Đánh giá của bạn (${_review!.rating}★)'
                                  : 'Đánh giá dịch vụ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF24364B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _review != null ? _review!.ratingLabel : 'Chia sẻ cảm nhận giúp WashCare nâng cao chất lượng',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _handleReview,
                        child: Text(
                          _review != null ? 'Sửa' : 'Đánh giá',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_review != null) ...[
                    const Divider(height: 20),
                    if (_review!.tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _review!.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber[900],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    if (_review!.comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '"${_review!.comment}"',
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
          if (_order.canCancel) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  await widget.onCancel();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Hủy đơn hàng'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn chỉ có thể hủy đơn khi đơn đang chờ xác nhận.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
