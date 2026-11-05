# Phase 3 Implementation Matrix

Maps each module, assigned agent, file ownership, test requirements, and completion criteria. File ownership is strict: no two agents may edit the same service or model file. Shared model files are owned by a single designated owner listed first in each row.

## Module-to-Agent Mapping

| # | Module | Assigned Agent | Files to Create | Files to Modify | Dependencies | Tests Required | Completion Criteria |
|---|---|---|---|---|---|---|---|
| 1 | General Ledger (`LedgerService`, `ChartOfAccountsService`, `Account`/`JournalEntry` models) | Agent 2 | `lib/core/models/general_ledger_account_model.dart`, `lib/core/models/journal_entry_model.dart`, `lib/core/models/chart_account_model.dart`, `lib/core/services/ledger_service.dart`, `lib/core/services/chart_of_accounts_service.dart`, `test/ledger_service_test.dart` | `lib/firebase_options.dart` (no change), no existing app files | None | balanced posting test, duplicate rejection test, audit trail test |
| 2 | AR Aging Report | Agent 4 | `lib/features/reports/screens/ar_aging_screen.dart`, `lib/core/services/ar_aging_report_service.dart`, `test/ar_aging_report_test.dart` | `app_router.dart` add route, `app_shell.dart` add title entry | `PaymentModel`, `LotSaleModel` reads only | aging bucket logic tests, partial payment non-duplication test |
| 3 | Collection Rate Report | Agent 5 | `lib/features/analytics/screens/collection_rate_screen.dart`, `lib/core/services/collection_rate_report_service.dart`, `test/collection_rate_test.dart` | `app_router.dart` add route, `analytics_screen.dart` accept extra filter params | `PaymentModel`, `analytics_service.dart` integration for metrics display | rate formula tests including zero-denominator, monthly periods test |
| 4 | Accounting UI components (COA, Journal Entry, T-Account) | Agent 3 | New screens under `features/reports/screens/`: `accounting_chart_of_accounts_screen.dart`, `general_ledger_screen.dart`, `t_account_screen.dart`; shared widget `t_account_widget.dart` | app_router.dart, app_shell.dart updates, shared design tokens | LedgerService outputs from Agent 2 | widget test for T-account rows, balance totals verification |
| 5 | Demo data and QA | Agent 6 | `test/phase3_demo_data.json`, `test/phase3_seed_demo_accounts.dart`, unit tests covering generation/verification across all modules, `audit/PHASE_3_PROTOTYPE_COMPLETION_REPORT.md` | `audit/PHASE_3_PROTOTYPE_COMPLETION_REPORT.md` existing doc is written by this agent | all services read demonstration accounts; no production overlap | accounting balance test across 5 demo scenarios, report correctness check |

## File Ownership Strict List

| File | Owner | Can Edit? |
|---|---|---|
| `lib/core/models/general_ledger_account_model.dart` | Agent 2 | Yes |
| `lib/core/models/journal_entry_model.dart` | Agent 2 | Yes |
| `lib/core/models/chart_account_model.dart` | Agent 2 | Yes |
| `lib/core/services/ledger_service.dart` | Agent 2 | Yes |
| `lib/core/services/chart_of_accounts_service.dart` | Agent 2 | Yes |
| `lib/core/models/general_ledger_service_contracts.dart` | shared — Agent 6 writes contract stub (no real implementation file needed) | Read-only for all agents |
| `lib/core/services/ar_aging_report_service.dart` | Agent 4 | Yes |
| `lib/core/services/collection_rate_report_service.dart` | Agent 5 | Yes |
| `lib/features/reports/screens/*.dart` | Agent 3 + UI reviews merged | Parallel where separate files; app_router & app_shell updated only after UI design frozen |
| `lib/firebase_options.dart` | No one — configuration only; create overlay test fakes instead | Read-only outside of feature work |
| `lib/features/analytics/screens/collection_rate_screen.dart` | Agent 5 overlaid on analytics screen | Partial edit acceptable under approved owner |

## Concurrency plan

1. Agents 2 and 4 run first together since they depend on shared Phase 3 models in `lib/core/models/`. The model master file will not be consumed until both have agreed on shape.
2. Agent 5 writes independently against existing `PaymentModel` and existing `analytics_service.dart` reads. No collaboration required.
3. Agent 3 needs Ledger model ids before writing T-account rows; this is a sequential handoff after Agent 2 publishes its models.
4. Agent 6 builds demo accounts into `chart_of_accounts_service` then validates across all UIs. Late stage, remaining coordination.
