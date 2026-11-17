# Demo Flow — the whole system, start to finish, in plain English

Run it in this order. Each step says what you click, what you see, and what
it proves. Roles: Admin sees everything; Officer/Accountant see less;
members use the mobile app.

## 0. Set up the HOA (Settings, Admin only)

- **Do:** Settings → enter HOA name and address, the monthly/annual dues
  rates, the late-payment penalty, and the lot price table (one row per
  effective date, so last year's price and next year's price can both exist).
- **See:** the rates saved and listed with their dates.
- **Proves:** every price later comes from this table — no hard-coded rates
  anywhere in the app.
- **Note:** if Settings shows "permission denied," the Firestore rules on
  the server are older than the app. Deploy first (see the Phase 2 plan doc).

## 1. Put the lots on the map (Location Mapping)

- **Do:** open the phase map, click lots, assign them (phase, block, lot
  number, size, status). Or upload a CSV for a bulk update.
- **See:** the map colored by status — available, reserved, sold.
- **Proves:** the lot inventory the whole system sells from.

## 2. Register a member who buys a lot (Members → Add Member)

- **Do:** the 5-step wizard — personal info → pick lots on the map → payment
  terms (cash, or installment with down payment and duration) → preview →
  confirm.
- **See:** a member account; one sale per lot, each priced at the rate-table
  row in force that day; an installment schedule (period 0 = the down
  payment); ownership history written; the annual membership fee charged
  right away. Optional co-owners can be added here.
- **Proves:** the moment of sale. From here the member owes money on a
  schedule, and the price is whatever the table said on that date.

## 3. Bill everyone (Membership Dues → Generate)

- **Do:** pick annual or monthly dues, run Generate.
- **See:** one `unpaid` charge per member per period.
- **Proves:** dues are bulk-created, not typed in one by one. Miss a due date
  and the next visit to the Payments screen auto-tags it `overdue` and adds
  the penalty.

## 4. Take the money (Payments → Record Payment)

- **Do:** open a member, enter the cash received, optional reference number
  (the official receipt no.), save.
- **See:** the FIFO split shown before you save — every open debt, oldest
  first, dues and lot installments together — then the receipt.
- **Proves:** the core. One payment pays down the oldest bill first
  (principal before penalty), writes a transaction row and allocation rows
  showing exactly where each peso went, and leaves any excess as credit.
  Same member + same amount twice within 30 seconds is rejected as a
  double-submit.

## 5. Look at a member (Members → tap a member)

- **See:** their ledger (every charge, payment, penalty), a statement PDF
  preview, their lots, and the Assign Lot action.
- **Proves:** the audit trail a member asks about at the desk.

## 6. Run the office (Reports / Dashboard)

- **See:** collections dashboard, analytics, the payments and installment
  reports (exportable to CSV/PDF), and the AR aging view of who is late and
  for how long.
- **Proves:** money in, money owed, nothing deleted — corrections are new
  records, so the trail stays.

## 7. Hand the member their view (mobile app)

- **See:** as the member — balance card, payment records, announcements,
  notifications, complaints and feedback.
- **Proves:** members read only their own data, inside the same Firestore
  rules.

## Demo script in one line

Set rates → map lots → register a buyer → generate dues → record a payment
that splits across dues and installments → show the ledger, the reports,
and the member's phone.
