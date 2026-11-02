# Flow 03–04: Record Sale + Installment Schedule Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans

**Goal:** Enable selling a lot (cash or installment) from the For-Sale lot dialog, auto-generating payment records on sale.

**Architecture:** A new `SaleService` (`core/services/sale_service.dart`) handles all Firestore writes for lot sales. It consumes `AmortizationService` for installment computation. The UI layer (`lot_dialogs.dart`) calls `SaleService.recordSale()` from the For-Sale confirmation step.

**Tech Stack:** Flutter/Dart, Cloud Firestore, `amortization_service.dart`, `transaction_id_service.dart`, `lot_sale_model.dart`, `lot_payment_model.dart`.

**Spec:** `docs/flow-payment-scheme.md` (§03 cash, §04 installment).

## Global Constraints
- Lot must be in `LotStatus.forSale` before selling — enforced at the dialog level.
- Cash: single payment record, `financedAmount=0`, `status='paidOff'` immediately.
- Installment: `monthlyPayment` computed via `AmortizationService`, N periods auto-created with `scheduled` status.
- Don't modify `FirestoreService` — `SaleService` owns the `lot_sales`/`lot_payments` collections.

## Review Focus
- What if no lots exist? → `streamLots()` returns empty; handler shows error.
- What if rate config missing? → falls back to 0; dialog shows price = area × 0.
- Partial payment semantics → deferred; cash = exact, installments = next-period match.
- Recorded by is required for audit trail.

---

### Task 1: Sale Service (write `sale_service.dart`)

**Files:**
- Modify: `web-admin/lib/core/services/sale_service.dart` (append methods)

**Interfaces:**
- Consumes: `LotModel`, `SalesRateModel`, `LotSaleModel`, `LotPaymentModel`, `AmortizationService.monthlyPayment()`, `TransactionIdService.nextTransactionId()`
- Produces: `Future<LotSaleModel>` per sale, `Future<List<LotPaymentModel>>` for schedule

```dart
// SaleService writes to `lot_sales` and `lot_payments` collections.
class SaleService {
  final _db = FirebaseFirestore.instance;
  final _amortization = AmortizationService();
  final _txId = TransactionIdService();

  CollectionReference<Map<String, dynamic>> get _lots  => _db.collection('lot_sales');
  CollectionReference<Map<String, dynamic>> get _payments => _db.collection('lot_payments');

  Future<void> recordSale({
    required LotModel lot,
    required String buyerUid,
    required String buyerName,
    required double downPayment,
    required int termMonths,
    required double annualInterestRate,
    required DateTime soldDate,
    required String recordedBy,
  }) async {
    final totalPrice = lot.price; // from LotModel.areaSqm * rate
    final financedAmount = totalPrice - downPayment;
    final monthlyPayment = termMonths > 0
        ? _amortization.monthlyPayment(financedAmount, annualInterestRate, termMonths)
        : 0.0;

    final seq = await _txId.nextSequenceNumber(soldDate);
    final saleDoc = await _lots.doc().set({...});

    if (termMonths == 0) {
      // Cash: one payment
      await _payments.doc().set({
        'saleId': saleDoc.id, 'lotId': lot.id, 'period': 0,
        'transactionId': 'LP-${soldDate.year}-${seq}-000',
        'amount': totalPrice, 'principalPortion': totalPrice,
        'interestPortion': 0.0, 'remainingBalance': 0.0,
        'status': LotPaymentStatus.paid.name, 'paidAt': Timestamp.now(), 'createdAt': Timestamp.now(),
      });
    } else {
      // Installment: schedule via AmortizationService
      final schedule = _amortization.buildSchedule(
        Principal{original: financedAmount, months: termMonths},
        soldDate,
      );
      for (var i = 0; i < schedule.length; i++) {
        final p = schedule[i];
        await _payments.doc().set({
          'saleId': saleDoc.id, 'lotId': lot.id, 'period': i,
          'transactionId': 'LP-${soldDate.year}-${seq}-${i.toString().padLeft(3, '0')}',
          'dueDate': Timestamp.fromDate(p.dueDate),
          'amount': p.payment, 'principalPortion': p.principal,
          'interestPortion': p.interest, 'remainingBalance': p.remaining,
          'status': LotPaymentStatus.scheduled.name, 'createdAt': Timestamp.now(),
        });
      }
    }

    // Link lot to buyer
    await lot.ref.update({'uid': buyerUid, 'ownerName': buyerName, 'status': 'occupied'});

    // Set sale status
    final sale = LotSaleModel(...status: active);
    await sale.ref.update({'status': 'active', ...});
  }
}
```

- [ ] **Step 1: Write failing test** — unit test `SaleService.recordSale` via mock Firestore; verifies cash = 1 payment doc, installment = N docs, lot updated with uid+ownerName.
- [ ] **Step 2: Run test → FAIL** (service doesn't exist yet).
- [ ] **Step 3: Write minimal `sale_service.dart`** with `recordSale()`, `streamSales()`, `streamPaymentsForSale()`.
- [ ] **Step 4: Run test → PASS.**
- [ ] **Step 5: Commit.**

---

### Task 2: Lot Dialog Sale Recording (modify `lot_dialogs.dart`)

**Files:** Modify `web-admin/lib/features/location/widgets/lot_dialogs.dart`

**Approach:** Add a "Record Sale" panel below the confirmation when the lot is `forSale`. Two mode buttons: "Cash Sale" and "Installment". On selection, show a small form (buyer name field, optional down payment + term + rate for installment). Submit calls `SaleService.recordSale()`.

- [ ] **Step 1: Add `SaleService` field to `ForSaleLotDialog` state** and expose a `_showRecordSaleForm` flag.
- [ ] **Step 2: Build the form UI** — mode toggle (Cash/Installment), dropdown for buyer name, number inputs, submit button.
- [ ] **Step 3: Wire submit** → call `SaleService.recordSale(...)`, pop dialog, refresh.
- [ ] **Step 4: Run `flutter analyze` on modified file.**
- [ ] **Step 5: Commit.**

---

### Task 3: Stream Sales & Payments

**Files:** Modify `sale_service.dart`

- [ ] Add `Stream<List<LotSaleModel>> streamSales()`
- [ ] Add `Stream<List<LotPaymentModel>> streamPaymentsForSale(String saleId)`
- [ ] Add `Future<LotSaleModel?> getSale(String saleId)`
- [ ] Add `Future<List<LotSaleModel>> getAllSalesForLot(String lotId)`
- [ ] Commit.
