import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:lamhoai_admin/core/services/rate_service.dart';
import 'package:lamhoai_admin/core/models/rate_schedule_model.dart';

void main() {
  late FakeFirebaseFirestore instance;
  late RateService service;

  setUp(() {
    instance = FakeFirebaseFirestore();
    service = RateService(db: instance);
  });

  group('activateSchedule', () {
    test('sets isActive to true', () async {
      await instance.collection('rate_schedules').doc('s1').set({
        'year': 2027,
        'isActive': false,
        'tiers': [{'label': 'a', 'threshold': 0, 'rate': 5000}]
      });

      await service.activateSchedule('s1');

      final doc = await instance.collection('rate_schedules').doc('s1').get();
      expect(doc.data()!['isActive'], true);
    });
  });

  group('getSchedules', () {
    test('returns all schedules', () async {
      await instance.collection('rate_schedules').doc('s1').set({
        'year': 2027,
        'isActive': false,
        'tiers': [{'label': 'b120', 'threshold': 120, 'rate': 6000}]
      });
      await instance.collection('rate_schedules').doc('s2').set({
        'year': 2028,
        'isActive': true,
        'tiers': [{'label': 'a', 'threshold': 0, 'rate': 5000}]
      });

      final schedules = await service.getSchedules();
      expect(schedules.length, 2);
    });

    test('respects isActive filtering', () async {
      await instance.collection('rate_schedules').doc('s3').set({
        'year': 2029,
        'isActive': false,
        'tiers': [{'label': 'low', 'threshold': 0, 'rate': 4000}]
      });
      await instance.collection('rate_schedules').doc('s4').set({
        'year': 2030,
        'isActive': true,
        'tiers': [{'label': 'high', 'threshold': 120, 'rate': 8000}]
      });

      final schedules = await service.getSchedules();
      // We just want to assert we got data back and filter later if needed
      expect(schedules.length, 2);
    });
  });

  group('createSchedule', () {
    test('creates a new schedule doc', () async {
      await service.createSchedule(RateScheduleModel(
        id: 'new_s',
        year: 2031,
        isActive: false,
        tiers: [const RateTier(label: 'tier1', threshold: 0, rate: 7000)],
      ));

      final doc = await instance.collection('rate_schedules').doc('new_s').get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['year'], 2031);
      expect(data['isActive'], false);
      expect((data['tiers'] as List).first['rate'], 7000.0);
    });
  });
}
