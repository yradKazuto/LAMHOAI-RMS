import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle;

import '../../../core/models/lot_model.dart';
import '../../../core/services/lot_service.dart';
import 'lot_dialogs.dart';

const _navy = Color(0xFF0D2A52);
const _blue = Color(0xFF1565C0);
const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _purple = Color(0xFF6A1B9A);
const _grey = Color(0xFF9E9E9E);

const String kSubdivisionMapAsset =
    'assets/images/subdivision_map.png';

const double kMapWidth = 934.0;
const double kMapHeight = 1683.0;

class MapPinView extends StatefulWidget {
  final List<LotModel> lots;
  final bool canEdit;
  final String currentUserId;

  final Future<List<MapEntry<String, String>>>
      Function() loadAssignableMembers;

  /// When provided, the map automatically selects and zooms to this
  /// Firestore lot document when the map is opened.
  final String? targetLotId;

  /// Called when the user chooses View Member from an occupied lot.
  final Future<void> Function(LotModel lot)? onViewMember;

  const MapPinView({
    super.key,
    required this.lots,
    required this.canEdit,
    required this.currentUserId,
    required this.loadAssignableMembers,
    this.targetLotId,
    this.onViewMember,
  });

  @override
  State<MapPinView> createState() =>
      _MapPinViewState();
}

class _MapPinViewState extends State<MapPinView>
    with SingleTickerProviderStateMixin {
  final _service = LotService();

  final TransformationController
      _transformController =
      TransformationController();

  final GlobalKey _mapContentKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey();

  late final AnimationController
      _zoomAnimController;

  double? _aspectRatio;
  String? _loadError;

  String? _selectedBlock;
  int? _selectedLot;

  static const double _minScale = 0.3;
  static const double _maxScale = 8.0;

  @override
  void initState() {
    super.initState();
    _loadImageSize();

    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void didUpdateWidget(covariant MapPinView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.targetLotId != null &&
        widget.targetLotId != oldWidget.targetLotId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusTargetLot();
      });
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    _zoomAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    try {
      final data =
          await rootBundle.load(
        kSubdivisionMapAsset,
      );

      final codec =
          await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );

      final frame =
          await codec.getNextFrame();

      if (!mounted) return;

      setState(() {
        _aspectRatio =
            frame.image.width /
                frame.image.height;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusTargetLot();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadError = e.toString();
      });
    }
  }

  // ============================================================
  // BLOCKS
  // ============================================================

  List<String> _getBlocks() {
    final blocks = <String>{};

    for (final lot in widget.lots) {
      final block = lot.block.trim();

      if (block.isNotEmpty) {
        blocks.add(block);
      }
    }

    // Every block that has polygons digitized on the map is
    // included even if the database has not been populated yet.
    for (final polygon in allLotPolygons) {
      blocks.add(polygon.block);
    }

    final result = blocks.toList();

    result.sort((a, b) {
      final aNumber = int.tryParse(
        a.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        ),
      );

      final bNumber = int.tryParse(
        b.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        ),
      );

      if (aNumber != null &&
          bNumber != null) {
        return aNumber.compareTo(
          bNumber,
        );
      }

      return a
          .toLowerCase()
          .compareTo(
            b.toLowerCase(),
          );
    });

    return result;
  }

  // ============================================================
  // OPEN A SPECIFIC LOT
  // ============================================================

  void _focusTargetLot() {
    final targetId = widget.targetLotId;
    if (targetId == null || targetId.isEmpty) return;

    LotModel? targetLot;

    for (final lot in widget.lots) {
      if (lot.id == targetId) {
        targetLot = lot;
        break;
      }
    }

    if (targetLot == null) return;

    LotPolygon? targetPolygon;

    for (final polygon in allLotPolygons) {
      if (polygon.block.trim().toLowerCase() ==
              targetLot.block.trim().toLowerCase() &&
          polygon.lotNumber.toString() ==
              targetLot.lotNumber.trim()) {
        targetPolygon = polygon;
        break;
      }
    }

    if (targetPolygon == null || !mounted) return;

    setState(() {
      _selectedBlock = targetPolygon!.block;
      _selectedLot = targetPolygon!.lotNumber;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _zoomToLot(targetPolygon!);
    });
  }

  void _zoomToLot(LotPolygon polygon) {
    final contentBox = _mapContentKey.currentContext
        ?.findRenderObject() as RenderBox?;

    final viewportBox = _viewportKey.currentContext
        ?.findRenderObject() as RenderBox?;

    if (contentBox == null ||
        viewportBox == null ||
        !contentBox.hasSize ||
        !viewportBox.hasSize) {
      return;
    }

    final contentSize = contentBox.size;
    final viewportSize = viewportBox.size;

    final letterboxX =
        (viewportSize.width - contentSize.width) / 2;
    final letterboxY =
        (viewportSize.height - contentSize.height) / 2;

    final points = polygon.points.map((p) => Offset(
      letterboxX +
          p.dx / kMapWidth * contentSize.width,
      letterboxY +
          p.dy / kMapHeight * contentSize.height,
    )).toList();

    if (points.isEmpty) return;

    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final boxWidth = maxX - minX;
    final boxHeight = maxY - minY;

    if (boxWidth <= 0 || boxHeight <= 0) return;

    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    const paddingFactor = 2.5;

    final scaleByWidth =
        (viewportSize.width /
                (boxWidth * paddingFactor))
            .clamp(_minScale, _maxScale);

    final scaleByHeight =
        (viewportSize.height /
                (boxHeight * paddingFactor))
            .clamp(_minScale, _maxScale);

    final scale =
        scaleByWidth < scaleByHeight
            ? scaleByWidth
            : scaleByHeight;

    final target = Matrix4.identity()
      ..translate(
        viewportSize.width / 2 - centerX * scale,
        viewportSize.height / 2 - centerY * scale,
      )
      ..scale(scale);

    _animateToMatrix(target);
  }

  void _selectBlock(String block) {
    final deselecting = _selectedBlock == block;

    setState(() {
      _selectedBlock = deselecting ? null : block;
      _selectedLot = null;
    });

    if (deselecting) {
      _animateToMatrix(Matrix4.identity());
    } else {
      // Wait a frame so layout is settled before measuring.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _zoomToBlock(block);
      });
    }
  }

  /// Returns the highlight color for a polygon based on the matching
  /// lot's status. Always shown, regardless of which block (if any)
  /// is currently selected.
  Color? _lotHighlightColor(LotPolygon polygon) {
    LotModel? match;

    for (final lot in widget.lots) {
      if (lot.block.trim().toLowerCase() ==
              polygon.block.trim().toLowerCase() &&
          lot.lotNumber.trim() ==
              polygon.lotNumber.toString()) {
        match = lot;
        break;
      }
    }

    if (match == null) {
      // Lot exists on the map but hasn't been created
      // in the database yet.
      return _grey;
    }

    switch (match.status) {
      case LotStatus.occupied:
        return _green;
      case LotStatus.vacant:
        return _blue;
      case LotStatus.forSale:
        return _orange;
      case LotStatus.reserved:
        return _purple;
    }
  }

  // ============================================================
  // ZOOM TO BLOCK
  // ============================================================

  void _animateToMatrix(Matrix4 target) {
    final tween = Matrix4Tween(
      begin: _transformController.value,
      end: target,
    );

    _zoomAnimController
      ..reset()
      ..addListener(() {
        _transformController.value =
            tween.evaluate(
          CurvedAnimation(
            parent: _zoomAnimController,
            curve: Curves.easeInOutCubic,
          ),
        );
      })
      ..forward();
  }

  void _zoomToBlock(String block) {
  final contentBox = _mapContentKey.currentContext
      ?.findRenderObject() as RenderBox?;

  final viewportBox = _viewportKey.currentContext
      ?.findRenderObject() as RenderBox?;

  if (contentBox == null ||
      viewportBox == null ||
      !contentBox.hasSize ||
      !viewportBox.hasSize) {
    return;
  }

  final contentSize = contentBox.size;
  final viewportSize = viewportBox.size;

  // The map content (AspectRatio box) is centered inside the
  // InteractiveViewer's child area, which is the same size as the
  // viewport. If the map's aspect ratio doesn't match the viewport's,
  // Center adds empty margin on the sides (or top/bottom) — that
  // margin has to be added back in, or every computed position drifts
  // by exactly that amount.
  final letterboxX =
      (viewportSize.width - contentSize.width) / 2;
  final letterboxY =
      (viewportSize.height - contentSize.height) / 2;

  final points = <Offset>[];

  for (final polygon in allLotPolygons) {
    if (polygon.block.trim().toLowerCase() !=
        block.trim().toLowerCase()) {
      continue;
    }

    for (final p in polygon.points) {
      points.add(
        Offset(
          letterboxX +
              p.dx / kMapWidth * contentSize.width,
          letterboxY +
              p.dy / kMapHeight * contentSize.height,
        ),
      );
    }
  }

  if (points.isEmpty) return;

  double minX = points.first.dx;
  double maxX = points.first.dx;
  double minY = points.first.dy;
  double maxY = points.first.dy;

  for (final p in points) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }

  final boxWidth = maxX - minX;
  final boxHeight = maxY - minY;

  if (boxWidth <= 0 || boxHeight <= 0) return;

  final centerX = (minX + maxX) / 2;
  final centerY = (minY + maxY) / 2;

  // Add breathing room around the block instead of framing it
  // edge-to-edge.
  const paddingFactor = 1.35;

  final scaleByWidth = (viewportSize.width /
          (boxWidth * paddingFactor))
      .clamp(_minScale, _maxScale);

  final scaleByHeight = (viewportSize.height /
          (boxHeight * paddingFactor))
      .clamp(_minScale, _maxScale);

  final scale =
      scaleByWidth < scaleByHeight ? scaleByWidth : scaleByHeight;

  final target = Matrix4.identity()
    ..translate(
      viewportSize.width / 2 - centerX * scale,
      viewportSize.height / 2 - centerY * scale,
    )
    ..scale(scale);

  _animateToMatrix(target);
}

  // ============================================================
  // LOT CLICK
  // ============================================================

  void _onLotTapped(
    LotPolygon polygon,
  ) {
    setState(() {
      _selectedLot = polygon.lotNumber;
      _selectedBlock = polygon.block;
    });

    LotModel? selectedLot;

    for (final lot in widget.lots) {
      if (lot.block.trim().toLowerCase() ==
              polygon.block.trim().toLowerCase() &&
          lot.lotNumber.trim() ==
              polygon.lotNumber.toString()) {
        selectedLot = lot;
        break;
      }
    }

    if (selectedLot == null) {
      if (!widget.canEdit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${polygon.block} • Lot ${polygon.lotNumber} '
              'is selected, but its details are not available yet.',
            ),
          ),
        );

        return;
      }

      final center = _polygonCenter(polygon.points);

      showDialog(
        context: context,
        builder: (_) => AddLotDialog(
          phase: 'Phase 1',
          block: polygon.block,
          lotNumber: polygon.lotNumber.toString(),
          currentUserId: widget.currentUserId,
          loadAssignableMembers: widget.loadAssignableMembers,
          mapX: center.dx / kMapWidth,
          mapY: center.dy / kMapHeight,
        ),
      );

      return;
    }

    _openLotDialog(selectedLot);
  }

  Offset _polygonCenter(List<Offset> points) {
    double sumX = 0;
    double sumY = 0;

    for (final p in points) {
      sumX += p.dx;
      sumY += p.dy;
    }

    return Offset(
      sumX / points.length,
      sumY / points.length,
    );
  }

  void _openLotDialog(
    LotModel lot,
  ) {
    if (lot.status ==
        LotStatus.occupied) {
      showDialog(
        context: context,
        builder: (_) =>
            OccupiedLotDialog(
          lot: lot,
          canEdit: widget.canEdit,
          onViewMember: widget.onViewMember == null
              ? null
              : () => widget.onViewMember!(lot),
          onUnassign: () =>
              _service.unassignOwner(
            lotId: lot.id,
            updatedBy:
                widget.currentUserId,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) =>
            VacantLotDialog(
          lot: lot,
          canEdit: widget.canEdit,
          currentUserId:
              widget.currentUserId,
          loadAssignableMembers:
              widget
                  .loadAssignableMembers,
        ),
      );
    }
  }

  // ============================================================
  // MANUAL ZOOM
  // ============================================================

  void _zoomBy(double factor) {
    final current =
        _transformController.value.clone();

    final currentScale =
        current.getMaxScaleOnAxis();

    final targetScale =
        (currentScale * factor).clamp(
      _minScale,
      _maxScale,
    );

    final adjust =
        targetScale / currentScale;

    final matrix =
        current.clone()
          ..scale(adjust);

    _transformController.value =
        matrix;
  }

  void _resetZoom() {
    _animateToMatrix(Matrix4.identity());
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loadError != null) {
      return _buildError();
    }

    if (_aspectRatio == null) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    return LayoutBuilder(
      builder:
          (context, constraints) {
        final width =
            constraints.maxWidth;

        final panelWidth =
            width < 900
                ? 190.0
                : 230.0;

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
          children: [
            SizedBox(
              width: panelWidth,
              child:
                  _buildBlockPanel(),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
                  _buildMapArea(),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BLOCK PANEL
  // ============================================================

  Widget _buildBlockPanel() {
    final blocks =
        _getBlocks();

    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xFFE1E5EA),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Blocks',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w700,
              color: _navy,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Tap a block to zoom '
            'in. Tap again to reset.',
            style: TextStyle(
              fontSize: 12,
              color:
                  Colors.grey[600],
              height: 1.3,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Expanded(
            child: ListView(
              padding:
                  EdgeInsets.zero,
              children: [
                ...blocks.map(
                  (block) =>
                      Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      bottom: 8,
                    ),
                    child:
                        _buildBlockButton(
                      label: block,
                      icon: Icons
                          .grid_view_rounded,
                      selected:
                          _selectedBlock ==
                              block,
                      onTap: () =>
                          _selectBlock(
                        block,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF4F7FB,
              ),
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_alt_outlined,
                  size: 16,
                  color: _navy,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    _selectedBlock ==
                            null
                        ? 'Select a block'
                        : 'Selected: '
                            '$_selectedBlock',
                    style:
                        const TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                      color: _navy,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE2E5E9),
              ),
            ),
            child: const Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _LegendRow(
                  color: _green,
                  label: 'Occupied',
                ),
                SizedBox(height: 6),
                _LegendRow(
                  color: _blue,
                  label: 'Vacant',
                ),
                SizedBox(height: 6),
                _LegendRow(
                  color: _orange,
                  label: 'For Sale',
                ),
                SizedBox(height: 6),
                _LegendRow(
                  color: _purple,
                  label: 'Reserved',
                ),
                SizedBox(height: 6),
                _LegendRow(
                  color: _grey,
                  label: 'Not yet added',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(9),
        onTap: onTap,
        child:
            AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          decoration:
              BoxDecoration(
            color: selected
                ? const Color(
                    0xFFE8F0FE,
                  )
                : const Color(
                    0xFFF8F9FB,
                  ),
            borderRadius:
                BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? _blue
                  : const Color(
                      0xFFE2E5E9,
                    ),
              width:
                  selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? _blue
                    : _navy,
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  label,
                  style:
                      TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected
                            ? FontWeight
                                .w700
                            : FontWeight
                                .w500,
                    color: selected
                        ? _blue
                        : _navy,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  size: 17,
                  color: _blue,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MAP
  // ============================================================

  Widget _buildMapArea() {
    return Container(
      key: _viewportKey,
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFF1F3F5),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xFFE1E5EA),
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Stack(
        children: [
          InteractiveViewer(
            transformationController:
                _transformController,
            minScale: _minScale,
            maxScale: _maxScale,
            boundaryMargin:
                const EdgeInsets.all(
              150,
            ),
            child: Center(
              child: AspectRatio(
                aspectRatio:
                    _aspectRatio!,
                child: Stack(
                  key: _mapContentKey,
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      kSubdivisionMapAsset,
                      fit: BoxFit.contain,
                    ),

                    if (_selectedBlock != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _BlockSpotlightPainter(
                              blockPolygons: allLotPolygons
                                  .where((p) =>
                                      p.block.trim().toLowerCase() ==
                                      _selectedBlock!.trim().toLowerCase())
                                  .map((p) => p.points)
                                  .toList(),
                            ),
                          ),
                        ),
                      ),

                    // ==================================================
                    // LOT POLYGONS (all digitized blocks)
                    // ==================================================

                    ...allLotPolygons
                        .map(
                      (polygon) =>
                          Positioned.fill(
                        child:
                            _LotPolygonWidget(
                          polygon:
                              polygon,
                          highlightColor:
                              _lotHighlightColor(
                            polygon,
                          ),
                          selected:
                              _selectedLot ==
                                  polygon
                                      .lotNumber &&
                              _selectedBlock ==
                                  polygon.block,
                          onTap: () =>
                              _onLotTapped(
                            polygon,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 14,
            top: 14,
            child:
                _buildMapStatus(),
          ),

          Positioned(
            right: 14,
            bottom: 14,
            child: Column(
              children: [
                _ZoomButton(
                  icon: Icons.add,
                  tooltip: 'Zoom in',
                  onPressed: () =>
                      _zoomBy(1.4),
                ),
                const SizedBox(
                  height: 8,
                ),
                _ZoomButton(
                  icon:
                      Icons.remove,
                  tooltip:
                      'Zoom out',
                  onPressed: () =>
                      _zoomBy(1 / 1.4),
                ),
                const SizedBox(
                  height: 8,
                ),
                _ZoomButton(
                  icon: Icons
                      .center_focus_strong,
                  tooltip:
                      'Reset view',
                  onPressed:
                      _resetZoom,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapStatus() {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius:
          BorderRadius.circular(20),
      child: Padding(
        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.layers_outlined,
              size: 17,
              color: _navy,
            ),
            const SizedBox(
              width: 7,
            ),
            Text(
              _selectedBlock ??
                  'Select a Block',
              style:
                  const TextStyle(
                color: _navy,
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      alignment:
          Alignment.center,
      color: Colors.grey[100],
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Text(
          'Could not load map image.\n\n'
          'Make sure the file exists at:\n'
          '$kSubdivisionMapAsset\n\n'
          'Error: $_loadError',
          textAlign:
              TextAlign.center,
          style:
              const TextStyle(
            color: Colors.red,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// BLOCK SPOTLIGHT PAINTER
// ================================================================

class _BlockSpotlightPainter extends CustomPainter {
  final List<List<Offset>> blockPolygons;

  const _BlockSpotlightPainter({
    required this.blockPolygons,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (blockPolygons.isEmpty) return;

    canvas.saveLayer(Offset.zero & size, Paint());

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withOpacity(0.45),
    );

    final clearPaint = Paint()
      ..blendMode = BlendMode.clear;

    for (final points in blockPolygons) {
      if (points.isEmpty) continue;

      final path = Path();
      final first = points.first;

      path.moveTo(
        first.dx / kMapWidth * size.width,
        first.dy / kMapHeight * size.height,
      );

      for (int i = 1; i < points.length; i++) {
        final p = points[i];

        path.lineTo(
          p.dx / kMapWidth * size.width,
          p.dy / kMapHeight * size.height,
        );
      }

      path.close();

      canvas.drawPath(path, clearPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlockSpotlightPainter oldDelegate) {
    return true;
  }
}

// ================================================================
// LOT POLYGON WIDGET
// ================================================================

class _LotPolygonWidget
    extends StatelessWidget {
  final LotPolygon polygon;
  final Color? highlightColor;
  final bool selected;
  final VoidCallback onTap;

  const _LotPolygonWidget({
    required this.polygon,
    required this.highlightColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ClipPath(
      clipper:
          _LotPolygonClipper(
        points: polygon.points,
      ),
      child: GestureDetector(
        behavior:
            HitTestBehavior.opaque,
        onTap: onTap,
        child: CustomPaint(
          painter:
              _LotPolygonPainter(
            highlightColor:
                highlightColor,
            selected:
                selected,
          ),
          child:
              const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _LotPolygonClipper
    extends CustomClipper<Path> {
  final List<Offset> points;

  const _LotPolygonClipper({
    required this.points,
  });

  @override
  Path getClip(Size size) {
    final path = Path();

    if (points.isEmpty) {
      return path;
    }

    final first = points.first;

    path.moveTo(
      first.dx / kMapWidth * size.width,
      first.dy / kMapHeight * size.height,
    );

    for (int i = 1;
        i < points.length;
        i++) {
      final point = points[i];

      path.lineTo(
        point.dx / kMapWidth *
            size.width,
        point.dy / kMapHeight *
            size.height,
      );
    }

    path.close();

    return path;
  }

  @override
  bool shouldReclip(
    _LotPolygonClipper oldClipper,
  ) {
    return true;
  }
}

class _LotPolygonPainter
    extends CustomPainter {
  final Color? highlightColor;
  final bool selected;

  const _LotPolygonPainter({
    required this.highlightColor,
    required this.selected,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (highlightColor != null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = highlightColor!.withOpacity(0.40),
      );
    }

    if (selected) {
      final rect = Offset.zero & size;

      canvas.drawRect(
        rect.deflate(1.5),
        Paint()
          ..color = _navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(
    _LotPolygonPainter oldDelegate,
  ) {
    return oldDelegate.highlightColor !=
            highlightColor ||
        oldDelegate.selected !=
            selected;
  }
}

// ================================================================
// LOT POLYGON DATA MODEL
// ================================================================

/// A single lot's clickable/highlightable boundary on the
/// subdivision map image, in image pixel coordinates
/// (0,0 = top-left, matching kMapWidth x kMapHeight).
class LotPolygon {
  final String block;
  final int lotNumber;
  final List<Offset> points;

  const LotPolygon({
    required this.block,
    required this.lotNumber,
    required this.points,
  });
}

/// All digitized blocks combined. Add new block lists here as
/// they get traced (see block1LotPolygons / block2LotPolygons
/// below for the per-block source data).
final List<LotPolygon> allLotPolygons = [
  ...block1LotPolygons,
  ...block2LotPolygons,
  ...block3LotPolygons,
  ...block4LotPolygons,
  ...block5LotPolygons,
  ...block6LotPolygons,
  ...block7LotPolygons,
  ...block8LotPolygons,
  ...block9LotPolygons,
  ...block10LotPolygons,
  ...block11LotPolygons,
  ...block12LotPolygons,
  ...block13LotPolygons,
  ...block14LotPolygons,
  ...block15LotPolygons,
  ...block16LotPolygons,

];

// ================================================================
// BLOCK 1 LOT DATA
// ================================================================

const List<LotPolygon> block1LotPolygons = [
  LotPolygon(
    block: 'Block 1',
    lotNumber: 1,
    points: [
      Offset(301, 802),
      Offset(335, 817),
      Offset(324, 850),
      Offset(283, 833),
      Offset(291, 807),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 2,
    points: [
      Offset(283, 834),
      Offset(324, 851),
      Offset(311, 888),
      Offset(270, 870),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 3,
    points: [
      Offset(270, 872),
      Offset(310, 889),
      Offset(298, 926),
      Offset(257, 907),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 4,
    points: [
      Offset(257, 909),
      Offset(298, 926),
      Offset(294, 940),
      Offset(292, 960),
      Offset(246, 941),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 5,
    points: [
      Offset(246, 943),
      Offset(292, 961),
      Offset(288, 985),
      Offset(243, 978),
      Offset(237, 969),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 6,
    points: [
      Offset(295, 942),
      Offset(330, 947),
      Offset(325, 991),
      Offset(290, 986),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 7,
    points: [
      Offset(331, 947),
      Offset(367, 953),
      Offset(361, 996),
      Offset(326, 991),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 8,
    points: [
      Offset(367, 953),
      Offset(403, 959),
      Offset(398, 1002),
      Offset(362, 997),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 9,
    points: [
      Offset(404, 959),
      Offset(440, 965),
      Offset(434, 1008),
      Offset(399, 1003),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 10,
    points: [
      Offset(441, 965),
      Offset(475, 970),
      Offset(469, 1013),
      Offset(435, 1008),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 11,
    points: [
      Offset(477, 970),
      Offset(511, 975),
      Offset(505, 1019),
      Offset(471, 1014),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 12,
    points: [
      Offset(512, 975),
      Offset(548, 980),
      Offset(541, 1023),
      Offset(506, 1019),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 13,
    points: [
      Offset(549, 980),
      Offset(584, 984),
      Offset(577, 1027),
      Offset(542, 1023),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 14,
    points: [
      Offset(585, 984),
      Offset(619, 988),
      Offset(612, 1031),
      Offset(578, 1027),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 15,
    points: [
      Offset(620, 988),
      Offset(655, 991),
      Offset(647, 1034),
      Offset(613, 1031),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 16,
    points: [
      Offset(655, 992),
      Offset(690, 995),
      Offset(681, 1038),
      Offset(648, 1034),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 17,
    points: [
      Offset(691, 995),
      Offset(703, 996),
      Offset(726, 1020),
      Offset(696, 1052),
      Offset(683, 1039),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 18,
    points: [
      Offset(727, 1021),
      Offset(748, 1042),
      Offset(718, 1074),
      Offset(697, 1054),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 19,
    points: [
      Offset(749, 1043),
      Offset(772, 1066),
      Offset(742, 1099),
      Offset(718, 1075),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 20,
    points: [
      Offset(773, 1067),
      Offset(798, 1095),
      Offset(768, 1128),
      Offset(743, 1100),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 21,
    points: [
      Offset(799, 1096),
      Offset(824, 1123),
      Offset(794, 1156),
      Offset(769, 1130),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 22,
    points: [
      Offset(825, 1124),
      Offset(849, 1149),
      Offset(820, 1184),
      Offset(795, 1158),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 23,
    points: [
      Offset(849, 1150),
      Offset(877, 1181),
      Offset(882, 1230),
      Offset(841, 1240),
      Offset(838, 1204),
      Offset(820, 1185),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 24,
    points: [
      Offset(841, 1241),
      Offset(882, 1231),
      Offset(886, 1268),
      Offset(846, 1277),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 25,
    points: [
      Offset(846, 1279),
      Offset(886, 1270),
      Offset(890, 1304),
      Offset(850, 1313),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 26,
    points: [
      Offset(850, 1314),
      Offset(890, 1306),
      Offset(894, 1339),
      Offset(854, 1348),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 27,
    points: [
      Offset(854, 1350),
      Offset(894, 1341),
      Offset(897, 1374),
      Offset(858, 1382),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 28,
    points: [
      Offset(858, 1384),
      Offset(898, 1376),
      Offset(901, 1409),
      Offset(862, 1418),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 29,
    points: [
      Offset(862, 1420),
      Offset(901, 1412),
      Offset(905, 1444),
      Offset(866, 1454),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 30,
    points: [
      Offset(866, 1455),
      Offset(905, 1446),
      Offset(909, 1479),
      Offset(870, 1488),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 31,
    points: [
      Offset(870, 1489),
      Offset(908, 1481),
      Offset(912, 1513),
      Offset(874, 1521),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 32,
    points: [
      Offset(874, 1523),
      Offset(912, 1515),
      Offset(916, 1546),
      Offset(878, 1556),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 33,
    points: [
      Offset(878, 1557),
      Offset(916, 1549),
      Offset(919, 1580),
      Offset(883, 1589),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 34,
    points: [
      Offset(883, 1591),
      Offset(920, 1582),
      Offset(924, 1621),
      Offset(905, 1626),
      Offset(893, 1615),
      Offset(883, 1602),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 35,
    points: [
      Offset(893, 1630),
      Offset(924, 1623),
      Offset(928, 1661),
      Offset(892, 1662),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 36,
    points: [
      Offset(860, 1622),
      Offset(884, 1622),
      Offset(893, 1629),
      Offset(891, 1662),
      Offset(860, 1663),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 37,
    points: [
      Offset(828, 1623),
      Offset(859, 1622),
      Offset(858, 1663),
      Offset(828, 1663),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 38,
    points: [
      Offset(795, 1624),
      Offset(827, 1623),
      Offset(827, 1663),
      Offset(795, 1664),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 39,
    points: [
      Offset(763, 1625),
      Offset(794, 1625),
      Offset(794, 1664),
      Offset(762, 1665),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 40,
    points: [
      Offset(730, 1626),
      Offset(762, 1625),
      Offset(761, 1665),
      Offset(729, 1665),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 41,
    points: [
      Offset(696, 1627),
      Offset(729, 1626),
      Offset(728, 1665),
      Offset(696, 1666),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 42,
    points: [
      Offset(663, 1628),
      Offset(695, 1627),
      Offset(695, 1666),
      Offset(663, 1667),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 43,
    points: [
      Offset(630, 1629),
      Offset(662, 1628),
      Offset(662, 1667),
      Offset(629, 1668),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 44,
    points: [
      Offset(597, 1630),
      Offset(629, 1629),
      Offset(629, 1668),
      Offset(596, 1669),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 45,
    points: [
      Offset(564, 1631),
      Offset(596, 1630),
      Offset(596, 1668),
      Offset(564, 1669),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 46,
    points: [
      Offset(531, 1632),
      Offset(562, 1630),
      Offset(562, 1669),
      Offset(530, 1669),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 47,
    points: [
      Offset(496, 1633),
      Offset(530, 1632),
      Offset(530, 1669),
      Offset(497, 1670),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 48,
    points: [
      Offset(464, 1633),
      Offset(496, 1633),
      Offset(496, 1670),
      Offset(464, 1672),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 49,
    points: [
      Offset(430, 1634),
      Offset(463, 1633),
      Offset(463, 1671),
      Offset(430, 1672),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 50,
    points: [
      Offset(399, 1634),
      Offset(429, 1633),
      Offset(429, 1672),
      Offset(398, 1671),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 51,
    points: [
      Offset(358, 1628),
      Offset(399, 1627),
      Offset(398, 1672),
      Offset(358, 1671),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 52,
    points: [
      Offset(358, 1595),
      Offset(391, 1597),
      Offset(399, 1610),
      Offset(399, 1625),
      Offset(358, 1627),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 53,
    points: [
      Offset(314, 1592),
      Offset(358, 1596),
      Offset(358, 1671),
      Offset(327, 1671),
      Offset(327, 1633),
      Offset(303, 1631),
      Offset(306, 1599),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 54,
    points: [
      Offset(294, 1632),
      Offset(327, 1633),
      Offset(327, 1670),
      Offset(294, 1670),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 55,
    points: [
      Offset(261, 1630),
      Offset(293, 1632),
      Offset(293, 1670),
      Offset(261, 1669),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 56,
    points: [
      Offset(230, 1629),
      Offset(261, 1631),
      Offset(261, 1669),
      Offset(230, 1668),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 57,
    points: [
      Offset(197, 1627),
      Offset(230, 1629),
      Offset(229, 1668),
      Offset(197, 1667),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 58,
    points: [
      Offset(164, 1626),
      Offset(197, 1627),
      Offset(197, 1667),
      Offset(164, 1666),
    ],
  ),
  LotPolygon(
    block: 'Block 1',
    lotNumber: 59,
    points: [
      Offset(141, 1624),
      Offset(163, 1626),
      Offset(164, 1667),
      Offset(133, 1666),
      Offset(133, 1631),
    ],
  ),
];


// ================================================================
// BLOCK 2 LOT DATA
// ================================================================

const List<LotPolygon> block2LotPolygons = [
  LotPolygon(
    block: 'Block 2',
    lotNumber: 1,
    points: [
      Offset(423, 1524),
      Offset(448, 1524),
      Offset(448, 1566),
      Offset(414, 1566),
      Offset(415, 1531),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 2,
    points: [
      Offset(414, 1569),
      Offset(449, 1568),
      Offset(449, 1608),
      Offset(425, 1608),
      Offset(412, 1590),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 3,
    points: [
      Offset(450, 1524),
      Offset(482, 1524),
      Offset(482, 1565),
      Offset(451, 1565),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 4,
    points: [
      Offset(451, 1567),
      Offset(482, 1567),
      Offset(482, 1607),
      Offset(451, 1607),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 5,
    points: [
      Offset(484, 1524),
      Offset(516, 1523),
      Offset(516, 1563),
      Offset(484, 1564),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 6,
    points: [
      Offset(484, 1566),
      Offset(516, 1566),
      Offset(516, 1606),
      Offset(484, 1607),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 7,
    points: [
      Offset(518, 1523),
      Offset(550, 1522),
      Offset(550, 1562),
      Offset(518, 1563),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 8,
    points: [
      Offset(518, 1565),
      Offset(550, 1565),
      Offset(550, 1605),
      Offset(518, 1605),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 9,
    points: [
      Offset(552, 1521),
      Offset(584, 1521),
      Offset(584, 1562),
      Offset(552, 1562),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 10,
    points: [
      Offset(552, 1564),
      Offset(584, 1564),
      Offset(584, 1604),
      Offset(552, 1604),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 11,
    points: [
      Offset(586, 1520),
      Offset(618, 1520),
      Offset(618, 1561),
      Offset(586, 1561),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 12,
    points: [
      Offset(586, 1563),
      Offset(618, 1563),
      Offset(618, 1603),
      Offset(586, 1604),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 13,
    points: [
      Offset(620, 1520),
      Offset(651, 1519),
      Offset(650, 1560),
      Offset(620, 1560),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 14,
    points: [
      Offset(620, 1562),
      Offset(651, 1562),
      Offset(651, 1602),
      Offset(620, 1603),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 15,
    points: [
      Offset(653, 1518),
      Offset(685, 1518),
      Offset(685, 1559),
      Offset(653, 1559),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 16,
    points: [
      Offset(653, 1561),
      Offset(684, 1561),
      Offset(683, 1601),
      Offset(653, 1601),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 17,
    points: [
      Offset(687, 1517),
      Offset(718, 1517),
      Offset(718, 1557),
      Offset(687, 1558),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 18,
    points: [
      Offset(687, 1560),
      Offset(718, 1560),
      Offset(717, 1600),
      Offset(686, 1600),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 19,
    points: [
      Offset(721, 1516),
      Offset(752, 1516),
      Offset(751, 1556),
      Offset(721, 1556),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 20,
    points: [
      Offset(720, 1559),
      Offset(750, 1559),
      Offset(750, 1598),
      Offset(720, 1599),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 21,
    points: [
      Offset(754, 1515),
      Offset(785, 1515),
      Offset(785, 1555),
      Offset(754, 1555),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 22,
    points: [
      Offset(753, 1558),
      Offset(784, 1558),
      Offset(784, 1597),
      Offset(753, 1597),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 23,
    points: [
      Offset(787, 1514),
      Offset(818, 1514),
      Offset(818, 1554),
      Offset(787, 1555),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 24,
    points: [
      Offset(786, 1557),
      Offset(817, 1557),
      Offset(816, 1596),
      Offset(786, 1597),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 25,
    points: [
      Offset(821, 1513),
      Offset(838, 1512),
      Offset(846, 1519),
      Offset(851, 1558),
      Offset(820, 1559),
    ],
  ),

  LotPolygon(
    block: 'Block 2',
    lotNumber: 26,
    points: [
      Offset(819, 1561),
      Offset(851, 1560),
      Offset(854, 1588),
      Offset(848, 1595),
      Offset(818, 1596),
    ],
  ),
];

// Block 3
const List<LotPolygon> block3LotPolygons = [
  LotPolygon(
    block: 'Block 3',
    lotNumber: 1,
    points: [
      Offset(431, 1418),
      Offset(457, 1417),
      Offset(458, 1458),
      Offset(423, 1459),
      Offset(425, 1424),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 2,
    points: [
      Offset(422, 1461),
      Offset(458, 1460),
      Offset(458, 1501),
      Offset(426, 1502),
      Offset(420, 1495),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 3,
    points: [
      Offset(459, 1417),
      Offset(492, 1416),
      Offset(492, 1457),
      Offset(459, 1458),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 4,
    points: [
      Offset(459, 1460),
      Offset(492, 1459),
      Offset(492, 1499),
      Offset(460, 1501),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 5,
    points: [
      Offset(494, 1416),
      Offset(526, 1415),
      Offset(526, 1456),
      Offset(494, 1457),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 6,
    points: [
      Offset(494, 1459),
      Offset(526, 1458),
      Offset(527, 1499),
      Offset(494, 1500),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 7,
    points: [
      Offset(529, 1415),
      Offset(561, 1414),
      Offset(561, 1455),
      Offset(528, 1456),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 8,
    points: [
      Offset(528, 1458),
      Offset(561, 1457),
      Offset(561, 1498),
      Offset(529, 1499),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 9,
    points: [
      Offset(563, 1414),
      Offset(595, 1413),
      Offset(595, 1454),
      Offset(563, 1455),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 10,
    points: [
      Offset(563, 1457),
      Offset(595, 1457),
      Offset(595, 1497),
      Offset(563, 1498),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 11,
    points: [
      Offset(597, 1413),
      Offset(629, 1413),
      Offset(629, 1454),
      Offset(597, 1454),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 12,
    points: [
      Offset(597, 1457),
      Offset(629, 1456),
      Offset(629, 1496),
      Offset(597, 1497),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 13,
    points: [
      Offset(632, 1413),
      Offset(664, 1412),
      Offset(663, 1453),
      Offset(632, 1454),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 14,
    points: [
      Offset(631, 1456),
      Offset(663, 1455),
      Offset(662, 1495),
      Offset(631, 1496),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 15,
    points: [
      Offset(666, 1412),
      Offset(698, 1411),
      Offset(697, 1451),
      Offset(665, 1452),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 16,
    points: [
      Offset(665, 1455),
      Offset(697, 1454),
      Offset(696, 1494),
      Offset(664, 1495),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 17,
    points: [
      Offset(700, 1411),
      Offset(732, 1410),
      Offset(731, 1450),
      Offset(699, 1451),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 18,
    points: [
      Offset(699, 1454),
      Offset(731, 1453),
      Offset(730, 1493),
      Offset(698, 1494),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 19,
    points: [
      Offset(734, 1410),
      Offset(766, 1409),
      Offset(765, 1449),
      Offset(733, 1450),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 20,
    points: [
      Offset(733, 1453),
      Offset(765, 1452),
      Offset(764, 1492),
      Offset(732, 1493),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 21,
    points: [
      Offset(768, 1409),
      Offset(798, 1408),
      Offset(796, 1448),
      Offset(767, 1449),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 22,
    points: [
      Offset(766, 1451),
      Offset(797, 1451),
      Offset(795, 1491),
      Offset(766, 1492),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 23,
    points: [
      Offset(800, 1408),
      Offset(826, 1407),
      Offset(834, 1414),
      Offset(838, 1450),
      Offset(798, 1451),
    ],
  ),
  LotPolygon(
    block: 'Block 3',
    lotNumber: 24,
    points: [
      Offset(798, 1454),
      Offset(838, 1453),
      Offset(842, 1482),
      Offset(834, 1490),
      Offset(796, 1491),
    ],
  ),
];

// Block 4
const List<LotPolygon> block4LotPolygons = [
  LotPolygon(
    block: 'Block 4',
    lotNumber: 1,
    points: [
      Offset(440, 1302),
      Offset(466, 1302),
      Offset(467, 1348),
      Offset(431, 1349),
      Offset(433, 1309),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 2,
    points: [
      Offset(431, 1349),
      Offset(466, 1349),
      Offset(467, 1393),
      Offset(435, 1394),
      Offset(428, 1387),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 3,
    points: [
      Offset(467, 1303),
      Offset(501, 1302),
      Offset(502, 1347),
      Offset(468, 1348),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 4,
    points: [
      Offset(468, 1349),
      Offset(501, 1349),
      Offset(502, 1392),
      Offset(468, 1393),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 5,
    points: [
      Offset(503, 1303),
      Offset(536, 1303),
      Offset(536, 1346),
      Offset(503, 1347),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 6,
    points: [
      Offset(503, 1349),
      Offset(536, 1349),
      Offset(537, 1390),
      Offset(503, 1392),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 7,
    points: [
      Offset(538, 1303),
      Offset(571, 1303),
      Offset(572, 1346),
      Offset(538, 1347),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 8,
    points: [
      Offset(538, 1348),
      Offset(572, 1348),
      Offset(572, 1389),
      Offset(539, 1391),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 9,
    points: [
      Offset(573, 1302),
      Offset(606, 1302),
      Offset(606, 1345),
      Offset(573, 1346),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 10,
    points: [
      Offset(573, 1348),
      Offset(606, 1347),
      Offset(606, 1389),
      Offset(574, 1389),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 11,
    points: [
      Offset(608, 1302),
      Offset(641, 1302),
      Offset(641, 1344),
      Offset(609, 1345),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 12,
    points: [
      Offset(608, 1347),
      Offset(641, 1346),
      Offset(641, 1388),
      Offset(608, 1389),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 13,
    points: [
      Offset(643, 1301),
      Offset(676, 1300),
      Offset(676, 1343),
      Offset(643, 1344),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 14,
    points: [
      Offset(643, 1346),
      Offset(676, 1346),
      Offset(675, 1387),
      Offset(643, 1388),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 15,
    points: [
      Offset(678, 1300),
      Offset(711, 1299),
      Offset(711, 1342),
      Offset(678, 1343),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 16,
    points: [
      Offset(678, 1345),
      Offset(710, 1344),
      Offset(710, 1386),
      Offset(677, 1387),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 17,
    points: [
      Offset(713, 1299),
      Offset(747, 1298),
      Offset(746, 1341),
      Offset(712, 1342),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 18,
    points: [
      Offset(712, 1344),
      Offset(745, 1343),
      Offset(744, 1385),
      Offset(712, 1386),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 19,
    points: [
      Offset(748, 1299),
      Offset(782, 1298),
      Offset(780, 1339),
      Offset(747, 1341),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 20,
    points: [
      Offset(747, 1343),
      Offset(780, 1342),
      Offset(778, 1384),
      Offset(746, 1385),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 21,
    points: [
      Offset(783, 1297),
      Offset(811, 1296),
      Offset(820, 1303),
      Offset(823, 1328),
      Offset(783, 1329),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 22,
    points: [
      Offset(782, 1331),
      Offset(823, 1330),
      Offset(826, 1355),
      Offset(781, 1356),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 23,
    points: [
      Offset(781, 1359),
      Offset(826, 1358),
      Offset(828, 1375),
      Offset(822, 1382),
      Offset(779, 1384),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 24,
    points: [
      Offset(641, 1258),
      Offset(697, 1276),
      Offset(697, 1288),
      Offset(641, 1290),
      Offset(632, 1283),
      Offset(632, 1272),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 25,
    points: [
      Offset(656, 1231),
      Offset(706, 1259),
      Offset(698, 1274),
      Offset(641, 1257),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 26,
    points: [
      Offset(669, 1207),
      Offset(723, 1228),
      Offset(707, 1257),
      Offset(656, 1229),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 27,
    points: [
      Offset(690, 1183),
      Offset(724, 1183),
      Offset(724, 1227),
      Offset(670, 1206),
      Offset(680, 1188),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 28,
    points: [
      Offset(725, 1182),
      Offset(760, 1182),
      Offset(759, 1226),
      Offset(725, 1227),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 29,
    points: [
      Offset(725, 1228),
      Offset(740, 1228),
      Offset(740, 1274),
      Offset(730, 1296),
      Offset(698, 1298),
      Offset(698, 1275),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 30,
    points: [
      Offset(742, 1228),
      Offset(760, 1228),
      Offset(777, 1230),
      Offset(775, 1273),
      Offset(741, 1273),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 31,
    points: [
      Offset(761, 1182),
      Offset(778, 1184),
      Offset(811, 1222),
      Offset(778, 1229),
      Offset(760, 1227),
    ],
  ),
  LotPolygon(
    block: 'Block 4',
    lotNumber: 32,
    points: [
      Offset(778, 1230),
      Offset(811, 1224),
      Offset(816, 1264),
      Offset(809, 1272),
      Offset(776, 1273),
    ],
  ),
];

const List<LotPolygon> block5LotPolygons = [
  LotPolygon(
    block: 'Block 5',
    lotNumber: 1,
    points: [
      Offset(442, 1156),
      Offset(477, 1161),
      Offset(481, 1192),
      Offset(437, 1204),
      Offset(431, 1164),
    ],
  ),
  LotPolygon(
    block: 'Block 5',
    lotNumber: 2,
    points: [
      Offset(478, 1161),
      Offset(516, 1163),
      Offset(523, 1168),
      Offset(524, 1189),
      Offset(483, 1199),
    ],
  ),
  LotPolygon(
    block: 'Block 5',
    lotNumber: 3,
    points: [
      Offset(437, 1206),
      Offset(480, 1194),
      Offset(485, 1228),
      Offset(442, 1238),
    ],
  ),
  LotPolygon(
    block: 'Block 5',
    lotNumber: 4,
    points: [
      Offset(483, 1201),
      Offset(525, 1191),
      Offset(527, 1229),
      Offset(487, 1229),
    ],
  ),
  LotPolygon(
    block: 'Block 5',
    lotNumber: 5,
    points: [
      Offset(442, 1241),
      Offset(485, 1231),
      Offset(485, 1275),
      Offset(452, 1275),
      Offset(445, 1270),
    ],
  ),
  LotPolygon(
    block: 'Block 5',
    lotNumber: 6,
    points: [
      Offset(486, 1231),
      Offset(520, 1231),
      Offset(520, 1276),
      Offset(487, 1275),
    ],
  ),
  LotPolygon(
    block: 'Block 5',
    lotNumber: 7,
    points: [
      Offset(518, 1163),
      Offset(579, 1167),
      Offset(580, 1198),
      Offset(527, 1197),
      Offset(524, 1168),
    ],
  ),
  LotPolygon(
    block: 'Block 5',
    lotNumber: 8,
    points: [
      Offset(527, 1200),
      Offset(580, 1199),
      Offset(580, 1228),
      Offset(530, 1228),
    ],
  ),
  LotPolygon(
    block: 'Block 5',
    lotNumber: 9,
    points: [
      Offset(522, 1231),
      Offset(555, 1231),
      Offset(555, 1276),
      Offset(522, 1276),
    ],
  ),
  LotPolygon(
    block: 'Block 5',
    lotNumber: 10,
    points: [
      Offset(557, 1231),
      Offset(591, 1231),
      Offset(591, 1276),
      Offset(557, 1276),
    ],
  ),
  LotPolygon(
    block: 'Block 5',
    lotNumber: 11,
    points: [
      Offset(581, 1167),
      Offset(614, 1169),
      Offset(608, 1211),
      Offset(591, 1229),
      Offset(582, 1229),
    ],
  ),
  LotPolygon(
    block: 'Block 5',
    lotNumber: 12,
    points: [
      Offset(592, 1230),
      Offset(609, 1213),
      Offset(634, 1226),
      Offset(612, 1269),
      Offset(601, 1276),
      Offset(592, 1277),
    ],
  ),
  LotPolygon(
    block: 'Block 5',
    lotNumber: 13,
    points: [
      Offset(616, 1171),
      Offset(621, 1170),
      Offset(651, 1175),
      Offset(657, 1181),
      Offset(657, 1186),
      Offset(635, 1225),
      Offset(609, 1212),
    ],
  ),
];

// Block 6
const List<LotPolygon> block6LotPolygons = [
  LotPolygon(
    block: 'Block 6',
    lotNumber: 1,
    points: [
      Offset(420, 1035),
      Offset(449, 1039),
      Offset(437, 1131),
      Offset(431, 1131),
      Offset(423, 1123),
      Offset(413, 1044),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 2,
    points: [
      Offset(450, 1039),
      Offset(485, 1044),
      Offset(479, 1091),
      Offset(444, 1086),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 3,
    points: [
      Offset(445, 1088),
      Offset(478, 1092),
      Offset(472, 1135),
      Offset(439, 1131),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 4,
    points: [
      Offset(486, 1045),
      Offset(519, 1049),
      Offset(513, 1095),
      Offset(480, 1091),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 5,
    points: [
      Offset(480, 1092),
      Offset(513, 1096),
      Offset(507, 1139),
      Offset(474, 1136),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 6,
    points: [
      Offset(521, 1050),
      Offset(555, 1054),
      Offset(549, 1099),
      Offset(515, 1095),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 7,
    points: [
      Offset(515, 1097),
      Offset(549, 1100),
      Offset(542, 1142),
      Offset(509, 1139),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 8,
    points: [
      Offset(557, 1054),
      Offset(601, 1058),
      Offset(594, 1102),
      Offset(551, 1099),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 9,
    points: [
      Offset(551, 1100),
      Offset(594, 1103),
      Offset(586, 1145),
      Offset(543, 1142),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 10,
    points: [
      Offset(603, 1059),
      Offset(637, 1062),
      Offset(630, 1105),
      Offset(595, 1102),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 11,
    points: [
      Offset(595, 1104),
      Offset(630, 1106),
      Offset(623, 1148),
      Offset(588, 1145),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 12,
    points: [
      Offset(638, 1063),
      Offset(663, 1065),
      Offset(673, 1073),
      Offset(666, 1106),
      Offset(632, 1105),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 13,
    points: [
      Offset(631, 1107),
      Offset(665, 1108),
      Offset(660, 1152),
      Offset(625, 1148),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 14,
    points: [
      Offset(674, 1074),
      Offset(697, 1097),
      Offset(691, 1156),
      Offset(661, 1153),
      Offset(667, 1107),
    ],
  ),
  LotPolygon(
    block: 'Block 6',
    lotNumber: 15,
    points: [
      Offset(698, 1098),
      Offset(742, 1144),
      Offset(742, 1151),
      Offset(737, 1156),
      Offset(692, 1157),
    ],
  ),
];

// Block 7
const List<LotPolygon> block7LotPolygons = [
  LotPolygon(
    block: 'Block 7',
    lotNumber: 1,
    points: [
      Offset(135, 994),
      Offset(236, 1009),
      Offset(227, 1099),
      Offset(131, 1083),
      Offset(125, 1075),
      Offset(125, 1001),
    ],
  ),
  LotPolygon(
    block: 'Block 7',
    lotNumber: 2,
    points: [
      Offset(238, 1009),
      Offset(272, 1014),
      Offset(268, 1058),
      Offset(233, 1053),
    ],
  ),
  LotPolygon(
    block: 'Block 7',
    lotNumber: 3,
    points: [
      Offset(233, 1054),
      Offset(268, 1060),
      Offset(262, 1105),
      Offset(228, 1099),
    ],
  ),
  LotPolygon(
    block: 'Block 7',
    lotNumber: 4,
    points: [
      Offset(274, 1014),
      Offset(308, 1019),
      Offset(304, 1063),
      Offset(270, 1059),
    ],
  ),
  LotPolygon(
    block: 'Block 7',
    lotNumber: 5,
    points: [
      Offset(269, 1060),
      Offset(304, 1065),
      Offset(301, 1094),
      Offset(291, 1109),
      Offset(265, 1104),
    ],
  ),
  LotPolygon(
    block: 'Block 7',
    lotNumber: 6,
    points: [
      Offset(311, 1019),
      Offset(345, 1025),
      Offset(337, 1081),
      Offset(305, 1064),
    ],
  ),
  LotPolygon(
    block: 'Block 7',
    lotNumber: 7,
    points: [
      Offset(305, 1066),
      Offset(346, 1089),
      Offset(322, 1128),
      Offset(293, 1109),
      Offset(302, 1095),
    ],
  ),
  LotPolygon(
    block: 'Block 7',
    lotNumber: 8,
    points: [
      Offset(346, 1026),
      Offset(380, 1030),
      Offset(388, 1038),
      Offset(393, 1069),
      Offset(342, 1061),
    ],
  ),
  LotPolygon(
    block: 'Block 7',
    lotNumber: 9,
    points: [
      Offset(342, 1063),
      Offset(393, 1072),
      Offset(398, 1106),
      Offset(368, 1101),
      Offset(339, 1082),
    ],
  ),
  LotPolygon(
    block: 'Block 7',
    lotNumber: 10,
    points: [
      Offset(348, 1090),
      Offset(367, 1103),
      Offset(361, 1145),
      Offset(343, 1142),
      Offset(324, 1129),
    ],
  ),
  LotPolygon(
    block: 'Block 7',
    lotNumber: 11,
    points: [
      Offset(369, 1103),
      Offset(398, 1108),
      Offset(404, 1145),
      Offset(398, 1151),
      Offset(364, 1145),
    ],
  ),
];

// Block 8
const List<LotPolygon> block8LotPolygons = [
  LotPolygon(
    block: 'Block 8',
    lotNumber: 1,
    points: [
      Offset(338, 1280),
      Offset(361, 1286),
      Offset(359, 1313),
      Offset(327, 1310),
      Offset(328, 1286),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 2,
    points: [
      Offset(362, 1286),
      Offset(403, 1301),
      Offset(408, 1310),
      Offset(407, 1319),
      Offset(361, 1313),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 3,
    points: [
      Offset(327, 1312),
      Offset(366, 1316),
      Offset(364, 1353),
      Offset(324, 1348),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 4,
    points: [
      Offset(368, 1317),
      Offset(407, 1321),
      Offset(405, 1357),
      Offset(366, 1353),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 5,
    points: [
      Offset(324, 1351),
      Offset(364, 1355),
      Offset(361, 1391),
      Offset(322, 1387),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 6,
    points: [
      Offset(366, 1355),
      Offset(405, 1359),
      Offset(403, 1395),
      Offset(363, 1391),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 7,
    points: [
      Offset(322, 1389),
      Offset(361, 1393),
      Offset(359, 1427),
      Offset(320, 1424),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 8,
    points: [
      Offset(363, 1393),
      Offset(402, 1397),
      Offset(400, 1432),
      Offset(361, 1428),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 9,
    points: [
      Offset(320, 1426),
      Offset(358, 1429),
      Offset(357, 1464),
      Offset(318, 1460),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 10,
    points: [
      Offset(361, 1430),
      Offset(400, 1434),
      Offset(398, 1467),
      Offset(359, 1463),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 11,
    points: [
      Offset(317, 1463),
      Offset(356, 1466),
      Offset(354, 1500),
      Offset(315, 1497),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 12,
    points: [
      Offset(358, 1466),
      Offset(397, 1469),
      Offset(396, 1503),
      Offset(356, 1500),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 13,
    points: [
      Offset(315, 1499),
      Offset(354, 1503),
      Offset(352, 1535),
      Offset(313, 1532),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 14,
    points: [
      Offset(356, 1502),
      Offset(395, 1505),
      Offset(393, 1537),
      Offset(354, 1535),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 15,
    points: [
      Offset(312, 1534),
      Offset(352, 1537),
      Offset(349, 1571),
      Offset(317, 1569),
      Offset(310, 1562),
    ],
  ),
  LotPolygon(
    block: 'Block 8',
    lotNumber: 16,
    points: [
      Offset(354, 1537),
      Offset(392, 1540),
      Offset(390, 1567),
      Offset(383, 1574),
      Offset(351, 1572),
    ],
  ),
];

// Block 9
const List<LotPolygon> block9LotPolygons = [
  LotPolygon(
    block: 'Block 9',
    lotNumber: 1,
    points: [
      Offset(234, 1226),
      Offset(302, 1266),
      Offset(306, 1277),
      Offset(295, 1440),
      Offset(214, 1431),
      Offset(225, 1232),
    ],
  ),
  LotPolygon(
    block: 'Block 9',
    lotNumber: 2,
    points: [
      Offset(214, 1432),
      Offset(253, 1436),
      Offset(251, 1471),
      Offset(212, 1467),
    ],
  ),
  LotPolygon(
    block: 'Block 9',
    lotNumber: 3,
    points: [
      Offset(255, 1436),
      Offset(294, 1441),
      Offset(293, 1476),
      Offset(253, 1471),
    ],
  ),
  LotPolygon(
    block: 'Block 9',
    lotNumber: 4,
    points: [
      Offset(212, 1469),
      Offset(251, 1473),
      Offset(249, 1507),
      Offset(211, 1503),
    ],
  ),
  LotPolygon(
    block: 'Block 9',
    lotNumber: 5,
    points: [
      Offset(253, 1473),
      Offset(292, 1478),
      Offset(290, 1512),
      Offset(251, 1508),
    ],
  ),
  LotPolygon(
    block: 'Block 9',
    lotNumber: 6,
    points: [
      Offset(211, 1505),
      Offset(249, 1510),
      Offset(247, 1543),
      Offset(209, 1539),
    ],
  ),
  LotPolygon(
    block: 'Block 9',
    lotNumber: 7,
    points: [
      Offset(251, 1510),
      Offset(290, 1514),
      Offset(288, 1548),
      Offset(249, 1544),
    ],
  ),
  LotPolygon(
    block: 'Block 9',
    lotNumber: 8,
    points: [
      Offset(209, 1540),
      Offset(247, 1545),
      Offset(245, 1578),
      Offset(208, 1573),
    ],
  ),
  LotPolygon(
    block: 'Block 9',
    lotNumber: 9,
    points: [
      Offset(249, 1545),
      Offset(288, 1551),
      Offset(285, 1582),
      Offset(247, 1578),
    ],
  ),
  LotPolygon(
    block: 'Block 9',
    lotNumber: 10,
    points: [
      Offset(208, 1574),
      Offset(245, 1580),
      Offset(243, 1610),
      Offset(210, 1608),
      Offset(206, 1588),
    ],
  ),
  LotPolygon(
    block: 'Block 9',
    lotNumber: 11,
    points: [
      Offset(247, 1580),
      Offset(285, 1584),
      Offset(283, 1604),
      Offset(276, 1611),
      Offset(245, 1610),
    ],
  ),
  LotPolygon(
    block: 'Block 9',
    lotNumber: 12,
    points: [
      Offset(182, 1582),
      Offset(199, 1583),
      Offset(205, 1587),
      Offset(209, 1609),
      Offset(203, 1614),
      Offset(174, 1613),
      Offset(170, 1609),
      Offset(173, 1591),
    ],
  ),
];
const List<LotPolygon> block10LotPolygons = [
  LotPolygon(
    block: 'Block 10',
    lotNumber: 1,
    points: [
      Offset(136, 1163),
      Offset(198, 1203),
      Offset(203, 1212),
      Offset(127, 1205),
      Offset(128, 1169),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 2,
    points: [
      Offset(126, 1206),
      Offset(164, 1210),
      Offset(162, 1249),
      Offset(124, 1245),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 3,
    points: [
      Offset(165, 1210),
      Offset(203, 1214),
      Offset(201, 1253),
      Offset(163, 1249),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 4,
    points: [
      Offset(124, 1246),
      Offset(162, 1250),
      Offset(160, 1288),
      Offset(123, 1285),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 5,
    points: [
      Offset(163, 1251),
      Offset(201, 1255),
      Offset(198, 1292),
      Offset(162, 1289),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 6,
    points: [
      Offset(122, 1287),
      Offset(160, 1290),
      Offset(158, 1328),
      Offset(121, 1325),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 7,
    points: [
      Offset(162, 1291),
      Offset(199, 1294),
      Offset(197, 1332),
      Offset(160, 1328),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 8,
    points: [
      Offset(121, 1327),
      Offset(158, 1330),
      Offset(156, 1367),
      Offset(119, 1363),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 9,
    points: [
      Offset(160, 1330),
      Offset(196, 1334),
      Offset(195, 1370),
      Offset(158, 1367),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 10,
    points: [
      Offset(119, 1365),
      Offset(156, 1369),
      Offset(154, 1405),
      Offset(119, 1400),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 11,
    points: [
      Offset(158, 1369),
      Offset(195, 1372),
      Offset(193, 1408),
      Offset(156, 1405),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 12,
    points: [
      Offset(118, 1402),
      Offset(154, 1406),
      Offset(153, 1443),
      Offset(138, 1442),
      Offset(117, 1421),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 13,
    points: [
      Offset(156, 1406),
      Offset(193, 1410),
      Offset(191, 1449),
      Offset(154, 1444),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 14,
    points: [
      Offset(122, 1443),
      Offset(152, 1445),
      Offset(152, 1484),
      Offset(115, 1483),
      Offset(116, 1447),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 15,
    points: [
      Offset(154, 1446),
      Offset(190, 1451),
      Offset(189, 1487),
      Offset(153, 1485),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 16,
    points: [
      Offset(115, 1484),
      Offset(152, 1487),
      Offset(151, 1526),
      Offset(114, 1524),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 17,
    points: [
      Offset(153, 1486),
      Offset(189, 1489),
      Offset(188, 1527),
      Offset(152, 1526),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 18,
    points: [
      Offset(114, 1526),
      Offset(151, 1528),
      Offset(150, 1570),
      Offset(113, 1567),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 19,
    points: [
      Offset(152, 1528),
      Offset(187, 1529),
      Offset(187, 1559),
      Offset(182, 1562),
      Offset(172, 1563),
      Offset(160, 1573),
      Offset(151, 1571),
    ],
  ),
  LotPolygon(
    block: 'Block 10',
    lotNumber: 20,
    points: [
      Offset(113, 1569),
      Offset(150, 1572),
      Offset(159, 1575),
      Offset(151, 1581),
      Offset(149, 1595),
      Offset(141, 1602),
      Offset(120, 1602),
      Offset(112, 1594),
    ],
  ),
];

// ==================== Block 11 ====================
const List<LotPolygon> block11LotPolygons = [
  LotPolygon(
    block: 'Block 11',
    lotNumber: 1,
    points: [
      Offset(66, 1620),
      Offset(74, 1620),
      Offset(78, 1618),
      Offset(95, 1619),
      Offset(101, 1624),
      Offset(101, 1664),
      Offset(64, 1664),
    ],
  ),
  LotPolygon(
    block: 'Block 11',
    lotNumber: 2,
    points: [
      Offset(35, 1606),
      Offset(65, 1608),
      Offset(62, 1663),
      Offset(34, 1662),
    ],
  ),
  LotPolygon(
    block: 'Block 11',
    lotNumber: 3,
    points: [
      Offset(37, 1565),
      Offset(80, 1567),
      Offset(80, 1595),
      Offset(66, 1607),
      Offset(36, 1605),
    ],
  ),
  LotPolygon(
    block: 'Block 11',
    lotNumber: 4,
    points: [
      Offset(39, 1522),
      Offset(81, 1525),
      Offset(80, 1565),
      Offset(37, 1563),
    ],
  ),
  LotPolygon(
    block: 'Block 11',
    lotNumber: 5,
    points: [
      Offset(39, 1481),
      Offset(83, 1483),
      Offset(81, 1522),
      Offset(38, 1520),
    ],
  ),
  LotPolygon(
    block: 'Block 11',
    lotNumber: 6,
    points: [
      Offset(41, 1439),
      Offset(83, 1441),
      Offset(82, 1481),
      Offset(40, 1478),
    ],
  ),
  LotPolygon(
    block: 'Block 11',
    lotNumber: 7,
    points: [
      Offset(42, 1397),
      Offset(85, 1400),
      Offset(84, 1439),
      Offset(41, 1437),
    ],
  ),
  LotPolygon(
    block: 'Block 11',
    lotNumber: 8,
    points: [
      Offset(44, 1356),
      Offset(86, 1358),
      Offset(85, 1398),
      Offset(43, 1396),
    ],
  ),
  LotPolygon(
    block: 'Block 11',
    lotNumber: 9,
    points: [
      Offset(45, 1311),
      Offset(88, 1313),
      Offset(86, 1356),
      Offset(44, 1354),
    ],
  ),
  LotPolygon(
    block: 'Block 11',
    lotNumber: 10,
    points: [
      Offset(46, 1272),
      Offset(89, 1273),
      Offset(88, 1311),
      Offset(45, 1309),
    ],
  ),
  LotPolygon(
    block: 'Block 11',
    lotNumber: 11,
    points: [
      Offset(47, 1232),
      Offset(90, 1234),
      Offset(89, 1271),
      Offset(46, 1270),
    ],
  ),
  LotPolygon(
    block: 'Block 11',
    lotNumber: 12,
    points: [
      Offset(48, 1193),
      Offset(81, 1194),
      Offset(90, 1203),
      Offset(90, 1232),
      Offset(48, 1230),
    ],
  ),
];

// ==================== Block 12 ====================
const List<LotPolygon> block12LotPolygons = [
  LotPolygon(
    block: 'Block 12',
    lotNumber: 1,
    points: [
      Offset(51, 1110),
      Offset(93, 1113),
      Offset(92, 1149),
      Offset(83, 1156),
      Offset(49, 1154),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 2,
    points: [
      Offset(52, 1067),
      Offset(94, 1071),
      Offset(93, 1112),
      Offset(51, 1108),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 3,
    points: [
      Offset(53, 1028),
      Offset(95, 1033),
      Offset(94, 1069),
      Offset(52, 1065),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 4,
    points: [
      Offset(53, 989),
      Offset(97, 994),
      Offset(96, 1031),
      Offset(53, 1027),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 5,
    points: [
      Offset(55, 951),
      Offset(97, 955),
      Offset(96, 992),
      Offset(54, 987),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 6,
    points: [
      Offset(56, 911),
      Offset(99, 915),
      Offset(98, 953),
      Offset(55, 949),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 7,
    points: [
      Offset(57, 870),
      Offset(100, 874),
      Offset(99, 913),
      Offset(56, 908),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 8,
    points: [
      Offset(58, 830),
      Offset(102, 833),
      Offset(100, 872),
      Offset(57, 868),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 9,
    points: [
      Offset(59, 788),
      Offset(104, 793),
      Offset(102, 831),
      Offset(58, 828),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 10,
    points: [
      Offset(60, 747),
      Offset(105, 750),
      Offset(104, 791),
      Offset(59, 787),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 11,
    points: [
      Offset(61, 705),
      Offset(106, 708),
      Offset(105, 749),
      Offset(60, 746),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 12,
    points: [
      Offset(63, 663),
      Offset(108, 666),
      Offset(106, 707),
      Offset(61, 703),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 13,
    points: [
      Offset(65, 620),
      Offset(110, 623),
      Offset(108, 664),
      Offset(63, 661),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 14,
    points: [
      Offset(66, 575),
      Offset(112, 579),
      Offset(110, 621),
      Offset(64, 618),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 15,
    points: [
      Offset(67, 532),
      Offset(114, 535),
      Offset(112, 577),
      Offset(66, 574),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 16,
    points: [
      Offset(69, 489),
      Offset(116, 492),
      Offset(114, 534),
      Offset(68, 531),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 17,
    points: [
      Offset(71, 445),
      Offset(118, 448),
      Offset(116, 491),
      Offset(69, 487),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 18,
    points: [
      Offset(72, 400),
      Offset(120, 403),
      Offset(118, 447),
      Offset(71, 443),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 19,
    points: [
      Offset(74, 354),
      Offset(122, 357),
      Offset(120, 402),
      Offset(73, 398),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 20,
    points: [
      Offset(76, 306),
      Offset(123, 310),
      Offset(122, 355),
      Offset(74, 352),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 21,
    points: [
      Offset(78, 257),
      Offset(126, 260),
      Offset(124, 308),
      Offset(76, 304),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 22,
    points: [
      Offset(80, 208),
      Offset(128, 212),
      Offset(126, 258),
      Offset(78, 255),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 23,
    points: [
      Offset(82, 160),
      Offset(130, 164),
      Offset(128, 210),
      Offset(80, 207),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 24,
    points: [
      Offset(84, 112),
      Offset(132, 116),
      Offset(130, 162),
      Offset(82, 159),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 25,
    points: [
      Offset(86, 41),
      Offset(135, 43),
      Offset(132, 105),
      Offset(85, 101),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 26,
    points: [
      Offset(136, 42),
      Offset(182, 44),
      Offset(193, 54),
      Offset(166, 101),
      Offset(134, 89),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 27,
    points: [
      Offset(194, 56),
      Offset(227, 83),
      Offset(199, 129),
      Offset(167, 102),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 28,
    points: [
      Offset(227, 84),
      Offset(260, 111),
      Offset(232, 157),
      Offset(200, 130),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 29,
    points: [
      Offset(261, 113),
      Offset(293, 140),
      Offset(266, 186),
      Offset(234, 159),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 30,
    points: [
      Offset(294, 141),
      Offset(326, 168),
      Offset(299, 214),
      Offset(267, 187),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 31,
    points: [
      Offset(328, 170),
      Offset(359, 197),
      Offset(331, 242),
      Offset(300, 215),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 32,
    points: [
      Offset(360, 198),
      Offset(392, 225),
      Offset(364, 270),
      Offset(332, 243),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 33,
    points: [
      Offset(393, 226),
      Offset(424, 252),
      Offset(396, 296),
      Offset(365, 271),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 34,
    points: [
      Offset(425, 253),
      Offset(454, 277),
      Offset(426, 321),
      Offset(397, 297),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 35,
    points: [
      Offset(455, 279),
      Offset(486, 304),
      Offset(458, 347),
      Offset(428, 323),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 36,
    points: [
      Offset(487, 305),
      Offset(518, 331),
      Offset(490, 375),
      Offset(459, 348),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 37,
    points: [
      Offset(519, 332),
      Offset(551, 359),
      Offset(523, 402),
      Offset(492, 376),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 38,
    points: [
      Offset(552, 360),
      Offset(584, 387),
      Offset(556, 430),
      Offset(525, 404),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 39,
    points: [
      Offset(585, 388),
      Offset(616, 415),
      Offset(589, 458),
      Offset(558, 431),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 40,
    points: [
      Offset(617, 416),
      Offset(649, 443),
      Offset(621, 486),
      Offset(590, 459),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 41,
    points: [
      Offset(650, 445),
      Offset(680, 470),
      Offset(653, 512),
      Offset(623, 487),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 42,
    points: [
      Offset(682, 472),
      Offset(712, 498),
      Offset(685, 539),
      Offset(654, 514),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 43,
    points: [
      Offset(714, 499),
      Offset(743, 525),
      Offset(715, 566),
      Offset(686, 540),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 44,
    points: [
      Offset(744, 526),
      Offset(801, 575),
      Offset(773, 616),
      Offset(717, 567),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 45,
    points: [
      Offset(737, 587),
      Offset(773, 617),
      Offset(749, 652),
      Offset(714, 623),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 46,
    points: [
      Offset(712, 624),
      Offset(748, 653),
      Offset(726, 687),
      Offset(690, 659),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 47,
    points: [
      Offset(690, 661),
      Offset(725, 688),
      Offset(703, 722),
      Offset(667, 695),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 48,
    points: [
      Offset(666, 697),
      Offset(701, 723),
      Offset(680, 757),
      Offset(643, 730),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 49,
    points: [
      Offset(643, 732),
      Offset(679, 759),
      Offset(657, 792),
      Offset(622, 765),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 50,
    points: [
      Offset(621, 767),
      Offset(656, 793),
      Offset(635, 826),
      Offset(599, 800),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 51,
    points: [
      Offset(588, 795),
      Offset(634, 827),
      Offset(617, 854),
      Offset(567, 830),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 52,
    points: [
      Offset(554, 770),
      Offset(585, 784),
      Offset(587, 794),
      Offset(566, 829),
      Offset(535, 814),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 53,
    points: [
      Offset(519, 753),
      Offset(552, 769),
      Offset(534, 814),
      Offset(500, 797),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 54,
    points: [
      Offset(483, 737),
      Offset(518, 753),
      Offset(499, 798),
      Offset(465, 782),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 55,
    points: [
      Offset(447, 720),
      Offset(483, 736),
      Offset(464, 781),
      Offset(430, 764),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 56,
    points: [
      Offset(412, 704),
      Offset(447, 720),
      Offset(429, 764),
      Offset(395, 748),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 57,
    points: [
      Offset(383, 681),
      Offset(412, 704),
      Offset(394, 747),
      Offset(364, 734),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 58,
    points: [
      Offset(348, 652),
      Offset(383, 680),
      Offset(370, 713),
      Offset(327, 693),
      Offset(339, 656),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 59,
    points: [
      Offset(327, 694),
      Offset(370, 713),
      Offset(362, 734),
      Offset(356, 752),
      Offset(315, 732),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 60,
    points: [
      Offset(314, 733),
      Offset(356, 753),
      Offset(343, 792),
      Offset(309, 777),
      Offset(304, 766),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 61,
    points: [
      Offset(298, 602),
      Offset(329, 627),
      Offset(334, 640),
      Offset(313, 698),
      Offset(323, 703),
      Offset(303, 764),
      Offset(305, 769),
      Offset(270, 787),
      Offset(246, 859),
      Offset(252, 743),
      Offset(288, 746),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 62,
    points: [
      Offset(255, 692),
      Offset(291, 695),
      Offset(288, 745),
      Offset(252, 742),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 63,
    points: [
      Offset(258, 640),
      Offset(294, 643),
      Offset(291, 693),
      Offset(255, 690),
    ],
  ),
  LotPolygon(
    block: 'Block 12',
    lotNumber: 64,
    points: [
      Offset(269, 579),
      Offset(297, 601),
      Offset(295, 641),
      Offset(258, 639),
      Offset(260, 583),
    ],
  ),
];

// ==================== Block 13 ====================
const List<LotPolygon> block13LotPolygons = [
  LotPolygon(
    block: 'Block 13',
    lotNumber: 1,
    points: [
      Offset(162, 327),
      Offset(168, 327),
      Offset(199, 355),
      Offset(198, 377),
      Offset(153, 374),
      Offset(155, 333),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 2,
    points: [
      Offset(153, 376),
      Offset(198, 379),
      Offset(195, 421),
      Offset(151, 419),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 3,
    points: [
      Offset(201, 356),
      Offset(236, 386),
      Offset(242, 398),
      Offset(241, 424),
      Offset(197, 422),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 4,
    points: [
      Offset(151, 420),
      Offset(195, 423),
      Offset(193, 465),
      Offset(149, 462),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 5,
    points: [
      Offset(197, 424),
      Offset(240, 427),
      Offset(239, 468),
      Offset(194, 465),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 6,
    points: [
      Offset(149, 463),
      Offset(193, 466),
      Offset(191, 508),
      Offset(147, 505),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 7,
    points: [
      Offset(194, 467),
      Offset(239, 470),
      Offset(237, 512),
      Offset(192, 509),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 8,
    points: [
      Offset(147, 507),
      Offset(191, 510),
      Offset(189, 553),
      Offset(145, 550),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 9,
    points: [
      Offset(192, 510),
      Offset(237, 514),
      Offset(235, 557),
      Offset(190, 553),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 10,
    points: [
      Offset(145, 551),
      Offset(189, 555),
      Offset(187, 597),
      Offset(143, 594),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 11,
    points: [
      Offset(190, 555),
      Offset(235, 558),
      Offset(234, 601),
      Offset(188, 597),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 12,
    points: [
      Offset(143, 595),
      Offset(187, 598),
      Offset(185, 640),
      Offset(141, 637),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 13,
    points: [
      Offset(188, 598),
      Offset(233, 602),
      Offset(232, 645),
      Offset(186, 641),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 14,
    points: [
      Offset(141, 639),
      Offset(185, 642),
      Offset(183, 684),
      Offset(139, 681),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 15,
    points: [
      Offset(187, 642),
      Offset(231, 646),
      Offset(230, 688),
      Offset(184, 685),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 16,
    points: [
      Offset(139, 682),
      Offset(182, 686),
      Offset(181, 727),
      Offset(137, 724),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 17,
    points: [
      Offset(185, 686),
      Offset(229, 690),
      Offset(228, 731),
      Offset(183, 727),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 18,
    points: [
      Offset(137, 726),
      Offset(181, 729),
      Offset(180, 769),
      Offset(135, 765),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 19,
    points: [
      Offset(183, 730),
      Offset(227, 733),
      Offset(226, 773),
      Offset(181, 769),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 20,
    points: [
      Offset(135, 767),
      Offset(179, 771),
      Offset(178, 810),
      Offset(134, 806),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 21,
    points: [
      Offset(181, 771),
      Offset(225, 775),
      Offset(223, 814),
      Offset(180, 810),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 22,
    points: [
      Offset(134, 808),
      Offset(178, 812),
      Offset(175, 851),
      Offset(132, 848),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 23,
    points: [
      Offset(180, 812),
      Offset(224, 816),
      Offset(222, 856),
      Offset(177, 852),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 24,
    points: [
      Offset(132, 849),
      Offset(176, 853),
      Offset(174, 892),
      Offset(131, 888),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 25,
    points: [
      Offset(178, 854),
      Offset(221, 858),
      Offset(219, 896),
      Offset(176, 892),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 26,
    points: [
      Offset(130, 890),
      Offset(174, 894),
      Offset(172, 932),
      Offset(129, 928),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 27,
    points: [
      Offset(175, 894),
      Offset(219, 898),
      Offset(218, 931),
      Offset(215, 937),
      Offset(173, 933),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 28,
    points: [
      Offset(130, 930),
      Offset(172, 934),
      Offset(170, 967),
      Offset(134, 963),
      Offset(128, 953),
    ],
  ),
  LotPolygon(
    block: 'Block 13',
    lotNumber: 29,
    points: [
      Offset(173, 934),
      Offset(215, 939),
      Offset(208, 964),
      Offset(198, 971),
      Offset(171, 968),
    ],
  ),
];

// ==================== Block 14 ====================
const List<LotPolygon> block14LotPolygons = [
  LotPolygon(
    block: 'Block 14',
    lotNumber: 1,
    points: [
      Offset(278, 419),
      Offset(309, 444),
      Offset(283, 487),
      Offset(266, 475),
      Offset(268, 425),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 2,
    points: [
      Offset(310, 445),
      Offset(341, 470),
      Offset(314, 513),
      Offset(284, 488),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 3,
    points: [
      Offset(265, 475),
      Offset(313, 515),
      Offset(288, 555),
      Offset(269, 540),
      Offset(263, 530),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 4,
    points: [
      Offset(342, 472),
      Offset(373, 497),
      Offset(347, 539),
      Offset(316, 514),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 5,
    points: [
      Offset(315, 516),
      Offset(346, 541),
      Offset(320, 582),
      Offset(290, 557),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 6,
    points: [
      Offset(374, 499),
      Offset(406, 524),
      Offset(379, 566),
      Offset(349, 540),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 7,
    points: [
      Offset(347, 542),
      Offset(378, 568),
      Offset(352, 609),
      Offset(322, 583),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 8,
    points: [
      Offset(407, 526),
      Offset(436, 552),
      Offset(411, 592),
      Offset(381, 567),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 9,
    points: [
      Offset(380, 569),
      Offset(410, 594),
      Offset(383, 635),
      Offset(354, 610),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 10,
    points: [
      Offset(439, 553),
      Offset(469, 577),
      Offset(443, 619),
      Offset(413, 594),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 11,
    points: [
      Offset(411, 595),
      Offset(442, 621),
      Offset(416, 662),
      Offset(385, 636),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 12,
    points: [
      Offset(471, 579),
      Offset(501, 604),
      Offset(474, 645),
      Offset(444, 620),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 13,
    points: [
      Offset(443, 622),
      Offset(473, 647),
      Offset(451, 682),
      Offset(423, 667),
      Offset(417, 663),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 14,
    points: [
      Offset(502, 606),
      Offset(532, 631),
      Offset(505, 671),
      Offset(476, 647),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 15,
    points: [
      Offset(474, 648),
      Offset(504, 673),
      Offset(488, 698),
      Offset(453, 683),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 16,
    points: [
      Offset(534, 632),
      Offset(563, 656),
      Offset(536, 696),
      Offset(507, 673),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 17,
    points: [
      Offset(505, 674),
      Offset(566, 723),
      Offset(559, 733),
      Offset(506, 706),
      Offset(489, 699),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 18,
    points: [
      Offset(565, 657),
      Offset(594, 682),
      Offset(567, 722),
      Offset(538, 698),
    ],
  ),
  LotPolygon(
    block: 'Block 14',
    lotNumber: 19,
    points: [
      Offset(595, 684),
      Offset(615, 701),
      Offset(617, 711),
      Offset(596, 743),
      Offset(585, 746),
      Offset(561, 734),
    ],
  ),
];

// ==================== Block 15 ====================
const List<LotPolygon> block15LotPolygons = [
  LotPolygon(
    block: 'Block 15',
    lotNumber: 1,
    points: [
      Offset(172, 155),
      Offset(204, 183),
      Offset(178, 228),
      Offset(161, 214),
      Offset(162, 161),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 2,
    points: [
      Offset(160, 216),
      Offset(209, 258),
      Offset(184, 302),
      Offset(163, 285),
      Offset(158, 274),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 3,
    points: [
      Offset(205, 184),
      Offset(237, 211),
      Offset(211, 256),
      Offset(179, 229),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 4,
    points: [
      Offset(211, 259),
      Offset(243, 286),
      Offset(217, 329),
      Offset(186, 303),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 5,
    points: [
      Offset(239, 213),
      Offset(270, 239),
      Offset(244, 284),
      Offset(212, 258),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 6,
    points: [
      Offset(245, 287),
      Offset(275, 314),
      Offset(249, 355),
      Offset(219, 330),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 7,
    points: [
      Offset(272, 241),
      Offset(303, 267),
      Offset(276, 312),
      Offset(245, 286),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 8,
    points: [
      Offset(276, 314),
      Offset(307, 339),
      Offset(279, 381),
      Offset(251, 357),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 9,
    points: [
      Offset(304, 268),
      Offset(335, 295),
      Offset(308, 338),
      Offset(278, 313),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 10,
    points: [
      Offset(308, 340),
      Offset(337, 364),
      Offset(311, 408),
      Offset(281, 383),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 11,
    points: [
      Offset(336, 296),
      Offset(366, 320),
      Offset(339, 362),
      Offset(309, 339),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 12,
    points: [
      Offset(339, 365),
      Offset(371, 391),
      Offset(344, 435),
      Offset(312, 409),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 13,
    points: [
      Offset(367, 322),
      Offset(398, 346),
      Offset(371, 389),
      Offset(340, 363),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 14,
    points: [
      Offset(372, 392),
      Offset(403, 419),
      Offset(377, 462),
      Offset(345, 436),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 15,
    points: [
      Offset(400, 347),
      Offset(431, 373),
      Offset(404, 416),
      Offset(373, 391),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 16,
    points: [
      Offset(405, 420),
      Offset(436, 446),
      Offset(410, 488),
      Offset(379, 463),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 17,
    points: [
      Offset(432, 374),
      Offset(463, 400),
      Offset(437, 445),
      Offset(406, 418),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 18,
    points: [
      Offset(437, 448),
      Offset(468, 473),
      Offset(442, 515),
      Offset(411, 490),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 19,
    points: [
      Offset(464, 402),
      Offset(495, 428),
      Offset(468, 471),
      Offset(439, 445),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 20,
    points: [
      Offset(469, 474),
      Offset(499, 500),
      Offset(473, 542),
      Offset(443, 517),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 21,
    points: [
      Offset(496, 429),
      Offset(527, 455),
      Offset(501, 498),
      Offset(470, 472),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 22,
    points: [
      Offset(501, 501),
      Offset(532, 526),
      Offset(505, 569),
      Offset(475, 543),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 23,
    points: [
      Offset(529, 457),
      Offset(559, 482),
      Offset(532, 525),
      Offset(502, 499),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 24,
    points: [
      Offset(533, 528),
      Offset(563, 554),
      Offset(537, 596),
      Offset(506, 570),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 25,
    points: [
      Offset(561, 484),
      Offset(591, 510),
      Offset(564, 552),
      Offset(534, 526),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 26,
    points: [
      Offset(565, 555),
      Offset(595, 581),
      Offset(568, 622),
      Offset(538, 596),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 27,
    points: [
      Offset(593, 511),
      Offset(624, 537),
      Offset(596, 579),
      Offset(566, 553),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 28,
    points: [
      Offset(597, 582),
      Offset(627, 608),
      Offset(600, 648),
      Offset(569, 623),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 29,
    points: [
      Offset(625, 539),
      Offset(655, 564),
      Offset(628, 606),
      Offset(597, 580),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 30,
    points: [
      Offset(628, 608),
      Offset(664, 639),
      Offset(643, 673),
      Offset(631, 675),
      Offset(601, 649),
    ],
  ),
  LotPolygon(
    block: 'Block 15',
    lotNumber: 31,
    points: [
      Offset(657, 565),
      Offset(686, 590),
      Offset(686, 604),
      Offset(665, 637),
      Offset(629, 607),
    ],
  ),
];

// ==================== Block 16 ====================
const List<LotPolygon> block16LotPolygons = [
  LotPolygon(
    block: 'Block 16',
    lotNumber: 1,
    points: [
      Offset(130, 1110),
      Offset(186, 1118),
      Offset(181, 1163),
      Offset(127, 1128),
      Offset(123, 1121),
      Offset(123, 1114),
    ],
  ),
  LotPolygon(
    block: 'Block 16',
    lotNumber: 2,
    points: [
      Offset(188, 1118),
      Offset(222, 1124),
      Offset(216, 1185),
      Offset(183, 1164),
    ],
  ),
  LotPolygon(
    block: 'Block 16',
    lotNumber: 3,
    points: [
      Offset(224, 1124),
      Offset(265, 1131),
      Offset(253, 1175),
      Offset(236, 1198),
      Offset(218, 1186),
    ],
  ),
  LotPolygon(
    block: 'Block 16',
    lotNumber: 4,
    points: [
      Offset(267, 1131),
      Offset(284, 1133),
      Offset(301, 1144),
      Offset(288, 1180),
      Offset(255, 1175),
    ],
  ),
  LotPolygon(
    block: 'Block 16',
    lotNumber: 5,
    points: [
      Offset(255, 1176),
      Offset(288, 1182),
      Offset(279, 1226),
      Offset(238, 1200),
    ],
  ),
  LotPolygon(
    block: 'Block 16',
    lotNumber: 6,
    points: [
      Offset(303, 1145),
      Offset(337, 1168),
      Offset(326, 1203),
      Offset(290, 1181),
    ],
  ),
  LotPolygon(
    block: 'Block 16',
    lotNumber: 7,
    points: [
      Offset(289, 1182),
      Offset(325, 1205),
      Offset(305, 1241),
      Offset(281, 1226),
    ],
  ),
  LotPolygon(
    block: 'Block 16',
    lotNumber: 8,
    points: [
      Offset(339, 1168),
      Offset(376, 1173),
      Offset(354, 1218),
      Offset(327, 1205),
    ],
  ),
  LotPolygon(
    block: 'Block 16',
    lotNumber: 9,
    points: [
      Offset(326, 1206),
      Offset(354, 1220),
      Offset(340, 1257),
      Offset(325, 1253),
      Offset(306, 1242),
    ],
  ),
  LotPolygon(
    block: 'Block 16',
    lotNumber: 10,
    points: [
      Offset(377, 1174),
      Offset(401, 1177),
      Offset(410, 1185),
      Offset(421, 1271),
      Offset(414, 1278),
      Offset(342, 1257),
      Offset(355, 1219),
    ],
  ),
];

// ================================================================
// LEGEND ROW
// ================================================================

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendRow({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _navy,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// ADD LOT DIALOG
// ================================================================

class AddLotDialog extends StatefulWidget {
  final String phase;
  final String block;
  final String lotNumber;

  final double? mapX;
  final double? mapY;

  final String currentUserId;

  final Future<List<MapEntry<String, String>>>
      Function() loadAssignableMembers;

  const AddLotDialog({
    super.key,
    required this.phase,
    required this.block,
    required this.lotNumber,
    required this.currentUserId,
    required this.loadAssignableMembers,
    this.mapX,
    this.mapY,
  });

  @override
  State<AddLotDialog> createState() =>
      _AddLotDialogState();
}

class _AddLotDialogState
    extends State<AddLotDialog> {
  final LotService _service =
      LotService();

  final _formKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _phaseController;

  late final TextEditingController
      _blockController;

  late final TextEditingController
      _lotController;

  late final TextEditingController
      _areaController;

  late final TextEditingController
      _notesController;

  late final TextEditingController
      _contactController;

  late final TextEditingController
      _priceController;

  LotStatus _status = LotStatus.vacant;
  String? _selectedUid;
  String? _selectedOwnerName;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _phaseController =
        TextEditingController(
      text: widget.phase,
    );

    _blockController =
        TextEditingController(
      text: widget.block,
    );

    _lotController =
        TextEditingController(
      text: widget.lotNumber,
    );

    _areaController =
        TextEditingController();

    _notesController =
        TextEditingController();

    _contactController =
        TextEditingController();

    _priceController =
        TextEditingController();
  }

  @override
  void dispose() {
    _phaseController.dispose();
    _blockController.dispose();
    _lotController.dispose();
    _areaController.dispose();
    _notesController.dispose();
    _contactController.dispose();
    _priceController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.add_location_alt_outlined,
            color: _blue,
          ),
          SizedBox(width: 10),
          Text('Add Lot'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _textField(
                        controller:
                            _phaseController,
                        label: 'Phase',
                        hint: 'Phase 1',
                        icon:
                            Icons.layers_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _textField(
                        controller:
                            _blockController,
                        label: 'Block',
                        hint: 'Block 1',
                        icon:
                            Icons.grid_view_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _textField(
                  controller:
                      _lotController,
                  label: 'Lot Number',
                  hint: '1 - 59',
                  icon: Icons.tag,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Lot number is required';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                _textField(
                  controller:
                      _areaController,
                  label: 'Lot Area (sqm)',
                  hint: 'Optional',
                  icon: Icons.square_foot,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                ),

                const SizedBox(height: 18),

                Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<LotStatus>(
                  initialValue: _status,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.flag_outlined,
                      size: 19,
                    ),
                    filled: true,
                    fillColor:
                        const Color(0xFFF8F9FB),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E4E8),
                      ),
                    ),
                    enabledBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E4E8),
                      ),
                    ),
                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                      borderSide: const BorderSide(
                        color: _blue,
                        width: 1.5,
                      ),
                    ),
                    contentPadding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 13,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: LotStatus.vacant,
                      child: _statusMenuLabel(
                        'Vacant',
                        Icons.circle_outlined,
                        _blue,
                      ),
                    ),
                    DropdownMenuItem(
                      value: LotStatus.occupied,
                      child: _statusMenuLabel(
                        'Occupied',
                        Icons.home_work_outlined,
                        _green,
                      ),
                    ),
                    DropdownMenuItem(
                      value: LotStatus.forSale,
                      child: _statusMenuLabel(
                        'For Sale',
                        Icons.sell_outlined,
                        _orange,
                      ),
                    ),
                    DropdownMenuItem(
                      value: LotStatus.reserved,
                      child: _statusMenuLabel(
                        'Reserved',
                        Icons.lock_clock,
                        _purple,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _status = value;

                      if (_status !=
                          LotStatus.occupied) {
                        _selectedUid = null;
                        _selectedOwnerName = null;
                      }
                    });
                  },
                ),

                if (_status ==
                    LotStatus.occupied) ...[
                  const SizedBox(height: 14),

                  if (_selectedOwnerName != null)
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _green
                            .withOpacity(0.08),
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                        border: Border.all(
                          color: _green
                              .withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 18,
                            color: _green,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              _selectedOwnerName!,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight
                                        .w600,
                                color: _navy,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedUid =
                                    null;
                                _selectedOwnerName =
                                    null;
                              });
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : _openAssignOwner,
                        icon: const Icon(
                          Icons.person_add_alt_1,
                        ),
                        label: const Text(
                          'Assign Existing Member',
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  _textField(
                    controller:
                        _contactController,
                    label: 'Contact Number',
                    hint: 'Optional',
                    icon: Icons.phone_outlined,
                  ),
                ],

                if (_status ==
                    LotStatus.forSale) ...[
                  const SizedBox(height: 14),

                  _textField(
                    controller:
                        _priceController,
                    label: 'Price',
                    hint: 'Enter selling price',
                    icon:
                        Icons.payments_outlined,
                    keyboardType:
                        const TextInputType
                            .numberWithOptions(
                      decimal: true,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _textField(
                    controller:
                        _contactController,
                    label: 'Contact Number',
                    hint: 'Optional',
                    icon: Icons.phone_outlined,
                  ),
                ],

                if (_status ==
                    LotStatus.reserved) ...[
                  const SizedBox(height: 14),

                  _textField(
                    controller:
                        _contactController,
                    label: 'Contact Number',
                    hint: 'Optional',
                    icon: Icons.phone_outlined,
                  ),
                ],

                const SizedBox(height: 18),

                _textField(
                  controller:
                      _notesController,
                  label: 'Notes',
                  hint: 'Optional notes',
                  icon:
                      Icons.notes_outlined,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  Navigator.of(context)
                      .pop();
                },
          child:
              const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed:
              _saving
                  ? null
                  : _createLot,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.add,
                ),
          label: Text(
            _saving
                ? 'Creating...'
                : 'Create Lot',
          ),
        ),
      ],
    );
  }

  Widget _statusMenuLabel(
    String label,
    IconData icon,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  Future<void> _openAssignOwner() async {
    setState(() {
      _saving = true;
    });

    try {
      final members =
          await widget.loadAssignableMembers();

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      if (members.isEmpty) {
        _showError(
          'No members are available to assign.',
        );
        return;
      }

      String query = '';

      final selected = await showDialog<MapEntry<String, String>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              dialogContext,
              setDialogState,
            ) {
              final filtered =
                  members.where((member) {
                return member.value
                    .toLowerCase()
                    .contains(
                      query.toLowerCase(),
                    );
              }).toList();

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                title: const Text(
                  'Assign Member',
                ),
                content: SizedBox(
                  width: 360,
                  height: 420,
                  child: Column(
                    children: [
                      TextField(
                        decoration:
                            const InputDecoration(
                          hintText:
                              'Search member...',
                          prefixIcon: Icon(
                            Icons.search,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            query = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No members found.',
                                ),
                              )
                            : ListView.separated(
                                itemCount:
                                    filtered.length,
                                separatorBuilder:
                                    (_, __) =>
                                        const Divider(
                                  height: 1,
                                ),
                                itemBuilder:
                                    (_, index) {
                                  final member =
                                      filtered[
                                          index];

                                  return ListTile(
                                    leading:
                                        const CircleAvatar(
                                      child: Icon(
                                        Icons
                                            .person,
                                      ),
                                    ),
                                    title: Text(
                                      member.value,
                                    ),
                                    onTap: () {
                                      Navigator.of(
                                        dialogContext,
                                      ).pop(member);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        dialogContext,
                      ).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (selected == null) return;

      setState(() {
        _selectedUid = selected.key;
        _selectedOwnerName = selected.value;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(
        'Failed to load members.\n$e',
      );
    }
  }

  Future<void> _createLot() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_status == LotStatus.occupied &&
        _selectedUid == null) {
      _showError(
        'Please assign a member for an occupied lot.',
      );
      return;
    }

    double? area;

    final areaText =
        _areaController.text.trim();

    if (areaText.isNotEmpty) {
      area = double.tryParse(areaText);

      if (area == null) {
        _showError(
          'Please enter a valid lot area.',
        );
        return;
      }
    }

    double? price;

    if (_status == LotStatus.forSale) {
      final priceText =
          _priceController.text.trim();

      price = double.tryParse(priceText);

      if (priceText.isEmpty ||
          price == null ||
          price < 0) {
        _showError(
          'Please enter a valid price.',
        );
        return;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      await _service.createLotAtPin(
        phase:
            _phaseController.text.trim(),
        block:
            _blockController.text.trim(),
        lotNumber:
            _lotController.text.trim(),
        mapX: widget.mapX ?? 0,
        mapY: widget.mapY ?? 0,
        updatedBy:
            widget.currentUserId,
        status: _status,
        uid: _status == LotStatus.occupied
            ? _selectedUid
            : null,
        ownerName: _status ==
                LotStatus.occupied
            ? _selectedOwnerName
            : null,
        price: _status == LotStatus.forSale
            ? price
            : null,
        contactNumber: (_status ==
                        LotStatus.occupied ||
                    _status ==
                        LotStatus.forSale ||
                    _status ==
                        LotStatus.reserved) &&
                _contactController.text
                    .trim()
                    .isNotEmpty
            ? _contactController.text.trim()
            : null,
        notes: _notesController.text
                .trim()
                .isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(
        'Failed to create lot.\n$e',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFC62828),
      ),
    );
  }
}

Widget _textField({
  required TextEditingController
      controller,
  required String label,
  required String hint,
  required IconData icon,
  bool enabled = true,
  TextInputType? keyboardType,
  int maxLines = 1,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: keyboardType,
    maxLines: maxLines,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        size: 19,
      ),
      filled: true,
      fillColor: enabled
          ? const Color(0xFFF8F9FB)
          : const Color(0xFFF0F1F3),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFFE0E4E8),
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFFE0E4E8),
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide:
            const BorderSide(
          color: _blue,
          width: 1.5,
        ),
      ),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 13,
      ),
    ),
  );
}

// ================================================================
// ZOOM BUTTON
// ================================================================

class _ZoomButton
    extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape:
            const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder:
              const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding:
                const EdgeInsets.all(
              10,
            ),
            child: Icon(
              icon,
              size: 20,
              color: _navy,
            ),
          ),
        ),
      ),
    );
  }
}