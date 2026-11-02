# Tiered Pricing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a tiered pricing mechanism that allows setting, drafting, and activating rate schedules (with area tiers) and recalculating active installment sales.

**Architecture:** A `rate_schedules` Firestore collection stores tiered rate configuration. `RateService` manages these schedules. `SettingsScreen` gets a new tab for Rate History. Activation triggers a background batch update on all `active` installment sales using `AmortizationService`.

**Tech Stack:** `Firestore`, `AmortizationService` (existing).

**Spec:** Requirement documented in `plan-coding.md` (Flow 01b).

## Global Constraints

- Configuration-based tiered rates (supports future adjustments).
- Only the `active` schedule for the current year determines pricing.
- Activation of a schedule triggers recalculation for all *active* installment sales.
- Entire activation batch rejected if any row fails validation.

## Review Focus

- Recalculation errors (incorrect math on balance).
- Activation race conditions (multiple administrators activating).
- Missing installment records during batch update.
- Partial update failure handling (should be atomic).

---

### Task 1: Rate Schedule Model and Service Update

**Files:**
- Create: `web-admin/lib/core/models/rate_schedule_model.dart`
- Modify: `web-admin/lib/core/services/rate_service.dart`

**Interfaces:**
- Produces: `Future<List<RateScheduleModel>> getSchedules()`, `Future<void> activateSchedule(String scheduleId)`, `Future<void> createSchedule(RateScheduleModel schedule)`

- [ ] **Step 1: Define RateScheduleModel**
- [ ] **Step 2: Implement RateService methods**
- [ ] **Step 3: Commit**

### Task 2: Settings UI for Rate History

**Files:**
- Modify: `web-admin/lib/features/settings/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `RateService`

- [ ] **Step 1: Implement UI tab for Rate History**
- [ ] **Step 2: Add Create and Activate functionality**
- [ ] **Step 3: Commit**

### Task 3: Activation and Recalculation Logic

**Files:**
- Modify: `web-admin/lib/core/services/sale_service.dart`

**Interfaces:**
- Consumes: `AmortizationService`, `RateService`

- [ ] **Step 1: Write test for recalculation logic**
- [ ] **Step 2: Run test to fail**
- [ ] **Step 3: Implement batch recalculation logic**
- [ ] **Step 4: Run test to verify passes**
- [ ] **Step 5: Commit**
