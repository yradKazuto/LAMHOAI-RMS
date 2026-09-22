// features/payments/screens/add_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/lot_model.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/lot_service.dart';
import '../../../core/services/rate_history_service.dart';
import '../../../core/services/settings_service.dart';

class AddPaymentScreen extends StatefulWidget {
  final String? preselectedMemberId;
  final String? preselectedMemberName;

  const AddPaymentScreen({
    super.key,
    this.preselectedMemberId,
    this.preselectedMemberName,
  });

  /// Opens the form as a modal dialog over the current screen (instead of
  /// pushing a full page). Not dismissible by tapping outside, so a
  /// half-filled payment isn't lost by accident — use Cancel or the X.
  static Future<void> show(
    BuildContext context, {
    String? preselectedMemberId,
    String? preselectedMemberName,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddPaymentScreen(
        preselectedMemberId: preselectedMemberId,
        preselectedMemberName: preselectedMemberName,
      ),
    );
  }

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _fs       = FirestoreService();
  final _rateSvc  = RateHistoryService();
  final _settings = SettingsService();
  final _amount   = TextEditingController();
  final _notes    = TextEditingController();

  String?        _memberId;
  String?        _memberName;
  PaymentType    _type      = PaymentType.dues;
  PaymentStatus  _status    = PaymentStatus.unpaid;
  DateTime       _dueDate   = DateTime.now();
  DateTime?      _paidDate;
  bool           _loading   = false;

  // Shown inside the dialog. A SnackBar would be hidden behind the modal.
  String?        _formError;

  // Once the user types an amount themselves we stop auto-filling it.
  bool           _amountEdited = false;

  // Lots owned by the selected member (from the lots collection — the
  // source of truth; the member record's own lotNumber is provisional).
  List<LotModel> _memberLots   = const [];
  LotModel?      _selectedLot;
  bool           _lotsLoading  = false;

  static const Color _navy   = Color(0xFF0D2A5C);

  @override
  void initState() {
    super.initState();
    if (widget.preselectedMemberId != null) {
      _memberId   = widget.preselectedMemberId;
      _memberName = widget.preselectedMemberName;
    }
    if (_memberId != null) _loadLots(_memberId!);
    _suggestAmount();
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Monthly dues and lot payments each belong to one specific lot.
  bool get _needsLot =>
      _type == PaymentType.dues || _type == PaymentType.lotPayment;

  /// Loads the member's lots. One lot → auto-selected; several → the user
  /// picks; none → recording is blocked for lot-based types.
  Future<void> _loadLots(String uid) async {
    setState(() {
      _lotsLoading = true;
      _memberLots  = const [];
      _selectedLot = null;
    });
    try {
      final lots = [...await LotService().streamLotsForMember(uid).first]
        ..sort(compareLotsForBilling);
      if (!mounted || _memberId != uid) return; // member changed meanwhile
      setState(() {
        _memberLots  = lots;
        _selectedLot = lots.length == 1 ? lots.first : null;
        _lotsLoading = false;
      });
    } catch (_) {
      if (!mounted || _memberId != uid) return;
      setState(() => _lotsLoading = false);
    }
  }

  /// Parses "1,500.50" / "1500.5". Returns null for empty, non-numeric,
  /// NaN or infinite input.
  double? _parseAmount(String? v) {
    if (v == null) return null;
    final n = double.tryParse(v.trim().replaceAll(',', ''));
    if (n == null || n.isNaN || n.isInfinite) return null;
    return n;
  }

  String get _typeHint {
    switch (_type) {
      case PaymentType.dues:
        return 'Monthly dues for ONE lot. Normally created in bulk from '
            'Membership Dues → Generate; use this only for one-off records.';
      case PaymentType.membershipFee:
        return 'Yearly association membership fee. Normally created in bulk '
            'from Membership Dues → Generate.';
      case PaymentType.lotPayment:
        return 'Payment toward one lot (amortization / installment). '
            'Separate from monthly and annual dues.';
      case PaymentType.penalty:
      case PaymentType.specialAssessment:
      case PaymentType.other:
        return '';
    }
  }

  /// Pre-fills the amount from the configured rate for the chosen type:
  ///  • Monthly Dues        → the monthly rate in effect for the due month
  ///  • Annual Membership   → the annual fee from settings
  ///  • everything else     → left blank (lot payments vary per lot)
  /// Never overwrites an amount the user typed.
  Future<void> _suggestAmount() async {
    if (_amountEdited) return;
    final forType = _type;
    final forDue  = _dueDate;
    double? suggested;
    try {
      if (forType == PaymentType.dues) {
        suggested = await _rateSvc
            .getRateForMonth(DateTime(forDue.year, forDue.month, 1));
      } else if (forType == PaymentType.membershipFee) {
        suggested = (await _settings.getSettings()).dues.annual;
      }
    } catch (_) {
      return; // suggestion is a convenience — never block the form on it
    }
    // Ignore stale results if the user changed type/date while we waited.
    if (!mounted || _amountEdited || _type != forType || _dueDate != forDue) {
      return;
    }
    setState(() {
      _amount.text = (suggested != null && suggested > 0)
          ? suggested.toStringAsFixed(2)
          : '';
    });
  }

  /// Monthly dues and annual fees are generated one-per-member-per-period,
  /// and the dues screen shows a single record per member. A second manual
  /// record for the same period would make totals/rows ambiguous, so block it.
  /// (Lot payments are installments — multiple per month are legitimate.)
  Future<String?> _duplicateMessage() async {
    if (_type != PaymentType.dues && _type != PaymentType.membershipFee) {
      return null;
    }
    // Two equality filters only — no composite index needed; the period
    // check is done in Dart.
    final snap = await FirebaseFirestore.instance
        .collection('payments')
        .where('uid', isEqualTo: _memberId)
        .where('type', isEqualTo: _type.name)
        .get();

    for (final d in snap.docs) {
      final p = PaymentModel.fromMap(d.data(), d.id);
      final sameYear = p.dueDate.year == _dueDate.year;
      final sameMonth = p.dueDate.month == _dueDate.month;
      if (_type == PaymentType.membershipFee && sameYear) {
        return '$_memberName already has a ${_dueDate.year} membership '
            'fee record (${p.displayStatus.label}).';
      }
      if (_type == PaymentType.dues && sameYear && sameMonth) {
        final lot = _selectedLot;
        if (lot != null) {
          // A record with no lotId predates per-lot billing and counts as
          // the member's first lot (same rule as the generator).
          final sameLot = p.lotId == lot.id ||
              (p.lotId.isEmpty &&
                  _memberLots.isNotEmpty &&
                  _memberLots.first.id == lot.id);
          if (sameLot) {
            final text = buildLotLabel(
                phase: lot.phase,
                block: lot.block,
                lotNumber: lot.lotNumber);
            return '$_memberName already has a monthly dues record for '
                '${text.isEmpty ? 'this lot' : text} in '
                '${_monthName(_dueDate.month)} ${_dueDate.year} '
                '(${p.displayStatus.label}).';
          }
        }
      }
    }
    return null;
  }

  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];
  String _monthName(int m) => _months[m - 1];

  Future<void> _pickDate(bool isDueDate) async {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: isDueDate ? _dueDate : (_paidDate ?? today),
      firstDate: DateTime(2020),
      // A payment can't have been received in the future.
      lastDate: isDueDate ? DateTime(now.year + 5, 12, 31) : today,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _navy),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = picked;
        } else {
          _paidDate = picked;
        }
      });
      // Monthly rate depends on the due month.
      if (isDueDate) _suggestAmount();
    }
  }

  Future<void> _submit() async {
    setState(() => _formError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_memberId == null) {
      setState(() => _formError = 'Please select a member.');
      return;
    }
    if (_needsLot && _selectedLot == null) {
      setState(() => _formError = _memberLots.isEmpty
          ? '$_memberName has no lot assigned. Assign one from Location '
            'Mapping first.'
          : 'Please select the lot this payment is for.');
      return;
    }
    final amount = _parseAmount(_amount.text)!; // validated above
    final lotRef = _needsLot ? _selectedLot : null;
    final lotId  = lotRef?.id ?? '';
    final lot    = lotRef == null
        ? ''
        : buildLotLabel(
            phase: lotRef.phase,
            block: lotRef.block,
            lotNumber: lotRef.lotNumber);

    setState(() => _loading = true);
    try {
      final dup = await _duplicateMessage();
      if (dup != null) {
        if (!mounted) return;
        setState(() {
          _loading   = false;
          _formError = '$dup Use "Mark Paid" on the Membership Dues '
              'screen instead of adding another.';
        });
        return;
      }

      final auth = context.read<AuthProvider>();
      final id   = FirebaseFirestore.instance.collection('payments').doc().id;
      await _fs.addPayment(PaymentModel(
        id:         id,
        uid:        _memberId!,
        memberName: _memberName ?? '',
        type:       _type,
        amount:     amount,
        status:     _status,
        dueDate:    _dueDate,
        paidDate:   _status == PaymentStatus.paid
            ? (_paidDate ?? DateTime.now())
            : null,
        recordedBy: auth.userModel?.uid ?? '',
        notes:      _notes.text.trim(),
        createdAt:  DateTime.now(),
        lotId:      lotId,
        lotLabel:   lot,
      ));

      // ── Audit log ──────────────────────────────────────────────────────
      // Kept in its own try/catch: the payment is already saved at this
      // point, so an audit failure must not look like a failed save
      // (that would invite the user to submit it a second time).
      var auditFailed = false;
      try {
        await SettingsService().logAction(
          performedBy:      auth.userModel?.uid ?? '',
          performedByName:  auth.userModel?.displayName ?? '',
          action:           AuditAction.created,
          targetCollection: 'payments',
          targetId:         id,
          description:
              'Recorded ${_type.label} payment of ₱${amount.toStringAsFixed(2)} '
              'for $_memberName'
              '${lot.isNotEmpty ? ' ($lot)' : ''}',
        );
      } catch (_) {
        auditFailed = true;
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(auditFailed
                ? 'Payment saved, but the audit log entry could not be written.'
                : 'Payment recorded successfully.'),
            backgroundColor: auditFailed
                ? const Color(0xFF7A6A1A)
                : const Color(0xFF1A7A4A),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading   = false;
        _formError = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Record Payment',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: _navy)),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed:
                              _loading ? null : () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Member selector ───────────────────────────────────
                    _SectionLabel('Member'),
                    const SizedBox(height: 6),
                    if (widget.preselectedMemberId != null)
                      _ReadonlyChip(label: _memberName ?? '')
                    else
                      _MemberSelector(
                        fs: _fs,
                        selectedId: _memberId,
                        selectedName: _memberName,
                        onSelected: (id, name) {
                          setState(() {
                            _memberId   = id;
                            _memberName = name;
                          });
                          _loadLots(id);
                        },
                      ),
                    const SizedBox(height: 20),

                    // ── Type + Status ─────────────────────────────────────
                    Row(children: [
                      Expanded(
                        child: _FormDropdown<PaymentType>(
                          label: 'Payment Type',
                          value: _type,
                          items: PaymentType.values,
                          labelOf: (v) => v.label,
                          onChanged: (v) {
                            setState(() => _type = v);
                            _suggestAmount();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _FormDropdown<PaymentStatus>(
                          label: 'Status',
                          value: _status,
                          items: PaymentStatus.values,
                          labelOf: (v) => v.label,
                          onChanged: (v) => setState(() {
                            _status = v;
                            if (v == PaymentStatus.paid) {
                              _paidDate ??= DateTime.now();
                            } else {
                              // A paid date only makes sense for Paid.
                              _paidDate = null;
                            }
                          }),
                        ),
                      ),
                    ]),
                    if (_typeHint.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_typeHint,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                    const SizedBox(height: 20),

                    // ── Lot (monthly dues + lot payments) ─────────────────
                    if (_needsLot && _memberId != null) ...[
                      _SectionLabel('Lot'),
                      const SizedBox(height: 6),
                      if (_lotsLoading)
                        Text('Loading lots...',
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.grey[600]))
                      else if (_memberLots.isEmpty)
                        Text(
                            'This member has no lot assigned yet. Assign one '
                            'from Location Mapping before recording '
                            '${_type.label}.',
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFFCC2200)))
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedLot?.id,
                          hint: Text('Select a lot',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[400])),
                          style: const TextStyle(
                              fontSize: 13.5, color: Color(0xFF1A2B4A)),
                          validator: (v) =>
                              v == null ? 'Please select a lot' : null,
                          decoration: _fieldDec(''),
                          items: _memberLots
                              .map((l) => DropdownMenuItem<String>(
                                    value: l.id,
                                    child: Text(buildLotLabel(
                                        phase: l.phase,
                                        block: l.block,
                                        lotNumber: l.lotNumber)),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _selectedLot = _memberLots
                                .firstWhere((l) => l.id == v);
                          }),
                        ),
                      const SizedBox(height: 20),
                    ],

                    // ── Amount ────────────────────────────────────────────
                    _SectionLabel('Amount (₱)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => _amountEdited = true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = _parseAmount(v);
                        if (n == null) return 'Enter a valid amount';
                        if (n <= 0) return 'Must be greater than zero';
                        return null;
                      },
                      style: const TextStyle(fontSize: 14),
                      decoration: _fieldDec('0.00'),
                    ),
                    const SizedBox(height: 20),

                    // ── Due date + Paid date ──────────────────────────────
                    Row(children: [
                      Expanded(
                        child: _DatePicker(
                          label: 'Due Date',
                          date: _dueDate,
                          onTap: () => _pickDate(true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DatePicker(
                          label: 'Paid Date',
                          date: _paidDate,
                          optional: true,
                          enabled: _status == PaymentStatus.paid,
                          onTap: () => _pickDate(false),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Notes ─────────────────────────────────────────────
                    _SectionLabel('Notes (optional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: _fieldDec(
                          'Add any remarks or reference numbers...'),
                    ),
                    const SizedBox(height: 28),

                    if (_formError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEA),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: const Color(0xFFF2B8B0)),
                        ),
                        child: Text(_formError!,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFCC2200))),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Actions ───────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel',
                              style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Text('Save Payment',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
            color: Color(0xFF2E6BE6), width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCC2200))),
  );
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0D2A5C)));
}

// ── Readonly chip ─────────────────────────────────────────────────────────────
class _ReadonlyChip extends StatelessWidget {
  final String label;
  const _ReadonlyChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F4FB),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFD0DBEE)),
    ),
    child: Text(label,
        style: const TextStyle(
            fontSize: 13.5, color: Color(0xFF1A2B4A))),
  );
}

// ── Member selector ───────────────────────────────────────────────────────────
class _MemberSelector extends StatelessWidget {
  final FirestoreService fs;
  final String? selectedId;
  final String? selectedName;
  final void Function(String id, String name) onSelected;

  const _MemberSelector({
    required this.fs,
    required this.selectedId,
    required this.selectedName,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MemberModel>>(
      stream: fs.streamMembers(),
      builder: (context, snap) {
        final members = [...(snap.data ?? <MemberModel>[])]
          ..sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return DropdownButtonFormField<String>(
          value: selectedId,
          hint: Text('Select a member',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey[400])),
          style: const TextStyle(
              fontSize: 13.5, color: Color(0xFF1A2B4A)),
          validator: (v) =>
              v == null ? 'Please select a member' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF7F9FC),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFD0DBEE))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFD0DBEE))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF2E6BE6), width: 1.5)),
          ),
          items: members
              .map((m) => DropdownMenuItem<String>(
                    value: m.uid,
                    child: Text('${m.name}'
                        '${m.status == MemberStatus.inactive ? ' (inactive)' : ''}'),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            final m = members.firstWhere((m) => m.uid == v);
            onSelected(m.uid, m.name);
          },
        );
      },
    );
  }
}

// ── Dropdown form field ───────────────────────────────────────────────────────
class _FormDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final void Function(T) onChanged;

  const _FormDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D2A5C))),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        value: value,
        style: const TextStyle(
            fontSize: 13.5, color: Color(0xFF1A2B4A)),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFFD0DBEE))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFFD0DBEE))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFF2E6BE6), width: 1.5)),
        ),
        items: items
            .map((i) => DropdownMenuItem<T>(
                value: i, child: Text(labelOf(i))))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ],
  );
}

// ── Date picker field ─────────────────────────────────────────────────────────
class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool optional;
  final bool enabled;
  final VoidCallback onTap;

  const _DatePicker({
    required this.label,
    required this.date,
    required this.onTap,
    this.optional = false,
    this.enabled = true,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D2A5C))),
      const SizedBox(height: 6),
      InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: const Color(0xFFD0DBEE)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 16, color: Colors.grey[500]),
              const SizedBox(width: 10),
              Text(
                date != null
                    ? _fmt(date!)
                    : (optional ? 'Not set' : 'Select date'),
                style: TextStyle(
                    fontSize: 13.5,
                    color: date != null
                        ? const Color(0xFF1A2B4A)
                        : Colors.grey[400]),
              ),
            ],
          ),
        ),
        ),
      ),
    ],
  );
}