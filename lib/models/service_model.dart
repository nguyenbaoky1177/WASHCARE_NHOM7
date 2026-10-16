import 'package:flutter/material.dart';

class ServiceModel {
  final int id;
  final String name;
  final String description;
  final double price;
  final String unit;
  final String? icon;
  final bool isActive;

  const ServiceModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.unit = 'kg',
    this.icon,
    this.isActive = true,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      unit: json['unit']?.toString() ?? 'kg',
      icon: json['icon']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'unit': unit,
      'icon': icon,
      'is_active': isActive,
    };
  }

  String get formattedPrice {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }

  IconData get iconData {
    switch (icon) {
      case 'local_laundry_service':
        return Icons.local_laundry_service;
      case 'iron':
        return Icons.iron;
      case 'dry_cleaning':
        return Icons.dry_cleaning;
      case 'checkroom':
        return Icons.checkroom;
      case 'steps':
        return Icons.directions_walk;
      default:
        return Icons.local_laundry_service;
    }
  }
}
