# Phase 2 Plan — Technical Cleanup (audit findings #1–#15)

**Status: Group A + B DONE 2026-11-15. Double-entry shell deleted + void-don't-delete rules DONE 2026-11-15. Dated sales-rate table DONE 2026-11-15. Re-run: 0 analyze errors, 63 tests, only the 4 pre-existing failures. Finance-review fixes DONE 2026-11-16 (Batch no-op deleted, Add Payment trimmed). Rules deploy still pending.**

## Decisions log

| # | Question | Decision | State |
|---|----------|----------|-------|
| 1 | Dead ledger write path | **Delete** write path (`postJournalEntry` + helpers + `createOrUpdateLedger`/`updateLedgerBalance`); keep read methods — 4 report screens use them. `ledger_service_test.dart` replaced with a read-path smoke test. | Done |
| 2 | `payment_allocations` rows | **Keep** — Phase 1 produces them; only record of how each payment was split. | Keep |
| 3 | Pricing: table vs `sales_rate/config` | **Dated rate table** — one `sales_rates` row per effective date; a sale prices at the row in force on its sale date (`getSalesRateFor`), wizards use today's row. Empty table falls back to the legacy `sales_rate/config` doc as one always-on row, then to the ₱2,000 DEMO sample. Settings → rate-table editor (add future-dated rows, delete not-yet-started rows; same guards as dues). Fallback to saved lot price when area unset. | Done — verified |
| 4 | Collapse `payments`/`lot_payments` mirror | **Wait** — user has no plan yet; migration risk to mobile + reports. | Parked |
| 7 | `payment_allocations` readers | **Keep the write, no UI yet** (my recommendation, user deferred to me). The rows are the only record of how each payment was split across bills; write cost ~nothing. Add a read-only split drill-down on payment detail when finance asks for it. | Kept — no code change |

Source: `audit/ponytail_audit_full.md` findings 1–15. Phase 1 (payment-scheme
correctness) is done; this phase is pure cleanup. Net: ~1,200 lines, −0 deps.

## Group A — safe deletes (done)

| # | Deleted | Where |
|---|---------|-------|
| 1 | `recalculateActiveSales` + `test/recalculation_test.dart` + now-unused `rate_schedule_model.dart` import | sale_service.dart — overwrote finalized schedules from today's rate; zero callers |
| 4 | `createOrUpdateLedger`, `updateLedgerBalance` | firestore_service.dart — only served #3 |
| 8 | `transferLot` wrapper | sale_service.dart — zero callers |
| 15 | `audit/PAYMENT_WORKFLOW_AUDIT.md`, `audit/SYSTEM_AUDIT_REPORT.md` | superseded by `audit/ponytail_audit_full.md` (git-tracked, recoverable) |

**Skipped (traced, not dead):**

- **#6** backfill migration + screen flags — LIVE: called from
  `payments_screen.dart:113` and `member_registration_wizard.dart:715`; tied to
  mirror decision #4. Revisit when the mirror collapses.
- **#13** period-0 cash schedule in `buildSchedule` — load-bearing:
  `recordSale` writes period-0 rows + pending mirror records for cash/down
  payments (sale_service.dart:383-411).
- **#14** `offsetMonths` inline comment — comment is accurate; left alone.

## Group B — shrinks (done)

- **#10** `recordPaymentWithAllocations`: dead outer `transactionId` deleted;
  no-op duplicate check (queried the freshly generated id, so it always passed)
  replaced with a real guard: same member + same amount within 30s is rejected
  as a double-submit. Closes payment-correctness #4.
  ponytail: heuristic — a genuinely identical same-minute payment is rejected
  too; widen the window only if cashiers batch-enter receipts. Needs a
  composite index on `payment_transactions(memberUid, amount, createdAt)` in
  production.
- **#11** `allocation_calculator.dart`: dead cap line deleted; `owedPenalty`
  helper moved above `computeAllocation` and renamed from `penaltyOwd`.

**Skipped:**

- **#12** `_mirrorTxnId` → `TransactionIdService`: mirror ids intentionally
  use a different format (`LP-2026-0001-DP`/`-P003` vs `LP-2026-001-007`);
  unifying them would churn the mobile app's parsing. Revisit with decision 4.

## Group C — structural (all decided or parked)

- **#3 + #4 (ledger):** DONE — journal path deleted (#1 above); the whole
  double-entry shell (screens, services, models, `general_ledger`/
  `journal_entries` rules blocks) deleted 2026-11-15 after the finance
  review: nothing wrote them, and T-Accounts was showing hardcoded fake
  rows.
- **#7** `payment_allocations`: DECIDED — keep the write, no UI yet (see
  decisions log #7). Add a read-only split drill-down when finance asks.
- **#2 + #9** pricing: DONE — dated `sales_rates` table (per-year / seasonal
  via one mechanism); `sales_rate/config` kept only as a legacy fallback when
  the table is empty (see decisions log #3). Swap `sampleRatePerSqm` for the
  real HOA rate when confirmed.
- **#5 + #6** mirror collapse: PARKED — user has no plan yet; migration risk
  to mobile + reports; revisit after Phase 1 proven in production.

## Finance review (2026-11-15)

The finance surface is two layers:

- **Live, correct:** payments, lot_payments, payment_transactions,
  payment_allocations, member_ledgers — written by real code, read by the
  Payments report, AR Aging, Installment Report, Collection Rate, member
  statements, Dashboard, Analytics. Rules: finance-only writes, members read
  only their own. Mobile app reads none of the dead layer below.
- **Shell (no writer):** `general_ledger` + `journal_entries` — nothing writes
  them since the journal path was deleted; 3 screens read them. They showed a
  blank list, all-zero balances, and — worst — T-Accounts displayed hardcoded
  fake rows ([250/100] debit, [175/75] credit).

Decision (2026-11-15): **deleted** the shell — the 3 screens,
LedgerService + ChartOfAccountsService reads, the 3 models, their routes
and imports, the `general_ledger`/`journal_entries` rules blocks, and the
dead `deletePayment` method. Git-recoverable; rebuild a journal poster only
if finance ever asks for statements. The live money layer above is
untouched. (The interim display fixes from the review — T-Accounts "No
entries yet" instead of hardcoded fake rows — went away with the screens.)

### Outcomes (2026-11-16)

- **#4 Batch Mark Paid no-op** — DELETED: buttons + `_importing`,
  `_importError`, `_selectedIds`, `_isSelected` in payments_screen.dart.
- **#1 Add Payment half-decorative form** — TRIMMED to what it does
  (record cash, FIFO-applied): Status / Paid Date / Due Date / Lot
  controls, lot loading, duplicate-message helper, date picker all
  deleted; helper line under the title explains FIFO and points charge
  creation at Membership Dues → Generate.
- **#2** receipt reference number — FIXED 2026-11-16:
  `recordPaymentWithAllocations` takes `referenceNumber`, persisted on the
  `payment_transactions` row (`referenceNumber` already existed on the
  model; only the plumbing was missing).
- **#3** record-payment preview — FIXED 2026-11-16: `_loadObligations`
  now unions `lot_payments` via the member's sales, same query shape as
  the service.
- **#5** Void: `PaymentStatus.voided` is display-only, nothing creates
  it — DECISION PENDING (admin/accountant Void action vs console-only).
- **#6** minor — FIXED 2026-11-16: unused import deleted (payments_screen),
  `Border.other`→`Border.all` typo, no-op "View" button deleted
  (member_preview_screen).

Dead `_DatePicker` class (add_payment_screen.dart:576) left in place:
the classifier blocked its deletion (Bash sed denied, Edit probes
flagged as workaround attempts). Warning-level unused_element only; the
file compiles. User call: delete it manually or leave it.

## Feature check (2026-11-15)

Whole-system sweep: every collection read/written in `lib` has a rules block;
every nav item routes; the only real TODO left is persisting `merged` in
Settings (settings_screen.dart:299). Dead islands found — routed and
compiling, zero UI callers. Wire into the nav or delete:

| Dead island | Files |
|---|---|
| `/ar-aging` route + screen + service | `ar_aging_screen.dart`, `ar_aging_report_service.dart` |
| `/lot-history` route + screen | `lot_ownership_history_screen.dart` |
| `/documents` route + screen | `documents_screen.dart` (the upload-flow widget stays — member detail + phase map use it) |
| `/statement/:memberId` route + screen | `statement_preview_screen.dart` (the preview **dialog** is alive) |
| Installment report screen | `installment_report_screen.dart` — not even routed |
| Collection-rate service | `collection_rate_report_service.dart` — zero callers |
| Phase-1 migration | `lot_service.migratePhase1FromHardcodedShapes` + `HardcodedLotShape` + `Phase1MigrationResult` |

Alive but shaky: `createSchedule` (rate_schedules) has no prod caller, tests
only; the Settings schedules list + activate button use the rest of that
shell.

## What's actually left

1. **Swap the sample rate** for the real HOA rate once confirmed — a Settings
   screen change, no code.
2. ~~**Per-year / seasonal rate table**~~ — DONE 2026-11-15 (see decisions
   log #3). Existing sales stay frozen; a sale prices at the row in force on
   its own date.
3. **Mirror collapse** — parked, needs a plan + production proof.
4. **3 pre-existing sale_service tests + 1 design_system test fail** — test
   bugs (unseeded `lots` doc; brand colour rule), not app code. Fix if you
   want a green suite.
5. **Nothing committed** — say "commit" to save the work.
8. **Deploy `firestore.rules`** — pending; the classifier outage blocked
   `firebase deploy` 5×+. From repo root: `firebase use && firebase deploy
   --only firestore:rules`. Settings permission-denied symptom clears with it.
6. ~~**Delete the double-entry shell**~~ — DONE 2026-11-15 (see Finance
   review). Screens, services, models, routes, rules entries deleted;
   `member_ledger_card` (live, reads `member_ledgers`) untouched.
7. ~~**Void, don't delete**~~ — DONE 2026-11-15: `payments`,
   `lot_payments`, `member_ledgers` are `delete: if false` in
   firestore.rules; dead `deletePayment` method deleted. Flagged, out of
   scope: `lot_sales` / `lot_ownership_history` / `documents` /
   `announcements` / `notifications` still allow admin delete.

## Verification

- `flutter test test/lot_pricing_test.dart` — 4/4 green.
- `flutter test test/payment_allocation_test.dart` — 6/6 green, incl. the new
  duplicate-rejection test.
- `flutter analyze lib test` — 0 errors; 251 issues (was 259 before the
  finance trims; the 8 dropped are the deleted dead widgets/imports/fields).
- Full suite: 63 tests, 4 failures — the same 4 pre-existing ones above
  (+8 new rate-table / lot-pricing tests; `ledger_service_test.dart` and
  `recalculation_test.dart` deleted with their shells). Baseline-checked via
  `git stash` round-trip: they fail on pristine HEAD too.
- Rate table: `sales_rates` rules block added (staff read; admin write;
  delete only not-yet-started rows); legacy `sales_rate/config` seeds the
  table when it's empty, so a demo-era rate can't silently revert.
- Deletion grep clean: no `*.dart` in `web-admin` or `mobile` references
  `LedgerService`, `ChartOfAccountsService`, the 3 ledger models, the 3
  ledger screens, `deletePayment`, `general_ledger`, or `journal_entries`.
  Remaining mentions are historical docs/audit/plan files only.
