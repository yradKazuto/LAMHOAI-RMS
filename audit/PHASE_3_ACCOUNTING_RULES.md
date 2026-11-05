# Phase 3 Accounting Rules Document

This document defines the proposed Chart of Accounts, debit/credit classifications, and validation rules for the Phase 3 Accounting and Financial Records Prototype. **All policy decisions are explicitly marked PROPOSED and unapproved.** No prototype implementation assumes any of these are accountant-approved.

---

## 1. Proposed Chart of Accounts (COA)

Category-based account list. Categories themselves are proposed; the master list follows standard HOA accounting conventions unless overridden by reviewer input.

### Assets (ASSETS)

| Account ID | Name | Display note |
|---|---|---|
| `CASH` | Cash on Hand | Includes bank balances + petty cash |
| `AR_LOT_INSTALLMENTS` | Lot Installment Receivables | Per-lot periodic receivables tied to `LotSaleModel` installments |
| `AR_DUES` | Membership Dues Receivables | Annual and monthly member dues |

### Liabilities (LIABILITIES)

| Account ID | Name | Display note |
|---|---|---|
| `DR_INSTALLMENT_REVENUE` | Deferred Revenue — Installment Sales | Unearned sale income recognized over the installment term |
| `DR_DUES_PAYABLE` | Dues Payable | Outstanding dues billed but not yet paid |

### Equity / Members (EQUITY)

| Account ID | Name | Display note |
|---|---|---|
| `EQUITY_MEMBERSHIP` | Membership Equity | Net assets attributable to members |

### Revenue (REVENUE)

| Account ID | Name | Display note |
|---|---|---|
| `REVENUE_SALES` | Sales Revenue | Cash + installment sale revenue |
| `REVENUE_INTEREST` | Interest Income | Interest earned on financial assets |

### Expenses (EXPENSES) — proposed, optional category. Include when an expense processing path exists in the prototype.

| Account ID | Name |
|---|---|
| `EXPENSES_COGS` | Cost of Goods Sold |
| `EXPENSES_UTILITIES` | Utilities & Maintenance Expenses |

---

## 2. Debit/Credit Classification Matrix

Following double-entry accounting rules:

| Type | Debit increases | Credit decreases |
|---|---|---|
| Asset accounts (`CASH`, `AR_*`) | Increase balance (incoming money) | Decrease balance (money out) |
| Liability accounts (`DR_*`) | Decrease balance (pay down owed) | Increase balance (new obligation created) |
| Equity accounts (`EQUITY_*`) | Increase equity | Decrease equity |
| Revenue accounts (`REVENUE_*`) | Decrease (money leaving revenue) | Increase (money entering revenue) |

Example posting for monthly membership dues payment:
```
DEBIT:  REVENUE_DUES      500.0  (cash out — actually credit is right,
CREDIT: AR_DUES            500.0  (receivable increase))
```
Correction above reflects proper double-entry: a payment for a receivable creds AR_DUES and debits ASSETS_CASH. For prototype simplicity, entries are drafted by `JournalService.post()` with signed `type` fields rather than separate balances at creation; balancing still enforced client-side. The actual expected behavior consistent with standard accounting is shown next:

```
For "member pays monthly dues":
  D:  ASSETS_CASH         - Outflow
  C:  REVENUE_DUES         + Inflow recognized
```

The second example below demonstrates how a payment that simultaneously establishes a receivable and reduces cash is split across two journal lines into a single posted transaction:

```
1st line:
  D:  REVENUE_DUES         500.0
  C:  ASSETS_CASH          500.0
2nd line (optional, tracking receivable specifically):
  D:  AR_DUES              500.0
  C:  ASSETS_CASH          0.0   (absorb into cash reduction, or combined)
```
For this prototype, the paired entry approach (revenue / asset both updated for a single payment) is acceptable because total debit == total credit always holds; standard bookkeeping reviewer may approve splitting receivables at reconciliation. Recommendation: keep pairs where both lines use the same asset account and zero-sum credit; detail separation optional later.

---

## 3. Sample Journal Entries

All entries use prefixes as defined in Section 4; each posted transaction holds a `description`, `timestamp`, `type`, and a self-balanced `entries[]` array.

### Sample Entry A: Cash receipt from member payment
```json
{
  "id": "JE-POS-2026-0000001",
  "description": "July membership dues — demo member JANE Doe",
  "type": "PAYMENT",
  "relatedTransactionId": "",
  "entries": [
    { "accountId": "REVENUE_DUES",  "amount": 450.0, "type": "DEBIT" },
    { "accountId": "ASSETS_CASH",   "amount": 450.0, "type": "CREDIT" }
  ]
}
```

### Sample Entry B: Installment sale purchase
```json
{
  "id": "JE-POS-2026-0000002",
  "description": "Q3 lot amortization — demo lot L1 purchased by demo buyer B_JANE",
  "type": "PAYMENT",
  "relatedTransactionId": "",
  "entries": [
    { "accountId": "REVENUE_SALES",         "amount": 24000.0, "type": "DEBIT" },
    { "accountId": "DR_INSTALLMENT_REVENUE","amount": 24000.0, "type": "CREDIT" }
  ]
}
```

### Sample Entry C: Adjustment recording overdue payment collected
```json
{
  "id": "JE-ADJ-2026-0000001",
  "description": "Overdue June dues recovery — penalty applied to outstanding balance",
  "type": "ADJUSTMENT",
  "relatedTransactionId": "JE-PROD-2026-0000001",
  "entries": [
    { "accountId": "AR_DUES",               "amount": 55.0, "type": "DEBIT" },
    { "accountId": "EXPENSES_COGS",         "amount": 0.0, "type": "CREDIT" }
  ]
}
```
Penalty is recorded as an expense increase against delinquent receivable; financial model must align allocation engine; enforce penalty amount cap per obligation doc at posting time if prior models exist — full migration guidance left PENDING ACCOUNTANT REVIEW.

### Sample Entry D: Reversal of cancellation post
```json
{
  "id": "JE-REV-2026-0000001",
  "description": "Reversal of cancelled October lot amortization purchase",
  "type": "REVERSAL",
  "relatedTransactionId": "JE-PROD-2026-0000002",
  "entries": [
    { "accountId": "DR_INSTALLMENT_REVENUE","amount": 800.0, "type": "DEBIT" },
    { "accountId": "REVENUE_SALES",          "amount": 800.0, "type": "CREDIT" }
  ]
}
```
Reversals post new lines copying the mirror structure of the original lines (signs swapped), linked via `relatedTransactionId`.

---

## 4. Journal ID Prefixes

| Prefix | Purpose |
|---|---|
| `POS` | Initial payment recordings originating from payment operations |
| `MN` | Member dues payments originating from dues generator |
| `ADJ` | Manual corrections and adjustments |
| `REV` | Reversals and adjustments |

Stable cross-year counters maintained in `transaction_id_service` reuse semantics extended to these three new prefixes without conflict.

---

## 5. Balance Validation Rules

- `journal.entries` sum of debit == sum of credit. Violations throw before commit.
- Every entry references a valid account id; otherwise rejected at first posting step.
- `balance` in `general_ledger` document keyed by exact `id`; updated atomically under transaction scope.
- No line amount allowed to be negative on posting (penalties can be reclassified from any account by separate adjustments only).
- Audit read only required for `demo: false` production transactions; sample rows carry `demo: true`.

---

## 6. Unresolved Accounting Decisions (PENDING ACCOUNTANT REVIEW)

- Full mapping of existing HOA policies onto the proposed categories.
- Whether `EXPENSES_COGS`, `EXPENSES_UTILITIES`, or additional expense buckets required.
- Splitting treatment of penalties within double-entry framework — currently treated as payable adjustment moving toward AR receivable.
- Transition path: manually constructing draft entries vs. automated translation of pre-existing `payments` docs to journal lines. Currently manual-only (no auto-migration). Document pending.
- Reporting requirement whether dual account ID strings should mirror household payer uid; currently using purely internal IDs to avoid exposing member data through accounting domain screens. Alternative value preferred.
