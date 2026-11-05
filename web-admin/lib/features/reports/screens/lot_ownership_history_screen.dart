import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/lot_service.dart';
import '../../../core/models/lot_model.dart';
import '../../../core/theme/design_tokens.dart';

class LotOwnershipHistoryScreen extends StatelessWidget {
  final String lotId;
  const LotOwnershipHistoryScreen({super.key, required this.lotId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lot Ownership History')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lot_ownership_history')
            .where('lotId', isEqualTo: lotId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No history found.'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['type'] ?? 'Unknown'),
                subtitle: Text('From: ${data['previousOwnerName'] ?? 'None'} To: ${data['currentOwnerName'] ?? 'None'}'),
                trailing: Text((data['createdAt'] as Timestamp).toDate().toString().substring(0, 16)),
              );
            },
          );
        },
      ),
    );
  }
}
