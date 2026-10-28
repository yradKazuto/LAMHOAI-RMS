# Update Dashboard Pending Items Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display pending complaints and feedback counts on the Dashboard for Officers/Admins.

**Architecture:** Add stream methods for pending items to `FirestoreService`, update `DashboardScreen` to fetch and display counts.

**Tech Stack:** Flutter, Firebase

**Spec:** Dashboard update to show actionable pending items.

## Global Constraints

- Dart / Flutter
- Firestore

## Review Focus

- Ensure counts update in real-time.
- Navigation routes to `AppRoutes.complaints` and `AppRoutes.feedback` work.

---

### Task 1: Update `FirestoreService`

**Files:**
- Modify: `web-admin/lib/core/services/firestore_service.dart`

**Interfaces:**
- Produces: `streamPendingComplaints()`, `streamPendingFeedbacks()`

- [ ] **Step 1: Add `streamPendingComplaints`**

```dart
Stream<List<ComplaintModel>> streamPendingComplaints() {
  return _complaints
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) => snap.docs.map((d) => ComplaintModel.fromMap(d.data(), d.id)).toList());
}
```

- [ ] **Step 2: Add `streamPendingFeedbacks`**

```dart
Stream<List<FeedbackModel>> streamPendingFeedbacks() {
  return _feedbacks
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) => snap.docs.map((d) => FeedbackModel.fromMap(d.data(), d.id)).toList());
}
```

- [ ] **Step 3: Commit**

```bash
git add web-admin/lib/core/services/firestore_service.dart
git commit -m "feat: add streams for pending complaints/feedback"
```

### Task 2: Update `DashboardScreen` UI

**Files:**
- Modify: `web-admin/lib/features/dashboard/screens/dashboard_screen.dart`

- [ ] **Step 1: Add `_PendingItemCard` widget**

```dart
class _PendingItemCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;
  const _PendingItemCard({required this.label, required this.count, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: AppComponents.cardDecoration(),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label, style: AppTypography.bodyMedium),
          const Spacer(),
          Text('$count', style: AppTypography.sectionHeader.copyWith(color: AppColors.primary)),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: Update `DashboardScreen` to include new cards**

In `DashboardScreen`, inside the build, add `StreamBuilder` for these streams and display `_PendingItemCard`s.

- [ ] **Step 3: Commit**

```bash
git add web-admin/lib/features/dashboard/screens/dashboard_screen.dart
git commit -m "feat: show pending complaints/feedback on dashboard"
```
