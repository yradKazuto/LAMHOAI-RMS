// features/reports/screens/reports_screen.dart
// Filter payments by date range / member / status
// Export to PDF or CSV

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/routing/app_router.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _fs = FirestoreService();

  DateTime?      _startDate;
  DateTime?      _endDate;
  PaymentStatus? _statusFilter;
  String?        _memberFilter;
  String?        _memberFilterName;
  bool           _exporting = false;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  // ── Filter payments ────────────────────────────────────────────────────────
  List<PaymentModel> _applyFilters(List<PaymentModel> all) {
    return all.where((p) {
      final matchStatus = _statusFilter == null ||
          p.status == _statusFilter;
      final matchMember = _memberFilter == null ||
          p.uid == _memberFilter;
      final matchStart = _startDate == null ||
          !p.dueDate.isBefore(_startDate!);
      final matchEnd = _endDate == null ||
          !p.dueDate.isAfter(_endDate!);
      return matchStatus && matchMember &&
          matchStart && matchEnd;
    }).toList();
  }

  String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              const ColorScheme.light(primary: _navy),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else         _endDate   = picked;
      });
    }
  }

  // ── Export to CSV ──────────────────────────────────────────────────────────
  Future<void> _exportCsv(List<PaymentModel> payments) async {
    setState(() => _exporting = true);
    try {
      final rows = [
        ['Member', 'Type', 'Amount', 'Status',
         'Due Date', 'Paid Date', 'Notes'],
        ...payments.map((p) => [
          p.memberName,
          p.type.label,
          p.amount.toStringAsFixed(2),
          p.status.label,
          _fmt(p.dueDate),
          _fmt(p.paidDate),
          p.notes,
        ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(csv.codeUnits);

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'lamhoai_payments_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Export to PDF ──────────────────────────────────────────────────────────
  Future<void> _exportPdf(List<PaymentModel> payments) async {
    setState(() => _exporting = true);
    try {
      final pdf  = pw.Document();
      final font = await PdfGoogleFonts.notoSansRegular();
      final bold = await PdfGoogleFonts.notoSansBold();

      // Chunk into pages of 20 rows
      const pageSize = 20;
      final chunks   = <List<PaymentModel>>[];
      for (var i = 0; i < payments.length; i += pageSize) {
        chunks.add(payments.sublist(
          i,
          i + pageSize > payments.length
              ? payments.length
              : i + pageSize,
        ));
      }

      for (final chunk in chunks) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(28),
            build: (pw.Context ctx) => pw.Column(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('LAMHOAI-RMS — Payment Report',
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 16,
                            color: PdfColors.indigo900)),
                    pw.Text(
                        'Generated: ${_fmt(DateTime.now())}',
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey600)),
                  ],
                ),
                pw.SizedBox(height: 6),
                if (_startDate != null ||
                    _endDate != null ||
                    _statusFilter != null)
                  pw.Text(
                    'Filters: '
                    '${_startDate != null ? 'From ${_fmt(_startDate)} ' : ''}'
                    '${_endDate != null ? 'To ${_fmt(_endDate)} ' : ''}'
                    '${_statusFilter != null ? 'Status: ${_statusFilter!.label}' : ''}',
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        color: PdfColors.grey600),
                  ),
                pw.SizedBox(height: 12),
                pw.Divider(
                    color: PdfColors.indigo100,
                    thickness: 1),
                pw.SizedBox(height: 8),

                // Table
                pw.Table(
                  border: pw.TableBorder.all(
                      color: PdfColors.grey200,
                      width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                    5: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                          color: PdfColors.indigo900),
                      children: [
                        'Member', 'Type', 'Amount',
                        'Status', 'Due Date', 'Paid Date',
                      ]
                          .map((h) => pw.Padding(
                                padding:
                                    const pw.EdgeInsets.all(6),
                                child: pw.Text(h,
                                    style: pw.TextStyle(
                                        font: bold,
                                        fontSize: 9,
                                        color:
                                            PdfColors.white)),
                              ))
                          .toList(),
                    ),
                    // Data rows
                    ...chunk.asMap().entries.map((e) {
                      final p   = e.value;
                      final bg  = e.key.isEven
                          ? PdfColors.white
                          : PdfColors.grey50;
                      return pw.TableRow(
                        decoration:
                            pw.BoxDecoration(color: bg),
                        children: [
                          p.memberName,
                          p.type.label,
                          '₱${p.amount.toStringAsFixed(2)}',
                          p.status.label,
                          _fmt(p.dueDate),
                          _fmt(p.paidDate),
                        ]
                            .map((cell) => pw.Padding(
                                  padding:
                                      const pw.EdgeInsets.all(
                                          5),
                                  child: pw.Text(cell,
                                      style: pw.TextStyle(
                                          font: font,
                                          fontSize: 8.5)),
                                ))
                            .toList(),
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 12),
                pw.Text(
                    'Total records: ${payments.length}  |  '
                    'Total collected: ₱${payments.where((p) => p.status == PaymentStatus.paid).fold(0.0, (s, p) => s + p.amount).toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 9,
                        color: PdfColors.indigo900)),
              ],
            ),
          ),
        );
      }

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'lamhoai_payments_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: _navy),
                  tooltip: 'Back to Dashboard',
                  onPressed: () => context.go(AppRoutes.dashboard),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reports & Export',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 2),
                    Text('Filter and export payment records',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Filters ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFFE0E8F4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filters',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _navy)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      // Date range
                      _DateFilter(
                        label: 'From Date',
                        date:  _startDate,
                        onTap: () => _pickDate(true),
                      ),
                      _DateFilter(
                        label: 'To Date',
                        date:  _endDate,
                        onTap: () => _pickDate(false),
                      ),

                      // Status filter
                      _FilterDropdown(
                        label: 'Status',
                        value: _statusFilter?.name,
                        hint:  'All Statuses',
                        items: [
                          const DropdownMenuItem(
                              value: null,
                              child: Text('All Statuses')),
                          ...PaymentStatus.values.map((s) =>
                              DropdownMenuItem(
                                  value: s.name,
                                  child: Text(s.label))),
                        ],
                        onChanged: (v) => setState(() =>
                            _statusFilter = v == null
                                ? null
                                : PaymentStatusExt
                                    .fromString(v)),
                      ),

                      // Member filter
                      _MemberDropdown(
                        fs:           _fs,
                        selectedId:   _memberFilter,
                        selectedName: _memberFilterName,
                        onSelected:   (id, name) =>
                            setState(() {
                              _memberFilter     = id;
                              _memberFilterName = name;
                            }),
                        onClear: () => setState(() {
                          _memberFilter     = null;
                          _memberFilterName = null;
                        }),
                      ),

                      // Clear all
                      if (_startDate != null ||
                          _endDate != null ||
                          _statusFilter != null ||
                          _memberFilter != null)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _startDate        = null;
                            _endDate          = null;
                            _statusFilter     = null;
                            _memberFilter     = null;
                            _memberFilterName = null;
                          }),
                          icon: const Icon(Icons.clear,
                              size: 15),
                          label: const Text('Clear All'),
                          style: TextButton.styleFrom(
                              foregroundColor:
                                  Colors.grey[600]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Results table ──────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<PaymentModel>>(
                stream: _fs.streamPayments(),
                builder: (context, snap) {
                  if (snap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final payments =
                      _applyFilters(snap.data ?? []);
                  final totalCollected = payments
                      .where((p) =>
                          p.status == PaymentStatus.paid)
                      .fold(0.0, (s, p) => s + p.amount);

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE0E8F4)),
                    ),
                    child: Column(
                      children: [
                        // Table toolbar
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF7F9FC),
                            borderRadius:
                                BorderRadius.vertical(
                                    top: Radius.circular(
                                        12)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${payments.length} records  '
                                '· Collected: ₱${totalCollected.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w600,
                                    color: _navy),
                              ),
                              const Spacer(),
                              // CSV export
                              OutlinedButton.icon(
                                onPressed: payments.isEmpty ||
                                        _exporting
                                    ? null
                                    : () =>
                                        _exportCsv(payments),
                                icon: const Icon(
                                    Icons.table_chart_outlined,
                                    size: 16),
                                label: const Text('CSV'),
                                style:
                                    OutlinedButton.styleFrom(
                                  foregroundColor: _navy,
                                  side: const BorderSide(
                                      color: Color(
                                          0xFFD0DBEE)),
                                  shape:
                                      RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      8)),
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                              horizontal: 14,
                                              vertical: 10),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // PDF export
                              ElevatedButton.icon(
                                onPressed: payments.isEmpty ||
                                        _exporting
                                    ? null
                                    : () =>
                                        _exportPdf(payments),
                                icon: _exporting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors
                                                    .white))
                                    : const Icon(
                                        Icons
                                            .picture_as_pdf_outlined,
                                        size: 16),
                                label: Text(_exporting
                                    ? 'Exporting...'
                                    : 'PDF'),
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor: _navy,
                                  foregroundColor:
                                      Colors.white,
                                  shape:
                                      RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      8)),
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                              horizontal: 14,
                                              vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Column headers
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                  flex: 3,
                                  child: _TH('Member')),
                              Expanded(
                                  flex: 2,
                                  child: _TH('Type')),
                              Expanded(
                                  flex: 2,
                                  child: _TH('Amount')),
                              Expanded(
                                  flex: 2,
                                  child: _TH('Due Date')),
                              Expanded(
                                  flex: 2,
                                  child: _TH('Paid Date')),
                              Expanded(
                                  flex: 2,
                                  child: _TH('Status')),
                            ],
                          ),
                        ),
                        const Divider(
                            height: 1,
                            color: Color(0xFFE0E8F4)),

                        if (payments.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Text(
                                  'No records match your filters.',
                                  style: TextStyle(
                                      color: Colors.grey)),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: payments.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(
                                      height: 1,
                                      color:
                                          Color(0xFFEEF2F9)),
                              itemBuilder: (_, i) =>
                                  _PaymentRow(
                                      payment: payments[i],
                                      fmt: _fmt),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Payment row ───────────────────────────────────────────────────────────────
class _PaymentRow extends StatelessWidget {
  final PaymentModel payment;
  final String Function(DateTime?) fmt;

  const _PaymentRow(
      {required this.payment, required this.fmt});

  Color _fg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return const Color(0xFF1A7A4A);
      case PaymentStatus.unpaid:  return const Color(0xFF7A6A1A);
      case PaymentStatus.overdue: return const Color(0xFFCC2200);
      case PaymentStatus.waived:  return const Color(0xFF5A7099);
    }
  }

  Color _bg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return const Color(0xFFEAF7F0);
      case PaymentStatus.unpaid:  return const Color(0xFFFFF8E0);
      case PaymentStatus.overdue: return const Color(0xFFFFF0EE);
      case PaymentStatus.waived:  return const Color(0xFFF0F4FB);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
        horizontal: 20, vertical: 12),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(payment.memberName,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0D2A5C)),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          flex: 2,
          child: Text(payment.type.label,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[700])),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '₱${payment.amount.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2B4A)),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(fmt(payment.dueDate),
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[600])),
        ),
        Expanded(
          flex: 2,
          child: Text(fmt(payment.paidDate),
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[600])),
        ),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _bg(payment.status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(payment.status.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _fg(payment.status))),
          ),
        ),
      ],
    ),
  );
}

// ── Small widgets ─────────────────────────────────────────────────────────────
class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5A7099),
          letterSpacing: 0.4));
}

class _DateFilter extends StatelessWidget {
  final String    label;
  final DateTime? date;
  final VoidCallback onTap;

  static const Color _navy = Color(0xFF0D2A5C);

  const _DateFilter({
    required this.label, required this.date,
    required this.onTap,
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _navy)),
      const SizedBox(height: 6),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: const Color(0xFFD0DBEE)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 15, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Text(
                date != null ? _fmt(date!) : 'Select date',
                style: TextStyle(
                    fontSize: 13,
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

class _FilterDropdown extends StatelessWidget {
  final String  label, hint;
  final String? value;
  final List<DropdownMenuItem<String?>> items;
  final void Function(String?) onChanged;

  static const Color _navy = Color(0xFF0D2A5C);

  const _FilterDropdown({
    required this.label, required this.hint,
    required this.value, required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _navy)),
      const SizedBox(height: 6),
      Container(
        height: 42,
        padding:
            const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: const Color(0xFFD0DBEE)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: value,
            hint: Text(hint,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400])),
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A2B4A)),
            icon: const Icon(Icons.expand_more, size: 18),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}

class _MemberDropdown extends StatelessWidget {
  final FirestoreService  fs;
  final String?           selectedId;
  final String?           selectedName;
  final void Function(String id, String name) onSelected;
  final VoidCallback      onClear;

  static const Color _navy = Color(0xFF0D2A5C);

  const _MemberDropdown({
    required this.fs,
    required this.selectedId,
    required this.selectedName,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: fs.streamMembers(),
      builder: (context, snap) {
        final members = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Member',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _navy)),
            const SizedBox(height: 6),
            Container(
              height: 42,
              width: 200,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFD0DBEE)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: selectedId,
                  hint: Text('All Members',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400])),
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1A2B4A)),
                  icon: const Icon(Icons.expand_more,
                      size: 18),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Members')),
                    ...members.map((m) =>
                        DropdownMenuItem<String?>(
                          value: m.uid,
                          child: Text(m.name,
                              overflow:
                                  TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) {
                    if (v == null) {
                      onClear();
                    } else {
                      final m = members
                          .firstWhere((m) => m.uid == v);
                      onSelected(m.uid, m.name);
                    }
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}