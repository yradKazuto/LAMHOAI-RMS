# REVISION_PRIORITY_PLAN.md

## Implementation Priority Plan

This plan outlines the sequence for addressing the audit findings.

### Phase 1: Critical — Financial Integrity (High Priority)
1. **Firestore Index Fix**: Create the required composite index on `payments` (`uid` ASC, `status` ASC) immediately to prevent production runtime errors.
2. **Payment Duplicate Check**: Implement a duplicate submission check in `recordPaymentWithAllocations` using a lock or transaction-based check on the `transactionId`.
3. **Penalty Underflow Check**: Add validation to `computeAllocation` to ensure penalty deduction never exceeds the available penalty amount.

### Phase 2: Functional Hardening (Medium Priority)
1. **Fix Lot Dialog Placeholder**: Replace `TODO-BUYER-UID` in `ForSaleLotDialog` with proper buyer selection.
2. **Fix Bulk Update Hardcoding**: Replace hardcoded `'admin'` UIDs in `BulkLotUpdateScreen` with the current user's UID.
3. **Restore Polygon Import**: Restore the XLSX parsing functionality in `polygon_import_flow.dart` (or replace with a valid implementation).
4. **Member Verification Queue**: Implement the pending verification/approval workflow for new registrations.

### Phase 3: Financial Framework Hardening (Low Priority)
1. **Centralized AR Aging Report**: Implement the consolidated AR aging report to provide a holistic view of outstanding obligations.
2. **Collection Rate Metric**: Implement the Actual vs. Expected revenue ratio metric in `AnalyticsService`.
3. **Formal Ledger**: Evaluate the architecture for a formal, centralized T-account ledger for total system inflows/outflows.

---

### Implementation Sequence Dependencies
- **Phase 1 must be completed before any other changes.** These are integrity-blocking issues.
- **Phase 2 depends on Phase 1 completion.** These fix known UI/broken functional issues.
- **Phase 3 depends on defining the accounting rules** with the accountant/HOA, which is currently a `PENDING BUSINESS DECISION`.

**Do not start Phase 2 or 3 until Phase 1 is authorized and completed.**
