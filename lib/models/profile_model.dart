class ProfileModel {
  final String id;
  final String fullName;
  final String? phone;
  final String role;
  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    required this.fullName,
    this.phone,
    this.role = 'customer',
    this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'customer',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'role': role,
    };
  }

  ProfileModel copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? role,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get roleDisplayName => roleLabel();

  String roleLabel({bool english = false}) => switch (role.toLowerCase()) {
    'admin' => english ? 'Administrator' : 'Quản trị viên',
    'staff' => english ? 'Staff' : 'Nhân viên',
    _ => english ? 'Customer' : 'Khách hàng',
  };

  String displayName({bool english = false}) {
    final name = fullName.trim();
    return name.isEmpty ? roleLabel(english: english) : name;
  }

  String get formattedCreatedAt {
    if (createdAt == null) return 'Chưa có thông tin';
    final d = createdAt!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
