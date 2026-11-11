import '../core/order_status_tracker.dart';
import '../core/request_timeout.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_colors.dart';
import '../core/app_settings.dart';
import '../core/notification_service.dart';
import '../core/review_service.dart';
import '../core/supabase_client.dart';
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
  final _orderSearch = TextEditingController();
  final Set<String> _cancellingOrders = {};
  RealtimeChannel? _ordersChannel;
  Map<int, ReviewModel> _reviews = {};
  final _statusTracker = OrderStatusTracker();
  int _loadGeneration = 0;
  int _eventRevision = 0;

  static const Color _primary = primaryBlue;

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
    _orderSearch.dispose();
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
                  statusName = AppSettings.text(context, 'Đang xử lý', 'In progress');
                  break;
                case 'delivering':
                  statusName = 'Đang giao hàng';
                  break;
                case 'completed':
                  statusName = AppSettings.text(context, 'Hoàn thành', 'Completed');
                  break;
                case 'cancelled':
                  statusName = AppSettings.text(context, 'Đã hủy', 'Cancelled');
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
        title: Text(AppSettings.text(context, 'Xác nhận hủy đơn', 'Cancel this order?')),
        content: Text(
          'Bạn có chắc muốn hủy đơn hàng #${order.id} không? '
          'Thao tác này sẽ cập nhật trạng thái đơn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppSettings.text(context, 'Không', 'Keep order')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppSettings.text(context, 'Xác nhận hủy', 'Cancel order')),
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
    final filters = [
      ('all', AppSettings.text(context, 'Tất cả', 'All')),
      ('active', AppSettings.text(context, 'Đang xử lý', 'In progress')),
      ('completed', AppSettings.text(context, 'Hoàn thành', 'Completed')),
      ('cancelled', AppSettings.text(context, 'Đã hủy', 'Cancelled')),
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
            backgroundColor: context.cardSurface,
            side: BorderSide(
              color: selected ? _primary : context.cardOutline,
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : context.mutedColor,
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
    final statusColor = order.statusColor;
    final color = context.isDarkTheme
        ? Color.lerp(statusColor, Colors.white, 0.45)!
        : statusColor;
    final reviewColor = context.isDarkTheme
        ? Colors.amber.shade200
        : const Color(0xFF8A5A00);
    final orderId = order.id.toString();
    final cancelling = _cancellingOrders.contains(orderId);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: context.cardSurface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.cardOutline),
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
                      color: context.accentSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_laundry_service_outlined,
                      color: context.accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppSettings.text(context, 'Đơn hàng #${order.id}', 'Order #${order.id}'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.headingColor,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          order.formattedCreatedAt,
                          style: TextStyle(
                            color: context.mutedColor,
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
                              AppSettings.text(
                                context,
                                order.statusDisplayName,
                                switch (order.status) {
                                  'pending' => 'Awaiting confirmation',
                                  'confirmed' => 'Confirmed',
                                  'washing' => 'Washing',
                                  'delivering' => 'Out for delivery',
                                  'completed' => 'Completed',
                                  'cancelled' => 'Cancelled',
                                  _ => order.status,
                                },
                              ),
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
                    : AppSettings.text(context, 'Chưa có tên người nhận', 'No recipient name'),
              ),
              const SizedBox(height: 10),
              _infoRow(
                Icons.location_on_outlined,
                order.address.isNotEmpty ? order.address : AppSettings.text(context, 'Chưa có địa chỉ', 'No address'),
              ),
              const SizedBox(height: 16),
              Text(
                AppSettings.text(context, 'DỊCH VỤ', 'SERVICES'),
                style: TextStyle(
                  color: context.mutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              if (order.items.isEmpty)
                Text(
                  AppSettings.text(context, 'Chưa có thông tin dịch vụ.', 'No service details.'),
                  style: TextStyle(color: context.mutedColor),
                )
              else
                ...order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.checkroom_outlined,
                          size: 17,
                          color: context.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.serviceName)),
                        Text(
                          '${item.formattedQuantity} ${item.serviceUnit}',
                          style: TextStyle(color: context.mutedColor),
                        ),
                      ],
                    ),
                  );
                }),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppSettings.text(context, 'Tổng thanh toán', 'Order total'),
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Flexible(
                    child: Text(
                      order.formattedTotalPrice,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: context.accentColor,
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
                AppSettings.text(context, 'Thời gian nhận: ${order.formattedPickupTime}', 'Pickup: ${order.formattedPickupTime}'),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  AppSettings.text(context, 'Nhấn để xem chi tiết  ›', 'View details  ›'),
                  style: TextStyle(
                    color: context.accentColor,
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
                                    AppSettings.text(
                                      context,
                                      'Đã đánh giá: ${review.rating}★ (${review.ratingLabel})',
                                      'Rated: ${review.rating}★',
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: reviewColor,
                                    ),
                                  ),
                                  if (review.comment.isNotEmpty)
                                    Text(
                                      review.comment,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: context.mutedColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: reviewColor,
                              ),
                              onPressed: () => _openReviewDialog(order),
                              child: Text(AppSettings.text(context, 'Sửa', 'Edit')),
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
                        label: Text(AppSettings.text(context, 'Đánh giá chất lượng dịch vụ', 'Rate this service')),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.black,
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
                    label: Text(cancelling ? AppSettings.text(context, 'Đang hủy...', 'Cancelling…') : AppSettings.text(context, 'Hủy đơn hàng', 'Cancel order')),
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
        Icon(icon, size: 18, color: context.mutedColor),
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
        Center(
          child: Text(
            AppSettings.text(context, 'Chưa có đơn hàng phù hợp', 'No matching orders'),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            AppSettings.text(context, 'Thử chọn bộ lọc khác hoặc kéo xuống để làm mới.', 'Try a different filter or pull down to refresh.'),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageSurface,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              AppSettings.text(context, 'Đơn hàng', 'Orders'),
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
                    Text(
                      AppSettings.text(context, 'Không tải được danh sách đơn hàng.', 'Could not load orders.'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppSettings.text(context, 'Vui lòng kiểm tra kết nối Internet và thử lại.', 'Check your internet connection and try again.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: context.mutedColor),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refreshOrders,
                      child: Text(AppSettings.text(context, 'Thử lại', 'Retry')),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];
          final query = _orderSearch.text.trim();
          final orderId = int.tryParse(query.replaceFirst(RegExp(r'^#\s*'), ''));
          final matches = query.isEmpty
              ? orders
              : orders.where((order) => order.id == orderId).toList();
          final filteredOrders = _filterOrders(matches);

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 16, bottom: 14),
                color: context.pageSurface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        AppSettings.text(context, 'Theo dõi đơn giặt ủi của bạn (cập nhật trực tiếp)', 'Track your laundry orders in real time'),
                        style: TextStyle(fontSize: 14, color: context.mutedColor),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _orderSearch,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: AppSettings.text(
                            context, 'Tìm theo mã đơn', 'Find by order number',
                          ),
                          hintText: '#13',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: AppSettings.text(context, 'Xóa tìm kiếm', 'Clear search'),
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(_orderSearch.clear),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFilter(matches),
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
