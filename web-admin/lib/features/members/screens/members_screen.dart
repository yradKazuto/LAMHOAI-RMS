// features/members/screens/members_screen.dart
// UPDATED — Lot No. / Block now pulled live from the `lots` collection
// (matched by uid) instead of the member's own manually-typed fields.
// UPDATED — Add Member dialog now creates Firebase Auth account + Firestore doc

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/lot_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/lot_service.dart';
import 'member_detail_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _search      = TextEditingController();
  final _fs          = FirestoreService();
  final _lotService  = LotService();

  String  _searchQuery  = '';
  String? _statusFilter;
  String? _blockFilter;

  static const Color _navy   = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _bg     = Color(0xFFF4F7FB);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Filters members using the REAL lot data (matched by uid), not the
  /// member's own manually-typed lotNumber/phase fields.
  List<MemberModel> _filtered(
    List<MemberModel> all,
    Map<String, List<LotModel>> lotsByUid,
  ) {
    return all.where((m) {
      final lots         = lotsByUid[m.uid] ?? const <LotModel>[];
      final q            = _searchQuery.toLowerCase();
      final matchSearch  = q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          m.email.toLowerCase().contains(q) ||
          lots.any((l) => l.lotNumber.toLowerCase().contains(q));
      final matchStatus  = _statusFilter == null ||
          m.status.name == _statusFilter;
      final matchBlock   = _blockFilter == null ||
          lots.any((l) => l.block == _blockFilter);
      return matchSearch && matchStatus && matchBlock;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final canEdit = auth.isAdmin || auth.isOfficer;

    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final titleBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Homeowner Records',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 2),
                    Text('Manage and view all registered homeowners',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600])),
                  ],
                );

                final addButton = canEdit
                    ? ElevatedButton.icon(
                        onPressed: () =>
                            _showAddMemberDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Member'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                        ),
                      )
                    : null;

                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      if (addButton != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: addButton),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleBlock),
                    if (addButton != null) addButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Filters ───────────────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final searchField = TextField(
                  controller: _search,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search name, email, lot...',
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
                    _searchQuery.isNotEmpty ||
                    _statusFilter != null ||
                    _blockFilter != null;

                final clearButton = TextButton.icon(
                  onPressed: () => setState(() {
                    _search.clear();
                    _searchQuery  = '';
                    _statusFilter = null;
                    _blockFilter  = null;
                  }),
                  icon: const Icon(Icons.clear, size: 15),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600]),
                );

                void openFilterSheet() {
                  String? tempStatus = _statusFilter;
                  String? tempBlock = _blockFilter;

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
                                  const Text('Filter Homeowners',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: _navy)),
                                  const Spacer(),
                                  if (tempStatus != null ||
                                      tempBlock != null)
                                    TextButton(
                                      onPressed: () => setSheetState(() {
                                        tempStatus = null;
                                        tempBlock = null;
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
                                child: _DropdownFilter(
                                  value: tempStatus,
                                  hint: 'All Statuses',
                                  items: const [
                                    DropdownMenuItem(
                                        value: null,
                                        child: Text('All Statuses')),
                                    DropdownMenuItem(
                                        value: 'active',
                                        child: Text('Active')),
                                    DropdownMenuItem(
                                        value: 'inactive',
                                        child: Text('Inactive')),
                                    DropdownMenuItem(
                                        value: 'delinquent',
                                        child: Text('Delinquent')),
                                  ],
                                  onChanged: (v) =>
                                      setSheetState(() => tempStatus = v),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text('Block',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600])),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: _DropdownFilter(
                                  value: tempBlock,
                                  hint: 'All Blocks',
                                  items: const [
                                    DropdownMenuItem(
                                        value: null,
                                        child: Text('All Blocks')),
                                    DropdownMenuItem(
                                        value: 'Block 1',
                                        child: Text('Block 1')),
                                    DropdownMenuItem(
                                        value: 'Block 2',
                                        child: Text('Block 2')),
                                    DropdownMenuItem(
                                        value: 'Block 3',
                                        child: Text('Block 3')),
                                    DropdownMenuItem(
                                        value: 'Block 4',
                                        child: Text('Block 4')),
                                    DropdownMenuItem(
                                        value: 'Block 5',
                                        child: Text('Block 5')),
                                    DropdownMenuItem(
                                        value: 'Block 6',
                                        child: Text('Block 6')),
                                    DropdownMenuItem(
                                        value: 'Block 7',
                                        child: Text('Block 7')),
                                    DropdownMenuItem(
                                        value: 'Block 8',
                                        child: Text('Block 8')),
                                    DropdownMenuItem(
                                        value: 'Block 9',
                                        child: Text('Block 9')),
                                  ],
                                  onChanged: (v) =>
                                      setSheetState(() => tempBlock = v),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _statusFilter = tempStatus;
                                      _blockFilter = tempBlock;
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
                    (_blockFilter != null ? 1 : 0);

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

                // A 280px search box plus two dropdowns can't share
                // one line below this width — swap in the single
                // Filter button beside the search field instead.
                final narrow = constraints.maxWidth < 620;

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
                    SizedBox(width: 280, child: searchField),
                    const SizedBox(width: 12),
                    _FilterPopoverButton(
                      activeFilterCount: activeFilterCount,
                      panelBuilder: (context, setPanelState, close) => [
                        _PopoverFilterField(
                          label: 'Status',
                          child: _FilterChipGroup<String?>(
                            value: _statusFilter,
                            options: const [
                              MapEntry(null, 'All Statuses'),
                              MapEntry('active', 'Active'),
                              MapEntry('inactive', 'Inactive'),
                              MapEntry('delinquent', 'Delinquent'),
                            ],
                            onChanged: (v) {
                              setState(() => _statusFilter = v);
                              setPanelState(() {});
                            },
                          ),
                        ),
                        _PopoverFilterField(
                          label: 'Block',
                          child: _FilterChipGroup<String?>(
                            value: _blockFilter,
                            options: const [
                              MapEntry(null, 'All Blocks'),
                              MapEntry('Block 1', 'Block 1'),
                              MapEntry('Block 2', 'Block 2'),
                              MapEntry('Block 3', 'Block 3'),
                              MapEntry('Block 4', 'Block 4'),
                              MapEntry('Block 5', 'Block 5'),
                              MapEntry('Block 6', 'Block 6'),
                              MapEntry('Block 7', 'Block 7'),
                              MapEntry('Block 8', 'Block 8'),
                              MapEntry('Block 9', 'Block 9'),
                            ],
                            onChanged: (v) {
                              setState(() => _blockFilter = v);
                              setPanelState(() {});
                            },
                          ),
                        ),
                      ],
                      onReset: () => setState(() {
                        _statusFilter = null;
                        _blockFilter = null;
                      }),
                    ),
                    if (hasActiveFilter) ...[
                      const SizedBox(width: 12),
                      clearButton,
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Table ─────────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<LotModel>>(
                stream: _lotService.streamLots(),
                builder: (context, lotSnap) {
                  // Build a uid -> lot lookup from the real lots collection.
                  // This is the single source of truth for Lot No. / Block.
                  // A member can own several lots, so keep them all.
                  final lotsByUid = <String, List<LotModel>>{};
                  for (final lot in lotSnap.data ?? <LotModel>[]) {
                    final uid = lot.uid;
                    if (uid != null && uid.isNotEmpty) {
                      lotsByUid.putIfAbsent(uid, () => []).add(lot);
                    }
                  }

                  return StreamBuilder<List<MemberModel>>(
                    stream: _fs.streamMembers(),
                    builder: (context, snap) {
                      if (snap.connectionState ==
                              ConnectionState.waiting ||
                          lotSnap.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(
                            child:
                                CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(
                            child: Text(
                                'Error: ${snap.error}',
                                style: const TextStyle(
                                    color: Colors.red)));
                      }

                      final members = _filtered(
                        snap.data ?? [],
                        lotsByUid,
                      );

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          // Name/Email/Lot/Block/Status plus a chevron
                          // can't stay readable below this width —
                          // switch each row to a stacked card instead.
                          final compact =
                              constraints.maxWidth < 700;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      const Color(0xFFE0E8F4)),
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
                                  _TableHeader(),
                                  const Divider(
                                      height: 1,
                                      color: Color(0xFFE0E8F4)),
                                ],
                                if (members.isEmpty)
                                  const Expanded(
                                    child: Center(
                                      child: Text(
                                          'No members found.',
                                          style: TextStyle(
                                              color:
                                                  Colors.grey)),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: members.length,
                                      separatorBuilder:
                                          (_, __) =>
                                              const Divider(
                                                  height: 1,
                                                  color: Color(
                                                      0xFFEEF2F9)),
                                      itemBuilder:
                                          (context, i) {
                                        final member =
                                            members[i];
                                        final lots = [
                                          ...(lotsByUid[member.uid] ??
                                              const <LotModel>[])
                                        ]..sort(compareLotsForBilling);

                                        return _MemberRow(
                                          member:  member,
                                          lots:    lots,
                                          canEdit: canEdit,
                                          compact: compact,
                                          onTap: () =>
                                              Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  MemberDetailScreen(
                                                      member:
                                                          member),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
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

  void _showAddMemberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) =>
          _AddMemberDialog(fsService: _fs),
    );
  }
}

// ── Dropdown filter ───────────────────────────────────────────────────────────
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

class _DropdownFilter extends StatelessWidget {
  final String?                            value;
  final String                             hint;
  final List<DropdownMenuItem<String?>>    items;
  final void Function(String?)             onChanged;

  const _DropdownFilter({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding:
        const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
          color: const Color(0xFFD0DBEE)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: value,
        hint: Text(hint,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500])),
        style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF1A2B4A)),
        icon: const Icon(Icons.expand_more,
            size: 18),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
}

// ── Table header ──────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 20, vertical: 14),
    decoration: const BoxDecoration(
      color: Color(0xFFF7F9FC),
      borderRadius: BorderRadius.vertical(
          top: Radius.circular(12)),
    ),
    child: const Row(
      children: [
        Expanded(flex: 3, child: _TH('Name')),
        Expanded(flex: 3, child: _TH('Email')),
        Expanded(flex: 2, child: _TH('Lot No.')),
        Expanded(flex: 2, child: _TH('Block')),
        Expanded(flex: 2, child: _TH('Status')),
        SizedBox(width: 48),
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

// ── Member row ────────────────────────────────────────────────────────────────
class _MemberRow extends StatelessWidget {
  final MemberModel  member;
  final List<LotModel> lots;
  final bool         canEdit;
  final bool         compact;
  final VoidCallback onTap;

  const _MemberRow({
    required this.member,
    required this.lots,
    required this.canEdit,
    required this.onTap,
    this.compact = false,
  });

  Color _fg(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:
        return const Color(0xFF1A7A4A);
      case MemberStatus.inactive:
        return const Color(0xFF7A6A1A);
      case MemberStatus.delinquent:
        return const Color(0xFFCC2200);
    }
  }

  Color _bg(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:
        return const Color(0xFFEAF7F0);
      case MemberStatus.inactive:
        return const Color(0xFFFFF8E0);
      case MemberStatus.delinquent:
        return const Color(0xFFFFF0EE);
    }
  }

  // Several lots → "Lots 12, 15"; blocks are de-duplicated ("3, 4").
  String get _lotText {
    final nums = lots
        .map((l) => l.lotNumber)
        .where((n) => n.isNotEmpty)
        .toList();
    if (nums.isEmpty) return '—';
    return nums.length == 1
        ? 'Lot ${nums.first}'
        : 'Lots ${nums.join(', ')}';
  }

  String get _blockText {
    final blocks = lots
        .map((l) => l.block)
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList();
    return blocks.isEmpty ? '—' : blocks.join(', ');
  }

  Widget _avatarAndName() => Row(
    children: [
      CircleAvatar(
        radius: 16,
        backgroundColor:
            const Color(0xFF2563EB).withOpacity(0.12),
        child: Text(
          member.name.isNotEmpty
              ? member.name[0].toUpperCase()
              : '?',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB)),
        ),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(member.name,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B)),
            overflow: TextOverflow.ellipsis),
      ),
    ],
  );

  Widget _statusPill() => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _bg(member.status),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      member.status.label,
      style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: _fg(member.status)),
      textAlign: TextAlign.center,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (compact) {
      // Stacked card — Name/Email/Lot/Block/Status plus a chevron
      // don't have room to stay readable at phone widths.
      return Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: _fg(member.status), width: 3),
          ),
        ),
        child: InkWell(
        onTap: onTap,
        hoverColor: const Color(0xFFF4F7FB),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _avatarAndName()),
                  const SizedBox(width: 8),
                  _statusPill(),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 18, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Text(member.email,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Text('$_lotText  ·  $_blockText',
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF1A2B4A))),
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
          left: BorderSide(color: _fg(member.status), width: 3),
        ),
      ),
      child: InkWell(
      onTap: onTap,
      hoverColor: const Color(0xFFF4F7FB),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(flex: 3, child: _avatarAndName()),
            Expanded(
              flex: 3,
              child: Text(member.email,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(_lotText,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1A2B4A))),
            ),
            Expanded(
              flex: 2,
              child: Text(_blockText,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1A2B4A))),
            ),
            Expanded(flex: 2, child: _statusPill()),
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
}

// ── Add Member dialog — creates Auth + Firestore ───────────────────────────────
class _AddMemberDialog extends StatefulWidget {
  final FirestoreService fsService;
  const _AddMemberDialog({required this.fsService});

  @override
  State<_AddMemberDialog> createState() =>
      _AddMemberDialogState();
}

class _AddMemberDialogState
    extends State<_AddMemberDialog> {
  final _formKey  = GlobalKey<FormState>();
  final _name     = TextEditingController();
  final _email    = TextEditingController();
  final _password = TextEditingController();
  final _lot      = TextEditingController();
  final _contact  = TextEditingController();
  final _address  = TextEditingController();
  String  _block   = 'Block 1';
  bool    _loading = false;
  bool    _obscure = true;
  String? _error;

  static const Color _navy   = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF2563EB);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _lot.dispose();
    _contact.dispose();
    _address.dispose();
    super.dispose();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      default:
        return 'Error: $code';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      // Use a secondary Firebase App instance so the
      // admin session is NOT affected when creating a new user
      final secondaryApp = await Firebase.initializeApp(
        name:    'secondary',
        options: Firebase.app().options,
      );

      final secondaryAuth =
          FirebaseAuth.instanceFor(app: secondaryApp);

      // 1. Create member Auth account in secondary app
      final cred = await secondaryAuth
          .createUserWithEmailAndPassword(
        email:    _email.text.trim(),
        password: _password.text,
      );
      final memberUid = cred.user!.uid;

      // 2. Send email verification to the new member
      await cred.user!.sendEmailVerification();

      // 3. Sign out from secondary app and delete it
      await secondaryAuth.signOut();
      await secondaryApp.delete();

      // 3. Save Firestore document — admin session untouched
      await widget.fsService.addMember(MemberModel(
        uid:           memberUid,
        name:          _name.text.trim(),
        email:         _email.text.trim(),
        role:          'member',
        lotNumber:     _lot.text.trim(),
        phase:         _block,
        status:        MemberStatus.active,
        contactNumber: _contact.text.trim(),
        address:       _address.text.trim(),
        createdAt:     DateTime.now(),
      ));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Member created. Verification email sent. '
                'Assign them to a lot from Location Mapping to '
                'show their Lot No. and Block in this list.'),
            backgroundColor: Color(0xFF1A7A4A),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Clean up secondary app if it exists
      try {
        await Firebase.app('secondary').delete();
      } catch (_) {}
      setState(() {
        _loading = false;
        _error   = _mapAuthError(e.code);
      });
    } catch (e) {
      try {
        await Firebase.app('secondary').delete();
      } catch (_) {}
      setState(() {
        _loading = false;
        _error   = 'An unexpected error occurred: $e';
      });
    }
  }

  InputDecoration _dec(String hint,
          {bool hasError = false}) =>
      InputDecoration(
        hintText:  hint,
        hintStyle: TextStyle(
            fontSize: 13, color: Colors.grey[400]),
        filled:    true,
        fillColor: const Color(0xFFF7F9FC),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: Color(0xFFD0DBEE))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: Color(0xFFD0DBEE))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: _accent, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: Color(0xFFCC2200))),
      );

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth =
        screenSize.width > 600 ? 540.0 : screenSize.width * 0.92;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: screenSize.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ── Title ─────────────────────────────
                const Text('Add New Member',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _navy)),
                const SizedBox(height: 4),
                Text(
                  'Creates a login account for the mobile app.',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey[500]),
                ),
                const SizedBox(height: 20),

                // ── Error banner ──────────────────────
                if (_error != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFFFF0EE),
                      borderRadius:
                          BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(
                                  0xFFCC2200)
                              .withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                            Icons.error_outline,
                            size: 15,
                            color:
                                Color(0xFFCC2200)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style:
                                  const TextStyle(
                                fontSize: 12.5,
                                color: Color(
                                    0xFFCC2200),
                              )),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Name + Email ──────────────────────
                LayoutBuilder(builder: (context, c) {
                  final nameField = _Field(
                    ctrl:  _name,
                    label: 'Full Name',
                    hint:  'Juan dela Cruz',
                    dec:   _dec,
                    validator: (v) =>
                        v!.isEmpty ? 'Required' : null,
                  );
                  final emailField = _Field(
                    ctrl:  _email,
                    label: 'Email Address',
                    hint:  'juan@email.com',
                    dec:   _dec,
                    keyboardType:
                        TextInputType.emailAddress,
                    validator: (v) {
                      if (v!.isEmpty) return 'Required';
                      if (!v.contains('@'))
                        return 'Invalid email';
                      return null;
                    },
                  );
                  if (c.maxWidth < 420) {
                    return Column(children: [
                      nameField,
                      const SizedBox(height: 14),
                      emailField,
                    ]);
                  }
                  return Row(children: [
                    Expanded(child: nameField),
                    const SizedBox(width: 14),
                    Expanded(child: emailField),
                  ]);
                }),
                const SizedBox(height: 14),

                // ── Password ──────────────────────────
                _FieldLabel('Temporary Password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller:  _password,
                  obscureText: _obscure,
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Required';
                    if (v.length < 6)
                      return 'Minimum 6 characters';
                    return null;
                  },
                  style: const TextStyle(
                      fontSize: 13),
                  decoration: _dec(
                          'Min. 6 characters')
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons
                                .visibility_outlined
                            : Icons
                                .visibility_off_outlined,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                      onPressed: () => setState(
                          () =>
                              _obscure =
                                  !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Lot + Phase ───────────────────────
                LayoutBuilder(builder: (context, c) {
                  final lotField = _Field(
                    ctrl:  _lot,
                    label: 'Lot Number',
                    hint:  'Lot 12 Blk 3',
                    dec:   _dec,
                    validator: (v) =>
                        v!.isEmpty ? 'Required' : null,
                  );
                  final blockField = Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Block'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _block,
                        items: [
                          'Block 1',
                          'Block 2',
                          'Block 3',
                          'Block 4',
                          'Block 5',
                          'Block 6',
                          'Block 7',
                          'Block 8',
                          'Block 9',
                        ]
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _block = v!),
                        decoration: _dec('Select block'),
                      ),
                    ],
                  );
                  if (c.maxWidth < 420) {
                    return Column(children: [
                      lotField,
                      const SizedBox(height: 14),
                      blockField,
                    ]);
                  }
                  return Row(children: [
                    Expanded(child: lotField),
                    const SizedBox(width: 14),
                    Expanded(child: blockField),
                  ]);
                }),
                const SizedBox(height: 14),

                // ── Contact ───────────────────────────
                _Field(
                  ctrl:  _contact,
                  label: 'Contact Number',
                  hint:  '09XX-XXX-XXXX',
                  dec:   _dec,
                ),
                const SizedBox(height: 14),

                // ── Address ───────────────────────────
                _Field(
                  ctrl:  _address,
                  label: 'Address',
                  hint:  'House number, street...',
                  dec:   _dec,
                ),
                const SizedBox(height: 20),

                // ── Info notice ───────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFE8F4FF),
                    borderRadius:
                        BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(
                                0xFF2563EB)
                            .withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 15,
                          color:
                              Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The member will use this email and password to log in on the mobile app. Lot Number and Block entered here are provisional — they will not appear in the Homeowner Records table until this member is assigned a lot from Location Mapping.',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: Color(
                                  0xFF1A4A9C)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Actions ───────────────────────────
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: Colors.grey)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed:
                          _loading ? null : _submit,
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor:
                            Colors.white,
                        shape:
                            RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                            8)),
                        padding: const EdgeInsets
                            .symmetric(
                            horizontal: 24,
                            vertical: 12),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                      color: Colors
                                          .white))
                          : const Text(
                              'Create Member'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B)));
}

class _Field extends StatelessWidget {
  final TextEditingController           ctrl;
  final String                          label, hint;
  final InputDecoration Function(String) dec;
  final String? Function(String?)?       validator;
  final TextInputType                    keyboardType;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.dec,
    this.validator,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FieldLabel(label),
      const SizedBox(height: 6),
      TextFormField(
        controller:   ctrl,
        validator:    validator,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13),
        decoration:   dec(hint),
      ),
    ],
  );
}