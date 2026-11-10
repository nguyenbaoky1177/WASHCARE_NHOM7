import '../core/account_storage.dart';
import '../core/address_service.dart';
import '../core/request_timeout.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/order/order_checkout_bar.dart';
import '../widgets/order/order_summary_card.dart';
import '../widgets/section_title.dart';
import '../core/app_colors.dart';
import '../core/app_settings.dart';
import '../core/profile_cache.dart';
import '../core/service_cache.dart';
import '../core/supabase_client.dart';
import '../core/momo_payment_service.dart';
import '../widgets/momo_payment_dialog.dart';
import '../models/models.dart';
import 'saved_addresses_page.dart';

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
  String _paymentMethod = 'cod'; // 'cod' or 'momo'

  double get _discountAmount =>
      _appliedVoucher == 'WASHCARE20' && _subtotal >= 50000 ? 20000 : 0;
  String? _appliedVoucher;
  String _savedAddress = '';

  AccountStorage? _addressStorage;
  String? _loadError;
  bool _checkingVoucher = false;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _addressStorage = AccountStorage.current;
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
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<Object?>([
        ProfileCache.getProfile(),
        ServiceCache.getServices(forceNetwork: true),
      ]);
      if (!mounted) return;
      final profile = results[0] as ProfileModel?;
      if (profile != null) {
        _nameController.text = profile.fullName;
        _phoneController.text = profile.phone ?? '';
      }
      final saved = await AddressService.getDefaultAddress();
      if (!mounted) return;
      _savedAddress = saved?.fullAddress ?? '';
      if (_addressController.text.isEmpty) _addressController.text = _savedAddress;
      _services = results[1] as List<ServiceModel>;
      for (final service in _services) {
        _quantities.putIfAbsent(service.id, () => 0);
      }
    } catch (error) {
      debugPrint('Order data load failed: $error');
      if (mounted) {
        _loadError = 'Không tải được dịch vụ. Vui lòng kiểm tra kết nối và thử lại.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectFromAddressBook() async {
    final selected = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => const SavedAddressesPage(isSelectMode: true),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _addressController.text = selected.fullAddress;
        if (selected.recipientName.isNotEmpty) {
          _nameController.text = selected.recipientName;
        }
        if (selected.phoneNumber.isNotEmpty) {
          _phoneController.text = selected.phoneNumber;
        }
      });
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
    return val
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
  }

  Future<void> _applyVoucher() async {
    if (_checkingVoucher || _submitting) return;
    final code = _voucherController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (code == 'WASHCARE20') {
      if (_subtotal < 50000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã WASHCARE20 áp dụng cho đơn từ 50.000đ'),
          ),
        );
        return;
      }
      setState(() => _checkingVoucher = true);
      try {
        final eligible = await supabase.rpc('is_first_order_eligible')
            .timeout(supabaseRequestTimeout);
        if (!mounted) return;
        if (eligible != true) {
          setState(() => _appliedVoucher = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mã chỉ áp dụng cho đơn đầu tiên chưa bị hủy.')),
          );
          return;
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chưa kiểm tra được mã ưu đãi. Vui lòng thử lại.')),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _checkingVoucher = false);
      }
      if (!mounted) return;
      setState(() {
        _appliedVoucher = code;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Áp dụng mã giảm giá 20.000đ thành công!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã ưu đãi không hợp lệ hoặc đã hết hạn.'),
        ),
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
      helpText: AppSettings.text(context, 'Chọn ngày hẹn lấy đồ', 'Select a pickup date'),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_pickupTime ?? DateTime.now()),
      helpText: AppSettings.text(context, 'Chọn giờ hẹn lấy đồ', 'Select a pickup time'),
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
        SnackBar(
          content: Text(AppSettings.text(context, 'Vui lòng chọn thời gian trong tương lai.', 'Choose a time in the future.')),
        ),
      );
      return;
    }

    setState(() => _pickupTime = selected);
  }

  Future<void> _submitOrder() async {
    if (_loading || _submitting || _loadError != null || _services.isEmpty) return;
    if (!_formKey.currentState!.validate()) return;

    final items = <Map<String, dynamic>>[];
    for (final service in _services) {
      final quantity = _quantities[service.id] ?? 0;
      if (quantity > 0) {
        items.add({'service_id': service.id, 'quantity': quantity});
      }
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppSettings.text(context, 'Vui lòng chọn ít nhất 1 dịch vụ giặt ủi.', 'Select at least one laundry service.')),
        ),
      );
      return;
    }

    if (_pickupTime == null || !_pickupTime!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppSettings.text(context, 'Vui lòng chọn thời gian lấy đồ.', 'Select a pickup time.'))),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      if (_paymentMethod == 'momo') {
        await MomoPaymentService.request('configuration');
      }
      // Build structured order note with shipping, payment & voucher details
      final speedLabel = _deliveryType == 'express' ? 'HỎA TỐC 4H' : 'TIÊU CHUẨN';
      final payLabel = _paymentMethod == 'cod' ? 'TIỀN MẶT KHI NHẬN (COD)' : 'MOMO SANDBOX';
      final voucherLabel = _appliedVoucher != null ? ' | Voucher: $_appliedVoucher (-${_formatMoney(_discountAmount)}đ)' : '';
      final customNote = _noteController.text.trim();
      final fullNote = '[$speedLabel] [$payLabel]$voucherLabel${customNote.isNotEmpty ? ' | Ghi chú: $customNote' : ''}';

      final createdOrder = await supabase.rpc(
        'create_order_v2',
        params: {
          'p_customer_name': _nameController.text.trim(),
          'p_phone': _phoneController.text.trim(),
          'p_address': _addressController.text.trim(),
          'p_pickup_time': _pickupTime!.toUtc().toIso8601String(),
          'p_note': fullNote,
          'p_items': items,
          'p_delivery_type': _deliveryType,
          'p_payment_method': _paymentMethod,
          'p_voucher_code': _discountAmount > 0 ? _appliedVoucher : null,
        },
      );

      final orderId = (createdOrder['id'] as num).toInt();
      final chargedTotal = (createdOrder['total_price'] as num).toDouble();

      try {
        await _addressStorage?.writeString(
          'saved_address', _addressController.text.trim(),
        );
      } catch (error) {
        debugPrint('Address cache write failed: $error');
      }

      if (!mounted) return;

      if (_paymentMethod == 'momo') {
        final openMomo = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 54),
            title: const Text(
              'Đặt dịch vụ thành công!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mã đơn hàng: #$orderId',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tổng tiền: ${_formatMoney(chargedTotal)} đ',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bạn đã chọn MoMo Sandbox. Mở trang thanh toán để thực hiện giao dịch thử nghiệm.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedColor, fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryBlue, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx, true),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text(
                      'Mở MoMo Sandbox',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Để sau & Theo dõi đơn'),
              ),
            ],
          ),
        );
        if (openMomo == true && mounted) {
          await MomoPaymentDialog.show(
            context: context,
            orderId: orderId,
            amount: chargedTotal,
          );
        }
      } else {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 54),
            title: const Text(
              'Đặt dịch vụ thành công!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mã đơn hàng: #$orderId',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tổng tiền: ${_formatMoney(chargedTotal)} đ',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bạn sẽ thanh toán tiền mặt khi shipper giao đồ sạch.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedColor, fontSize: 13),
                ),
              ],
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: primaryBlue),
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Hoàn tất & Theo dõi'),
              ),
            ],
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đặt đơn: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Có lỗi xảy ra: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageSurface,
      appBar: AppBar(
        title: Text(
          AppSettings.text(context, 'Đặt lịch giặt ủi', 'Schedule laundry'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: OrderCheckoutBar(
        total: '${_formatMoney(_finalTotal)} đ',
        submitting: _submitting,
        enabled: !_loading && _loadError == null && _services.isNotEmpty,
        onSubmit: _submitOrder,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    TextButton(onPressed: _loadData, child: Text(AppSettings.text(context, 'Thử lại', 'Retry'))),
                  ],
                ))
              : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
                  // 1. Service Selection Section
                  SectionTitle(
                    AppSettings.text(context, '1. Chọn dịch vụ giặt ủi', '1. Choose laundry services'),
                    subtitle: AppSettings.text(context, 'Chọn khối lượng hoặc số lượng tương ứng', 'Choose a weight or quantity'),
                  ),
                  if (_services.isEmpty)
                    const Text('Cửa hàng hiện chưa có dịch vụ đang hoạt động.'),
                  ..._buildServicesSelector(),

                  const SizedBox(height: 18),

                  // 2. Delivery Speed Options
                  SectionTitle(AppSettings.text(context, '2. Thời gian hoàn thành mong muốn', '2. Turnaround time')),
                  _buildDeliverySpeedSelector(),

                  const SizedBox(height: 18),

                  // 3. Pickup Schedule Selector
                  SectionTitle(AppSettings.text(context, '3. Lịch hẹn tài xế đến lấy đồ', '3. Pickup appointment')),
                  _buildPickupSchedulePicker(),

                  const SizedBox(height: 18),

                  // 4. Contact & Address Details
                  SectionTitle(AppSettings.text(context, '4. Thông tin người nhận & Địa chỉ', '4. Recipient and address')),
                  _buildCustomerFields(),

                  const SizedBox(height: 18),

                  // 5. Voucher Code Input
                  SectionTitle(AppSettings.text(context, '5. Mã ưu đãi / Voucher', '5. Promo code')),
                  _buildVoucherInput(),

                  const SizedBox(height: 18),

                  // 6. Payment Method Selector
                  SectionTitle(AppSettings.text(context, '6. Phương thức thanh toán', '6. Payment method')),
                  _buildPaymentMethodSelector(),

                  const SizedBox(height: 18),

                  // 7. Order Cost Summary
                  OrderSummaryCard(
                    subtotal: '${_formatMoney(_subtotal)} đ',
                    shippingFee: _shippingFee == 0
                        ? null
                        : '+${_formatMoney(_shippingFee)} đ',
                    discount: _discountAmount > 0
                        ? '-${_formatMoney(_discountAmount)} đ'
                        : null,
                    voucherCode: _appliedVoucher,
                    total: '${_formatMoney(_finalTotal)} đ',
                  ),

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
          color: context.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? context.accentColor : context.cardOutline,
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
                color: isSelected ? context.accentSurface : context.insetSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                service.iconData,
                color: isSelected ? context.accentColor : Colors.blueGrey,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: context.headingColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${service.formattedPrice} đ / ${service.unit}',
                    style: TextStyle(
                      color: context.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: context.insetSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.cardOutline),
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
                        : () => setState(
                            () => _quantities[service.id] = quantity - 1,
                          ),
                    icon: const Icon(Icons.remove),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      quantity % 1 == 0
                          ? quantity.toInt().toString()
                          : quantity.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _quantities[service.id] = quantity + 1),
                    icon: Icon(Icons.add, color: context.accentColor),
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
            title: AppSettings.text(context, 'Tiêu chuẩn', 'Standard'),
            time: AppSettings.text(context, '24 - 48 giờ', '24–48 hours'),
            fee: _subtotal >= 100000 ? AppSettings.text(context, 'Miễn phí', 'Free') : '15.000 đ',
            icon: Icons.local_shipping_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _speedCard(
            type: 'express',
            title: AppSettings.text(context, 'Hỏa tốc', 'Express'),
            time: AppSettings.text(context, '4 - 6 giờ', '4–6 hours'),
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
          color: context.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? context.accentColor : context.cardOutline,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: selected ? context.accentColor : Colors.blueGrey,
                  size: 22,
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? context.accentColor : context.mutedColor,
                  size: 20,
                ),
              ],
            ),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(fontSize: 11, color: context.mutedColor),
            ),
            const SizedBox(height: 6),
            Text(
              fee,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? context.accentColor : context.headingColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupSchedulePicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardOutline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.accentSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_month,
                  color: context.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppSettings.text(context, 'Thời gian shipper đến nhận:', 'Pickup time:'),
                      style: TextStyle(fontSize: 12, color: context.mutedColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _pickupTime == null
                          ? AppSettings.text(context, 'Chưa chọn thời gian', 'Choose a pickup time')
                          : '${_pickupTime!.day.toString().padLeft(2, '0')}/${_pickupTime!.month.toString().padLeft(2, '0')}/${_pickupTime!.year} lúc ${_pickupTime!.hour.toString().padLeft(2, '0')}:${_pickupTime!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: context.headingColor,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.accentColor,
                  side: BorderSide(color: context.accentColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                onPressed: _choosePickupTime,
                child: Text(AppSettings.text(context, 'Thay đổi', 'Change'), style: TextStyle(fontSize: 12)),
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
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardOutline),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: AppSettings.text(context, 'Họ và tên người nhận *', 'Recipient name *'),
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? AppSettings.text(context, 'Nhập họ tên', 'Enter the recipient name') : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: AppSettings.text(context, 'Số điện thoại liên hệ *', 'Phone number *'),
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return AppSettings.text(context, 'Nhập số điện thoại', 'Enter a phone number');
              final clean = v.trim();
              if (!RegExp(r'^(0[1-9][0-9]{8,9})$').hasMatch(clean)) {
                return AppSettings.text(context, 'Số điện thoại 10 số bắt đầu bằng 0', 'Enter a 10-digit phone number starting with 0');
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: AppSettings.text(context, 'Địa chỉ nhận và giao đồ *', 'Pickup and delivery address *'),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? AppSettings.text(context, 'Nhập địa chỉ nhận đồ', 'Enter the pickup address') : null,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: Icon(Icons.bookmark_rounded, size: 14, color: context.accentColor),
              label: Text(
                AppSettings.text(context, 'Chọn từ sổ địa chỉ', 'Choose from address book'),
                style: TextStyle(
                  fontSize: 11,
                  color: context.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: context.accentSurface,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: _selectFromAddressBook,
            ),
          ),
          if (_savedAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(Icons.history, size: 14, color: context.accentColor),
                label: Text(
                  'Địa chỉ mặc định: ${_savedAddress.length > 30 ? '${_savedAddress.substring(0, 30)}...' : _savedAddress}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: context.accentSurface,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onPressed: () {
                  setState(() {
                    _addressController.text = _savedAddress;
                  });
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: AppSettings.text(context, 'Ghi chú cho xưởng giặt (nếu có)', 'Notes for the laundry (optional)'),
              hintText: AppSettings.text(context, 'Ví dụ: giặt riêng áo trắng, ủi li phẳng...', 'For example, wash white shirts separately'),
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
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardOutline),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _voucherController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: AppSettings.text(context, 'Nhập mã: WASHCARE20', 'Enter code: WASHCARE20'),
                prefixIcon: Icon(
                  Icons.confirmation_num_outlined,
                  color: context.accentColor,
                ),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _discountAmount > 0
                  ? Colors.green
                  : context.headingColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _checkingVoucher || _submitting ? null : _applyVoucher,
            child: Text(_checkingVoucher ? AppSettings.text(context, 'Đang kiểm tra...', 'Checking…') : _discountAmount > 0 ? AppSettings.text(context, 'Đã áp dụng', 'Applied') : AppSettings.text(context, 'Áp dụng', 'Apply')),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    final options = [
      (
        'cod',
        AppSettings.text(context, 'Tiền mặt khi giao nhận (COD)', 'Cash on delivery (COD)'),
        AppSettings.text(context, 'Thanh toán trực tiếp cho shipper khi nhận đồ sạch', 'Pay the driver when your laundry is delivered'),
        Icons.payments_outlined,
      ),
      (
        'momo',
        'MoMo Sandbox',
        AppSettings.text(context, 'Thanh toán qua cổng thử nghiệm chính thức của MoMo', 'Use the official MoMo test gateway'),
        Icons.account_balance_wallet_outlined,
      ),
    ];

    return Column(
      children: options.map((opt) {
        final selected = _paymentMethod == opt.$1;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: context.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? context.accentColor : context.cardOutline,
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
                      color: selected ? context.accentSurface : context.insetSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      opt.$4,
                      color: selected ? context.accentColor : Colors.blueGrey,
                      size: 22,
                    ),
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
                            color: selected ? context.headingColor : context.detailColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          opt.$3,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? context.accentColor : context.mutedColor,
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
}
