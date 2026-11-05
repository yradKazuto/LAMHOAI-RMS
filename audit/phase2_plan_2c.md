# Implementation Plan: Multi-Lot Reassignment Validation (Task 2c)

The goal is to prevent the assignment of lots that are already owned by another member during registration and to prevent silent overwriting of lots during re-registration.

## 1. Investigation Findings
- `member_registration_wizard.dart`: Allows selection of multiple lots (stored in `_selectedLots` map).
- `sale_service.dart`: Handles `registerSale()`, which updates `lot_sales`, `lot_payments`, and `lots` collections in a single transaction.
- `LotModel`: Stores `uid` (buyer/owner) and `status`.
- Current state: Lots are filtered by status `vacant` or `forSale` in Step 2 of the wizard. There is **no server-side validation** that prevents assigning a lot that might have been acquired by another owner between the user opening the wizard and final confirmation, other than the initial load filter.

## 2. Proposed Validation Strategy

### A. Client-Side (User Experience)
- During lot selection in the wizard (Step 2), ensure the `StreamBuilder` that fetches available lots is reactive. If a lot changes status, the UI should reflect it.
- Before final submission in `_submit()`:
    - Perform a final Firestore check (transaction) to verify all selected lots in `_selectedLots` are still `vacant` or `forSale` and do not have an owner (`uid` is null or empty).

### B. Server-Side / Transactional Validation (Critical Safety)
- To prevent race conditions, the actual lot assignment MUST be protected by a Firestore transaction.
- Modify `SaleService.registerSale` (or create a new `registerMultipleSales` method) to use a transaction.
    - Inside the transaction:
        1. Read all selected `LotModel` docs.
        2. Verify all are still `vacant` or `forSale` AND `uid` is empty/null.
        3. If any check fails, abort transaction and throw a specific exception.
        4. If all checks pass, write the sale records, update lot statuses, and update lot ownerships.

### C. Re-registration/Overwrite Protection
- Current `registerSale` logic already checks `existingSales` to avoid creating duplicate sale records for a buyer on a specific lot.
- To prevent silent overwriting:
    - If re-registering (registering a member that already exists), add an explicit confirmation step (or at least a UI warning) if they already own lots.
    - The transaction check mentioned in B will prevent overwriting a lot that is now owned by someone else.

## 3. Implementation Steps

1.  **`web-admin/lib/core/services/sale_service.dart`**:
    - Update `registerSale` or create a method `verifyAndRegisterSales(List<LotModel> lots, ...)` that performs the transactional check of lot status and ownership before proceeding with batch writes.

2.  **`web-admin/lib/features/members/screens/member_registration_wizard.dart`**:
    - In `_submit()`, call the new transactional verification method BEFORE proceeding with account creation and fee generation.
    - Handle the specific exception thrown by the transaction if a lot has been taken, and display a meaningful error to the user (e.g., "Lot X is no longer available").

3.  **Firestore Security Rules**:
    - Ensure rules allow writing to `lots` only if `uid` matches the buyer (which `SaleService` handles via server-side credentials/service account). No direct changes needed here if `SaleService` remains the sole entry point for modifications.

## 4. Proposed Changeset Summary
- **`sale_service.dart`**: Add transactional verification logic to ensure lot availability immediately before sale recording.
- **`member_registration_wizard.dart`**: Integrate this transactional check into the registration workflow.
