# Plan — V2 Add Member / Multi-Lot Registration Workflow

**Source:** `docs/LAMHOAI_V2_Registration_Workflow.md` (approved, 2026-10-30)
**Scope:** 5-step wizard — Member Details → Location Mapping → Payment Setup → Finance Preview → Confirm Registration.
**Principle:** reuse existing services (`SaleService`, `AmortizationService`, `RateService`, `LotService`); no duplicate services; registration writes nothing paid.

---

## Design decisions (from the doc + current code)

| Decision | Rationale |
|---|---|
| Registration creates sale + schedules with **all periods `scheduled`** — nothing paid | Doc §5/§6: down payment is a term, not proof of receipt; cash is marked paid only when money is actually received via Record Payment. |
| New `SaleService.registerSale` method, **distinct from** `recordSale` | `recordSale` (used by the For-Sale lot dialog) marks cash `paidOff` + creates a paid period-0 doc — exactly what registration must not do. Keep legacy behavior; add a registration-only path. |
| **T-account is a derived, read-only draft view** — no ledger writes, no posted accounting entries | Doc §7: preview only; account names / debit-credit mapping need adviser confirmation. Codebase has no `LedgerService`; balances are computed from `lot_sales` + `lot_payments` at display time. |
| `totalPrice` is the **price snapshot** saved to `lot_sales` | Doc §11: snapshot so later rate changes don't rewrite an existing sale's agreed price. Pricing-basis field (standard vs approved exception) is a pending §15 decision — leave as `totalPrice` for now, note as pending. |
| Multi-lot: one `lot_sales` per lot + `lots.uid → buyerUid` link | Doc §10: `lot_sales` is one record per lot; `MemberModel.lotNumber`/`phase` remain singular legacy fields — do not silently treat one lot as the only lot. |
| Auth + Firestore are **not atomic** → recoverable registration workflow | Doc §9: if Auth creation succeeds but DB writes fail, provide recovery rather than a half-created registration. |

---

## Reuse inventory (do not rebuild)

- `AmortizationService.monthlyPayment` + `buildSchedule` — pure math, already unit-tested. §5 installment calc.
- `LotSaleModel` / `LotPaymentModel` — sale + schedule records. `LotSaleModel` already holds `totalPrice`, `downPayment`, `financedAmount`, `termMonths`, `annualInterestRate`, `monthlyPayment`, `saleType`, `status`.
- `RateService.getSalesRate` — configurable rate per sqm (`sales_rate`/`config`). §11 pricing basis.
- `LotService.streamLots`, `streamLotsByPhase`, `streamLotsForMember` — lot eligibility/availability.
- `LocationMappingScreen` / `lot_dialogs.dart` / `simple_phase_map_view.dart` — map + vacant/eligible lot display. §2 map step.
- `statement_preview_dialog.dart` — read-only preview pattern (streams only, no writes). §7/§15 preview baseline.
- `_AddMemberDialog` Auth-creation pattern (secondary Firebase App, email verification) — reuse for Auth step at confirm; do **not** create Auth at step 1.

---

## What to build (smallest vertical slices)

### Phase A — Service: `registerSale` (no UI)

Add to `SaleService` (`web-admin/lib/core/services/sale_service.dart`):

```dart
registerSale({
  required LotModel lot,
  required String buyerUid,
  required String buyerName,
  required SaleType saleType,       // cash | installment
  required double downPayment,      // 0 for cash
  required int termMonths,          // 0 for cash
  required double annualInterestRate,
  required DateTime soldDate,
  required String recordedBy,
})
```

Behavior:
1. `totalPrice = lot.price ?? 0.0` (price snapshot), `financedAmount = totalPrice - downPayment`.
2. `monthlyPayment` via `AmortizationService` for installment; `0.0` for cash.
3. `saleSeq` via existing `_nextSaleSeq(soldDate.year)`.
4. Build `LotSaleModel` with `status = LotSaleStatus.active` (never `paidOff` at registration).
5. Build schedule via `AmortizationService.buildSchedule` — **all periods `scheduled`**, including cash (a single period-0 lump-sum at `totalPrice`, status `scheduled`, not paid). Down payment period 0 also `scheduled` when > 0.
6. One Firestore batch:
   - `lot_sales/{saleId}` → sale doc
   - `lot_payments/{period}` → each schedule doc, all `scheduled`
   - `lots/{lotId}` merge: `uid = buyerUid`, `ownerName = buyerName`, `status = occupied`, `price = null` (delist), `updatedBy/updatedAt`
7. Return `saleId` (and `saleSeq`) so the wizard can link multiple lots to one member.

**Not in `registerSale`:** Firebase Auth creation, member record, paid statuses, accounting entries. Those are handled at the wizard confirm step / by Record Payment later.

### Phase B — Wizard state controller

A single controller holding temporary wizard state until confirmation:
- `step` (1..5), `memberDetails` (name, email, contact, address, role), `selectedLots` (list of `LotModel`), `lotPaymentSetup` (map lotId → {saleType, downPayment, termMonths, annualInterestRate, firstDueDate}), `isLoading`, `error`.
- Navigation: Next/Back with field validation before proceeding; step 5 disabled when invalid.
- Reset/clear selections.

No Firestore writes in the controller — pure temp state.

### Phase C — Step 1: Member Details

Form: name, email, contact, address. Validate required fields + email format. Action: **Next** (not Create/Submit). Keep state in controller. No Auth, no member record.

### Phase D — Step 2: Location Mapping

Reuse the existing map/grid lot list (`LocationMappingScreen` patterns). Show eligible vacant/for-sale lots. Tap a lot → details modal (phase, block, lot number, area, status, selling price, pricing basis as "standard" / pending). **Select Lot** → close modal, highlight lot, add to selected-lots list. Multi-select supported; remove individual; clear all; proceed disabled when none selected.

Revalidate availability at confirm (step 5), not at selection.

### Phase E — Step 3: Payment Setup

Two-column layout (wide) / stacked (narrow). Each selected lot gets independent payment mode:
- **Cash:** show full amount due; no installment schedule; not marked paid.
- **Installment:** collect agreed down payment, annual interest rate, term months, first due date. Show total price, down payment, financed amount, monthly amortization, schedule summary (via `AmortizationService`).

Different lots may use different modes.

### Phase F — Step 4: Finance Preview (draft T-account)

Read-only. Show: member summary, every selected lot, price + pricing basis per lot, payment mode per lot, down payment + financed amount (installment), monthly amortization + term (installment), combined totals. Draft label: "Provisional Sales Invoice / Payment Agreement Preview". No accounting posts.

The T-account = per-lot remaining balance = `totalPrice` minus sum of paid periods (none paid yet at registration, so balance = financed amount / total price). Computed at display time from `lot_sales` + `lot_payments`.

### Phase G — Step 5: Confirm Registration

Revalidate before writing:
- Required member details
- Duplicate email / unique identifiers
- Lot eligibility + current availability (re-check close to write)
- Duplicate lot IDs in selection
- Current pricing + price snapshots
- Installment calculations + schedule inputs

After validation, create records:
1. Firebase Auth user (secondary App pattern, email verification) — if account model requires one.
2. Member record (`users/{uid}` or `members/{uid}` per existing convention) → Active.
3. One `lot_sales` per selected lot via `registerSale`.
4. Lot → member link (`lots.uid = buyerUid`) — inside `registerSale` batch.
5. Installment schedule records only for installment lots — inside `registerSale`.
6. No paid payment records.

**Failure recovery:** if Auth succeeds but Firestore batch fails, record the pending registration (e.g. a `pending_registrations` doc or surface a retryable error with the created Uid) so it can be reconciled — do not leave a silent half-created registration. Prevent duplicate confirmation taps (loading state + disabled button).

---

## Files to touch / create

**Create:**
- `web-admin/lib/features/members/screens/member_registration_wizard.dart` — wizard shell + step controller + all 5 steps (one file, matching the doc's single-wizard intent; split later only if it grows).

**Edit:**
- `web-admin/lib/core/services/sale_service.dart` — add `registerSale` (no change to `recordSale`).

**No edits to:** `AmortizationService`, `RateService`, `LotService`, models, `location_mapping_screen.dart`, `lot_dialogs.dart`, `members_screen.dart`, `member_detail_screen.dart`.

---

## Definition of done

1. Add Member opens at Member Details; first action is Next (no account created).
2. Member details persist across Back/Forward navigation.
3. Map shows eligible vacant/for-sale lots; lot details modal shows available info.
4. Select Lot closes modal, highlights lot, adds to selected list.
5. Multiple lots selectable; individual remove + clear-all supported.
6. Proceed disabled when no lot selected.
7. Payment Setup lists every selected lot; each independently Cash or Installment.
8. Installment inputs compute financed amount + monthly amortization; cash gets no schedule.
9. Finance Preview shows per-lot details + combined totals; read-only; no accounting posts.
10. Confirm revalidates member data + lot availability; creates one `lot_sales` per lot; schedules only for installment lots; nothing marked paid.
11. Duplicate taps and concurrent lot selection handled safely; failed registration is retryable/reconcilable.
12. Existing member/lot/payment workflows unchanged (regression: `recordSale`, Record Payment, closeout, statements all still work).

---

## Open / pending (do not invent — flag to the HOA/finance reviewer)

- Rate per sqm (already configurable via `RateService`; confirm current value).
- Which lots qualify for special pricing + who approves exceptions (pricing-basis field not yet modeled).
- Lot status lifecycle beyond `vacant / forSale / reserved / occupied`.
- Approved interest rate rules; minimum down payment; approved installment terms; first-due-date rules.
- Amortization formula / rounding policy (already implemented in `AmortizationService` — confirm it matches the approved rule).
- Roles permitted to register members and activate members.
- Required audit history + document retention.
