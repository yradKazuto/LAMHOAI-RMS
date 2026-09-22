// features/location/widgets/simple_phase_map_view.dart
//
// Map view for any phase OTHER than "Phase 1". Phase 1 keeps using
// the existing hand-digitized polygon system in map_pin_view.dart,
// unchanged. New phases use this system instead: an uploaded image
// (via Cloudinary, so no app rebuild needed), with lots shown as a
// precise clickable polygon shape traced via the "Digitize Lot" tool
// — tracing is the ONLY way to create a lot here; tapping empty space
// (road, open space, any untraced gap) intentionally does nothing.
// Reuses OccupiedLotDialog / VacantLotDialog from lot_dialogs.dart,
// same as Phase 1's lot management.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:file_picker/file_picker.dart';

import '../../../core/models/lot_model.dart';
import '../../../core/models/phase_map_model.dart';
import '../../../core/services/lot_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/phase_map_service.dart';
import '../../documents/widgets/document_upload_flow.dart' show documentMimeType;
import 'lot_dialogs.dart';
// import 'polygon_import_flow.dart'; // TODO: re-enable once `excel` package is added (flutter pub add excel)

const _navy = Color(0xFF1E293B);
const _blue = Color(0xFF2563EB);
const _green = Color(0xFF16A34A);
const _orange = Color(0xFFF97316);
const _purple = Color(0xFF9333EA);
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
  // Uses the phase's OWN defined block list (set via block count at
  // phase creation, or PhaseMapService.addBlocks) rather than
  // inferring blocks from whichever lots happen to exist — so a
  // brand-new, still-empty block shows up and can be picked from a
  // dropdown before it has any lots in it yet.
  List<String> _getBlocks() {
    final result = List<String>.from(widget.phaseMap.blocks);
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


  /// Counts how many lots currently sit in [block], so rename/remove
  /// can refuse to touch a block that's actually in use.
  int _lotCountForBlock(String block) => widget.lots
      .where((l) => l.block.trim().toLowerCase() == block.trim().toLowerCase())
      .length;

  Future<void> _showManageBlocksDialog() async {
    final addCountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final blocks = _getBlocks();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text('Manage Blocks — ${widget.phaseMap.name}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${blocks.length} block(s) defined.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final block in blocks)
                            _ManageBlockRow(
                              block: block,
                              lotCount: _lotCountForBlock(block),
                              onRename: (newLabel) async {
                                await _phaseMapService.renameBlock(
                                    widget.phaseMap.id, block, newLabel);
                                setDialogState(() {});
                                if (mounted) setState(() {});
                              },
                              onRemove: () async {
                                await _phaseMapService.removeBlock(
                                    widget.phaseMap.id, block);
                                setDialogState(() {});
                                if (mounted) setState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addCountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Add how many blocks',
                            hintText: 'e.g. 2',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          final count = int.tryParse(addCountController.text.trim());
                          if (count == null || count <= 0) return;
                          await _phaseMapService.addBlocks(widget.phaseMap.id, count);
                          addCountController.clear();
                          setDialogState(() {});
                          if (mounted) setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }


  void _selectBlock(String block) {
    final deselecting = _selectedBlock == block;
    setState(() {
      _selectedBlock = deselecting ? null : block;
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
    // can.
    final lotCentroids = <Offset>[];
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
        lotCentroids.add(
          Offset(letterboxX + sx / pts.length, letterboxY + sy / pts.length),
        );
      } else if (lot.mapX != null && lot.mapY != null) {
        lotCentroids.add(
          Offset(
            letterboxX + lot.mapX! * contentSize.width,
            letterboxY + lot.mapY! * contentSize.height,
          ),
        );
      }
    }

    if (lotCentroids.isEmpty) return;

    // Median center (robust to outliers, unlike a mean or a min/max
    // box) — used only to detect which lots are clearly out of place,
    // not as the final target itself. Worth knowing its limit: this
    // only protects against a MINORITY of bad points. If most of a
    // block's lots share the same mistake (e.g. several digitized in
    // the wrong spot), the median gets pulled toward THEM, and the
    // one correctly-placed lot can end up looking like the "outlier"
    // instead.
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

    final points = _digitizePoints.map((o) => LotPoint(o.dx, o.dy)).toList();

    if (LotService.isSelfIntersecting(points)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This boundary crosses itself — some of the traced lines '
              'overlap each other. Clear and re-trace the outline in order '
              'around the lot, without crossing back over an earlier line.',
            ),
            backgroundColor: Color(0xFFCC2200),
          ),
        );
      }
      return;
    }

    // Check against every already-saved, already-digitized lot in this
    // phase — pin-only lots (no polygonPoints) have no real boundary to
    // compare against, so they're skipped inside findOverlappingLots.
    final conflicts = await _lotService.findOverlappingLots(
      phase: widget.phaseMap.name,
      points: points,
    );

    if (conflicts.isNotEmpty) {
      final names = conflicts
          .map((l) => 'Block ${l.block} Lot ${l.lotNumber}')
          .join(', ');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This shape overlaps an existing lot ($names). Adjust the '
              'boundary so it doesn\'t cross into another lot\'s area.',
            ),
            backgroundColor: const Color(0xFFCC2200),
          ),
        );
      }
      return;
    }

    final blocks = _getBlocks();
    String? selectedBlock = blocks.isNotEmpty ? blocks.first : null;
    final lotController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
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
              if (blocks.isEmpty)
                Text(
                  'No blocks defined for this phase yet. Add blocks first '
                  'from the Blocks panel\'s Manage button.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                )
              else
                DropdownButtonFormField<String>(
                  value: selectedBlock,
                  decoration: const InputDecoration(labelText: 'Block'),
                  items: blocks
                      .map((b) => DropdownMenuItem(
                          value: b, child: Text('Block $b')))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBlock = v),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: lotController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                if (selectedBlock == null ||
                    lotController.text.trim().isEmpty) return;
                Navigator.pop(dialogCtx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (selectedBlock == null) return;

    final block = selectedBlock!;
    final lotNumber = lotController.text.trim();

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
    } on LotOverlapException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not save — conflicts found: ${e.conflicts.join('; ')}'),
            backgroundColor: const Color(0xFFCC2200),
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

  // ── Tap handling: check traced lot polygons first, then existing
  // pin lots (if any remain from before digitize-only creation) —
  // empty space (road, open space) does nothing beyond that. ─────────
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

    // Tapping empty space (road, open space, any gap between traced
    // lots) intentionally does nothing beyond this point — digitizing
    // is the only way to create a lot now, so there's no implicit
    // "add a lot here" fallback for an arbitrary tap. A hint nudges an
    // editor toward the actual tool instead of the tap silently being
    // ignored with no feedback at all.
    if (widget.canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nothing here. Use "Digitize Lot" to trace a new lot\'s '
            'boundary — that\'s the only way to add one.',
          ),
        ),
      );
    }
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
        final width = constraints.maxWidth;

        // A fixed side panel leaves the map too cramped to use below
        // this width — show the map full-width instead, with the
        // block list moved into a "Blocks" bottom sheet opened on
        // demand rather than a permanently docked panel.
        if (width < 700) {
          return _buildMapArea(showBlocksButton: true);
        }

        final panelWidth = width < 900 ? 190.0 : 230.0;

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

  Widget _buildMapArea({bool showBlocksButton = false}) {
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
                          child: AnimatedBuilder(
                            animation: _transformController,
                            builder: (context, _) {
                              final scale = _transformController.value
                                  .getMaxScaleOnAxis();
                              // Divide by the current zoom scale so the
                              // border stays visually ~1.6px on screen
                              // regardless of zoom level, instead of
                              // ballooning in lockstep with InteractiveViewer's
                              // own scaling (which is what made it look thick
                              // when zoomed in). Clamped so it can't vanish
                              // at high zoom or turn chunky when zoomed out.
                              final strokeWidth =
                                  (1.6 / scale).clamp(0.4, 3.0);
                              return CustomPaint(
                                painter: _PolygonPainter(
                                  lots: polygonLots,
                                  contentSize: contentSize,
                                  colorFor: _colorFor,
                                  strokeWidth: strokeWidth,
                                ),
                              );
                            },
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

        // ── Blocks toggle (mobile only) ─────────────────────────────────
        if (showBlocksButton)
          Positioned(
            top: 12,
            left: 12,
            child: _buildBlocksToggleButton(),
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

  // ============================================================
  // BLOCK PICKER (mobile) — same block list as the desktop panel,
  // presented as a bottom sheet opened via the "Blocks" toggle.
  // Selecting a block closes the sheet, matching a typical mobile
  // picker rather than staying open like the docked panel.
  // ============================================================

  void _openBlockPickerSheet() {
    final blocks = _getBlocks();

    showModalBottomSheet(
      context: context,
      // Without this, a modal bottom sheet caps itself around ~56% of
      // screen height regardless of content — my fixed chrome (handle,
      // title, subtitle) plus the list's own internal cap together
      // exceeded that, which is what overflowed. isScrollControlled
      // lets the sheet size itself up to the bound below instead.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Blocks',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _navy),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a block to zoom in.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 14),
                // Flexible (not a fixed fraction of screen height) so
                // the chrome above and this list together respect the
                // ConstrainedBox bound — the list scrolls internally
                // if there isn't room for every block.
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: blocks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final block = blocks[i];
                      return _buildBlockButton(
                        label: block,
                        selected: _selectedBlock == block,
                        onTap: () {
                          _selectBlock(block);
                          Navigator.pop(sheetCtx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlocksToggleButton() {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openBlockPickerSheet,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.view_list_outlined, size: 17, color: _navy),
              SizedBox(width: 7),
              Text('Blocks',
                  style: TextStyle(
                      color: _navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

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
          Row(
            children: [
              const Text(
                'Blocks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const Spacer(),
              if (widget.canEdit)
                TextButton.icon(
                  onPressed: _showManageBlocksDialog,
                  icon: const Icon(Icons.settings_outlined, size: 15),
                  label: const Text('Manage'),
                  style: TextButton.styleFrom(
                    foregroundColor: _blue,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
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
                            label: 'Block $block',
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
                        : 'Selected: Block $_selectedBlock',
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

// ── One row in the Manage Blocks dialog ────────────────────────────────
class _ManageBlockRow extends StatefulWidget {
  final String block;
  final int lotCount;
  final Future<void> Function(String newLabel) onRename;
  final Future<void> Function() onRemove;

  const _ManageBlockRow({
    required this.block,
    required this.lotCount,
    required this.onRename,
    required this.onRemove,
  });

  @override
  State<_ManageBlockRow> createState() => _ManageBlockRowState();
}

class _ManageBlockRowState extends State<_ManageBlockRow> {
  bool _renaming = false;
  late final TextEditingController _renameController =
      TextEditingController(text: widget.block);

  bool get _inUse => widget.lotCount > 0;

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_renaming) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _renameController,
                autofocus: true,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check, size: 18, color: _blue),
              tooltip: 'Save',
              onPressed: () async {
                final newLabel = _renameController.text.trim();
                if (newLabel.isEmpty || newLabel == widget.block) {
                  setState(() => _renaming = false);
                  return;
                }
                await widget.onRename(newLabel);
                setState(() => _renaming = false);
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              tooltip: 'Cancel',
              onPressed: () => setState(() => _renaming = false),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('Block ${widget.block}',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          Text(
            _inUse ? '${widget.lotCount} lot(s)' : 'Empty',
            style: TextStyle(
                fontSize: 12,
                color: _inUse ? Colors.grey[600] : Colors.grey[400]),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: _inUse
                ? 'Cannot rename — this block has lots in it'
                : 'Rename',
            onPressed: _inUse ? null : () => setState(() => _renaming = true),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            tooltip: _inUse
                ? 'Cannot remove — this block has lots in it'
                : 'Remove',
            onPressed: _inUse ? null : () => widget.onRemove(),
          ),
        ],
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
  final double strokeWidth;

  _PolygonPainter({
    required this.lots,
    required this.contentSize,
    required this.colorFor,
    this.strokeWidth = 1.6,
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
          ..strokeWidth = strokeWidth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter oldDelegate) {
    return oldDelegate.lots != lots ||
        oldDelegate.contentSize != contentSize ||
        oldDelegate.strokeWidth != strokeWidth;
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