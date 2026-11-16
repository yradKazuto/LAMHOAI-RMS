# Ponytail Audit — Full System + Payment Scheme

Scope: over-engineering and complexity only. **Read-only** — lists findings, applies nothing. One-shot. Payment-scheme findings marked `PAYMENT:` for emphasis.

1. `delete:` `recalculateActiveSales` in `sale_service.dart:800` — dead (definition-only; no live callers except its test), and it overwrites existing amortization schedules from the *current* global rate, violating the sale-price snapshot rule. [web-admin/lib/core/services/sale_service.dart:800]
2. `delete:` `LotPricing.priceFor` in `lot_pricing.dart:1-42` — hardcoded 300-month table (`areaThresholdSqm=120`, `monthlyLarge=610`, `monthlySmall=590`, `years=25`, `totalInstallment`) that ignores `sales_rate/config` ratePerSqm entirely; the config doc exists but is decorative, making both the pricing-exception fields and the rate service surface pointless. [web-admin/lib/core/utils/lot_pricing.dart:1]
3. `delete:` journal/ledger write path — `LedgerService.postJournalEntry` has no callers in production (only tests); `general_ledger`/`journal_entries` are read by `general_ledger_screen` but nothing ever writes them, so the whole double-entry path is scaffolding. [web-admin/lib/core/services/ledger_service.dart:58]
4. `delete:` `createOrUpdateLedger` + `updateLedgerBalance` in `firestore_service.dart:159,181` — ~90 lines of definition-only dead code for the journal path above. [web-admin/lib/core/services/firestore_service.dart:159]
5. `delete:` two-payment-store mirror (`_mirrorMap` / `_mirrorTxnId` / `_mirrorSource` / `_mirrorId`) — the payment scheme intentionally keeps `lot_payments` (schedule) and `payments` (mirror with `type: lotPayment`) in sync via `_markPeriodPaid`, `markLotPaymentRecordPaid`, and `markInstallmentPaid`; three mark-paid paths for one state, two streams, two write locations. Collapse to one schedule read by the same UI. [PAYMENT: web-admin/lib/core/services/sale_service.dart:60]
6. `delete:` backfill migration (`backfillLotPaymentRecords`, `payments_screen._backfillLotPayments`, `payments_screen._lotBackfillChecked`) — its own doc comment says it is a one-time catch-up; safe to delete once the run completes. [web-admin/lib/core/services/sale_service.dart:202; web-admin/lib/features/payments/screens/payments_screen.dart:109]
7. `delete:` `payment_allocations` write — `recordPaymentWithAllocations` writes here, but the collection is queried by nobody anywhere in `web-admin` or `mobile`; the allocation row is dead and takes a collection + rules block with it. [web-admin/lib/core/services/firestore_service.dart:1311; firestore.rules:103-109]
8. `delete:` `transferLot` — a thin wrapper over `changeLotOwner` with one caller; delegate directly. [web-admin/lib/core/services/sale_service.dart:707]
9. `delete:` pricing-exception surface (`sales_rate/config`, `rate_schedules`, `SalesRateModel`, `pricingType`/`basePrice`/`adjustmentAmount`/`pricingApprovedBy`) — nobody reads the configured rate (see #2), so this whole abstraction has no implementation. [web-admin/lib/core/services/rate_service.dart]
10. `shrink:` `recordPaymentWithAllocations` in `firestore_service.dart:1174-1208` — `transactionId` is computed and never used (recomputed at 1208); its duplicate check queries the *newly generated* id so it always finds nothing and the check is a no-op. [web-admin/lib/core/services/firestore_service.dart:1174]
11. `shrink:` `AllocationCalculator.computeAllocation` in `allocation_calculator.dart:122-123` — `if (applyPenalty > remaining) applyPenalty = remaining;` is dead (`penaltyOwd` already caps to `remaining`); move the helper above its use and rename `penaltyOwd` → `owedPenalty`. [web-admin/lib/core/services/allocation_calculator.dart:122]
12. `reuse:` `_mirrorTxnId` in `sale_service.dart:66-72` — hand-rolls `LP-YYYY-{seq}-CASH/DP/Pnnn`; `TransactionIdService` already formats this exact shape, and the mismatch is why `payment_labels.dart` exists as a fragile suffix heuristic. Reuse the service. [web-admin/lib/core/services/transaction_id_service.dart; web-admin/lib/core/utils/payment_labels.dart]
13. `delete:` amortization cash path in `amortization_service.dart` — `buildSchedule` emits period 0 with `status: scheduled` and `amount = totalPrice` for cash/no-financed sales; a cash sale needs no amortization schedule at all. [web-admin/lib/core/services/amortization_service.dart]
14. `delete:` inline doc-comment inside `offsetMonths` body in `amortization_service.dart` — misplaced comment text in the function body rather than the doc-comment block. [web-admin/lib/core/services/amortization_service.dart]
15. `delete:` stale audit docs `audit/PAYMENT_WORKFLOW_AUDIT.md` and `audit/SYSTEM_AUDIT_REPORT.md` — superseded by this report and `docs/flow-payment-scheme.md`; keep a single source of truth. [audit/]

**net: ~1,200 lines, -0 deps possible.**

---

## Payment Scheme — correctness items flagged on request (out of ponytail scope)

`ponytail:ponytail-audit` scopes to over-engineering/complexity; correctness/bugs belong in a normal review pass. The user explicitly asked for the payment scheme, so these are listed separately:

1. **FIFO allocation only sees `payments`, not `lot_payments`.** `recordPaymentWithAllocations` reads obligations from `payments` only, so it cannot allocate a payment against the amortization schedule rows; lot installments sit invisible to the engine.
2. **`recordPayment` ignores amount/partial.** It marks the *first unpaid period fully paid* regardless of the amount tendered — partial payments overstate principal, and overpayments are silently absorbed.
3. **`markInstallmentPaid`** — same all-or-nothing behavior at the UI click path; an installment cannot be partially settled.
4. **Duplicate-submission gap.** The duplicate check in `recordPaymentWithAllocations` is the dead code in #10 above (queries a fresh id), so the same payment can be recorded twice.
5. **Overdue/penalty (Flow 06) never runs on lot installments.** `syncOverdueStatuses` / `applyOverduePenalties` operate on `payments` (dues); the `lot_payments` schedule has no overdue→penalty flow, so installment interest/penalty is never applied.
6. **No centralized ledger.** Dues use `member_ledgers`; lot sales use the amortization schedule; there is no single source of truth for what a buyer actually owes, which is exactly what the general ledger path in #3 was meant to provide but was never wired in.

---

## Plain-English Explanation

Here is a simpler version of the technical findings above, explained without programming jargon:

1. **Dead Calculation Tool:** There is an old tool for recalculating payment schedules that shouldn't be used anymore because it has the potential to accidentally overwrite correct, finalized payment records.
2. **Incorrect Sales Rates:** The system is currently ignoring your official sales rates (price per square meter) and instead using a fixed, outdated pricing list that doesn't follow your actual pricing policies.
3. **Disconnected Accounting:** An accounting system (a "ledger") was built, but it isn't connected to the actual data, meaning it doesn't currently do any work and its reports show nothing.
4. **Duplicate Record-Keeping:** We are tracking member payments in two different places at once. This makes it very difficult to keep records accurate and often leads to mistakes where one record is updated but the other is forgotten.
5. **Leftover Setup Code:** There is extra "cleanup" code in the system that was only needed when it was first set up years ago, which is now just taking up space.
6. **Useless Data Collection:** The system is recording extra payment details that nobody ever looks at, which just slows down the payment process.
7. **Unused Pricing Features:** There are built-in settings for "pricing exceptions" that don't do anything because the rest of the system isn't using them.
8. **Limited Payment Tracking:** The current system for deciding which bills a payment should cover is very limited; it cannot correctly link payments to specific lot installment plans, making it hard to track exactly what each buyer owes.
9. **Missing Late Penalties:** The system automatically applies late penalties to membership dues, but it does NOT apply these same penalties to lot installment payments, meaning late lot payments are effectively free of penalty.
10. **No Single Source of Truth:** Because dues records and lot sale records are tracked differently, there isn't one single place to see exactly what a member owes for everything, making financial reconciliation difficult.
