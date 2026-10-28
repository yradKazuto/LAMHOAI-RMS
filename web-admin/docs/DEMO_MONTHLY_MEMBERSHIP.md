# Demonstrating Monthly Membership Fees

This guide explains how to manage and demonstrate the new `Monthly Membership Fee` feature within your web-admin interface.

## 1. Setup & Configuration

1.  **Navigate to Settings**: Go to the **Settings** screen in the web-admin.
2.  **Access Dues Configuration**: Click the **Dues Configuration** button.
3.  **Manage Monthly Rates**: You will see the **Monthly Dues Rate** section (which now handles both Monthly Dues and Monthly Membership Fees).
    *   To set a rate, enter the amount (e.g., `250`) in the "New rate" field.
    *   Select the effective month from the dropdown.
    *   Click **Add rate**.
    *   The table will update to show the current active rate and any scheduled future rates.

## 2. Generating Membership Fees

1.  **Navigate to Membership Dues**: Go to the **Membership Dues** screen.
2.  **Switch to Monthly Mode**: Use the **Monthly** toggle at the top.
3.  **Select Period**: Choose the desired Month and Year using the dropdowns.
4.  **Generate**: Click **Generate Dues**.
    *   The system will automatically fetch the rate configured for that specific month.
    *   It will create individual unpaid records for every active member.
    *   If records already exist for that month, they will be skipped (safe to run multiple times).

## 3. Payment & Tracking

1.  **Dashboard/Dues Screen**: The generated fees appear on the screen with the `unpaid` status.
2.  **Marking Paid**: Click **Mark Paid** to settle the record.
3.  **Reporting**: These records are stored with `PaymentType.monthlyMembership`, ensuring they are grouped correctly in financial reports, distinct from annual fees or monthly per-lot dues.
4.  **Penalties**: If left unpaid past the grace period, the automatic `applyOverduePenalties` logic will apply penalties to these records just as it does for regular dues.
