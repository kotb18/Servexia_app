import 'package:cloud_firestore/cloud_firestore.dart';
import 'plan_model.dart';

class PlanService {
  PlanService({FirebaseFirestore? firestore})
    : _col = (firestore ?? FirebaseFirestore.instance).collection('plans');

  final CollectionReference<Map<String, dynamic>> _col;

  Stream<List<PlanModel>> get plansStream {
    return _col.snapshots().map((snapshot) {
      final plans = snapshot.docs
          .map((doc) => PlanModel.fromFirestore(doc))
          .where((plan) => plan.isActive)
          .toList();

      plans.sort((a, b) => a.order.compareTo(b.order));
      return plans;
    });
  }

  /// لوحة الأدمن: يعرض الباقات النشطة وغير النشطة.
  Stream<List<PlanModel>> get allPlansStream {
    return _col
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => PlanModel.fromFirestore(doc)).toList(),
        );
  }

  Future<List<PlanModel>> getActivePlans() async {
    final snapshot = await _col.get();

    final plans = snapshot.docs
        .map(PlanModel.fromFirestore)
        .where((plan) => plan.isActive)
        .toList();

    plans.sort((a, b) => a.order.compareTo(b.order));
    return plans;
  }

  Future<List<PlanModel>> getActiveIDPlansMonthly(String id) async {
    final snapshot = await _col.get();

    final plans = snapshot.docs
        .map(PlanModel.fromFirestore)
        .where((plan) => plan.isActive && plan.monthlyProductId == id)
        .toList();

    plans.sort((a, b) => a.order.compareTo(b.order));
    return plans;
  }

  Future<List<PlanModel>> getActiveIDPlansYearly(String id) async {
    final snapshot = await _col.get();

    final plans = snapshot.docs
        .map(PlanModel.fromFirestore)
        .where((plan) => plan.isActive && plan.yearlyProductId == id)
        .toList();

    plans.sort((a, b) => a.order.compareTo(b.order));
    return plans;
  }

  /// يحدّث الباقة، ويسمح بتغيير معرّف مستند Firestore.
  ///
  /// عند تغيير المعرّف: ينسخ البيانات إلى المستند الجديد ثم يحذف القديم
  /// ضمن معاملة واحدة. يجب تمرير oldId، وهو معرّف المستند قبل التعديل.
  Future<void> updatePlan(PlanModel plan, {required String oldId}) async {
    final oldRef = _col.doc(oldId);
    final newRef = _col.doc(plan.id);

    if (oldId == plan.id) {
      await oldRef.update(plan.toMap());
      return;
    }

    await _col.firestore.runTransaction<void>((transaction) async {
      // يجب إجراء القراءات قبل الكتابات في معاملة Firestore.
      final oldSnapshot = await transaction.get(oldRef);
      final newSnapshot = await transaction.get(newRef);

      if (!oldSnapshot.exists) {
        throw StateError('لم يتم العثور على الباقة القديمة بالمعرّف: $oldId');
      }

      if (newSnapshot.exists) {
        throw StateError('يوجد بالفعل مستند بالمعرّف الجديد: ${plan.id}');
      }

      transaction.set(newRef, plan.toMap());
      transaction.delete(oldRef);
    });
  }

  Future<void> addPlan(PlanModel plan) {
    return _col.doc(plan.id).set(plan.toMap());
  }

  Future<void> deletePlan(String id) {
    return _col.doc(id).delete();
  }

  Future<void> toggleActive(PlanModel plan) {
    return _col.doc(plan.id).update({'isActive': !plan.isActive});
  }

  Future<void> seedDefaultPlans() async {
    final existing = await _col.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _col.firestore.batch();

    for (final plan in PlanModel.defaultPlans) {
      batch.set(_col.doc(plan.id), plan.toMap());
    }

    await batch.commit();
  }
}
