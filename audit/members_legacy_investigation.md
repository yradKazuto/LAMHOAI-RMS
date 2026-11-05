# Investigation: Legacy Members Collection

## Finding
The `members` collection in Firestore is obsolete. Canonical user data is stored in the `users` collection.

## Recommendation
- Do NOT use or populate the `members` collection.
- All new development must interface only with the `users` collection.
- Migration of existing legacy member data to `users` is NOT required at this time unless specified by a future requirement.
