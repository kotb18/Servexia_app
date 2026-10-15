import 'package:cloud_firestore/cloud_firestore.dart';

class PlanModel {
  final String id;
  final String name;
  final int maxGroups;
  final int maxInventoryItems;
  final int maxInvoicesPerMonth;
  final int maxAssets;
  final int maxMembers;
  final int order;
  final bool isActive;
  final String monthlyProductId;
  final String yearlyProductId;

  const PlanModel({
    required this.id,
    required this.name,
    required this.maxGroups,
    required this.maxInventoryItems,
    required this.maxInvoicesPerMonth,
    required this.maxAssets,
    required this.maxMembers,
    this.order = 0,
    this.isActive = true,
    required this.monthlyProductId,
    required this.yearlyProductId,
  });

  factory PlanModel.fromFirestore(DocumentSnapshot<Object?> doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return PlanModel(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      maxGroups: _toInt(data['maxGroups']),
      maxInventoryItems: _toInt(data['maxInventoryItems']),
      maxInvoicesPerMonth: _toInt(data['maxInvoicesPerMonth']),
      maxAssets: _toInt(data['maxAssets']),
      maxMembers: _toInt(data['maxMembers']),
      order: _toInt(data['order']),
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
      monthlyProductId: data['monthlyProductId']?.toString() ?? '',
      yearlyProductId: data['yearlyProductId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'maxGroups': maxGroups,
      'maxInventoryItems': maxInventoryItems,
      'maxInvoicesPerMonth': maxInvoicesPerMonth,
      'maxAssets': maxAssets,
      'maxMembers': maxMembers,
      'order': order,
      'isActive': isActive,
      'monthlyProductId': monthlyProductId,
      'yearlyProductId': yearlyProductId,
    };
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static const List<PlanModel> defaultPlans = [
    PlanModel(
      id: 'basic',
      name: 'الأساسي',
      maxGroups: 5,
      maxInventoryItems: 500,
      maxInvoicesPerMonth: 1000,
      maxAssets: 50,
      maxMembers: 3,
      order: 1,
      monthlyProductId: 'basic_monthly',
      yearlyProductId: 'basic_yearly',
    ),
    PlanModel(
      id: 'pro',
      name: 'الاحترافي',
      maxGroups: 25,
      maxInventoryItems: 5000,
      maxInvoicesPerMonth: 10000,
      maxAssets: 500,
      maxMembers: 15,
      order: 2,
      monthlyProductId: 'pro_monthly',
      yearlyProductId: 'pro_yearly',
    ),
    PlanModel(
      id: 'enterprise',
      name: 'الشركات',
      maxGroups: -1,
      maxInventoryItems: -1,
      maxInvoicesPerMonth: -1,
      maxAssets: -1,
      maxMembers: -1,
      order: 3,
      monthlyProductId: 'enterprise_monthly',
      yearlyProductId: 'enterprise_yearly',
    ),
  ];
}
