import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

class PlayRegionalPrice {
  const PlayRegionalPrice({
    required this.productId,
    required this.basePlanId,
    required this.period,
    required this.regionCode,
    required this.currencyCode,
    required this.amount,
  });

  final String productId;
  final String basePlanId;
  final String period;
  final String regionCode;
  final String currencyCode;
  final num amount;

  factory PlayRegionalPrice.fromMap(Map<dynamic, dynamic> map) {
    return PlayRegionalPrice(
      productId: map['productId'] as String,
      basePlanId: map['basePlanId'] as String,
      period: map['period'] as String,
      regionCode: map['regionCode'] as String,
      currencyCode: map['currencyCode'] as String,
      amount: map['amount'] as num,
    );
  }

  String format({String locale = 'ar', int decimalDigits = 0}) {
    return NumberFormat.currency(
      locale: locale,
      name: currencyCode,
      decimalDigits: decimalDigits,
    ).format(amount);
  }
}

class PlayRegionalPriceService {
  PlayRegionalPriceService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<PlayRegionalPrice> getPrice({
    required String productId,
    required String period,
  }) async {
    final callable = _functions.httpsCallable('getPlayRegionalPrice');

    final response = await callable.call(<String, Object>{
      'productId': productId,
      'period': period,
    });

    final data = response.data;
    if (data is! Map) {
      throw const FormatException('استجابة السعر من الخادم غير صالحة.');
    }

    return PlayRegionalPrice.fromMap(data);
  }
}
