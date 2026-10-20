import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/review_service.dart';
import '../models/order_model.dart';
import '../models/review_model.dart';

class OrderReviewDialog extends StatefulWidget {
  final OrderModel order;
  final ReviewModel? initialReview;

  const OrderReviewDialog({
    super.key,
    required this.order,
    this.initialReview,
  });

  static Future<ReviewModel?> show(
    BuildContext context, {
    required OrderModel order,
    ReviewModel? initialReview,
  }) {
    return showModalBottomSheet<ReviewModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderReviewDialog(
        order: order,
        initialReview: initialReview,
      ),
    );
  }

  @override
  State<OrderReviewDialog> createState() => _OrderReviewDialogState();
}

class _OrderReviewDialogState extends State<OrderReviewDialog> {
  late int _rating;
  late TextEditingController _commentController;
  late Set<String> _selectedTags;
  bool _isSubmitting = false;

  final List<String> _positiveTags = [
    'Giặt rất sạch',
    'Thơm ngát',
    'Giao đúng hẹn',
    'Gấp xếp gọn gàng',
    'Nhân viên thân thiện',
    'Giá cả hợp lý',
  ];

  final List<String> _criticalTags = [
    'Giao trễ hẹn',
    'Vết bẩn chưa sạch',
    'Mùi hương chưa thơm',
    'Cần đóng gói kỹ hơn',
    'Chưa đúng yêu cầu',
  ];

  @override
  void initState() {
    super.initState();
    _rating = widget.initialReview?.rating ?? 5;
    _commentController = TextEditingController(text: widget.initialReview?.comment ?? '');
    _selectedTags = Set<String>.from(widget.initialReview?.tags ?? []);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String get _ratingLabel {
    switch (_rating) {
      case 5:
        return 'Tuyệt vời! Rất hài lòng ⭐';
      case 4:
        return 'Tốt! Dịch vụ ổn định 👍';
      case 3:
        return 'Bình thường, cần cải thiện 🙂';
      case 2:
        return 'Chưa hài lòng 🙁';
      case 1:
        return 'Rất không hài lòng 😞';
      default:
        return 'Đánh giá dịch vụ';
    }
  }

  Color get _ratingColor {
    if (_rating >= 4) return Colors.amber[700]!;
    if (_rating == 3) return Colors.orange;
    return Colors.redAccent;
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);

    final review = ReviewModel(
      id: widget.initialReview?.id,
      orderId: widget.order.id,
      userId: widget.order.userId,
      rating: _rating,
      comment: _commentController.text.trim(),
      tags: _selectedTags.toList(),
      createdAt: DateTime.now(),
    );

    final success = await ReviewService.saveReview(review);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, review);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Cảm ơn bạn đã đánh giá dịch vụ WashCare!'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentTags = _rating >= 4 ? _positiveTags : _criticalTags;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh kéo nhỏ trên đầu dialog
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tiêu đề
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đánh giá chất lượng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Đơn hàng #${widget.order.id}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Đóng',
                ),
              ],
            ),
            const Divider(height: 24),

            // Chấm sao tương tác 1 - 5 sao
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNumber = index + 1;
                      final isSelected = starNumber <= _rating;
                      return IconButton(
                        iconSize: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        icon: AnimatedScale(
                          duration: const Duration(milliseconds: 200),
                          scale: isSelected ? 1.1 : 0.9,
                          child: Icon(
                            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isSelected ? _ratingColor : Colors.grey[300],
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _rating = starNumber;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _ratingLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _ratingColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tag gợi ý nhanh
            Text(
              'Bạn thấy điều gì nổi bật nhất?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: currentTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withAlpha(40),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? AppColors.primary : Colors.grey[800],
                  ),
                  backgroundColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    ),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Nhận xét chi tiết
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Để lại ý kiến đóng góp giúp WashCare phục vụ bạn tốt hơn...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 14),

            // Nút gửi đánh giá
            ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Gửi đánh giá',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
