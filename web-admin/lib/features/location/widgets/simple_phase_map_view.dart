// features/location/widgets/simple_phase_map_view.dart
//
// Map view for any phase OTHER than "Phase 1". Phase 1 keeps using
// the existing hand-digitized polygon system in map_pin_view.dart,
// unchanged. New phases use this system instead: an uploaded image
// (via Cloudinary, so no app rebuild needed), with lots shown either
// as a simple pin (tap-placed, or before a polygon is digitized) or
// as a precise clickable polygon shape (once boundary points are
// imported from the coordinate picker tool). Reuses the same
// AddLotDialog / OccupiedLotDialog / VacantLotDialog already used
// for Phase 1's lot management.

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/models/lot_model.dart';
import '../../../core/models/phase_map_model.dart';
import '../../../core/services/lot_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/phase_map_service.dart';
import '../../documents/widgets/document_upload_flow.dart' show documentMimeType;
import 'map_pin_view.dart' show AddLotDialog;
import 'lot_dialogs.dart' hide AddLotDialog;
// import 'polygon_import_flow.dart'; // TODO: re-enable once `excel` package is added (flutter pub add excel)

const _navy = Color(0xFF1E293B);
const _blue = Color(0xFF1565C0);
const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _purple = Color(0xFF6A1B9A);
const _grey = Color(0xFF9E9E9E);
const _accent = Color(0xFF2563EB);

class SimplePhaseMapView extends StatefulWidget {
  final PhaseMapModel phaseMap;
  final List<LotModel> lots; // already filtered to this phase
  final bool canEdit;
  final String currentUserId;
  final Future<List<MapEntry<String, String>>> Function()
      loadAssignableMembers;
  final Future<void> Function(LotModel lot)? onViewMember;

  const SimplePhaseMapView({
    super.key,
    required this.phaseMap,
    required this.lots,
    required this.canEdit,
    required this.currentUserId,
    required this.loadAssignableMembers,
    this.onViewMember,
  });

  @override
  State<SimplePhaseMapView> createState() => _SimplePhaseMapViewState();
}

class _SimplePhaseMapViewState extends State<SimplePhaseMapView>
    with SingleTickerProviderStateMixin {
  final _lotService = LotService();
  final _cloudinary = CloudinaryService();
  final _phaseMapService = PhaseMapService();

  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey();

  late final AnimationController _zoomAnimController;
  late final CurvedAnimation _zoomCurve;
  Matrix4Tween? _zoomTween;

  double? _aspectRatio;
  double? _naturalWidth;
  double? _naturalHeight;
  bool _uploading = false;
  double _uploadProgress = 0;
  bool _importing = false;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  // ── Blocks side panel ────────────────────────────────────────────────
  // Selecting a block highlights its lots (spotlight — see
  // _BlockSpotlightPainter) AND zooms/pans to frame them, matching how
  // the click-to-focus reference works: translate = viewportCenter -
  // scale * targetPoint, using MEASURED content/viewport sizes (not
  // assumed constants) each time.
  String? _selectedBlock;
  static const double _minScale = 0.3;
  static const double _maxScale = 8.0;

  // Diagnostic snapshot of the last zoom-to-block computation, shown
  // as an on-screen overlay so "the zoom is off" can be checked
  // against actual numbers instead of guessed at blind.
  _ZoomDebugInfo? _lastZoomDebug;

  // ── Native digitize mode ────────────────────────────────────────────
  bool _digitizing = false;
  final List<Offset> _digitizePoints = []; // normalized 0.0-1.0 points

  @override
  void initState() {
    super.initState();
    if (widget.phaseMap.hasImage) {
      _resolveImageSize(widget.phaseMap.imageUrl);
    }
    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _zoomCurve = CurvedAnimation(
        parent: _zoomAnimController, curve: Curves.easeInOutCubic);
    _zoomAnimController.addListener(() {
      final tween = _zoomTween;
      if (tween != null) {
        _transformController.value = tween.evaluate(_zoomCurve);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SimplePhaseMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phaseMap.imageUrl != oldWidget.phaseMap.imageUrl &&
        widget.phaseMap.hasImage) {
      _aspectRatio = null;
      _naturalWidth = null;
      _naturalHeight = null;
      _resolveImageSize(widget.phaseMap.imageUrl);
    }
  }

  // Resolves the real pixel width/height of the uploaded image — used
  // both for accurate aspect ratio display AND to correctly normalize
  // coordinates imported from the coordinate picker tool (which
  // records raw pixel positions against the image's true dimensions).
  void _resolveImageSize(String url) {
    final provider = NetworkImage(url);
    _imageStream?.removeListener(_imageListener!);
    _imageStream = provider.resolve(const ImageConfiguration());
    _imageListener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (w > 0 && h > 0) {
        setState(() {
          _aspectRatio = w / h;
          _naturalWidth = w;
          _naturalHeight = h;
        });
      }
    });
    _imageStream!.addListener(_imageListener!);
  }

  @override
  void dispose() {
    _transformController.dispose();
    _zoomCurve.dispose();
    _zoomAnimController.dispose();
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    super.dispose();
  }

  // Status colors match Phase 1's map_pin_view.dart mapping exactly,
  // so the Blocks legend means the same thing on both screens.
  Color _colorFor(LotStatus s) {
    switch (s) {
      case LotStatus.occupied: return _green;
      case LotStatus.vacant:   return _blue;
      case LotStatus.forSale:  return _orange;
      case LotStatus.reserved: return _purple;
    }
  }

  IconData _iconFor(LotStatus s) {
    switch (s) {
      case LotStatus.occupied: return Icons.home;
      case LotStatus.forSale:  return Icons.sell;
      case LotStatus.reserved: return Icons.lock_clock;
      case LotStatus.vacant:   return Icons.crop_square;
    }
  }

  // ── Blocks side panel ────────────────────────────────────────────────
  List<String> _getBlocks() {
    final blocks = <String>{};
    for (final lot in widget.lots) {
      final block = lot.block.trim();
      if (block.isNotEmpty) blocks.add(block);
    }

    final result = blocks.toList();
    result.sort((a, b) {
      final aNumber = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
      final bNumber = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
      if (aNumber != null && bNumber != null) {
        return aNumber.compareTo(bNumber);
      }
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return result;
  }


  /// Toggles which block is highlighted, and zooms/pans to frame it.
  void _selectBlock(String block) {
    final deselecting = _selectedBlock == block;
    setState(() {
      _selectedBlock = deselecting ? null : block;
      if (deselecting) _lastZoomDebug = null;
    });

    if (deselecting) {
      _animateToMatrix(Matrix4.identity());
    } else {
      // Wait a frame so layout (including the spotlight/highlight
      // showing up) is settled before measuring anything.
      WidgetsBinding.instance.addPostFrameCallback((_) => _zoomToBlock(block));
    }
  }

  void _animateToMatrix(Matrix4 target) {
    _zoomTween = Matrix4Tween(begin: _transformController.value, end: target);
    _zoomAnimController.reset();
    _zoomAnimController.forward();
  }

  /// Frames the given block's lots (polygon or pin) in the viewport.
  ///
  /// translate = viewportCenter - scale * targetPoint — the same
  /// formula the click-to-focus reference reduces to once its
  /// transform-origin:center math is worked out, using MEASURED
  /// content/viewport sizes each time rather than assumed constants.
  void _zoomToBlock(String block) {
    final contentBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;

    if (contentBox == null ||
        viewportBox == null ||
        !contentBox.hasSize ||
        !viewportBox.hasSize) {
      return;
    }

    final contentSize = contentBox.size;
    final viewportSize = viewportBox.size;

    // The content box (AspectRatio) is centered inside the
    // InteractiveViewer's child area — if the map's aspect ratio
    // doesn't match the viewport's, Center adds empty margin on the
    // sides (or top/bottom). That margin has to be added back into
    // every point below, exactly like Phase 1's map_pin_view.dart
    // does, or every computed position drifts by exactly that amount.
    final letterboxX = (viewportSize.width - contentSize.width) / 2;
    final letterboxY = (viewportSize.height - contentSize.height) / 2;

    // One representative point PER LOT (its own centroid, or its pin
    // position) — not every raw vertex. A single stray digitized point
    // only nudges its own lot's centroid a little; it can't single-
    // handedly blow out a min/max bounding box the way a raw vertex
    // can. The lot itself is tracked alongside each centroid purely
    // for the debug overlay (status/owner) — doesn't affect the
    // framing math at all.
    final lotEntries = <MapEntry<LotModel, Offset>>[];
    for (final lot in widget.lots) {
      if (lot.block.trim().toLowerCase() != block.trim().toLowerCase()) {
        continue;
      }
      if (lot.hasPolygon) {
        final pts = lot.polygonPoints!;
        double sx = 0, sy = 0;
        for (final p in pts) {
          sx += p.x * contentSize.width;
          sy += p.y * contentSize.height;
        }
        lotEntries.add(MapEntry(
          lot,
          Offset(letterboxX + sx / pts.length, letterboxY + sy / pts.length),
        ));
      } else if (lot.mapX != null && lot.mapY != null) {
        lotEntries.add(MapEntry(
          lot,
          Offset(
            letterboxX + lot.mapX! * contentSize.width,
            letterboxY + lot.mapY! * contentSize.height,
          ),
        ));
      }
    }

    if (lotEntries.isEmpty) return;
    final lotCentroids = lotEntries.map((e) => e.value).toList();

    // Median center (robust to outliers, unlike a mean or a min/max
    // box) — used only to detect which lots are clearly out of place,
    // not as the final target itself. Worth knowing its limit: this
    // only protects against a MINORITY of bad points. If most of a
    // block's lots share the same mistake (e.g. several digitized in
    // the wrong spot), the median gets pulled toward THEM, and the
    // one correctly-placed lot can end up looking like the "outlier"
    // instead. The per-lot list in the debug overlay is there so you
    // can catch that case by eye — it shows the raw numbers whether
    // or not this filter agrees with them.
    final xs = lotCentroids.map((p) => p.dx).toList()..sort();
    final ys = lotCentroids.map((p) => p.dy).toList()..sort();
    final medianCenter = Offset(xs[xs.length ~/ 2], ys[ys.length ~/ 2]);

    final distances =
        lotCentroids.map((p) => (p - medianCenter).distance).toList()..sort();
    final medianDistance = distances[distances.length ~/ 2];
    // A lot's centroid counts as an outlier once it's much farther from
    // the median than the typical lot is — generous enough that a
    // genuinely large block doesn't trip this, but tight enough to
    // reject a lot whose digitized shape stretches off into unrelated
    // parts of the map.
    final outlierThreshold =
        (medianDistance * 4).clamp(120.0, double.infinity);

    bool isOutlier(Offset c) =>
        (c - medianCenter).distance > outlierThreshold;

    final keptLots =
        lotCentroids.where((c) => !isOutlier(c)).toList();
    // If literally everything got flagged (e.g. only one or two lots
    // total, so "distance from median" isn't meaningful), fall back to
    // using all of them rather than framing nothing.
    final framingPoints = keptLots.isNotEmpty ? keptLots : lotCentroids;

    double minX = framingPoints.first.dx;
    double maxX = framingPoints.first.dx;
    double minY = framingPoints.first.dy;
    double maxY = framingPoints.first.dy;

    for (final p in framingPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    // A block that's just a single lot collapses to a zero-size box —
    // pad it so we still zoom in on it instead of bailing out below.
    if (maxX - minX <= 0 || maxY - minY <= 0) {
      const pad = 80.0;
      final cx = (minX + maxX) / 2;
      final cy = (minY + maxY) / 2;
      minX = cx - pad;
      maxX = cx + pad;
      minY = cy - pad;
      maxY = cy + pad;
    }

    final boxWidth = maxX - minX;
    final boxHeight = maxY - minY;
    if (boxWidth <= 0 || boxHeight <= 0) return;

    final targetPoint = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    const paddingFactor = 2.5;
    final scaleByWidth = (viewportSize.width / (boxWidth * paddingFactor))
        .clamp(_minScale, _maxScale);
    final scaleByHeight = (viewportSize.height / (boxHeight * paddingFactor))
        .clamp(_minScale, _maxScale);
    final scale = scaleByWidth < scaleByHeight ? scaleByWidth : scaleByHeight;

    final viewportCenter =
        Offset(viewportSize.width / 2, viewportSize.height / 2);
    final translate = viewportCenter - targetPoint * scale;

    final target = Matrix4.identity()
      ..translate(translate.dx, translate.dy)
      ..scale(scale);

    // Center, expressed as a percentage of the IMAGE itself (letterbox
    // subtracted back out) — this is the number to eyeball against
    // where the block actually visually sits on the map.
    final imageLocalCenter =
        Offset(targetPoint.dx - letterboxX, targetPoint.dy - letterboxY);
    final centerPercent = Offset(
      (imageLocalCenter.dx / contentSize.width).clamp(0.0, 1.0),
      (imageLocalCenter.dy / contentSize.height).clamp(0.0, 1.0),
    );

    final debugLots = lotEntries.map((e) {
      final lot = e.key;
      final localCenter = Offset(
        e.value.dx - letterboxX,
        e.value.dy - letterboxY,
      );
      return _ZoomDebugLot(
        lotNumber: lot.lotNumber,
        centerPercent: Offset(
          (localCenter.dx / contentSize.width).clamp(0.0, 1.0),
          (localCenter.dy / contentSize.height).clamp(0.0, 1.0),
        ),
        isOutlier: isOutlier(e.value),
        status: lot.status,
        ownerName: lot.ownerName,
      );
    }).toList();

    setState(() {
      _lastZoomDebug = _ZoomDebugInfo(
        block: block,
        lotsFound: lotCentroids.length,
        lotsExcluded: lotCentroids.length - framingPoints.length,
        centerPercent: centerPercent,
        scale: scale,
        contentSize: contentSize,
        viewportSize: viewportSize,
        lots: debugLots,
      );
    });

    _animateToMatrix(target);
  }

  // ── Upload the map image for this phase ──────────────────────────────
  Future<void> _uploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final url = await _cloudinary.uploadFile(
        fileBytes: file.bytes!,
        fileName: file.name,
        memberId: 'phase_maps/${widget.phaseMap.id}',
        mimeType: documentMimeType(file.extension ?? ''),
        onProgress: (p) => setState(() => _uploadProgress = p),
      );
      await _phaseMapService.setPhaseImage(widget.phaseMap.id, url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Import digitized lot boundaries from the coordinate picker tool ──
  Future<void> _importCoordinates() async {
    if (_naturalWidth == null || _naturalHeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Still loading the map image — try again in a moment.')),
      );
      return;
    }

    setState(() => _importing = true);
    try {
      // TODO: re-enable once `excel` package is added (flutter pub add excel)
      final int? count = null;
      /*
      final count = await runPolygonImportFlow(
        context: context,
        phase: widget.phaseMap.name,
        imageWidth: _naturalWidth!,
        imageHeight: _naturalHeight!,
        updatedBy: widget.currentUserId,
      );
      */
      if (count != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $count lot(s).'),
            backgroundColor: const Color(0xFF1A7A4A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  // ── Digitize mode controls ─────────────────────────────────────────
  void _toggleDigitize() {
    setState(() {
      _digitizing = !_digitizing;
      _digitizePoints.clear();
    });
  }

  void _undoDigitizePoint() {
    if (_digitizePoints.isEmpty) return;
    setState(() => _digitizePoints.removeLast());
  }

  void _clearDigitizePoints() {
    setState(() => _digitizePoints.clear());
  }

  Future<void> _saveDigitizedLot() async {
    if (_digitizePoints.length < 3) return;

    final blockController = TextEditingController();
    final lotController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Save Lot Boundary',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_digitizePoints.length} points traced.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
            const SizedBox(height: 14),
            TextField(
              controller: blockController,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Block', hintText: 'e.g. Block 1'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lotController,
              decoration: const InputDecoration(
                  labelText: 'Lot Number', hintText: 'e.g. 1'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (blockController.text.trim().isEmpty ||
                  lotController.text.trim().isEmpty) return;
              Navigator.pop(dialogCtx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final block = blockController.text.trim();
    final lotNumber = lotController.text.trim();
    final points =
        _digitizePoints.map((o) => LotPoint(o.dx, o.dy)).toList();

    try {
      await _lotService.importPolygonLots(
        phase: widget.phaseMap.name,
        lotsData: {'$block|$lotNumber': points},
        updatedBy: widget.currentUserId,
      );
      if (mounted) {
        setState(() {
          _digitizing = false;
          _digitizePoints.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved Block $block • Lot $lotNumber.'),
            backgroundColor: const Color(0xFF1A7A4A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  // ── Point-in-polygon test (ray casting) ───────────────────────────────
  bool _pointInPolygon(Offset point, List<LotPoint> polygon) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].x, yi = polygon[i].y;
      final xj = polygon[j].x, yj = polygon[j].y;
      final intersects = ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx < (xj - xi) * (point.dy - yi) / (yj - yi) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  // ── Tap handling: check polygons first, then fall back to placing
  // a new pin on empty space ─────────────────────────────────────────
  void _onTapUp(TapUpDetails details, Size contentSize) {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(details.globalPosition);
    final nx = (local.dx / contentSize.width).clamp(0.0, 1.0);
    final ny = (local.dy / contentSize.height).clamp(0.0, 1.0);

    // Digitize mode — every tap just adds another boundary point,
    // nothing else happens while active.
    if (_digitizing) {
      setState(() => _digitizePoints.add(Offset(nx, ny)));
      return;
    }

    final normalizedTap = Offset(nx, ny);

    // Check polygon lots first — tapping inside a digitized boundary
    // opens that lot directly, same as Phase 1's polygon map.
    for (final lot in widget.lots) {
      if (lot.hasPolygon &&
          _pointInPolygon(normalizedTap, lot.polygonPoints!)) {
        _openLotDialog(lot);
        return;
      }
    }

    // Defensive safety net for pin lots: each pin marker has its own
    // GestureDetector for opening it, which normally wins the tap over
    // this outer handler — but that's a gesture-arena race, not a
    // guarantee. If this handler ever DOES end up processing a tap
    // that landed on/near an existing pin (as happened during digitize
    // mode — see the pin markers below), open that lot instead of
    // silently creating a duplicate one on top of it.
    LotModel? nearestPin;
    double nearestDistSq = double.infinity;
    const pinHitRadius = 14 / 1000; // matches the 28px pin marker, normalized
    for (final lot in widget.lots) {
      if (lot.hasPolygon || lot.mapX == null || lot.mapY == null) continue;
      final dx = lot.mapX! - nx;
      final dy = lot.mapY! - ny;
      final distSq = dx * dx + dy * dy;
      if (distSq <= pinHitRadius * pinHitRadius && distSq < nearestDistSq) {
        nearestDistSq = distSq;
        nearestPin = lot;
      }
    }
    if (nearestPin != null) {
      _openLotDialog(nearestPin);
      return;
    }

    if (!widget.canEdit) return;

    showDialog(
      context: context,
      builder: (_) => AddLotDialog(
        phase: widget.phaseMap.name,
        block: '',
        lotNumber: '',
        currentUserId: widget.currentUserId,
        loadAssignableMembers: widget.loadAssignableMembers,
        mapX: nx,
        mapY: ny,
      ),
    );
  }

  void _openLotDialog(LotModel lot) {
    if (lot.status == LotStatus.occupied) {
      showDialog(
        context: context,
        builder: (_) => OccupiedLotDialog(
          lot: lot,
          canEdit: widget.canEdit,
          onViewMember: widget.onViewMember == null
              ? null
              : () => widget.onViewMember!(lot),
          onUnassign: () => _lotService.unassignOwner(
            lotId: lot.id,
            updatedBy: widget.currentUserId,
          ),
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

  @override
  Widget build(BuildContext context) {
    if (!widget.phaseMap.hasImage) {
      return _EmptyMapState(
        phaseName: widget.phaseMap.name,
        canEdit: widget.canEdit,
        uploading: _uploading,
        progress: _uploadProgress,
        onUpload: _uploadImage,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = constraints.maxWidth < 900 ? 190.0 : 230.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: panelWidth,
              child: _buildBlockPanel(),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildMapArea()),
          ],
        );
      },
    );
  }

  Widget _buildMapArea() {
    return Stack(
      key: _viewportKey,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final polygonLots =
                widget.lots.where((l) => l.hasPolygon).toList();
            final pinLots =
                widget.lots.where((l) => !l.hasPolygon).toList();

            return InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.3,
              maxScale: 8,
              boundaryMargin: const EdgeInsets.all(200),
              // Center + AspectRatio — matching Phase 1's
              // map_pin_view.dart structure exactly, not just its
              // math. Phase 1's zoom math explicitly accounts for a
              // real letterbox margin that Center+AspectRatio
              // guarantees exists; this view was previously using a
              // plain fixed-size SizedBox with no such guarantee,
              // which is the most likely actual cause of the zoom
              // drift — the two views' content simply wasn't laid out
              // the same way, no matter how carefully the transform
              // math tried to compensate for it.
              child: Center(
                child: AspectRatio(
                  aspectRatio: _aspectRatio ?? 1.0,
                  child: LayoutBuilder(
                    builder: (context, innerConstraints) {
                      // The REAL, final size of the content box, now
                      // that AspectRatio has resolved it — used for
                      // every coordinate calculation below instead of
                      // an assumed constant, so this stays correct
                      // regardless of what size AspectRatio actually
                      // settles on for a given viewport.
                      final contentSize = innerConstraints.biggest;

                      return GestureDetector(
                        onTapUp: (d) => _onTapUp(d, contentSize),
                        child: Stack(
                          key: _contentKey,
                          fit: StackFit.expand,
                          children: [
                      Positioned.fill(
                        child: Image(
                          image: NetworkImage(widget.phaseMap.imageUrl),
                          fit: BoxFit.fill,
                          errorBuilder: (context, error, stack) => Container(
                            color: const Color(0xFFF0F1F3),
                            child: const Center(
                              child: Text('Could not load map image.'),
                            ),
                          ),
                        ),
                      ),

                      // Spotlight highlight — matches Phase 1's
                      // map_pin_view.dart exactly: a dark layer over
                      // the whole map with the selected block's actual
                      // digitized shape (or a circle, for pin lots)
                      // cut out of it. Lots ALWAYS show their normal
                      // status color everywhere, selected or not —
                      // this only dims the background map art around
                      // the selected block, it never grays out lots.
                      if (_selectedBlock != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _BlockSpotlightPainter(
                                polygonShapes: widget.lots
                                    .where((l) =>
                                        l.hasPolygon &&
                                        l.block.trim().toLowerCase() ==
                                            _selectedBlock!.trim().toLowerCase())
                                    .map((l) => l.polygonPoints!
                                        .map((p) => Offset(p.x, p.y))
                                        .toList())
                                    .toList(),
                                pinCenters: widget.lots
                                    .where((l) =>
                                        !l.hasPolygon &&
                                        l.mapX != null &&
                                        l.mapY != null &&
                                        l.block.trim().toLowerCase() ==
                                            _selectedBlock!.trim().toLowerCase())
                                    .map((l) => Offset(l.mapX!, l.mapY!))
                                    .toList(),
                              ),
                            ),
                          ),
                        ),

                      // Digitized polygon lots — precise clickable shapes
                      if (polygonLots.isNotEmpty)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PolygonPainter(
                              lots: polygonLots,
                              contentSize: contentSize,
                              colorFor: _colorFor,
                            ),
                          ),
                        ),

                      // Simple pin lots — no digitized boundary yet.
                      // Their own GestureDetector normally handles taps
                      // for opening the lot, but that was competing with
                      // the outer map's tap handler for the SAME tap
                      // whenever digitize mode was active — Flutter's
                      // gesture arena doesn't reliably pick a winner
                      // between a nested GestureDetector and an
                      // ancestor's when both recognize a tap, so a tap
                      // meant to hit a pin could instead register as a
                      // new digitize boundary point right on top of it
                      // (that's the red dot). While digitizing, pins are
                      // dimmed and stop intercepting taps entirely, so
                      // every tap unambiguously goes to placing a point.
                      for (final lot in pinLots)
                        if (lot.mapX != null && lot.mapY != null)
                          Positioned(
                            left: lot.mapX! * contentSize.width - 14,
                            top: lot.mapY! * contentSize.height - 14,
                            child: IgnorePointer(
                              ignoring: _digitizing,
                              child: GestureDetector(
                                onTap: () => _openLotDialog(lot),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 220),
                                  opacity: _digitizing ? 0.35 : 1.0,
                                  child: Tooltip(
                                    message:
                                        'Block ${lot.block} • Lot ${lot.lotNumber}',
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _colorFor(lot.status),
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 3,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Icon(_iconFor(lot.status),
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                      // Live preview while digitizing a new lot boundary
                      if (_digitizing && _digitizePoints.isNotEmpty)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DigitizePreviewPainter(
                              points: _digitizePoints,
                              contentSize: contentSize,
                            ),
                          ),
                        ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),

        // ── Zoom diagnostic overlay ──────────────────────────────────
        if (_lastZoomDebug != null)
          Positioned(
            top: 12,
            left: 12,
            child: _ZoomDebugOverlay(info: _lastZoomDebug!),
          ),

        // ── Toolbar ──────────────────────────────────────────────────
        if (widget.canEdit)
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                // Import Excel button hidden until `excel` package is added
                // (flutter pub add excel) — see _importCoordinates() above.
                // if (!_digitizing) ...[
                //   if (_importing)
                //     Container(
                //       padding: const EdgeInsets.symmetric(
                //           horizontal: 14, vertical: 10),
                //       decoration: BoxDecoration(
                //         color: Colors.white,
                //         borderRadius: BorderRadius.circular(8),
                //         boxShadow: const [
                //           BoxShadow(color: Colors.black12, blurRadius: 6),
                //         ],
                //       ),
                //       child: const SizedBox(
                //         width: 16,
                //         height: 16,
                //         child: CircularProgressIndicator(strokeWidth: 2),
                //       ),
                //     )
                //   else
                //     ElevatedButton.icon(
                //       onPressed: _importCoordinates,
                //       icon: const Icon(Icons.upload_file_outlined, size: 16),
                //       label: const Text('Import Excel'),
                //       style: ElevatedButton.styleFrom(
                //         backgroundColor: Colors.white,
                //         foregroundColor: _accent,
                //         elevation: 2,
                //         padding: const EdgeInsets.symmetric(
                //             horizontal: 14, vertical: 10),
                //         shape: RoundedRectangleBorder(
                //             borderRadius: BorderRadius.circular(8)),
                //       ),
                //     ),
                //   const SizedBox(width: 8),
                // ],
                ElevatedButton.icon(
                  onPressed: _toggleDigitize,
                  icon: Icon(
                      _digitizing
                          ? Icons.close
                          : Icons.edit_location_alt_outlined,
                      size: 16),
                  label: Text(_digitizing ? 'Stop Digitizing' : 'Digitize Lot'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _digitizing ? _orange : Colors.white,
                    foregroundColor: _digitizing ? Colors.white : _navy,
                    elevation: 2,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

        // ── Digitize control panel ──────────────────────────────────────
        if (_digitizing)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_digitizePoints.length} point(s)',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _navy)),
                    const SizedBox(width: 14),
                    IconButton(
                      onPressed:
                          _digitizePoints.isEmpty ? null : _undoDigitizePoint,
                      icon: const Icon(Icons.undo, size: 18),
                      tooltip: 'Undo last point',
                    ),
                    IconButton(
                      onPressed:
                          _digitizePoints.isEmpty ? null : _clearDigitizePoints,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Clear points',
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: _digitizePoints.length >= 3
                          ? _saveDigitizedLot
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Save Lot'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // BLOCK PANEL
  // ============================================================

  Widget _buildBlockPanel() {
    final blocks = _getBlocks();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blocks',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a block to zoom in and highlight its lots. '
            'Tap again to reset.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: blocks.isEmpty
                ? Center(
                    child: Text(
                      'No blocks yet',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey[500],
                      ),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ...blocks.map(
                        (block) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildBlockButton(
                            label: block,
                            selected: _selectedBlock == block,
                            onTap: () => _selectBlock(block),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_outlined, size: 16, color: _navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedBlock == null
                        ? 'Select a block'
                        : 'Selected: $_selectedBlock',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
              border: Border.all(color: const Color(0xFFE2E5E9)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegendRow(color: _green, label: 'Occupied'),
                SizedBox(height: 6),
                _LegendRow(color: _blue, label: 'Vacant'),
                SizedBox(height: 6),
                _LegendRow(color: _orange, label: 'For Sale'),
                SizedBox(height: 6),
                _LegendRow(color: _purple, label: 'Reserved'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8F0FE) : const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? _accent : const Color(0xFFE2E5E9),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 16,
                color: selected ? _accent : Colors.grey[500],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? _navy : Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small legend swatch + label row used inside the Blocks panel ──────
class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: _navy),
        ),
      ],
    );
  }
}

// ── Zoom diagnostic snapshot ────────────────────────────────────────
// Plain data holder — what _zoomToBlock actually computed, surfaced
// so "it's off" can be checked against real numbers instead of
// guessed at. Nothing here affects the zoom itself.
class _ZoomDebugInfo {
  final String block;
  final int lotsFound;
  final int lotsExcluded;
  final Offset centerPercent; // 0..1 of the image itself
  final double scale;
  final Size contentSize;
  final Size viewportSize;
  final List<_ZoomDebugLot> lots;

  const _ZoomDebugInfo({
    required this.block,
    required this.lotsFound,
    required this.lotsExcluded,
    required this.centerPercent,
    required this.scale,
    required this.contentSize,
    required this.viewportSize,
    required this.lots,
  });
}

// Per-lot breakdown — lets you spot exactly which lot number's stored
// points are sitting somewhere they shouldn't, instead of guessing
// from the block-level average.
class _ZoomDebugLot {
  final String lotNumber;
  final Offset centerPercent; // 0..1 of the image itself — kept for
  // the outlier math, no longer shown directly (status is more useful
  // to read at a glance than a raw position).
  final bool isOutlier;
  final LotStatus status;
  final String? ownerName;

  const _ZoomDebugLot({
    required this.lotNumber,
    required this.centerPercent,
    required this.isOutlier,
    required this.status,
    required this.ownerName,
  });

  /// "John Doe" if occupied and named, otherwise the status itself
  /// ("Unassigned" for vacant, so it reads clearly rather than blank).
  String get statusLabel {
    if (status == LotStatus.occupied) {
      final name = ownerName?.trim() ?? '';
      if (name.isNotEmpty) return name;
      return 'Occupied';
    }
    switch (status) {
      case LotStatus.vacant:
        return 'Unassigned';
      case LotStatus.forSale:
        return 'For Sale';
      case LotStatus.reserved:
        return 'Reserved';
      case LotStatus.occupied:
        return 'Occupied'; // unreachable, handled above
    }
  }
}

class _ZoomDebugOverlay extends StatelessWidget {
  final _ZoomDebugInfo info;

  const _ZoomDebugOverlay({required this.info});

  @override
  Widget build(BuildContext context) {
    String pct(double v) => '${(v * 100).toStringAsFixed(0)}%';
    String px(double v) => v.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          height: 1.5,
          fontFamily: 'monospace',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Block ${info.block}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${info.lotsFound} lots found'
              '${info.lotsExcluded > 0 ? ' · ${info.lotsExcluded} excluded (outlier)' : ''}',
            ),
            Text(
              'Center: ${pct(info.centerPercent.dx)}, ${pct(info.centerPercent.dy)}',
            ),
            Text('Scale: ${info.scale.toStringAsFixed(2)}x'),
            Text(
              'Content: ${px(info.contentSize.width)}x${px(info.contentSize.height)} '
              '· Viewport: ${px(info.viewportSize.width)}x${px(info.viewportSize.height)}',
            ),
            if (info.lots.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('— Lots —',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              for (final lot in info.lots)
                Text(
                  'Lot ${lot.lotNumber}: ${lot.statusLabel}'
                  '${lot.isOutlier ? '  ⚠ likely misplaced' : ''}',
                  style: TextStyle(
                    color: lot.isOutlier ? Colors.amber : Colors.white,
                    fontWeight:
                        lot.isOutlier ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Live preview while tracing a new lot boundary ─────────────────────
class _DigitizePreviewPainter extends CustomPainter {
  final List<Offset> points; // normalized 0.0-1.0
  final Size contentSize;

  _DigitizePreviewPainter({required this.points, required this.contentSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final scaled = points
        .map((p) => Offset(p.dx * contentSize.width, p.dy * contentSize.height))
        .toList();

    if (scaled.length > 1) {
      final path = Path()..moveTo(scaled.first.dx, scaled.first.dy);
      for (final p in scaled.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      if (scaled.length >= 3) {
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = _accent.withOpacity(0.25)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    for (final p in scaled) {
      canvas.drawCircle(
        p,
        5,
        Paint()..color = const Color(0xFFCC2200),
      );
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DigitizePreviewPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

// ── Paints all digitized polygon lots at once ───────────────────────────
class _PolygonPainter extends CustomPainter {
  final List<LotModel> lots;
  final Size contentSize;
  final Color Function(LotStatus) colorFor;

  _PolygonPainter({
    required this.lots,
    required this.contentSize,
    required this.colorFor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final lot in lots) {
      final points = lot.polygonPoints!;
      final path = Path();
      final first = points.first;
      path.moveTo(first.x * contentSize.width, first.y * contentSize.height);
      for (final p in points.skip(1)) {
        path.lineTo(p.x * contentSize.width, p.y * contentSize.height);
      }
      path.close();

      final color = colorFor(lot.status);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.28)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter oldDelegate) {
    return oldDelegate.lots != lots || oldDelegate.contentSize != contentSize;
  }
}

// ── Selected-block spotlight — matches Phase 1's map_pin_view.dart ────
// Dims the whole map with a translucent black layer, then cuts the
// selected block's exact shape out of that layer (BlendMode.clear),
// so only the background map art around it dims. Lot colors are
// painted in a separate layer on top of this and are never touched
// here — every lot keeps its normal status color always.
class _BlockSpotlightPainter extends CustomPainter {
  final List<List<Offset>> polygonShapes; // normalized 0..1 points
  final List<Offset> pinCenters; // normalized 0..1 centers

  const _BlockSpotlightPainter({
    required this.polygonShapes,
    required this.pinCenters,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (polygonShapes.isEmpty && pinCenters.isEmpty) return;

    canvas.saveLayer(Offset.zero & size, Paint());

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withOpacity(0.45),
    );

    final clearPaint = Paint()..blendMode = BlendMode.clear;

    for (final points in polygonShapes) {
      if (points.isEmpty) continue;

      final path = Path();
      final first = points.first;
      path.moveTo(first.dx * size.width, first.dy * size.height);
      for (int i = 1; i < points.length; i++) {
        final p = points[i];
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      path.close();

      canvas.drawPath(path, clearPaint);
    }

    // Pin lots have no digitized boundary to cut out — clear a circle
    // around the marker instead, matching its own on-screen size.
    for (final center in pinCenters) {
      canvas.drawCircle(
        Offset(center.dx * size.width, center.dy * size.height),
        20,
        clearPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BlockSpotlightPainter oldDelegate) {
    return true;
  }
}

// ── Empty state: no image uploaded yet for this phase ─────────────────────
class _EmptyMapState extends StatelessWidget {
  final String phaseName;
  final bool canEdit;
  final bool uploading;
  final double progress;
  final VoidCallback onUpload;

  const _EmptyMapState({
    required this.phaseName,
    required this.canEdit,
    required this.uploading,
    required this.progress,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No map uploaded yet for $phaseName',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: _navy)),
          const SizedBox(height: 6),
          Text(
            'Upload the subdivision map image for this phase\n'
            'once it\'s ready, and lots can be pinned onto it.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
          ),
          if (canEdit) ...[
            const SizedBox(height: 20),
            if (uploading)
              Column(
                children: [
                  SizedBox(
                    width: 160,
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload_outlined, size: 18),
                label: const Text('Upload Map Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}