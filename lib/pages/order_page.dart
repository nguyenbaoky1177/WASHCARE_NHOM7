import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_colors.dart';
import '../core/supabase_client.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();

  List<Map<String, dynamic>> _services = [];
  final Map<int, double> _quantities = {};

  DateTime? _pickupTime;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = supabase.auth.currentUser;

      if (user != null) {
        final profile = await supabase
            .from('profiles')
            .select('full_name, phone')
            .eq('id', user.id)
            .maybeSingle();

        _nameController.text =
            profile?['full_name']?.toString() ?? '';

        _phoneController.text =
            profile?['phone']?.toString() ?? '';
      }

      final result = await supabase
          .from('services')
          .select('id, name, description, price, unit')
          .eq('is_active', true)
          .order('id');

      _services = List<Map<String, dynamic>>.from(result);

      for (final service in _services) {
        _quantities[service['id'] as int] = 0;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được dữ liệu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _total {
    double total = 0;

    for (final service in _services) {
      final id = service['id'] as int;
      final price = double.tryParse(
        service['price'].toString(),
      ) ??
          0;

      total += price * (_quantities[id] ?? 0);
    }

    return total;
  }

  String _money(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  Future<void> _choosePickupTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Chọn ngày lấy đồ',
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Chọn giờ lấy đồ',
    );

    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (selected.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn thời gian trong tương lai.'),
        ),
      );
      return;
    }

    setState(() => _pickupTime = selected);
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final items = <Map<String, dynamic>>[];

    for (final service in _services) {
      final id = service['id'] as int;
      final quantity = _quantities[id] ?? 0;

      if (quantity > 0) {
        items.add({
          'service_id': id,
          'quantity': quantity,
        });
      }
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn hãy chọn ít nhất một dịch vụ.'),
        ),
      );
      return;
    }

    if (_pickupTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn thời gian lấy đồ.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final orderId = await supabase.rpc(
        'create_order',
        params: {
          'p_customer_name': _nameController.text.trim(),
          'p_phone': _phoneController.text.trim(),
          'p_address': _addressController.text.trim(),
          'p_pickup_time': _pickupTime!.toUtc().toIso8601String(),
          'p_note': _noteController.text.trim(),
          'p_items': items,
        },
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 52,
          ),
          title: const Text('Đặt đơn thành công!'),
          content: Text(
            'Mã đơn hàng của bạn: #$orderId\n'
                'Tổng tiền: ${_money(_total)} đ',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hoàn tất'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đặt đơn: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Có lỗi xảy ra: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt đơn giặt'),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Chọn dịch vụ',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 12),

            if (_services.isEmpty)
              const Text('Hiện chưa có dịch vụ khả dụng.'),

            ..._services.map((service) {
              final id = service['id'] as int;
              final quantity = _quantities[id] ?? 0;
              final price = double.tryParse(
                service['price'].toString(),
              ) ??
                  0;
              final unit = service['unit']?.toString() ?? '';

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service['name'].toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        service['description']?.toString() ?? '',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_money(price)} đ / $unit',
                        style: const TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Text('Số lượng ($unit)'),
                          const Spacer(),
                          IconButton(
                            onPressed: quantity <= 0
                                ? null
                                : () {
                              setState(() {
                                _quantities[id] =
                                    quantity - 1;
                              });
                            },
                            icon: const Icon(
                              Icons.remove_circle_outline,
                            ),
                          ),
                          Text(
                            quantity.toStringAsFixed(
                              quantity % 1 == 0 ? 0 : 1,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _quantities[id] = quantity + 1;
                              });
                            },
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 18),
            const Text(
              'Thông tin nhận đồ',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 14),

            _field(
              controller: _nameController,
              label: 'Họ và tên',
              icon: Icons.person_outline,
              validator: (v) =>
              v == null || v.trim().isEmpty
                  ? 'Vui lòng nhập họ tên'
                  : null,
            ),
            _field(
              controller: _phoneController,
              label: 'Số điện thoại',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Vui lòng nhập số điện thoại';
                }
                final clean = v.trim();
                if (!RegExp(r'^(0[1-9][0-9]{8,9})$').hasMatch(clean)) {
                  return 'Số điện thoại không hợp lệ (10 chữ số, bắt đầu bằng 0)';
                }
                return null;
              },
            ),
            _field(
              controller: _addressController,
              label: 'Địa chỉ nhận đồ',
              icon: Icons.location_on_outlined,
              validator: (v) =>
              v == null || v.trim().isEmpty
                  ? 'Vui lòng nhập địa chỉ'
                  : null,
            ),

            OutlinedButton.icon(
              onPressed: _choosePickupTime,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _pickupTime == null
                    ? 'Chọn thời gian lấy đồ'
                    : 'Lấy đồ: ${_pickupTime!.day.toString().padLeft(2, '0')}/'
                    '${_pickupTime!.month.toString().padLeft(2, '0')}/'
                    '${_pickupTime!.year} '
                    '${_pickupTime!.hour.toString().padLeft(2, '0')}:'
                    '${_pickupTime!.minute.toString().padLeft(2, '0')}',
              ),
            ),

            const SizedBox(height: 14),
            _field(
              controller: _noteController,
              label: 'Ghi chú (không bắt buộc)',
              icon: Icons.notes,
              maxLines: 3,
            ),

            Container(
              margin: const EdgeInsets.symmetric(vertical: 18),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tổng tiền dự kiến',
                    style: TextStyle(color: darkBlue),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_money(_total)} đ',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tổng tiền được tính theo giá dịch vụ hiện tại.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submitOrder,
                icon: _submitting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.shopping_bag_outlined),
                label: Text(
                  _submitting ? 'Đang đặt đơn...' : 'Đặt đơn',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
