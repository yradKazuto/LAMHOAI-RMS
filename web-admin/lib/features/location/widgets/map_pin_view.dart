import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../core/models/lot_model.dart';
import '../../../core/services/lot_service.dart';
import 'lot_dialogs.dart';

const _navy = Color(0xFF0D2A52);
const _blue = Color(0xFF1565C0);
const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _grey = Color(0xFF757575);

const String kSubdivisionMapAsset = 'assets/images/subdivision_map.png';

/// Displays the subdivision map image with pins overlaid at each lot's
/// normalized (mapX, mapY) position. Fills all available space; supports
/// pinch-zoom/pan in every direction plus on-screen zoom buttons.
/// Admin/Officer can tap empty space to place a new lot pin there.
class MapPinView extends StatefulWidget {
  final List<LotModel> lots;
  final bool canEdit;
  final String currentUserId;
  final Future<List<MapEntry<String, String>>> Function() loadAssignableMembers;

  const MapPinView({
    super.key,
    required this.lots,
    required this.canEdit,
    required this.currentUserId,
    required this.loadAssignableMembers,
  });

  @override
  State<MapPinView> createState() => _MapPinViewState();
}

class _MapPinViewState extends State<MapPinView> {
  final _service = LotService();
  final _transformController = TransformationController();

  double? _aspectRatio; // width / height of the actual image
  String? _loadError;

  static const double _minScale = 0.3;
  static const double _maxScale = 8;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    try {
      final data = await rootBundle.load(kSubdivisionMapAsset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _aspectRatio = frame.image.width / frame.image.height;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

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

  void _zoomBy(double factor) {
    final current = _transformController.value.clone();
    final currentScale = current.getMaxScaleOnAxis();
    final targetScale =
        (currentScale * factor).clamp(_minScale, _maxScale);
    final adjust = targetScale / currentScale;
    // Scale around the center of the current matrix rather than the origin,
    // so zoom buttons feel like they zoom "into the middle" of the view.
    final matrix = current.clone()..scale(adjust);
    _transformController.value = matrix;
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  void _openLotDialog(LotModel lot) {
    if (lot.status == LotStatus.occupied) {
      showDialog(
        context: context,
        builder: (_) => OccupiedLotDialog(
          lot: lot,
          canEdit: widget.canEdit,
          onUnassign: () => _service.unassignOwner(
              lotId: lot.id, updatedBy: widget.currentUserId),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => VacantLotDialog(
          lot: lot,
          canEdit: widget.canEdit,
          currentUserId: widget.currentUserId,
          loadAssignableMembers: widget.loadAssignableMembers,
        ),
      );
    }
  }

  Future<void> _openAddPinDialog(double normX, double normY) async {
    final phaseCtrl = TextEditingController();
    final blockCtrl = TextEditingController();
    final lotCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Lot Here'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phaseCtrl,
                decoration: const InputDecoration(
                    labelText: 'Phase (e.g. Phase 1)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: blockCtrl,
                decoration: const InputDecoration(
                    labelText: 'Block (e.g. Block 3)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lotCtrl,
                decoration: const InputDecoration(
                    labelText: 'Lot Number (e.g. Lot 12)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add Pin'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (phaseCtrl.text.trim().isEmpty ||
        blockCtrl.text.trim().isEmpty ||
        lotCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Fill in phase, block, and lot number')));
      }
      return;
    }

    await _service.createLotAtPin(
      phase: phaseCtrl.text.trim(),
      block: blockCtrl.text.trim(),
      lotNumber: lotCtrl.text.trim(),
      mapX: normX,
      mapY: normY,
      updatedBy: widget.currentUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Container(
        alignment: Alignment.center,
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load map image.\n\n'
            'Make sure the file exists at:\n$kSubdivisionMapAsset\n\n'
            'and is registered under `assets:` in pubspec.yaml, '
            'then run flutter pub get.\n\nError: $_loadError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      );
    }

    if (_aspectRatio == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final pinnedLots = widget.lots.where((l) => l.isPlottedOnMap).toList();

    return SizedBox.expand(
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.grey[100],
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: _minScale,
                maxScale: _maxScale,
                boundaryMargin: const EdgeInsets.all(120),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _aspectRatio!,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;
                        return GestureDetector(
                          onTapUp: widget.canEdit
                              ? (details) {
                                  final box = context.findRenderObject()
                                      as RenderBox?;
                                  if (box == null) return;
                                  final local = box
                                      .globalToLocal(details.globalPosition);
                                  final normX =
                                      (local.dx / w).clamp(0.0, 1.0);
                                  final normY =
                                      (local.dy / h).clamp(0.0, 1.0);
                                  _openAddPinDialog(normX, normY);
                                }
                              : null,
                          child: Stack(
                            children: [
                              Image.asset(
                                kSubdivisionMapAsset,
                                width: w,
                                height: h,
                                fit: BoxFit.fill,
                              ),
                              ...pinnedLots.map((lot) {
                                final color = _colorFor(lot.status);
                                return Positioned(
                                  left: (lot.mapX! * w) - 16,
                                  top: (lot.mapY! * h) - 36,
                                  child: GestureDetector(
                                    onTap: () => _openLotDialog(lot),
                                    child: Tooltip(
                                      message: lot.displayLabel,
                                      child: _MapPin(color: color),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── On-screen zoom controls ──────────────────────────────────
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              children: [
                _ZoomButton(
                  icon: Icons.add,
                  tooltip: 'Zoom in',
                  onPressed: () => _zoomBy(1.4),
                ),
                const SizedBox(height: 8),
                _ZoomButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom out',
                  onPressed: () => _zoomBy(1 / 1.4),
                ),
                const SizedBox(height: 8),
                _ZoomButton(
                  icon: Icons.center_focus_strong,
                  tooltip: 'Reset view',
                  onPressed: _resetZoom,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small floating circular button used for the zoom controls.
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 20, color: _navy),
          ),
        ),
      ),
    );
  }
}

/// Clearer pin marker: solid color circle with a white house icon and a
/// pointed tip, plus a subtle white outline so it stands out against any
/// background (roofs, roads, trees, etc.) on the satellite image.
class _MapPin extends StatelessWidget {
  final Color color;
  const _MapPin({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 40,
      child: CustomPaint(
        painter: _PinPainter(color: color),
        child: const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Icon(Icons.home, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  final Color color;
  _PinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.width / 2);
    final radius = size.width / 2 - 2;

    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..moveTo(center.dx - radius * 0.55, center.dy + radius * 0.6)
      ..lineTo(center.dx, size.height)
      ..lineTo(center.dx + radius * 0.55, center.dy + radius * 0.6)
      ..close();

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(path.shift(const Offset(0, 1.5)), shadowPaint);

    final fillPaint = Paint()..color = color;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PinPainter oldDelegate) =>
      oldDelegate.color != color;
}