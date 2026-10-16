class OrderItemModel {
  final int? id;
  final int? orderId;
  final int? serviceId;
  final double quantity;
  final double subtotal;
  final String serviceName;
  final String serviceUnit;

  const OrderItemModel({
    this.id,
    this.orderId,
    this.serviceId,
    required this.quantity,
    this.subtotal = 0.0,
    required this.serviceName,
    required this.serviceUnit,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    String name = 'Dịch vụ';
    String unit = '';

    final servicesData = json['services'];
    if (servicesData is Map) {
      name = servicesData['name']?.toString() ?? 'Dịch vụ';
      unit = servicesData['unit']?.toString() ?? '';
    }

    return OrderItemModel(
      id: (json['id'] as num?)?.toInt(),
      orderId: (json['order_id'] as num?)?.toInt(),
      serviceId: (json['service_id'] as num?)?.toInt(),
      quantity: double.tryParse(json['quantity']?.toString() ?? '') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '') ?? 0.0,
      serviceName: name,
      serviceUnit: unit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (serviceId != null) 'service_id': serviceId,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  String get formattedQuantity {
    return quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
  }

  String get formattedSubtotal {
    return '${subtotal.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    )} đ';
  }
}
