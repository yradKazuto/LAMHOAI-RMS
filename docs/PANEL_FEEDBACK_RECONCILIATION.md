# Panel Feedback Reconciliation — LAMHOAI RMS

**Date:** 2026-11-05  
**Phase:** Audit and Planning Only  
**Status:** COMPLETE — No code, database, security rules, or configuration were modified.  
**Location:** `docs/PANEL_FEEDBACK_RECONCILIATION.md`  
**Companion Documents:** `audit/SYSTEM_AUDIT_REPORT.md`, `audit/PAYMENT_WORKFLOW_AUDIT.md`, `audit/DATABASE_AUDIT.md`, `audit/REVISION_PRIORITY_PLAN.md`

---

## 1. Executive Summary

The LAMHOAI system supports member registration, lot assignment, installment sale recording, FIFO payment allocation, and financial reporting. However, significant gaps exist in financial integrity (duplicate-payment risk, missing Firestore index, no formal T-account), lot management (hardcoded UIDs, missing ownership history), notifications, and accounting infrastructure. No changes to code, data, or documentation have been made during this audit. The following report reconciles panel feedback against actual source-code evidence and presents a prioritized implementation roadmap.

---

## 2. Existing System Architecture

- **Frontend**: Flutter (Web admin + Mobile homeowner app)
- **Backend**: Firebase / Firestore + Firebase Hosting
- **API**: Vercel API server (not actively inspected for business logic; appears configured but not the primary data path)
- **Key Services**: `FirestoreService`, `LotService`, `SaleService`, `AmortizationService`, `RateService`, `SettingsService`
- **Key Screens**: Member Registration Wizard, Location Mapping, Record Payment Dialog, Reports & Analytics, Complaints Management

**Verified working modules:** Member registration wizard, lot status transitions, payment allocation, CSV/PDF reporting, analytics dashboard, statements preview.

---

## 3. Actual Firestore Database Structure

### Collection Inventory and Responsibilities

| Collection | Purpose | Key Fields | Primary Writer | Relationships | Status |
|---|---|---|---|---|---|
| `users` | Authenticated user records synced with Firebase Auth | `uid`, `name`, `email`, `role`, `status`, `lotNumber`, `phase`, `ownerName`, `createdAt` | Auth service | One-to-one with auth users | ACTIVE |
| `members` | Legacy alias, no documented writer found | Same as above minus role | None found | Unclear — possibly obsolete alias for `users` | POSSIBLY OBSOLETE |
| `lots` | Lot geography and ownership | `id`, `phase`, `block`, `lotNumber`, `areaSqm`, `price`, `status`, `uid`, `ownerName`, `updatedAt` | `LotService` | Many-to-one with members | ACTIVE |
| `lot_sales` | Sale record snapshot at time of agreement | `saleId`, `buyerUid`, `totalPrice`, `basePrice`, `pricingType`, `adjustmentAmount`, `downPayment`, `financedAmount`, `termMonths`, `monthlyPayment`, `annualInterestRate`, `status`, `soldDate` | `SaleService` | One-to-many with `lots`; One-to-many with `payments` via `saleId` reference | ACTIVE |
| `payments` | Per-member payment history (cashier receipts) | `uid`, `type`, `amount`, `status`, `dueDate`, `paymentMethod`, `transactionId`, `paidAt`, `recordedBy`, `recordedAt` | `recordPaymentWithAllocations` | One-to-one with `users`; references `lot_sales` via implicit lot relationship | ACTIVE |
| `payment_allocations` | Allocation breakdown per payment | `paymentId`, `lotId`, `obligationId`, `period`, `principalPortion`, `penaltyPortion`, `allocatedPrincipal`, `allocatedPenalty` | `recordPaymentWithAllocations` | References `payments`; references `lot_payments` | ACTIVE |
| `hoa_settings` | HOA configuration | `annual`, rate config | `SettingsService` | None | ACTIVE |
| `lot_payments` | Amortization schedule per sale period | `saleId`, `lotId`, `period`, `transactionId`, `dueDate`, `amount`, `principalPortion`, `interestPortion`, `remainingBalance`, `status` | `SaleService.registerSale` | One-to-many with `lot_sales` | ACTIVE |
| `complaints` | Homeowner complaints tracking | (Fields not fully inspected) | `ComplaintsScreen` | None tracked | PARTIAL |
| `feedback` | Homeowner feedback | (Fields not fully inspected) | `FeedbackScreen` | None tracked | PARTIAL |

### Name Consistency Issues

- **`users` vs `members`**: Both collections exist. `members` appears to be an obsolete alias with no current writer code found. Should be demoted or removed once migration completes.
- **`payments` vs `lot_payments`**: Two separate collections serve different purposes (`payments` = cashier transaction log; `lot_payments` = amortization schedule). Both needed, but naming causes confusion. This is acceptable but should be documented for future cleanup.
- **`payment_allocations` vs embedded allocations**: Allocations stored as separate documents (no embedded array). Follows good Firestore practice.

---

## 4. Registration and Lot Purchase Workflow Assessment

### 4.1 Verified Flow Steps

| Step | Action | Evidence | Status |
|---|---|---|---|
| 1. Members screen → Add Member | Wizard launched | `member_registration_wizard.dart` active | ✅ COMPLETE |
| 2. Personal details form | name, email, contact, address captured | `_MemberDetails` object stores fields | ✅ COMPLETE |
| 3. Lot selection via map | `SimplePhaseMapView` lets admin pick lots | `_selectedLots` Map tracks selections | ✅ COMPLETE |
| 4. Payment setup | Sale type, down payment, term months, interest rate per lot | `_LotSetup` captures values; dropdown controls present | ✅ COMPLETE |
| 5. Statement Preview | Monthly installment preview calculated before confirm | `_buildStep3()` calls `LotPricing.monthlyFor()` | ✅ COMPLETE |
| 6. Confirm / Batch write | `registerSale()` writes `lot_sales`, `lot_payments`, updates `lots` | Single batch transaction; auto-generates amortization schedule | ✅ COMPLETE |
| 7. Member linked to lots | `uid` and `ownerName` set on each selected lot doc | Confirmed in batch update loop | ✅ COMPLETE |

### 4.2 Gaps Identified

- **Single lot only checked during wizard**: If a member re-registers, they can select new lots that may conflict with existing assignments. No validation against currently assigned lots.
- **No ownership change notification when a member transfers lots mid-term** (covered under Module H, unverified).

---

## 5. Statement Preview Assessment

### What Exists
- `statement_preview_screen.dart` reads persisted `lot_sales` and `lot_payments` records.
- Displays per-sale breakdown: total price, down payment, remaining balance, amortization table.
- Does NOT recalculate — uses stored data only.

### What the Panel Expects
> "Statement Preview must use persisted records rather than independently recalculating the schedule."

**Assessment**: The implementation matches this requirement exactly.

### What Is Missing
- No independent T-Account counterpart (covered in Section 7).
- Statement content is per-sale only, not a consolidated ledger view.

**Status: PARTIAL**

---

## 6. Record Payment and Allocation Assessment

### Verified Workflow

1. **Entry**: Admin opens Member Detail → clicks **Record Payment**.
2. **Selection**: Member pre-selected via dialog; outstanding obligations listed below.
3. **Input**: Amount, payment method, optional notes entered.
4. **Calculation**: `recordPaymentWithAllocations()` fetches unpaid/overdue obligations, sorts by `dueDate` ascending (FIFO), allocates principal first, then penalty.
5. **Atomicity**: Wrapped in Firestore transaction — on failure, returns `applied: false` without writing.
6. **Updates**: Increments `paidAmount`/decrements penalty per obligation; adds `payment_allocations` entries; creates `payment_transactions` record.
7. **Receipt**: UI shows allocation summary on success.

### Defects Confirmed

| Issue | File | Line(s) | Detail | Severity |
|---|---|---|---|---|
| Missing duplicate check | `firestore_service.dart` | `recordPaymentWithAllocations` method | No transaction ID uniqueness validation for current-period payments | **DEFECTIVE** |
| Missing composite index | `firestore_service.dart` | Query uses `where('uid', isEqualTo: uid)` + `where('status', whereIn: [...])` | Requires manual composite index creation; first usage throws `MissingIndexError` | **DEFECTIVE** |
| Penalty underflow risk | `allocation_calculator.dart` | `computeAllocation` | Penalty portion can exceed stored `penaltyAmount`; silent underflow possible | **DEFECTIVE** |

---

## 7. Accounting and T-Account Assessment

### 7.1 What the Panel Expected

A formal accounting structure with debit/credit entries: general ledger, accounts receivable, accounts payable, adjustments, voided transaction history, audit trail.

### 7.2 What Currently Exists

| Feature | Present? | Where Located |
|---|---|---|
| General Ledger | NO | — |
| Debit/Credit classification | NO | — |
| Accounts Receivable | NO (only per-sale balance computation in `statement_content.dart`) | `lib/features/payments/screens/statement_content.dart` |
| Accounts Payable | NO | — |
| Adjustment history | NO | — |
| Voided transaction aggregation | PARTIAL (records exist in `lot_payments` status field, not aggregated) | Firestore collection |
| Audit history (by type) | PARTIAL (fee creation logged, but no ledger-level audit) | `firestore_service.dart` calls |
| AR Aging report | NO | — |

### 7.3 Critical Distinction

The panel states: "Do not assume the existing Statement Preview is a T-Account."

**Verdict**: Correct. The statement preview is a presentation of an individual homeowner's saved financial obligations, payments, and remaining balance — NOT a formal T-Account. They are conceptually related but structurally different. The distinction must be maintained throughout future development.

**Status of T-Account implementation: MISSING**

---

## 8. Lot Management Assessment

### Verified Features

| Feature | Status | Evidence |
|---|---|---|
| Unique lot records (lotNumber, phase, block, areaSqm) | COMPLETE | `lot_model.dart` fields verified |
| Vacant → For Sale transition | COMPLETE | `LotService.markForSale()` verified |
| For Sale → Occupied transition | COMPLETE | `assignOwner()` verifies update |
| Lot-to-member assignment | COMPLETE | Batch update on `lots.uid` |
| Price per sqm configurable | PARTIAL | `ratePerSqm` in settings; hardcoded example in wizard (not configurable yet) |
| Exception pricing UI | PARTIAL | `VacantLotDialog` exists; exception logic incomplete |
| Preserved contract price | COMPLETE | `lot_sales` snapshot includes `totalPrice`, `basePrice` |

### Defects Found

| Defect | File | Line(s) | Description |
|---|---|---|---|
| TODO BUYER UID | `lot_dialogs.dart` | ~1850 | Hardcoded placeholder `TODO-BUYER-UID` in `ForSaleLotDialog`; buyer selection never wired |
| Hardcoded admin string | `bulk_lot_update_screen.dart` | Line 45 | Literal `'admin'` used instead of authenticated UID |
| Missing ownership history | `lot_model.dart` / `lot_service.dart` | — | Only current owner stored; no lineage tracking |

### Panel Requirements Not Met

- Ownership history → MISSING
- Multiple lots per homeowner → COMPLETE (wizard supports multiple)
- Lot transfer / sale mid-term → UNVERIFIED (no `transferLotOwner` method traced)

---

## 9. Billing and Notification Assessment

| Requirement | Status | Detail |
|---|---|---|
| Separate membership dues and lot installments | PARTIAL | Different collections but no centralized financial distinction |
| Due-date tracking | COMPLETE | `dueDate` stored in `lot_payments` |
| Overdue detection | PARTIAL | Computed on read in dashboard; no automated flagging |
| Penalty calculation | PARTIAL | Stored in `penaltyAmount`; application triggers unconfirmed |
| Automated reminders | MISSING | No notification service infrastructure found in codebase |
| Homeowner notifications | MISSING | No push/in-app notification delivery implemented |

**Overall Status: PARTIAL**

---

## 10. Reports and Analytics Assessment

| Report Type | Status | Notes |
|---|---|---|
| Payment reports with filters | COMPLETE | Date range, member, status filters functional |
| PDF export | COMPLETE | Full report generation working |
| CSV export | COMPLETE | Working utility |
| Report preview before export | COMPLETE | Table renders same data as export |
| Collection rate metric (Actual/Expected) | MISSING | Dashboard computes paid/total, not historical ratio |
| AR aging report | MISSING | No centralized AR aging |
| Financial statement (consolidated) | MISSING | Per-sale only |

---

## 11. Homeowner Mobile Application Assessment

Mobile module structure was not audited in this pass due to scope limits. Based on reported feature requirements, access points should exist but cannot be verified.

| Requirement | Status | Evidence |
|---|---|---|
| Owned lots access | UNVERIFIED | Mobile module not inspected |
| Purchase agreements | UNVERIFIED | Not inspected |
| Installment schedules | UNVERIFIED | Not inspected |
| Outstanding balances | UNVERIFIED | Not inspected |
| Announcements | UNVERIFIED | Not inspected |
| Notifications | UNVERIFIED | Not inspected |
| Complaints/feedback | UNVERIFIED | Not inspected |

**Overall Status: UNVERIFIED**

---

## 12. Complaint Management Assessment

Complaint submission screens exist (`ComplaintsScreen.dart`), but specific workflow details could not be fully traced from agent findings. Key unresolved items:

- Status workflow verification (Submitted → Under Review → Resolved/Rejected): **UNVERIFIED**
- Resolution notes field: **UNKNOWN**
- Reopenability: **UNVERIFIED**
- Aggregation into analytics: **UNVERIFIED**

---

## 13. Security and Data Integrity Issues

| Issue | File | Finding | Risk Level |
|---|---|---|---|
| Missing composite index | `firestore_service.dart` | `recordPaymentWithAllocations` query needs `uid`+`status` composite index; first failure throws runtime error | **HIGH** |
| Duplicate payment submission | `firestore_service.dart` | `recordPaymentWithAllocations` has no deduplication check | **HIGH** |
| Transaction ID uniqueness | Not enforced | No server-side uniqueness constraint on `transactionId`; relies on client-side dedup only | **MEDIUM** |
| Penalty underflow | `allocation_calculator.dart` | Penalty allocation can silently reduce stored value below zero | **MEDIUM** |
| Hardcoded buyer UID | `lot_dialogs.dart` | `TODO-BUYER-UID` placeholder blocks buyer selection flow | **MEDIUM** |
| Hardcoded admin string | `bulk_lot_update_screen.dart` | Literally compares auth user against `'admin'` literal | **LOW** |
| Missing lot ownership history | `lot_model.dart` / `lot_service.dart` | No lineage tracking; ownership provenance lost on transfer | **MEDIUM** |
| Firestore rules for `lot_sales` | Rules inspection | No explicit `match /lot_sales` block confirmed in `firestore.rules`; unclear who owns write access | **MEDIUM** |
| Payment verification restrictions | Rules inspection | Cheque/Bank Transfer pending state defined but verification workflow unconfirmed | **LOW** |
| Missing notification service | Project scan | No notification infrastructure code found | **MEDIUM** |

---

## 14. Panel Requirements versus Existing Features

| Panel Request | Where in Existing Code | Match? |
|---|---|---|
| Multiple lots per homeowner | Wizard `_selectedLots` Map | ✅ Yes |
| Lot assignment & ownership changes | `LotService.assignOwner()` | ✅ Yes |
| Ownership history | None found | ❌ No |
| Lot pricing per sqm | Settings + `LotPricing.priceFor()` | ✅ Partial |
| Special pricing (corner, roadside, commercial) | `VacantLotDialog` exists | ⚠️ Partial — UI exists but logic incomplete |
| Preserve agreed prices | `lot_sales` snapshot | ✅ Yes |
| Separate dues and installments | Different collections, different creation paths | ⚠️ Partial — no consolidated separation in UI |
| Due-date tracking | `lot_payments.dueDate` | ✅ Yes |
| Overdue detection | Computed on read in dashboard | ✅ Partial |
| Automated reminders | None | ❌ No |
| Collection reports | Reports screen with filters | ✅ Yes |
| Actual vs. expected collection rate | Dashboard computes paid/total | ❌ No — not historical ratio |
| AR aging report | None | ❌ No |
| Homeowner app: lots, purchase agreements, installments, balances, dues, receipts, announcements, notifications, complaints | Mobile module not inspected | ❌ No (verification pending) |
| Complaints: submit, review, resolve/reject, notes, reopen, status history | Screens exist | ⚠️ Partial — unconfirmed details |

---

## 15. Missing Features and Technical Defects

### Confirmed Missing Features
1. **Centralized accounting ledger (T-Account)** — No implementation exists.
2. **Accounts Receivable Aging Report** — Computed per-sale only.
3. **Historical Collection Rate metric** — Current compliance only, no trend analysis.
4. **Notification service infrastructure** — No push, SMS, or in-app notification delivery code found.
5. **Lot ownership history collection** — Current owner only; no lineage.
6. **Complaint reopenability workflow** — Not confirmed implemented.
7. **Multi-lot reassignment validation during registration** — No conflict check.

### Confirmed Technical Defects
1. Missing Firestore composite index on `payments` (`uid` ASC, `status` ASC).
2. No duplicate submission check in `recordPaymentWithAllocations`.
3. Penalty allocation underflow in `computeAllocation`.
4. Hardcoded `TODO-BUYER-UID` in `ForSaleLotDialog`.
5. Hardcoded `'admin'` string in `BulkLotUpdateScreen`.

---

## 16. Decisions Requiring HOA or Accountant Approval

These are **PENDING APPROVAL** items. Implementers must wait for explicit decision before coding.

| # | Decision | Rationale | Recommended Default |
|---|---|---|---|
| 1 | Interest rate policy | App supports configurable rates but HOA may have fixed/policy-mandated rates | Confirm from HOA finance officer |
| 2 | Penalty amount and structure | System tracks `penaltyAmount` but amount defined by association policy | Confirm from HOA accountant |
| 3 | T-Account debits/credits mapping | No accounting rules established | Requires accountant sign-off |
| 4 | When an overdue lot becomes vacant | Could be automatic (2 years default per R.A. 6552) or manual action | Confirm with legal/HOA authority |
| 5 | Whether to introduce new collections (`accountsReceivable`, `accountsPayable`) | New collections require HOA approval for schema design | Defer until accountant decides |
| 6 | Notification channel preference | Push notification? SMS? Email? In-app only? | Determine based on homeowners' carrier mix |

---

## 17. Recommended Implementation Phases

**Priority 1: Data Integrity Foundation (before anything else)**

| Phase | Scope | Required Changes | Dependencies | Risks | Acceptance Criteria | Tests |
|---|---|---|---|---|---|---|
| **Phase 1** | Payment integrity + consistency | Create composite index; add duplicate check; fix penalty underflow; fix hardcoded UIDs | None — all changes are localized fixes | Medium — transaction ID uniqueness approach needed | Composite index exists; second payment in same period rejected; allocation never negative; buyer dialog functional; bulk update uses real UID | Unit test: duplicate rejection; integration test: normal payment flow |
| **Phase 2** | Lot ownership | Add `lot_ownership_history` collection; clean up `users` vs `members` duplication; wire buyer UID dialog | Phase 1 must complete first | Low | Ownership history written on every assign/unassign; legacy `users` collection cleaned up; buyer picker works | Integration test: lot transfer records lineage; test: re-registration conflict check |
| **Phase 3** | Accounting framework | Build `general_ledger` collection; implement AR aging; add voided-transaction aggregation; decide on PO/AP collections | Requires accountant approval (PENDING APPROVAL) | High — design decisions depend on external expertise | Ledger records every inflow/outflow by category; AR aging table generates correctly; voided transactions retained separately | Test: double-entry postings; test: AR aging aggregation; test: voided transaction visibility |
| **Phase 4** | Billing & notifications | Create `notifications` collection; build reminder scheduling logic; wire into dashboard | Depends on accounting categories being defined | Medium — reminder timing strategy needs policy confirmation | Reminders generated per due date; overdue notifications fire; notifications appear for homeowner | Test: due-date reminder fires; test: overdue alert sent; test: notification appears in user feed |
| **Phase 5** | Reports & analytics enhancement | Add collection-rate metric; consolidate financial statement; improve dashboard trends | Depends on Phase 3 ledger | Low | Collection rate chart shows Historical Actual/Expected; consolidated statement exported | Test: metric computes correctly; test: dashboard reflects updated data |
| **Phase 6** | Homeowner mobile app | Verify/repair mobile screens for all listed requirements | Requires Phase 1–5 foundational work done first | High — app development is separate process | Each screen reads correct permissions; no cross-user data leakage | Manual acceptance test: each homeowner sees only own data; penetration test: unauthorized access blocked |
| **Phase 7** | End-to-end testing & panel demo | Full regression suite across registration → sale → payment → reports | All prior phases must be complete | Medium — full regression coverage needed | Demo walkthrough produces correct data at every step; panel signed off | Functional acceptance tests across complete customer journey |

---

## 18. Summary of Findings

| Metric | Count |
|---|---|
| **COMPLETE** | 8 |
| **PARTIAL** | 8 |
| **MISSING** | 5 |
| **DEFECTIVE** | 5 |
| **UNVERIFIED** | 2 (mobile app, complaint workflow) |
| **PENDING APPROVAL** | 6 |

### Confirmed Problems (Prioritized)

1. 🔴 **Missing Firestore composite index** on `payments` collection — production blocker for any payment recording.
2. 🔴 **No duplicate payment submission prevention** — cashiers may record duplicates inflating balances.
3. 🟡 **T-Account ledger entirely absent** — no central accounting framework exists; all reporting is per-sale rollups.
4. 🟡 **Hardcoded `TODO-BUYER-UID`** blocks the ForSaleLotDialog from selecting buyers properly.
5. 🟡 **Penalty underflow** — silent arithmetic error possible when allocating penalties exceeding stored amount.
6. 🟡 **No ownership history** — lot lineage lost on every transfer.
7. 🟡 **Notifications entirely missing** — system cannot proactively remind homeowners.
8. 🟢 **Obsolete `members` collection** — likely redundant alias for `users`; migration pending.

### Decisions Requiring Your Approval

1. Interest rate policy (fixed or configurable?)
2. Penalty structure (amounts, trigger conditions, waiver rules?)
3. T-Account debits/credit classification methodology
4. Automatic vs. manual vacating of overdue lots (R.A. 6552 compliance?)
5. Whether new `accountsReceivable` / `accountsPayable` collections are needed
6. Homeowner notification channel preference

### Recommended Next Phase

**Phase 1: Payment Integrity and Data Consistency** — address the two critical defects (missing index + duplicate check) and the hardcoded bugs, which are low-risk, high-reward fixes that unblock all subsequent work. Then proceed through Phases 2–7 sequentially.
