# Version 2 — Admin Add Member & Multi-Lot Registration Workflow

**Date:** 2026-10-30  
**Status:** Approved working direction for the first implementation  
**Project:** LAMHOAI / Lamhoy Information Management System

## 1. Purpose and implementation boundary

Version 2 updates the existing Add Member and lot-registration workflow. It is an enhancement to the current system, not a replacement or a new project.

Implementation must:
- Inspect and reuse the existing Flutter, Firebase, authentication, member, lot, sales, and payment services where appropriate.
- Preserve existing working modules and unrelated workflows.
- Avoid broad rewrites or duplicate services when an existing service can be extended safely.
- Treat unresolved HOA rules as configuration or explicit pending decisions. Do not invent policy.

## 2. Target admin journey

The Add Member process is a five-step wizard:

1. Member Details
2. Location Mapping
3. Payment Setup
4. Finance Preview
5. Confirm Registration

The wizard keeps entered information in temporary state until the final confirmation. Clicking **Next** must not create a Firebase Auth account, activate a member, or permanently assign a lot.

## 3. Step 1 — Member Details

- Admin enters the required member information.
- The primary action is **Next**, not Create or Submit.
- Validate required fields and obvious formatting issues before proceeding.
- Keep the entered details in wizard state so Back navigation does not erase them.
- Do not create the Auth user or permanent member record at this stage.

## 4. Step 2 — Location Mapping

Display the existing lot map and make vacant/eligible lots available for selection.

When the admin clicks a lot, open a Lot Details modal showing the available information, such as:
- Phase
- Block
- Lot number
- Area in square meters
- Current status
- Selling price
- Pricing basis (standard price or approved exception)

The modal is for inspecting and selecting a lot. It is not the place to configure payment terms.

When the admin clicks **Select Lot**:
- Close the details modal.
- Highlight the selected lot on the map.
- Add it to the selected-lots list.

Support multiple lot selections in one registration:
- Admin can select more than one eligible lot.
- Admin can remove an individual selected lot.
- Admin can clear all selections.
- Show the selected-lot count and selected lot identifiers.
- Do not allow the admin to proceed when no lot is selected.

Revalidate availability before final confirmation. A lot that becomes unavailable while the wizard is open must not be registered.

## 5. Step 3 — Payment Setup

Use a two-column layout on wider screens:
- **Left:** member summary.
- **Right:** selected lots, each with its own payment setup.

On narrow screens, stack the sections vertically.

Each selected lot has an independent payment mode. Different lots belonging to the same member may use different modes.

### Cash

For a cash lot:
- Show the full lot amount due.
- Do not generate an installment schedule.
- Do not mark the sale as paid merely because Cash was selected.
- Record actual receipt of money later through the existing Record Payment workflow.

### Installment

For an installment lot, collect:
- Agreed down payment
- Annual interest rate
- Term in months
- First due date

Calculate and display:
- Total selling price
- Agreed down payment
- Financed amount
- Monthly amortization
- Relevant schedule summary

The financed amount is based on the lot's saved price snapshot minus the agreed down payment. The amortization calculation must use the approved formula and rounding rules once those rules are confirmed.

The agreed down payment is a term of the agreement, not proof that money has been received. Do not create a paid transaction or mark the down payment as collected at registration.

## 6. Payment collection boundary

Keep registration and payment collection separate.

- Registration records the sale and the agreed payment arrangement.
- The cashier records money actually received using the existing Record Payment workflow.
- Cash is marked paid only after the money is physically received and recorded.
- Cheque or bank transfer remains pending verification until verified.
- Never create a paid payment record just because a down payment value was entered in the wizard.

Do not add online payment integration as part of this workflow unless separately approved.

## 7. Step 4 — Finance Preview

Provide a separate, read-only preview before final registration.

Show:
- Member summary
- Every selected lot
- Each lot's price and pricing basis
- Payment mode per lot
- Down payment and financed amount for installment lots
- Monthly amortization and term for installment lots
- Combined totals across the selected lots

A T-account or accounting breakdown may be displayed as a **draft preview only**. Do not post accounting entries from this screen. Final account names, debit/credit mapping, and accounting treatment require confirmation from the adviser or authorized finance reviewer.

A generated document at this stage must be labelled **Provisional Sales Invoice / Payment Agreement Preview** (or another approved draft label). It must not be presented as an official receipt because no payment has necessarily been received.

## 8. Back navigation and state

Allow the admin to return to earlier steps:
- Finance Preview → Payment Setup
- Payment Setup → Location Mapping
- Location Mapping → Member Details

Preserve all entered member details, selected lots, and payment settings when navigating backward and forward.

If the admin changes or removes a selected lot, update the payment setup and finance preview accordingly. Do not retain stale payment settings for a lot that is no longer selected.

## 9. Step 5 — Confirm Registration

**Confirm Registration** is the only point at which permanent registration writes begin.

Before writing, revalidate:
- Required member details
- Duplicate email or other applicable unique identifiers
- Lot eligibility and current availability
- Duplicate lot IDs in the selection
- Current pricing and pricing approval snapshots
- Payment mode and required payment terms
- Installment calculations and schedule inputs

After successful validation, create the required records using the existing project architecture:

1. Create the Firebase Auth user, if the current account model requires one.
2. Create the member record and set the member to Active after successful registration, subject to the authorized admin's permission.
3. Create one `lot_sales` record for each selected lot.
4. Save the relationship between each lot and the member using the existing data model.
5. Generate installment schedule records only for lots configured as Installment.
6. Do not create paid payment records for money that has not been received.

The operation must prevent duplicate submissions and handle partial failure. If Auth creation succeeds but later database writes fail, provide a recoverable process rather than leaving an unnoticed half-created registration.

Use a Firestore transaction/batch where appropriate, or a carefully designed recoverable workflow where Firebase Auth and Firestore cannot be committed atomically. Re-check lot availability close to the write operation to reduce conflicts between admins.

## 10. Data-model considerations

The existing sample `members` model has singular fields such as `lotNumber` and `phase`, while `lot_sales` is designed as one sale record per lot.

Do not assume a member can only have one lot. Inspect the actual application models and queries before changing them. For multi-lot registration, the per-lot sales records and lot-to-member relationships must remain unambiguous.

Existing relationships described in the current payment-flow documentation include:
- `lot_sales.lotId` → `lots.id`
- `lot_sales.buyerUid` → `members.uid`
- `lot_payments.saleId` → `lot_sales.id`
- `lots.uid` → `members.uid`

Preserve compatible existing fields and migration behavior. If singular member fields are still required by older screens, determine how they should behave for members with multiple lots rather than silently treating one lot as the only lot.

## 11. Pricing and payment data

The existing payment-flow reference describes:
- A configurable rate per square meter.
- Optional per-lot pricing exceptions for special lots, with a reason and approval.
- A final price snapshot saved to `lot_sales`.
- Cash sales without installment schedules.
- Installment sales with monthly schedule records.

Use the current configured rate and approved pricing rules. Do not hardcode example rates or prices in the UI or business logic.

At registration, save a stable price snapshot for each sale so later changes to the general rate do not rewrite an existing sale's agreed price.

The exact interest formula, rounding policy, treatment of partial/overpayments, penalties, and due-date conventions remain subject to confirmation if they are not already defined in the current approved implementation.

## 12. Suggested implementation responsibilities

First inspect the existing code and map these responsibilities to existing classes/services. These are responsibility boundaries, not instructions to create duplicate services.

- Wizard state/controller: step navigation and temporary form state.
- Lot selection: map selection, eligibility, selected-lot list.
- Pricing: current rate, approved exceptions, price snapshots.
- Amortization: installment calculations and schedule generation.
- Registration: final validation and coordinated record creation.
- Existing Auth, Member, Lot, Sale, and Payment services: reuse or extend where appropriate.

Keep UI components focused. Avoid putting all registration, pricing, schedule, and database-write logic into one widget.

## 13. Reliability, security, and audit requirements

- Enforce role permissions on the server/data-access path, not only by hiding UI controls.
- Prevent duplicate confirmation taps and duplicate registration requests.
- Revalidate selected lots before committing.
- Record the responsible admin and relevant timestamps in accordance with existing audit conventions.
- Do not expose sensitive member information to unauthorized roles.
- Ensure failed registration can be retried or reconciled safely.
- Keep existing payment collection and verification controls intact.

## 14. Acceptance criteria

The implementation is acceptable when:

1. Add Member opens the member-details step.
2. The first action is Next; it does not create an account.
3. Member details remain available after navigating backward.
4. The lot map displays eligible vacant lots.
5. Selecting a lot opens a details modal with its available information.
6. Select Lot closes the modal and highlights the lot.
7. More than one eligible lot can be selected.
8. Individual selections can be removed and all selections can be cleared.
9. Proceed is disabled when no lot is selected.
10. Payment Setup lists every selected lot.
11. Each lot can independently use Cash or Installment.
12. Installment inputs calculate the financed amount and monthly amortization.
13. Cash lots do not receive installment schedules.
14. Finance Preview shows per-lot details and combined totals.
15. Finance Preview is read-only and does not post accounting entries.
16. Back navigation preserves wizard state.
17. Final confirmation revalidates member data and lot availability.
18. One sale record is created per selected lot.
19. Installment schedules are created only for installment lots.
20. No payment is marked paid unless actual money is received and recorded.
21. Duplicate submissions and concurrent lot selection are handled safely.
22. Existing unrelated member, lot, and payment workflows continue to work.

## 15. Decisions still requiring confirmation

Do not invent answers for these items. Review existing project documentation and ask the appropriate HOA/adviser/finance decision-maker when needed.

- Current approved rate per square meter.
- Which lots qualify for special pricing and who approves exceptions.
- Lot status lifecycle (vacant, reserved, sold, occupied, owned, or other statuses).
- Approved interest rate rules and whether rates can vary by sale.
- Minimum down payment rules.
- Approved installment terms.
- First due-date rules and schedule generation conventions.
- Amortization formula and rounding policy.
- Accounting account names and debit/credit mapping.
- Official receipt and sales-document requirements.
- Partial payment, overpayment, penalty, refund, and cancellation policies.
- Roles permitted to register members, approve pricing, and activate members.
- Required audit history and document retention.

## 16. Implementation approach

1. Inspect the current codebase and current documentation before editing.
2. Trace the existing Add Member, map, lot assignment, sale, and Record Payment workflows.
3. Identify the actual models, collections, services, and screens involved.
4. Report existing behavior, bugs, and the smallest safe change plan.
5. Implement the wizard in small vertical slices, reusing existing services.
6. Test multi-lot registration, mixed Cash/Installment selection, back navigation, failed writes, duplicate submissions, and regression of existing payment workflows.
7. Update the project documentation to match the implemented behavior.

Do not rename, delete, or overwrite unrelated files. Do not rewrite the application from scratch.

## 17. Version 2 change note

This Version 2 workflow supersedes the earlier assumption that Add Member selects exactly one lot and immediately assigns it during the map step. The updated flow supports multiple selected lots, independent payment modes per lot, a finance preview, and permanent registration only after final confirmation.

Unrelated existing flows remain in place unless a separate approved change explicitly updates them.
