import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_settings.dart';
import '../core/notification_service.dart';
import '../models/notification_model.dart';
import 'active_orders_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<NotificationModel>> _notificationsFuture;
  String _selectedFilter = 'all'; // 'all', 'unread', 'order_update', 'promo'

  @override
  void initState() {
    super.initState();
    _notificationsFuture = NotificationService.getNotifications();
  }

  Future<void> _refresh() async {
    final future = NotificationService.getNotifications();
    setState(() {
      _notificationsFuture = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _handleMarkAllAsRead() async {
    await NotificationService.markAllAsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đánh dấu tất cả là đã đọc'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      _refresh();
    }
  }

  Future<void> _handleClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xóa tất cả thông báo?'),
        content: const Text('Tất cả lịch sử thông báo sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationService.clearAll();
      if (mounted) {
        _refresh();
      }
    }
  }

  Future<void> _handleItemClick(NotificationModel item) async {
    if (!item.isRead) {
      await NotificationService.markAsRead(item.id);
      _refresh();
    }

    if (item.orderId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActiveOrdersPage()),
      );
    }
  }

  List<NotificationModel> _filterItems(List<NotificationModel> items) {
    switch (_selectedFilter) {
      case 'unread':
        return items.where((n) => !n.isRead).toList();
      case 'order_update':
        return items.where((n) => n.type == 'order_update').toList();
      case 'promo':
        return items.where((n) => n.type == 'promo').toList();
      case 'all':
      default:
        return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageSurface,
      appBar: AppBar(
        title: Text(
          AppSettings.text(context, 'Thông báo', 'Notifications'),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: context.cardSurface,
        foregroundColor: context.headingColor,
        systemOverlayStyle: context.isDarkTheme
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Đánh dấu đã đọc tất cả',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: _handleMarkAllAsRead,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'clear') _handleClearAll();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Xóa tất cả thông báo', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationModel>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allItems = snapshot.data ?? [];
          final filtered = _filterItems(allItems);
          final unreadCount = allItems.where((n) => !n.isRead).length;

          return Column(
            children: [
              // Filter Chips
              Container(
                color: context.cardSurface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip('Tất cả', 'all', allItems.length),
                      const SizedBox(width: 8),
                      _buildChip('Chưa đọc', 'unread', unreadCount),
                      const SizedBox(width: 8),
                      _buildChip(
                        'Đơn hàng',
                        'order_update',
                        allItems.where((n) => n.type == 'order_update').length,
                      ),
                      const SizedBox(width: 8),
                      _buildChip(
                        'Ưu đãi',
                        'promo',
                        allItems.where((n) => n.type == 'promo').length,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE4ECF5)),

              // Notification List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: filtered.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                'Không có thông báo nào',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: context.headingColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                _selectedFilter == 'unread'
                                    ? 'Bạn đã đọc tất cả thông báo!'
                                    : 'WashCare sẽ cập nhật tin tức và đơn hàng tại đây.',
                                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          itemCount: filtered.length,
                          separatorBuilder: (ctx, i) => const Divider(
                            height: 1,
                            indent: 72,
                            endIndent: 16,
                            color: Color(0xFFF0F4F8),
                          ),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final color = item.typeColor;

                            return InkWell(
                              onTap: () => _handleItemClick(item),
                              child: Container(
                                color: item.isRead
                                    ? Colors.transparent
                                    : primaryBlue.withAlpha(10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Icon category
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: color.withAlpha(25),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(item.iconData, color: color, size: 22),
                                    ),
                                    const SizedBox(width: 12),

                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: TextStyle(
                                                    fontWeight: item.isRead
                                                        ? FontWeight.w600
                                                        : FontWeight.bold,
                                                    fontSize: 14,
                                                    color: context.headingColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                item.formattedTime,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.message,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: item.isRead
                                                  ? context.mutedColor
                                                  : context.detailColor,
                                              height: 1.3,
                                            ),
                                          ),
                                          if (item.orderId != null) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: primaryBlue.withAlpha(20),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Xem đơn hàng #${item.orderId}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: primaryBlue,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      const Icon(
                                                        Icons.chevron_right_rounded,
                                                        size: 14,
                                                        color: primaryBlue,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // Unread dot
                                    if (!item.isRead) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(top: 6),
                                        decoration: const BoxDecoration(
                                          color: primaryBlue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChip(String label, String value, int count) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: context.accentSurface,
      checkmarkColor: context.accentColor,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? context.accentColor : context.detailColor,
      ),
      backgroundColor: context.insetSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? primaryBlue : context.cardOutline,
        ),
      ),
      onSelected: (_) {
        setState(() => _selectedFilter = value);
      },
    );
  }
}
