import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:lamhoai_admin/core/services/lot_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore instance;
  late LotService service;

  setUp(() {
    instance = FakeFirebaseFirestore();
    service = LotService(db: instance);
  });

  test('bulkUpdateLotAreas updates valid lots', () async {
    // Setup: Create 2 lots in Firestore
    await instance.collection('lots').add({
      'phase': '1',
      'block': '1',
      'lotNumber': '1',
      'areaSqm': 100.0,
    });
    await instance.collection('lots').add({
      'phase': '1',
      'block': '1',
      'lotNumber': '2',
      'areaSqm': 150.0,
    });

    // Action: Bulk update
    final rows = [
      {'block': '1', 'lotNumber': '1', 'areaSqm': 120.0},
      {'block': '1', 'lotNumber': '2', 'areaSqm': 160.0},
    ];
    await service.bulkUpdateLotAreas('1', rows, 'admin');

    // Verify
    final lots = await instance.collection('lots').get();
    for (var doc in lots.docs) {
      final data = doc.data();
      if (data['block'] == '1' && data['lotNumber'] == '1') {
        expect(data['areaSqm'], 120.0);
      }
      if (data['block'] == '1' && data['lotNumber'] == '2') {
        expect(data['areaSqm'], 160.0);
      }
    }
  });
}
