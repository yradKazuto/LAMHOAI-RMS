# Reports Feature Flows

**Screen**: `dashboard_screen.dart`
- **Route**: `/dashboard`
- **Role gate**: Any authenticated
- **Entry points**: After login
- **Sections/Tabs**: Summary widgets, quick actions.
- **User flows**:
    1. **View Overview**: Displays aggregate RMS data.
- **Reads collections**: Various (for stats).

**Screen**: `analytics_screen.dart`
- **Route**: `/analytics`
- **Role gate**: Admin, Accountant
- **Entry points**: Nav item
- **Sections/Tabs**: Sales trends, Dues trends, Lot status distribution.
- **User flows**:
    1. **View Analytics**: Visual representation of system data.
- **Reads collections**: `lot_sales`, `payments`, `member_ledgers`

**Screen**: `reports_screen.dart`
- **Route**: `/reports`
- **Role gate**: Admin, Accountant
- **Entry points**: Nav item
- **Sections/Tabs**: Payments table with filters + CSV/PDF export.
- **User flows**:
    1. **Generate Report**: Navigates to selected report.

**Screen**: `installment_report_screen.dart`
- **Route**: sub-screen
- **User flows**:
    1. **Preview**: Generates installment PDF.
- **Reads collections**: `lot_sales`, `lot_payments`

**Screen**: `ar_aging_screen.dart`
- **Route**: `/ar-aging`
- **Role gate**: Any authenticated
- **User flows**:
    1. **View**: Displays receivables aging report.
- **Reads collections**: `payments` (via `ArAgingReportService`)

**Screen**: `lot_ownership_history_screen.dart`
- **Route**: `/lot-history`
- **Role gate**: Admin, Officer
- **Entry points**: Member Detail, Location Screen.
- **User flows**:
    1. **View History**: Shows ownership changes for a lot.
- **Reads collections**: `lot_ownership_history`
