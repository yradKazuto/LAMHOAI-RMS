// features/payments/screens/add_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/rate_history_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/design_tokens.dart';


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
  bool           _loading   = false;

  // Shown inside the dialog. A SnackBar would be hidden behind the modal.
  String?        _formError;

  // Once the user types an amount themselves we stop auto-filling it.
  bool           _amountEdited = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedMemberId != null) {
      _memberId   = widget.preselectedMemberId;
      _memberName = widget.preselectedMemberName;
    }
    _suggestAmount();
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

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
        return 'Monthly dues payment.';
      case PaymentType.membershipFee:
        return 'Yearly membership fee payment.';
      case PaymentType.monthlyMembership:
        return 'Monthly membership fee payment.';
      case PaymentType.lotPayment:
        return 'Lot amortization installment payment.';
      case PaymentType.penalty:
      case PaymentType.specialAssessment:
      case PaymentType.other:
        return '';
    }
  }

  /// Pre-fills the amount from the configured rate for the chosen type:
  ///  • Monthly Dues        → the monthly rate in effect for this month
  ///  • Annual Membership   → the annual fee from settings
  ///  • everything else     → left blank (installments vary per lot)
  /// Never overwrites an amount the user typed.
  Future<void> _suggestAmount() async {
    if (_amountEdited) return;
    final forType = _type;
    final now = DateTime.now();
    double? suggested;
    try {
      if (forType == PaymentType.dues) {
        suggested = await _rateSvc
            .getRateForMonth(DateTime(now.year, now.month, 1));
      } else if (forType == PaymentType.membershipFee) {
        suggested = (await _settings.getSettings()).dues.annual;
      } else if (forType == PaymentType.monthlyMembership) {
        suggested = await _rateSvc
            .getRateForMonth(DateTime(now.year, now.month, 1));
      }
    } catch (_) {
      return; // suggestion is a convenience — never block the form on it
    }
    // Ignore stale results if the user changed type while we waited.
    if (!mounted || _amountEdited || _type != forType) return;
    setState(() {
      _amount.text = (suggested != null && suggested > 0)
          ? suggested.toStringAsFixed(2)
          : '';
    });
  }

  Future<void> _submit() async {
    setState(() => _formError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_memberId == null) {
      setState(() => _formError = 'Please select a member.');
      return;
    }
    final amount = _parseAmount(_amount.text)!; // validated above

    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final outcome = await _fs.recordPaymentWithAllocations(
        memberUid: _memberId!,
        memberName: _memberName ?? '',
        paymentAmount: amount,
        type: _type,
        dueDate: DateTime.now(),
        recordedBy: auth.userModel?.uid ?? '',
        notes: _notes.text.trim(),
      );

      if (!outcome.applied) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _formError = 'Payment exceeds outstanding balance or was rejected.';
        });
        return;
      }

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
          targetCollection: 'payment_transactions',
          targetId:         '',
          description:
              'Recorded ${_type.label} payment of ₱${amount.toStringAsFixed(2)} '
              'for $_memberName',
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
                ? AppColors.warning
                : AppColors.success,
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
      backgroundColor: AppColors.surface,
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
                                  color: AppColors.textPrimary)),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close, color: AppColors.textMuted),
                          onPressed:
                              _loading ? null : () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // What this form does: records cash received, applied
                    // oldest-debt-first. Charge creation lives in the dues
                    // generator, not here.
                    const Text(
                      "Cash received is applied to the member's oldest "
                      'dues and installments first (FIFO). To create an '
                      'unpaid dues record, use Membership Dues → Generate.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
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
                        },
                      ),
                    const SizedBox(height: 20),

                    // ── Type ──────────────────────────────────────────────
                    _FormDropdown<PaymentType>(
                      label: 'Payment Type',
                      value: _type,
                      items: PaymentType.values,
                      labelOf: (v) => v.label,
                      onChanged: (v) {
                        setState(() => _type = v);
                        _suggestAmount();
                      },
                    ),
                    if (_typeHint.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_typeHint,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 20),

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
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: AppColors.dangerBg),
                        ),
                        child: Text(_formError!,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.danger)),
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
                              style: TextStyle(color: AppColors.textMuted)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textPrimary,
                            foregroundColor: AppColors.textInverted,
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
                                      color: AppColors.textInverted))
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
    hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.background,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderStrong)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderStrong)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
            color: AppColors.primaryHover, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.danger)),
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
          color: AppColors.primaryHeader));
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
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.borderStrong),
    ),
    child: Text(label,
        style: const TextStyle(
            fontSize: 13.5, color: AppColors.textPrimary)),
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
                  TextStyle(fontSize: 13, color: AppColors.textMuted)),
          style: const TextStyle(
              fontSize: 13.5, color: AppColors.textPrimary),
          validator: (v) =>
              v == null ? 'Please select a member' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.borderStrong)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.borderStrong)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.primaryHover, width: 1.5)),
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
              color: AppColors.primaryHeader)),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        value: value,
        style: const TextStyle(
            fontSize: 13.5, color: AppColors.textPrimary),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.borderStrong)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.borderStrong)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppColors.primaryHover, width: 1.5)),
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
              color: AppColors.primaryHeader)),
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
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: AppColors.borderStrong),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 10),
              Text(
                date != null
                    ? _fmt(date!)
                    : (optional ? 'Not set' : 'Select date'),
                style: TextStyle(
                    fontSize: 13.5,
                    color: date != null
                        ? AppColors.textPrimary
                        : AppColors.textMuted),
              ),
            ],
          ),
        ),
        ),
      ),
    ],
  );
}