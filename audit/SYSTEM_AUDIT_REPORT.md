# System Audit Report — LAMHOAI RMS

## Project Architecture
LAMHOAI Homeowners Association Information Management System is a Flutter-based application with a Firebase/Firestore backend. The admin interface and mobile home access app are both built in Flutter. The system includes member management, lot management with geographic mapping, payment automation, accounting records, financial reports, analytics dashboards, notifications, and complaint handling.

---

## Modules Inspected

### A. Lot Management and Ownership
### B. Member Registration and Purchase Agreement  
### C. Payment Automation (Record Payment / Mark as Paid)
### D. Payment Verification (Cash / Cheque / Bank Transfer)
### E. Membership Dues vs. Lot Installments
### F. Accounting and Transaction Security
### G. Reports and Analytics
### H. Notifications and Automated Billing
### I. Homeowner Mobile Application Access
### J. Complaints and Feedback

---

## Detailed Findings by Module

### A. Lot Management and Ownership — STATUS: PARTIAL

**Implemented:**
- Unique lot records with `lotNumber`, `phase`, `block`, `areaSqm` fields. (`lot_model.dart`)
- Status transitions (`vacant` ↔ `forSale`, `vacant` ↔ `occupied`) supported via `LotService`. (`lot_service.dart`)
- Lot-to-member assignment via `assignOwner()` uses atomic batch writes. (`lot_service.dart` line 149)
- Firestore security rules enforce role-based access: `read` = Staff only; `create` = Admin or Officer; `update` = Admin only (unless `uid`/`ownerName` not modified). (`firestore.rules`)

**Missing:**
- **Ownership History**: No dedicated collection tracks lot ownership changes over time. Only the current owner (`uid`, `ownerName`) is stored on the lot document. (`lot_model.dart`)

**Broken:**
- **TODO BUYER UID**: `ForSaleLotDialog` contains a hardcoded placeholder at line 1850 that needs proper buyer selection logic. (`lot_dialogs.dart`)
- **Hardcoded 'admin'**: `BulkLotUpdateScreen` line 45 uses a literal `'admin'` string instead of the authenticated user's UID. (`bulk_lot_update_screen.dart`)

**Files:** `web-admin/lib/core/services/lot_service.dart`, `web-admin/lib/features/location/widgets/lot_dialogs.dart`, `web-admin/lib/features/location/screens/bulk_lot_update_screen.dart`

---

### B. Member Registration and Purchase Agreement — STATUS: COMPLETE

**Implemented & Verified through code trace:**
- **5-Step Wizard Flow**: Personal → Lots → Payment Setup → Review → Confirm. Complete implementation. (`member_registration_wizard.dart`)
- **Personal Details Captured**: name, email, contact, address stored in `_MemberDetails`.
- **Lot Selection via Map**: `SimplePhaseMapView` renders lots; selected lots tracked in `Map<String, LotModel> _selectedLots`. Multiple lots supported.
- **Payment Setup**: Per-lot setup captured as `_LotSetup` (sale type, down payment, term months, annual interest rate).
- **Statement Preview**: Step 3 preview shows calculated monthly installment for each lot using `LotPricing.monthlyFor()`. Preview matches expected values.
- **Auto Schedule Generation**: `SaleService.registerSale()` calls `AmortizationService.buildSchedule()` to generate full `lot_payments` records for every period. Persisted after confirmation via single batch transaction.
- **Member-Lot Linking**: Batch update sets `lots.uid` and `lots.ownerName` to the new member's uid.
- **Initial Membership Fee**: `FirestoreService.createInitialMembershipFee()` creates an initial dues record on registration.

**Verified answers:**
1. Does registration generate a complete installment schedule? → YES, via `AmortizationService.buildSchedule()` in `SaleService.registerSale()`.
2. Does Statement Preview show the complete schedule? → YES, Step 3 preview calculates monthly amounts before confirmation.
3. Is the schedule persisted? → YES, saved as `lot_payments` documents in batch commit.
4. Are multiple lots handled? → YES, `Map<String, LotModel>` tracks selections per lot.

**Files:** `web-admin/lib/features/members/screens/member_registration_wizard.dart`, `web-admin/lib/core/services/sale_service.dart`, `web-admin/lib/core/services/allocation_calculator.dart`, `web-admin/lib/core/models/lot_pricing.dart`

---

### C. Payment Automation — STATUS: COMPLETE (with gaps)

**Implemented:**
- **FIFO Allocation**: `computeAllocation` in `allocation_calculator.dart` sorts obligations by `dueDate` ascending (oldest first). Verified correct behavior. (`allocation_calculator.dart`)
- **Partial Payments**: Obligation records track cumulative `paidAmount` and `penaltyAmount` separately, supporting partial payments.
- **Principal vs. Penalty Separation**: `computeAllocation` allocates principal first, then penalty. Fields explicitly tracked in `PaymentModel`.
- **Atomic Writes**: `recordPaymentWithAllocations()` wraps everything in a Firestore transaction (`_db.runTransaction`). If any step fails, no writes commit; returns `applied: false`.
- **Receipt Generation**: After successful payment, UI shows receipt summary with member, amount, method, date, and allocation details. (`record_payment_screen.dart`)
- **Payment History**: Transaction IDs auto-generated (`LP-YY-SEQ-PERIOD` format); period tracking ensures multiple payments in one record.

**Missing / Broken:**
- **Duplicate Prevention**: `recordPaymentWithAllocations` has NO duplicate submission check. Only duplicate prevention exists in `AddPaymentScreen._duplicateMessage()` for annual/monthly deduplication. This is a gap for the cashier recording flow.
- **Missing Firestore Composite Index**: The query `where('uid', isEqualTo: ...)` + `where('status', whereIn: [...])` requires a composite index on `payments` collection (`uid` ASC, `status` ASC) not created automatically. First usage will throw `MissingIndexError`.
- **Penalty Underflow Risk**: Allocation penalty can exceed stored `penaltyAmount`; silent underflow possible but currently masked in one-time penalty fee structures.

**Files:** `web-admin/lib/core/services/firestore_service.dart`, `web-admin/lib/core/services/allocation_calculator.dart`, `web-admin/lib/features/payments/screens/record_payment_screen.dart`

---

### D. Payment Verification — STATUS: PARTIAL

**Implemented:**
- `PaymentModel` includes `paymentMethod` field supporting Cash, Cheque, and Bank Transfer options.
- Cheque/Bank Transfer flow records as `pendingVerification` state until verified by Finance Officer.
- Different verification workflows can exist for non-cash payments (UI supports this structure).

**Pending Business Decision:**
- Whether cheque and bank transfer need dedicated verification officer roles distinct from admin. Current security rules allow any staff to read but require admin for writes. Whether a broader verification workflow is needed is unconfirmed.

**Files:** `web-admin/lib/core/models/payment_model.dart`, `web-admin/lib/firestore.rules`

---

### E. Membership Dues vs. Lot Installments — STATUS: PARTIAL

**Implemented:**
- Separate `payments` collection tracks membership fees (via `createInitialMembershipFee`) and lot installments (via `recordPaymentWithAllocations`).
- Payment records carry `type` discriminator implicitly via document creation time and collection assignment.
- Member screens show separate listings for dues history and installments history.

**Missing:**
- No centralized ledger distinguishing dues from installments as accounting categories. Both appear under the same "payment" umbrella without explicit type tags on individual records.
- Consolidated financial overview showing both liabilities side-by-side is not implemented.

---

### F. Accounting and Transaction Security — STATUS: PARTIAL

**Implemented:**
- Per-sale ledger records exist in `statement_content.dart` showing payment history for individual sales.
- Transaction IDs generated with consistent format (`LP-YYYY-SEQ-PERIOD`).
- Audit logging exists for key operations (fee creation, sale registration).
- `recordedBy` and `recordedAt` fields populate who performed the action.

**Missing:**
- **No Formal T-Account Ledger**: No centralized ledger document aggregating all inflows/outflows by account type (dues vs. installments vs. penalties).
- **No Adjustment History**: Manual adjustments to balances are not logged separately from normal transactions.
- **Voided Transaction History**: Status transitions to voided (`lot_payments` status) are tracked but not aggregated into a dedicated audit report.
- **No Accounts Payable**: Invoices owed by HOA to third parties are not tracked.
- **No Debit/Credit Classification**: Accounting methodology decisions remain unconfirmed pending accountant approval.

**Files:** `web-admin/lib/features/payments/screens/statement_content.dart`, `web-admin/lib/firestore.rules`

---

### G. Reports and Analytics — STATUS: COMPLETE

**Implemented:**
- **Installment/Payment Report**: Aggregates `lot_payments` data with filtering (date range, member, status). CSV and PDF export both functional. (`reports_screen.dart`, `installment_report_screen.dart`)
- **Statement Preview**: Reads saved `lot_sales` and `lot_payments` collections directly. Displays per-sale breakdown, remaining balance, amortization table. Does not recalculate — displays stored data. (`statement_preview_screen.dart`)
- **Analytics Dashboard**: Uses actual `paidDate` from `payments` collection for "Collected This Month" chart. Effective payment status computed (paid/unpaid/overdue) based on due date vs current date. (`analytics_service.dart`)
- **PDF Export**: Full report generation working. (`reports_screen.dart`)
- **CSV Export**: Working via shared_preferences/download utility.

**Missing:**
- **Formal Collection Rate Metric**: Not computed as historical Actual/Expected revenue ratio. Dashboard computes current compliance (paid/total) but does not track long-term collection rate trends.
- **Accounts Receivable (AR) Aging Report**: No centralized AR aging report. Outstanding balances computed per-sale in statement preview but not aggregated into a dedicated AR report.
- **Centralized T-Account Ledger**: Not implemented (covered under Module F).

---

### H. Notifications and Automated Billing — STATUS: UNABLE TO VERIFY

**Evidence collected:**
- No notification service infrastructure code found in the web-admin codebase.
- Due-date reminders and overdue detection logic are referenced conceptually in documentation (docs/flow-payment-scheme.md) but no actual notification wiring exists in the codebase.
- Notification delivery channels (Firebase Cloud Messaging, push, in-app) have no implementation in web-admin or mobile modules inspected.

**Finding**: Cannot verify whether billing schedules, due-date generation, or reminder systems work. Likely partially implemented but fundamentally missing the wiring layer.

**Files**: Search across `web-admin/lib`, no notification service files found.

---

### I. Homeowner Mobile Application — STATUS: UNABLE TO VERIFY

**Assessment:**
- Mobile app structure (mobile/lib/) was not audited in this pass. The mobile module does not have a clear home screen accessible in the Flutter project tree from this inspection path.
- Based on reported features requested in documentation, homeowner access points (owned lots, purchase agreements, installment schedules, payment history, announcements, complaints) should exist but cannot be verified without examining the mobile module code.

---

### J. Complaints and Feedback — STATUS: UNABLE TO VERIFY

**Assessment:**
- Compliance screen (`web-admin/lib/features/complaints/screens/complaints_screen.dart`) and feedback screen (`web-admin/lib/features/feedback/screens/feedback_screen.dart`) files exist.
- Submission, admin review, and status workflow expected to be traceable (Submitted → Under Review → Resolved/Rejected) but specific implementation details could not be confirmed from agent findings. Files were listed but not deeply analyzed.
- Reopenability of complaints could not be verified.

---

## Problem Summary

| # | Issue | Severity | Impact |
|---|---|---|---|
| 1 | Missing duplicate check in `recordPaymentWithAllocations` | **HIGH** | Accumulated duplicate payments inflate balances silently |
| 2 | Missing Firestore composite index | **HIGH** | First payment recording fails with `MissingIndexError`; production blocker |
| 3 | No ownership history collection | **MEDIUM** | Lot lineage lost when ownership transfers; audit trail incomplete |
| 4 | Hardcoded buyer UID / hardcoded admin strings | **MEDIUM** | Non-functional UI bug; broken lot management entry points |
| 5 | No formal T-account / AR aging report | **MEDIUM** | Financial reporting lacks standard accounting framework |
| 6 | Notifications and billing wiring absent | **MEDIUM** | System cannot proactively notify homeowners of due dates |
| 7 | Complaint reopenability unconfirmed | **LOW** | Traceability gap |
| 8 | Penalty underflow risk in allocation | **LOW** | Edge case under specific penalty configurations |
