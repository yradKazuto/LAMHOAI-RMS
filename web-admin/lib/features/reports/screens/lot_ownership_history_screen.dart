import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/lot_service.dart';
import '../../../core/models/lot_ownership_model.dart';

class LotOwnershipHistoryScreen extends StatelessWidget {
  final String lotId;
  const LotOwnershipHistoryScreen({super.key, required this.lotId});

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  String _acquiredLabel(String v) {
    switch (v) {
      case 'sale':
        return 'Sale';
      case 'transfer':
        return 'Transfer';
      case 'assignment':
        return 'Assignment';
      default:
        return v.isEmpty ? 'Unknown' : v;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lot Ownership History')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Single equality filter -> no composite index. Sorted client-side.
        stream: FirebaseFirestore.instance
            .collection(LotService.ownershipCollection)
            .where('lotId', isEqualTo: lotId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  'Failed to load history:\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = (snap.data?.docs ?? [])
              .map((d) => LotOwnershipRecord.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt)); // newest first

          if (records.isEmpty) {
            return const Center(child: Text('No history found.'));
          }

          // Only the newest open record counts as the current owner.
          final currentId = records
              .where((r) => r.isCurrent)
              .map((r) => r.id)
              .firstWhere((_) => true, orElse: () => '');

          return ListView.separated(
            itemCount: records.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = records[i];
              final isCurrent = r.id == currentId;
              final unclosed = r.isCurrent && !isCurrent;
              final scheme = Theme.of(context).colorScheme;

              return ListTile(
                isThreeLine: true,
                leading: Icon(
                  isCurrent ? Icons.person : Icons.person_outline,
                  color: isCurrent ? scheme.primary : null,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        r.ownerName.isEmpty ? 'Unknown' : r.ownerName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text('Current'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: scheme.primaryContainer,
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${_acquiredLabel(r.acquiredBy)}\n'
                  '${_fmt(r.startedAt)}  →  '
                  '${isCurrent ? 'Present' : unclosed ? 'Ended (no end date)' : _fmt(r.endedAt)}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}