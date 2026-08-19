import 'package:cloud_firestore/cloud_firestore.dart';

class StoreModel {
  final String id;
  final String groupId; // معرف التاجر في ERP
  final String name;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String primaryColor;
  final String? phone;
  final String? phoneCode;
  final String? whatsapp;
  final String? whatsCode;
  final String? email;
  final String? facebookUrl;
  final String? instagramUrl;
  final bool isActive;
  final String storeSlug; // للرابط المخصص: store-slug.web.app
  final String? customDomain;
  final DateTime createdAt;
  final DateTime updatedAt;
  final StoreSettings settings;
  final bool isClothes; // <-- علم الملابس
  final double shippingFee; // <-- رسوم الشحن

  StoreModel({
    required this.id,
    required this.groupId,
    required this.name,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.primaryColor = '#2196F3',
    this.phone,
    this.whatsapp,
    this.email,
    this.facebookUrl,
    this.instagramUrl,
    this.isActive = true,
    required this.storeSlug,
    this.customDomain,
    required this.createdAt,
    required this.updatedAt,
    required this.settings,
    required this.isClothes,
    required this.shippingFee,
    this.phoneCode,
    this.whatsCode,
  });

  factory StoreModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreModel(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      logoUrl: data['logoUrl'],
      bannerUrl: data['bannerUrl'],
      primaryColor: data['primaryColor'] ?? '#2196F3',
      phone: data['phone'],
      phoneCode: data['phoneCode'],
      whatsapp: data['whatsapp'],
      whatsCode: data['whatsCode'],
      email: data['email'],
      facebookUrl: data['facebookUrl'],
      instagramUrl: data['instagramUrl'],
      isActive: data['isActive'] ?? true,
      storeSlug: data['storeSlug'] ?? '',
      customDomain: data['customDomain'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settings: StoreSettings.fromMap(data['settings'] ?? {}),
      isClothes: data['isClothes'] ?? false,
      shippingFee: (data['shippingFee'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'name': name,
      'description': description,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'primaryColor': primaryColor,
      'phone': phone,
      'phoneCode': phoneCode,
      'whatsapp': whatsapp,
      'whatsCode': whatsCode,
      'email': email,
      'facebookUrl': facebookUrl,
      'instagramUrl': instagramUrl,
      'isActive': isActive,
      'storeSlug': storeSlug,
      'customDomain': customDomain,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'settings': settings.toMap(),
      'isClothes': isClothes,
      'shippingFee': shippingFee,
    };
  }

  String get storeUrl => customDomain ?? 'https://$storeSlug.web.app';
}

class StoreSettings {
  final bool allowGuestCheckout;
  final bool showOutOfStock;
  final double? minOrderAmount;
  final double? freeShippingThreshold;
  final double shippingFee;
  final String currency;
  final String? termsAndConditions;

  StoreSettings({
    this.allowGuestCheckout = true,
    this.showOutOfStock = false,
    this.minOrderAmount,
    this.freeShippingThreshold,
    this.shippingFee = 0,
    this.currency = 'EGP',
    this.termsAndConditions,
  });

  factory StoreSettings.fromMap(Map<String, dynamic> map) {
    return StoreSettings(
      allowGuestCheckout: map['allowGuestCheckout'] ?? true,
      showOutOfStock: map['showOutOfStock'] ?? false,
      minOrderAmount: map['minOrderAmount']?.toDouble(),
      freeShippingThreshold: map['freeShippingThreshold']?.toDouble(),
      shippingFee: (map['shippingFee'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'EGP',
      termsAndConditions: map['termsAndConditions'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'allowGuestCheckout': allowGuestCheckout,
      'showOutOfStock': showOutOfStock,
      'minOrderAmount': minOrderAmount,
      'freeShippingThreshold': freeShippingThreshold,
      'shippingFee': shippingFee,
      'currency': currency,
      'termsAndConditions': termsAndConditions,
    };
  }
}
