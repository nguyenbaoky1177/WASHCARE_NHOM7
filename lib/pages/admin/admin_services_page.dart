import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/supabase_client.dart';
import '../../models/models.dart';

class AdminServicesPage extends StatefulWidget {
  const AdminServicesPage({super.key});

  @override
  State<AdminServicesPage> createState() => _AdminServicesPageState();
}

class _AdminServicesPageState extends State<AdminServicesPage> {
  late Future<List<ServiceModel>> _servicesFuture;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _servicesFuture = _loadServices();
  }

  Future<List<ServiceModel>> _loadServices() async {
    // Admin loads ALL services (both active and inactive)
    final result = await supabase
        .from('services')
        .select('id, name, description, price, unit, icon, is_active')
        .order('id');

    return (result as List)
        .whereType<Map<String, dynamic>>()
        .map((item) => ServiceModel.fromJson(item))
        .toList();
  }

  Future<void> _refresh() async {
    final future = _loadServices();
    setState(() {
      _servicesFuture = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _toggleServiceStatus(ServiceModel service, bool newStatus) async {
    setState(() => _actionLoading = true);
    try {
      await supabase
          .from('services')
          .update({'is_active': newStatus})
          .eq('id', service.id);

      _showMessage(newStatus
          ? 'Đã kích hoạt dịch vụ "${service.name}"'
          : 'Đã tạm ngưng dịch vụ "${service.name}"');
      await _refresh();
    } catch (e) {
      _showMessage('Không thể cập nhật trạng thái: $e');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _showEditPriceDialog(ServiceModel service) async {
    final priceController = TextEditingController(
      text: service.price.toInt().toString(),
    );
    final descController = TextEditingController(text: service.description);

    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sửa dịch vụ: ${service.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Đơn giá (đ / ${service.unit})',
                  suffixText: 'đ',
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Vui lòng nhập giá';
                  final numVal = double.tryParse(val.replaceAll('.', ''));
                  if (numVal == null || numVal <= 0) return 'Giá không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mô tả dịch vụ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );

    if (updated != true || !mounted) return;

    final newPrice = double.tryParse(priceController.text.replaceAll('.', '')) ?? service.price;
    final newDesc = descController.text.trim();

    setState(() => _actionLoading = true);
    try {
      await supabase.from('services').update({
        'price': newPrice,
        'description': newDesc,
      }).eq('id', service.id);

      _showMessage('Đã cập nhật dịch vụ "${service.name}"');
      await _refresh();
    } catch (e) {
      _showMessage('Lỗi cập nhật: $e');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _showAddServiceDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final unitController = TextEditingController(text: 'kg');
    final descController = TextEditingController();
    String selectedIcon = 'local_laundry_service';

    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Thêm dịch vụ mới'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên dịch vụ *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nhập tên dịch vụ' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Đơn giá *',
                            suffixText: 'đ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || double.tryParse(v) == null ? 'Giá lỗi' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: unitController,
                          decoration: const InputDecoration(
                            labelText: 'Đơn vị *',
                            hintText: 'kg, cái',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Thiếu đv' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedIcon,
                    decoration: const InputDecoration(
                      labelText: 'Biểu tượng',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'local_laundry_service',
                        child: Row(children: [
                          Icon(Icons.local_laundry_service, color: primaryBlue),
                          SizedBox(width: 8),
                          Text('Giặt sấy thông dụng'),
                        ]),
                      ),
                      DropdownMenuItem(
                        value: 'iron',
                        child: Row(children: [
                          Icon(Icons.iron, color: primaryBlue),
                          SizedBox(width: 8),
                          Text('Ủi / Là phẳng'),
                        ]),
                      ),
                      DropdownMenuItem(
                        value: 'dry_cleaning',
                        child: Row(children: [
                          Icon(Icons.dry_cleaning, color: primaryBlue),
                          SizedBox(width: 8),
                          Text('Giặt khô / Giặt hấp'),
                        ]),
                      ),
                      DropdownMenuItem(
                        value: 'checkroom',
                        child: Row(children: [
                          Icon(Icons.checkroom, color: primaryBlue),
                          SizedBox(width: 8),
                          Text('Chăm sóc trang phục'),
                        ]),
                      ),
                      DropdownMenuItem(
                        value: 'steps',
                        child: Row(children: [
                          Icon(Icons.directions_walk, color: primaryBlue),
                          SizedBox(width: 8),
                          Text('Vệ sinh giày & túi'),
                        ]),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedIcon = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả dịch vụ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Thêm dịch vụ'),
            ),
          ],
        ),
      ),
    );

    if (created != true || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      await supabase.from('services').insert({
        'name': nameController.text.trim(),
        'price': double.parse(priceController.text.trim()),
        'unit': unitController.text.trim(),
        'description': descController.text.trim(),
        'icon': selectedIcon,
        'is_active': true,
      });

      _showMessage('Đã thêm dịch vụ mới thành công!');
      await _refresh();
    } catch (e) {
      _showMessage('Lỗi thêm dịch vụ: $e');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Quản lý Dịch vụ & Giá cước'),
        backgroundColor: darkBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _actionLoading ? null : _showAddServiceDialog,
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm dịch vụ'),
      ),
      body: FutureBuilder<List<ServiceModel>>(
        future: _servicesFuture,
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Lỗi tải danh mục dịch vụ: ${snapshot.error}'),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _refresh, child: const Text('Thử lại')),
                  ],
                ),
              ),
            );
          }

          final services = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final s = services[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Colors.white,
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: s.isActive ? const Color(0xFFE4ECF5) : Colors.red.shade100,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: s.isActive ? paleBlue : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            s.iconData,
                            color: s.isActive ? primaryBlue : Colors.grey,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: s.isActive ? darkBlue : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: s.isActive,
                                    activeThumbColor: primaryBlue,
                                    onChanged: _actionLoading
                                        ? null
                                        : (val) => _toggleServiceStatus(s, val),
                                  ),
                                ],
                              ),
                              if (s.description.isNotEmpty) ...[
                                Text(
                                  s.description,
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${s.formattedPrice} đ / ${s.unit}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: s.isActive ? primaryBlue : Colors.grey,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _showEditPriceDialog(s),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Sửa giá'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
