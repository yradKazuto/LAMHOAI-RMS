# HOA RMS - Core Model Class Diagram

```mermaid
classDiagram
    %% Core Models
    class UserModel {
        <<Firestore Entity>>
        +String uid
        +String displayName
        +String email
        +UserRole role
        +bool isActive
        +DateTime createdAt
        +DateTime? lastSignIn
        +Map<String, dynamic> toMap()
        +factory UserModel.fromMap(Map, String)
    }

    class StaffModel {
        <<Firestore Entity>>
        +String uid
        +String displayName
        +String email
        +UserRole role
        +bool isActive
        +DateTime createdAt
        +Map<String, dynamic> toMap()
        +factory StaffModel.fromMap(Map, String)
        +StaffModel copyWith()
    }

    class MemberModel {
        <<Firestore Entity>>
        +String uid
        +String name          // displayName in Firestore
        +String email
        +String role          // legacy role string
        +String lotNumber
        +String phase
        +MemberStatus status
        +String contactNumber
        +String address
        +String photoUrl
        +DateTime createdAt
        +Map<String, dynamic> toMap()
        +factory MemberModel.fromMap(Map, String)
    }

    class PaymentModel {
        <<Firestore Entity>>
        +String id
        +String uid          // member UID (FK to MemberModel.uid)
        +String memberName   // denormalized for display
        +PaymentType type
        +double amount
        +PaymentStatus status
        +DateTime dueDate
        +DateTime? paidDate
        +String recordedBy   // staff UID who recorded (FK to StaffModel.uid)
        +String notes
        +DateTime createdAt
        +String lotId        // FK to LotModel.id (optional)
        +String lotLabel     // denormalized
        +Map<String, dynamic> toMap()
        +factory PaymentModel.fromMap(Map, String)
    }

    class LotModel {
        <<Firestore Entity>>
        +String id
        +String phase
        +String block
        +String lotNumber
        +double? areaSqm
        +LotStatus status
        +String? uid           // member UID (FK to MemberModel.uid, nullable)
        +String? ownerName
        +double? price
        +String? contactNumber
        +String? notes
        +String updatedBy      // staff UID (FK to StaffModel.uid)
        +Timestamp updatedAt
        +double? mapX
        +double? mapY
        +List<LotPoint>? polygonPoints
        +Map<String, dynamic> toMap()
        +factory LotModel.fromMap(Map, String)
    }

    class DocumentModel {
        <<Firestore Entity>>
        +String id
        +String uid          // member UID (FK to MemberModel.uid)
        +String memberName   // denormalized
        +DocumentType type
        +String fileName
        +String fileUrl
        +String uploadedBy   // staff UID (FK to StaffModel.uid)
        +DateTime createdAt
        +Map<String, dynamic> toMap()
        +factory DocumentModel.fromMap(Map, String)
    }

    class ComplaintModel {
        <<Firestore Entity>>
        +String id
        +String uid           // member UID (FK to MemberModel.uid)
        +String memberName    // denormalized
        +String subject
        +String description
        +ComplaintStatus status
        +String resolvedBy    // staff UID who resolved (FK to StaffModel.uid, nullable)
        +String resolutionNote
        +DateTime createdAt
        +DateTime? updatedAt
        +Map<String, dynamic> toMap()
        +factory ComplaintModel.fromMap(Map, String)
    }

    class FeedbackModel {
        <<Firestore Entity>>
        +String id
        +String uid           // member UID (FK to MemberModel.uid)
        +String memberName    // denormalized
        +String email
        +String? title
        +String message
        +String category
        +int? rating
        +FeedbackStatus status
        +String resolvedBy    // staff UID who resolved (FK to StaffModel.uid, nullable)
        +String resolutionNote
        +DateTime createdAt
        +DateTime? updatedAt
        +String? platform
        +Map<String, dynamic> toMap()
        +factory FeedbackModel.fromMap(Map, String)
    }

    class AuditLogModel {
        <<Firestore Entity>>
        +String id
        +String performedBy      // staff UID (FK to StaffModel.uid)
        +String performedByName  // denormalized
        +AuditAction action
        +String targetCollection // e.g. 'members', 'payments'
        +String targetId
        +String description
        +DateTime createdAt
        +Map<String, dynamic> toMap()
        +factory AuditLogModel.fromMap(Map, String)
    }

    class HoaSettingsModel {
        <<Singleton>>
        +bool emailNotificationsEnabled
        +bool smsNotificationsEnabled
        +int penaltyDaysLate
        +double penaltyAmount
        +double penaltyRatePerDay
        +double penaltyMaxPercent
        +int graceDays
        +DateTime lastUpdated
        +String updatedBy
        +Map<String, dynamic> toMap()
        +factory HoaSettingsModel.fromMap(Map)
    }

    class DuesConfig {
        <<Value Object>>
        +double baseAmount
        +double lateFee
        +DateTime effectiveDate
        +String description
        +Map<String, dynamic> toMap()
        +factory DuesConfig.fromMap(Map)
    }

    class DuesConfigHistoryModel {
        <<Firestore Entity>>
        +String id
        +DuesConfig config
        +String changedBy     // staff UID (FK to StaffModel.uid)
        +DateTime changedAt
        +String reason
        +Map<String, dynamic> toMap()
        +factory DuesConfigHistoryModel.fromMap(Map, String)
    }

    class AnnouncementModel {
        <<Firestore Entity>>
        +String id
        +String title
        +String content
        +String postedByName   // staff name who posted
        +bool isActive
        +DateTime createdAt
        +DateTime? expiresAt
        +Map<String, dynamic> toMap()
        +factory AnnouncementModel.fromMap(Map, String)
    }

    class PhaseMapModel {
        <<Firestore Entity>>
        +String id
        +String name
        +String imageUrl
        +String uploadedBy     // staff UID (FK to StaffModel.uid)
        +DateTime createdAt
        +Map<String, dynamic> toMap()
        +factory PhaseMapModel.fromMap(Map, String)
    }

    %% Supporting Models
    class LotPoint {
        +double x
        +double y
        +LotPoint(this.x, this.y)
    }

    %% Enumerations
    enum UserRole {
        admin
        accountant
        officer
        unknown
    }

    enum MemberStatus {
        active
        inactive
        delinquent
    }

    enum PaymentType {
        dues
        membershipFee
        lotPayment
        penalty
        specialAssessment
        other
    }

    enum PaymentStatus {
        paid
        unpaid
        overdue
        waived
    }

    enum ComplaintStatus {
        pending
        reviewing
        resolved
        rejected
    }

    enum FeedbackStatus {
        pending
        reviewed
        resolved
    }

    enum LotStatus {
        occupied
        vacant
        forSale
        reserved
    }

    enum AuditAction {
        CREATE
        READ
        UPDATE
        DELETE
        LOGIN
        LOGOUT
        APPROVE
        REJECT
    }

    %% Relationships
    UserModel |||.."manages" StaffModel : role
    StaffModel |||.."records" PaymentModel : recordedBy
    StaffModel |||.."uploads" DocumentModel : uploadedBy
    StaffModel |||.."resolves" ComplaintModel : resolvedBy
    StaffModel |||.."resolves" FeedbackModel : resolvedBy
    StaffModel |||.."updates" LotModel : updatedBy
    StaffModel |||.."creates" HoaSettingsModel : updatedBy
    StaffModel |||.."modifies" DuesConfigHistoryModel : changedBy
    StaffModel |||.."posts" AnnouncementModel : postedByName
    StaffModel |||.."uploads" PhaseMapModel : uploadedBy
    StaffModel |||.."logs" AuditLogModel : performedBy

    MemberModel }|.."makes" PaymentModel : uid
    MemberModel }|.."owns" DocumentModel : uid
    MemberModel }|.."files" ComplaintModel : uid
    MemberModel }|.."submits" FeedbackModel : uid
    MemberModel }|.."occupies" LotModel : uid

    LotModel }|.."contains" LotPoint : polygonPoints
    PaymentModel }|.."applies to" LotModel : lotId
```

## Key Relationships Summary

- **Staff ↔ Records**: Staff members record payments, upload documents, resolve complaints/feedback, update lot info, manage settings, post announcements, upload phase maps, and audit actions.
- **Members ↔ Transactions**: Members make payments, own documents, file complaints, submit feedback, and occupy lots.
- **Lots ↔ Points**: Lot polygons consist of multiple points; payments can optionally reference lots.
- **Settings & History**: Singleton settings track app configuration; history tracks dues config changes by staff.
- **Audit Trail**: All significant actions by staff are logged with target entity references.

*Note: This diagram reflects the core data models as of the latest commit. Denormalized fields (like `memberName`) are kept for UI performance but represent the same logical relationship as the UID foreign key.*