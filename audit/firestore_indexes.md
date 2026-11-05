# Firestore Indexes

Required indexes for production:

1.  **Payments Collection**
    - Fields: `uid` (ASC), `status` (ASC)
    - Collection Group: No
    - Purpose: Queries in `FirestoreService.recordPaymentWithAllocations`.

Firestore Index Definition:
```json
{
  "fieldOverrides": [],
  "indexes": [
    {
      "collectionGroup": "payments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "uid", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    }
  ]
}
```
