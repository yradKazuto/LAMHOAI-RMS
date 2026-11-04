# Plan: Payment Automation & Automatic Allocation

**Status:** Planning only — do not implement until approved.
**Branch:** `dev` (main is the integration target)

## 0. Confirmed Design Direction (from association)

| # | Decision | Status |
|---|---|---|
| 1 | **Cash** is the only enabled payment method for the current version | Confirmed |
| 2 | Payments are received **in person at the association office** | Confirmed |
| 3 | Authorized staff **manually record** the amount received | Confirmed |
| 4 | Members may pay **multiple outstanding months in one transaction** | Confirmed |
| 5 | Allocation follows **FIFO** (oldest outstanding obligation first) | Confirmed |
| 6 | **Partial payments** must be supported | Confirmed |
| 7 | **Principal is allocated before penalty** within each obligation | Confirmed |
| 8 | **Excess payments** are stored as unapplied member credit (subject to association approval) | Confirmed, pending approval |
| 9 | Receipts are **displayed on-screen** initially | Confirmed |
| 10 | Keep the **existing client-side** overdue status synchronization for the first implementation | Confirmed |
| 11 | The proposed penalty is ₱45 per overdue obligation, applied **once**, stored **separately** from principal, and configurable | Confirmed, pending formal policy approval |

**Payment method scope (current version):** Cash only. GCash and all other online payment functionality are **excluded** from the current development scope — the project's academic paper does not include online transactions. No GCash reference-number capture, no duplicate-reference validation, no online payment APIs, webhooks, gateways, or automatic online verification.

**Future extensibility:** the payment method field and configuration are designed so additional methods can be enabled later without rewriting the FIFO allocation algorithm. See §0.1.

### 0.1 Future payment-method extensibility

Do not permanently hardcode the payment system to cash. The `paymentMethod` field is designed as an extensible enum/config so additional methods (e.g. GCash) can be enabled later through configuration alone — without rewriting the FIFO allocation algorithm.

For the current version:
- `cash` is the only enabled method; it is the only method shown in the payment interface.
- GCash must not appear in the payment interface.
- No GCash reference-number fields, no GCash duplicate-reference validation.

For future versions:
- Additional payment methods may be added through configuration.
- Enabling another method must not require rewriting the FIFO allocation algorithm.
- Future payment methods may require their own verification and validation rules — document each method's rules when added.

---

## 1. Current Payment Implementation Analysis

Collections used:

| Collection | Purpose | Status |
|---|---|---|
| `payments` | One doc per payment obligation (monthly dues, annual membership fee, monthly membership fee, lot payment, penalty, special assessment, other) | EXISTS |
| `member_ledgers` | Per-member `currentBalance` snapshot (O(1) read of outstanding membership balance) | EXISTS |
| `monthly_dues_rates` | Monthly rate history (per-month rate) | EXISTS |
| `lot_sales` / `lot_payments` | Lot installment sales & periods (separate domain, not part of monthly dues) | EXISTS |

`PaymentModel` fields: `id`, `uid`, `memberName`, `type`, `amount`, `status`, `dueDate`, `paidDate`, `recordedBy`, `notes`, `createdAt`, `lotId`, `lotLabel`, `transactionId`, `txnYear`, `txnSeq`.

Existing penalty/ledger logic (`firestore_service.dart`):

- `syncOverdueStatuses()` — flips stored `status` to `overdue` when dueDate < today (client-side trigger in `PaymentsScreen.initState`, not a background job). Requires composite index `(status, dueDate)`.
- `applyOverduePenalties(penaltyAmount, graceDays)` — flat ₱N added once per record; sets `penaltyApplied: true` so duplicate application is prevented. Applies only to `dues` / `membershipFee` / `monthlyMembership` records still `unpaid`/`overdue` past dueDate+graceDays. Amount is added to the record's `amount` field (penalty is **folded into** principal, not stored separately).
- `markPaymentPaid(paymentId)` — sets `status=paid`, `paidDate=now`; reduces `member_ledgers` balance for membership-type payments only. **Clamps annual-fee balance at ≥ 0** (never goes negative).
- `addPayment(payment)` — creates a payment record; ledger adjusted for membership types.
- `deletePayment(paymentId)` — deletes record; ledger restored for membership types.
- Dues generation: `generateMonthlyDues`, `generateMonthlyFeesForMonth`, `generateMembershipFees` — one record per member per period, duplicate-prevention by type+period.

**Ledger semantics (important for allocation design):** `member_ledgers/{uid}` holds `{uid, annualTarget, currentBalance, year, createdAt, updatedAt}` — the outstanding **annual** membership balance only. Monthly dues records do NOT touch the ledger. `generateMembershipFees` initializes it; `markPaymentPaid` reduces it for `monthlyMembership` and `membershipFee` types. **There is no per-lot ledger and no per-obligation balance** — a member's true total outstanding is the sum of their unpaid/overdue `payments` docs, not the ledger.

**Transaction IDs:** `PaymentModel.transactionId` / `txnYear` / `txnSeq` already exist, prefixed per type (`MD`/`MF`/`MM`/`LPAY`/`PEN`/`SA`/`TXN`) via `TransactionIdService`. Already displayed on statements.

**Mobile app shares the same Firestore collections** (`mobile/lib/core/services/firestore_service.dart` reads `member_ledgers.doc(uid)` and `payments`). Any change must stay backward-compatible for the mobile app too.

**Existing planning docs** (not implementation, but directly relevant):
- `docs/flow-payment-scheme.md` already describes reference numbers, duplicate-reference prevention, partial payment as credit/partial, and overdue+penalty opt-in — membership explicitly left unchanged.
- `docs/plan-payment-overhaul.md` — lot-installment scheme with transaction IDs.
- `docs/bugs/2026-10-19-overdue-payment-reminders-not-sent.md` — confirms the pre-penalty amount is **not** retained after `applyOverduePenalties` mutates `amount` (this is a known gap, not an oversight).

Settings (`hoa_settings_model.dart` — `DuesConfig`): `annual`, `specialAssessment`, `penalty` (default ₱50), `penaltyGraceDays` (default 5). History tracked in `dues_config_history`.

### Existing bugs / gaps relative to the requirement

1. **Penalty folded into `amount`** — `applyOverduePenalties` adds the penalty to the record's `amount` and marks `penaltyApplied: true`. The penalty is **not stored separately** from principal, so the association cannot report "principal vs penalty collected" or reverse a penalty without reversing principal. Confirmed as a known gap in `docs/bugs/2026-10-19-overdue-payment-reminders-not-sent.md`.
2. **No allocation concept** — each `payments` doc IS one obligation; there is no `payment_allocations` collection. A single cash payment covering several months cannot be split across obligations.
3. **Per-payment clicking** — every payment must be marked individually via `markPaymentPaid`. Staff complained about "manual" recording.
4. **Reference number not captured** — `PaymentModel` has no `referenceNumber` field; `transactionId` exists but no duplicate-reference check at write time.
5. **Overdue flip is client-side** — only runs when an admin opens Payments; no background job (free Spark tier, no Cloud Functions).
6. **No receipt generation** — no receipt document or printable output exists.
7. **No unapplied credit handling** — overpayment has no defined destination.

Files already inspected (read-only): `payments_screen.dart`, `add_payment_screen.dart`, `sale_service.dart`, `amortization_service.dart`, `statement_content.dart`, `payment_model.dart`, `hoa_settings_model.dart`, `settings_service.dart`, `membership_dues_screen.dart`, `member_detail_screen.dart`, `lot_service.dart`, `notification_service.dart`, `rate_history_service.dart`, `firestore_service.dart` (penalty/ledger sections).

---

## 2. Existing Database Structure

**`payments/{paymentId}`**
- `uid` (member), `memberName`, `type`, `amount`, `status`, `dueDate`, `paidDate`, `recordedBy`, `notes`, `createdAt`, `lotId`, `lotLabel`, `transactionId`, `txnYear`, `txnSeq`, `penaltyApplied` (bool, written by penalty job)

**`member_ledgers/{uid}`**
- `uid`, `currentBalance`, `year`, `createdAt`, `updatedAt`

**`monthly_dues_rates/{doc}`**
- Month → rate mapping (used by `RateHistoryService.getRateForMonth`)

**`settings/hoa_settings`**
- `dues.penalty`, `dues.penaltyGraceDays`, `dues.annual`, `dues.specialAssessment`

No `payment_allocations` collection exists. No receipts collection exists.

---

## 3. Current Payment Flow

```
1. Dues generated (bulk) → one unpaid PaymentModel per member per period
   (membership_dues_screen → FirestoreService.generateMonthlyDues / generateMembershipFees)
2. Overdue status flipped → syncOverdueStatuses() (on PaymentsScreen open)
3. Penalty applied → applyOverduePenalties() (on PaymentsScreen open)
4. Staff opens PaymentsScreen → table of payments, per-row "Mark Paid"
5. Staff clicks "Mark Paid" on a row → FirestoreService.markPaymentPaid(id)
   → sets status=paid, paidDate=now, adjusts ledger balance (membership types only)
6. Member taps name → _MemberPaymentsDialog → per-row Mark Paid
```

Each payment = one click. No batch, no allocation preview, no reference entry.

---

## 4. Proposed Improved Payment Flow

```
1. Staff opens Record Payment screen (new modal on PaymentsScreen)
2. Select member → system loads all outstanding obligations for that member
   (unpaid/overdue dues + membershipFee + monthlyMembership, sorted by dueDate oldest first)
3. Each obligation shows: month, principal, penalty (if applied), total, due date
4. System shows total outstanding balance
5. Staff enters amount received → live FIFO allocation preview (see §5)
6. Staff selects Cash (only method available) → optionally enters a manual reference number
7. Staff clicks Confirm → single Firestore write batch:
   - Create payment doc (amount, method, referenceNumber, receivedBy, paymentDate)
   - Create allocation docs (one per obligation covered)
   - Mark each covered obligation paid
   - Update member_ledgers balance
   - Write audit log entry
8. Receipt generated automatically (on-screen summary; PDF/receipts collection deferred to a later phase)

---

## 5. FIFO Allocation Algorithm

```
input: paymentAmount, obligations sorted by dueDate asc (oldest first)
remaining = paymentAmount
allocations = []
for obligation in obligations:
    if remaining <= 0: break
    owed = obligation.amount (principal + penalty already folded in)
    apply = min(remaining, owed)
    allocations.append({obligationId, principalAmount: min(apply, principalPortion),
                        penaltyAmount: apply - principalAmount, allocatedAmount: apply})
    remaining -= apply
unappliedCredit = remaining  // > 0 means overpayment
```

Rules:
- Oldest outstanding month first; never skip an older unpaid obligation for a newer one.
- Penalty is part of the obligation's `amount` (existing schema). If penalties are later stored separately (§7), principal and penalty are allocated separately within each obligation.
- Overpayment → `unappliedCredit` carried as a credit balance (stored on `member_ledgers` as negative `currentBalance`, or a new `unappliedCredit` field) — **association approval needed** on whether to implement negative balance or reject overpayment.
- Partial payment of an obligation → obligation stays `unpaid` with reduced `amount` (or keep amount and track `paidAmount` separately — decision needed, see §14).

---

## 6. Penalty Calculation Design

**Confirmed:** ₱45 proposed fixed penalty per overdue obligation, applied **once** per obligation. The penalty **frequency** (one-time vs recurring) is pending formal association approval — keep the design configurable either way.

Penalty amount and frequency are stored in `DuesConfig` (`dues.penalty`, `dues.penaltyGraceDays`) and remain configurable, not hardcoded.

### Penalty stored separately from principal

**Current defect:** `applyOverduePenalties` adds the penalty to the obligation's `amount` field and sets `penaltyApplied: true`. The pre-penalty principal is lost — there is no way to report principal-vs-penalty collected or to reverse a penalty independently.

**Proposed fix:**
- Add `penaltyAmount` field to the obligation doc (default `0` on existing records — backward compatible).
- `applyOverduePenalties` writes `penaltyAmount` on the obligation instead of inflating `amount`.
- `penaltyApplied` flag still gates duplicate application.
- The obligation's `amount` then holds **principal only** (or principal + prior allocated penalty if legacy).
- Historical penalties are never silently modified.

### Penalty in allocation

When a payment covers an overdue obligation with a `penaltyAmount`, the FIFO allocation (§5) splits each applied amount into `allocatedPrincipal` and `allocatedPenalty` per obligation, recorded in `payment_allocations`. Partial payment of an overdue obligation pays principal first; penalty is paid only after principal is fully settled — unless the association approves penalty-first ordering (see §14).

---

## 7. Proposed Database Changes

### Collections (no change to existing `payments` semantics)

| Collection | Purpose | Status |
|---|---|---|
| `payments` | One doc per **payment obligation** (monthly dues, annual fee, monthly membership fee, lot payment, penalty, special assessment, other) — **unchanged meaning** | EXISTS |
| `member_ledgers` | Per-member outstanding **annual** membership balance only (`uid`, `annualTarget`, `currentBalance`, `year`, `createdAt`, `updatedAt`). Monthly dues do NOT touch this ledger. | EXISTS |
| `payment_transactions` | **NEW**: one document per actual payment received (the cash handed over event) | NEW |
| `payment_allocations` | **NEW**: links one transaction to one or more obligations, recording allocated principal & penalty per obligation | NEW |

**`payment_transactions/{transactionId}`**
- `transactionId`, `memberId` (uid), `memberName`, `amount` (total received), `paymentMethod` (`cash` for current version — extensible enum/config for future methods), `referenceNumber` (optional, manual reference for cash or a future method; **not required** to confirm a payment; no GCash-specific validation), `paymentDate`, `receivedBy` (staff uid), `notes`, `createdAt`, `status` (`posted` | `voided`), `unappliedCredit` (excess not allocated — see §8.2)

**`payment_allocations/{allocationId}`**
- `allocationId`, `transactionId`, `memberId` (uid), `obligationId` (the `payments` doc id), `allocatedPrincipal`, `allocatedPenalty`, `allocatedAmount` (= principal + penalty), `allocatedAt`

### Why two new collections instead of extending `payments`

The existing `payments` doc **is the obligation** — its `amount` is what is owed, `status` is paid/unpaid/overdue/waived. It should not be repurposed to record *who paid* or *when*. `payment_transactions` records the actual payment event; `payment_allocations` records how that event was split across obligations. This preserves `payments` backward compatibility for the mobile app and all existing reports.

### Backward-compatible field additions to `payments` (obligations)

- `penaltyAmount` (double, default `0`) — penalty stored separately
- `paidAmount` (double, default `0`) — cumulative amount allocated toward this obligation (supports partial payments without mutating `amount`)

No existing field is renamed or removed. No migration of existing records.

---

## 8. Proposed Improved Payment Flow

```
1. Staff opens Record Payment screen (new modal on PaymentsScreen)
2. Select member → system loads all outstanding obligations for that member
   (unpaid/overdue dues + membershipFee + monthlyMembership, sorted by dueDate oldest first)
   Monthly dues obligations read their `amount` (principal) + `penaltyAmount`.
3. Each obligation shows: month, principal, penalty, total, due date
4. System shows total outstanding balance (sum of principal + penalty across obligations)
5. Staff enters amount received → live FIFO allocation preview (§8.1)
6. Staff selects Cash (the only payment method) → optionally enters a manual reference number
7. Staff clicks Confirm → Firestore write in a single transaction:
   - Create `payment_transactions` doc (amount, method, referenceNumber, receivedBy, paymentDate)
   - For each covered obligation: create `payment_allocations` doc; update obligation's
     `paidAmount`; mark obligation `status=paid` only when fully covered
   - Compute `unappliedCredit` = amount received − total allocated; if > 0, store it
     (§8.2) — do NOT update `member_ledgers` for monthly dues
   - Write audit log entry
   - On-screen receipt displayed (§8.3)
8. Duplicate-reference check: if a `referenceNumber` was provided, query `payment_transactions` where `referenceNumber == X` before committing → block if duplicate found
```

### 8.1 FIFO allocation algorithm (with principal/penalty split)

```
input: paymentAmount, obligations sorted by dueDate asc (oldest first)
remaining = paymentAmount
allocations = []
for obligation in obligations:
    if remaining <= 0: break
    principalOwed = obligation.amount − obligation.paidAmount   # remaining principal
    penaltyOwed   = obligation.penaltyAmount − obligation.paidPenaltyAmount  # tracked via allocations
    # Principal first; penalty paid only after principal fully settled
    applyPrincipal = min(remaining, principalOwed)
    remaining -= applyPrincipal
    applyPenalty   = min(remaining, penaltyOwed)
    remaining -= applyPenalty
    allocations.append({obligationId, allocatedPrincipal: applyPrincipal,
                        allocatedPenalty: applyPenalty,
                        allocatedAmount: applyPrincipal + applyPenalty})
    if principalOwed == applyPrincipal and penaltyOwed == applyPenalty:
        obligation marked paid
unappliedCredit = remaining  # > 0 means overpayment → stored as credit (§8.2)
```

**Partial payment of an obligation:** obligation stays `unpaid`; `paidAmount` accumulates across allocations; `status` flips to `paid` only when cumulative allocated ≥ principal + penalty.

**Penalty-first vs principal-first:** penalties are paid after principal within an obligation. Association must confirm (see §14).

### 8.2 Unapplied credit storage and usage

When a member pays more than their total outstanding balance:
- Excess = `paymentAmount − totalAllocated` is stored as `unappliedCredit` on the `payment_transactions` doc.
- On subsequent payments for that member, the system first applies any existing unapplied credit toward the oldest outstanding obligation before applying new cash.
- Unapplied credit is **not** written to `member_ledgers` (that ledger is reserved for annual membership balances per §7).
- Association approval needed on whether unapplied credit can carry indefinitely or expires.

### 8.3 Receipt

On-screen receipt summary shown after confirmation (member, date, amount, method, reference, allocated obligations, balance remaining). Saved as a read-only view for now; `receipts/{receiptId}` collection deferred to a later phase (§12).

---

## 9. Backend & Firestore Transaction Requirements

All confirmation writes in **one Firestore transaction** (atomic — succeeds or fails entirely):

1. `payment_transactions.doc(transactionId).set(...)` — the payment received event
2. For each covered obligation:
   - `payment_allocations.doc(allocationId).set({transactionId, obligationId, allocatedPrincipal, allocatedPenalty, allocatedAmount, allocatedAt})`
   - `payments.doc(obligationId).update({paidAmount: newPaidAmount})` and optionally `status: 'paid'` when fully covered
3. `audit_logs.doc().set(...)` — who recorded what, amount, method, reference
4. On-screen receipt data (computed, not persisted yet)

**Duplicate transaction prevention:**
- If a `referenceNumber` was provided, read all `payment_transactions` matching the member + date window and any transaction doc with the same `referenceNumber`. This is done inside the Firestore transaction before writing, so if another concurrent transaction already committed with that reference, this one aborts cleanly. A single-field equality index on `referenceNumber` lets `where('referenceNumber', isEqualTo: x)` return those docs; one such index is sufficient and there is no composite index requirement. For cash payments (the only method in Phase 1), `referenceNumber` is optional, so the duplicate check runs only when one has been entered.
- Obligation status check: skip obligations already `paid`; only allocate to `unpaid`/`overdue`.

**FIFO under concurrent confirmations:**
- Firestore transactions provide serializable isolation — two concurrent payments for the same member's obligations will serialize; the second transaction reads the updated `paidAmount`/`status` from the first and allocates only what remains.
- `paidAmount` is the source of truth for remaining obligation balance; read inside the transaction, never cached across calls.

---

## 10. Security & Validation Requirements

- Only `isAdmin`/`isAccountant` can record payments (existing `canRecord` gate).
- Amount must be > 0.
- `referenceNumber` optional for cash; required when a future payment method mandates one.
- Duplicate `referenceNumber` rejected at write time.
- FIFO enforced in code — cannot allocate to a newer obligation while an older one is unpaid.
- Partial payments accumulate `paidAmount`; obligation marked `paid` only when fully covered.
- Unapplied credit decision pending association approval.
- Audit log entry for every recorded payment (existing `logAction` in `SettingsService`).
- Mobile app backward compatibility: new collections are additive; mobile reads `payments` and `member_ledgers` unchanged.

---

## 11. Files That Need Modification

| File | Why |
|---|---|
| `web-admin/lib/features/payments/screens/payments_screen.dart` | Add "Record Payment" entry point; batch mark dialog (already started this session) |
| `web-admin/lib/features/payments/screens/add_payment_screen.dart` | Extend `PaymentModel` usage or add new transaction/allocation path (current single-payment form) |
| `web-admin/lib/core/services/firestore_service.dart` | Add `recordPaymentWithAllocations` (Firestore transaction), reference number dup check, `penaltyAmount`/`paidAmount` updates |
| `web-admin/lib/core/models/payment_model.dart` | Add `penaltyAmount`, `paidAmount` fields (optional, defaults 0) |
| `web-admin/lib/core/models/hoa_settings_model.dart` | `DuesConfig.penalty` default ₱45 (proposed), `penaltyGraceDays` configurable — no schema change |
| `web-admin/lib/core/services/settings_service.dart` | No change needed — penalty/grace already configurable via `DuesConfig` |
| `web-admin/lib/features/members/screens/member_detail_screen.dart` | Optional: add "Record Payment" entry point from member's payments tab |

No existing collection is renamed or removed. `payment_transactions` and `payment_allocations` are additive.

---

## 12. Migration Requirements

- **No migration of existing records.** Existing `payments` docs keep working unchanged; `penaltyAmount` and `paidAmount` default to `0`.
- Existing penalty amounts already folded into `amount` by legacy `applyOverduePenalties` runs remain as-is (historical). New penalties are stored separately.
- Mobile app requires no schema change — reads `payments`/`member_ledgers` as before.
- Composite index on `payment_transactions(referenceNumber)` is not needed (single-field equality). Composite index on `payments(status, dueDate)` already exists for `syncOverdueStatuses`/`applyOverduePenalties`.

---

## 13. Implementation Phases

**Phase 1 — Backend transaction layer**
- Add `recordPaymentWithAllocations` to `firestore_service.dart`: Firestore transaction creating `payment_transactions` + `payment_allocations`, updating obligation `paidAmount`/`status`, audit log.
- Add reference number duplicate check inside the transaction.
- Add `penaltyAmount` and `paidAmount` to `PaymentModel`.

**Phase 2 — Record Payment UI modal**
- Member selector, obligation list (oldest first, principal/penalty/total), amount input, Cash payment method, manual reference field, live FIFO preview, confirm button, on-screen receipt display.

**Phase 3 — Penalty separation in `applyOverduePenalties`**
- Write `penaltyAmount` separately instead of inflating `amount`; keep `penaltyApplied` flag; update allocation preview to split principal/penalty.

**Phase 4 — Unapplied credit + receipts persistence**
- Unapplied credit carry-forward on subsequent payments; `receipts/{receiptId}` collection if needed later.

---

## 14. Testing Scenarios

1. Payment covers exactly one obligation → `payment_transactions` + 1 `payment_allocation` created; obligation marked paid.
2. Payment covers multiple obligations (FIFO) → oldest paid first; allocations per obligation.
3. Partial payment of one obligation → obligation stays `unpaid`; `paidAmount` accumulates; partial `payment_allocation` created.
4. Overpayment → excess stored as `unappliedCredit` on transaction; obligation fully paid; credit available for next payment.
5. Duplicate reference → transaction aborted, error shown.
6. Missing reference for a future method that requires one → blocked before submit.
7. Member with no outstanding dues → "nothing to pay" state.
8. Overdue obligation with penalty → principal allocated first, then penalty.
9. Concurrent confirmations for same member → Firestore transaction serializes; no double allocation.
10. Existing records display correctly after field additions (defaults hold).
11. Mobile app still reads `payments`/`member_ledgers` correctly (backward compat).
12. Ledger not updated for monthly dues (annual-only ledger preserved).

---

## 15. Unresolved Business Decisions (needs formal association approval)

| Decision | Options | Current leaning / provisional rule |
|---|---|---|
| Penalty frequency | One-time per overdue obligation vs recurring every month | Proposed one-time per overdue obligation — **pending formal association approval** |
| Penalty allocation within an obligation | Principal first vs penalty first | **Provisional implementation rule: principal-first.** Pending confirmation by association. |
| Unapplied credit | Carry forward indefinitely vs expire vs reject overpayment | Keep configurable, but do not automatically apply excess until approved |
| Receipt persistence | On-screen only vs `receipts/{receiptId}` collection | On-screen initially; document that this is not permanent receipt storage — `receipts` collection deferred to a later phase |
| Background overdue flip | Client-side (current) vs Cloud Function (Blaze) | Keep client-side (current) |

---

## 16. Conflicts with Existing Implementation

| Conflict | Resolution |
|---|---|
| `applyOverduePenalties` inflates `amount` with penalty | New `penaltyAmount` field; legacy folded amounts remain historical |
| `member_ledgers` updated by `markPaymentPaid` for membership types | Unchanged — monthly dues never touch it; `payment_transactions` also does not update it for monthly dues |
| `markPaymentPaid` sets `status=paid` on a single obligation | Kept for existing single-payment path; new `recordPaymentWithAllocations` uses `paidAmount` accumulation instead |
| `notes` field used as free-text reference | New structured `referenceNumber` field on `payment_transactions`; `notes` kept for free-text remarks |
| `PaymentModel.transactionId` already exists on obligations | `payment_transactions` gets its own `transactionId` — distinct from obligation references |

---

## 16b. Implementation Safeguards

Before coding Phase 1, all of the following must be guaranteed:

1. **Preserve existing collections.** The current `payments` collection semantics and `member_ledgers` behavior are retained. The new `payment_transactions` and `payment_allocations` collections are additive only.
2. **Monthly dues separate from annual membership balances.** Monthly dues are never written to `member_ledgers`. Only annual membership fees may affect `currentBalance`.
3. **`payment_transactions` stores actual received payments.** One transaction doc per cash payment received, with amount, method (`cash`), date, receiving staff uid, optional manual reference number, status (`posted`/`voided`), and unapplied credit where applicable.
4. **`payment_allocations` tracks distribution.** Each allocation records the mapped obligation, allocated principal, allocated penalty, and total allocated amount. This decouples the received cash event from the obligation documents.
5. **Duplicate submissions prevented.** A duplicate reference number check runs inside the Firestore transaction before writing — if a transaction's `referenceNumber` matches an existing one, the whole write aborts. Cash has no mandatory reference requirement.
6. **Concurrent confirmations handled safely.** Firestore transactions provide serializable isolation. Concurrent confirmations serialize; each reads fresh `paidAmount`/`status` inside the transaction before allocating.
7. **Who received and when recorded.** The `receivedBy` field captures the staff member; `paymentDate` captures the date the funds were physically received.
8. **Failed transactions atomic.** All writes execute in one `runTransaction`; there are no partial updates. If any step fails, nothing changes.
9. **Backward compatibility.** Existing `payments` docs display correctly with added `penaltyAmount`/`paidAmount` fields defaulting to `0`. Existing records keep their stored value unchanged except where explicitly updated by the application logic.

---

**Next step:** Review this revised plan. Once approved, Phase 1 (backend transaction layer) begins. Nothing is coded yet.
