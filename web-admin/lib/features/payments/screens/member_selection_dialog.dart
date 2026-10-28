import 'package:flutter/material.dart';
import '../../../core/models/member_model.dart';
import '../../../core/theme/design_tokens.dart';

class MemberSelectionDialog extends StatefulWidget {
  final List<MemberModel> allMembers;
  const MemberSelectionDialog({super.key, required this.allMembers});

  @override
  State<MemberSelectionDialog> createState() => _MemberSelectionDialogState();
}

class _MemberSelectionDialogState extends State<MemberSelectionDialog> {
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedUids = {};
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MemberModel> get _filtered => widget.allMembers
      .where((m) =>
          m.name.toLowerCase().contains(_query.toLowerCase()) ||
          m.email.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final allSelected = filtered.isNotEmpty && filtered.every((m) => _selectedUids.contains(m.uid));

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Select Members to Generate Dues'),
      content: SizedBox(
        width: 450,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search member name or email...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            CheckboxListTile(
              title: const Text('Select All Filtered', style: TextStyle(fontWeight: FontWeight.w600)),
              value: allSelected,
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selectedUids.addAll(filtered.map((m) => m.uid));
                } else {
                  _selectedUids.removeAll(filtered.map((m) => m.uid));
                }
              }),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final m = filtered[i];
                  return CheckboxListTile(
                    title: Text(m.name),
                    subtitle: Text(m.email),
                    value: _selectedUids.contains(m.uid),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selectedUids.add(m.uid);
                      } else {
                        _selectedUids.remove(m.uid);
                      }
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _selectedUids.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  widget.allMembers
                      .where((m) => _selectedUids.contains(m.uid))
                      .toList()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.textInverted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
