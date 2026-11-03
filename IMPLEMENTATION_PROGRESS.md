# Implementation Progress — Payment Scheme Overhaul

Source of truth: `docs/plan-coding.md` (8 phases), `docs/plan-payment-overhaul.md`,
`docs/flow-payment-scheme.md`. Branch: `dev`.

## Current state

**Phase 0-7** — COMPLETED.
**Phase 8 — Acceptance tests & final review** — IN PROGRESS.

## Completed tasks

- [All tasks up to Phase 6 complete]
- Updated UI of `MemberRegistrationWizard` (Stepper, field clarity, payment preview auto-update)
- Refactored `ReportsScreen` filter widgets into reusable `report_widgets.dart`
- Updated `InstallmentReportScreen` with filters and dataset fetching
- Added full-screen `StatementPreviewScreen` and registered `/statement/:memberId` route
- Implemented Bulk Lot Update mechanism (Phase 7 Flow 13)
- Fixed Settings Screen structure (Association info, Dues configuration dialog, Sales rate configuration)
- Fixed Firestore Security Rules for rate schedules and sales rates
- Completed Phase 7 Report filtering and CSV export enhancements
- Fixed member registration permission failure (added `lot_sales` / `lot_payments` Firestore rules — the missing rules made the whole sale batch fail: no lot assignment, no finance records)
- Auto-charge annual membership fee on member registration (`createInitialMembershipFee` — payment + ledger from Settings)
- Transaction IDs on every payments-collection record (`MF-`/`MD-`/`MM-`/`LPAY-`/`PEN-`/`SA-`/`TXN-{year}-{seq}` via TransactionIdService; lot payments keep `LP-{year}-{seq}-{period}`)

## Files created or modified

- `web-admin/lib/core/models/sales_rate_model.dart`
- `web-admin/lib/core/models/lot_sale_model.dart`
- `web-admin/lib/core/models/lot_payment_model.dart`
- `web-admin/lib/core/services/transaction_id_service.dart`
- `web-admin/lib/core/services/amortization_service.dart`
- `web-admin/lib/core/services/lot_service.dart`
- `web-admin/test/amortization_service_test.dart`
- `web-admin/test/transaction_id_service_test.dart`
- `web-admin/test/lot_service_test.dart`
- `web-admin/lib/features/reports/widgets/report_widgets.dart`
- `web-admin/lib/features/reports/screens/installment_report_screen.dart`
- `web-admin/lib/features/payments/screens/statement_preview_screen.dart`
- `web-admin/lib/features/location/screens/bulk_lot_update_screen.dart`
- `web-admin/lib/core/routing/app_router.dart`

## Tests and analysis commands actually executed

- `flutter test` (all Phase 0 + service tests)
- Manual verification of UI components

## Remaining tasks

- Phase 7: Reports + mobile views (filters/export for installment report, statement preview)
- Phase 8: Acceptance tests + interview