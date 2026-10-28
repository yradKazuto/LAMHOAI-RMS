// features/feedback/screens/feedback_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/feedback_model.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/design_tokens.dart';


class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _fs         = FirestoreService();
  final _searchCtrl = TextEditingController();
  FeedbackStatus?   _statusFilter;

  
  
  

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FeedbackModel> _filtered(List<FeedbackModel> all) {
    final q = _searchCtrl.text.toLowerCase();
    return all.where((f) {
      final matchSearch = q.isEmpty ||
          f.memberName.toLowerCase().contains(q) ||
          f.email.toLowerCase().contains(q) ||
          (f.title != null && f.title!.toLowerCase().contains(q)) ||
          f.message.toLowerCase().contains(q);
      final matchStatus = _statusFilter == null ||
          f.status == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();
  }

  Color _statusColor(FeedbackStatus s) {
    switch (s) {
      case FeedbackStatus.pending:   return AppColors.warning;
      case FeedbackStatus.reviewed:  return AppColors.dataInk;
      case FeedbackStatus.resolved:  return AppColors.success;
    }
  }

  Color _statusBg(FeedbackStatus s) {
    switch (s) {
      case FeedbackStatus.pending:   return AppColors.warningBg;
      case FeedbackStatus.reviewed:  return AppColors.primaryBg;
      case FeedbackStatus.resolved:  return AppColors.successBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final canUpdate = auth.isAdmin || auth.isOfficer;
    final phoneScreen = MediaQuery.of(context).size.width < 560;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  tooltip: 'Back to Dashboard',
                  onPressed: () => context.go(AppRoutes.dashboard),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Feedback',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                        'Review homeowner feedback and suggestions',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
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
                    hintText: 'Search member, title or message...',
                    hintStyle: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted),
                    prefixIcon:
                        const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.borderStrong)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.borderStrong)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
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
                      foregroundColor: AppColors.textSecondary),
                );

                void openFilterSheet() {
                  FeedbackStatus? tempStatus = _statusFilter;

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
                                    color: AppColors.borderStrong,
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Text('Filter Feedback',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary)),
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
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.textInverted,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                        color:
                                            AppColors.borderStrong),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<FeedbackStatus?>(
                                      value: tempStatus,
                                      isExpanded: true,
                                      hint: Text('All Statuses',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textMuted)),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textPrimary),
                                      icon: const Icon(Icons.expand_more,
                                          size: 18),
                                      items: [
                                        const DropdownMenuItem(
                                            value: null,
                                            child: Text('All Statuses')),
                                        ...FeedbackStatus.values.map(
                                            (s) => DropdownMenuItem(
                                                  value: s,
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
                                    backgroundColor: AppColors.textPrimary,
                                    foregroundColor: AppColors.textInverted,
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
                  color: AppColors.textInverted,
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
                                ? AppColors.primary
                                : AppColors.borderStrong),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_list,
                              size: 18,
                              color: _statusFilter != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                              _statusFilter != null
                                  ? 'Filter (1)'
                                  : 'Filter',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _statusFilter != null
                                      ? AppColors.primary
                                      : AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                );

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
                          child: _FilterChipGroup<FeedbackStatus?>(
                            value: _statusFilter,
                            options: [
                              const MapEntry(null, 'All Statuses'),
                              ...FeedbackStatus.values.map(
                                  (s) => MapEntry(s, s.label)),
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
              child: StreamBuilder<List<FeedbackModel>>(
                stream: _fs.streamFeedback(),
                builder: (context, snap) {
                  if (snap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final feedbacks =
                      _filtered(snap.data ?? []);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 700;

                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.textInverted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.dataInk
                                  .withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (!compact) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                decoration: const BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius:
                                      BorderRadius.vertical(
                                          top: Radius.circular(12)),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(flex: 2, child: _TH('Member')),
                                    Expanded(flex: 3, child: _TH('Category / Title')),
                                    Expanded(flex: 2, child: _TH('Date')),
                                    Expanded(flex: 2, child: _TH('Status')),
                                    SizedBox(width: 48),
                                  ],
                                ),
                              ),
                              const Divider(
                                  height: 1,
                                  color: AppColors.border),
                            ],

                            if (feedbacks.isEmpty)
                              const Expanded(
                                child: Center(
                                  child: Text(
                                      'No feedback found.',
                                      style: TextStyle(
                                          color: AppColors.textMuted)),
                                ),
                              )
                            else
                              Expanded(
                                child: ListView.separated(
                                  itemCount: feedbacks.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(
                                          height: 1,
                                          color:
                                              AppColors.background),
                                  itemBuilder: (context, i) =>
                                      _FeedbackRow(
                                    feedback:    feedbacks[i],
                                    canUpdate:   canUpdate,
                                    fs:          _fs,
                                    auth:        auth,
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

// ── Feedback row ─────────────────────────────────────────────────────────────
class _FeedbackRow extends StatelessWidget {
  final FeedbackModel    feedback;
  final bool             canUpdate;
  final FirestoreService fs;
  final AuthProvider     auth;
  final Color Function(FeedbackStatus) statusColor;
  final Color Function(FeedbackStatus) statusBg;
  final bool             compact;

  const _FeedbackRow({
    required this.feedback,
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
      color: statusBg(feedback.status),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      feedback.status.label,
      textAlign: TextAlign.center,
      style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: statusColor(feedback.status)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
                color: statusColor(feedback.status), width: 3),
          ),
        ),
        child: InkWell(
          onTap: () => _showDetailSheet(context),
          hoverColor: AppColors.background,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(feedback.memberName,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    _statusPill(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(feedback.message,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(_fmt(feedback.createdAt),
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted)),
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        size: 18, color: AppColors.textMuted),
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
              color: statusColor(feedback.status), width: 3),
        ),
      ),
      child: InkWell(
        onTap: () => _showDetailSheet(context),
        hoverColor: AppColors.background,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(feedback.memberName,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 3,
                child: Text(
                    feedback.title != null && feedback.title!.isNotEmpty
                        ? '${feedback.title} (${feedback.category})'
                        : feedback.category,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 2,
                child: Text(_fmt(feedback.createdAt),
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary)),
              ),
              Expanded(
                flex: 2,
                child: _statusPill(),
              ),
              SizedBox(
                width: 48,
                child: Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
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
      builder: (_) => _FeedbackDetailSheet(
        feedback:    feedback,
        canUpdate:   canUpdate,
        fs:          fs,
        auth:        auth,
        statusColor: statusColor,
        statusBg:    statusBg,
      ),
    );
  }
}

// ── Feedback detail bottom sheet ─────────────────────────────────────────────
class _FeedbackDetailSheet extends StatefulWidget {
  final FeedbackModel    feedback;
  final bool             canUpdate;
  final FirestoreService fs;
  final AuthProvider     auth;
  final Color Function(FeedbackStatus) statusColor;
  final Color Function(FeedbackStatus) statusBg;

  const _FeedbackDetailSheet({
    required this.feedback,
    required this.canUpdate,
    required this.fs,
    required this.auth,
    required this.statusColor,
    required this.statusBg,
  });

  @override
  State<_FeedbackDetailSheet> createState() =>
      _FeedbackDetailSheetState();
}

class _FeedbackDetailSheetState
    extends State<_FeedbackDetailSheet> {
  late FeedbackStatus _selectedStatus;
  final _noteCtrl = TextEditingController();
  bool _loading   = false;

  

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.feedback.status;
    _noteCtrl.text  = widget.feedback.resolutionNote;
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

    try {
      await widget.fs.updateFeedbackStatus(
        feedbackId:     widget.feedback.id,
        status:         _selectedStatus,
        resolvedBy:     widget.auth.userModel?.uid ?? '',
        resolutionNote: _noteCtrl.text.trim(),
      );

      // Audit log
      await SettingsService().logAction(
        performedBy:      widget.auth.userModel?.uid ?? '',
        performedByName:  widget.auth.userModel?.displayName ?? '',
        action:           AuditAction.statusChanged,
        targetCollection: 'feedback',
        targetId:         widget.feedback.id,
        description:      'Updated feedback status to ${_selectedStatus.label}',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback status updated.'),
            backgroundColor: AppColors.success,
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
          color: AppColors.textInverted,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Text(widget.feedback.title ?? 'Feedback',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.statusBg(
                        widget.feedback.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.feedback.status.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.statusColor(
                            widget.feedback.status)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Submitted by ${widget.feedback.memberName} (${widget.feedback.email}) on '
              '${_fmt(widget.feedback.createdAt)} • Category: ${widget.feedback.category}'
              '${widget.feedback.rating != null ? ' • Rating: ${widget.feedback.rating}/5 ⭐' : ''}',
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),

            const Text('Message',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
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
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.border),
                      ),
                      child: Text(
                        widget.feedback.message,
                        style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                            height: 1.55),
                      ),
                    ),

                    if (widget.canUpdate) ...[
                      const SizedBox(height: 20),

                      const Text('Update Status',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: FeedbackStatus.values
                            .map((s) => ChoiceChip(
                                  label: Text(s.label),
                                  selected:
                                      _selectedStatus == s,
                                  selectedColor:
                                      AppColors.textPrimary,
                                  labelStyle: TextStyle(
                                      fontSize: 12.5,
                                      color:
                                          _selectedStatus == s
                                              ? AppColors.surface
                                              : AppColors.textSecondary),
                                  onSelected: (_) => setState(
                                      () => _selectedStatus =
                                          s),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),

                      const Text('Notes / Response',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _noteCtrl,
                        maxLines: 3,
                        style:
                            const TextStyle(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText:
                              'Add a note or response...',
                          hintStyle: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted),
                          filled: true,
                          fillColor:
                              AppColors.background,
                          contentPadding:
                              const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color:
                                      AppColors.borderStrong)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color:
                                      AppColors.borderStrong)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: AppColors.primary,
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
                            backgroundColor: AppColors.textPrimary,
                            foregroundColor: AppColors.textInverted,
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
                                              AppColors.surface))
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
                        color: AppColors.textInverted,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.border),
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
                                      color: AppColors.textPrimary)),
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
                                backgroundColor: AppColors.textPrimary,
                                foregroundColor: AppColors.textInverted,
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
        color: AppColors.textInverted,
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
                      ? AppColors.primary
                      : AppColors.borderStrong),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list,
                    size: 18,
                    color: widget.activeFilterCount > 0
                        ? AppColors.primary
                        : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                    widget.activeFilterCount > 0
                        ? 'Filter (${widget.activeFilterCount})'
                        : 'Filter',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.activeFilterCount > 0
                            ? AppColors.primary
                            : AppColors.textPrimary)),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChipGroup<T> extends StatelessWidget {
  final T value;
  final List<MapEntry<T, String>> options;
  final ValueChanged<T> onChanged;

  const _FilterChipGroup({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  

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
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.borderStrong),
          ),
          child: Text(opt.value,
              style: TextStyle(
                  fontSize: 12.5,
                  color:
                      selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
    }).toList(),
  );
}

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
                color: AppColors.textSecondary)),
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
          color: AppColors.textSecondary,
          letterSpacing: 0.4));
}