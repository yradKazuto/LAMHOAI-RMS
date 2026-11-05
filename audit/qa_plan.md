# Phase 2 QA Strategy: Ownership History & Lot Management

## Investigation
Existing tests use `fake_cloud_firestore` for mocking Firestore operations. 
Repositories/Services are injected with the mock instance in `setUp()`. 
Assertions use `expect` from `flutter_test`.
Methods are tested by performing actions on the service and querying the mock database for side effects (doc existence, field values).

## Test Cases

### A. New assignment creates history
- **Description**: Assigning an owner to a previously vacant lot creates a new document in `lot_ownership_history`.
- **Inputs**: `LotService().assignOwner(lotId: 'L1', uid: 'U1', ...)`
- **Expected**: A document exists in `lot_ownership_history` with `lotId='L1'`, `uid='U1'`, `type='assign'`, `previousOwner=''`, and `createdAt` timestamp.

### B. Transfer records both owners
- **Description**: Transferring ownership from U1 to U2 records both in history.
- **Inputs**: `assignOwner` to U2 when L1 is occupied by U1.
- **Expected**: A new history document with `lotId='L1'`, `uid='U2'`, `type='transfer'`, `previousOwner='U1'`, `currentOwner='U2'`.

### C. Unassignment records owner
- **Description**: Unassigning a lot records the previous owner.
- **Inputs**: `unassignOwner(lotId: 'L1')` for an occupied lot.
- **Expected**: A history document with `type='unassign'`, `previousOwner='U1'`, `currentOwner=''`.

### D. Failed transaction isolation
- **Description**: Exceptions in `assignOwner` don't leave partial history.
- **Inputs**: Trigger an error during `assignOwner` (e.g., non-existent member).
- **Expected**: No new documents in `lot_ownership_history`.

### E. Multiple lots per member
- **Description**: Assigning multiple lots to one homeowner records all.
- **Inputs**: Assign L1, L2, L3 to U1.
- **Expected**: 3 distinct history entries for U1.

### F. Cross-householder blocked
- **Description**: Assigning an occupied lot to a different homeowner throws an error.
- **Inputs**: `assignOwner` for L1 (occupied by U1) to U2.
- **Expected**: Exception thrown, lot ownership remains U1.

### G. Same-homeowner reassignment
- **Description**: Re-assigning a lot to the same homeowner passes.
- **Inputs**: `assignOwner` for L1 (occupied by U1) to U1.
- **Expected**: Succeeds, no history entry (or a specific type='re-assign' if needed, though 'assign' is likely fine).

### H. Register sale doesn't overwrite
- **Description**: Sale records don't overwrite existing lot assignments incorrectly.
- **Inputs**: Run `SaleService.recordSale` for a lot already occupied by U1.
- **Expected**: Should likely fail or handle gracefully, ensuring no unintended state changes.

### I. Wizard smoke test
- **Description**: Ensure the registration wizard flow remains functional.
- **Inputs**: End-to-end registration of a new member.
- **Expected**: Wizard completes, lot status updates, history created.

### J. Existing tests still pass
- **Description**: Run full test suite.
- **Inputs**: `flutter test`
- **Expected**: 0 failures.
