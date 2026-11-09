class AddressModel {
  final String id;
  final String label; // 'Nhà riêng', 'Văn phòng', 'Khác'
  final String recipientName;
  final String phoneNumber;
  final String fullAddress;
  final bool isDefault;

  const AddressModel({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phoneNumber,
    required this.fullAddress,
    this.isDefault = false,
  });

  AddressModel copyWith({
    String? id,
    String? label,
    String? recipientName,
    String? phoneNumber,
    String? fullAddress,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullAddress: fullAddress ?? this.fullAddress,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Nhà riêng',
      recipientName: json['recipient_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      fullAddress: json['full_address']?.toString() ?? '',
      isDefault: json['is_default'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'recipient_name': recipientName,
      'phone_number': phoneNumber,
      'full_address': fullAddress,
      'is_default': isDefault,
    };
  }
}
