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

  test('assignOwner creates assign history', () async {
    // Setup
    final lotId = 'lot1';
    await instance.collection('lots').doc(lotId).set({
      'phase': '1', 'block': '1', 'lotNumber': '1', 'status': 'vacant',
    });
    await instance.collection('users').doc('user1').set({'name': 'John'});

    // Action
    await service.assignOwner(lotId: lotId, uid: 'user1', ownerName: 'John', updatedBy: 'admin');

    // Verify
    final historySnap = await instance.collection('lot_ownership_history').get();
    expect(historySnap.docs.length, 1);
    final history = historySnap.docs.first.data();
    expect(history['type'], 'assign');
    expect(history['currentOwnerUid'], 'user1');
  });

  test('assignOwner creates transfer history on reassignment', () async {
    // Setup
    final lotId = 'lot1';
    await instance.collection('lots').doc(lotId).set({
      'phase': '1', 'block': '1', 'lotNumber': '1', 'status': 'occupied',
      'uid': 'user1', 'ownerName': 'John',
    });
    await instance.collection('users').doc('user1').set({'name': 'John'});
    await instance.collection('users').doc('user2').set({'name': 'Jane'});

    // Action
    await service.assignOwner(lotId: lotId, uid: 'user2', ownerName: 'Jane', updatedBy: 'admin');

    // Verify
    final historySnap = await instance.collection('lot_ownership_history').get();
    expect(historySnap.docs.length, 1);
    final history = historySnap.docs.first.data();
    expect(history['type'], 'transfer');
    expect(history['previousOwnerUid'], 'user1');
    expect(history['currentOwnerUid'], 'user2');
  });

  test('unassignOwner records unassign history', () async {
    // Setup
    final lotId = 'lot1';
    await instance.collection('lots').doc(lotId).set({
      'phase': '1', 'block': '1', 'lotNumber': '1', 'status': 'occupied',
      'uid': 'user1', 'ownerName': 'John',
    });
    await instance.collection('users').doc('user1').set({'name': 'John'});

    // Action
    await service.unassignOwner(lotId: lotId, updatedBy: 'admin');

    // Verify
    final historySnap = await instance.collection('lot_ownership_history').get();
    expect(historySnap.docs.length, 1);
    final history = historySnap.docs.first.data();
    expect(history['type'], 'unassign');
    expect(history['previousOwnerUid'], 'user1');
  });
}
