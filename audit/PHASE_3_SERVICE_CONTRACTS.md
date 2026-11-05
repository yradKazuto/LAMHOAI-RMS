# Phase 3 Service Contracts Document

Defines the contracts between new accounting modules. Interface boundaries enforced by method signatures, error handling policies, and transactional boundaries. Shared and owned files require a single designated owner; each implementation agent may contribute through strictly assigned file ownership.

---

## 1. Service responsibilities

| Service | Responsibility | File ownership |
|---|---|---|
| `LedgerService` (new) | Owns `general_ledger` + `journal_entries` collections. Posts balanced entries under transaction. Validates debit/credit sums before commit. Prevents duplicate posting by deterministic entry id. | Single owner: Agent 2 |
| `ChartOfAccountsService` (new) | Reads/writes catalog of valid account IDs used for allowlist enforcement on every journal line. Seeds initial demo accounts. | Single owner: Agent 2 (shared with Ledger) |
| `AccountingScreenService` (presentation-side, optional) | Read helpers to list accounts, query ledger balances, query journal history by date range, expose creation of proposed drafts from COA screen UI. | Single owner: Agent 6 |
| `ArAgingReportService` (new) | Computes outstanding balances across members, separates lot installments vs membership dues, classifies aging buckets, reports totals per phase and globally. Pure read from existing `payments`, `lot_sales`, `payment_allocations`. No writes. | Single owner: Agent 4 |
| `CollectionRateReportService` (new) | Derives expected collection totals (`REVENUE_DUES`, `REVENUE_SALES`) from existing `payments` docs, actual collections similarly, computes rate. Monthly and yearly windows supported. No writes. | Single owner: Agent 5 |

---

## 2. Method signatures

### LedgerService — core contract
```dart
class LedgerService {
  final Database db;
  LedgerService(this.db);

  // Creates an immutable posted journal entry atomically with updated balances.
  // Throws LedgerPostingException if balances unbalanced or duplicate id exists.
  Future<String> postJournalEntry({
    required String description,
    required List<JournalLineInput> lines,
    required DateTime timestamp,
    String? relatedTransactionId,
  });

  // Returns all general_ledger account balances keyed by id.
  Future<Map<String, double>> getBalances();

  // Returns chart_account documents filtered by category string.
  Future<List<ChartAccount>> getAccountsByCategory(String category);
}

class JournalLineInput {
  final String accountId;
  final double amount; // positive
  final String type;   // 'DEBIT' | 'CREDIT'
  const JournalLineInput({
    required this.accountId,
    required this.amount,
    required this.type,
  });
}
```

### ChartOfAccountsService — core contract
```dart
class ChartOfAccountsService {
  final Database db;
  const ChartOfAccountsService(this.db);

  Future<List<ChartAccount>> getAll();
  Future<void> seedDemoAccounts();
}
```

### AR Aging Report Service — core contract
```dart
class ArAgingReportService {
  final Database db;
  const ArAgingReportService(this.db);

  // Per member overdue buckets grouped by lot installment and membership dues.
  Future<ArAgingReport> generateReport({DateTime asOf});

  Future<ArAgingReport> generateReport({DateTime asOf}) async {
    return ArAgingReport(...);
  }
}

class ArAgingReport {
  final int totalOutstanding;
  final Map<String, int> currentBucket;
  final Map<String, int> bucket1To30;
  final Map<String, int> bucket31To60;
  final Map<String, int> bucket61To90;
  final Map<String, int> bucket90Plus;
  final int totalCashCollected;
}
```

### Collection Rate Report Service — core contract
```dart
class CollectionRateReportService {
  final Database db;
  const CollectionRateReportService(this.db);

  // Returns monthly/yearly summary cards: expected, actual, collected,
  // outstanding, rate percentage, period labels.
  Future<List<CollectionSummary>> generateReport({int? year, int? month});

  class CollectionSummary {
    final String periodLabel;
    final double expected;
    final double actual;
    final double outstanding;
    final double rate;       // = (actual / expected) * 100; zero-denominator guard returns null
    final bool hasDenominator;
  }
}
```

---

## 3. Input/output models

All models referenced above are implemented inside Phase 3 model files (see `PHASE_3_IMPLEMENTATION_MATRIX.md` for exact file locations). Idiomatic shape follows existing Firestore model style: manual `toMap`/`fromMap`, camelCase field names consistent with project conventions, `enum`-backed field types where values are closed sets.

---

## 4. Error handling

| Error | Trigger | Behavior |
|---|---|---|
| `LedgerPostingException` | Unbalanced entry, invalid account id, duplicate posting | Rejected; caller should display message and retry. |
| `ArAgingValidationException` | Partial payment double counting detected | Null/throw; guarded in write path. |
| `CollectionRateZeroDenominator` | Expected == 0 | Return `null` rate value marked `hasDenominator`; never divide. |
| Missing required entry | Empty or negative line count | `LedgerPostingException`. |

---

## 5. Transaction boundaries

Only the central `postJournalEntry()` call uses a Firestore transaction. All other services are pure reads. Report services also pure reads. Data integrity relies on existing production transactions being atomic when currently recorded (Stage 1 assurance); prototype additions preserve the pattern.

---

## 6. Module dependencies

```
Agent 2: LedgerService + ChartOfAccountsService → foundational
Agent 3: Accounting UIs consume both above
Agent 4: AR aging consumes PaymentModel / LotSaleModel / LotSaleService reads
Agent 5: Collection Rate consumes PaymentModel reads only
Agent 6: Consumes all output models; adds screens under app_router
```

No cross-service write dependencies exist. Shared model files: define one master `phase3_models.dart` owned by Agent 2; other agents pass models by reference. No two agents edit the same service file.
