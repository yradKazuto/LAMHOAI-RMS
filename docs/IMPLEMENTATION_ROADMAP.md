# LAMHOAI RMS — Implementation Roadmap

## Overview
This document presents the prioritized implementation sequence based on findings from the Panel Feedback Reconciliation (`docs/PANEL_FEEDBACK_RECONCILIATION.md`). All phases follow a dependency model: earlier phases must complete before later phases can begin. **No code changes are scheduled during this phase. Approval from the panel is required before any modification.**

---

## Phase 1: Payment Integrity and Data Consistency

**Objective:** Fix confirmed defects that block financial accuracy without touching accounting architecture.

| Item | Description | Files | Risk | Acceptance Criteria | Tests |
|---|---|---|---|---|---|
| 1a | Create Firestore composite index on `payments` (`uid` ASC, `status` ASC) | `firestore_service.dart` (add index creation script) | Low | Index exists in production Firestore; payment query returns immediately | Verify with Firestore emulator query |
| 1b | Add duplicate submission check in `recordPaymentWithAllocations` | `firestore_service.dart`, `record_payment_screen.dart` | Medium | Second payment in same period rejected; UI shows error message | Unit test: duplicate rejection path |
| 1c | Add penalty underflow guard in `computeAllocation` | `allocation_calculator.dart` | Low | `principalPortion` + `penaltyPortion` never exceed obligation capacity | Unit test: boundary values |
| 1d | Replace `TODO-BUYER-UID` placeholder with buyer selection dialog | `lot_dialogs.dart` (ForSaleLotDialog) | Medium | Buyer can be selected through picker; no literal remaining | Integration test: buyer populated |
| 1e | Replace hardcoded `'admin'` with authenticated UID | `bulk_lot_update_screen.dart` | Low | Bulk update operates on correct author identity | Integration test: author ID matches current user |

**Dependencies:** None — all are independent fixes.
**Timeline estimate:** 2–3 days.

---

## Phase 2: Lot Ownership and Pricing

**Objective:** Establish lot ownership lineage; clean up legacy collection duplication.

| Item | Description | Files | Dependencies | Acceptance Criteria |
|---|---|---|---|---|
| 2a | Add `lot_ownership_history` collection | New file `lib/core/models/lot_ownership_model.dart`; batch update in `LotService.assignOwner()` | Phase 1 | Every transfer writes a history document with timestamp, previous owner, new owner | Integration test: transfer records lineage |
| 2b | Remove or demote `members` collection alias | Verify no writer references `members`; migration plan to `users` | Phase 3 (cleanup scope) | Zero active writers to `members` collection after migration | Code search: zero references |
| 2c | Add multi-lot reassignment validation during wizard re-registration | `member_registration_wizard.dart` | None | Re-registration blocks lots already assigned to another member | Integration test: conflict blocked |

**Dependencies:** 2a and 2b done before 2c.
**Timeline estimate:** 3–4 days.

---

## Phase 3: Accounting and Financial Records

**Objective:** Build formal T-Account ledger infrastructure. Requires HOA accountant approval.

| Item | Description | Files | Dependencies | Acceptance Criteria |
|---|---|---|---|---|
| 3a | Define debits/credits classification (PENDING APPROVAL) | Model definitions | Accountant decision | Classification methodology documented and approved | Decision signed by accountant |
| 3b | Create `general_ledger` collection | New models and service | 3a | Each inflow/outflow recorded as debit/credit pair per category | Test: double-entry verification |
| 3c | Implement AR aging report | Report screen using `general_ledger` | 3b | AR aging table shows distinct buckets (current, 1–30d, 31–60d, 61–90d, 90+d) | Unit + integration test |
| 3d | Implement collection rate metric (Actual vs Expected) | `analytics_service.dart` | 3b | Historical ratio computed from actual vs expected totals over configurable windows | Unit test: ratio calculation |
| 3e | Decide whether to introduce `accountsReceivable` / `accountsPayable` | Schema decision | 3a (pending) | Collection needed only if PA exists; otherwise ledger alone suffices | Decision documented |

**Dependencies:** 3a before 3b, 3c.
**Timeline estimate:** 5–7 days (heavy — new collections + reports).

---

## Phase 4: Billing and Notifications

**Objective:** Generate automated reminders and notify homeowners about due dates and overdue items.

| Item | Description | Files | Dependencies | Acceptance Criteria |
|---|---|---|---|---|
| 4a | Create `notifications` collection and notification service | New service file `lib/core/services/notification_service.dart` | 3 (ledger defined) | System can write notifications with due date and status | Integration test: notification written |
| 4b | Build reminder scheduling logic | `notification_service.dart` (scheduler) | 4a | Reminders generated per due date; fire at configured intervals before due date | Test: reminder fires at correct time |
| 4c | Overdue alert generation | `notification_service.dart` | 4a | Alert sent when period past dueDate; penalty flag included | Test: overdue alert triggers |
| 4d | Wire notifications into dashboard widget | `dashboard_screen.dart` or equivalent | 4a, 4b | Active notifications show in app feed | UI test: notifications visible |
| 4e | Homeowner push/SMS preference configuration | Settings screen | None | Homeowner selects delivery channel | UI test: channel selectable |

**Dependencies:** All sub-items depend on ledger being defined (Phase 3).
**Timeline estimate:** 4–6 days.

---

## Phase 5: Reports and Analytics Enhancement

**Objective:** Extend reporting capabilities using the ledger from Phase 3.

| Item | Description | Files | Dependencies | Acceptance Criteria |
|---|---|---|---|---|
| 5a | Consolidated financial statement report | New report type in `reports_screen.dart` | 3 (ledger) | Single report showing all liabilities/assets across all members | Integration test: report aggregates correctly |
| 5b | Improved analytics dashboard trends | `analytics_service.dart` enhancements | 3, 4 | Dashboard shows 90-day, 180-day collection trends, compliance percentages | UI test: trend charts render correctly |
| 5c | Audit trail export for voided transactions | Report generator | 3 (voided transaction aggregation) | Voided payments visible and exportable in audit report | Integration test: voided transactions included |

**Dependencies:** 5a depends on ledger completeness; 5b depends on metrics from 3c.
**Timeline estimate:** 3–4 days.

---

## Phase 6: Homeowner Mobile Application

**Objective:** Ensure homeowners can access all authorized financial information on mobile.

| Item | Description | Files | Dependencies | Acceptance Criteria |
|---|---|---|---|---|
| 6a | Verify/repair owned lots screen | Mobile app screen | 2, 3 | Lists lots with status; shows lotNumber, phase, price | Manual test: lots populate correctly |
| 6b | Purchase agreement view | Mobile screen | 3 | Shows sale details, remaining balance, monthly installments | Manual test: agreement view accurate |
| 6c | Installment schedule display | Mobile screen | 3 | Shows schedule with due dates, amounts, paid status | Manual test: schedule matches server data |
| 6d | Payment history and outstanding balances | Mobile screen | 3 | Lists payments, shows total paid vs total owed | Manual test: balances correct |
| 6e | Membership dues visibility | Mobile screen | 3 | Shows dues balance, payment method | Manual test: dues displayed |
| 6f | Announcements and notifications | Mobile screen | 4 | Homeowner sees relevant announcements and system notifications | Manual test: content matches |
| 6g | Complaints/feedback access | Mobile screen | None | Homeowner sees own submissions and resolution status | Manual test: data scoped to user |

**Dependencies:** All depend on Phases 2–5 foundational work being complete.
**Timeline estimate:** 7–10 days (mobile development cycle; requires dedicated effort).

---

## Phase 7: End-to-End Testing and Panel Demonstration

**Objective:** Full regression suite covering complete customer journey; panel sign-off.

| Item | Description | Acceptance Criteria |
|---|---|---|
| 7a | Full customer journey test cases | Registration → Sale → Schedule → First Payment → More Payments → Reports → Notifications → All balances correct |
| 7b | Negative scenarios | Duplicate payments rejected; oversized allocations flagged; empty obligations handled gracefully |
| 7c | Security penetration test | No cross-user data leakage; unauthorized screens return 403-equivalent responses |
| 7d | Compliance check | All FICO/local tax filing requirements met for reported amounts |
| 7e | Panel walkthrough demo | Walkthrough produces verified correct data at every step |

**Dependencies:** All prior phases must be complete.
**Timeline estimate:** 3–5 days.

---

## Dependency Graph Summary

```
Phase 1: Payment Integrity ──┬──► (blocks) Phase 3 (T-Account definition needed)
                            │         │
                            │         ├──► Phase 2 (Lot ownership cleanup)
                            │         ├──► Phase 4 (Notifications — ledger defined)
                            │         └──► Phase 5 (Analytics metrics)
                            │
                            └──► Phase 2 independent

Phase 2: Lot Ownership ─────┐
                            ├──► Phase 6 (Mobile — lots, agreements, payments)
                            │
Phase 3: Accounting ─────────┘ (depends on accountant approval for classification rules)

Phase 4: Notifications ─────► Phase 6 (mobile notifications)

Phase 5: Reports ──────────► Phase 6 (mobile reports, statements)

Phase 6: Mobile App ───────► Phase 7 (end-to-end testing)

Phase 7: Testing & Demo ───► ALL phases complete
```

---

## Final Recommendation

**Start Phase 1 today.** The two critical defects — missing Firestore index and no duplicate payment check — block production readiness for the entire system. The hardcoded bugs and penalty guard are lower priority but should be fixed in the same week. Do not start Phase 2 or any later phase until Phase 1 is complete and verified.

---

*This roadmap is part of the Panel Feedback Reconciliation Phase 0. All phases require explicit panel approval before any code modification begins.*
