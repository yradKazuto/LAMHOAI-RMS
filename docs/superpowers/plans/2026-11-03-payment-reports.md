# Payment Reports & Mobile Statement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance the payment reporting features in the web admin and add a statement preview feature for mobile/member-facing views.

**Architecture:** Extend existing `ReportsScreen` to support new payment scheme data. Implement a full-screen statement preview that shares logic with the existing `StatementPreviewDialog`.

**Tech Stack:** Flutter, Firestore, PDF, CSV, Provider.

**Spec:** N/A (Based on discussion: enhance reporting + full-screen statement preview).

## Global Constraints

- Use established `AppColors`, `AppTypography`, and `AppSpacing` tokens.
- Maintain CSV and PDF export functionality for reports.
- Ensure payment records follow the paid-date/due-date logic implemented in `ReportsScreen`.

## Review Focus

- Date filtering logic for paid vs. unpaid payments (ensure parity with `ReportsScreen`).
- CSV export encoding (must handle UTF-8/special characters correctly).
- PDF export layout and font rendering (must handle large datasets).
- Mobile responsiveness for the new statement preview screen.
- Payment status badge styling and readability.

---

### Task 1: Update InstallmentReportScreen

**Files:**
- Modify: `web-admin/lib/features/reports/screens/installment_report_screen.dart`
- Modify: `web-admin/lib/features/reports/screens/reports_screen.dart` (reuse components)

**Interfaces:**
- Consumes: `SaleService.getPaymentsReportDataset()`

- [ ] **Step 1: Reuse `ReportsScreen` components**
Extract reusable components (`_DateFilter`, `_FilterDropdown`, `_PaymentRow`) from `reports_screen.dart` if possible, or build similar UI in `InstallmentReportScreen`.
- [ ] **Step 2: Implement Filters and Dataset Fetching**
Add date range and member filters to `InstallmentReportScreen`. Use `_applyFilters` logic from `ReportsScreen`.
- [ ] **Step 3: Add Export CSV/PDF functionality**
Integrate the export logic from `ReportsScreen` to `InstallmentReportScreen`.
- [ ] **Step 4: Commit**
```bash
git add web-admin/lib/features/reports/screens/installment_report_screen.dart
git commit -m "feat: enhance installment report with filters and exports"
```

### Task 2: Create Mobile Statement Preview Screen

**Files:**
- Create: `web-admin/lib/features/payments/screens/statement_preview_screen.dart`
- Modify: `web-admin/lib/core/routing/app_router.dart`

**Interfaces:**
- Consumes: `SaleService.streamAllSales()`, `SaleService.streamPaymentsForSale(saleId)`

- [ ] **Step 1: Create Full-Screen UI**
Create a new screen that takes `memberId` as an argument. Use the logic from `StatementPreviewDialog` but wrap in a full `Scaffold`.
- [ ] **Step 2: Implement responsive layout**
Ensure the preview is readable on mobile (compact row stacking).
- [ ] **Step 3: Register Route**
Add the new screen to the `AppRouter`.
- [ ] **Step 4: Commit**
```bash
git add web-admin/lib/features/payments/screens/statement_preview_screen.dart web-admin/lib/core/routing/app_router.dart
git commit -m "feat: add full-screen statement preview"
```
