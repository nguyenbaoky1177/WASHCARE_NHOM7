import 'package:flutter/material.dart';

import '../core/address_service.dart';
import '../core/app_colors.dart';
import '../core/app_settings.dart';
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

  String _labelForDisplay(String label) => switch (label) {
    'Nhà riêng' => AppSettings.text(context, label, 'Home'),
    'Văn phòng' => AppSettings.text(context, label, 'Office'),
    'Khác' => AppSettings.text(context, label, 'Other'),
    _ => label,
  };

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
    bool saving = false;

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
                decoration: BoxDecoration(
                  color: context.cardSurface,
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
                              color: context.cardOutline,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          existing == null
                              ? AppSettings.text(context, 'Thêm địa chỉ mới', 'Add address')
                              : AppSettings.text(context, 'Chỉnh sửa địa chỉ', 'Edit address'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.headingColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Chọn loại nhãn: Nhà riêng / Văn phòng / Khác
                        Wrap(
                          spacing: 8,
                          children: ['Nhà riêng', 'Văn phòng', 'Khác'].map((lbl) {
                            final isSelected = selectedLabel == lbl;
                            return Padding(
                              padding: EdgeInsets.zero,
                              child: ChoiceChip(
                                label: Text(_labelForDisplay(lbl)),
                                selected: isSelected,
                                selectedColor: primaryBlue.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: isSelected ? context.accentColor : context.detailColor,
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
                          decoration: InputDecoration(
                            labelText: AppSettings.text(context, 'Địa chỉ chi tiết *', 'Street address *'),
                            hintText: AppSettings.text(context, 'Số nhà, ngõ, tên đường, phường/xã, quận/huyện', 'House number, street, ward and district'),
                            prefixIcon: Icon(Icons.pin_drop_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return AppSettings.text(context, 'Vui lòng nhập địa chỉ nhận/giao đồ', 'Enter a pickup and delivery address');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: AppSettings.text(context, 'Tên người nhận (tùy chọn)', 'Recipient name (optional)'),
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: AppSettings.text(context, 'Số điện thoại (tùy chọn)', 'Phone number (optional)'),
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            AppSettings.text(context, 'Đặt làm địa chỉ mặc định', 'Set as default address'),
                            style: TextStyle(fontSize: 14),
                          ),
                          value: isDefault,
                          activeThumbColor: primaryBlue,
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
                              backgroundColor: primaryBlue, foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: saving ? null : () async {
                              if (formKey.currentState!.validate()) {
                                setModalState(() => saving = true);
                                final newAddress = AddressModel(
                                  id: existing?.id ??
                                      'addr_${DateTime.now().millisecondsSinceEpoch}',
                                  label: selectedLabel,
                                  recipientName: nameController.text.trim(),
                                  phoneNumber: phoneController.text.trim(),
                                  fullAddress: addressController.text.trim(),
                                  isDefault: isDefault,
                                );
                                try {
                                  await AddressService.saveAddress(newAddress);
                                  if (context.mounted) {
                                    Navigator.pop(context, true);
                                  }
                                } catch (error) {
                                  debugPrint('Save address failed: $error');
                                  if (!context.mounted) return;
                                  setModalState(() => saving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(AppSettings.text(context, 'Không lưu được địa chỉ. Vui lòng thử lại.', 'Could not save the address. Please try again.')),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              existing == null
                                  ? AppSettings.text(context, 'Lưu địa chỉ', 'Save address')
                                  : AppSettings.text(context, 'Cập nhật thay đổi', 'Save changes'),
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

    if (saved == true && mounted) {
      _loadAddresses();
    }
  }

  Future<void> _deleteAddress(AddressModel address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppSettings.text(context, 'Xác nhận xóa', 'Delete address?')),
        content: Text('Bạn có chắc muốn xóa địa chỉ "${address.fullAddress}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppSettings.text(context, 'Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppSettings.text(context, 'Xóa', 'Delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AddressService.deleteAddress(address.id);
      _loadAddresses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppSettings.text(context, 'Đã xóa địa chỉ', 'Address deleted'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageSurface,
      appBar: AppBar(
        title: Text(
          widget.isSelectMode ? AppSettings.text(context, 'Chọn địa chỉ nhận đồ', 'Select a pickup address') : AppSettings.text(context, 'Sổ địa chỉ', 'Address book'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: darkBlue,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(AppSettings.text(context, 'Thêm địa chỉ mới', 'Add address')),
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
                    child: Icon(
                      Icons.location_off_outlined,
                      size: 56,
                      color: context.accentColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppSettings.text(context, 'Chưa có địa chỉ nào được lưu', 'No saved addresses'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.headingColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppSettings.text(context, 'Lưu địa chỉ giúp bạn đặt dịch vụ nhanh chóng hơn', 'Save an address for faster booking'),
                    style: TextStyle(fontSize: 13, color: context.mutedColor),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: primaryBlue),
                    onPressed: () => _openAddressForm(),
                    icon: const Icon(Icons.add),
                    label: Text(AppSettings.text(context, 'Thêm địa chỉ ngay', 'Add an address')),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: addresses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = addresses[index];
              return Card(
                elevation: 1,
                color: context.cardSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: item.isDefault
                        ? primaryBlue
                        : context.cardOutline,
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
                                color: context.accentColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _labelForDisplay(item.label),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.headingColor,
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
                                child: Text(
                                  AppSettings.text(context, 'Mặc định', 'Default'),
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
                                  PopupMenuItem(
                                    value: 'default',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 18),
                                        SizedBox(width: 8),
                                        Text(AppSettings.text(context, 'Đặt làm mặc định', 'Set as default')),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text(AppSettings.text(context, 'Chỉnh sửa', 'Edit')),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                      SizedBox(width: 8),
                                      Text(AppSettings.text(context, 'Xóa', 'Delete'), style: TextStyle(color: Colors.red)),
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: context.detailColor,
                            height: 1.3,
                          ),
                        ),
                        if (item.recipientName.isNotEmpty ||
                            item.phoneNumber.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 16,
                                color: context.mutedColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.recipientName.isNotEmpty
                                    ? item.recipientName
                                    : AppSettings.text(context, 'Không có tên', 'No recipient name'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.mutedColor,
                                ),
                              ),
                              if (item.phoneNumber.isNotEmpty) ...[
                                Text(
                                  ' • ',
                                  style: TextStyle(color: context.mutedColor),
                                ),
                                Text(
                                  item.phoneNumber,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.mutedColor,
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
                              label: Text(AppSettings.text(context, 'Giao đến địa chỉ này', 'Use this address')),
                              style: TextButton.styleFrom(
                                foregroundColor: context.accentColor,
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
