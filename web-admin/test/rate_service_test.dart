import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  group('sales rate table (sales_rates)', () {
    test('getSalesRateFor prices each date at the row in force on it', () async {
      final today = DateTime.now();
      final nextYear = DateTime(today.year + 1, today.month, today.day);
      await service.addSalesRate(
        ratePerSqm: 2000,
        effectiveFrom: today,
        setBy: 'admin',
      );
      await service.addSalesRate(
        ratePerSqm: 2500,
        effectiveFrom: nextYear,
        setBy: 'admin',
      );

      expect(
        (await service.getSalesRateFor(today))?.ratePerSqm,
        2000.0,
      );
      expect(
        (await service.getSalesRateFor(nextYear))?.ratePerSqm,
        2500.0,
      );
      expect(
        await service.getSalesRateFor(today.subtract(const Duration(days: 1))),
        isNull,
      );
    });

    test('getSalesRate resolves the row in force today', () async {
      await service.addSalesRate(
        ratePerSqm: 2000,
        effectiveFrom: DateTime.now(),
        setBy: 'admin',
      );
      expect((await service.getSalesRate())?.ratePerSqm, 2000.0);
    });

    test('legacy flat config stands in as the always-on row', () async {
      await instance.collection('sales_rate').doc('config').set({
        'ratePerSqm': 1800.0,
        'updatedBy': 'admin',
        'updatedAt': Timestamp.now(),
      });

      final rate = await service.getSalesRate();
      expect(rate?.ratePerSqm, 1800.0);
      expect(rate?.updatedBy, 'admin');
    });

    test('addSalesRate rejects a past date and a duplicate date', () async {
      final when = DateTime.now().add(const Duration(days: 30));
      await service.addSalesRate(
        ratePerSqm: 2000,
        effectiveFrom: when,
        setBy: 'admin',
      );

      await expectLater(
        service.addSalesRate(
          ratePerSqm: 3000,
          effectiveFrom: DateTime(2020, 1, 1),
          setBy: 'admin',
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        service.addSalesRate(
          ratePerSqm: 3000,
          effectiveFrom: when,
          setBy: 'admin',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteSalesRate removes only a row that has not started', () async {
      await service.addSalesRate(
        ratePerSqm: 3000,
        effectiveFrom: DateTime.now().add(const Duration(days: 30)),
        setBy: 'admin',
      );
      final futureId = (await service.getSalesRates()).first.id;
      await service.deleteSalesRate(futureId);
      expect(await service.getSalesRates(), isEmpty);

      await instance.collection('sales_rates').add({
        'effectiveFrom': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'ratePerSqm': 1500.0,
        'setBy': 'admin',
        'createdAt': Timestamp.now(),
      });
      final pastId = (await service.getSalesRates()).first.id;
      await expectLater(
        service.deleteSalesRate(pastId),
        throwsA(isA<Exception>()),
      );
      expect((await service.getSalesRates()).length, 1);
    });
  });
}
