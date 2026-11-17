// Pins the `payments` mirror-id contract: BOTH writers (SaleService and
// FirestoreService.recordPaymentWithAllocations) must produce ids that
// markLotPaymentRecordPaid can parse back into saleId + period.
import 'package:flutter_test/flutter_test.dart';
import 'package:lamhoai_admin/core/services/sale_service.dart';

void main() {
  group('lot payments mirror id', () {
    test('canonical id round-trips saleId + period', () {
      const saleId = 'saleAbc123';
      final id = SaleService.mirrorId(saleId, 8);
      expect(id, 'lot_saleAbc123_8');

      // Same parse markLotPaymentRecordPaid performs on the id.
      final body = id.substring(4);
      final cut = body.lastIndexOf('_');
      expect(cut > 0, isTrue);
      expect(int.tryParse(body.substring(cut + 1)), 8);
      expect(body.substring(0, cut), saleId);
    });

    test('saleId containing underscores still parses', () {
      final body = SaleService.mirrorId('sale_a_b', 12).substring(4);
      final cut = body.lastIndexOf('_');
      expect(body.substring(cut + 1), '12');
      expect(body.substring(0, cut), 'sale_a_b');
    });
  });
}
