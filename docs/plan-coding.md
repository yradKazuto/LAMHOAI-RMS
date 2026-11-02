# Coding Plan — Payment Scheme Overhaul

**Date:** 2026-10-28
**Source:** built from `flow-payment-scheme.md` (flows 01–12) and `plan-payment-overhaul.md` (requirements/decisions).
**Rule that shapes this plan:** code the **Core** spine first in small vertical slices; build the **Optional** features as separate, removable modules (own screen/tab + own service method) so that after the company/presenter interview, anything that doesn't fit is deleted cleanly without touching the rest.

## How each flow maps to code

| Flow | Module (service) | Screen (UI) | Tier |
|---|---|---|---|
| 01 Set default rate | `RateService` (or extend `RateHistoryService`) | Settings → Lot Pricing | **Core** |
| 02 Price a lot / mark for sale | `LotService` + pricing config | Location map → lot dialog | **Core** |
| 03 Cash sale | `SaleService` | Lot dialog → Record Sale | **Core** |
| 04 Installment sale + schedule | `SaleService` (amortization math) | Lot dialog → Record Sale | **Core** |
| 05 Record payment | `SaleService`/`PaymentService` | Payments → Record Payment | **Core** |
| 06 Overdue + penalty | display-time helper | Payments lists / lot dashboard | **Core** |
| 09 Paid off → Deed | `SaleService` | Lot dashboard / sale detail | **Core** |
| 12a Register via map | `AuthService` + `MemberService` | Members → Add Member | **Core** |
| 07 Cancellation (R.A. 6552) | `SaleService` (closeout) | Lot dashboard | Optional |
| 08 Resale / transfer | `SaleService` (assume/restructure) | Payments → Transfer tab | Optional |
| 10 Reports preview/export | existing reports + dataset fn | Reports screen | Optional |
| 11 Promissory note / docs | `DocumentService` (PDF) | Sale detail | Optional |
| 12b Member self-registration | `AuthService` | Mobile → Create account | Optional |

## Build order at a glance (phases)

```
Phase 0  Models + math foundation         (no UI)
Phase 1  Flow 01–02  rate + lot pricing   (Core)
Phase 2  Flow 12a    register via map      (Core)
Phase 3  Flow 03–04  sales + schedule      (Core)   ← big milestone
Phase 4  Flow 05–06  payments + overdue    (Core)
Phase 5  Flow 09     paid off → deed       (Core)
Phase 6  Optional 07 / 08 / 10 / 11 / 12b  (build to present, removable)
Phase 7  Reports + mobile views            (Optional-depth)
Phase 8  Acceptance tests + interview prep
```

---
## Phase 0 — Foundation: models + math (no UI yet)

**Create the new data models** (mirror the flow doc):

1. `web-admin/lib/core/models/sales_rate_model.dart`
   - `SalesRateModel`: `ratePerSqm`, `updatedBy`, `updatedAt`.
2. `web-admin/lib/core/models/lot_sale_model.dart`
   - `LotSaleModel`: `lotId`, `lotNumber`, `phase`, `block`, `buyerUid`, `buyerName`, `saleType` (`cash`|`installment`), `totalPrice`, `downPayment`, `financedAmount`, `termMonths`, `annualInterestRate`, `monthlyPayment`, `status` (`active`|`paidOff`|`cancelled`|`assumed`), `soldDate`, `createdBy`, `updatedAt`.
3. `web-admin/lib/core/models/lot_payment_model.dart`
   - `LotPaymentModel`: `saleId`, `lotId`, `period`, `transactionId`, `dueDate`, `amount`, `principalPortion`, `interestPortion`, `remainingBalance`, `status` (`scheduled`|`paid`|`overdue`|`waived`|`void`), `paidAt`, `paidBy`, `createdAt`.
4. Extend `LotModel` (`lot_model.dart`) with sale-facing fields if needed (`lots.uid` already exists for owner).

**Create the math + ID services** (pure, unit-tested):

5. `web-admin/lib/core/services/amortization_service.dart`
   - `double monthlyPayment(principal, annualRate, months)`
   - `List<LotPaymentModel> buildSchedule(sale, firstDueDate)` — generates every period with principal/interest/balance split; last period adjusts the balance to exactly 0.
6. `web-admin/lib/core/services/transaction_id_service.dart`
   - `String nextTransactionId(int year, int saleSeq, int period)` → `LP-2026-001-007`.

**Tests first** (`web-admin/test/`):
- Schedule sums exactly to `financedAmount`; balance ends at 0; zero-interest case = equal payments; monthly-payment formula spot-checks.

---

## Phase 1 — Flow 01–02: rate + lot pricing (Core)

1. **Settings screen** (`features/settings/screens/settings_screen.dart`): add "Price per sqm" field → save `sales_rate/config` via a new `RateService`.
2. **Lot dialog** (`features/location/widgets/lot_dialogs.dart`): when "Mark For Sale" is tapped, read the rate, compute `price = areaSqm × rate`, show a preview (`120 sqm × ₱2,000 = ₱240,000`), and gate on a yes/no confirm (per the adviser convention).
3. **`LotService`** (`core/services/lot_service.dart`): `markForSale(area, rate)` computes and stores `price`; keep `delist` and the existing status transitions.

**Definition of done:** a vacant lot can be priced and marked for sale from the map, and the price is always derived, never hand-typed.

---
## Phase 2 — Flow 12a: registration + linking member to lot via map (Core)

**Trigger:** Admin → Members → Add Member.

1. **UI:** Replace free-text `lotNumber`/`phase`/block fields with a map-picker UI: show available lots (not owned / not sold) searchable by phase·block·lot. Admin picks one lot; `phase`, `block`, `areaSqm` auto-fill from the lot — no hand-typed lot numbers.
2. (Write) `members/{uid}`: `displayName`, `email`, `status` (active/pending, per choice), `contactNumber`, `address`, `lotNumber`, `phase`.
3. (Write) `lots/{lotId}`: `uid = memberUid`, `ownerName = memberName`.
4. Create Firebase Auth account + send email verification (reuse existing auth flow from `user_management_screen.dart`/`members_screen.dart`).

**Why this comes early:** your panelist flagged it as the key registration fix. Coding it first proves the map↔member link works before money touches it.

**Definition of done:** selecting a lot on the map creates a member assigned to exactly one lot; lots screen shows owner; map pin shows owner.

---

## Phase 3 — Flow 03–04: record sale + auto-generate schedule (Core)

### Flow 03 — Cash sale (single payment, no schedule)
1. From the For-Sale lot dialog, admin picks buyer, mode = Cash.
2. (Write) `lot_sales/{id}` with `saleType='cash'`, `financedAmount=0`, `status='active'`.
3. (Write) `lot_payments/{period}` — one record: `transactionId='LP-...-000'`, `amount=totalPrice`, `status='paid'`, `paidAt=now`.
4. (Write) `lot_sales` → `status='paidOff'`, and `lots/{lotId}` status → `occupied`.

### Flow 04 — Installment sale (auto schedule)
1. Admin picks buyer, down payment, term months, interest rate.
2. Use the **amortization service** (Phase 0) to compute `monthlyPayment` and generate N periods.
3. (Write) `lot_sales/{id}` with the full sale breakdown: `totalPrice`, `downPayment`, `financedAmount`, `termMonths`, `annualInterestRate`, `monthlyPayment`, `status='active'`.
4. (Write) `lot_payments/{period}` — one doc per month with `transactionId`, `dueDate`, `amount`, `principalPortion`, `interestPortion`, `remainingBalance`, `status='scheduled'`.
5. If down payment > 0: one `lot_payments` period 0 marked `paid`.
6. (Write) `lot_sales` → `status='occupied'` (lot assigned to buyer).

**Definition of done:** selling a lot auto-creates every future payment record; member's remaining balance is computable from the schedule at any time.

---
## Phase 4 — Flow 05–06: record payments + overdue (Core)

### Flow 05 — Record a payment
1. **UI:** from a sale / member / lot, "Record Payment" with amount, date, method (cash/cheque/bank — cheque/bank stays `pendingVerification` until an officer confirms, per the confirmed direction).
2. **Service** finds the first unpaid period (`saleId` + `status != paid`):
   - Exact → mark `paid`, write `paidAt`, `paidBy`, `transactionId` shown as the receipt ref.
   - Partial → (Decision) HOA policy Q11: accept as a credit/partial on the current period or reject.
   - Overpay → pay current period, roll remainder to the next unpaid period(s) until exhausted.
3. (Write) `payer`/`paymentMethod`/`verifiedAt` for cheque/bank-then-confirm.

### Flow 06 — Overdue (display-only, no silent auto-write)
- `displayStatus`-style getter: `scheduled` whose `dueDate < startOfToday` renders `overdue`. No background job needed initially.
- Penalty (if the HOA opts in after Q13): mark once per period with `penaltyAmount`, keep `status` untouched.

**Definition of done:** a member's remaining balance drops correctly on every posted payment; overdue renders correctly everywhere without any stored-state confusion.

---

## Phase 5 — Flow 09: paid off → Deed of Absolute Sale (Core)

1. (Read) after each payment (Phase 4): sum paid vs balance; (Decision) `All periods paid?` → if yes:
   - (Write) `lot_sales` → `status='paidOff'`, `paidOffAt`.
   - (Write) `lots` stays `occupied` (owner confirmed).
   - Generate/attach Deed (link to the optional DocumentService in Phase 6 / Flow 11) and final zero-balance statement.
2. Ledger mirror: update any `member_ledgers` currentBalance for that lot to 0.

**Definition of done:** completed sales close cleanly with a zero balance and an issued deed, and the full payment trail stays viewable.

---
## Phase 6 — Optional modules (build to present; removable)

These are decoupled enough to delete after the interview if the company doesn't use them.

### Flow 07 — Cancellation / default (R.A. 6552)
- `SaleService.closeoutSale()` → sets `status='cancelled'`, writes `refundAmount`, marks unpaid periods `void`.
- Interleave with overdue UI (Flow 06) and relist lot for sale (Flow 02).
- **Removable:** delete the closeout button + voiding logic without touching core payments.

### Flow 08 — Transfer / mid-term resale (Option A/B/C)
- `SaleService.transferLot(lotId, newBuyer)` → updates `lot_sales.buyerUid`, `lots.uid`; re-generates schedule (Option B) or keeps it (Option A).
- **Removable:** the transfer tab on Payments/Lot dashboard.

### Flow 10 — Reports (preview then export)
- Extend `reports_screen.dart` to read from `lot_payments` + `lot_sales` instead of only legacy `payments`.
- Dataset function shared by preview + export; CSV/PDF render via existing `printing` package.
- **Removable:** report screens; keep core collection writes untouched.

### Flow 11 — Promissory note / documents
- `DocumentService` generates PDF schedule + promissory note; stores under `lot_sales/{id}`.
- **Removable:** document upload/display only; doesn't break payment math.

### Flow 12b — Member self-registration (mobile)
- Mobile `Create an account` wizard → `status='pending'` → admin approval queue → `active`.
- **Removable:** keep admin-only member creation (Flow 12a) if company rejects self-register.

**Definition of done:** each optional is one screen + one service path; removing it leaves Core untouched.

---

## Phase 7 — Reports + mobile views (optional depth)

**Reports (web-admin):**
- Add per-sale statement preview (transaction IDs, principal/interest, balance).
- CSV + PDF export from the same dataset function (preview parity).

**Mobile app:**
- Member-facing statement preview: transaction IDs, paid/next-due, remaining balance.
- No changes to membership/dues screens (per "let membership the same").

---

## Phase 8 — Acceptance tests + interview prep

1. **Acceptance examples** (from the plan): standard pricing, cash sale, installment schedule, pending cheque/bank transfer, partial payment, overpayment, overdue status, paid-off sale.
2. **Interview go/no-go:** run Section 10 (Q1–Q36) with the company; mark each flow confirmed or trimmed.
3. **Trim:** delete any Optional module the company doesn't use; re-run Core tests; demo.

**Final milestone:** all Core flows work end-to-end (rate → mark for sale → register → sell → pay → pay off → deed), and Optional features are either confirmed kept or deleted cleanly.

---

## Flow 13 — Bulk lot area update (admin, initial data entry)

**Trigger:** Admin → Location Mapping → "Bulk Upload" → Upload CSV (cols: `phase`, `block`, `lotNumber`, `areaSqm`).

1. (Read) `lots` collection.
2. (Decision) `Is CSV format valid?`
   - **No** → Show error, return to upload. End.
   - **Yes** → continue.
3. (Process) Match CSV row to `lots` doc (via Phase+Block+LotNumber).
4. (Decision) `Are all lots found?`
   - **No** → Show list of missing lots (to fix/retry). End.
   - **Yes** → continue.
5. (Decision) `Is areaSqm > 0?`
   - **No** → show row-level error. End.
   - **Yes** → continue.
6. (Write) Batch update matched `lots/{id}`: `areaSqm = row.areaSqm`, `updatedAt`, `updatedBy`.

---

## Flow 01b — Set/Activate tiered rates (admin)

**Trigger:** Settings → Rate History.

1. Admin adds a new year (e.g. 2027) with rates for 120sqm+ and below-120sqm tiers.
2. (Write) `rate_schedules/{year}`: `rate120sqmPlus`, `rateBelow120sqm`, `isActive=false`.
3. (Decision) `Is the new year ready to activate?`
   - **No** → keep `isActive=false` (Draft).
   - **Yes** → (Write) `rate_schedules/{year}`: `isActive=true`, and update all `lot_sales` (installment records) to recalculate future months based on the new tiered rate.

**Logic:** only the `active` schedule for the current year is used for pricing.




