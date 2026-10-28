# Ledger System Design Specification
## Membership Fee Tracking via Per-Member Balance Docs

**Date:** 2026-10-26
**Scope:** Replace the aggregate-sum computation for outstanding membership balances with a lean per-member ledger doc (`member_ledgers`) that provides O(1) read of `currentBalance`. The `payments` collection stays untouched — each generated fee record remains a standalone record; the ledger is a derived denormalized snapshot updated lazily on payment.

---

## 1. Problem Statement

Currently, the dashboard and dues screen compute outstanding membership amounts by
reading the entire `payments` collection and filtering by member UID + relevant type.
As the association grows, this becomes expensive and blocks real-time UI updates.

A per-member `member_ledgers` document with a single `currentBalance` field gives us
O(1) reads for the common case (showing how much each member still owes) without
requiring aggregation across the payments collection.

---

## 2. Data Structure

### 2.1 Collection: `member_ledgers`

```
member_ledgers/{uid}
  ├── uid: String          // The member's UID — matches Firestore doc ID
  ├── annualTarget: double  // Total annual membership fee obligation
  ├── currentBalance: double // Remaining unpaid amount
  ├── year: int             // Year the annual fee covers (for annual mode)
  ├── createdAt: Timestamp   // When ledger doc was created
  └── updatedAt: Timestamp    // Last update time
```

**Why these fields:**
- `uid` as document ID — guarantees 1:1 mapping with the member record; no lookup needed.
- `annualTarget` — upper bound; never decreases. Set at generation time, frozen.
- `currentBalance` — the number the dashboard reads. Decreases on every payment.
- `year` — allows filtering by year without scanning all docs.
- Timestamps for audit trail.

No other fields. No `monthlyOwed`, no `ratesApplied` — those live elsewhere or
are recomputed on demand. Keep it minimal.

### 2.2 What Stays in `payments`

No structural change. Each generated fee (annual or monthly) remains a standalone
record with `type: 'membershipFee' | 'monthlyMembership'`. The ledger is purely
derived from these records.

---

## 3. Payment Integration

### 3.1 Generation Flow (unchanged)

When `generateMembershipFees()` or `generateMonthlyMemberships()` runs:
1. For each billable member, write one payment record.
2. Create or update the corresponding `member_ledgers/{uid}` doc with:
   - `annualTarget = amount`
   - `currentBalance = amount`
   - `year = <selected year>`

Members with an existing ledger get `skipped`. Members who had prior fee records
but a zero/missing ledger get the ledger initialized fresh.

### 3.2 Adding a Payment Flow (lazy ledger update)

In `FirestoreService.addPayment()`:

After writing the payment record to `payments/{id}`:
1. Read or create `member_ledgers/{payment.uid}`.
2. Subtract `payment.amount` from `currentBalance`.
3. Write back `currentBalance` and `updatedAt`.

This is a single read + single write per payment. No background listeners, no
scheduled jobs. The moment a payment is recorded, the ledger reflects it.

### 3.3 Marking Paid (unchanged behavior)

Marking a payment as paid does NOT change the ledger balance — the payment was
already recorded and deducted. Marking paid only flips the status to `paid` in
the payments collection. The ledger `currentBalance` already accounts for it.

### 3.4 Canceling a Generated Record

If a generated record is later deleted (cancel), the ledger must be adjusted:
the corresponding ledger's `currentBalance` is increased by the cancelled
amount. This is handled in the delete path of `addPayment()`.

---

## 4. Rate Changes Mid-Year

The current monthly dues system uses `RateHistoryService` to look up the rate
in effect for any given month. The monthly membership fee records use this same
mechanism at generation time — each generated record reflects the rate
applies at the time of generation.

**Ledger is NOT the source for monthly amounts.** Each monthly record carries
its own `amount` reflecting the rate then in effect. The ledger's
`currentBalance` is simply the sum of all outstanding records.

**Annual membership has no rate changes.** The annual fee is set once and
fixed. Records created with that year's fee don't need rate lookup. The
ledger just tracks whether the annual target has been met.

This means rate changes require NO ledger reconciliation logic. Changing the
rate at generation time creates records at the new rate; changing it later
affects only future generations. Old records stay as they were.

---

## 5. Dashboard Integration

Replace the aggregate query in the dashboard's payment section:

**Before:** Stream all `payments` matching `type` ∈ {`membershipFee`, `monthlyMembership`}, group by `uid`, sum amounts where not paid.

**After:** Stream `member_ledgers`, filter by `type == 'membershipFee' || 'monthlyMembership'`, display `currentBalance` directly. No aggregation needed.

Dashboard summary cards become:
| Label | Value |
|-------|-------|
| Total Outstanding | ₱{ledgers sum of currentBalance} |
| Payments Processed | count of ledgers with currentBalance > 0 |
| Years Covered | distinct `year` values |

---

## 6. User Interface Changes

### 6.1 Dashboard Outstanding Section

Change the payment dashboard area from a list-of-payments view to a simple
"Total Outstanding" card reading from the ledger stream. No per-member rows.

### 6.2 Dues Screen

The dues screen continues to use `payments` streams — no change there. The
"Outstanding" summary card on each period section can optionally also display
the member-level ledger, but this is progressive enhancement (not required
for v1).

### 6.3 Add Payment Screen

No change needed. The payment form writes records as before; the lazy
ledger update happens automatically inside `addPayment()`.

---

## 7. Implementation Plan

| Step | File(s) | Action |
|------|---------|--------|
| 1 | `lib/core/services/firestore_service.dart` | Add `streamMemberLedgers()`, `createOrUpdateLedger()` |
| 2 | `lib/core/services/firestore_service.dart` | In `addPayment()`: update ledger after payment record written |
| 3 | `lib/core/services/firestore_service.dart` | In `deletePayment()`: restore ledger balance |
| 4 | `lib/features/payments/screens/dashboard_screen.dart` | Replace aggregate with ledger stream read |
| 5 | Test | Verify ledger updates on payment and deletion |

---

## 8. Constraints & Trade-offs

- **Read latency:** O(1) per member instead of O(records per member). Acceptable for a web app; firestore view strongly favors this pattern.
- **Write path:** One extra read+write per payment. Negligible.
- **No eventual consistency gap:** Ledger is updated synchronously with the payment write. A missed update means a stale balance — caught by manual reconciliation or admin review.
- **Penalty extension:** Overdue penalties applied to monthly membership records follow the existing penalty logic — unaffected by ledger architecture.
