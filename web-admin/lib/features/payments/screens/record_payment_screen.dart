import '../../../core/models/audit_log_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/allocation_calculator.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/design_tokens.dart';

class RecordPaymentScreen extends StatefulWidget {
  final String? preselectedMemberId;
  final String? preselectedMemberName;

  const RecordPaymentScreen({
    super.key,
    this.preselectedMemberId,
    this.preselectedMemberName,
  });

  static Future<void> show(
    BuildContext context, {
    String? preselectedMemberId,
    String? preselectedMemberName,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordPaymentScreen(
        preselectedMemberId: preselectedMemberId,
        preselectedMemberName: preselectedMemberName,
      ),
    );
  }

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _memberId;
  String? _memberName;
  bool _loading = false;
  String? _formError;

  // Outstanding obligations loaded for selected member
  List<PaymentModel> _obligations = [];
  bool _loadingObligations = false;

  // Receipt summary data shown upon successful save
  RecordPaymentOutcome? _successResult;
  double _savedAmount = 0.0;
  String _savedReference = '';

  @override
  void initState() {
    super.initState();
    if (widget.preselectedMemberId != null) {
      _memberId = widget.preselectedMemberId;
      _memberName = widget.preselectedMemberName;
      _loadObligations(_memberId!);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadObligations(String uid) async {
    setState(() {
      _loadingObligations = true;
      _obligations = [];
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('payments')
          .where('uid', isEqualTo: uid)
          .where('status', whereIn: ['unpaid', 'overdue'])
          .get();

      final list = snap.docs
          .map((d) => PaymentModel.fromMap(d.data(), d.id))
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

      if (!mounted || _memberId != uid) return;
      setState(() {
        _obligations = list;
        _loadingObligations = false;
      });
    } catch (_) {
      if (!mounted || _memberId != uid) return;
      setState(() => _loadingObligations = false);
    }
  }

  double? _parseAmount(String? v) {
    if (v == null) return null;
    final n = double.tryParse(v.trim().replaceAll(',', ''));
    if (n == null || n.isNaN || n.isInfinite) return null;
    return n;
  }

  double get _totalOutstanding {
    double total = 0;
    for (final ob in _obligations) {
      final principalRem = ob.amount - ob.penaltyAmount - ob.paidAmount;
      final penaltyRem = ob.penaltyAmount;
      total += (principalRem > 0 ? principalRem : 0) + (penaltyRem > 0 ? penaltyRem : 0);
    }
    return total;
  }

  AllocationResult? get _currentPreview {
    final amt = _parseAmount(_amountCtrl.text);
    if (amt == null || amt <= 0 || _obligations.isEmpty) return null;

    final inputs = _obligations.map((ob) => ObligationInput(
      id: ob.id,
      amount: ob.amount,
      penaltyAmount: ob.penaltyAmount,
      paidAmount: ob.paidAmount,
      dueDate: ob.dueDate,
    )).toList();

    return computeAllocation(obligations: inputs, paymentAmount: amt);
  }

  Future<void> _submit() async {
    setState(() => _formError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_memberId == null) {
      setState(() => _formError = 'Please select a member.');
      return;
    }

    final amt = _parseAmount(_amountCtrl.text)!;
    final preview = _currentPreview;
    if (preview == null || preview.hasExcess) {
      setState(() => _formError = preview?.rejectionReason ?? 'Invalid payment amount.');
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final outcome = await _fs.recordPaymentWithAllocations(
        memberUid: _memberId!,
        memberName: _memberName ?? '',
        paymentAmount: amt,
        type: PaymentType.other,
        dueDate: DateTime.now(),
        recordedBy: auth.userModel?.uid ?? '',
        notes: _notesCtrl.text.trim(),
      );

      if (!outcome.applied) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _formError = 'Payment could not be applied.';
        });
        return;
      }

      // Audit log
      try {
        await SettingsService().logAction(
          performedBy: auth.userModel?.uid ?? '',
          performedByName: auth.userModel?.displayName ?? '',
          action: AuditAction.created,
          targetCollection: 'payment_transactions',
          targetId: '',
          description: 'Recorded cash payment of ₱${amt.toStringAsFixed(2)} for $_memberName',
        );
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _loading = false;
        _successResult = outcome;
        _savedAmount = amt;
        _savedReference = _referenceCtrl.text.trim();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _formError = 'Error recording payment: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _successResult != null
              ? _buildReceiptView()
              : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    final preview = _currentPreview;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Record Payment (Cash)',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: _loading ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Member selector
            const _SectionLabel('Member'),
            const SizedBox(height: 6),
            if (widget.preselectedMemberId != null)
              _ReadonlyChip(label: _memberName ?? '')
            else
              _MemberDropdown(
                fs: _fs,
                selectedId: _memberId,
                onSelected: (id, name) {
                  setState(() {
                    _memberId = id;
                    _memberName = name;
                  });
                  _loadObligations(id);
                },
              ),
            const SizedBox(height: 16),

            // Outstanding obligations summary & list
            if (_memberId != null) ...[
              const _SectionLabel('Outstanding Obligations (FIFO)'),
              const SizedBox(height: 6),
              if (_loadingObligations)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_obligations.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('This member has no outstanding obligations.',
                      style: TextStyle(color: AppColors.success, fontSize: 13)),
                )
              else ...[
                Text('Total Outstanding: ₱${_totalOutstanding.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.danger)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _obligations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final ob = _obligations[i];
                      final pRem = ob.amount - ob.penaltyAmount - ob.paidAmount;
                      final penRem = ob.penaltyAmount;
                      final totalRem = (pRem > 0 ? pRem : 0) + (penRem > 0 ? penRem : 0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('${ob.type.label}${ob.lotLabel.isNotEmpty ? ' (${ob.lotLabel})' : ''}',
                                  style: const TextStyle(fontSize: 12.5)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Due: ${_fmtDate(ob.dueDate)}',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                            ),
                            Text('₱${totalRem.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],

            // Amount input
            const _SectionLabel('Amount Received (₱)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = _parseAmount(v);
                if (n == null || n <= 0) return 'Enter a valid amount > 0';
                return null;
              },
              decoration: _fieldDec('0.00'),
            ),
            const SizedBox(height: 16),

            // Live FIFO allocation preview
            if (preview != null && _obligations.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: preview.hasExcess ? AppColors.dangerBg : AppColors.primaryBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: preview.hasExcess ? AppColors.danger : AppColors.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preview.hasExcess ? 'Excess Payment Warning' : 'FIFO Allocation Preview',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: preview.hasExcess ? AppColors.danger : AppColors.primaryHeader)),
                    const SizedBox(height: 4),
                    if (preview.hasExcess)
                      Text('Excess amount: ₱${preview.unappliedCredit.toStringAsFixed(2)} will be stored as unapplied credit.',
                          style: const TextStyle(fontSize: 12, color: AppColors.danger))
                    else
                      Text('Will allocate across ${preview.allocations.length} obligation(s).',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Payment method (Cash only) & Reference
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel('Payment Method'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderStrong),
                        ),
                        child: const Text('Cash (Office)', style: TextStyle(fontSize: 13.5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel('Reference Number (Optional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _referenceCtrl,
                        decoration: _fieldDec('e.g. Receipt / Ref #'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            const _SectionLabel('Notes (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: _fieldDec('Remarks...'),
            ),
            const SizedBox(height: 20),

            if (_formError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_formError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ),
              const SizedBox(height: 16),
            ],

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.textInverted,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Payment Successfully Recorded',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _receiptRow('Member:', _memberName ?? ''),
              _receiptRow('Amount Received:', '₱${_savedAmount.toStringAsFixed(2)}'),
              _receiptRow('Method:', 'Cash'),
              if (_savedReference.isNotEmpty) _receiptRow('Reference #:', _savedReference),
              _receiptRow('Date:', _fmtDate(DateTime.now())),
              if (_successResult!.unappliedCredit > 0)
                _receiptRow('Unapplied Credit:', '₱${_successResult!.unappliedCredit.toStringAsFixed(2)}', isHighlight: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Allocated Obligations (${_successResult!.allocations.length}):',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _successResult!.allocations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final alloc = _successResult!.allocations[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Obligation ID: ${alloc.obligationId.substring(0, 8)}...', style: const TextStyle(fontSize: 12)),
                    Text('Principal: ₱${alloc.allocatedPrincipal.toStringAsFixed(2)} | Penalty: ₱${alloc.allocatedPenalty.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.textInverted,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _receiptRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isHighlight ? AppColors.danger : AppColors.textPrimary)),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  InputDecoration _fieldDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderStrong)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderStrong)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryHover, width: 1.5)),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryHeader));
}

class _ReadonlyChip extends StatelessWidget {
  final String label;
  const _ReadonlyChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.borderStrong),
    ),
    child: Text(label, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary)),
  );
}

class _MemberDropdown extends StatelessWidget {
  final FirestoreService fs;
  final String? selectedId;
  final void Function(String id, String name) onSelected;

  const _MemberDropdown({required this.fs, required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MemberModel>>(
      stream: fs.streamMembers(),
      builder: (context, snap) {
        final members = [...(snap.data ?? <MemberModel>[])]
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return DropdownButtonFormField<String>(
          value: selectedId,
          hint: const Text('Select a member', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
          validator: (v) => v == null ? 'Please select a member' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderStrong)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderStrong)),
          ),
          items: members.map((m) => DropdownMenuItem<String>(
            value: m.uid,
            child: Text(m.name),
          )).toList(),
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
