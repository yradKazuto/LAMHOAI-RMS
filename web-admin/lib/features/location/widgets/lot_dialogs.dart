import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/models/lot_model.dart';
import '../../../core/services/lot_service.dart';

const _navy = Color(0xFF0D2A52);
const _blue = Color(0xFF1565C0);
const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _red = Color(0xFFC62828);
const _grey = Color(0xFF757575);

/// ================================================================
/// OCCUPIED LOT DIALOG
/// ================================================================

class OccupiedLotDialog extends StatelessWidget {
  final LotModel lot;
  final bool canEdit;
  final String? currentUserId;

  final Future<void> Function()? onUnassign;

  /// Loads members that can be selected as the new owner.
  final Future<List<MapEntry<String, String>>> Function()?
      loadAssignableMembers;

  /// Opens the member details screen for the current owner.
  final Future<void> Function()? onViewMember;

  const OccupiedLotDialog({
    super.key,
    required this.lot,
    required this.canEdit,
    this.currentUserId,
    this.onUnassign,
    this.loadAssignableMembers,
    this.onViewMember,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding:
          const EdgeInsets.fromLTRB(24, 20, 24, 8),
      contentPadding:
          const EdgeInsets.fromLTRB(24, 8, 24, 8),
      actionsPadding:
          const EdgeInsets.fromLTRB(16, 8, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),

      // ============================================================
      // TITLE
      // ============================================================

      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.home_work_outlined,
              color: _green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Lot ${lot.lotNumber}',
              style: const TextStyle(
                color: _navy,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),

      // ============================================================
      // CONTENT
      // ============================================================

      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _statusBanner(
                icon: Icons.check_circle_outline,
                title: 'Occupied',
                color: _green,
              ),

              const SizedBox(height: 18),

              _sectionTitle(
                'Lot Information',
              ),

              const SizedBox(height: 10),

              _infoRow(
                Icons.layers_outlined,
                'Phase',
                _displayValue(lot.phase),
              ),

              _infoRow(
                Icons.grid_view_rounded,
                'Block',
                _displayValue(lot.block),
              ),

              _infoRow(
                Icons.tag,
                'Lot Number',
                _displayValue(lot.lotNumber),
              ),

              if (lot.areaSqm != null)
                _infoRow(
                  Icons.square_foot,
                  'Lot Area',
                  '${_formatNumber(lot.areaSqm!)} sqm',
                ),

              const SizedBox(height: 18),

              _sectionTitle(
                'Owner Information',
              ),

              const SizedBox(height: 10),

              _infoRow(
                Icons.person_outline,
                'Owner',
                _displayValue(lot.ownerName),
              ),

              if (lot.uid != null &&
                  lot.uid!.trim().isNotEmpty)
                _infoRow(
                  Icons.badge_outlined,
                  'User ID',
                  lot.uid!,
                ),

              if (lot.contactNumber != null &&
                  lot.contactNumber!
                      .trim()
                      .isNotEmpty)
                _infoRow(
                  Icons.phone_outlined,
                  'Contact',
                  lot.contactNumber!,
                ),

              if (lot.notes != null &&
                  lot.notes!
                      .trim()
                      .isNotEmpty) ...[
                const SizedBox(height: 18),

                _sectionTitle(
                  'Notes',
                ),

                const SizedBox(height: 8),

                _notesBox(
                  lot.notes!,
                ),
              ],
            ],
          ),
        ),
      ),

      // ============================================================
      // ACTIONS
      // ============================================================

      actions: [
        if (onViewMember != null &&
            lot.uid != null &&
            lot.uid!.trim().isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              await onViewMember!();
            },
            icon: const Icon(
              Icons.person_outline,
            ),
            label: const Text('View Member'),
          ),

        if (canEdit &&
            loadAssignableMembers != null)
          TextButton.icon(
            onPressed: () async {
              await _changeOwner(context);
            },
            icon: const Icon(
              Icons.swap_horiz,
            ),
            label: const Text('Change Owner'),
          ),

        if (canEdit &&
            onUnassign != null)
          TextButton.icon(
            onPressed: () async {
              final confirmed =
                  await _confirmUnassign(
                context,
              );

              if (!confirmed) return;

              try {
                await onUnassign!();

                if (!context.mounted) {
                  return;
                }

                Navigator.of(context).pop(true);
              } catch (e) {
                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to unassign owner:\n$e',
                    ),
                    backgroundColor: _red,
                  ),
                );
              }
            },
            icon: const Icon(
              Icons.person_remove_outlined,
              color: _red,
            ),
            label: const Text(
              'Unassign',
              style: TextStyle(
                color: _red,
              ),
            ),
          ),

        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _changeOwner(
    BuildContext context,
  ) async {
    if (loadAssignableMembers == null) {
      return;
    }

    try {
      final members =
          await loadAssignableMembers!();

      if (!context.mounted) return;

      if (members.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'No members are available to assign.',
            ),
          ),
        );
        return;
      }

      String query = '';

      final selected =
          await showDialog<MapEntry<String, String>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              context,
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
                  'Change Owner',
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
                          prefixIcon:
                              Icon(Icons.search),
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
                                      filtered[index];

                                  return ListTile(
                                    leading:
                                        const CircleAvatar(
                                      child: Icon(
                                        Icons.person,
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

      await LotService().assignOwner(
        lotId: lot.id,
        uid: selected.key,
        ownerName: selected.value,
        updatedBy: currentUserId ?? '',
      );

      if (!context.mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to change owner.\n$e',
          ),
          backgroundColor: _red,
        ),
      );
    }
  }

  Future<bool> _confirmUnassign(
    BuildContext context,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
          title:
              const Text('Unassign Owner?'),
          content: Text(
            'Remove the owner from '
            '${lot.phase} • '
            'Block ${lot.block} • '
            'Lot ${lot.lotNumber}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              style:
                  FilledButton.styleFrom(
                backgroundColor: _red,
              ),
              child:
                  const Text('Unassign'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

/// ================================================================
/// VACANT / RESERVED LOT DIALOG
/// ================================================================

class VacantLotDialog extends StatefulWidget {
  final LotModel lot;
  final bool canEdit;
  final String currentUserId;

  final Future<List<MapEntry<String, String>>>
      Function() loadAssignableMembers;

  const VacantLotDialog({
    super.key,
    required this.lot,
    required this.canEdit,
    required this.currentUserId,
    required this.loadAssignableMembers,
  });

  @override
  State<VacantLotDialog> createState() =>
      _VacantLotDialogState();
}

class _VacantLotDialogState
    extends State<VacantLotDialog> {
  final LotService _service =
      LotService();

  final _formKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _blockController;

  late final TextEditingController
      _lotController;

  late final TextEditingController
      _areaController;

  late final TextEditingController
      _priceController;

  late final TextEditingController
      _contactController;

  late final TextEditingController
      _notesController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _blockController =
        TextEditingController(
      text: widget.lot.block.isNotEmpty
          ? widget.lot.block
          : 'Block 1',
    );

    _lotController =
        TextEditingController(
      text: widget.lot.lotNumber,
    );

    _areaController =
        TextEditingController(
      text: widget.lot.areaSqm == null
          ? ''
          : _formatNumber(
              widget.lot.areaSqm!,
            ),
    );

    _priceController =
        TextEditingController(
      text: widget.lot.price == null
          ? ''
          : widget.lot.price!
              .toStringAsFixed(2),
    );

    _contactController =
        TextEditingController(
      text:
          widget.lot.contactNumber ?? '',
    );

    _notesController =
        TextEditingController(
      text: widget.lot.notes ?? '',
    );
  }

  @override
  void dispose() {
    _blockController.dispose();
    _lotController.dispose();
    _areaController.dispose();
    _priceController.dispose();
    _contactController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  bool get _isReserved =>
      widget.lot.status ==
      LotStatus.reserved;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding:
          const EdgeInsets.fromLTRB(
        24,
        20,
        24,
        8,
      ),
      contentPadding:
          const EdgeInsets.fromLTRB(
        24,
        8,
        24,
        8,
      ),
      actionsPadding:
          const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),

      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: _blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Lot ${widget.lot.lotNumber}',
              style: const TextStyle(
                color: _navy,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),

      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _statusBanner(
                  icon: _isReserved
                      ? Icons.lock_clock
                      : Icons.circle_outlined,
                  title: _isReserved
                      ? 'Reserved'
                      : 'Vacant',
                  color: _isReserved
                      ? _orange
                      : _blue,
                ),

                const SizedBox(height: 18),

                _sectionTitle(
                  'Lot Information',
                ),

                const SizedBox(height: 12),

                // Phase is intentionally NOT an editable field here.
                // It's fixed to whichever phase this lot already
                // belongs to — editing it as free text previously let
                // a lot get silently re-tagged into the wrong phase
                // (e.g. a Phase 2 lot ending up in Phase 1's list)
                // whenever this shared dialog was opened from a
                // different phase's map screen.
                _infoRow(
                  Icons.layers_outlined,
                  'Phase',
                  _displayValue(widget.lot.phase),
                ),

                const SizedBox(height: 12),

                _textField(
                  controller: _blockController,
                  label: 'Block',
                  hint: 'Block 1',
                  icon: Icons.grid_view_rounded,
                  enabled: widget.canEdit,
                ),

                const SizedBox(height: 12),

                _textField(
                  controller: _lotController,
                  label: 'Lot Number',
                  hint: '1 - 59',
                  icon: Icons.tag,
                  enabled:
                      widget.canEdit,
                  keyboardType:
                      TextInputType.number,
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
                  controller: _areaController,
                  label: 'Lot Area (sqm)',
                  hint: 'e.g. 120',
                  icon: Icons.square_foot,
                  enabled:
                      widget.canEdit,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                ),

                const SizedBox(height: 18),

                _sectionTitle(
                  'Ownership',
                ),

                const SizedBox(height: 10),

                _infoRow(
                  Icons.person_outline,
                  'Owner',
                  _displayValue(
                    widget.lot.ownerName,
                  ),
                ),

                if (widget.lot.uid != null &&
                    widget.lot.uid!
                        .trim()
                        .isNotEmpty)
                  _infoRow(
                    Icons.badge_outlined,
                    'User ID',
                    widget.lot.uid!,
                  ),

                const SizedBox(height: 10),

                if (widget.canEdit)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _saving
                              ? null
                              : _openAssignOwner,
                      icon: const Icon(
                        Icons.person_add_alt_1,
                      ),
                      label: Text(
                        widget.lot.uid != null &&
                                widget.lot.uid!
                                    .trim()
                                    .isNotEmpty
                            ? 'Change Assigned Member'
                            : 'Assign Existing Member',
                      ),
                    ),
                  ),

                const SizedBox(height: 18),

                _sectionTitle(
                  'Sale Information',
                ),

                const SizedBox(height: 10),

                _textField(
                  controller:
                      _priceController,
                  label: 'Price',
                  hint: 'Optional',
                  icon:
                      Icons.payments_outlined,
                  enabled:
                      widget.canEdit,
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
                  icon:
                      Icons.phone_outlined,
                  enabled:
                      widget.canEdit,
                ),

                const SizedBox(height: 18),

                _sectionTitle(
                  'Additional Details',
                ),

                const SizedBox(height: 10),

                _textField(
                  controller:
                      _notesController,
                  label: 'Notes',
                  hint:
                      'Enter additional information...',
                  icon:
                      Icons.notes_outlined,
                  enabled:
                      widget.canEdit,
                  maxLines: 4,
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
                  Navigator.of(
                    context,
                  ).pop();
                },
          child:
              const Text('Close'),
        ),

        if (widget.canEdit)
          OutlinedButton(
            onPressed:
                _saving
                    ? null
                    : _markForSale,
            child:
                const Text('Mark For Sale'),
          ),

        if (widget.canEdit)
          FilledButton.icon(
            onPressed:
                _saving
                    ? null
                    : _save,
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
                    Icons.save_outlined,
                  ),
            label: Text(
              _saving
                  ? 'Saving...'
                  : 'Save Details',
            ),
            style:
                FilledButton.styleFrom(
              backgroundColor: _blue,
            ),
          ),
      ],
    );
  }

  // ================================================================
  // SAVE DETAILS
  // ================================================================

  Future<void> _save() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final areaText =
        _areaController.text.trim();

    double? area;

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

    final priceText =
        _priceController.text.trim();

    if (priceText.isNotEmpty) {
      price = double.tryParse(priceText);

      if (price == null) {
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
      final data =
          <String, dynamic>{
        // Phase is never re-derived from user input here — it stays
        // whatever it already was on the lot. See the note above the
        // Phase display field for why.
        'phase': widget.lot.phase,

        'block':
            _blockController.text.trim(),

        'lotNumber':
            _lotController.text.trim(),

        'areaSqm': area,

        'price': price,

        'contactNumber':
            _contactController.text
                    .trim()
                    .isEmpty
                ? null
                : _contactController
                    .text
                    .trim(),

        'notes':
            _notesController.text
                    .trim()
                    .isEmpty
                ? null
                : _notesController
                    .text
                    .trim(),

        'updatedBy':
            widget.currentUserId,

        'updatedAt':
            Timestamp.now(),
      };

      await _service.updateLot(
        widget.lot.id,
        data,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(
        'Failed to save lot details.\n$e',
      );
    }
  }

  // ================================================================
  // ASSIGN MEMBER
  // ================================================================

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

      final selected =
          await showDialog<
              MapEntry<String, String>>(
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
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
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
                          prefixIcon:
                              Icon(
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

                      const SizedBox(
                        height: 10,
                      ),

                      Expanded(
                        child: filtered
                                .isEmpty
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
                                      child:
                                          Icon(
                                        Icons
                                            .person,
                                      ),
                                    ),
                                    title:
                                        Text(
                                      member
                                          .value,
                                    ),
                                    onTap: () {
                                      Navigator.of(
                                        dialogContext,
                                      ).pop(
                                        member,
                                      );
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
                    child:
                        const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (selected == null) return;

      setState(() {
        _saving = true;
      });

      await _service.assignOwner(
        lotId: widget.lot.id,
        uid: selected.key,
        ownerName: selected.value,
        updatedBy:
            widget.currentUserId,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(
        'Failed to assign member.\n$e',
      );
    }
  }

  // ================================================================
  // MARK FOR SALE
  // ================================================================

  Future<void> _markForSale() async {
    double price = 0;

    final priceText =
        _priceController.text.trim();

    if (priceText.isNotEmpty) {
      final parsed =
          double.tryParse(priceText);

      if (parsed == null ||
          parsed < 0) {
        _showError(
          'Please enter a valid price.',
        );
        return;
      }

      price = parsed;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _service.markForSale(
        lotId: widget.lot.id,
        price: price,
        contactNumber:
            _contactController.text
                .trim(),
        updatedBy:
            widget.currentUserId,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(
        'Failed to mark lot for sale.\n$e',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _red,
      ),
    );
  }
}

/// ================================================================
/// FOR SALE LOT DIALOG
/// ================================================================

class ForSaleLotDialog extends StatefulWidget {
  final LotModel lot;
  final bool canEdit;
  final String currentUserId;

  final Future<List<MapEntry<String, String>>>
      Function() loadAssignableMembers;

  const ForSaleLotDialog({
    super.key,
    required this.lot,
    required this.canEdit,
    required this.currentUserId,
    required this.loadAssignableMembers,
  });

  @override
  State<ForSaleLotDialog> createState() =>
      _ForSaleLotDialogState();
}

class _ForSaleLotDialogState
    extends State<ForSaleLotDialog> {
  final LotService _service =
      LotService();

  late final TextEditingController
      _priceController;

  late final TextEditingController
      _contactController;

  late final TextEditingController
      _notesController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _priceController =
        TextEditingController(
      text: widget.lot.price == null
          ? ''
          : widget.lot.price!
              .toStringAsFixed(2),
    );

    _contactController =
        TextEditingController(
      text:
          widget.lot.contactNumber ?? '',
    );

    _notesController =
        TextEditingController(
      text: widget.lot.notes ?? '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _contactController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding:
          const EdgeInsets.fromLTRB(
        24,
        20,
        24,
        8,
      ),
      contentPadding:
          const EdgeInsets.fromLTRB(
        24,
        8,
        24,
        8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),

      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  _orange.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sell_outlined,
              color: _orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Lot ${widget.lot.lotNumber}',
              style: const TextStyle(
                color: _navy,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),

      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _statusBanner(
                icon: Icons.sell_outlined,
                title: 'For Sale',
                color: _orange,
              ),

              const SizedBox(height: 18),

              _sectionTitle(
                'Lot Information',
              ),

              const SizedBox(height: 10),

              _infoRow(
                Icons.layers_outlined,
                'Phase',
                _displayValue(
                  widget.lot.phase,
                ),
              ),

              _infoRow(
                Icons.grid_view_rounded,
                'Block',
                _displayValue(
                  widget.lot.block,
                ),
              ),

              _infoRow(
                Icons.tag,
                'Lot Number',
                widget.lot.lotNumber,
              ),

              if (widget.lot.areaSqm !=
                  null)
                _infoRow(
                  Icons.square_foot,
                  'Lot Area',
                  '${_formatNumber(widget.lot.areaSqm!)} sqm',
                ),

              const SizedBox(height: 18),

              _sectionTitle(
                'Sale Information',
              ),

              const SizedBox(height: 12),

              _textField(
                controller:
                    _priceController,
                label: 'Price',
                hint:
                    'Enter selling price',
                icon:
                    Icons.payments_outlined,
                enabled:
                    widget.canEdit,
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
                label:
                    'Contact Number',
                hint:
                    'Enter contact number',
                icon:
                    Icons.phone_outlined,
                enabled:
                    widget.canEdit,
              ),

              const SizedBox(height: 18),

              _sectionTitle(
                'Ownership',
              ),

              const SizedBox(height: 10),

              _infoRow(
                Icons.person_outline,
                'Owner',
                _displayValue(
                  widget.lot.ownerName,
                ),
              ),

              if (widget.lot.uid != null &&
                  widget.lot.uid!
                      .trim()
                      .isNotEmpty)
                _infoRow(
                  Icons.badge_outlined,
                  'User ID',
                  widget.lot.uid!,
                ),

              if (widget.canEdit)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _saving
                            ? null
                            : _openAssignOwner,
                    icon: const Icon(
                      Icons.person_add_alt_1,
                    ),
                    label:
                        const Text(
                      'Assign Existing Member',
                    ),
                  ),
                ),

              const SizedBox(height: 18),

              _sectionTitle(
                'Notes',
              ),

              const SizedBox(height: 10),

              _textField(
                controller:
                    _notesController,
                label: 'Notes',
                hint: 'Optional notes',
                icon:
                    Icons.notes_outlined,
                enabled:
                    widget.canEdit,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed:
              _saving
                  ? null
                  : () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
          child:
              const Text('Close'),
        ),

        if (widget.canEdit)
          TextButton(
            onPressed:
                _saving
                    ? null
                    : _delist,
            style:
                TextButton.styleFrom(
              foregroundColor: _red,
            ),
            child:
                const Text('Delist'),
          ),

        if (widget.canEdit)
          FilledButton(
            onPressed:
                _saving
                    ? null
                    : _save,
            style:
                FilledButton.styleFrom(
              backgroundColor: _orange,
            ),
            child: Text(
              _saving
                  ? 'Saving...'
                  : 'Save',
            ),
          ),
      ],
    );
  }

  Future<void> _save() async {
    final price =
        double.tryParse(
      _priceController.text.trim(),
    );

    if (price == null ||
        price < 0) {
      _showError(
        'Please enter a valid price.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _service.markForSale(
        lotId: widget.lot.id,
        price: price,
        contactNumber:
            _contactController.text
                .trim(),
        updatedBy:
            widget.currentUserId,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(
        'Failed to update lot.\n$e',
      );
    }
  }

  Future<void> _delist() async {
    setState(() {
      _saving = true;
    });

    try {
      await _service.delist(
        lotId: widget.lot.id,
        updatedBy:
            widget.currentUserId,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(
        'Failed to delist lot.\n$e',
      );
    }
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
          'No members are available.',
        );
        return;
      }

      String query = '';

      final selected =
          await showDialog<
              MapEntry<String, String>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              context,
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
                title:
                    const Text(
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
                          prefixIcon:
                              Icon(
                            Icons.search,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        onChanged:
                            (value) {
                          setDialogState(() {
                            query =
                                value;
                          });
                        },
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Expanded(
                        child: filtered
                                .isEmpty
                            ? const Center(
                                child:
                                    Text(
                                  'No members found.',
                                ),
                              )
                            : ListView.builder(
                                itemCount:
                                    filtered.length,
                                itemBuilder:
                                    (_, index) {
                                  final member =
                                      filtered[
                                          index];

                                  return ListTile(
                                    leading:
                                        const CircleAvatar(
                                      child:
                                          Icon(
                                        Icons
                                            .person,
                                      ),
                                    ),
                                    title:
                                        Text(
                                      member
                                          .value,
                                    ),
                                    onTap: () {
                                      Navigator.of(
                                        dialogContext,
                                      ).pop(
                                        member,
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
            },
          );
        },
      );

      if (selected == null) return;

      setState(() {
        _saving = true;
      });

      await _service.assignOwner(
        lotId: widget.lot.id,
        uid: selected.key,
        ownerName: selected.value,
        updatedBy:
            widget.currentUserId,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(
        'Failed to assign member.\n$e',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _red,
      ),
    );
  }
}

/// ================================================================
/// ADD LOT DIALOG
/// ================================================================

class AddLotDialog extends StatefulWidget {
  final String phase;
  final String block;
  final String lotNumber;

  final double? mapX;
  final double? mapY;

  final String currentUserId;

  const AddLotDialog({
    super.key,
    required this.phase,
    required this.block,
    required this.lotNumber,
    required this.currentUserId,
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
      _blockController;

  late final TextEditingController
      _lotController;

  late final TextEditingController
      _areaController;

  late final TextEditingController
      _notesController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

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
  }

  @override
  void dispose() {
    _blockController.dispose();
    _lotController.dispose();
    _areaController.dispose();
    _notesController.dispose();

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
                // Phase is fixed to whichever screen this dialog was
                // opened from (widget.phase) and is not user-editable —
                // letting it be freely typed here previously allowed a
                // lot to be created under the wrong phase (e.g. a lot
                // typed while working in Phase 2 silently landing in
                // Phase 1's list).
                _infoRow(
                  Icons.layers_outlined,
                  'Phase',
                  _displayValue(widget.phase),
                ),

                const SizedBox(height: 12),

                _textField(
                  controller:
                      _blockController,
                  label: 'Block',
                  hint: 'Block 1',
                  icon:
                      Icons.grid_view_rounded,
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

                const SizedBox(height: 12),

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

  Future<void> _createLot() async {
    if (!_formKey.currentState!
        .validate()) {
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

    setState(() {
      _saving = true;
    });

    try {
      await _service.createLotAtPin(
        phase: widget.phase,
        block:
            _blockController.text.trim(),
        lotNumber:
            _lotController.text.trim(),
        mapX: widget.mapX ?? 0,
        mapY: widget.mapY ?? 0,
        updatedBy:
            widget.currentUserId,
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
        backgroundColor: _red,
      ),
    );
  }
}

/// ================================================================
/// SHARED UI
/// ================================================================

Widget _sectionTitle(
  String title,
) {
  return Text(
    title,
    style: const TextStyle(
      color: _navy,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  );
}

Widget _statusBanner({
  required IconData icon,
  required String title,
  required Color color,
}) {
  return Container(
    width: double.infinity,
    padding:
        const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius:
          BorderRadius.circular(10),
      border: Border.all(
        color: color.withOpacity(0.25),
      ),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight:
                FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

Widget _infoRow(
  IconData icon,
  String label,
  String value,
) {
  return Padding(
    padding:
        const EdgeInsets.only(
      bottom: 10,
    ),
    child: Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Icon(
            icon,
            size: 18,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _notesBox(
  String text,
) {
  return Container(
    width: double.infinity,
    padding:
        const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F8FA),
      borderRadius:
          BorderRadius.circular(10),
      border: Border.all(
        color: const Color(0xFFE2E6EA),
      ),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: Colors.black87,
        height: 1.4,
      ),
    ),
  );
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

String _displayValue(
  String? value,
) {
  if (value == null ||
      value.trim().isEmpty) {
    return 'Not assigned';
  }

  return value;
}

String _formatNumber(
  double value,
) {
  if (value ==
      value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(2);
}