import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/app_settings.dart';
import '../core/profile_cache.dart';
import '../core/supabase_client.dart';
import '../models/models.dart';
import 'admin/admin_hub_page.dart';
import 'saved_addresses_page.dart';
import '../widgets/settings/theme_language_bottom_sheet.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _changingPassword = false;

  ProfileModel? _profile;

  String get _email => supabase.auth.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({bool forceNetwork = false}) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final profile = await ProfileCache.getProfile(forceNetwork: forceNetwork);
      if (!mounted) return;

      if (profile != null) {
        _profile = profile;
        _nameController.text = profile.fullName;
        _phoneController.text = profile.phone ?? '';
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editProfile() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: _nameController.text);
    final phoneController = TextEditingController(text: _phoneController.text);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chỉnh sửa thông tin'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập họ và tên';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!RegExp(r'^(0[1-9][0-9]{8,9})$').hasMatch(value.trim())) {
                        return 'Số điện thoại không hợp lệ (10 chữ số, bắt đầu bằng 0)';
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );

    if (result != true) {
      nameController.dispose();
      phoneController.dispose();
      return;
    }

    setState(() => _saving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Bạn chưa đăng nhập.');

      final name = nameController.text.trim();
      final phone = phoneController.text.trim();

      await supabase
          .from('profiles')
          .update({'full_name': name, 'phone': phone.isEmpty ? null : phone})
          .eq('id', user.id)
          .select('id')
          .single();

      if (!mounted) return;

      setState(() {
        _nameController.text = name;
        _phoneController.text = phone;
        _profile = _profile != null
            ? _profile!.copyWith(
                fullName: name,
                phone: phone.isEmpty ? null : phone,
              )
            : ProfileModel(
                id: user.id,
                fullName: name,
                phone: phone.isEmpty ? null : phone,
              );
        _saving = false;
      });

      if (_profile != null) {
        ProfileCache.updateCache(_profile!);
      }

      _showMessage('Cập nhật thông tin thành công!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Không thể cập nhật thông tin: $e');
    } finally {
      nameController.dispose();
      phoneController.dispose();
    }
  }

  Future<void> _changePassword() async {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    bool obscurePassword = true;
    bool obscureConfirm = true;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setDialogState(
                          () => obscurePassword = !obscurePassword,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Mật khẩu cần ít nhất 6 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setDialogState(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value != passwordController.text) {
                        return 'Mật khẩu xác nhận không khớp';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'cancel'),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, 'submit');
                }
              },
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );

    if (result != 'submit') {
      passwordController.dispose();
      confirmController.dispose();
      return;
    }

    setState(() => _changingPassword = true);

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: passwordController.text),
      );

      if (!mounted) return;

      setState(() => _changingPassword = false);
      _showMessage('Đổi mật khẩu thành công!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _changingPassword = false);
      _showMessage('Không thể đổi mật khẩu: $e');
    } finally {
      passwordController.dispose();
      confirmController.dispose();
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ProfileCache.clear();
      await supabase.auth.signOut();
    } catch (e) {
      _showMessage('Không thể đăng xuất: $e');
    }
  }

  Future<void> _callHotline() async {
    final uri = Uri.parse('tel:19001234');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showMessage('Không thể mở ứng dụng gọi điện');
      }
    } catch (_) {
      _showMessage('Không thể mở ứng dụng gọi điện');
    }
  }

  void _showSupportDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.support_agent,
                    color: primaryBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hỗ trợ khách hàng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    Text(
                      'WashCare luôn sẵn sàng lắng nghe bạn',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4ECF5)),
              ),
              child: Column(
                children: [
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.access_time_filled, color: primaryBlue, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Thời gian hỗ trợ: 08:00 - 21:00\n(Tất cả các ngày trong tuần)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: darkBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Hotline: 1900 1234',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                          _callHotline();
                        },
                        icon: const Icon(Icons.call, size: 16),
                        label: const Text('Gọi ngay'),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.email_outlined, color: primaryBlue, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Email: hotro@washcare.vn',
                        style: TextStyle(fontSize: 14, color: darkBlue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Câu hỏi thường gặp',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 8),
            _buildFaqItem(
              'Thời gian giặt sấy mất bao lâu?',
              'Thông thường từ 3 - 6 tiếng đối với dịch vụ giặt sấy thông thường, cam kết giao hàng trong ngày.',
            ),
            _buildFaqItem(
              'Phí giao nhận được tính như thế nào?',
              'Miễn phí vận chuyển 2 chiều cho đơn hàng từ 100.000đ trong bán kính 5km.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: darkBlue,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_laundry_service, color: primaryBlue),
            ),
            const SizedBox(width: 12),
            const Text(
              'Về WashCare',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WashCare - Ứng dụng giặt ủi thông minh',
              style: TextStyle(fontWeight: FontWeight.w600, color: darkBlue),
            ),
            const SizedBox(height: 6),
            const Text(
              'Phiên bản: 1.0.0\nNhóm thực hiện: Nhóm 7\nDự án: Lập trình Thiết bị Di động',
              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Giải pháp tiện lợi, giao nhận tận nơi, bảo vệ và chăm sóc từng bộ trang phục của bạn.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }


  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Chưa cập nhật' : value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
    bool loading = false,
  }) {
    final color = danger ? Colors.redAccent : primaryBlue;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(13),
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: danger
              ? Colors.redAccent
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: loading ? null : onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(
          AppSettings.text(context, 'Tài khoản', 'Account'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadProfile(forceNetwork: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primaryBlue, Color(0xFF55A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nameController.text.isEmpty
                                    ? 'Khách hàng'
                                    : _nameController.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _email,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _profile?.roleDisplayName ?? 'Khách hàng',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_profile?.role.toLowerCase() == 'admin' ||
                      _profile?.role.toLowerCase() == 'staff') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF17365D), Color(0xFF2878D0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF17365D).withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.amber,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trung tâm Quản trị',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Duyệt đơn, chuyển trạng thái & gọi khách',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: const Color(0xFF17365D),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminHubPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Truy cập',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Color(0xFFE4ECF5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Thông tin cá nhân',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: darkBlue,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _saving ? null : _editProfile,
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Sửa'),
                              ),
                            ],
                          ),
                          const Divider(),
                          _infoTile(
                            icon: Icons.person_outline,
                            title: 'Họ và tên',
                            value: _nameController.text,
                          ),
                          _infoTile(
                            icon: Icons.email_outlined,
                            title: 'Email',
                            value: _email,
                          ),
                          _infoTile(
                            icon: Icons.phone_outlined,
                            title: 'Số điện thoại',
                            value: _phoneController.text,
                          ),
                          _infoTile(
                            icon: Icons.calendar_month_outlined,
                            title: 'Ngày tạo tài khoản',
                            value: _profile?.formattedCreatedAt ??
                                'Chưa có thông tin',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Color(0xFFE4ECF5)),
                    ),
                    child: Column(
                      children: [
                        _actionTile(
                          icon: Icons.location_on_outlined,
                          title: 'Sổ địa chỉ đã lưu',
                          subtitle: 'Quản lý địa chỉ giao nhận đồ',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SavedAddressesPage(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 74),
                        _actionTile(
                          icon: Icons.palette_outlined,
                          title: AppSettings.text(
                            context, 'Giao diện & Ngôn ngữ', 'Theme & language',
                          ),
                          subtitle: AppSettings.text(
                            context, 'Chế độ Sáng/Tối và Tiếng Việt/English',
                            'Light/Dark mode and Vietnamese/English',
                          ),
                          onTap: () => ThemeLanguageBottomSheet.show(context),
                        ),
                        const Divider(height: 1, indent: 74),
                        _actionTile(
                          icon: Icons.support_agent_outlined,
                          title: 'Trung tâm hỗ trợ',
                          subtitle: 'Hotline 08:00 - 21:00 & Giải đáp thắc mắc',
                          onTap: _showSupportDialog,
                        ),
                        const Divider(height: 1, indent: 74),
                        _actionTile(
                          icon: Icons.info_outline,
                          title: 'Về WashCare',
                          subtitle: 'Phiên bản 1.0.0 & Nhóm phát triển',
                          onTap: _showAboutDialog,
                        ),
                        const Divider(height: 1, indent: 74),
                        _actionTile(
                          icon: Icons.lock_outline,
                          title: 'Đổi mật khẩu',
                          subtitle: 'Cập nhật mật khẩu đăng nhập',
                          loading: _changingPassword,
                          onTap: _changePassword,
                        ),
                        const Divider(height: 1, indent: 74),
                        _actionTile(
                          icon: Icons.logout,
                          title: 'Đăng xuất',
                          subtitle: 'Đăng xuất khỏi tài khoản WashCare',
                          danger: true,
                          onTap: _signOut,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'WashCare • Chăm sóc quần áo của bạn',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
