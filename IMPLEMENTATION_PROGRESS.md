# Implementation Progress — Payment Scheme Overhaul

Source of truth: `docs/plan-coding.md` (8 phases), `docs/plan-payment-overhaul.md`,
`docs/flow-payment-scheme.md`. Branch: `dev`.

## Current state

**Phase 0 — Models + math foundation** — COMPLETED.
**Phase 1 — Flow 01–02 rate + lot pricing** — IN PROGRESS.

## Completed tasks

- Phase 0: created `sales_rate_model.dart`, `lot_sale_model.dart`, `lot_payment_model.dart`
- Phase 0: created `amortization_service.dart`, `transaction_id_service.dart`
- Phase 0: added `web-admin/test/amortization_service_test.dart`, `transaction_id_service_test.dart`
- Phase 0: passed tests, fixed interest rate bug.

## Files created or modified

- `web-admin/lib/core/models/sales_rate_model.dart`
- `web-admin/lib/core/models/lot_sale_model.dart`
- `web-admin/lib/core/models/lot_payment_model.dart`
- `web-admin/lib/core/services/transaction_id_service.dart`
- `web-admin/lib/core/services/amortization_service.dart`
- `web-admin/test/amortization_service_test.dart`
- `web-admin/test/transaction_id_service_test.dart`

## Tests and analysis commands actually executed

- `flutter analyze` (on new files)
- `flutter test` (Phase 0 files)

## Remaining tasks

- Phase 1: Flow 01–02 rate + lot pricing (Core) — COMPLETED.
- Phase 2: Flow 12a register via map (Core) — COMPLETED.
- Phase 3: Flow 03–04 sales + schedule (Core) — COMPLETED.
- Phase 4: Flow 05–06 payments + overdue (Core) — COMPLETED.
- Phase 5: Flow 09 paid off → deed (Core) — COMPLETED.
- Phase 6: Optional 07 / 08 / 10 / 11 / 12b (build to present, removable) — IN PROGRESS.
- Phase 7: Reports + mobile views
- Phase 8: Acceptance tests + interview