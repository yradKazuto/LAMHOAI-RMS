// features/audit/screens/audit_screen.dart

import 'package:flutter/material.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/services/settings_service.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final _svc        = SettingsService();
  final _searchCtrl = TextEditingController();
  String?      _actionFilter;
  String?      _collectionFilter;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AuditLogModel> _filtered(List<AuditLogModel> all) {
    final q = _searchCtrl.text.toLowerCase();
    return all.where((log) {
      final matchSearch = q.isEmpty ||
          log.performedByName.toLowerCase().contains(q) ||
          log.description.toLowerCase().contains(q) ||
          log.targetCollection.toLowerCase().contains(q);
      final matchAction = _actionFilter == null ||
          log.action.name == _actionFilter;
      final matchColl = _collectionFilter == null ||
          log.targetCollection == _collectionFilter;
      return matchSearch && matchAction && matchColl;
    }).toList();
  }

  Color _actionColor(AuditAction a) {
    switch (a) {
      case AuditAction.created:       return const Color(0xFF1A7A4A);
      case AuditAction.updated:       return const Color(0xFF1A4A9C);
      case AuditAction.deleted:       return const Color(0xFFCC2200);
      case AuditAction.statusChanged: return const Color(0xFF7A6A1A);
      case AuditAction.roleChanged:   return const Color(0xFF5A1A7A);
      case AuditAction.login:         return const Color(0xFF5A7099);
    }
  }

  Color _actionBg(AuditAction a) {
    switch (a) {
      case AuditAction.created:       return const Color(0xFFEAF7F0);
      case AuditAction.updated:       return const Color(0xFFEEF4FF);
      case AuditAction.deleted:       return const Color(0xFFFFF0EE);
      case AuditAction.statusChanged: return const Color(0xFFFFF8E0);
      case AuditAction.roleChanged:   return const Color(0xFFF5EEFF);
      case AuditAction.login:         return const Color(0xFFF0F4FB);
    }
  }

  IconData _actionIcon(AuditAction a) {
    switch (a) {
      case AuditAction.created:       return Icons.add_circle_outline;
      case AuditAction.updated:       return Icons.edit_outlined;
      case AuditAction.deleted:       return Icons.delete_outline;
      case AuditAction.statusChanged: return Icons.swap_horiz_outlined;
      case AuditAction.roleChanged:   return Icons.manage_accounts_outlined;
      case AuditAction.login:         return Icons.login_outlined;
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            const Text('Audit Log',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _navy)),
            const SizedBox(height: 2),
            Text('Track all admin actions and changes',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600])),
            const SizedBox(height: 24),

            // ── Filters ────────────────────────────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by staff or action...',
                      hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400]),
                      prefixIcon: const Icon(
                          Icons.search, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12),
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
                              color: _accent,
                              width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Action filter
                _FilterDrop(
                  value: _actionFilter,
                  hint:  'All Actions',
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('All Actions')),
                    ...AuditAction.values.map((a) =>
                        DropdownMenuItem(
                            value: a.name,
                            child: Text(a.label))),
                  ],
                  onChanged: (v) =>
                      setState(() => _actionFilter = v),
                ),
                const SizedBox(width: 12),
                // Collection filter
                _FilterDrop(
                  value: _collectionFilter,
                  hint:  'All Collections',
                  items: const [
                    DropdownMenuItem(
                        value: null,
                        child: Text('All Collections')),
                    DropdownMenuItem(
                        value: 'users',
                        child: Text('Users')),
                    DropdownMenuItem(
                        value: 'payments',
                        child: Text('Payments')),
                    DropdownMenuItem(
                        value: 'documents',
                        child: Text('Documents')),
                    DropdownMenuItem(
                        value: 'announcements',
                        child: Text('Announcements')),
                    DropdownMenuItem(
                        value: 'complaints',
                        child: Text('Complaints')),
                    DropdownMenuItem(
                        value: 'settings',
                        child: Text('Settings')),
                  ],
                  onChanged: (v) => setState(
                      () => _collectionFilter = v),
                ),
                if (_searchCtrl.text.isNotEmpty ||
                    _actionFilter != null ||
                    _collectionFilter != null) ...[
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _searchCtrl.clear();
                      _actionFilter     = null;
                      _collectionFilter = null;
                    }),
                    icon: const Icon(Icons.clear,
                        size: 15),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                        foregroundColor:
                            Colors.grey[600]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Log list ───────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<AuditLogModel>>(
                stream: _svc.streamAuditLogs(limit: 100),
                builder: (context, snap) {
                  if (snap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child:
                            CircularProgressIndicator());
                  }

                  final logs =
                      _filtered(snap.data ?? []);

                  if (logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              Icons
                                  .history_toggle_off_outlined,
                              size: 52,
                              color: Colors.grey[300]),
                          const SizedBox(height: 14),
                          Text('No audit logs found.',
                              style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      Colors.grey[500])),
                          const SizedBox(height: 6),
                          Text(
                            'Actions performed by staff will appear here.',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    Colors.grey[400]),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFFE0E8F4)),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14),
                          decoration:
                              const BoxDecoration(
                            color: Color(0xFFF7F9FC),
                            borderRadius:
                                BorderRadius.vertical(
                                    top: Radius.circular(
                                        12)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${logs.length} records',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w600,
                                    color: _navy),
                              ),
                              const Spacer(),
                              Text(
                                'Showing last 100 actions',
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        const Divider(
                            height: 1,
                            color: Color(0xFFE0E8F4)),

                        Expanded(
                          child: ListView.separated(
                            itemCount: logs.length,
                            separatorBuilder: (_, __) =>
                                const Divider(
                                    height: 1,
                                    color: Color(
                                        0xFFEEF2F9)),
                            itemBuilder: (_, i) {
                              final log = logs[i];
                              return Padding(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                        horizontal: 20,
                                        vertical: 14),
                                child: Row(
                                  children: [
                                    // Action icon
                                    Container(
                                      padding:
                                          const EdgeInsets
                                              .all(8),
                                      decoration:
                                          BoxDecoration(
                                        color: _actionBg(
                                            log.action),
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    8),
                                      ),
                                      child: Icon(
                                        _actionIcon(
                                            log.action),
                                        size: 16,
                                        color:
                                            _actionColor(
                                                log.action),
                                      ),
                                    ),
                                    const SizedBox(
                                        width: 14),

                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            log.description,
                                            style: const TextStyle(
                                                fontSize:
                                                    13.5,
                                                fontWeight:
                                                    FontWeight
                                                        .w500,
                                                color: Color(
                                                    0xFF0D2A5C)),
                                          ),
                                          const SizedBox(
                                              height: 3),
                                          Row(
                                            children: [
                                              Icon(
                                                  Icons
                                                      .person_outline,
                                                  size:
                                                      12,
                                                  color: Colors
                                                      .grey[400]),
                                              const SizedBox(
                                                  width:
                                                      4),
                                              Text(
                                                log.performedByName,
                                                style: TextStyle(
                                                    fontSize:
                                                        12,
                                                    color: Colors
                                                        .grey[500]),
                                              ),
                                              const SizedBox(
                                                  width:
                                                      12),
                                              Icon(
                                                  Icons
                                                      .folder_outlined,
                                                  size:
                                                      12,
                                                  color: Colors
                                                      .grey[400]),
                                              const SizedBox(
                                                  width:
                                                      4),
                                              Text(
                                                log.targetCollection,
                                                style: TextStyle(
                                                    fontSize:
                                                        12,
                                                    color: Colors
                                                        .grey[500]),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Action badge + time
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .end,
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                  horizontal:
                                                      10,
                                                  vertical:
                                                      4),
                                          decoration:
                                              BoxDecoration(
                                            color: _actionBg(
                                                log.action),
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                                        20),
                                          ),
                                          child: Text(
                                            log.action
                                                .label,
                                            style:
                                                TextStyle(
                                              fontSize:
                                                  11.5,
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                              color:
                                                  _actionColor(
                                                      log.action),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                            height: 4),
                                        Text(
                                          _fmt(log
                                              .createdAt),
                                          style:
                                              TextStyle(
                                            fontSize: 11,
                                            color: Colors
                                                .grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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

class _FilterDrop extends StatelessWidget {
  final String?                            value;
  final String                             hint;
  final List<DropdownMenuItem<String?>>    items;
  final void Function(String?)             onChanged;

  const _FilterDrop({
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