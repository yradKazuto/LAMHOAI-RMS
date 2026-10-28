# Ledger System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a per-member ledger system to track outstanding membership fee balances in O(1) time.

**Architecture:** A new `member_ledgers` Firestore collection is updated lazily: initialized during fee generation, decremented on payments, and incremented on cancellations. Dashboard reads directly from this collection instead of aggregating payments.

**Tech Stack:** Dart, Flutter, Firebase Firestore.

**Spec:** `docs/superpowers/specs/2026-10-26-ledger-system-design.md`

## Global Constraints

- Dart version compatible with existing codebase.
- Firestore `WriteBatch` operations must be used for bulk generation.
- No background cloud functions; all updates client-side.
- Ledger balance must be consistent with sum of `payments` records.

## Review Focus

- **Payment Cancellation:** Ensure ledger `currentBalance` increases correctly when a payment is deleted.
- **Multiple Generation Runs:** Ledger initialization must be idempotent (skip if already exists).
- **Incomplete Ledger:** What happens if a member has payments but no ledger doc? (Plan: lazy-initialize on next payment).
- **Negative Balance:** Ledger should not allow `currentBalance` to go below 0 (defensive programming).
- **Concurrency:** Ensure payment writes and ledger updates are atomic enough to avoid race conditions (using atomic increments if possible).

---

### Task 1: Add Ledger Service Methods

**Files:**
- Modify: `lib/core/services/firestore_service.dart`

**Interfaces:**
- Consumes: None
- Produces: `streamMemberLedgers()`, `createOrUpdateLedger(uid, target, balance, year)`, `updateLedgerBalance(uid, amountDelta)`

- [ ] **Step 1: Implement `streamMemberLedgers`**

```dart
Stream<List<Map<String, dynamic>>> streamMemberLedgers() {
  return _db.collection('member_ledgers').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
}
```

- [ ] **Step 2: Implement `createOrUpdateLedger`**

```dart
Future<void> createOrUpdateLedger(String uid, double target, double balance, int year) async {
  final docRef = _db.collection('member_ledgers').doc(uid);
  final doc = await docRef.get();
  if (!doc.exists) {
    await docRef.set({
      'uid': uid,
      'annualTarget': target,
      'currentBalance': balance,
      'year': year,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }
}
```

- [ ] **Step 3: Implement `updateLedgerBalance`**

```dart
Future<void> updateLedgerBalance(String uid, double amountDelta) async {
  final docRef = _db.collection('member_ledgers').doc(uid);
  await _db.runTransaction((transaction) async {
    final doc = await transaction.get(docRef);
    if (!doc.exists) return; // Lazy init will handle it later if needed
    final current = doc.data()?['currentBalance'] ?? 0.0;
    transaction.update(docRef, {
      'currentBalance': current + amountDelta, // amountDelta is negative for payment
      'updatedAt': Timestamp.now(),
    });
  });
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/services/firestore_service.dart
git commit -m "feat: add ledger service methods"
```

### Task 2: Integrate Ledger into Add/Delete Payment

**Files:**
- Modify: `lib/core/services/firestore_service.dart`

**Interfaces:**
- Consumes: `updateLedgerBalance`
- Produces: Updated payment workflows

- [ ] **Step 1: Modify `addPayment`**

```dart
// After writing payment record:
if (payment.type == PaymentType.membershipFee || payment.type == PaymentType.monthlyMembership) {
  await updateLedgerBalance(payment.uid, -payment.amount);
}
```

- [ ] **Step 2: Modify `deletePayment` (or cancel logic)**

```dart
// After deleting payment record:
if (payment.type == PaymentType.membershipFee || payment.type == PaymentType.monthlyMembership) {
  await updateLedgerBalance(payment.uid, payment.amount); // Positive delta to restore balance
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/firestore_service.dart
git commit -m "feat: integrate ledger with payment lifecycle"
```

### Task 3: Dashboard Integration

**Files:**
- Modify: `lib/features/dashboard/screens/dashboard_screen.dart`

**Interfaces:**
- Consumes: `streamMemberLedgers()`
- Produces: Ledger-based dashboard UI

- [ ] **Step 1: Add Ledger Stream to Dashboard**

- [ ] **Step 2: Calculate Outstanding from Ledgers**

```dart
// Instead of aggregate payments sum:
final totalOutstanding = ledgers.fold(0.0, (sum, l) => sum + (l['currentBalance'] ?? 0.0));
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/dashboard/screens/dashboard_screen.dart
git commit -m "feat: use ledger for dashboard outstanding"
```
