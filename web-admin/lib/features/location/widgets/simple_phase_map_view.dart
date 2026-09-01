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

const _navy = Color(0xFF0D2A52);
const _blue = Color(0xFF1565C0);
const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _purple = Color(0xFF6A1B9A);
const _grey = Color(0xFF9E9E9E);
const _accent = Color(0xFF2E6BE6);

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
  String? _selectedBlock;
  static const double _minScale = 0.3;
  static const double _maxScale = 8.0;

  // Manual zoom-center override per block. Long-pressing a block in the
  // panel arms this, then the next map tap saves that point (normalized
  // 0..1) as where "zoom to this block" should center on — sidesteps
  // trying to compute it automatically from stored lot/polygon data,
  // which kept landing off. Session-only for now (not persisted).
  String? _pickingFocusForBlock;
  final Map<String, Offset> _blockFocusPoints = {};

  // ── Native digitize mode ────────────────────────────────────────────
  bool _digitizing = false;
  final List<Offset> _digitizePoints = []; // normalized 0.0-1.0 points

  static const double _contentWidth = 1000;

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
    _zoomCurve =
        CurvedAnimation(parent: _zoomAnimController, curve: Curves.easeInOutCubic);
    // Registered ONCE — the previous version added a new listener on
    // every zoom call and never removed the old ones, which piled up
    // over repeated taps (still functionally masked by ordering, but
    // wasteful and a real bug worth fixing regardless).
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

  void _selectBlock(String block) {
    final deselecting = _selectedBlock == block;
    setState(() => _selectedBlock = deselecting ? null : block);

    if (deselecting) {
      _animateToMatrix(Matrix4.identity());
      return;
    }

    // A manually-set focus point (long-press a block, then tap the
    // map) always wins over the automatic guess — it's exact by
    // construction, since it's just "where the admin tapped."
    final savedFocus = _blockFocusPoints[block];
    if (savedFocus != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _zoomToNormalizedPoint(savedFocus, scale: 3.2),
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _zoomToBlock(block));
    }
  }

  /// Arms/disarms "tap the map to set this block's zoom center" mode.
  /// Long-pressing the same block again cancels it.
  void _toggleFocusPicking(String block) {
    if (_pickingFocusForBlock == block) {
      setState(() => _pickingFocusForBlock = null);
      return;
    }
    setState(() => _pickingFocusForBlock = block);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('Tap the map to set the zoom center for "$block"'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  TickerFuture _animateToMatrix(Matrix4 target) {
    _zoomTween = Matrix4Tween(
      begin: _transformController.value,
      end: target,
    );
    _zoomAnimController.reset();
    return _zoomAnimController.forward();
  }

  /// Best-effort automatic framing from stored lot/polygon data —
  /// used only when no manual focus point has been set for this block.
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

    final points = <Offset>[];
    for (final lot in widget.lots) {
      if (lot.block.trim().toLowerCase() != block.trim().toLowerCase()) {
        continue;
      }
      if (lot.hasPolygon) {
        for (final p in lot.polygonPoints!) {
          points.add(Offset(
            p.x * contentSize.width,
            p.y * contentSize.height,
          ));
        }
      } else if (lot.mapX != null && lot.mapY != null) {
        points.add(Offset(
          lot.mapX! * contentSize.width,
          lot.mapY! * contentSize.height,
        ));
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

    // A block that's just a single pin lot (no digitized boundary yet)
    // collapses to a zero-size box — pad it so we still zoom in on it
    // instead of bailing out below.
    if (maxX - minX <= 0 || maxY - minY <= 0) {
      const pad = 60.0;
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

    final centerLocal = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    const paddingFactor = 2.5;
    final scaleByWidth =
        (viewportSize.width / (boxWidth * paddingFactor))
            .clamp(_minScale, _maxScale);
    final scaleByHeight =
        (viewportSize.height / (boxHeight * paddingFactor))
            .clamp(_minScale, _maxScale);
    final scale = scaleByWidth < scaleByHeight ? scaleByWidth : scaleByHeight;

    _zoomToContentPoint(centerLocal, scale: scale);
  }

  /// Converts a normalized (0..1) lot-style point to content-local
  /// pixels and zooms to it. Used for manually-set focus points.
  void _zoomToNormalizedPoint(Offset normalized, {required double scale}) {
    final contentBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (contentBox == null || !contentBox.hasSize) return;
    final contentSize = contentBox.size;
    _zoomToContentPoint(
      Offset(
        normalized.dx * contentSize.width,
        normalized.dy * contentSize.height,
      ),
      scale: scale,
    );
  }

  /// Centers the viewport on a CONTENT-LOCAL point at the given scale.
  ///
  /// Rather than assuming any particular relationship between
  /// `_transformController.value` and what actually ends up on screen
  /// (an assumption that kept being wrong — this view has no Center()
  /// wrapper, and `constrained: true` may be fitting the content
  /// underneath the live matrix in a way that isn't visible in the
  /// controller's value), this reads Flutter's own EXACT composed
  /// transform for the current frame via `getTransformTo`, and backs
  /// out exactly what's "hidden" outside the live matrix — no
  /// approximation, no sampling, no guessing.
  void _zoomToContentPoint(Offset contentLocal, {required double scale}) {
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

    final viewportSize = viewportBox.size;
    final viewportCenter =
        Offset(viewportSize.width / 2, viewportSize.height / 2);

    final Matrix4 total = contentBox.getTransformTo(viewportBox);
    final Matrix4 live = _transformController.value;

    Matrix4 hiddenBase;
    Matrix4 hiddenBaseInverse;
    try {
      final liveInverse = Matrix4.inverted(live);
      hiddenBase = total.multiplied(liveInverse);
      hiddenBaseInverse = Matrix4.inverted(hiddenBase);
    } catch (_) {
      // Singular matrix (e.g. mid-layout) — skip this attempt rather
      // than crash; the next tap will just try again.
      return;
    }

    final desiredUnderLive =
        MatrixUtils.transformPoint(hiddenBaseInverse, viewportCenter);

    final clampedScale = scale.clamp(_minScale, _maxScale);
    final translate = desiredUnderLive - contentLocal * clampedScale;

    if (!translate.dx.isFinite || !translate.dy.isFinite) return;

    final target = Matrix4.identity()
      ..translate(translate.dx, translate.dy)
      ..scale(clampedScale);

    _animateToMatrix(target).whenComplete(() => _snapToExactCenter(contentLocal));
  }

  /// Runs once after the main zoom animation finishes. Measures exactly
  /// where `contentLocal` actually ended up on screen and, if it's off
  /// by more than a pixel or two, nudges the transform the rest of the
  /// way using a freshly-sampled LOCAL scale (accurate for a small
  /// correction like this even if whatever caused the original drift —
  /// still unclear — isn't something the upfront math accounted for).
  void _snapToExactCenter(Offset contentLocal) {
    if (!mounted) return;

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

    final viewportSize = viewportBox.size;
    final viewportCenter =
        Offset(viewportSize.width / 2, viewportSize.height / 2);

    Offset screenPosOf(Offset local) =>
        viewportBox.globalToLocal(contentBox.localToGlobal(local));

    final actualScreen = screenPosOf(contentLocal);
    final error = viewportCenter - actualScreen;

    if (error.distance < 1.5) return; // already dead-on

    const probe = 40.0;
    final sx = screenPosOf(contentLocal + const Offset(probe, 0));
    final sy = screenPosOf(contentLocal + const Offset(0, probe));
    final localScaleX = (sx.dx - actualScreen.dx) / probe;
    final localScaleY = (sy.dy - actualScreen.dy) / probe;

    if (localScaleX.abs() < 1e-6 || localScaleY.abs() < 1e-6) return;

    final delta = Offset(error.dx / localScaleX, error.dy / localScaleY);
    if (!delta.dx.isFinite || !delta.dy.isFinite) return;

    final corrected = _transformController.value.clone()
      ..translate(delta.dx, delta.dy);
    _transformController.value = corrected;
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
      builder: (_) => AlertDialog(
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (blockController.text.trim().isEmpty ||
                  lotController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
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

    // Picking a manual zoom-center for a block takes priority over
    // every other tap behavior while active.
    if (_pickingFocusForBlock != null) {
      final block = _pickingFocusForBlock!;
      final point = Offset(nx, ny);
      setState(() {
        _blockFocusPoints[block] = point;
        _pickingFocusForBlock = null;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Zoom center set for "$block"')),
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _zoomToNormalizedPoint(point, scale: 3.2),
      );
      return;
    }

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
            final contentHeight = _aspectRatio == null
                ? _contentWidth
                : _contentWidth / _aspectRatio!;
            final contentSize = Size(_contentWidth, contentHeight);

            final polygonLots =
                widget.lots.where((l) => l.hasPolygon).toList();
            final pinLots =
                widget.lots.where((l) => !l.hasPolygon).toList();

            return InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.3,
              maxScale: 8,
              boundaryMargin: const EdgeInsets.all(200),
              child: GestureDetector(
                onTapUp: (d) => _onTapUp(d, contentSize),
                child: SizedBox(
                  key: _contentKey,
                  width: contentSize.width,
                  height: contentSize.height,
                  child: Stack(
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

                      // Simple pin lots — no digitized boundary yet
                      for (final lot in pinLots)
                        if (lot.mapX != null && lot.mapY != null)
                          Positioned(
                            left: lot.mapX! * contentSize.width - 14,
                            top: lot.mapY! * contentSize.height - 14,
                            child: GestureDetector(
                              onTap: () => _openLotDialog(lot),
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
                ),
              ),
            );
          },
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
            'Tap a block to zoom in, tap again to reset. '
            'Long-press to set exactly where it zooms.',
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
                            picking: _pickingFocusForBlock == block,
                            hasCustomFocus: _blockFocusPoints.containsKey(block),
                            onTap: () => _selectBlock(block),
                            onLongPress: () => _toggleFocusPicking(block),
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
    required bool picking,
    required bool hasCustomFocus,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: picking
                ? const Color(0xFFFFF3E0)
                : selected
                    ? const Color(0xFFE8F0FE)
                    : const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: picking
                  ? _orange
                  : selected
                      ? _accent
                      : const Color(0xFFE2E5E9),
              width: picking || selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 16,
                color: picking
                    ? _orange
                    : selected
                        ? _accent
                        : Colors.grey[500],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  picking ? '$label — tap the map…' : label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: picking
                        ? const Color(0xFF8A5A00)
                        : selected
                            ? _navy
                            : Colors.grey[800],
                  ),
                ),
              ),
              // Subtle indicator — no extra button, just a small dot to
              // show this block has a manually-set zoom center.
              if (hasCustomFocus && !picking)
                Icon(
                  Icons.push_pin,
                  size: 12,
                  color: Colors.grey[400],
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