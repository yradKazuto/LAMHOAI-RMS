import 'package:flutter/material.dart';
import '../../../core/models/lot_model.dart';
import '../../../core/services/lot_service.dart';

const _navy = Color(0xFF0D2A52);
const _blue = Color(0xFF1565C0);
const _green = Color(0xFF2E7D32);
const _grey = Color(0xFF9E9E9E);

class OccupiedLotDialog extends StatelessWidget {
  final LotModel lot;
  final bool canEdit;
  final VoidCallback onUnassign;

  const OccupiedLotDialog({
    super.key,
    required this.lot,
    required this.canEdit,
    required this.onUnassign,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          const Icon(Icons.home, color: _blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(lot.displayLabel,
                style: const TextStyle(
                    color: _navy, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Owner', lot.ownerName ?? '—'),
          if (lot.areaSqm != null) _row('Area', '${lot.areaSqm} sqm'),
          if (lot.notes != null && lot.notes!.isNotEmpty)
            _row('Notes', lot.notes!),
        ],
      ),
      actions: [
        if (canEdit)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onUnassign();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unassign Owner'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        // NOTE: "View Full Profile" link removed for now — the members
        // route doesn't yet support a /members/:uid detail path. Re-add
        // once that route/screen exists.
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}

class VacantLotDialog extends StatefulWidget {
  final LotModel lot;
  final bool canEdit;
  final String currentUserId;
  final Future<List<MapEntry<String, String>>> Function() loadAssignableMembers;

  const VacantLotDialog({
    super.key,
    required this.lot,
    required this.canEdit,
    required this.currentUserId,
    required this.loadAssignableMembers,
  });

  @override
  State<VacantLotDialog> createState() => _VacantLotDialogState();
}

class _VacantLotDialogState extends State<VacantLotDialog> {
  final _service = LotService();
  final _priceCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl.text = widget.lot.price?.toStringAsFixed(0) ?? '';
    _contactCtrl.text = widget.lot.contactNumber ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isForSale = widget.lot.status == LotStatus.forSale;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(Icons.sell_outlined, color: isForSale ? _green : _grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.lot.displayLabel,
                style: const TextStyle(
                    color: _navy, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isForSale ? 'Currently listed for sale' : 'Currently vacant',
              style: TextStyle(
                  color: isForSale ? _green : _grey,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (widget.canEdit) ...[
              TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (₱)',
                  prefixText: '₱ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contactCtrl,
                decoration: const InputDecoration(
                  labelText: 'Inquiry Contact Number',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              if (isForSale) ...[
                _row('Price',
                    '₱${widget.lot.price?.toStringAsFixed(0) ?? '—'}'),
                _row('Contact', widget.lot.contactNumber ?? '—'),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (widget.canEdit) ...[
          if (isForSale)
            TextButton(
              onPressed: _saving ? null : _delist,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delist'),
            ),
          OutlinedButton(
            onPressed: _saving ? null : _openAssignOwner,
            child: const Text('Assign Existing Member'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: _saving ? null : _markForSale,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Mark For Sale'),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: value),
            ],
          ),
        ),
      );

  Future<void> _markForSale() async {
    // Price is now optional — if left blank or not a valid number, we just
    // default to 0 so this never blocks marking a lot as for sale. You can
    // always edit the price again later once you have the real figure.
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    setState(() => _saving = true);
    await _service.markForSale(
      lotId: widget.lot.id,
      price: price,
      contactNumber: _contactCtrl.text.trim(),
      updatedBy: widget.currentUserId,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delist() async {
    setState(() => _saving = true);
    await _service.delist(lotId: widget.lot.id, updatedBy: widget.currentUserId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openAssignOwner() async {
    final members = await widget.loadAssignableMembers();
    if (!mounted) return;
    final selected = await showDialog<MapEntry<String, String>>(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(builder: (ctx, setSt) {
          final filtered = members
              .where((m) =>
                  m.value.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return AlertDialog(
            title: const Text('Assign Member to Lot'),
            content: SizedBox(
              width: 320,
              height: 360,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search member name…',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setSt(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No members found'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => ListTile(
                              title: Text(filtered[i].value),
                              onTap: () => Navigator.pop(ctx, filtered[i]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
            ],
          );
        });
      },
    );

    if (selected == null) return;
    setState(() => _saving = true);
    await _service.assignOwner(
      lotId: widget.lot.id,
      uid: selected.key,
      ownerName: selected.value,
      updatedBy: widget.currentUserId,
    );
    if (mounted) Navigator.pop(context);
  }
}