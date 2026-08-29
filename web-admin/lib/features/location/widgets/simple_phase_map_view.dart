// features/location/widgets/simple_phase_map_view.dart
//
// Map view for any phase OTHER than "Phase 1". Phase 1 keeps using
// the existing hand-digitized polygon system in map_pin_view.dart,
// unchanged. New phases use this simpler system instead: an uploaded
// image (via Cloudinary, so no app rebuild needed) with plain
// tap-to-place pins, reusing the same AddLotDialog / OccupiedLotDialog
// / VacantLotDialog already used for Phase 1's lot management.

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

const _navy = Color(0xFF0D2A52);
const _blue = Color(0xFF1565C0);
const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _grey = Color(0xFF9E9E9E);

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

class _SimplePhaseMapViewState extends State<SimplePhaseMapView> {
  final _lotService = LotService();
  final _cloudinary = CloudinaryService();
  final _phaseMapService = PhaseMapService();

  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _contentKey = GlobalKey();

  double? _aspectRatio;
  bool _uploading = false;
  double _uploadProgress = 0;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  static const double _contentWidth = 1000;

  @override
  void initState() {
    super.initState();
    if (widget.phaseMap.hasImage) {
      _resolveImageSize(widget.phaseMap.imageUrl);
    }
  }

  @override
  void didUpdateWidget(covariant SimplePhaseMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phaseMap.imageUrl != oldWidget.phaseMap.imageUrl &&
        widget.phaseMap.hasImage) {
      _aspectRatio = null;
      _resolveImageSize(widget.phaseMap.imageUrl);
    }
  }

  // Resolves the real width/height of the uploaded image so pins are
  // positioned against its true aspect ratio, not an assumed square.
  void _resolveImageSize(String url) {
    final provider = NetworkImage(url);
    _imageStream?.removeListener(_imageListener!);
    _imageStream = provider.resolve(const ImageConfiguration());
    _imageListener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (w > 0 && h > 0) {
        setState(() => _aspectRatio = w / h);
      }
    });
    _imageStream!.addListener(_imageListener!);
  }

  @override
  void dispose() {
    _transformController.dispose();
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    super.dispose();
  }

  Color _colorFor(LotStatus s) {
    switch (s) {
      case LotStatus.occupied: return _blue;
      case LotStatus.forSale:  return _green;
      case LotStatus.reserved: return _orange;
      case LotStatus.vacant:   return _grey;
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

  // ── Tap on empty space → create a new pinned lot here ────────────────
  void _onTapUp(TapUpDetails details, Size contentSize) {
    if (!widget.canEdit) return;

    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(details.globalPosition);
    final nx = (local.dx / contentSize.width).clamp(0.0, 1.0);
    final ny = (local.dy / contentSize.height).clamp(0.0, 1.0);

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
        final contentHeight =
            _aspectRatio == null ? _contentWidth : _contentWidth / _aspectRatio!;
        final contentSize = Size(_contentWidth, contentHeight);

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
                  for (final lot in widget.lots)
                    if (lot.mapX != null && lot.mapY != null)
                      Positioned(
                        left: lot.mapX! * contentSize.width - 14,
                        top: lot.mapY! * contentSize.height - 14,
                        child: GestureDetector(
                          onTap: () => _openLotDialog(lot),
                          child: Tooltip(
                            message: 'Block ${lot.block} • Lot ${lot.lotNumber}',
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
                ],
              ),
            ),
          ),
        );
      },
    );
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