import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/models/lot_model.dart';
import '../../../core/services/lot_service.dart';
import '../../../core/services/rate_service.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/models/lot_ownership_model.dart';
import '../../../core/services/sale_service.dart';
import '../../../core/utils/lot_pricing.dart';
import 'assign_lot_wizard.dart';


const Color _blue = AppColors.primary;
const Color _green = AppColors.success;
const Color _orange = AppColors.warning;
const Color _red = AppColors.danger;
const Color _grey = AppPrimitiveColors.gray500;

/// Strips a redundant leading "Block" (any casing, e.g. "Block 1",
/// "block1") from user-typed input, so the stored value is always
/// just the bare identifier ("1") regardless of whether the person
/// typed "1" or "Block 1". Display code elsewhere adds the "Block "
/// prefix itself — without this, typing "Block 1" ends up stored (and
/// later shown) as "Block Block 1".
String normalizeBlockLabel(String raw) {
  final trimmed = raw.trim();
  final stripped =
      trimmed.replaceFirst(RegExp(r'^block\s*', caseSensitive: false), '').trim();
  return stripped.isEmpty ? trimmed : stripped;
}

/// A dialog `content` width that fits `preferred` on a wide screen but
/// shrinks to 90% of the viewport on a phone, where `preferred` (usually
/// 360-480px) would run off the edge of the screen. Used by every
/// AlertDialog in this file instead of a bare fixed SizedBox width.
double dialogWidth(BuildContext context, double preferred) {
  final screenWidth = MediaQuery.of(context).size.width;
  return screenWidth > preferred + 80 ? preferred : screenWidth * 0.9;
}

/// Same idea for a dialog `content` height that has its own Expanded
/// child (a scrollable list) and so needs a definite height to lay
/// out — caps at 60% of the viewport instead of a bare fixed value
/// that can be taller than a phone screen.
double dialogHeight(BuildContext context, double preferred) {
  final screenHeight = MediaQuery.of(context).size.height;
  final cap = screenHeight * 0.6;
  return preferred > cap ? cap : preferred;
}

/// ================================================================
/// OCCUPIED LOT DIALOG
/// ================================================================

class OccupiedLotDialog extends StatelessWidget {
  final LotModel lot;
  final bool canEdit;

  /// Admin-only — separate from [canEdit] (which Officers also have).
  /// Gates "Change Owner" / "Unassign" specifically: Officers can view
  /// and edit a lot's other details, but member assignment is an
  /// admin-only action.
  final bool canAssignMembers;

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
    required this.canAssignMembers,
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
                color: AppColors.textPrimary,
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
        width: dialogWidth(context, 450),
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

              const SizedBox(height: 18),

              _sectionTitle(
                'Ownership History',
              ),

              const SizedBox(height: 8),

              _OwnershipHistoryTable(lotId: lot.id),

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

        if (canAssignMembers &&
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

        if (canAssignMembers &&
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
                  width: dialogWidth(context, 360),
                  height: dialogHeight(context, 420),
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

      // The outstanding balance stays with the lot, so show what the new
      // owner is taking over before anything is changed.
      final saleService = SaleService();
      final sale = await saleService.getCurrentSaleForLot(lot.id);
      final balance = sale == null
          ? 0.0
          : await saleService.outstandingBalanceForSale(sale.id);

      if (!context.mounted) return;

      final ok = await _confirmTransfer(
        context,
        newOwner: selected.value,
        balance: balance,
        hasSale: sale != null,
      );
      if (!ok) return;

      await saleService.changeLotOwner(
        lotId: lot.id,
        newBuyerUid: selected.key,
        newBuyerName: selected.value,
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

  Future<bool> _confirmTransfer(
    BuildContext context, {
    required String newOwner,
    required double balance,
    required bool hasSale,
  }) async {
    final previous = _displayValue(lot.ownerName);

    final String detail;
    if (!hasSale) {
      detail = 'No sale is recorded for this lot, so only the owner changes. '
          'There is no balance to transfer.';
    } else if (balance > 0) {
      detail = '$newOwner takes over the outstanding balance of '
          '${LotPricing.peso(balance)} and must pay it all. What $previous '
          'already paid stays in their payment records.';
    } else {
      detail = 'This lot has no outstanding balance. What $previous already '
          'paid stays in their payment records.';
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Change Owner?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lot ${lot.lotNumber}: $previous  \u2192  $newOwner',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(detail),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Change Owner'),
          ),
        ],
      ),
    );

    return result ?? false;
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

  /// Admin-only — see OccupiedLotDialog.canAssignMembers.
  final bool canAssignMembers;

  final String currentUserId;

  final Future<List<MapEntry<String, String>>>
      Function() loadAssignableMembers;

  const VacantLotDialog({
    super.key,
    required this.lot,
    required this.canEdit,
    required this.canAssignMembers,
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
  final RateService _rateService = RateService();

  final _formKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _blockController;

  late final TextEditingController
      _lotController;

  late final TextEditingController
      _areaController;

  late final TextEditingController
      _contactController;

  late final TextEditingController
      _notesController;

  late final TextEditingController
      _priceControllerOverride;

  /// Manual price override. Defaults to null (derive from rate).
  /// Only shown in the dialog when no default rate has been configured
  /// yet — once one exists, admin can skip the field and let pricing
  /// flow automatically.
  String? _manualPriceText;
  bool _manualPriceSet = false;
  double? _currentRate;
  bool _loading = true;
  bool  _saving = false;

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

    _contactController =
        TextEditingController(
      text:
          widget.lot.contactNumber ?? '',
    );

    _notesController =
        TextEditingController(
      text: widget.lot.notes ?? '',
    );

    _priceControllerOverride =
        TextEditingController();

    _loadRate();
  }

  Future<void> _loadRate() async {
    final rate = await _rateService.getSalesRate();
    if (mounted) {
      setState(() {
        _currentRate = rate?.ratePerSqm;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _blockController.dispose();
    _lotController.dispose();
    _areaController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    _priceControllerOverride.dispose();

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
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),

      content: SizedBox(
        width: dialogWidth(context, 480),
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

                if (widget.canAssignMembers)
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

                // Derived price preview — always shown when a default
                // rate exists so admins see where the number comes from.
                if (_currentRate != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '₱${_currentRate!.toStringAsFixed(2)} × ${widget.lot.areaSqm ?? 0} sqm = ₱${(_currentRate! * (widget.lot.areaSqm ?? 0)).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                ],
                // Manual override only when no default rate has been
                // configured yet — once one exists, admins can skip the
                // field entirely and pricing flows automatically.
                if (_manualPriceText == null && _currentRate == null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _priceControllerOverride,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Manual Price (override)',
                        hintText: 'Price per sqm or total — use default rate if available',
                        prefixIcon: const Icon(Icons.sell_outlined, size: 19),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _blue.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _blue.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _blue, width: 1.5),
                        ),
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v.trim());
                        if (parsed != null && parsed >= 0) {
                          setState(() => _manualPriceSet = true);
                        } else {
                          setState(() => _manualPriceSet = false);
                        }
                      },
                    ),
                  ),
                ],
                if (_manualPriceSet) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '$_manualPriceText',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                ],

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
                      color: AppColors.textInverted,
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

      if (area == null || area < 0) {
        _showError(
          'Please enter a valid lot area.',
        );
        return;
      }
    }

    double? price;

    if (_currentRate != null) {
      price = _currentRate! * (area ?? 0);
    } else {
      final priceText = _priceControllerOverride.text.trim();
      if (priceText.isNotEmpty) {
        price = double.tryParse(priceText);
        if (price == null || price < 0) {
          _showError('Please enter a valid price.');
          return;
        }
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
            normalizeBlockLabel(_blockController.text),

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
    // Opens the assign-lot wizard (member -> payment -> review -> save).
    // It records the sale through SaleService.registerSale, so the lot is
    // assigned AND the payment shows up on the Payments screen.
    final assigned = await AssignLotWizard.show(
      context,
      lot: widget.lot,
      recordedBy: widget.currentUserId,
      loadMembers: widget.loadAssignableMembers,
    );

    if (!mounted) return;

    if (assigned == true) {
      Navigator.of(context).pop(true);
    }
  }

  // ================================================================
  // MARK FOR SALE
  // ================================================================

  Future<void> _markForSale() async {
    final area = double.tryParse(_areaController.text.trim()) ?? widget.lot.areaSqm ?? 0;

    final price = _currentRate != null
        ? (_currentRate! * area)
        : (double.tryParse(_priceControllerOverride.text.trim()) ?? 0.0);

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

  /// Admin-only — see OccupiedLotDialog.canAssignMembers.
  final bool canAssignMembers;

  final String currentUserId;

  final Future<List<MapEntry<String, String>>>
      Function() loadAssignableMembers;

  const ForSaleLotDialog({
    super.key,
    required this.lot,
    required this.canEdit,
    required this.canAssignMembers,
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
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),

      content: SizedBox(
        width: dialogWidth(context, 460),
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

              if (widget.canAssignMembers)
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

              const SizedBox(height: 18),

              _sectionTitle(
                'Record Sale',
              ),

              const SizedBox(height: 10),

              // Opens the assign-lot wizard, which records the sale through
              // SaleService.registerSale (lot assigned + schedule + the cash
              // purchase / down payment written to Payments). Admin only,
              // same as assigning a member.
              if (widget.canAssignMembers)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _openAssignOwner,
                    icon: const Icon(Icons.sell),
                    label: const Text('Record New Sale'),
                  ),
                )
              else
                const Text(
                  'Only an Admin can record a sale.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),

              const SizedBox(height: 18),
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
    // Opens the assign-lot wizard (member -> payment -> review -> save).
    // It records the sale through SaleService.registerSale, so the lot is
    // assigned AND the payment shows up on the Payments screen.
    final assigned = await AssignLotWizard.show(
      context,
      lot: widget.lot,
      recordedBy: widget.currentUserId,
      loadMembers: widget.loadAssignableMembers,
    );

    if (!mounted) return;

    if (assigned == true) {
      Navigator.of(context).pop(true);
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
        width: dialogWidth(context, 480),
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
                    color: AppColors.textInverted,
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

      if (area == null || area < 0) {
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
            normalizeBlockLabel(_blockController.text),
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
      color: AppColors.textPrimary,
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
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
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
              color: AppColors.textPrimary,
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
      color: AppColors.background,
      borderRadius:
          BorderRadius.circular(10),
      border: Border.all(
        color: AppColors.border,
      ),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textPrimary,
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
          ? AppColors.background
          : AppColors.borderSubtle,
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.border,
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

/// ================================================================
/// OWNERSHIP HISTORY TABLE
/// ================================================================

class _OwnershipHistoryTable extends StatefulWidget {
  final String lotId;

  const _OwnershipHistoryTable({required this.lotId});

  @override
  State<_OwnershipHistoryTable> createState() =>
      _OwnershipHistoryTableState();
}

class _OwnershipHistoryTableState extends State<_OwnershipHistoryTable> {
  late final Stream<List<LotOwnershipRecord>> _stream =
      SaleService().streamOwnershipHistory(widget.lotId);

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _cell(String text,
          {int flex = 1, bool header = false, bool bold = false}) =>
      Expanded(
        flex: flex,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: header ? 11.5 : 12.5,
            fontWeight: (header || bold) ? FontWeight.w700 : FontWeight.w500,
            color: header ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LotOwnershipRecord>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Text(
            'Could not load ownership history.',
            style: TextStyle(fontSize: 12.5, color: AppColors.danger),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final rows = snap.data!;
        if (rows.isEmpty) {
          return const Text(
            'No ownership history yet.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(children: [
                _cell('Owner', flex: 3, header: true),
                _cell('Period', flex: 3, header: true),
                _cell('Balance taken over', flex: 2, header: true),
              ]),
              const Divider(height: 14),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cell(
                        r.isCurrent ? '${r.ownerName} (current)' : r.ownerName,
                        flex: 3,
                        bold: r.isCurrent,
                      ),
                      _cell(
                        '${_fmt(r.startedAt)} \u2013 '
                        '${r.endedAt == null ? 'Present' : _fmt(r.endedAt!)}',
                        flex: 3,
                      ),
                      _cell(
                        r.acquiredBy == 'transfer'
                            ? LotPricing.peso(r.balanceTakenOver)
                            : '\u2014',
                        flex: 2,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}