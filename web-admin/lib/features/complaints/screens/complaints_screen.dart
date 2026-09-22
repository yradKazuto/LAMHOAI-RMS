// features/complaints/screens/complaints_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/complaint_model.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/routing/app_router.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});
  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final _fs          = FirestoreService();
  final _searchCtrl  = TextEditingController();
  String?           _statusFilter;

  static const Color _navy   = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _bg     = Color(0xFFF4F7FB);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ComplaintModel> _filtered(List<ComplaintModel> all) {
    final q = _searchCtrl.text.toLowerCase();
    return all.where((c) {
      final matchSearch = q.isEmpty ||
          c.memberName.toLowerCase().contains(q) ||
          c.subject.toLowerCase().contains(q);
      final matchStatus = _statusFilter == null ||
          c.status.name == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();
  }

  Color _statusColor(ComplaintStatus s) {
    switch (s) {
      case ComplaintStatus.pending:   return const Color(0xFF7A6A1A);
      case ComplaintStatus.reviewing: return const Color(0xFF1A4A9C);
      case ComplaintStatus.resolved:  return const Color(0xFF1A7A4A);
      case ComplaintStatus.rejected:  return const Color(0xFFCC2200);
    }
  }

  Color _statusBg(ComplaintStatus s) {
    switch (s) {
      case ComplaintStatus.pending:   return const Color(0xFFFFF8E0);
      case ComplaintStatus.reviewing: return const Color(0xFFEEF4FF);
      case ComplaintStatus.resolved:  return const Color(0xFFEAF7F0);
      case ComplaintStatus.rejected:  return const Color(0xFFFFF0EE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final canUpdate = auth.isAdmin || auth.isOfficer;
    final phoneScreen = MediaQuery.of(context).size.width < 560;

    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
            phoneScreen ? 16 : 28,
            phoneScreen ? 14 : 28,
            phoneScreen ? 16 : 28,
            phoneScreen ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: _navy),
                  tooltip: 'Back to Dashboard',
                  onPressed: () => context.go(AppRoutes.dashboard),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Complaints',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 2),
                    Text(
                        'Review and resolve homeowner complaints',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
            SizedBox(height: phoneScreen ? 14 : 24),

            // ── Filters ───────────────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final searchField = TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search member or subject...',
                    hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[400]),
                    prefixIcon:
                        const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFFD0DBEE))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFFD0DBEE))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: _accent, width: 1.5)),
                  ),
                );

                final hasActiveFilter =
                    _searchCtrl.text.isNotEmpty ||
                    _statusFilter != null;

                final clearButton = TextButton.icon(
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _statusFilter = null;
                  }),
                  icon: const Icon(Icons.clear, size: 15),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600]),
                );

                void openFilterSheet() {
                  String? tempStatus = _statusFilter;

                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (sheetCtx) => StatefulBuilder(
                      builder: (sheetCtx, setSheetState) => SafeArea(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 14, 20, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  margin:
                                      const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Text('Filter Complaints',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: _navy)),
                                  const Spacer(),
                                  if (tempStatus != null)
                                    TextButton(
                                      onPressed: () => setSheetState(
                                          () => tempStatus = null),
                                      child: const Text('Reset'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text('Status',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600])),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                        color:
                                            const Color(0xFFD0DBEE)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      value: tempStatus,
                                      isExpanded: true,
                                      hint: Text('All Statuses',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[500])),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF1A2B4A)),
                                      icon: const Icon(Icons.expand_more,
                                          size: 18),
                                      items: [
                                        const DropdownMenuItem(
                                            value: null,
                                            child: Text('All Statuses')),
                                        ...ComplaintStatus.values.map(
                                            (s) => DropdownMenuItem(
                                                  value: s.name,
                                                  child: Text(s.label),
                                                )),
                                      ],
                                      onChanged: (v) => setSheetState(
                                          () => tempStatus = v),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(
                                        () => _statusFilter = tempStatus);
                                    Navigator.pop(sheetCtx);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _navy,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Apply Filters'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final filterButton = Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: openFilterSheet,
                    child: Container(
                      height: 42,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _statusFilter != null
                                ? _accent
                                : const Color(0xFFD0DBEE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_list,
                              size: 18,
                              color: _statusFilter != null
                                  ? _accent
                                  : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                              _statusFilter != null
                                  ? 'Filter (1)'
                                  : 'Filter',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _statusFilter != null
                                      ? _accent
                                      : const Color(0xFF1A2B4A))),
                        ],
                      ),
                    ),
                  ),
                );

                // A fixed-width search box plus a dropdown can't share
                // one line below this width — swap in the Filter
                // button beside the search field instead.
                final narrow = constraints.maxWidth < 560;

                if (narrow) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 10),
                          filterButton,
                        ],
                      ),
                      if (hasActiveFilter) ...[
                        const SizedBox(height: 10),
                        clearButton,
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    SizedBox(width: 260, child: searchField),
                    const SizedBox(width: 12),
                    _FilterPopoverButton(
                      activeFilterCount:
                          _statusFilter != null ? 1 : 0,
                      panelBuilder: (context, setPanelState, close) => [
                        _PopoverFilterField(
                          label: 'Status',
                          child: _FilterChipGroup<String?>(
                            value: _statusFilter,
                            options: [
                              const MapEntry(null, 'All Statuses'),
                              ...ComplaintStatus.values.map(
                                  (s) => MapEntry(s.name, s.label)),
                            ],
                            onChanged: (v) {
                              setState(() => _statusFilter = v);
                              setPanelState(() {});
                            },
                          ),
                        ),
                      ],
                      onReset: () =>
                          setState(() => _statusFilter = null),
                    ),
                    if (hasActiveFilter) ...[
                      const SizedBox(width: 10),
                      clearButton,
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Table ─────────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<ComplaintModel>>(
                stream: _fs.streamComplaints(),
                builder: (context, snap) {
                  if (snap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final complaints =
                      _filtered(snap.data ?? []);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Fixed Member/Subject/Date/Status columns can't
                      // stay readable below this width — switch each
                      // row to a stacked card instead.
                      final compact = constraints.maxWidth < 700;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE0E8F4)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1A4A9C)
                                  .withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header (desktop/tablet column labels only —
                            // a compact card layout has no matching
                            // columns to label)
                            if (!compact) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF7F9FC),
                                  borderRadius:
                                      BorderRadius.vertical(
                                          top: Radius.circular(12)),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(flex: 2, child: _TH('Member')),
                                    Expanded(flex: 3, child: _TH('Subject')),
                                    Expanded(flex: 2, child: _TH('Date Filed')),
                                    Expanded(flex: 2, child: _TH('Status')),
                                    SizedBox(width: 48),
                                  ],
                                ),
                              ),
                              const Divider(
                                  height: 1,
                                  color: Color(0xFFE0E8F4)),
                            ],

                            if (complaints.isEmpty)
                              const Expanded(
                                child: Center(
                                  child: Text(
                                      'No complaints found.',
                                      style: TextStyle(
                                          color: Colors.grey)),
                                ),
                              )
                            else
                              Expanded(
                                child: ListView.separated(
                                  itemCount: complaints.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(
                                          height: 1,
                                          color:
                                              Color(0xFFEEF2F9)),
                                  itemBuilder: (context, i) =>
                                      _ComplaintRow(
                                    complaint:  complaints[i],
                                    canUpdate:  canUpdate,
                                    fs:         _fs,
                                    auth:       auth,
                                    statusColor: _statusColor,
                                    statusBg:    _statusBg,
                                    compact:     compact,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Complaint row ─────────────────────────────────────────────────────────────
class _ComplaintRow extends StatelessWidget {
  final ComplaintModel   complaint;
  final bool             canUpdate;
  final FirestoreService fs;
  final AuthProvider     auth;
  final Color Function(ComplaintStatus) statusColor;
  final Color Function(ComplaintStatus) statusBg;
  final bool             compact;

  const _ComplaintRow({
    required this.complaint,
    required this.canUpdate,
    required this.fs,
    required this.auth,
    required this.statusColor,
    required this.statusBg,
    this.compact = false,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _statusPill() => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: statusBg(complaint.status),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      complaint.status.label,
      textAlign: TextAlign.center,
      style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: statusColor(complaint.status)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (compact) {
      // Stacked card — the fixed Member/Subject/Date/Status columns
      // don't have room to stay readable at phone widths.
      return Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
                color: statusColor(complaint.status), width: 3),
          ),
        ),
        child: InkWell(
        onTap: () => _showDetailSheet(context),
        hoverColor: const Color(0xFFF4F7FB),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(complaint.memberName,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  _statusPill(),
                ],
              ),
              const SizedBox(height: 4),
              Text(complaint.subject,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(_fmt(complaint.createdAt),
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500])),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      size: 18, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: statusColor(complaint.status), width: 3),
        ),
      ),
      child: InkWell(
      onTap: () => _showDetailSheet(context),
      hoverColor: const Color(0xFFF4F7FB),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(complaint.memberName,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 3,
              child: Text(complaint.subject,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(_fmt(complaint.createdAt),
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600])),
            ),
            Expanded(
              flex: 2,
              child: _statusPill(),
            ),
            SizedBox(
              width: 48,
              child: Icon(Icons.chevron_right,
                  size: 18, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComplaintDetailSheet(
        complaint:   complaint,
        canUpdate:   canUpdate,
        fs:          fs,
        auth:        auth,
        statusColor: statusColor,
        statusBg:    statusBg,
      ),
    );
  }
}

// ── Complaint detail bottom sheet ─────────────────────────────────────────────
class _ComplaintDetailSheet extends StatefulWidget {
  final ComplaintModel   complaint;
  final bool             canUpdate;
  final FirestoreService fs;
  final AuthProvider     auth;
  final Color Function(ComplaintStatus) statusColor;
  final Color Function(ComplaintStatus) statusBg;

  const _ComplaintDetailSheet({
    required this.complaint,
    required this.canUpdate,
    required this.fs,
    required this.auth,
    required this.statusColor,
    required this.statusBg,
  });

  @override
  State<_ComplaintDetailSheet> createState() =>
      _ComplaintDetailSheetState();
}

class _ComplaintDetailSheetState
    extends State<_ComplaintDetailSheet> {
  late ComplaintStatus _selectedStatus;
  final _noteCtrl = TextEditingController();
  final _notif    = NotificationService();
  bool _loading   = false;

  static const Color _navy = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.complaint.status;
    _noteCtrl.text  = widget.complaint.resolutionNote;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _updateStatus() async {
    setState(() => _loading = true);

    // Remember the original status BEFORE updating, so we only notify
    // when it's actually changing to resolved/rejected — not on every
    // save (e.g. editing the note while status stays the same).
    final previousStatus = widget.complaint.status;

    try {
      await widget.fs.updateComplaintStatus(
        complaintId:    widget.complaint.id,
        status:         _selectedStatus,
        resolvedBy:     widget.auth.userModel?.uid ?? '',
        resolutionNote: _noteCtrl.text.trim(),
      );

      // ── Audit log ────────────────────────────────────────────────────
      await SettingsService().logAction(
        performedBy:      widget.auth.userModel?.uid ?? '',
        performedByName:  widget.auth.userModel?.displayName ?? '',
        action:           AuditAction.statusChanged,
        targetCollection: 'complaints',
        targetId:         widget.complaint.id,
        description:      'Changed complaint "${widget.complaint.subject}" '
                           'status from ${previousStatus.label} to '
                           '${_selectedStatus.label}',
      );

      // Notify the member only when the status is genuinely changing
      // to a final outcome (resolved or rejected).
      final justResolved = _selectedStatus == ComplaintStatus.resolved &&
          previousStatus != ComplaintStatus.resolved;
      final justRejected = _selectedStatus == ComplaintStatus.rejected &&
          previousStatus != ComplaintStatus.rejected;

      if (justResolved || justRejected) {
        final note = _noteCtrl.text.trim();
        final title =
            justResolved ? 'Complaint Resolved' : 'Complaint Update';
        final body = justResolved
            ? 'Your complaint "${widget.complaint.subject}" has been resolved'
                '${note.isNotEmpty ? ': $note' : '.'}'
            : 'Your complaint "${widget.complaint.subject}" was not approved'
                '${note.isNotEmpty ? ': $note' : '.'}';

        // Fire-and-forget — don't block the UI on push delivery; the
        // status update itself already succeeded and is what matters most.
        _notif.sendToMember(
          uid: widget.complaint.uid,
          title: title,
          body: body,
          type: 'complaint',
          extraData: {'complaintId': widget.complaint.id},
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint status updated.'),
            backgroundColor: Color(0xFF1A7A4A),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Expanded(
                  child: Text(widget.complaint.subject,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _navy)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.statusBg(
                        widget.complaint.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.complaint.status.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.statusColor(
                            widget.complaint.status)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Filed by ${widget.complaint.memberName} on '
              '${_fmt(widget.complaint.createdAt)}',
              style: TextStyle(
                  fontSize: 12.5, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE0E8F4)),
            const SizedBox(height: 12),

            // Description
            const Text('Description',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _navy)),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFE0E8F4)),
                      ),
                      child: Text(
                        widget.complaint.description,
                        style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF1A2B4A),
                            height: 1.55),
                      ),
                    ),

                    if (widget.canUpdate) ...[
                      const SizedBox(height: 20),

                      // Status update
                      const Text('Update Status',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _navy)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ComplaintStatus.values
                            .map((s) => ChoiceChip(
                                  label: Text(s.label),
                                  selected:
                                      _selectedStatus == s,
                                  selectedColor:
                                      const Color(0xFF1E293B),
                                  labelStyle: TextStyle(
                                      fontSize: 12.5,
                                      color:
                                          _selectedStatus == s
                                              ? Colors.white
                                              : Colors.grey[700]),
                                  onSelected: (_) => setState(
                                      () => _selectedStatus =
                                          s),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),

                      // Resolution note
                      const Text('Resolution Note',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _navy)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _noteCtrl,
                        maxLines: 3,
                        style:
                            const TextStyle(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText:
                              'Add a resolution note...',
                          hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400]),
                          filled: true,
                          fillColor:
                              const Color(0xFFF7F9FC),
                          contentPadding:
                              const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color:
                                      Color(0xFFD0DBEE))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color:
                                      Color(0xFFD0DBEE))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFF2563EB),
                                  width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _loading ? null : _updateStatus,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8)),
                            padding:
                                const EdgeInsets.symmetric(
                                    vertical: 14),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color:
                                              Colors.white))
                              : const Text('Save Status',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter popover button (desktop) ──────────────────────────────────────────
// Anchors a "Filter" button to a floating panel below it via
// CompositedTransformTarget/Follower + an OverlayEntry — a proper
// desktop dropdown panel, rather than reusing the mobile bottom sheet
// on a screen wide enough that a sheet sliding up from the bottom
// edge would look out of place.
class _FilterPopoverButton extends StatefulWidget {
  final int activeFilterCount;
  final List<Widget> Function(
    BuildContext context,
    void Function(void Function()) setPanelState,
    VoidCallback close,
  ) panelBuilder;
  final VoidCallback onReset;

  const _FilterPopoverButton({
    required this.activeFilterCount,
    required this.panelBuilder,
    required this.onReset,
  });

  @override
  State<_FilterPopoverButton> createState() => _FilterPopoverButtonState();
}

class _FilterPopoverButtonState extends State<_FilterPopoverButton> {
  static const Color _navy   = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF2563EB);

  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _toggle() => _entry == null ? _open() : _close();

  void _open() {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: const Offset(0, 48),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {},
                  child: StatefulBuilder(
                    builder: (panelContext, setPanelState) => Container(
                      width: 300,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFFE0E8F4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Filters',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _navy)),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  widget.onReset();
                                  setPanelState(() {});
                                },
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap),
                                child: const Text('Reset',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...widget.panelBuilder(
                              panelContext, setPanelState, _close),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _close,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _navy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                              child: const Text('Done',
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _toggle,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: widget.activeFilterCount > 0
                      ? _accent
                      : const Color(0xFFD0DBEE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list,
                    size: 18,
                    color: widget.activeFilterCount > 0
                        ? _accent
                        : Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                    widget.activeFilterCount > 0
                        ? 'Filter (${widget.activeFilterCount})'
                        : 'Filter',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.activeFilterCount > 0
                            ? _accent
                            : const Color(0xFF1A2B4A))),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 16, color: Colors.grey[500]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A row of tappable chips for picking one filter value — used inside
// popover panels instead of a nested DropdownButton, since a dropdown
// menu opening from inside a custom OverlayEntry panel can end up
// rendering behind the panel itself. A flat chip list avoids that.
class _FilterChipGroup<T> extends StatelessWidget {
  final T value;
  final List<MapEntry<T, String>> options;
  final ValueChanged<T> onChanged;

  const _FilterChipGroup({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  static const Color _accent = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options.map((opt) {
      final selected = opt.key == value;
      return InkWell(
        onTap: () => onChanged(opt.key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? _accent.withOpacity(0.1)
                : const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? _accent : const Color(0xFFD0DBEE)),
          ),
          child: Text(opt.value,
              style: TextStyle(
                  fontSize: 12.5,
                  color:
                      selected ? _accent : const Color(0xFF1A2B4A),
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
    }).toList(),
  );
}

// A labeled filter field inside a popover panel.
class _PopoverFilterField extends StatelessWidget {
  final String label;
  final Widget child;
  const _PopoverFilterField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600])),
        const SizedBox(height: 5),
        SizedBox(width: double.infinity, child: child),
      ],
    ),
  );
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5A7099),
          letterSpacing: 0.4));
}