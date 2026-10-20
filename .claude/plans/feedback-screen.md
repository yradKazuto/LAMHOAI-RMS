# Plan: Add Feedback Screen (Mobile + Web Admin)

## Goal
Add a feedback feature allowing members to submit feedback from the mobile app, which is saved to Firestore and viewable in the web admin panel.

---

## 1. Mobile App Changes

### a. New Screen: `FeedbackScreen`
**File:** `mobile/lib/features/feedback/feedback_screen.dart`

**Features:**
- Form with:
  - Category chips (General, Bug, Feature, Compliment, Other)
  - Rating stars (1-5) – optional
  - Message (multiline, required)
  - Title (short, optional)
- Submit button calls Firestore to create a document in `feedback` collection
- Loading spinner on submit
- Success toast on completion
- Navigation back to Profile screen after submit

**Fields written to Firestore (`feedback` collection):**
- `uid`: member UID
- `memberName`: display name
- `email`: member email
- `title`: optional title (string)
- `message`: feedback message (string, required)
- `category`: selected category (string, defaults to 'general')
- `rating`: 1-5 (nullable int)
- `status`: 'pending' (string)
- `platform`: 'mobile' (string)
- `createdAt`: server timestamp
- `updatedAt`: null
- `resolvedBy`: null
- `resolutionNote`: null

### b. Routing
**File:** `mobile/lib/core/routing/app_router.dart`

**Add route constants:**
```dart
static const feedback          = '/home/feedback';
```

**Add to `ShellRoute` branches** (new branch or add to existing Home branch?):
Add a new `StatefulShellBranch` for feedback or include under existing Home branch as a nested route.
Simplest: Add as a top-level branch in the StatefulShellRoute alongside Home, Payments, etc.

Alternatively, nest under home: `/home/feedback`.  
Let's nest under home to keep the shell tabs consistent.

Add to existing Home branch (first branch) as a nested route:
```dart
GoRoute(
  path: Routes.memberHome,
  builder: (_, __) => const HomeScreen(),
  routes: [
    // ... existing nested routes (announcements)
    GoRoute(
      path: 'feedback',
      builder: (_, __) => const FeedbackScreen(),
    ),
  ],
),
```

### c. Profile Screen Integration
**File:** `mobile/lib/features/profile/profile_screen.dart`

**Add a card in `_buildBody`:**  
After the Security card, add a new card:
- Icon: `Icons.feedback_outline`
- Title: `SEND FEEDBACK`
- Body: `Tap to send feedback or suggestions to the HOA team.`
- OnTap: `context.go(Routes.feedback)`

### d. Dependencies
No new dependencies needed (uses `cloud_firestore`, `provider`, `go_router`).

---

## 2. Web Admin App Changes

### a. Model
**File:** `web-admin/lib/core/models/feedback_model.dart`

**Define:**
```dart
enum FeedbackStatus { pending, reviewed, resolved }

class FeedbackModel {
  final String id;
  final String uid;
  final String memberName;
  final String email;
  final String? title;
  final String message;
  final String category;
  final int? rating;
  final FeedbackStatus status;
  final String? resolvedBy; // uid of staff
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory FeedbackModel.fromMap(Map<String, dynamic> map, String id) { ... }
  Map<String, dynamic> toMap() => { ... };
}
```

### b. Firestore Service Extension
**File:** `web-admin/lib/core/services/firestore_service.dart`

**Add method:**
```dart
Stream<List<FeedbackModel>> streamFeedback() {
  return _feedbacks
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => FeedbackModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList());
}
```

### c. New Screen: `FeedbackScreen`
**File:** `web-admin/lib/features/feedback/screens/feedback_screen.dart`

**Mirror `ComplaintsScreen` layout:**  
- App bar with back to dashboard
- Search field (search memberName, email, title, message)
- Filter by status (All, Pending, Reviewed, Resolved)
- Table/list of feedback entries
- Tapping a row opens a bottom sheet to:
  - View full feedback
  - Update status (pending → reviewed → resolved)
  - Add resolution note
  - (Optional) send push notification to member on status change to resolved/reviewed
- Use `FirestoreService().streamFeedback()`

### d. Routing
**File:** `web-admin/lib/core/routing/app_router.dart`

**Add route constant:**
```dart
static const feedback = '/feedback';
```

**Add to `ShellRoute` routes list:**  
```dart
GoRoute(
  path: AppRoutes.feedback,
  name: 'feedback',
  builder: (_, __) => const FeedbackScreen(),
),
```

### e. Permissions
**File:** `web-admin/lib/core/routing/app_router.dart` (inside redirect logic)  
Feedback routes accessible to `admin` and `officer` roles (same as complaints):  
Add guard:
```dart
// Feedback — Admin + Officer
if (path.startsWith(AppRoutes.feedback) &&
    role != UserRole.admin &&
    role != UserRole.officer) {
  return AppRoutes.dashboard;
}
```

### f. Dashboard Integration (Optional)
**File:** `web-admin/lib/features/dashboard/screens/dashboard_screen.dart`  
Add a "Recent Feedback" card under Activity and Complaints row (mirrors `_PendingComplaintsCard`).

---

## 3. Firestore Security Rules
Update `firestore.rules` to allow members to create feedback documents.

Add rule:
```javascript
match /databases/{database}/documents {
  match /feedback/{feedbackId} {
    allow create: if request.auth != null;
    allow read, update, delete: if false; // Members cannot read/update/delete
    // Admin/Officer access via web-admin service (bypasses rules via SDK)
  }
}
```
Alternatively, allow read for members to see their own feedback.

---

## 4. Implementation Order
1. Create mobile feedback screen and route.
2. Add Profile screen entry point.
3. Test mobile submission (verify documents appear in Firestore).
4. Create web feedback model and FirestoreService method.
5. Create web feedback screen.
6. Wire web route and permissions.
7. (Optional) Add dashboard card.

---

## 5. Estimated Effort
- Mobile: 2-3 hours
- Web: 3-4 hours
- Testing: 1 hour

Total: ~6-8 hours

---

## Notes
- Reuse existing UI patterns (category chips, form layout, success toast) from `SubmitComplaintScreen`.
- Mirror the web complaints screen UI for consistency.
- Consider adding email notification to admins when new feedback is submitted (via cloud function or web polling).
- Use same colors/icons as complaints for visual consistency (feedback icon already used).