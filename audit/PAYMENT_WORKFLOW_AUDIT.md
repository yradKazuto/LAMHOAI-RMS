# Payment Workflow Audit

## 1. Registration Flow
1. **Member Add**: Admin opens `MemberRegistrationWizard` → fills personal details → selects lots from map → configures payment terms (sale type, down payment, term months, interest rate) → reviews Statement Preview → confirms.
2. **Confirm**: `registerSale()` batch-writes `lot_sales`, `lot_payments` (amortization schedule via `AmortizationService.buildSchedule()`), and updates `lots` collection linking member to lots.
3. **Result**: Complete installment schedule persisted with transaction IDs per period.

## 2. Statement Preview Behavior
- **Source**: Reads saved data from `lot_sales` and `lot_payments` collections. Does NOT recalculate.
- **Contents**: Per-sale breakdown, remaining balance, amortization table, allocated obligations.
- **Accuracy**: Matches stored database records exactly. No logic mismatch expected.

## 3. Installment Schedule Persistence
- **Generated during registration**: `SaleService.registerSale()` auto-creates all `lot_payments` records in a single Firestore batch transaction.
- **Consistency**: Preview (Step 3 wizard) matches saved schedule — monthly amounts, due dates, remaining balances verified.

## 4. Record Payment / Mark as Paid Behavior
1. Admin opens Member Detail → clicks **Record Payment**.
2. `RecordPaymentScreen` popup opens; member pre-selected via dialog picker.
3. Admin enters amount, selects payment method, optionally notes.
4. System calls `recordPaymentWithAllocations()`:
   - Fetches unpaid/overdue payments for that member.
   - Applies FIFO allocation (oldest dueDate first).
   - Handles partial payments, principal/penalty separation.
   - Wraps in Firestore transaction for atomicity.
5. Success: Receipt view shows allocation results, ledger updated. Failure: Returns `applied: false`.
6. **Current gap**: No duplicate-submission check against the current period.

## 5. FIFO Allocation Verification
- `computeAllocation()` sorts obligations by `dueDate` ascending client-side after fetching from Firestore.
- Allocation order confirmed: oldest obligation gets funded first, remainder distributed across subsequent oldest obligations.

## 6. Ledger Update Behavior
- No dedicated centralized ledger document exists. Each sale maintains its own `lot_payments` history.
- Remaining balance tracked per-period via `paidAmount` + `penaltyAmount` fields on each `payment` doc.

## 7. Receipt Behavior
- UI confirmation screen shows: member name, amount received, method, date, allocation breakdown, transaction details.
- On success: user can close or navigate to the allocated obligation list.

## 8. T-Account Behavior
- **Not implemented** as a formal ledger concept.
- Functionality provided by reading `lot_payments` and computing balances on-the-fly.
- Doesn't meet standard double-entry accounting requirements.

---

## Direct Answers

| Question | Answer |
|---|---|
| Does registration generate a complete installment schedule? | YES — via `AmortizationService.buildSchedule()` in `SaleService.registerSale()`. |
| Does Statement Preview show the complete schedule? | YES — preview calculated before confirmation matches saved data. |
| Is the schedule persisted after registration? | YES — batch commit saves all `lot_payments` documents. |
| Does Record Payment use the correct member and agreement? | YES — member picked from dialog; agreement linked via payment's lotId. |
| Does FIFO allocation work correctly? | VERIFIED — oldest dueDate obligations funded first. |
| Are partial payments supported? | YES — `paidAmount` tracks cumulative partial payments. |
| Are penalties separated from principal? | YES — `penaltyAmount` tracked separately per obligation. |
| Are transaction and allocation writes atomic? | PARTIAL — wrapped in Firestore transaction, but no cross-check prevents duplicates. |
| Are confirmed and pending payments distinguished? | YES — `paymentMethod` field with `pendingVerification` status for non-cash. |
| Does the member ledger reflect actual confirmed transactions? | MIXED — depends on whether centralized ledger exists (it does not). |
