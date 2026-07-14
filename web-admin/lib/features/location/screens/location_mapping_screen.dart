import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/lot_model.dart';
import '../../../core/services/lot_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';
import '../widgets/lot_dialogs.dart';
import '../widgets/map_pin_view.dart';

const _navy = Color(0xFF0D2A52);
const _blue = Color(0xFF1565C0);
const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _grey = Color(0xFFBDBDBD);

class LocationMappingScreen extends StatefulWidget {
  const LocationMappingScreen({super.key});

  @override
  State<LocationMappingScreen> createState() => _LocationMappingScreenState();
}

class _LocationMappingScreenState extends State<LocationMappingScreen> {
  final _service = LotService();
  String? _selectedPhase; // null = all phases
  String _search = '';
  bool _showMapView = true; // true = image+pins, false = grid tiles

  Color _colorFor(LotStatus s) {
    switch (s) {
      case LotStatus.occupied:
        return _blue;
      case LotStatus.forSale:
        return _green;
      case LotStatus.reserved:
        return _orange;
      case LotStatus.vacant:
        return _grey;
    }
  }

  IconData _iconFor(LotStatus s) {
    switch (s) {
      case LotStatus.occupied:
        return Icons.home;
      case LotStatus.forSale:
        return Icons.sell;
      case LotStatus.reserved:
        return Icons.lock_clock;
      case LotStatus.vacant:
        return Icons.crop_square;
    }
  }

  Future<List<MapEntry<String, String>>> _loadAssignableMembers() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'member')
        .get();
    return snap.docs
        .map((d) => MapEntry(
            d.id, (d.data())['displayName'] as String? ?? 'Unnamed'))
        .toList();
  }

  void _openLotDialog(LotModel lot, bool canEdit, String currentUserId) {
    if (lot.status == LotStatus.occupied) {
      showDialog(
        context: context,
        builder: (_) => OccupiedLotDialog(
          lot: lot,
          canEdit: canEdit,
          onUnassign: () => _service.unassignOwner(
              lotId: lot.id, updatedBy: currentUserId),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => VacantLotDialog(
          lot: lot,
          canEdit: canEdit,
          currentUserId: currentUserId,
          loadAssignableMembers: _loadAssignableMembers,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.role;
    final canEdit = role == UserRole.admin || role == UserRole.officer;
    final currentUserId = auth.userModel?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location Mapping',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _navy),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Subdivision lot map — view occupancy and availability',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: true,
                        label: Text('Map View'),
                        icon: Icon(Icons.map_outlined)),
                    ButtonSegment(
                        value: false,
                        label: Text('Grid View'),
                        icon: Icon(Icons.grid_view)),
                  ],
                  selected: {_showMapView},
                  onSelectionChanged: (s) =>
                      setState(() => _showMapView = s.first),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildToolbar(),
            const SizedBox(height: 12),
            _buildLegend(),
            if (_showMapView && canEdit) ...[
              const SizedBox(height: 8),
              Text(
                'Tip: tap anywhere on the map to place a new lot pin.',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<LotModel>>(
                stream: _service.streamLots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red)));
                  }

                  var lots = snapshot.data ?? [];
                  if (_selectedPhase != null) {
                    lots =
                        lots.where((l) => l.phase == _selectedPhase).toList();
                  }
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    lots = lots
                        .where((l) =>
                            l.lotNumber.toLowerCase().contains(q) ||
                            l.block.toLowerCase().contains(q) ||
                            (l.ownerName ?? '').toLowerCase().contains(q))
                        .toList();
                  }

                  // Map View always renders — even with zero lots — so the
                  // image is visible and tappable to place the first pins.
                  // NOTE: intentionally NOT wrapped in a SingleChildScrollView
                  // here — a scrollable parent would intercept vertical drag
                  // gestures before InteractiveViewer gets them, breaking
                  // up/down panning on the map.
                  if (_showMapView) {
                    return MapPinView(
                      lots: lots,
                      canEdit: canEdit,
                      currentUserId: currentUserId,
                      loadAssignableMembers: _loadAssignableMembers,
                    );
                  }

                  // Grid View has nothing meaningful to show with zero lots.
                  if (lots.isEmpty) {
                    return const Center(
                        child: Text('No lots found for this filter'));
                  }

                  final grouped = <String, List<LotModel>>{};
                  for (final l in lots) {
                    grouped.putIfAbsent(l.phase, () => []).add(l);
                  }
                  final phaseKeys = grouped.keys.toList()..sort();

                  return ListView.builder(
                    itemCount: phaseKeys.length,
                    itemBuilder: (context, i) {
                      final phase = phaseKeys[i];
                      final phaseLots = grouped[phase]!
                        ..sort((a, b) => '${a.block}${a.lotNumber}'
                            .compareTo('${b.block}${b.lotNumber}'));
                      return _PhaseSection(
                        title: phase,
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 140,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1,
                          ),
                          itemCount: phaseLots.length,
                          itemBuilder: (context, idx) {
                            final lot = phaseLots[idx];
                            final color = _colorFor(lot.status);
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () =>
                                  _openLotDialog(lot, canEdit, currentUserId),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  border: Border.all(color: color, width: 1.4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_iconFor(lot.status),
                                        color: color, size: 22),
                                    const SizedBox(height: 6),
                                    Text(
                                      lot.lotNumber,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _navy),
                                    ),
                                    Text(
                                      lot.block,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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

  Widget _buildToolbar() {
    return Row(
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search lot, block, or owner…',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(width: 16),
        FutureBuilder<List<String>>(
          future: _service.getDistinctPhases(),
          builder: (context, snap) {
            final phases = snap.data ?? [];
            return DropdownButton<String?>(
              value: _selectedPhase,
              hint: const Text('All Phases'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All Phases')),
                ...phases.map((p) =>
                    DropdownMenuItem<String?>(value: p, child: Text(p))),
              ],
              onChanged: (v) => setState(() => _selectedPhase = v),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLegend() {
    Widget chip(Color c, IconData icon, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        );
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      children: [
        chip(_blue, Icons.home, 'Occupied'),
        chip(_green, Icons.sell, 'For Sale'),
        chip(_orange, Icons.lock_clock, 'Reserved'),
        chip(_grey, Icons.crop_square, 'Vacant'),
      ],
    );
  }
}

class _PhaseSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _PhaseSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}