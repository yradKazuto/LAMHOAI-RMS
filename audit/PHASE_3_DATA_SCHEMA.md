# Phase 3 Data Schema Document

This document defines the proposed Firestore data structures for the Phase 3 Accounting and Financial Records Prototype. All sections are marked **PROPOSED** until accountant review. No implementation touches production collections.

---

## 1. Collections Overview

| Collection | Purpose | Document type | Created by |
|---|---|---|---|
| `general_ledger` | Current account balances | `Account` | Ledger service |
| `journal_entries` | Immutable audit trail of every financial movement | `JournalEntry` | Ledger service |
| `chart_of_accounts` | Central index of valid account IDs and descriptions | `ChartAccount` | Bootstrap/seed |

A new demonstration namespace `phase3_demo` is used for all sample/synthetic data so prototype records never mix with production financial data.

---

## 2. Document Structures

### 2.1 `account` (within `general_ledger`)
Current running balance for a single account ID. Updated atomically within every journal posting transaction.

```json
{
  "id": "CASH",
  "name": "Cash on Hand",
  "category": "ASSETS",
  "balance": 0.0,
  "lastUpdated": null
}
```
Fields:
- `id` — stable, uppercase identifier (e.g. `CASH`, `ASSETS`, `AR_LOT_INSTALLMENTS`). Used as document key and by `JournalLine.accountId`.
- `name` — human label.
- `category` — one of `ASSETS`, `LIABILITIES`, `EQUITY`, `REVENUE`, `EXPENSES` (values enforced via `AccountCategory` enum).
- `balance` — current net balance. Decimals float in Firestore (storing number). Always written atomically with every journal update.
- `lastUpdated` — timestamp updated on every balance change. Optional but recommended.

### 2.2 `journal_entry`
Immutable record of one posted transaction. The primary source of truth for auditability. Append-only; never mutated after commit.

```json
{
  "id": "JE-PROD-2026-0000001",
  "timestamp": null,
  "description": "June membership dues — example entry for prototype demo",
  "type": "PAYMENT",
  "relatedTransactionId": "",
  "entries": [
    { "accountId": "MEMBERS_DUE_REVENUE", "amount": 500.0, "type": "DEBIT" },
    { "accountId": "CASH", "amount": 500.0,       "type": "CREDIT" }
  ]
}
```
Fields:
- `id` — UUID-style unique key. Stored as Firestore doc id; prevents duplicate posting via `set(merge: true)` inside transactions. Format: `<PREFIX>-YYYY-NNNNNNN` where PREFIX is the first account acronym (`POS` for sales, `MN` for dues).
- `timestamp` — ISO8601 DateTime. Same for all lines in a single entry.
- `description` — free text. Required; non-empty.
- `type` — one of `PAYMENT`, `ADJUSTMENT`, `REVERSAL`. Reversals duplicate entries by creating a *new* journal line referencing the original via `relatedTransactionId`. Not referenced to cancel old lines.
- `relatedTransactionId` — optional link to a prior `journal_entry.id` when this is an adjustment/reversal. Empty for original payment postings.
- `entries` — array. Every debit must equal sum of credits (enforced client-side before `commit()`). `amount` stored as floating-point number.

Validation rules:
1. Every `entries[].type` must be `DEBIT` or `CREDIT`.
2. Sum of `DEBIT` amounts == Sum of `CREDIT` amounts. Unbalanced entries rejected before commit.
3. At least one entry per journal line.
4. `accountId` must exist in `chart_of_accounts` (client resolves before posting; server-side reconciliation runs too).

### 2.3 `chart_account`
Static or dynamically seeded catalog. Provides the set of valid account ids consumed by journal entries and ledger updates.

```json
{
  "id": "CASH",
  "name": "Cash on Hand",
  "category": "ASSETS",
  "description": "All bank balances and petty cash inventory"
}
```
Fields mirror `Account`. No `balance`; used purely as an index/allowlist.

---

## 3. Document Identifier Strategy

- Primary identity: Firestore auto-generated document ID for `journal_entries`.
- Alternate identity (idempotency): deterministic string composed from `idPrefix` + year + sequence padded to 7 digits. e.g. `JE-POS-2026-0000010`. Sequence counters maintained per (prefix, year) group within `transaction_id_service.dart` semantics.
- Balances keyed by the `id` of `chart_account` documents.

All IDs must be globally unique across both `general_ledger` and `journal_entries`.

---

## 4. Relationships

```
journal_entries ──< entry >── accounts (general_ledger)
   │                              │
   │                              └──< journal_entry.id ── relatedTransactionId ──> journal_entries
   │
   └──< chart_account (allowlist) ──> uses account.id as doc key
```

- Every `JournalLine.accountId` references a `chart_account.id`.
- Every `general_ledger` `account.id` has corresponding `chart_account`.
- Historical references preserved via `relatedTransactionId`.

---

## 5. Required Indexes

No composite indexes required because queries target `type` equality and `accountId` equality; single-field suffices. For historical queries, consider:

```
collection path: journal_entries
fields: timestamp asc / timestamp desc   -- 1 field each, free
collection path: general_ledger
fields: accountId asc / accountId desc   -- 1 field each, free
```

Install these via the Firestore export script created in `firestore_service.dart`.

---

## 6. Security Rules Strategy

- `general_ledger` and `chart_accounts`: read public; write limited to admin/accountant roles.
- `journal_entries`: read public (full history); write restricted to admin only. Audit trail must never be overwritten.
- Demo collection: a top-level guard via `const prefix = 'phase3_demo/'` metadata on any record flagged `demo: true` ensures rules reject writes outside that namespace unless the caller passes an environment flag.
- Collection names: `phase3_demo_general_ledger`, `phase3_demo_journal_entries`, `phase3_demo_chart_accounts` (isolated prefix strategy), or same names with `demo` flag guard. Recommendation follows: **same names + demo flag** to preserve production paths while keeping writes blocked without the flag.

Default global rule updated in `firebase.json` `firestore.rules` to:
```
allow create, update: if false
allow read: if true
allow delete: if false
```
Overlay annotations only allow accounting writes from matching roles.

---

## 7. Data Isolation Strategy

1. Demonstration sample data lives exclusively in the `phase3_demo` prefixed sub-collections when feasible, or any top-level collection holding a `demo: true` boolean flag in every sample doc.
2. Sample records never reference real `users.uid`, real `lots.uid`, or real `lot_sales.buyerUid` except in deliberately mapped illustrative entries (such as journal entries reproducing payments already recorded in production), which should carry the matching `sourceDocId` reference for traceability.
3. `demo` flags are written only by bootstrap scripts, never inside `journal_service.post()` business methods.

---

## 8. Update Status

Stage 1 investigation confirmed: no `general_ledger`, `journal_entries`, or `chart_accounts` existed. No destructive changes required. Schemas below supersede provisional proposals in `audit/PHASE_3_PROPOSAL.md`. Ready for Stage 3 implementation.
