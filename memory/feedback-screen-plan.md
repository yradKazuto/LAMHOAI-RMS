---
name: feedback-screen-plan
description: Plan to add feedback screen in mobile and web admin for member-to-admin feedback submission
metadata:
  type: project
---

# Feedback Screen Plan

**Goal**: Add a feedback feature allowing members to submit feedback from the mobile app, which is saved to Firestore and viewable in the web admin panel.

## Summary
This plan outlines the implementation of a new feedback system:
- Mobile: New `FeedbackScreen` with form (category, rating, message) that writes to Firestore `feedback` collection
- Mobile: Route `/home/feedback` and Profile screen entry point ("Send Feedback" card)
- Web Admin: New `FeedbackScreen` to list, filter, and update feedback status/resolution notes
- Web Admin: Route `/feedback` under shell with admin/officer access
- Firestore: New collection with appropriate security rules

## Files to Create/Modify

### Mobile
1. `mobile/lib/features/feedback/feedback_screen.dart` - New screen
2. `mobile/lib/core/routing/app_router.dart` - Add route constants and nesting
3. `mobile/lib/features/profile/profile_screen.dart` - Add "Send Feedback" card

### Web Admin
1. `web-admin/lib/core/models/feedback_model.dart` - Feedback model with status enum
2. `web-admin/lib/core/services/firestore_service.dart` - Add `streamFeedback()` method
3. `web-admin/lib/features/feedback/screens/feedback_screen.dart` - New admin screen
4. `web-admin/lib/core/routing/app_router.dart` - Add route and permission guard
5. `web-admin/lib/features/dashboard/screens/dashboard_screen.dart` - Optional: Recent Feedback card

### Firestore Rules
- Update `firestore.rules` to allow members to create feedback documents

## Implementation Order
1. Mobile feedback screen and routing
2. Profile screen integration
3. Test mobile submission
4. Web feedback model and service
5. Web feedback screen
6. Web routing and permissions
7. Optional dashboard card

## Estimated Effort
- Mobile: 2-3 hours
- Web: 3-4 hours
- Testing: 1 hour
- Total: ~6-8 hours

## Related Components
- Mirrors existing complaints feature pattern
- Reuses UI components from `SubmitComplaintScreen`
- Uses same Firestore structure as complaints for consistency

---