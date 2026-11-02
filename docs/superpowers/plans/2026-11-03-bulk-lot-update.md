# Bulk Lot Area Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a bulk lot area update mechanism for administrative data entry via CSV.

**Architecture:** A new admin screen allowing CSV upload, with a service method that performs robust validation and a batch update on the `lots` collection.

**Tech Stack:** `csv` package, `Firestore` batch writes.

**Spec:** Requirement documented in `plan-coding.md`, Section 189.

## Global Constraints

- Matches lots via Phase+Block+LotNumber (trim, case-insensitive).
- Entire batch rejected if ANY row fails validation (no partial updates).

## Review Focus

- CSV formatting errors (wrong columns, empty values).
- Partial/misaligned phase/block/lot naming.
- Missing lot documents in Firestore.
- Large batch limits (ensure chunking if > 500 lots).

---

### Task 1: LotService Update

**Files:**
- Modify: `web-admin/lib/core/services/lot_service.dart`

**Interfaces:**
- Produces: `Future<int> bulkUpdateLotAreas(String phase, List<Map<String, dynamic>> rows, String updatedBy)`

- [ ] **Step 1: Write the failing test**

```dart
// web-admin/test/lot_service_test.dart
test('bulkUpdateLotAreas updates valid lots', () async {
  // Setup: Create 2 lots in Firestore
  // Call bulkUpdateLotAreas with 2 rows mapping to those lots
  // Verify both lots have updated areaSqm
});
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write minimal implementation in LotService**

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

### Task 2: Bulk Upload Screen

**Files:**
- Create: `web-admin/lib/features/location/screens/bulk_lot_update_screen.dart`
- Modify: `web-admin/lib/core/routing/app_router.dart`

**Interfaces:**
- Consumes: `BulkUpdateLotAreas` service method
- Produces: UI for file picking, CSV parsing, error listing, progress bar, success message.

- [ ] **Step 1: Write UI component test**

- [ ] **Step 2: Run to fail**

- [ ] **Step 3: Implement screen, router, and CSV parsing**

- [ ] **Step 4: Run to pass**

- [ ] **Step 5: Commit**
