# Bug: Overdue payments never receive a reminder notification

**Found:** 2026-10-19
**Area:** `web-admin` — Payments screen → "Send Dues Reminder"
**Severity:** High — the feature silently did nothing for the members who
most need the notice.

---

## Symptom

Pressing **Send Dues Reminder** on the Payments screen only ever reached
members whose dues were *coming up*. Members with **overdue** payments were
never notified, even though the Payments screen listed them as Overdue and
the reminder ran immediately after (the same screen, same session).

There was no error, no warning, and the snackbar reported success
("Dues reminder sent to N member(s).") — it just never included the
overdue ones.

## Root cause

`NotificationService.sendDuesReminders()`
(`web-admin/lib/core/services/notification_service.dart`) ran a single query:

```dart
.where('status', isEqualTo: 'unpaid')
.where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
.where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(cutoff))
```

An overdue record is excluded from that query **twice**, independently:

1. **By status.** `FirestoreService.syncOverdueStatuses()`
   (`web-admin/lib/core/services/firestore_service.dart:235`) — which the
   Payments screen runs on open — flips every past-due `unpaid` record to
   `status: 'overdue'`. So by the time the reminder runs, an overdue record
   is no longer `unpaid`.
2. **By due date.** The window is `[now, now + daysAhead]`. An overdue
   record's `dueDate` is *before* `now`, so it falls outside the window
   regardless of its status.

The query was correct for what it was written to do — "dues coming up" — but
nothing in the app ever notified the overdue set. The button's own copy
("Notify members whose unpaid dues are coming up within:") matched the
implementation, so the gap was invisible from the UI.

## Second, latent bug (same query)

The lower bound compared against `DateTime.now()` (with time-of-day), while
`dueDate` is stored at **midnight**. A payment due *today* has
`dueDate == today 00:00`, which is `< now` at any point after midnight, so
it was excluded from the window entirely. A "1 day" reminder therefore
skipped the members due today — the most urgent group in that window.

The message-building code right below it already used start-of-today
(`DateTime(now.year, now.month, now.day)`) to compute "due today", so the
query and the message disagreed with each other.

## Fix

`sendDuesReminders()` now runs **two** queries and sends one notification
per member:

| Query | Filter | Index |
|---|---|---|
| upcoming | `status == 'unpaid'`, `dueDate` in `[startOfToday, cutoff]` | `(status, dueDate)` |
| overdue  | `status in ['unpaid', 'overdue']`, `dueDate < startOfToday` | `(status, dueDate)` |

Both use the same `(status, dueDate)` composite index that
`applyOverduePenalties()` already requires, so no new index is needed.

- The upcoming bound is now **start of today**, not `now` — fixes the
  "due today is skipped" bug.
- The overdue query includes `unpaid` as well as `overdue`, so a record
  that is past due but hasn't been flipped yet (sync hasn't run, or a
  record written after it) is still picked up.
- A member in both sets gets **one** notification covering both, with the
  overdue part first and titled `Payment Overdue`.
- Message building was extracted into a pure top-level function
  `buildReminderMessage()` so it can be unit-tested without Firestore
  (`web-admin/test/notification_message_test.dart`).

The notification `type` stays `dues` for both, so the mobile app routes
tapping it to the Payments screen exactly as before — no mobile change
needed.

## How to verify

1. Admin → Payments. Wait for maintenance to flip past-due records to
   Overdue.
2. **Send Dues Reminder** → pick a window (e.g. 7 days).
3. Member with a *due-soon* payment → phone/app shows "Payment Due Soon".
4. Member with an *overdue* payment → shows "Payment Overdue", with the
   amount including the penalty that `applyOverduePenalties()` added.
5. Member with both → one notification, overdue part first.
6. Member in the Notifications list → entry appears with type `dues`.

## Related

- `firestore.indexes.json` is empty in the repo; the `(status, dueDate)`
  composite index was created in the Firebase console. If the reminder
  ever fails with a "requires an index" error, that index is the thing to
  create.
- Penalty amounts are folded into the record's `amount` field by
  `applyOverduePenalties()`, so the reminder quotes the **penalized total**.
  The original pre-penalty amount is not stored anywhere and cannot be
  shown without undoing the penalty write.
