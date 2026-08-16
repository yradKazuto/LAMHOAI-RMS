import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/lot_model.dart';
import '../../../core/services/lot_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/member_model.dart';
import '../../../core/routing/app_router.dart';
import '../../members/screens/member_detail_screen.dart';
import '../widgets/lot_dialogs.dart';
import '../widgets/map_pin_view.dart';

const _navy = Color(0xFF0D2A52);
const _blue = Color(0xFF1565C0);
const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _grey = Color(0xFFBDBDBD);

class LocationMappingScreen extends StatefulWidget {
  /// Optional lot document ID to open/highlight when entering the map.
  final String? targetLotId;

  const LocationMappingScreen({
    super.key,
    this.targetLotId,
  });

  @override
  State<LocationMappingScreen> createState() =>
      _LocationMappingScreenState();
}

class _LocationMappingScreenState
    extends State<LocationMappingScreen> {
  final _service = LotService();

  // true = Map View
  // false = Grid View
  bool _showMapView = true;

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

  Future<List<MapEntry<String, String>>>
      _loadAssignableMembers() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'member')
        .get();

    return snap.docs
        .map(
          (d) => MapEntry(
            d.id,
            (d.data())['displayName'] as String? ??
                'Unnamed',
          ),
        )
        .toList();
  }

  Future<void> _viewMemberFromLot(LotModel lot) async {
    final uid = lot.uid?.trim();

    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This lot has no assigned member.'),
        ),
      );
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) return;

      if (!doc.exists || doc.data() == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member information could not be found.'),
          ),
        );
        return;
      }

      final member = MemberModel.fromMap(
        doc.data()!,
        doc.id,
      );

      // Close the lot dialog first.
      Navigator.of(context).pop();

      // Open the member details screen.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MemberDetailScreen(
            member: member,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open member details: $e'),
        ),
      );
    }
  }

  void _openLotDialog(
    LotModel lot,
    bool canEdit,
    String currentUserId,
  ) {
    if (lot.status == LotStatus.occupied) {
      showDialog(
        context: context,
        builder: (_) => OccupiedLotDialog(
          lot: lot,
          canEdit: canEdit,
          onViewMember: () => _viewMemberFromLot(lot),
          onUnassign: () => _service.unassignOwner(
            lotId: lot.id,
            updatedBy: currentUserId,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => VacantLotDialog(
          lot: lot,
          canEdit: canEdit,
          currentUserId: currentUserId,
          loadAssignableMembers:
              _loadAssignableMembers,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final role = auth.role;

    final canEdit =
        role == UserRole.admin ||
        role == UserRole.officer;

    final currentUserId =
        auth.userModel?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,

      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          24,
          16,
          24,
          20,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ==================================================
            // SMALL HEADER
            // ==================================================

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center,

              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(8),
                    onTap: () {
                      if (Navigator.of(context)
                          .canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go(
                          AppRoutes.dashboard,
                        );
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(
                        right: 10,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: _navy,
                        size: 22,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'Location Mapping',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w700,
                          color: _navy,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        'Subdivision lot map — '
                        'view occupancy and availability',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // ==============================================
                // MAP / GRID VIEW
                // ==============================================

                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Map View'),
                      icon: Icon(
                        Icons.map_outlined,
                        size: 18,
                      ),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Grid View'),
                      icon: Icon(
                        Icons.grid_view,
                        size: 18,
                      ),
                    ),
                  ],

                  selected: {
                    _showMapView,
                  },

                  onSelectionChanged:
                      (selection) {
                    setState(() {
                      _showMapView =
                          selection.first;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ==================================================
            // MAP / GRID CONTENT
            // ==================================================

            Expanded(
              child: StreamBuilder<List<LotModel>>(
                stream: _service.streamLots(),

                builder:
                    (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style:
                            const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    );
                  }

                  final lots =
                      snapshot.data ?? [];

                  // ==================================================
                  // MAP VIEW
                  // ==================================================

                  if (_showMapView) {
                    return MapPinView(
                      lots: lots,
                      canEdit: canEdit,
                      currentUserId:
                          currentUserId,
                      loadAssignableMembers:
                          _loadAssignableMembers,
                      targetLotId:
                          widget.targetLotId,
                      onViewMember:
                          _viewMemberFromLot,
                    );
                  }

                  // ==================================================
                  // GRID VIEW
                  // ==================================================

                  if (lots.isEmpty) {
                    return const Center(
                      child: Text(
                        'No lots found.',
                      ),
                    );
                  }

                  final grouped =
                      <String, List<LotModel>>{};

                  for (final lot in lots) {
                    grouped
                        .putIfAbsent(
                          lot.phase,
                          () => [],
                        )
                        .add(lot);
                  }

                  final phaseKeys =
                      grouped.keys.toList()
                        ..sort();

                  return ListView.builder(
                    padding:
                        const EdgeInsets.only(
                      bottom: 20,
                    ),

                    itemCount:
                        phaseKeys.length,

                    itemBuilder:
                        (context, index) {
                      final phase =
                          phaseKeys[index];

                      final phaseLots =
                          grouped[phase]!
                            ..sort(
                              (a, b) =>
                                  '${a.block}${a.lotNumber}'
                                      .compareTo(
                                '${b.block}${b.lotNumber}',
                              ),
                            );

                      return _PhaseSection(
                        title: phase,

                        child:
                            GridView.builder(
                          shrinkWrap: true,

                          physics:
                              const NeverScrollableScrollPhysics(),

                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent:
                                140,
                            mainAxisSpacing:
                                10,
                            crossAxisSpacing:
                                10,
                            childAspectRatio:
                                1,
                          ),

                          itemCount:
                              phaseLots.length,

                          itemBuilder:
                              (context, index) {
                            final lot =
                                phaseLots[
                                    index];

                            final color =
                                _colorFor(
                              lot.status,
                            );

                            return InkWell(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),

                              onTap: () =>
                                  _openLotDialog(
                                lot,
                                canEdit,
                                currentUserId,
                              ),

                              child:
                                  Container(
                                decoration:
                                    BoxDecoration(
                                  color: color
                                      .withOpacity(
                                    0.12,
                                  ),

                                  border:
                                      Border.all(
                                    color:
                                        color,
                                    width: 1.4,
                                  ),

                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    10,
                                  ),
                                ),

                                padding:
                                    const EdgeInsets
                                        .all(8),

                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,

                                  children: [
                                    Icon(
                                      _iconFor(
                                        lot.status,
                                      ),
                                      color:
                                          color,
                                      size: 22,
                                    ),

                                    const SizedBox(
                                      height: 6,
                                    ),

                                    Text(
                                      lot.lotNumber,
                                      textAlign:
                                          TextAlign
                                              .center,
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            12,
                                        fontWeight:
                                            FontWeight
                                                .w600,
                                        color:
                                            _navy,
                                      ),
                                    ),

                                    Text(
                                      lot.block,
                                      textAlign:
                                          TextAlign
                                              .center,
                                      style:
                                          TextStyle(
                                        fontSize:
                                            10,
                                        color:
                                            Colors.grey[
                                                600],
                                      ),
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
}

// ================================================================
// PHASE SECTION — GRID VIEW
// ================================================================

class _PhaseSection
    extends StatelessWidget {
  final String title;
  final Widget child;

  const _PhaseSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 20,
      ),

      padding:
          const EdgeInsets.all(16),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(12),

        border: Border.all(
          color:
              const Color(0xFFE0E8F4),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Text(
            title,
            style:
                const TextStyle(
              fontSize: 14,
              fontWeight:
                  FontWeight.w700,
              color: _navy,
            ),
          ),

          const SizedBox(height: 12),

          child,
        ],
      ),
    );
  }
}