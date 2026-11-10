import 'package:flutter/material.dart';

import '../core/address_service.dart';
import '../core/app_colors.dart';
import '../models/address_model.dart';

class SavedAddressesPage extends StatefulWidget {
  final bool isSelectMode;

  const SavedAddressesPage({super.key, this.isSelectMode = false});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  late Future<List<AddressModel>> _addressesFuture;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  void _loadAddresses() {
    setState(() {
      _addressesFuture = AddressService.getAddresses();
    });
  }

  IconData _getLabelIcon(String label) {
    switch (label) {
      case 'Nhà riêng':
        return Icons.home_rounded;
      case 'Văn phòng':
        return Icons.business_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  Future<void> _openAddressForm([AddressModel? existing]) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.recipientName);
    final phoneController = TextEditingController(text: existing?.phoneNumber);
    final addressController =
        TextEditingController(text: existing?.fullAddress);
    String selectedLabel = existing?.label ?? 'Nhà riêng';
    bool isDefault = existing?.isDefault ?? false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          existing == null
                              ? 'Thêm địa chỉ mới'
                              : 'Chỉnh sửa địa chỉ',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Chọn loại nhãn: Nhà riêng / Văn phòng / Khác
                        Row(
                          children: ['Nhà riêng', 'Văn phòng', 'Khác'].map((lbl) {
                            final isSelected = selectedLabel == lbl;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(lbl),
                                selected: isSelected,
                                selectedColor: primaryBlue.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: isSelected ? primaryBlue : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                onSelected: (sel) {
                                  if (sel) {
                                    setModalState(() => selectedLabel = lbl);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: addressController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Địa chỉ chi tiết *',
                            hintText: 'Số nhà, ngõ, tên đường, phường/xã, quận/huyện',
                            prefixIcon: Icon(Icons.pin_drop_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập địa chỉ nhận/giao đồ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tên người nhận (tùy chọn)',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại (tùy chọn)',
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Đặt làm địa chỉ mặc định',
                            style: TextStyle(fontSize: 14),
                          ),
                          value: isDefault,
                          activeColor: primaryBlue,
                          onChanged: (val) {
                            setModalState(() => isDefault = val);
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                final newAddress = AddressModel(
                                  id: existing?.id ??
                                      'addr_${DateTime.now().millisecondsSinceEpoch}',
                                  label: selectedLabel,
                                  recipientName: nameController.text.trim(),
                                  phoneNumber: phoneController.text.trim(),
                                  fullAddress: addressController.text.trim(),
                                  isDefault: isDefault,
                                );
                                await AddressService.saveAddress(newAddress);
                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              }
                            },
                            child: Text(
                              existing == null
                                  ? 'Lưu địa chỉ'
                                  : 'Cập nhật thay đổi',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();

    if (saved == true) {
      _loadAddresses();
    }
  }

  Future<void> _deleteAddress(AddressModel address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa địa chỉ "${address.fullAddress}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AddressService.deleteAddress(address.id);
      _loadAddresses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa địa chỉ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(
          widget.isSelectMode ? 'Chọn địa chỉ nhận đồ' : 'Sổ địa chỉ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: darkBlue,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Thêm địa chỉ mới'),
        onPressed: () => _openAddressForm(),
      ),
      body: FutureBuilder<List<AddressModel>>(
        future: _addressesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final addresses = snapshot.data ?? [];

          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_off_outlined,
                      size: 56,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có địa chỉ nào được lưu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Lưu địa chỉ giúp bạn đặt dịch vụ nhanh chóng hơn',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: primaryBlue),
                    onPressed: () => _openAddressForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm địa chỉ ngay'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = addresses[index];
              return Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: item.isDefault
                        ? primaryBlue
                        : const Color(0xFFE5E7EB),
                    width: item.isDefault ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    if (widget.isSelectMode) {
                      Navigator.pop(context, item);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getLabelIcon(item.label),
                                color: primaryBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (item.isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: const Text(
                                  'Mặc định',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.grey),
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  _openAddressForm(item);
                                } else if (val == 'default') {
                                  await AddressService.setDefaultAddress(item.id);
                                  _loadAddresses();
                                } else if (val == 'delete') {
                                  _deleteAddress(item);
                                }
                              },
                              itemBuilder: (ctx) => [
                                if (!item.isDefault)
                                  const PopupMenuItem(
                                    value: 'default',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 18),
                                        SizedBox(width: 8),
                                        Text('Đặt làm mặc định'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Chỉnh sửa'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                      SizedBox(width: 8),
                                      Text('Xóa', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.fullAddress,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                        if (item.recipientName.isNotEmpty ||
                            item.phoneNumber.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.recipientName.isNotEmpty
                                    ? item.recipientName
                                    : 'Không có tên',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              if (item.phoneNumber.isNotEmpty) ...[
                                const Text(
                                  ' • ',
                                  style: TextStyle(color: Colors.black54),
                                ),
                                Text(
                                  item.phoneNumber,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (widget.isSelectMode) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => Navigator.pop(context, item),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Giao đến địa chỉ này'),
                              style: TextButton.styleFrom(
                                foregroundColor: primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
