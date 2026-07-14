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
const _grey = Color(0xFFBDBDBD);

const String kSubdivisionMapAsset = 'assets/images/subdivision_map.png';

/// Logical width the map content is drawn at, before any zoom transform.
/// A larger number gives more room to zoom in with less blur.
const double _kContentWidth = 2000;

/// Displays the subdivision map image with pins overlaid at each lot's
/// normalized (mapX, mapY) position. Fills all available space and
/// supports pinch-zoom/pan in every direction.
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
  final _contentKey = GlobalKey();

  double? _aspectRatio; // width / height of the actual image
  String? _loadError;
  bool _initialFitDone = false;

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

  void _applyInitialFit(BoxConstraints viewportConstraints) {
    if (_initialFitDone || _aspectRatio == null) return;
    final contentWidth = _kContentWidth;
    final contentHeight = _kContentWidth / _aspectRatio!;
    final viewportW = viewportConstraints.maxWidth;
    final viewportH = viewportConstraints.maxHeight;
    if (viewportW <= 0 || viewportH <= 0) return;

    final fitScale =
        (viewportW / contentWidth < viewportH / contentHeight)
            ? viewportW / contentWidth
            : viewportH / contentHeight;

    final scaledW = contentWidth * fitScale;
    final scaledH = contentHeight * fitScale;
    final dx = (viewportW - scaledW) / 2;
    final dy = (viewportH - scaledH) / 2;

    final matrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(fitScale);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _transformController.value = matrix;
      setState(() => _initialFitDone = true);
    });
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

  void _handleTap(TapUpDetails details) {
    // Use the content Stack's own RenderBox (not the outer viewport's) so
    // the tap position is correctly translated through InteractiveViewer's
    // current zoom/pan transform, no matter how far zoomed or panned.
    final box =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final size = box.size;
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > size.width ||
        local.dy > size.height) {
      return; // tapped outside the actual image content
    }
    final normX = (local.dx / size.width).clamp(0.0, 1.0);
    final normY = (local.dy / size.height).clamp(0.0, 1.0);
    _openAddPinDialog(normX, normY);
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

    final contentWidth = _kContentWidth;
    final contentHeight = _kContentWidth / _aspectRatio!;
    final pinnedLots = widget.lots.where((l) => l.isPlottedOnMap).toList();

    // SizedBox.expand forces this to fill all space the parent gives it
    // (e.g. the Expanded in the screen above), so InteractiveViewer gets
    // a real, non-zero viewport instead of collapsing to its content size.
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, viewportConstraints) {
          _applyInitialFit(viewportConstraints);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.grey[100],
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.2,
                maxScale: 8,
                boundaryMargin: const EdgeInsets.all(400),
                constrained: false,
                child: GestureDetector(
                  onTapUp: widget.canEdit ? _handleTap : null,
                  child: SizedBox(
                    key: _contentKey,
                    width: contentWidth,
                    height: contentHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Image.asset(
                          kSubdivisionMapAsset,
                          width: contentWidth,
                          height: contentHeight,
                          fit: BoxFit.fill,
                        ),
                        ...pinnedLots.map((lot) {
                          return Positioned(
                            left: (lot.mapX! * contentWidth) - 14,
                            top: (lot.mapY! * contentHeight) - 28,
                            child: GestureDetector(
                              onTap: () => _openLotDialog(lot),
                              child: Tooltip(
                                message: lot.displayLabel,
                                child: Icon(
                                  Icons.location_on,
                                  color: _colorFor(lot.status),
                                  size: 32,
                                  shadows: const [
                                    Shadow(
                                        color: Colors.black45,
                                        blurRadius: 4,
                                        offset: Offset(0, 1)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}