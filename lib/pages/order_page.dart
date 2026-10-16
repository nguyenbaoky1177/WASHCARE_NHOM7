import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_colors.dart';
import '../core/supabase_client.dart';
import '../models/models.dart';

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
  final _voucherController = TextEditingController();

  List<ServiceModel> _services = [];
  final Map<int, double> _quantities = {};

  DateTime? _pickupTime;
  String _deliveryType = 'standard'; // 'standard' (24-48h) or 'express' (4-6h)
  String _paymentMethod = 'cod'; // 'cod' or 'vietqr'

  double _discountAmount = 0.0;
  String? _appliedVoucher;

  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Default pickup time: tomorrow at 9:00 AM
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _pickupTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = supabase.auth.currentUser;

      if (user != null) {
        final profileData = await supabase
            .from('profiles')
            .select('id, full_name, phone')
            .eq('id', user.id)
            .maybeSingle();

        if (profileData != null) {
          final profile = ProfileModel.fromJson(profileData);
          _nameController.text = profile.fullName;
          _phoneController.text = profile.phone ?? '';
        }
      }

      final result = await supabase
          .from('services')
          .select('id, name, description, price, unit, icon, is_active')
          .eq('is_active', true)
          .order('id');

      _services = (result as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => ServiceModel.fromJson(item))
          .toList();

      for (final service in _services) {
        _quantities[service.id] = 0;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được danh mục dịch vụ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _subtotal {
    double total = 0;
    for (final service in _services) {
      total += service.price * (_quantities[service.id] ?? 0);
    }
    return total;
  }

  double get _shippingFee {
    if (_subtotal == 0) return 0;
    if (_deliveryType == 'express') return 25000;
    // Standard: Free shipping for orders >= 100.000đ, otherwise 15.000đ
    return _subtotal >= 100000 ? 0 : 15000;
  }

  double get _finalTotal {
    final raw = _subtotal + _shippingFee - _discountAmount;
    return raw > 0 ? raw : 0;
  }

  String _formatMoney(num val) {
    return val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }

  void _applyVoucher() {
    final code = _voucherController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (code == 'WASHCARE20') {
      if (_subtotal < 50000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mã WASHCARE20 áp dụng cho đơn từ 50.000đ')),
        );
        return;
      }
      setState(() {
        _appliedVoucher = code;
        _discountAmount = 20000;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Áp dụng mã giảm giá 20.000đ thành công!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã ưu đãi không hợp lệ hoặc đã hết hạn.')),
      );
    }
  }

  Future<void> _choosePickupTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: _pickupTime ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Chọn ngày hẹn lấy đồ',
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_pickupTime ?? DateTime.now()),
      helpText: 'Chọn giờ hẹn lấy đồ',
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
        const SnackBar(content: Text('Vui lòng chọn thời gian trong tương lai.')),
      );
      return;
    }

    setState(() => _pickupTime = selected);
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final items = <Map<String, dynamic>>[];
    for (final service in _services) {
      final quantity = _quantities[service.id] ?? 0;
      if (quantity > 0) {
        items.add({
          'service_id': service.id,
          'quantity': quantity,
        });
      }
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 dịch vụ giặt ủi.')),
      );
      return;
    }

    if (_pickupTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn thời gian lấy đồ.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Build structured order note with shipping, payment & voucher details
      final speedLabel = _deliveryType == 'express' ? 'HỎA TỐC 4H' : 'TIÊU CHUẨN';
      final payLabel = _paymentMethod == 'cod' ? 'TIỀN MẶT KHI NHẬN (COD)' : 'CHUYỂN KHOẢN QR';
      final voucherLabel = _appliedVoucher != null ? ' | Voucher: $_appliedVoucher (-${_formatMoney(_discountAmount)}đ)' : '';
      final customNote = _noteController.text.trim();
      final fullNote = '[$speedLabel] [$payLabel]$voucherLabel${customNote.isNotEmpty ? ' | Ghi chú: $customNote' : ''}';

      final orderId = await supabase.rpc(
        'create_order',
        params: {
          'p_customer_name': _nameController.text.trim(),
          'p_phone': _phoneController.text.trim(),
          'p_address': _addressController.text.trim(),
          'p_pickup_time': _pickupTime!.toUtc().toIso8601String(),
          'p_note': fullNote,
          'p_items': items,
        },
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 54),
          title: const Text('Đặt dịch vụ thành công!', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mã đơn hàng: #$orderId',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Tổng tiền: ${_formatMoney(_finalTotal)} đ',
                style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                _paymentMethod == 'cod'
                    ? 'Bạn sẽ thanh toán tiền mặt khi shipper giao đồ sạch.'
                    : 'Nhân viên sẽ cung cấp mã QR chuyển khoản khi nhận đồ.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: primaryBlue),
              onPressed: () => Navigator.pop(context),
              child: const Text('Hoàn tất & Theo dõi'),
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

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: darkBlue),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Đặt lịch giặt ủi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _buildBottomCheckoutBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
                  // 1. Service Selection Section
                  _sectionTitle('1. Chọn dịch vụ giặt ủi', subtitle: 'Chọn khối lượng hoặc số lượng tương ứng'),
                  ..._buildServicesSelector(),

                  const SizedBox(height: 18),

                  // 2. Delivery Speed Options
                  _sectionTitle('2. Thời gian hoàn thành mong muốn'),
                  _buildDeliverySpeedSelector(),

                  const SizedBox(height: 18),

                  // 3. Pickup Schedule Selector
                  _sectionTitle('3. Lịch hẹn tài xế đến lấy đồ'),
                  _buildPickupSchedulePicker(),

                  const SizedBox(height: 18),

                  // 4. Contact & Address Details
                  _sectionTitle('4. Thông tin người nhận & Địa chỉ'),
                  _buildCustomerFields(),

                  const SizedBox(height: 18),

                  // 5. Voucher Code Input
                  _sectionTitle('5. Mã ưu đãi / Voucher'),
                  _buildVoucherInput(),

                  const SizedBox(height: 18),

                  // 6. Payment Method Selector
                  _sectionTitle('6. Phương thức thanh toán'),
                  _buildPaymentMethodSelector(),

                  const SizedBox(height: 18),

                  // 7. Order Cost Summary
                  _buildOrderSummaryCard(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildServicesSelector() {
    if (_services.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Hiện không có dịch vụ nào khả dụng.'),
        ),
      ];
    }

    return _services.map((service) {
      final quantity = _quantities[service.id] ?? 0;
      final isSelected = quantity > 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryBlue : const Color(0xFFE4ECF5),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? paleBlue : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(service.iconData, color: isSelected ? primaryBlue : Colors.blueGrey, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkBlue),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${service.formattedPrice} đ / ${service.unit}',
                    style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: quantity <= 0
                        ? null
                        : () => setState(() => _quantities[service.id] = quantity - 1),
                    icon: const Icon(Icons.remove),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _quantities[service.id] = quantity + 1),
                    icon: const Icon(Icons.add, color: primaryBlue),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildDeliverySpeedSelector() {
    return Row(
      children: [
        Expanded(
          child: _speedCard(
            type: 'standard',
            title: 'Tiêu chuẩn',
            time: '24 - 48 giờ',
            fee: _subtotal >= 100000 ? 'Miễn phí' : '15.000 đ',
            icon: Icons.local_shipping_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _speedCard(
            type: 'express',
            title: 'Hỏa tốc',
            time: '4 - 6 giờ',
            fee: '+25.000 đ',
            icon: Icons.bolt,
          ),
        ),
      ],
    );
  }

  Widget _speedCard({
    required String type,
    required String title,
    required String time,
    required String fee,
    required IconData icon,
  }) {
    final selected = _deliveryType == type;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _deliveryType = type),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primaryBlue : const Color(0xFFE4ECF5),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: selected ? primaryBlue : Colors.blueGrey, size: 22),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? primaryBlue : Colors.grey,
                  size: 20,
                ),
              ],
            ),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(time, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(fee, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? primaryBlue : darkBlue, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupSchedulePicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4ECF5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: paleBlue, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.calendar_month, color: primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thời gian shipper đến nhận:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 2),
                    Text(
                      _pickupTime == null
                          ? 'Chưa chọn thời gian'
                          : '${_pickupTime!.day.toString().padLeft(2, '0')}/${_pickupTime!.month.toString().padLeft(2, '0')}/${_pickupTime!.year} lúc ${_pickupTime!.hour.toString().padLeft(2, '0')}:${_pickupTime!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: darkBlue),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryBlue,
                  side: const BorderSide(color: primaryBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: _choosePickupTime,
                child: const Text('Thay đổi', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerFields() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4ECF5)),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Họ và tên người nhận *',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Nhập họ tên' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại liên hệ *',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Nhập số điện thoại';
              final clean = v.trim();
              if (!RegExp(r'^(0[1-9][0-9]{8,9})$').hasMatch(clean)) {
                return 'Số điện thoại 10 số bắt đầu bằng 0';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ nhận và giao đồ *',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Nhập địa chỉ nhận đồ' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Ghi chú cho xưởng giặt (nếu có)',
              hintText: 'Ví dụ: giặt riêng áo trắng, ủi li phẳng...',
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherInput() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4ECF5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _voucherController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Nhập mã: WASHCARE20',
                prefixIcon: Icon(Icons.confirmation_num_outlined, color: primaryBlue),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _appliedVoucher != null ? Colors.green : darkBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _applyVoucher,
            child: Text(_appliedVoucher != null ? 'Đã áp dụng' : 'Áp dụng'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    final options = [
      ('cod', 'Tiền mặt khi giao nhận (COD)', 'Thanh toán trực tiếp cho shipper khi nhận đồ sạch', Icons.payments_outlined),
      ('vietqr', 'Chuyển khoản VietQR / MoMo', 'Nhân viên sẽ cung cấp mã QR khi nhận đồ', Icons.qr_code_scanner),
    ];

    return Column(
      children: options.map((opt) {
        final selected = _paymentMethod == opt.$1;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? primaryBlue : const Color(0xFFE4ECF5),
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _paymentMethod = opt.$1),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected ? paleBlue : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(opt.$4, color: selected ? primaryBlue : Colors.blueGrey, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opt.$2,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: selected ? darkBlue : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          opt.$3,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? primaryBlue : Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4ECF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chi tiết thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkBlue)),
          const Divider(height: 20),
          _summaryRow('Tiền dịch vụ', '${_formatMoney(_subtotal)} đ'),
          _summaryRow(
            'Phí vận chuyển',
            _shippingFee == 0 ? 'Miễn phí' : '+${_formatMoney(_shippingFee)} đ',
            highlight: _shippingFee == 0,
          ),
          if (_discountAmount > 0)
            _summaryRow(
              'Giảm giá ($_appliedVoucher)',
              '-${_formatMoney(_discountAmount)} đ',
              highlight: true,
            ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
              Text(
                '${_formatMoney(_finalTotal)} đ',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String title, String val, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          Text(
            val,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.green : Colors.black87,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckoutBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tổng thanh toán:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text(
                  '${_formatMoney(_finalTotal)} đ',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBlue),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submitting ? null : _submitOrder,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_submitting ? 'Đang đặt...' : 'Xác nhận đặt đơn'),
            ),
          ),
        ],
      ),
    );
  }
}
