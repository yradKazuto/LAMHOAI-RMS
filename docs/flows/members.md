# Members Feature Flows

**Screen**: `members_screen.dart`
- **Route**: `/members`
- **Role gate**: Admin, Officer
- **Entry points**: Dashboard nav item
- **Sections/Tabs**: Member list, Search/Filter, Add Member button.
- **User flows**:
    1. **View members**: Loads paginated list of homeowners.
    2. **Search**: Filters by name/lot.
    3. **Add Member**: Launches registration wizard.
- **Reads collections**: `homeowners`, `users`
- **Writes collections**: `homeowners`, `users`
- **Services used**: `FirestoreService`

**Screen**: `member_detail_screen.dart`
- **Route**: `sub-screen` (via Member list tap)
- **Role gate**: Admin, Officer
- **Sections/Tabs**: Personal Info, Lot Ownership, Ledgers, Payments, Actions.
- **User flows**:
    1. **Edit Info**: Updates user record.
    2. **View Ledger**: Shows real-time balance.
    3. **Assign Lot**: Launches wizard.
    4. **Statement**: Generates PDF statement.
- **Reads collections**: `users`, `homeowners`, `lot_sales`, `lot_payments`, `member_ledgers`
- **Writes collections**: `users`, `homeowners`
- **Services used**: `FirestoreService`, `SaleService`

**Screen**: `member_registration_wizard.dart`
- **Route**: `sub-screen` (via Members Screen)
- **Role gate**: Admin, Officer
- **Sections/Tabs**: 5-step wizard (Personal, Lot Setup, Billing, Review, Done).
- **User flows**:
    1. **Register**: Completes 5 steps.
    2. **Register Sale**: Records lot sales + payments + ownership history in one batch.
- **Writes collections**: `users`, `lot_sales`, `lot_payments`, `lots`, `lot_ownership_history`
- **Services used**: `SaleService`, `LotService`
