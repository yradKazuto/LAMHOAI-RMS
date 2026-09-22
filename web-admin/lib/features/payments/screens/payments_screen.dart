// features/payments/screens/payments_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/settings_service.dart';
import 'add_payment_screen.dart';
import 'membership_dues_screen.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_router.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _fs       = FirestoreService();
  final _settings = SettingsService();
  final _search   = TextEditingController();
  final _notif    = NotificationService();

  bool _sendingReminders = false;

  // Created ONCE. Building `_fs.streamPayments()` inline in build() opened
  // brand-new Firestore listeners on every rebuild (i.e. every keystroke in
  // the search box) — the same listener churn described in
  // membership_dues_screen.dart. `asBroadcastStream()` lets the summary cards
  // and the table share this single listener.
  late final Stream<List<PaymentModel>> _paymentsStream =
      _fs.streamPayments().asBroadcastStream();

  // A broadcast stream does NOT replay its last event to a listener that
  // subscribes late — only the table (which listens from the first build)
  // sees the initial snapshot. The member-payments dialog subscribes when
  // it opens, potentially long after that snapshot fired, and would
  // otherwise spin forever waiting for the NEXT emission. Caching the
  // latest value here lets the dialog start with data immediately.
  List<PaymentModel>? _cachedPayments;
  StreamSubscription<List<PaymentModel>>? _cacheSub;

  String         _searchQuery  = '';
  PaymentStatus? _statusFilter;
  PaymentType?   _typeFilter;

  static const Color _navy   = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _bg     = Color(0xFFF4F7FB);

  @override
  void initState() {
    super.initState();
    // Bulk writes (overdue flip + penalties) are only run by people who are
    // allowed to record payments — not by every user who merely opens this
    // screen — and failures are caught instead of surfacing as unhandled
    // async errors.
    final auth = context.read<AuthProvider>();
    if (auth.isAdmin || auth.isAccountant) _runMaintenance();

    // `late final` only runs on first read — with nothing else reading it,
    // this subscription never started and _cachedPayments stayed null
    // forever, so the member-payments dialog just spun. Starting it here,
    // eagerly, is what actually makes the cache work.
    _cacheSub = _paymentsStream.listen((data) => _cachedPayments = data);
  }

  Future<void> _runMaintenance() async {
    try {
      // Free-tier stand-in for a scheduled Cloud Function — flips any
      // unpaid-and-past-due record to overdue for real. streamPayments()
      // picks up the change live.
      await _fs.syncOverdueStatuses();
      // Separate concern from the status flip above: adds the flat penalty
      // to any dues/membershipFee record that's past its grace period and
      // hasn't been penalized yet (see FirestoreService.applyOverduePenalties).
      await _applyPenalties();
    } catch (e) {
      debugPrint('Payment maintenance failed: $e');
    }
  }

  Future<void> _applyPenalties() async {
    final settings = await _settings.getSettings();
    await _fs.applyOverduePenalties(
      penaltyAmount: settings.dues.penalty,
      graceDays:     settings.dues.penaltyGraceDays,
    );
  }

  @override
  void dispose() {
    _cacheSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  List<PaymentModel> _filtered(List<PaymentModel> all) {
    return all.where((p) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          p.memberName.toLowerCase().contains(q) ||
          p.type.label.toLowerCase().contains(q) ||
          p.lotLabel.toLowerCase().contains(q);
      final matchStatus = _statusFilter == null || p.displayStatus == _statusFilter;
      final matchType   = _typeFilter   == null || p.type   == _typeFilter;
      return matchSearch && matchStatus && matchType;
    }).toList();
  }

  // Summary totals
  Map<String, double> _totals(List<PaymentModel> list) {
    double totalCollected = 0, totalPending = 0, totalOverdue = 0;
    for (final p in list) {
      if (p.status == PaymentStatus.paid)          totalCollected += p.amount;
      if (p.displayStatus == PaymentStatus.unpaid) totalPending   += p.amount;
      if (p.displayStatus == PaymentStatus.overdue) totalOverdue  += p.amount;
    }
    return {
      'collected': totalCollected,
      'pending':   totalPending,
      'overdue':   totalOverdue,
    };
  }

  Future<void> _sendDuesReminders() async {
    final days = await showDialog<int>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Send Dues Reminder',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        content: const Text(
            'Notify members whose unpaid dues are coming up within:',
            style: TextStyle(fontSize: 13.5)),
        actions: [
          for (final d in [1, 3, 7, 14])
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, d),
              child: Text('$d day${d == 1 ? '' : 's'}'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );

    if (days == null) return;

    setState(() => _sendingReminders = true);
    final result = await _notif.sendDuesReminders(daysAhead: days);
    if (mounted) {
      setState(() => _sendingReminders = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success
              ? const Color(0xFF1A7A4A)
              : const Color(0xFFCC2200),
        ),
      );
    }
  }

  void _showMemberPayments(String uid, String name) {
    final auth      = context.read<AuthProvider>();
    final canRecord = auth.isAdmin || auth.isAccountant;
    showDialog<void>(
      context: context,
      builder: (_) => _MemberPaymentsDialog(
        uid:            uid,
        memberName:     name,
        paymentsStream: _paymentsStream,
        initialPayments: _cachedPayments,
        fs:             _fs,
        canRecord:      canRecord,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final canRecord = auth.isAdmin || auth.isAccountant;
    final phoneScreen = MediaQuery.of(context).size.width < 560;

    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            phoneScreen ? 16 : 28,
            phoneScreen ? 14 : 28,
            phoneScreen ? 16 : 28,
            phoneScreen ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final phone = constraints.maxWidth < 560;

                final titleBlock = Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: _navy),
                      tooltip: 'Back to Dashboard',
                      onPressed: () => context.go(AppRoutes.dashboard),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payments',
                              style: TextStyle(
                                  fontSize: phone ? 19 : 22,
                                  fontWeight: FontWeight.w700,
                                  color: _navy)),
                          if (!phone) ...[
                            const SizedBox(height: 2),
                            Text('Track dues and payment records',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[600])),
                          ],
                        ],
                      ),
                    ),
                  ],
                );

                // A pill-shaped row of compact icon+label buttons that
                // divides the available width evenly — used on phones
                // where the full-label buttons below can't fit three
                // to a row even when wrapped.
                Widget compactButton({
                  required IconData icon,
                  required String label,
                  required String tooltip,
                  required VoidCallback? onPressed,
                  required bool filled,
                  bool loading = false,
                }) {
                  return Expanded(
                    child: Tooltip(
                      message: tooltip,
                      child: Material(
                        color: filled ? _navy : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: onPressed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: filled
                                  ? null
                                  : Border.all(color: _navy),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                loading
                                    ? SizedBox(
                                        width: 13, height: 13,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: filled
                                                ? Colors.white
                                                : _navy),
                                      )
                                    : Icon(icon,
                                        size: 15,
                                        color: filled
                                            ? Colors.white
                                            : _navy),
                                const SizedBox(height: 2),
                                Text(label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: filled
                                            ? Colors.white
                                            : _navy)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final compactRow = canRecord
                    ? Row(
                        children: [
                          compactButton(
                            icon: Icons.notifications_active_outlined,
                            label: _sendingReminders ? 'Sending' : 'Remind',
                            tooltip: 'Send Dues Reminder',
                            onPressed:
                                _sendingReminders ? null : _sendDuesReminders,
                            filled: false,
                            loading: _sendingReminders,
                          ),
                          const SizedBox(width: 8),
                          compactButton(
                            icon: Icons.groups_outlined,
                            label: 'Dues',
                            tooltip: 'Membership Dues',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const MembershipDuesScreen()),
                            ),
                            filled: false,
                          ),
                          const SizedBox(width: 8),
                          compactButton(
                            icon: Icons.add,
                            label: 'Record',
                            tooltip: 'Record Payment',
                            onPressed: () => AddPaymentScreen.show(context),
                            filled: true,
                          ),
                        ],
                      )
                    : null;

                final actionButtons = <Widget>[
                  if (canRecord) ...[
                    OutlinedButton.icon(
                      onPressed:
                          _sendingReminders ? null : _sendDuesReminders,
                      icon: _sendingReminders
                          ? const SizedBox(
                              width: 16, height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_active_outlined,
                              size: 18),
                      label: Text(_sendingReminders
                          ? 'Sending...'
                          : 'Send Dues Reminder'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: const BorderSide(color: _navy),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MembershipDuesScreen()),
                      ),
                      icon: const Icon(Icons.groups_outlined, size: 18),
                      label: const Text('Membership Dues'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: const BorderSide(color: _navy),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => AddPaymentScreen.show(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Record Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ];

                // Phones: title, then the three actions as one compact
                // row (icon + short label, evenly divided) so they
                // stay horizontal instead of wrapping to three lines —
                // that extra stacked height was what pushed the table
                // below the bottom of the screen.
                if (phone) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      if (compactRow != null) ...[
                        const SizedBox(height: 10),
                        compactRow,
                      ],
                    ],
                  );
                }

                // Tablet: full-label buttons, wrapped if needed.
                final narrow = constraints.maxWidth < 900;

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      if (actionButtons.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: actionButtons),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleBlock),
                    for (int i = 0; i < actionButtons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      actionButtons[i],
                    ],
                  ],
                );
              },
            ),
            LayoutBuilder(
              builder: (context, c) => SizedBox(
                  height: c.maxWidth < 560 ? 16 : 24),
            ),

            // ── Summary cards ─────────────────────────────────────────────────
            StreamBuilder<List<PaymentModel>>(
              stream: _paymentsStream,
              builder: (context, snap) {
                final all    = snap.data ?? [];
                final totals = _totals(all);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 640;
                    final cards = [
                      _SummaryCard(
                        label: 'Total Collected',
                        amount: totals['collected']!,
                        icon: Icons.check_circle_outline,
                        color: const Color(0xFF1A7A4A),
                        compact: compact,
                      ),
                      _SummaryCard(
                        label: 'Pending',
                        amount: totals['pending']!,
                        icon: Icons.schedule_outlined,
                        color: const Color(0xFF7A6A1A),
                        compact: compact,
                      ),
                      _SummaryCard(
                        label: 'Overdue',
                        amount: totals['overdue']!,
                        icon: Icons.warning_amber_outlined,
                        color: const Color(0xFFCC2200),
                        compact: compact,
                      ),
                    ];

                    return Row(
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          if (i > 0) SizedBox(width: compact ? 8 : 14),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Filters ───────────────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final searchField = TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: _searchDec('Search member, type or lot...'),
                );

                final hasActiveFilter = _searchQuery.isNotEmpty ||
                    _statusFilter != null ||
                    _typeFilter != null;

                final clearButton = TextButton.icon(
                  onPressed: () => setState(() {
                    _search.clear();
                    _searchQuery = '';
                    _statusFilter = null;
                    _typeFilter = null;
                  }),
                  icon: const Icon(Icons.clear, size: 15),
                  label: const Text('Clear'),
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                );

                void openFilterSheet() {
                  PaymentStatus? tempStatus = _statusFilter;
                  PaymentType? tempType = _typeFilter;

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
                                  const Text('Filter Payments',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: _navy)),
                                  const Spacer(),
                                  if (tempStatus != null ||
                                      tempType != null)
                                    TextButton(
                                      onPressed: () => setSheetState(() {
                                        tempStatus = null;
                                        tempType = null;
                                      }),
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
                                child: _FilterDrop<PaymentStatus?>(
                                  value: tempStatus,
                                  hint: 'All Statuses',
                                  items: const [
                                    null,
                                    ...PaymentStatus.values,
                                  ],
                                  labelOf: (v) =>
                                      v == null ? 'All Statuses' : v.label,
                                  onChanged: (v) =>
                                      setSheetState(() => tempStatus = v),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text('Type',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600])),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: _FilterDrop<PaymentType?>(
                                  value: tempType,
                                  hint: 'All Types',
                                  items: const [
                                    null,
                                    ...PaymentType.values,
                                  ],
                                  labelOf: (v) =>
                                      v == null ? 'All Types' : v.label,
                                  onChanged: (v) =>
                                      setSheetState(() => tempType = v),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _statusFilter = tempStatus;
                                      _typeFilter = tempType;
                                    });
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

                final activeFilterCount =
                    (_statusFilter != null ? 1 : 0) +
                    (_typeFilter != null ? 1 : 0);

                // On phones, replace the two dropdowns with a single
                // "Filter" button that opens a bottom sheet.
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
                            color: activeFilterCount > 0
                                ? _accent
                                : const Color(0xFFD0DBEE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_list,
                              size: 18,
                              color: activeFilterCount > 0
                                  ? _accent
                                  : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                              activeFilterCount > 0
                                  ? 'Filter ($activeFilterCount)'
                                  : 'Filter',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: activeFilterCount > 0
                                      ? _accent
                                      : const Color(0xFF1A2B4A))),
                        ],
                      ),
                    ),
                  ),
                );

                // A 260px search box plus two dropdowns can't share one
                // line below this width — swap in the single Filter
                // button instead.
                final narrow = constraints.maxWidth < 600;

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      activeFilterCount: activeFilterCount,
                      panelBuilder: (context, setPanelState, close) => [
                        _PopoverFilterField(
                          label: 'Status',
                          child: _FilterChipGroup<PaymentStatus?>(
                            value: _statusFilter,
                            options: [
                              const MapEntry(null, 'All Statuses'),
                              ...PaymentStatus.values.map(
                                  (s) => MapEntry(s, s.label)),
                            ],
                            onChanged: (v) {
                              setState(() => _statusFilter = v);
                              setPanelState(() {});
                            },
                          ),
                        ),
                        _PopoverFilterField(
                          label: 'Type',
                          child: _FilterChipGroup<PaymentType?>(
                            value: _typeFilter,
                            options: [
                              const MapEntry(null, 'All Types'),
                              ...PaymentType.values.map(
                                  (t) => MapEntry(t, t.label)),
                            ],
                            onChanged: (v) {
                              setState(() => _typeFilter = v);
                              setPanelState(() {});
                            },
                          ),
                        ),
                      ],
                      onReset: () => setState(() {
                        _statusFilter = null;
                        _typeFilter = null;
                      }),
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
            // Not wrapped in Expanded — the whole page scrolls together
            // now (see the SingleChildScrollView in build()), so the
            // table renders its full natural height inline instead of
            // being its own independently-scrolling viewport.
            StreamBuilder<List<PaymentModel>>(
                stream: _paymentsStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final payments = _filtered(snap.data ?? []);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Member/Type/Amount/Due/Paid/Status plus an
                      // 80px action column can't stay readable below
                      // this width — switch each row to a stacked
                      // card instead.
                      final compact = constraints.maxWidth < 700;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0E8F4)),
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
                            if (!compact) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF7F9FC),
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(12)),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(flex: 3, child: _TH('Member')),
                                    Expanded(flex: 2, child: _TH('Type')),
                                    Expanded(flex: 2, child: _TH('Amount')),
                                    Expanded(
                                        flex: 2, child: _TH('Due Date')),
                                    Expanded(
                                        flex: 2, child: _TH('Paid Date')),
                                    Expanded(flex: 2, child: _TH('Status')),
                                    SizedBox(width: 80),
                                  ],
                                ),
                              ),
                              const Divider(
                                  height: 1, color: Color(0xFFE0E8F4)),
                            ],

                            if (payments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text('No payment records found.',
                                      style: TextStyle(color: Colors.grey)),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: payments.length,
                                separatorBuilder: (_, __) => const Divider(
                                    height: 1, color: Color(0xFFEEF2F9)),
                                itemBuilder: (_, i) => _PaymentTableRow(
                                    payment: payments[i],
                                    fs: _fs,
                                    canRecord: canRecord,
                                    compact: compact,
                                    onMemberTap: (uid, name) =>
                                        _showMemberPayments(uid, name)),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _searchDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
    prefixIcon: const Icon(Icons.search, size: 18),
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
  );
}

// ── Summary card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final bool compact;

  const _SummaryCard({
    required this.label, required this.amount,
    required this.icon, required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      // Icon above label/value (instead of icon beside text) uses far
      // less horizontal space per card, so three of these still fit
      // in one row on a phone instead of needing to stack vertically.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E8F4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(height: 8),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text('₱${amount.toStringAsFixed(0)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      );
    }

    return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0E8F4)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1A4A9C).withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 3),
              Text('₱${amount.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      ],
    ),
  );
  }
}

// ── Payment table row ─────────────────────────────────────────────────────────
class _PaymentTableRow extends StatefulWidget {
  final PaymentModel payment;
  final FirestoreService fs;
  final bool canRecord;
  final bool compact;
  final void Function(String uid, String name)? onMemberTap;

  const _PaymentTableRow({
    required this.payment,
    required this.fs,
    required this.canRecord,
    this.compact = false,
    this.onMemberTap,
  });

  @override
  State<_PaymentTableRow> createState() => _PaymentTableRowState();
}

class _PaymentTableRowState extends State<_PaymentTableRow> {
  final _notif = NotificationService();
  bool _marking = false;

  Color _fg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return const Color(0xFF1A7A4A);
      case PaymentStatus.unpaid:  return const Color(0xFF7A6A1A);
      case PaymentStatus.overdue: return const Color(0xFFCC2200);
      case PaymentStatus.waived:  return const Color(0xFF5A7099);
    }
  }

  Color _bg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return const Color(0xFFEAF7F0);
      case PaymentStatus.unpaid:  return const Color(0xFFFFF8E0);
      case PaymentStatus.overdue: return const Color(0xFFFFF0EE);
      case PaymentStatus.waived:  return const Color(0xFFF4F7FB);
    }
  }

  String _fmt(DateTime? d) => d == null ? '—'
      : '${d.day.toString().padLeft(2,'0')}/'
        '${d.month.toString().padLeft(2,'0')}/${d.year}';

  Future<void> _markPaid() async {
    setState(() => _marking = true);
    final payment = widget.payment;

    try {
      await widget.fs.markPaymentPaid(payment.id);

      // Notify the member their payment was confirmed. Fire this after
      // the Firestore update succeeds, so a failed/slow push never
      // blocks or misrepresents the actual payment record.
      final result = await _notif.sendToMember(
        uid: payment.uid,
        title: 'Payment Confirmed',
        body: 'Hi ${payment.memberName}, your ₱${payment.amount.toStringAsFixed(2)} '
            '${payment.type.label}'
            '${payment.lotLabel.isEmpty ? '' : ' (${payment.lotLabel})'} '
            'payment has been received and confirmed.',
        type: 'payment',
        extraData: {'paymentId': payment.id},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success
                ? 'Payment marked paid. Member notified.'
                : 'Payment marked paid, but notification failed: ${result.message}'),
            backgroundColor: result.success
                ? const Color(0xFF1A7A4A)
                : const Color(0xFF7A6A1A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking payment paid: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Widget _statusPill(PaymentModel payment) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _bg(payment.displayStatus),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(payment.displayStatus.label,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _fg(payment.displayStatus))),
  );

  bool get _canMarkPaid =>
      widget.canRecord &&
      (widget.payment.status == PaymentStatus.unpaid ||
       widget.payment.status == PaymentStatus.overdue);

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;

    if (widget.compact) {
      // Stacked card — Member/Type/Amount/Due/Paid/Status plus an
      // action column don't have room to stay readable at phone widths.
      return Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
                color: _fg(payment.displayStatus), width: 3),
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onMemberTap == null
                        ? null
                        : () => widget.onMemberTap!(
                            payment.uid, payment.memberName),
                    child: Text(payment.memberName,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: widget.onMemberTap == null
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF2563EB),
                            decoration: widget.onMemberTap == null
                                ? TextDecoration.none
                                : TextDecoration.underline,
                            decorationColor:
                                const Color(0xFF2563EB).withOpacity(0.35)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                _statusPill(payment),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(
                      payment.lotLabel.isEmpty
                          ? payment.type.label
                          : '${payment.type.label} · ${payment.lotLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ),
                const SizedBox(width: 8),
                Text('₱${payment.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2B4A))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Due ${_fmt(payment.dueDate)}'
              '${payment.paidDate != null ? '  ·  Paid ${_fmt(payment.paidDate)}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            if (_canMarkPaid) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _marking ? null : _markPaid,
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1A7A4A),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: _marking
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Mark Paid', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: _fg(payment.displayStatus), width: 3),
        ),
      ),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: InkWell(
            onTap: widget.onMemberTap == null
                ? null
                : () => widget.onMemberTap!(payment.uid, payment.memberName),
            child: Text(payment.memberName,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w500,
                    color: widget.onMemberTap == null
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF2563EB),
                    decoration: widget.onMemberTap == null
                        ? TextDecoration.none
                        : TextDecoration.underline,
                    decorationColor:
                        const Color(0xFF2563EB).withOpacity(0.35)),
                overflow: TextOverflow.ellipsis),
          )),
          Expanded(flex: 2, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(payment.type.label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              if (payment.lotLabel.isNotEmpty)
                Text(payment.lotLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
            ],
          )),
          Expanded(flex: 2, child: Text(
              '₱${payment.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2B4A)))),
          Expanded(flex: 2, child: Text(_fmt(payment.dueDate),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(flex: 2, child: Text(_fmt(payment.paidDate),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(
            flex: 2,
            child: _statusPill(payment),
          ),
          SizedBox(
            width: 80,
            child: _canMarkPaid
                ? TextButton(
                    onPressed: _marking ? null : _markPaid,
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1A7A4A),
                        padding: EdgeInsets.zero),
                    child: _marking
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mark Paid',
                            style: TextStyle(fontSize: 12)))
                : null,
          ),
        ],
      ),
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: Color(0xFF5A7099), letterSpacing: 0.4));
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

class _FilterDrop<T> extends StatelessWidget {
  final T value;
  final String hint;
  final List<T> items;
  final String Function(T) labelOf;
  final void Function(T) onChanged;

  const _FilterDrop({
    required this.value, required this.hint,
    required this.items, required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFD0DBEE)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        style: const TextStyle(
            fontSize: 13, color: Color(0xFF1A2B4A)),
        icon: const Icon(Icons.expand_more, size: 18),
        items: items.map((i) => DropdownMenuItem<T>(
            value: i, child: Text(labelOf(i)))).toList(),
        onChanged: (v) => onChanged(v as T),
      ),
    ),
  );
}


// ── Member payments dialog ──────────────────────────────────────────────────
// Opened by tapping a member's name in the payments table. Filters the same
// broadcast stream the table already uses — no extra Firestore listener.
class _MemberPaymentsDialog extends StatelessWidget {
  final String uid;
  final String memberName;
  final Stream<List<PaymentModel>> paymentsStream;
  final List<PaymentModel>? initialPayments;
  final FirestoreService fs;
  final bool canRecord;

  const _MemberPaymentsDialog({
    required this.uid,
    required this.memberName,
    required this.paymentsStream,
    this.initialPayments,
    required this.fs,
    required this.canRecord,
  });

  static const Color _navy = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final width = size.width > 560 ? 560.0 : size.width * 0.94;

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: width, maxHeight: size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(memberName,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _navy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Text('Payment records',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey)),
              const SizedBox(height: 14),
              Flexible(
                child: StreamBuilder<List<PaymentModel>>(
                  stream: paymentsStream,
                  initialData: initialPayments,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('Could not load payments: ${snap.error}',
                            style:
                                const TextStyle(color: Color(0xFFCC2200))),
                      );
                    }
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final records = snap.data!
                        .where((p) => p.uid == uid)
                        .toList()
                      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

                    if (records.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No payment records found.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      );
                    }

                    final totalPaid = records
                        .where((p) => p.status == PaymentStatus.paid)
                        .fold<double>(0, (sum, p) => sum + p.amount);
                    final totalDue = records
                        .where((p) =>
                            p.status != PaymentStatus.paid &&
                            p.status != PaymentStatus.waived)
                        .fold<double>(0, (sum, p) => sum + p.amount);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                  label: 'Paid',
                                  amount: totalPaid,
                                  color: const Color(0xFF1A7A4A)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniStat(
                                  label: 'Outstanding',
                                  amount: totalDue,
                                  color: const Color(0xFFCC2200)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: records.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: Color(0xFFEEF2F9)),
                            itemBuilder: (_, i) => _PaymentTableRow(
                              payment: records[i],
                              fs: fs,
                              canRecord: canRecord,
                              compact: true, // dialog is narrow regardless
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _MiniStat(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text('₱${amount.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
}