import '../../core/request_timeout.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/supabase_client.dart';
import '../../models/models.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late Future<List<ProfileModel>> _usersFuture;
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ProfileModel>> _loadUsers() async {
    final response = await supabase
        .from('profiles')
        .select()
        .order('created_at', ascending: false)
        .timeout(supabaseRequestTimeout);

    return (response as List)
        .whereType<Map<String, dynamic>>()
        .map((json) => ProfileModel.fromJson(json))
        .toList();
  }

  Future<void> _refresh() async {
    final future = _loadUsers();
    setState(() {
      _usersFuture = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  List<ProfileModel> _filterUsers(List<ProfileModel> users) {
    return users.where((u) {
      // Filter by role
      if (_selectedRoleFilter != 'all' && u.role.toLowerCase() != _selectedRoleFilter) {
        return false;
      }
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatches = u.fullName.toLowerCase().contains(q);
        final phoneMatches = (u.phone ?? '').toLowerCase().contains(q);
        final idMatches = u.id.toLowerCase().contains(q);
        return nameMatches || phoneMatches || idMatches;
      }
      return true;
    }).toList();
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.deepOrange;
      case 'staff':
        return Colors.indigo;
      case 'customer':
      default:
        return const Color(0xFF16845B);
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'staff':
        return Icons.badge_rounded;
      case 'customer':
      default:
        return Icons.person_rounded;
    }
  }

  Future<void> _changeUserRole(ProfileModel user) async {
    String selectedRole = user.role.toLowerCase();
    final currentUserId = supabase.auth.currentUser?.id;

    final newRole = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primaryBlue.withAlpha(25),
                    child: const Icon(
                      Icons.manage_accounts_rounded,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Phân quyền tài khoản',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName.isNotEmpty
                        ? user.fullName
                        : 'Tài khoản #${user.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (user.phone != null && user.phone!.isNotEmpty)
                    Text(
                      'SĐT: ${user.phone}',
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chọn vai trò mới:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ...[
                    (
                      'customer',
                      'Khách hàng (Customer)',
                      'Đặt đơn, theo dõi trạng thái, đánh giá',
                      Icons.person_rounded,
                      const Color(0xFF16845B),
                    ),
                    (
                      'admin',
                      'Quản trị viên (Admin)',
                      'Toàn quyền quản trị đơn, giá & tài khoản',
                      Icons.admin_panel_settings_rounded,
                      Colors.deepOrange,
                    ),
                  ].map((item) {
                    final isSelected = selectedRole == item.$1;
                    final roleAccent = context.isDarkTheme
                        ? Color.lerp(item.$5, Colors.white, 0.45)!
                        : item.$5;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedRole = item.$1),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? roleAccent.withAlpha(20)
                              : context.insetSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? roleAccent : context.cardOutline,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(item.$4, color: roleAccent, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.$2,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isSelected ? roleAccent : context.detailColor,
                                    ),
                                  ),
                                  Text(
                                    item.$3,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                              color: isSelected ? roleAccent : context.mutedColor,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx, selectedRole),
                  child: const Text('Lưu thay đổi'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newRole == null || newRole == user.role.toLowerCase() || !mounted) return;

    if (user.id == currentUserId && newRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tự hạ quyền tài khoản đang đăng nhập.'),
        ),
      );
      return;
    }

    try {
      await supabase.rpc(
        'admin_set_user_role',
        params: {'p_user_id': user.id, 'p_role': newRole},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Đã cập nhật vai trò của ${user.fullName} thành $newRole!',
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật vai trò: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageSurface,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.manage_accounts_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Quản lý Người dùng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
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
      body: FutureBuilder<List<ProfileModel>>(
        future: _usersFuture,
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
                    Text('Lỗi: ${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allUsers = snapshot.data ?? [];
          final filteredUsers = _filterUsers(allUsers);

          final adminCount = allUsers
              .where((u) => u.role.toLowerCase() == 'admin')
              .length;
          final customerCount = allUsers
              .where((u) => u.role.toLowerCase() == 'customer')
              .length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Thống kê nhanh người dùng
                Row(
                  children: [
                    Expanded(
                      child: _statPill(
                        'Tổng số',
                        allUsers.length.toString(),
                        primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statPill(
                        'Khách hàng',
                        customerCount.toString(),
                        const Color(0xFF16845B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statPill(
                        'Quản trị',
                        adminCount.toString(),
                        Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tìm kiếm
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, SĐT hoặc User ID...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search, color: primaryBlue),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: context.cardSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE4ECF5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE4ECF5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: primaryBlue,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
                const SizedBox(height: 12),

                // Bộ lọc vai trò
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _roleChip('Tất cả', 'all', allUsers.length),
                      const SizedBox(width: 8),
                      _roleChip('Khách hàng', 'customer', customerCount),
                      const SizedBox(width: 8),
                      const SizedBox(width: 8),
                      _roleChip('Quản trị viên', 'admin', adminCount),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Danh sách người dùng
                if (filteredUsers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      color: context.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.cardOutline),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 54,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Không tìm thấy người dùng phù hợp',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hãy thử thay đổi từ khóa hoặc bộ lọc vai trò',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredUsers.map((user) {
                    final roleColor = _getRoleColor(user.role);
                    final roleIcon = _getRoleIcon(user.role);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: context.cardSurface,
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE4ECF5)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: roleColor.withAlpha(25),
                                  child: Icon(
                                    roleIcon,
                                    color: roleColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName.isNotEmpty ? user.fullName : 'Chưa đặt tên',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: context.headingColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone_outlined,
                                            size: 13,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            user.phone ?? 'Chưa cập nhật SĐT',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: roleColor.withAlpha(20),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: roleColor.withAlpha(60),
                                    ),
                                  ),
                                  child: Text(
                                    user.roleDisplayName,
                                    style: TextStyle(
                                      color: roleColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 13,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tham gia: ${user.formattedCreatedAt}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryBlue,
                                    side: const BorderSide(color: primaryBlue),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => _changeUserRole(user),
                                  icon: const Icon(
                                    Icons.edit_note_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Phân quyền',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardOutline),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.mutedColor),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String label, String value, int count) {
    final isSelected = _selectedRoleFilter == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: primaryBlue.withAlpha(30),
      checkmarkColor: primaryBlue,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? context.accentColor : context.detailColor,
      ),
      backgroundColor: context.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? primaryBlue : context.cardOutline,
        ),
      ),
      onSelected: (_) {
        setState(() => _selectedRoleFilter = value);
      },
    );
  }
}
