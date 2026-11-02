// core/services/rate_service.dart
//
// Manages the sales rate per square metre.
// Collection: `sales_rate`, doc: `config`

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales_rate_model.dart';
import '../models/rate_schedule_model.dart';

class RateService {
  final FirebaseFirestore _db;

  RateService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Future<SalesRateModel?> getSalesRate() async {
    final doc = await _db.collection('sales_rate').doc('config').get();
    if (!doc.exists) return null;
    return SalesRateModel.fromMap(doc.data()!);
  }

  Stream<SalesRateModel?> streamSalesRate() {
    return _db.collection('sales_rate').doc('config').snapshots().map(
      (doc) {
        if (!doc.exists) return null;
        return SalesRateModel.fromMap(doc.data()!);
      },
    );
  }

  Future<void> setSalesRate(double rate, String updatedBy) async {
    await _db.collection('sales_rate').doc('config').set({
      'ratePerSqm': rate,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> activateSchedule(String scheduleId) async {
    await _db.collection('rate_schedules').doc(scheduleId).update({'isActive': true});
  }

  Future<List<RateScheduleModel>> getSchedules() async {
    final snap = await _db.collection('rate_schedules').get();
    return snap.docs
        .map((d) => RateScheduleModel.fromMap(d.id, d.data()))
        .toList();
  }

  Future<void> createSchedule(RateScheduleModel schedule) async {
    await _db.collection('rate_schedules').doc(schedule.id).set(schedule.toMap());
  }
}
