// features/payments/screens/add_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/settings_service.dart';

class AddPaymentScreen extends StatefulWidget {
  final String? preselectedMemberId;
  final String? preselectedMemberName;

  const AddPaymentScreen({
    super.key,
    this.preselectedMemberId,
    this.preselectedMemberName,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _fs       = FirestoreService();
  final _amount   = TextEditingController();
  final _notes    = TextEditingController();

  String?        _memberId;
  String?        _memberName;
  PaymentType    _type      = PaymentType.dues;
  PaymentStatus  _status    = PaymentStatus.unpaid;
  DateTime       _dueDate   = DateTime.now();
  DateTime?      _paidDate;
  bool           _loading   = false;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  @override
  void initState() {
    super.initState();
    if (widget.preselectedMemberId != null) {
      _memberId   = widget.preselectedMemberId;
      _memberName = widget.preselectedMemberName;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isDueDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDueDate ? _dueDate : (_paidDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _navy),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isDueDate) _dueDate  = picked;
        else           _paidDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_memberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a member.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final id   = FirebaseFirestore.instance.collection('payments').doc().id;
      await _fs.addPayment(PaymentModel(
        id:         id,
        uid:        _memberId!,      // ← was memberId, now uid
        memberName: _memberName!,
        type:       _type,
        amount:     double.parse(_amount.text.trim()),
        status:     _status,
        dueDate:    _dueDate,
        paidDate:   _status == PaymentStatus.paid
            ? (_paidDate ?? DateTime.now())
            : null,
        recordedBy: auth.userModel?.uid ?? '',
        notes:      _notes.text.trim(),
        createdAt:  DateTime.now(),
      ));

      // ── Audit log ──────────────────────────────────────────────────────
      await SettingsService().logAction(
        performedBy:      auth.userModel?.uid ?? '',
        performedByName:  auth.userModel?.displayName ?? '',
        action:           AuditAction.created,
        targetCollection: 'payments',
        targetId:         id,
        description:
            'Recorded ${_type.label} payment of ₱${_amount.text.trim()} '
            'for $_memberName',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded successfully.'),
            backgroundColor: Color(0xFF1A7A4A),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Record Payment',
            style: TextStyle(
                color: _navy, fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0E8F4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment Details',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 24),

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
                        onSelected: (id, name) => setState(() {
                          _memberId   = id;
                          _memberName = name;
                        }),
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
                          onChanged: (v) => setState(() => _type = v),
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
                            }
                          }),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Amount ────────────────────────────────────────────
                    _SectionLabel('Amount (₱)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) {
                          return 'Enter a valid number';
                        }
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
        final members = snap.data ?? [];
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
                    child: Text('${m.name} — Lot ${m.lotNumber}'),
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
  final VoidCallback onTap;

  const _DatePicker({
    required this.label,
    required this.date,
    required this.onTap,
    this.optional = false,
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
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
    ],
  );
}