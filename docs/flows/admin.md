# Admin Feature Flows

**Screen**: `user_management_screen.dart`
- **Route**: `/users`
- **Role gate**: Admin
- **Entry points**: Nav item
- **User flows**:
    1. **Add User**: Create account, set role.
    2. **Edit User**: Modify role/info.
- **Reads/Writes**: `users`

**Screen**: `settings_screen.dart`
- **Route**: `/settings`
- **Role gate**: Admin
- **User flows**:
    1. **Update Settings**: Update HOA name/address/penalty settings.
- **Reads/Writes**: `settings`

**Screen**: `audit_screen.dart`
- **Route**: `/audit`
- **Role gate**: Admin
- **User flows**:
    1. **View Logs**: Review audit trail.
- **Reads**: `audit_logs`

**Screen**: `documents_screen.dart`
- **Route**: `/documents`
- **Role gate**: Admin, Officer
- **Entry points**: Nav item
- **User flows**:
    1. **Upload Doc**: Upload to Firestore/Storage.
- **Reads/Writes**: `documents`
