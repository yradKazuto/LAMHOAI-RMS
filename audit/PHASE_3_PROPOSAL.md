# Phase 3 Implementation Roadmap — Updated Architecture Document

Stage 1 investigation complete: existing `PaymentModel`, `LotSaleModel`, `allocation_calculator.dart`, and all financial services were reviewed. Four new Firestore collections proposed: `general_ledger`, `journal_entries`, `chart_accounts`.

Stage 2 review agents (Agent 1, Agent 2, and Agent 4, Agent 5) delivered independent architectural recommendations:

- **Agent 1**: Proposes a category-based Chart of Accounts (ASSETS / LIABILITIES / EQUITY / REVENUE / EXPENSES). Journal entries carry debit/credit fields directly; balanced posting is enforced client-side before commit. Account balances are keyed by stable account ids in `general_ledger` documents updated atomically.
- **Agent 2**: Confirms separate collections for audit trail (`journal_entries`) and current state (`general_ledger`). Duplicate posting prevention relies on deterministic entry id pre-allocated from a counter service. Reversals are modeled as new journal entries referencing the original via `relatedTransactionId`, not deletions.
- **Agent 3 AR Aging**: AR Aging derives outstanding obligations from existing `payments`, `lot_sales`, `payment_allocations`. Buckets classify by overdue days computed relative to `dueDate`. Partial payments handled cumulatively via `paidAmount` on existing `PaymentModel`; no duplication risk because only unpaid records contribute to aging totals.
- **Agent 4 Collection Rate**: Expected collections derived directly from existing revenue `PaymentType` records; actual collections similarly filtered to `paid` status. Zero denominator guarded explicitly. Reporting periods handle monthly/yearly windows without new collections.
- **Agent 5 Database/Security**: Schema definition requires index hints; security rules enforce append-only writes to `journal_entries` restricted to admin role and `demo` flags block sample data from leaking into production writes. Demo isolation uses prefixed sub-collections under `phase3_demo` names and seeds only by bootstrap scripts.
- **Agent 6 UI Integration**: Existing Flutter routing under `app_router.dart` already gates `reports` and `analytics` routes to Admin+Accountant roles. Five dedicated accounting screens planned under `features/reports/screens/`: COA listing, General Ledger detail, T-Account view, AR Aging report, plus integrated `collection_rate_screen` under existing Analytics screen. Shared `design_tokens.dart` reused throughout.

## Consolidated Stage 2 Decisions

1. Separate collections `journal_entries` + `general_ledger` remain. No redundancy introduced.
2. Journal entries are single immutable documents. Ledger doc stores only current balances.
3. Balanced entry enforced before transaction commit. Unbalanced entries rejected.
4. Duplicate posting prevented by deterministically pre-computed entry id written as Firestore doc ID within `set(merge:true)` under transaction.
5. Reversal represented as new journal entry whose mirror entries invert signs and reference prior `relatedTransactionId`.
6. AR Aging calculates outstanding obligations from existing payment docs by summing remaining principal vs paid amount per member.
7. Collection Rate formulas derive expected & actual from existing `PaymentModel.type` field.
8. No separate analytics collection required. Reports calculated directly against existing `payments` collection.
9. Demo data isolated under `phase3_demo` prefixed sub-collections seeded exclusively by bootstrap scripts flagged `demo:true`.
10. Existing features (`payments`, `lot_sales`, `allocation_calculator`, `analytics_service`) untouched by prototype code.

## Files Produced This Stage

- `audit/PHASE_3_DATA_SCHEMA.md`
- `audit/PHASE_3_ACCOUNTING_RULES.md`
- `audit/PHASE_3_SERVICE_CONTRACTS.md`
- `audit/PHASE_3_IMPLEMENTATION_MATRIX.md`
- `audit/PHASE_3_PROPOSAL.md` (updated above)
- Test artifact: `web-admin/test/phase3_accounting_model.json` (from Agent 1)

See `audit/PHASE_3_STAGE_2_COMPLETION_REPORT.md` for final verification record. Implementation is ready for Stage 3.
