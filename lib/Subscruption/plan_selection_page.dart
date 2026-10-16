import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:maintenance/Subscruption/plan_model.dart';
import 'package:maintenance/Subscruption/plan_service.dart';
import 'package:maintenance/services/billing_service.dart';
import 'package:maintenance/services/regional_service.dart';

class FirestoreDynamicPlansPage extends StatefulWidget {
  /// مرّر بلد المستخدم من ملفه الشخصي (ISO-3166 مثل EG أو SA).
  /// إذا لم يتم تمريره، تستخدم الصفحة بلد Locale إن كان موجودًا.
  const FirestoreDynamicPlansPage({super.key, this.countryCode});

  final String? countryCode;

  @override
  State<FirestoreDynamicPlansPage> createState() =>
      _FirestoreDynamicPlansPageState();
}

class _FirestoreDynamicPlansPageState extends State<FirestoreDynamicPlansPage> {
  static const Color _primary = Color(0xFF315BEA);
  static const Color _secondary = Color(0xFF7047D8);
  static const Color _pageBackground = Color(0xFFF6F7FB);

  final PlanService _planService = PlanService();
  final PlayRegionalPriceService _regionalPriceService =
      PlayRegionalPriceService();
  final Map<String, Future<PlayRegionalPrice>> _regionalPriceFutures = {};
  late final BillingService _billingService;
  StreamSubscription<List<PlanModel>>? _plansSubscription;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userDocumentSubscription;
  Timer? _renewalExpiryTimer;

  String? _currentSubscriptionProductId;
  DateTime? _currentSubscriptionExpiry;

  List<PlanModel> _plans = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _yearlySelected = false;
  String? _firestoreError;

  @override
  void initState() {
    super.initState();
    _billingService = BillingService();
    if (!kIsWeb) _billingService.addListener(_onBillingChanged);
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _watchUserSubscription,
      onError: (Object error) {
        debugPrint('Auth state listener error: $error');
      },
    );
    _start();
  }

  Future<void> _start() async {
    try {
      if (!kIsWeb) await _billingService.init();
      if (!mounted) return;

      _plansSubscription = _planService.plansStream.listen(
        (plans) {
          if (!mounted) return;
          final sortedPlans = [...plans]
            ..sort((a, b) => a.order.compareTo(b.order));

          setState(() {
            _plans = sortedPlans;
            _loading = false;
            _firestoreError = null;
          });
          if (!kIsWeb) _loadGoogleProducts(sortedPlans);
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _firestoreError =
                'تعذر تحميل الباقات. تحقق من اتصالك ثم حاول مجددًا.';
          });
          debugPrint('Plans stream error: $error');
        },
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _firestoreError = 'حدث خطأ أثناء تشغيل صفحة الاشتراكات.';
      });
      debugPrint('Plans page start error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _loadGoogleProducts(List<PlanModel> plans) async {
    if (kIsWeb) return;
    final ids = <String>{};
    for (final plan in plans) {
      final monthlyId = plan.monthlyProductId.trim();
      final yearlyId = plan.yearlyProductId.trim();
      if (monthlyId.isNotEmpty) ids.add(monthlyId);
      if (yearlyId.isNotEmpty) ids.add(yearlyId);
    }
    if (ids.isEmpty) return;
    try {
      await _billingService.loadProducts(ids);
    } catch (error) {
      debugPrint('Load Google Play products error: $error');
    }
  }

  void _onBillingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _plansSubscription?.cancel();
    _authStateSubscription?.cancel();
    _userDocumentSubscription?.cancel();
    _renewalExpiryTimer?.cancel();
    if (!kIsWeb) {
      _billingService.removeListener(_onBillingChanged);
      _billingService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text(
          'الباقات والاشتراكات',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: _pageBackground,
        foregroundColor: const Color(0xFF20253A),
        actions: [
          IconButton(
            tooltip: 'استعادة المشتريات',
            onPressed: !kIsWeb && _billingService.isAvailable
                ? _restorePurchases
                : null,
            icon: const Icon(Icons.restore_rounded),
          ),
        ],
      ),
      body: _loading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _refresh,
              color: _primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildPeriodSelector(),
                  if (_firestoreError != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorMessage(_firestoreError!),
                  ],
                  if (!kIsWeb && _billingService.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _buildErrorMessage(_billingService.errorMessage!),
                  ],
                  const SizedBox(height: 20),
                  if (_plans.isEmpty)
                    _buildEmptyState()
                  else ...[
                    _buildSectionHeading(),
                    const SizedBox(height: 12),
                    ..._plans.map(_buildPlanCard),
                  ],
                  const SizedBox(height: 10),
                  _buildFooter(),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: _primary.withOpacity(.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: _primary,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 12),
        const Center(child: Text('جاري تحميل الباقات...')),
        const SizedBox(height: 30),
        for (var i = 0; i < 2; i++)
          Container(
            height: 230,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _secondary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'اختر الخطة المناسبة لنشاطك',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'طوّر إدارة أعمالك واستفد من الأدوات والحدود التي تناسبك.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(.88),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EAF1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _periodButton(
              title: 'شهري',
              subtitle: 'دفع شهري',
              selected: !_yearlySelected,
              onTap: () => setState(() => _yearlySelected = false),
            ),
          ),
          Expanded(
            child: _periodButton(
              title: 'سنوي',
              subtitle: 'دفع سنوي',
              selected: _yearlySelected,
              onTap: () => setState(() => _yearlySelected = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodButton({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEEF2FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _primary.withOpacity(.28) : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: selected ? _primary : const Color(0xFF555B6E),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: selected ? _primary.withOpacity(.75) : Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeading() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'خطط الاشتراك',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF20253A),
            ),
          ),
        ),
        if (_refreshing)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildPlanCard(PlanModel plan) {
    final productId = _yearlySelected
        ? plan.yearlyProductId.trim()
        : plan.monthlyProductId.trim();
    final product = productId.isEmpty
        ? null
        : _billingService.productFor(productId);

    // Keep the existing ordering convention: the second plan is highlighted.
    // Change this condition if your Firestore schema has a dedicated featured field.
    final isRecommended = plan.order == 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isRecommended ? _primary : const Color(0xFFE8EAF1),
                width: isRecommended ? 1.7 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isRecommended
                      ? _primary.withOpacity(.10)
                      : Colors.black.withOpacity(.025),
                  blurRadius: isRecommended ? 20 : 12,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.name,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF20253A),
                          ),
                        ),
                      ),
                      _planBadge(plan.order),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: _buildPrice(
                            productId: productId,
                            product: product,
                            period: _yearlySelected ? 'yearly' : 'monthly',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: _primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          _yearlySelected ? 'للسنة' : 'للشهر',
                          style: const TextStyle(
                            color: Color(0xFF777D8D),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        product == null && !kIsWeb
                            ? Icons.info_outline_rounded
                            : Icons.verified_user_outlined,
                        size: 15,
                        color: product == null && !kIsWeb
                            ? Colors.orange.shade800
                            : const Color(0xFF777D8D),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          kIsWeb
                              ? 'سعر إقليمي من Google Play • عرض فقط على الويب'
                              : product == null
                              ? 'السعر غير متاح حاليًا من Google Play'
                              : 'السعر من Google Play • تجديد تلقائي',
                          style: TextStyle(
                            color: product == null && !kIsWeb
                                ? Colors.orange.shade800
                                : const Color(0xFF777D8D),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 17),
                    child: Divider(height: 1, color: Color(0xFFEEF0F4)),
                  ),
                  _limitRow('المجموعات أو الفروع', plan.maxGroups),
                  _limitRow('أصناف المخزون / مجموعة', plan.maxInventoryItems),
                  _limitRow(
                    'الفواتير شهريًا / مجموعة',
                    plan.maxInvoicesPerMonth,
                  ),
                  _limitRow('الأصول / مجموعة', plan.maxAssets),
                  _limitRow('الأعضاء / مجموعة', plan.maxMembers),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSamePlanStillActive(productId)
                          ? null
                          : kIsWeb
                          ? _openPlayStore
                          : product == null ||
                                productId.isEmpty ||
                                _billingService.isPurchasePending
                          ? null
                          : () => _buy(productId, plan.name, _yearlySelected),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: isRecommended
                            ? _primary
                            : const Color(0xFF20253A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE1E3E8),
                        disabledForegroundColor: const Color(0xFF898D98),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        _billingService.isPurchasePending && !kIsWeb
                            ? 'جاري تنفيذ العملية...'
                            : _isRenewalDueFor(productId)
                            ? kIsWeb
                                  ? 'افتح التطبيق لتجديد الاشتراك'
                                  : 'جدّد الاشتراك الآن'
                            : _isSamePlanStillActive(productId)
                            ? 'اشتراكك الحالي فعال'
                            : kIsWeb
                            ? 'تحميل التطبيق وإتمام الاشتراك'
                            : product == null
                            ? 'السعر غير متاح'
                            : 'اشترك في ${plan.name}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isRecommended)
            Positioned(
              top: -12,
              right: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(.20),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  'موصى بها',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _planBadge(int order) {
    final badge = switch (order) {
      1 => ('الخطة الأساسية', const Color(0xFF3975D5)),
      2 => ('الخطة الاحترافية', _secondary),
      3 => ('خطة الأعمال', const Color(0xFF168A78)),
      _ => ('الخطة $order', const Color(0xFF697084)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: badge.$2.withOpacity(.09),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        badge.$1,
        style: TextStyle(
          color: badge.$2,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _limitRow(String label, int value) {
    final valueText = value < 0
        ? 'غير محدود'
        : NumberFormat.decimalPattern('ar').format(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF22A06B),
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF555B6E), fontSize: 13),
            ),
          ),
          Text(
            valueText,
            style: const TextStyle(
              color: Color(0xFF20253A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrice({
    required String productId,
    required ProductDetails? product,
    required String period,
    required TextStyle style,
  }) {
    // Android: اعرض السعر الذي يرجعه Google Play Billing.
    if (!kIsWeb) {
      return Text(_formatPrice(product), style: style);
    }

    if (productId.isEmpty) {
      return Text('السعر غير متاح', style: style);
    }

    // نخزن الطلب حسب المنتج والفترة لتجنب استدعائه مجددًا أثناء إعادة البناء.
    final key = '$productId|$period';

    final future = _regionalPriceFutures.putIfAbsent(key, () async {
      try {
        final price = await _regionalPriceService.getPrice(
          productId: productId,
          period: period,
        );

        debugPrint(
          'البلد: ${price.regionCode}، '
          'السعر: ${price.amount} ${price.currencyCode}',
        );

        return price;
      } catch (error, stackTrace) {
        debugPrint('خطأ جلب سعر Google Play: $error');
        debugPrintStack(stackTrace: stackTrace);
        rethrow;
      }
    });

    return FutureBuilder<PlayRegionalPrice>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            'جاري تحميل السعر...',
            style: style.copyWith(fontSize: 14),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Text('السعر غير متاح', style: style.copyWith(fontSize: 16));
        }

        return Text(
          snapshot.data!.format(locale: 'ar', decimalDigits: 0),
          style: style,
        );
      },
    );
  }

  String _formatPrice(ProductDetails? product) {
    if (product == null) return 'غير متاح';
    try {
      return NumberFormat.currency(
        locale: 'ar',
        name: product.currencyCode,
        decimalDigits: 0,
      ).format(product.rawPrice);
    } catch (error) {
      debugPrint('Price format error: $error');
      return product.price;
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EAF1)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, color: Colors.grey.shade400, size: 42),
          const SizedBox(height: 10),
          const Text(
            'لا توجد باقات نشطة حاليًا',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'اسحب الشاشة للأسفل لإعادة المحاولة.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFDAD4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB42318),
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF912018), fontSize: 12),
            ),
          ),
          TextButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        children: [
          Text(
            kIsWeb
                ? 'الأسعار على الويب إقليمية للعرض فقط. للاشتراك استخدم تطبيق Android.'
                : 'تتم معالجة الاشتراك والدفع عبر Google Play. قد يتجدد الاشتراك تلقائيًا وفق شروط الباقة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: !kIsWeb && _billingService.isAvailable
                ? _restorePurchases
                : null,
            icon: const Icon(Icons.restore_rounded, size: 17),
            label: const Text('استعادة المشتريات'),
          ),
        ],
      ),
    );
  }

  void _watchUserSubscription(User? user) {
    _userDocumentSubscription?.cancel();
    _renewalExpiryTimer?.cancel();

    if (mounted) {
      setState(() {
        _currentSubscriptionProductId = null;
        _currentSubscriptionExpiry = null;
      });
    }

    if (user == null) return;

    _userDocumentSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            final data = snapshot.data();
            final productId = (data?['subscriptionProductId'] ?? '')
                .toString()
                .trim();
            final expiry = _readDateTime(data?['expiredAt']);
            if (!mounted) return;

            setState(() {
              _currentSubscriptionProductId = productId.isEmpty
                  ? null
                  : productId;
              _currentSubscriptionExpiry = expiry;
            });
            _scheduleRenewalExpiryRefresh(expiry);
          },
          onError: (Object error) {
            debugPrint('User subscription listener error: $error');
          },
        );
  }

  DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  void _scheduleRenewalExpiryRefresh(DateTime? expiry) {
    _renewalExpiryTimer?.cancel();
    if (expiry == null) return;

    final remaining = expiry.toLocal().difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) return;

    _renewalExpiryTimer = Timer(remaining + const Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
  }

  bool _isRenewalDueFor(String productId) {
    final expiry = _currentSubscriptionExpiry;
    return productId.isNotEmpty &&
        productId == _currentSubscriptionProductId &&
        expiry != null &&
        !expiry.isAfter(DateTime.now());
  }

  bool _isSamePlanStillActive(String productId) {
    final expiry = _currentSubscriptionExpiry;
    return productId.isNotEmpty &&
        productId == _currentSubscriptionProductId &&
        expiry != null &&
        expiry.isAfter(DateTime.now());
  }

  Future<void> _openPlayStore() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.masry.maintenance',
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح صفحة التطبيق في Google Play.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Open Google Play page error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح صفحة التطبيق في Google Play.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _buy(String productId, String planName, bool isYearly) async {
    try {
      final started = await _billingService.buySubscription(
        productId,
        isYearly,
      );
      if (!mounted || !started) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'بدأت عملية شراء باقة $planName. أكمل الخطوات في Google Play.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر بدء عملية الشراء. حاول مجددًا.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      debugPrint('Purchase start error: $error');
    }
  }

  Future<void> _restorePurchases() async {
    try {
      await _billingService.restorePurchases();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذرت استعادة المشتريات حاليًا.')),
      );
      debugPrint('Restore purchases error: $error');
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final plans = await _planService.getActivePlans();
      final sortedPlans = [...plans]
        ..sort((a, b) => a.order.compareTo(b.order));
      await _loadGoogleProducts(sortedPlans);
      _regionalPriceFutures.clear();
      if (!mounted) return;
      setState(() {
        _plans = sortedPlans;
        _firestoreError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _firestoreError = 'تعذر تحديث الباقات. حاول مرة أخرى.');
      debugPrint('Refresh plans error: $error');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }
}
