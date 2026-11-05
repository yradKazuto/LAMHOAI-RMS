// features/location/widgets/assign_lot_wizard.dart
//
// Assign-a-lot wizard for Location Mapping. Same idea as the member
// registration wizard, but for a member who ALREADY exists and is buying
// another lot straight from the map:
//
//   1. Assign Member   — pick the member (the lot details are shown on top)
//   2. Payment Method  — cash, or installment (down payment / term / rate)
//   3. Review          — everything in one place, nothing is saved yet
//   4. Complete        — the sale is recorded
//
// Saving goes through SaleService.registerSale — the same call the
// registration wizard makes — so the lot is assigned to the member, the sale
// and its payment schedule are created, and the cash purchase / down payment
// is written to the `payments` collection and shows on the Payments screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../../../core/models/lot_model.dart';
import '../../../core/models/lot_sale_model.dart';
import '../../../core/models/payment_model.dart' show buildLotLabel;
import '../../../core/services/sale_service.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/lot_pricing.dart';

class AssignLotWizard extends StatefulWidget {
  final LotModel lot;

  /// uid of the signed-in staff member recording the sale.
  final String recordedBy;

  /// Same loader the map already uses: (member uid -> display name).
  final Future<List<MapEntry<String, String>>> Function() loadMembers;

  const AssignLotWizard({
    super.key,
    required this.lot,
    required this.recordedBy,
    required this.loadMembers,
  });

  /// Opens the wizard. Resolves to true when the lot was assigned.
  static Future<bool?> show(
    BuildContext context, {
    required LotModel lot,
    required String recordedBy,
    required Future<List<MapEntry<String, String>>> Function() loadMembers,
  }) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AssignLotWizard(
          lot: lot,
          recordedBy: recordedBy,
          loadMembers: loadMembers,
        ),
      );

  @override
  State<AssignLotWizard> createState() => _AssignLotWizardState();
}

class _AssignLotWizardState extends State<AssignLotWizard> {
  static const _stepLabels = ['Member', 'Payment', 'Review', 'Complete'];

  int _step = 1;
  bool _submitting = false;
  String? _error;

  // Step 1
  late final Future<List<MapEntry<String, String>>> _membersFuture;
  final _searchCtrl = TextEditingController();
  String? _memberUid;
  String? _memberName;

  // Step 2
  SaleType _saleType = SaleType.cash;
  final _downCtrl = TextEditingController();
  final _termCtrl = TextEditingController(text: '${LotPricing.totalMonths}');
  final _rateCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _membersFuture = widget.loadMembers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _downCtrl.dispose();
    _termCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  // ── Derived values ────────────────────────────────────────────────────────
  double get _price => LotPricing.priceFor(widget.lot);
  bool get _isInstallment => _saleType == SaleType.installment;
  double get _down =>
      _isInstallment ? (double.tryParse(_downCtrl.text.trim()) ?? 0.0) : 0.0;
  int get _term =>
      _isInstallment ? (int.tryParse(_termCtrl.text.trim()) ?? 0) : 0;
  double get _rate =>
      _isInstallment ? (double.tryParse(_rateCtrl.text.trim()) ?? 0.0) : 0.0;
  double get _financed => _price - _down;
  double get _monthly => (_isInstallment && _term > 0 && _financed > 0)
      ? LotPricing.monthlyFor(_financed, _rate, _term)
      : 0.0;
  double get _totalPayable =>
      _isInstallment ? _down + (_monthly * _term) : _price;

  String get _lotLabel => buildLotLabel(
        block: widget.lot.block,
        lotNumber: widget.lot.lotNumber,
        phase: widget.lot.phase,
      );

  String _termLabel() => _term % 12 == 0 && _term > 0
      ? '$_term months (${_term ~/ 12} years)'
      : '$_term months';

  // ── Validation / navigation ───────────────────────────────────────────────
  String? _validate(int step) {
    if (step == 1) {
      if (_price <= 0) {
        return 'This lot has no price yet — set its lot area first, '
            'otherwise no payment record can be created.';
      }
      if (_memberUid == null) return 'Select the member who is buying this lot.';
    }
    if (step == 2 && _isInstallment) {
      if (_term <= 0) return 'Enter the number of months (1 or more).';
      if (_rate < 0) return 'Interest rate cannot be negative.';
      if (_down < 0) return 'Down payment cannot be negative.';
      if (_down >= _price) {
        return 'Down payment must be less than the lot price '
            '(${LotPricing.peso(_price)}). For a full payment choose Cash.';
      }
    }
    return null;
  }

  void _next() {
    final err = _validate(_step);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  void _back() => setState(() {
        _error = null;
        _step--;
      });

  Future<void> _submit() async {
    // Re-check everything — the user may have gone back and edited.
    for (final s in [1, 2]) {
      final err = _validate(s);
      if (err != null) {
        setState(() => _error = err);
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await SaleService().registerSale(
        lot: widget.lot,
        buyerUid: _memberUid!,
        buyerName: _memberName ?? '',
        saleType: _saleType,
        downPayment: _down,
        termMonths: _isInstallment ? _term : 0,
        annualInterestRate: _rate,
        soldDate: DateTime.now(),
        recordedBy: widget.recordedBy,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _step = 4;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not assign this lot: $e';
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width > 680 ? 640.0 : size.width * 0.94;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: width, maxHeight: size.height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _body(),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assign Lot — $_lotLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            Row(
              children: [
                for (int i = 1; i <= 4; i++) ...[
                  if (i > 1)
                    Expanded(
                      child: Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: AppColors.border,
                      ),
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= _step
                              ? AppColors.primary
                              : AppColors.surfaceAlt,
                          border: Border.all(
                              color: i <= _step
                                  ? AppColors.primary
                                  : AppColors.border),
                        ),
                        child: (i < _step || _step == 4)
                            ? const Icon(Icons.check,
                                size: 15, color: AppColors.textInverted)
                            : Text('$i',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: i == _step
                                        ? AppColors.textInverted
                                        : AppColors.textSecondary)),
                      ),
                      const SizedBox(height: 6),
                      Text(_stepLabels[i - 1],
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: i == _step
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: i <= _step
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted)),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

  Widget _footer() {
    if (_step == 4) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: _primaryButton(),
            child: const Text('Done'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          TextButton(
            onPressed: _submitting
                ? null
                : (_step == 1
                    ? () => Navigator.of(context).pop(false)
                    : _back),
            child: Text(_step == 1 ? 'Cancel' : 'Back',
                style: const TextStyle(color: AppColors.textMuted)),
          ),
          const Spacer(),
          if (_step < 3)
            ElevatedButton(
              onPressed: _next,
              style: _primaryButton(),
              child: const Text('Next'),
            ),
          if (_step == 3)
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: _primaryButton(),
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.textInverted))
                  : const Text('Confirm & Assign'),
            ),
        ],
      ),
    );
  }

  ButtonStyle _primaryButton() => ElevatedButton.styleFrom(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.textInverted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      );

  Widget _body() {
    final Widget content;
    switch (_step) {
      case 1:
        content = _stepMember();
        break;
      case 2:
        content = _stepPayment();
        break;
      case 3:
        content = _stepReview();
        break;
      default:
        content = _stepComplete();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.danger)),
          ),
        ],
      ],
    );
  }

  // ── Step 1: member ────────────────────────────────────────────────────────
  Widget _lotCard() {
    final area = (widget.lot.areaSqm ?? 0).toDouble();
    return _card(
      child: Column(
        children: [
          _row('Lot', _lotLabel),
          _row(
              'Lot area',
              area > 0
                  ? '${area == area.roundToDouble() ? area.toInt().toString() : area.toStringAsFixed(2)} sqm'
                  : 'Not set'),
          _row('Price', _price > 0 ? LotPricing.peso(_price) : 'Not available',
              bold: true),
        ],
      ),
    );
  }

  Widget _stepMember() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Lot details'),
        _lotCard(),
        const SizedBox(height: 18),
        _title('Assign member'),
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: _input('Search member…',
              prefix: const Icon(Icons.search, size: 18)),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<MapEntry<String, String>>>(
          future: _membersFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Text('Could not load members: ${snap.error}',
                  style: const TextStyle(color: AppColors.danger));
            }
            final q = _searchCtrl.text.trim().toLowerCase();
            final members = (snap.data ?? [])
                .where((m) => q.isEmpty || m.value.toLowerCase().contains(q))
                .toList()
              ..sort((a, b) =>
                  a.value.toLowerCase().compareTo(b.value.toLowerCase()));

            if (members.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No members found.',
                    style: TextStyle(color: AppColors.textMuted)),
              );
            }

            return Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: members.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.background),
                itemBuilder: (_, i) {
                  final m = members[i];
                  final selected = m.key == _memberUid;
                  return ListTile(
                    dense: true,
                    selected: selected,
                    selectedTileColor: AppColors.primary.withOpacity(0.08),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: Text(
                          m.value.isNotEmpty ? m.value[0].toUpperCase() : '?',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                    title: Text(m.value,
                        style: const TextStyle(
                            fontSize: 13.5, color: AppColors.textPrimary)),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            size: 18, color: AppColors.primary)
                        : null,
                    onTap: () => setState(() {
                      _memberUid = m.key;
                      _memberName = m.value;
                      _error = null;
                    }),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Step 2: payment method ────────────────────────────────────────────────
  Widget _stepPayment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Payment method'),
        SegmentedButton<SaleType>(
          segments: [
            for (final t in SaleType.values)
              ButtonSegment<SaleType>(value: t, label: Text(t.label)),
          ],
          selected: {_saleType},
          onSelectionChanged: (s) => setState(() {
            _saleType = s.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_isInstallment) ...[
          TextField(
            controller: _downCtrl,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: _input('Down payment (₱)',
                hint: '0 for no down payment'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _termCtrl,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _input('Term (months)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _rateCtrl,
                  onChanged: (_) => setState(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: _input('Interest p.a. (%)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        _title('Payment preview'),
        _card(child: _summaryRows(includeMember: false)),
      ],
    );
  }

  // ── Step 3: review ────────────────────────────────────────────────────────
  Widget _stepReview() {
    final recorded = _isInstallment
        ? (_down > 0
            ? 'The down payment of ${LotPricing.peso(_down)} will be recorded '
                'as paid and appear in Payments.'
            : 'No down payment — the monthly schedule is created and each '
                'period is recorded as it is paid.')
        : 'The full price of ${LotPricing.peso(_price)} will be recorded as '
            'paid and appear in Payments.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Review'),
        _card(child: _summaryRows(includeMember: true)),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$recorded The lot is assigned to the member and marked '
                'Occupied. Nothing is saved until you tap Confirm & Assign.',
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryRows({required bool includeMember}) {
    return Column(
      children: [
        if (includeMember) _row('Member', _memberName ?? '—', bold: true),
        _row('Lot', _lotLabel),
        _row('Sale type', _saleType.label),
        _row('Lot price', LotPricing.peso(_price)),
        if (_isInstallment) ...[
          _row('Down payment', LotPricing.peso(_down)),
          _row('Amount financed', LotPricing.peso(_financed > 0 ? _financed : 0)),
          _row('Term', _term > 0 ? _termLabel() : '—'),
          _row('Interest p.a.', '${_rate.toStringAsFixed(1)}%'),
          _row('Monthly installment', LotPricing.peso(_monthly)),
        ],
        const Divider(height: 18),
        _row(_isInstallment ? 'Total payable' : 'Total', LotPricing.peso(_totalPayable),
            bold: true),
      ],
    );
  }

  // ── Step 4: complete ──────────────────────────────────────────────────────
  Widget _stepComplete() {
    return Column(
      children: [
        const SizedBox(height: 6),
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: AppColors.successBg),
          child: const Icon(Icons.check, size: 30, color: AppColors.success),
        ),
        const SizedBox(height: 14),
        const Text('Lot assigned',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text('$_lotLabel now belongs to ${_memberName ?? 'the member'}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        _card(child: _summaryRows(includeMember: true)),
        const SizedBox(height: 12),
        Text(
          (!_isInstallment || _down > 0)
              ? 'The payment has been added to the Payments screen.'
              : 'The payment schedule has been created.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
      ],
    );
  }

  // ── Small shared pieces ───────────────────────────────────────────────────
  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textMuted)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.textPrimary)),
            ),
          ],
        ),
      );

  InputDecoration _input(String label, {String? hint, Widget? prefix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderStrong)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderStrong)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
      );
}