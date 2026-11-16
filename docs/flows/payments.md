# Payments Feature Flows

**Screen**: `payments_screen.dart`
- **Route**: `/payments`
- **Role gate**: Admin, Accountant
- **Entry points**: Dashboard
- **Sections/Tabs**: Summary cards (Collected/Pending/Overdue), Search, Filter (Status/Type), Payments table (all).
- **User flows**:
    1. **View payments**: Load aggregate stats and filterable table (on init, syncs overdue status + applies penalties + backfills lot payments).
    2. **Record payment**: Opens `RecordPaymentScreen.show()`.
    3. **Send dues reminders**: Shows dialog to pick days-ahead, triggers `NotificationService.sendDuesReminders`.
    4. **View membership dues**: Navigates to `MembershipDuesScreen`.
- **Reads collections**: `payments` (stream).
- **Writes collections**: `payments` (updates status).
- **Services used**: `FirestoreService`, `NotificationService`, `SettingsService`, `SaleService`.

**Screen**: `add_payment_screen.dart`
- **Route**: dialog
- **Role gate**: Admin, Accountant
- **Entry points**: `PaymentsScreen`
- **Sections/Tabs**: Form: Member selector, Type/Status dropdowns, Lot dropdown (conditional), Amount, Date, Notes.
- **User flows**:
    1. **Select member**: Loads and displays member's lots (`LotService`).
    2. **Suggest amount**: Auto-fills based on `RateHistoryService` or `SettingsService`.
    3. **Save payment**: Validates form, checks for duplicates, records payment via `FirestoreService.recordPaymentWithAllocations`.
- **Reads collections**: `members`, `lots`, `payments`.
- **Writes collections**: `payments`, `member_ledgers`, `audit_log`.
- **Services used**: `FirestoreService`, `LotService`, `RateHistoryService`, `SettingsService`, `AuthProvider`.

**Screen**: `record_payment_screen.dart`
- **Route**: dialog
- **Role gate**: Admin, Accountant
- **Entry points**: `PaymentsScreen` (Record Payment button).
- **Sections/Tabs**: Form: Member selector, Obligations list (FIFO summary), Amount, Reference/Notes, Receipt view.
- **User flows**:
    1. **Load obligations**: Fetches unpaid/overdue for member (`FirestoreService`).
    2. **Preview allocation**: Shows FIFO breakdown using `AllocationCalculator` in real-time.
    3. **Confirm payment**: Saves payment (`recordPaymentWithAllocations`), logs audit, shows receipt view.
- **Reads collections**: `payments`, `users`.
- **Writes collections**: `payments`, `payment_transactions`, `payment_allocations`, `audit_log`.
- **Services used**: `FirestoreService`, `AuthProvider`, `SettingsService`, `AllocationCalculator`.

**Screen**: `membership_dues_screen.dart`
- **Route**: `/dues` (Navigated from `PaymentsScreen`)
- **Role gate**: Admin, Accountant
- **Entry points**: `PaymentsScreen` (Membership Dues button).
- **Sections/Tabs**: Mode toggle (Annual/Monthly), Period selectors (Year/Month), Unpaid-only filter, Dues table.
- **User flows**:
    1. **Generate Dues**: Select members via `MemberSelectionDialog`, triggers generation (`generateMembershipFees` or `generateMonthlyMemberships`).
    2. **Mark Paid**: Direct toggle (triggers `markPaymentPaid` + notification).
- **Reads collections**: `users`, `lots`, `member_ledgers`, `payments`.
- **Writes collections**: `payments`, `audit_log`.
- **Services used**: `FirestoreService`, `LotService`, `RateHistoryService`, `SettingsService`, `NotificationService`, `AuthProvider`.
