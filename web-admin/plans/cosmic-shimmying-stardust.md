# Plan: Add Member Search and Multi-Selection to Dues Generation

## Context
Admins need more control over who is billed when generating dues. Currently, "Generate Dues" automatically bills all active/delinquent members. This plan introduces a search bar and multi-selection mechanism to the dues generation process.

## Critical Files
- `lib/features/payments/screens/membership_dues_screen.dart`

## Design Approach
1. Modify `_generateDues` in `MembershipDuesScreen` to:
   - Present a dialog *before* final confirmation showing a list of members.
   - Include a search field in the dialog to filter members.
   - Allow checking individual members or "Select All".
2. Update the `FirestoreService` generator methods to optionally accept a `List<String> targetUids` (if provided, only bill those; if empty, bill all). 
   - *Wait: modifying `FirestoreService` might be too much. Instead, filter the list inside `_generateDues` before sending the batch to Firestore.*

## Implementation Plan
1. **Update `_generateDues`**: 
   - Before confirming generation, show a new `_MemberSelectionDialog`.
   - The dialog will filter `members` based on a search query.
   - It will return a `List<MemberModel>` of selected members to `_generateDues`.
2. **Update Generation Logic**: 
   - Modify the `_generateDues` method (in `membership_dues_screen.dart`) to filter the `members` list using the `List<MemberModel>` returned by the dialog.
3. **UI Updates**:
   - The dialog will use a `StatefulBuilder` to manage selection state.
   - A `CheckboxListTile` for each member in the dialog.
   - "Select All" checkbox.

## Verification
1. Open `MembershipDuesScreen`.
2. Click "Generate Dues".
3. Verify the selection dialog appears.
4. Search for a specific member, check them.
5. Click Generate.
6. Verify only the selected member received a dues record.
7. Verify "Select All" behavior.
