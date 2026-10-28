# Owned Lot Highlighting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to tap a lot row to highlight it within the Member Detail screen, separating selection from navigating to the map.

**Architecture:** Update `_ProfileSidebarCard` to manage `_selectedLotId`. Pass `isSelected` to `_OwnedLotTile` to conditionally style the row.

**Tech Stack:** Flutter

**Spec:** N/A (Bounded change)

## Global Constraints

- Dart / Flutter

## Review Focus

- Ensure highlighting persists across screen rebuilds within the `_ProfileSidebarCard` state.
- Verify clicking a row still navigates to the map if the user performs a deliberate action (e.g., tap again or separate button). Wait, the user asked to remove navigation entirely on phase tap. I will update `_OwnedLotTile` to highlight on tap, and ensure they can still navigate if needed, or simply make highlighting the primary action.

---

### Task 1: Update `_ProfileSidebarCard` State

**Files:**
- Modify: `web-admin/lib/features/members/screens/member_detail_screen.dart`

**Interfaces:**
- Produces: `_selectedLotId` state, `onSelectLot` callback

- [ ] **Step 1: Add state to `_ProfileSidebarCardState`**

```dart
String? _selectedLotId;
```

- [ ] **Step 2: Update `_ProfileSidebarCard` to pass `onSelectLot`**

Update `_ProfileSidebarCard` and its State to accept `onSelectLot` callback or just update state directly.

- [ ] **Step 3: Modify `_ProfileSidebarCard`'s `build` to pass selection info to `_OwnedLotTile`**

---

### Task 2: Update `_OwnedLotTile` UI

**Files:**
- Modify: `web-admin/lib/features/members/screens/member_detail_screen.dart`

**Interfaces:**
- Consumes: `isSelected` bool, `onTap` callback

- [ ] **Step 1: Update `_OwnedLotTile` constructor to accept `isSelected`**

- [ ] **Step 2: Conditional styling in `_OwnedLotTile`**

```dart
// inside build method, apply decoration change if isSelected
decoration: BoxDecoration(
  color: isSelected ? AppColors.accentLight : AppColors.background,
  ...
)
```

- [ ] **Step 3: Update `onTap` in parent to update `_selectedLotId`**

---

### Task 3: Commit and Verify

- [ ] **Step 1: Commit changes**

```bash
git add web-admin/lib/features/members/screens/member_detail_screen.dart
git commit -m "feat: add lot selection highlight in member detail"
```

- [ ] **Step 2: Verify in browser (manual test)**

Run app. Tap a lot row. It should highlight.
