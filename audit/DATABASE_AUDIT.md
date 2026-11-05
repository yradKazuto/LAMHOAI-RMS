# Database Audit — Firestore Collections & Structures

## Collections Identified

### `users` / `members`
- **Document fields**: `uid`, `name`, `email`, `role`, `status`, `contactNumber`, `address`, `lotNumber`, `phase`, `ownerName`, `createdAt`.
- **Indexing**: Default single-field index on `uid` (used by StreamBuilder for real-time member list).
- **Security**: Read = any authenticated user; Write = Admin only (based on rules inspection).

### `lots`
- **Document fields**: `id`, `phase`, `block`, `lotNumber`, `areaSqm`, `price`, `status` (vacant/forSale/occupied), `uid` (current owner), `ownerName`, `updatedAt`, `updatedBy`.
- **No composite index needed** — queries are single-field (`where('status', isEqualTo: ...)`).
- **Missing**: No ownership history tracking; only current owner stored.

### `lot_sales`
- **Document fields**: `saleId`, `lotId`, `buyerUid`, `buyerName`, `totalPrice`, `basePrice`, `pricingType`, `adjustmentAmount`, `downPayment`, `financedAmount`, `termMonths`, `monthlyPayment`, `annualInterestRate`, `status`, `soldDate`, `createdAt`, `paidOffAt`.
- **Unique**: Per lot sale record auto-generated with transaction ID pattern.

### `payments` (member payment history)
- **Document fields**: `uid`, `type`, `amount`, `status`, `dueDate`, `paymentMethod`, `transactionId`, `paidAt`, `recordedBy`, `recordedAt`, `verifiedBy`, `verifiedAt`, `notes`.
- **Issue**: Composite query (`uid` isEqualTo + status whereIn) requires a **missing composite index**. First usage throws `MissingIndexError`.
- **Required composite index**: `payments` collection, fields ordered by `uid` ASC first, then `status` ASC.

### `payment_allocations`
- **Document fields**: `paymentId`, `lotId`, `obligationId`, `period`, `principalPortion`, `penaltyPortion`, `allocatedPrincipal`, `allocatedPenalty`.
- **Purpose**: Tracks how each payment was distributed to individual installments.
- **Current status**: Not indexed; adequate for read queries but no composite indexes recommended for performance.

### `hoa_settings`
- **Document fields**: `annual`, `dues configuration`, rate per sqm.
- **Used by**: Member registration for initial membership fee amount.

## Relationships

| Collection A | Collection B | Relationship |
|---|---|---|
| `users` (member doc) | `lots` | Many-to-one (multiple lots → one member) |
| `lot_sales` | `lots` | One-to-many (one lot has multiple sale records) |
| `lot_sales` | `payments` | One-to-many (sale → period payments) |
| `payments` | `payment_allocations` | One-to-many (payment → allocation records) |
| `members` | `users` | One-to-one (member doc ↔ auth user) |

## Security Rules Summary
- `lots`: Read = Staff; Create = Admin/Officer; Update = Admin (unless uid/ownerName unchanged); Delete = Admin.
- Members/Users: Read = any authenticated; Write = Admin only.
- LotSales: Write access not confirmed in this audit pass (extension needed).

---

## Recommended Database Changes (Non-destructive)
1. CREATE composite index on `payments` (`uid` ASC, `status` ASC) — creates the missing required index.
2. Consider adding `ownerHistory` field array on `lots` or a dedicated `lot_ownership_history` collection for lineage tracking.
3. Ensure `lot_sales` collection has security rules for `status` updates (e.g., marking paid-off).
4. Add unique indexes for `lot_sales` (`saleId`) and `payments` (`transactionId` per sale).
