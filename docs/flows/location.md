# Location & Lot Feature Flows

**Screen**: `location_mapping_screen.dart`
- **Route**: `/location`
- **Role gate**: Admin, Officer
- **Entry points**: Dashboard nav item
- **Sections/Tabs**: Phase Map Canvas, Lot sidebar/info, Add Lot button.
- **User flows**:
    1. **View Map**: Visual representation of lot status.
    2. **Edit Lot**: Tap a lot to edit status, ownership, etc.
- **Reads collections**: `lots`, `phaseMaps`, `lot_ownership_history`
- **Writes collections**: `lots`, `lot_ownership_history`, `phaseMaps`
- **Services used**: `LotService`

**Screen**: `assign_lot_wizard.dart`
- **Route**: dialog
- **Role gate**: Admin, Officer
- **User flows**:
    1. **Assign Lot**: Select member, set sale type (cash/installment), define pricing/terms, record sale.
- **Writes collections**: `lot_sales`, `lot_payments`, `lots`, `lot_ownership_history`
- **Services used**: `SaleService`, `LotService`

**Screen**: `bulk_lot_update_screen.dart`
- **Route**: `/bulk-update`
- **Role gate**: Admin, Officer
- **User flows**:
    1. **Import CSV**: Uploads bulk updates (lot status/area/etc.).
- **Reads/Writes**: `lots`
