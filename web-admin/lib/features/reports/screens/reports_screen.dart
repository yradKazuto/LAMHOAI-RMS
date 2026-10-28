// features/reports/screens/reports_screen.dart
// Filter payments by date range / member / status
// Export to PDF or CSV
// UPDATED — date range now follows the paid date for paid payments (when the
// cash came in) and the due date for everything else, so it agrees with the
// dashboard and Analytics "Collected" numbers.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/member_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/design_tokens.dart';
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

  
  
  

  @override
  void initState() {
    super.initState();
    _fs.syncOverdueStatuses();
  }

  // The date a record is filed under in this report. Paid payments use the
  // date the cash actually came in (paidDate) — so a September-due payment
  // settled in October belongs to October, matching the dashboard and the
  // Analytics collections chart. Everything else (unpaid, overdue, waived)
  // has no payment date, so it stays under its due date.
  DateTime _reportDate(PaymentModel p) =>
      (p.status == PaymentStatus.paid && p.paidDate != null)
          ? p.paidDate!
          : p.dueDate;

  List<PaymentModel> _applyFilters(List<PaymentModel> all) {
    // "To Date" is picked as midnight at the START of that day, but a
    // paidDate carries a time of day (Mark Paid stamps DateTime.now()).
    // Compare against the start of the NEXT day so a payment made on the
    // To Date itself isn't cut off.
    final endExclusive = _endDate == null
        ? null
        : DateTime(_endDate!.year, _endDate!.month, _endDate!.day + 1);

    return all.where((p) {
      final d = _reportDate(p);
      final matchStatus = _statusFilter == null ||
          p.displayStatus == _statusFilter;
      final matchMember = _memberFilter == null ||
          p.uid == _memberFilter;
      final matchStart = _startDate == null ||
          !d.isBefore(_startDate!);
      final matchEnd = endExclusive == null ||
          d.isBefore(endExclusive);
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
              ColorScheme.fromSeed(seedColor: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

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
          p.displayStatus.label,
          _fmt(p.dueDate),
          _fmt(p.paidDate),
          p.notes,
        ]),
      ];

      final csv   = const ListToCsvConverter().convert(rows);
      // UTF-8, not codeUnits (which truncates each UTF-16 code unit to a
      // byte and mangles anything non-ASCII — ₱, ñ, or whatever a staff
      // member typed into a payment's free-text Notes field). The
      // leading BOM makes Excel auto-detect UTF-8 instead of guessing
      // the system codepage and showing mojibake.
      final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
      final name  = 'lamhoai_payments_${DateTime.now().millisecondsSinceEpoch}.csv';

      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'text/csv', name: name)],
        text: 'LAMHOAI-RMS Payment Report (CSV)',
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

  Future<void> _exportPdf(List<PaymentModel> payments) async {
    setState(() => _exporting = true);
    try {
      final pdf  = pw.Document();
      final font = await PdfGoogleFonts.notoSansRegular();
      final bold = await PdfGoogleFonts.notoSansBold();

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
                    '${(_startDate != null || _endDate != null) ? '(paid payments by paid date, others by due date) ' : ''}'
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
                          p.displayStatus.label,
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
    final phoneScreen = MediaQuery.of(context).size.width < 560;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            phoneScreen ? 16 : 28,
            phoneScreen ? 14 : 28,
            phoneScreen ? 16 : 28,
            phoneScreen ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  tooltip: 'Back to Dashboard',
                  onPressed: () => context.go(AppRoutes.dashboard),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reports & Export',
                          style: AppTypography.greeting),
                      const SizedBox(height: AppSpacing.space0_5),
                      Text('Filter and export payment records',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, panelConstraints) {
                final phoneScreen = panelConstraints.maxWidth < 560;

                final dateFilters = [
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
                ];
                final otherFilters = [
                  _FilterDropdown(
                    label: 'Status',
                    value: _statusFilter?.name,
                    hint:  'All Statuses',
                    items: [
                      const DropdownMenuItem(
                          value: null,
                          child: Text('All Statuses')),
                      ...PaymentStatus.values.where((s) => s != PaymentStatus.waived).map((s) =>
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
                ];

                final hasFilter = _startDate != null ||
                    _endDate != null ||
                    _statusFilter != null ||
                    _memberFilter != null;

                return Container(
                  padding: EdgeInsets.all(phoneScreen ? 14 : 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.cardBorderRadius,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Filters',
                              style: AppTypography.sectionHeader.copyWith(
                                  fontSize: phoneScreen ? 13 : 14,
                                  color: AppColors.textPrimary)),
                          const Spacer(),
                          if (hasFilter)
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _startDate        = null;
                                _endDate          = null;
                                _statusFilter     = null;
                                _memberFilter     = null;
                                _memberFilterName = null;
                              }),
                              icon: const Icon(Icons.clear, size: 14),
                              label: Text('Clear All', style: AppTypography.button),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textMuted,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            ),
                        ],
                      ),
                      SizedBox(height: phoneScreen ? 10 : 16),
                      // A horizontal 2-column grid instead of a Wrap
                      // that just stacked every field on its own line
                      // below the panel's usual width.
                      Row(
                        children: [
                          Expanded(child: dateFilters[0]),
                          SizedBox(width: phoneScreen ? 10 : 14),
                          Expanded(child: dateFilters[1]),
                        ],
                      ),
                      SizedBox(height: phoneScreen ? 10 : 14),
                      Row(
                        children: [
                          Expanded(child: otherFilters[0]),
                          SizedBox(width: phoneScreen ? 10 : 14),
                          Expanded(child: otherFilters[1]),
                        ],
                      ),
                      SizedBox(height: phoneScreen ? 10 : 12),
                      Text(
                        'Date range uses the paid date for paid payments '
                        'and the due date for everything else.',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Not wrapped in Expanded — the whole page scrolls together
            // now (see the SingleChildScrollView in build()), so the
            // table renders its full natural height inline instead of
            // being its own independently-scrolling viewport.
            StreamBuilder<List<PaymentModel>>(
                stream: _fs.streamPayments(),
                builder: (context, snap) {
                  if (snap.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final payments =
                      _applyFilters(snap.data ?? []);
                  final totalCollected = payments
                      .where((p) =>
                          p.status == PaymentStatus.paid)
                      .fold(0.0, (s, p) => s + p.amount);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Six fixed-flex columns can't stay readable
                      // below this width — switch each row to a
                      // stacked card instead.
                      final compact = constraints.maxWidth < 700;

                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.textInverted,
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(AppRadius.lg)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${payments.length} records  '
                                      '· Collected: ₱${totalCollected.toStringAsFixed(2)}',
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: AppTypography.cardTitle.copyWith(
                                          color: AppColors.textPrimary),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: payments
                                                .isEmpty ||
                                            _exporting
                                        ? null
                                        : () => _exportCsv(
                                            payments),
                                    icon: const Icon(
                                        Icons
                                            .table_chart_outlined,
                                        size: 16),
                                    label: const Text('CSV'),
                                    style: OutlinedButton
                                        .styleFrom(
                                      foregroundColor: AppColors.textPrimary,
                                      side: const BorderSide(
                                          color: AppColors.borderStrong),
                                      shape:
                                          RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                          8)),
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                                  horizontal:
                                                      14,
                                                  vertical:
                                                      10),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: payments
                                                .isEmpty ||
                                            _exporting
                                        ? null
                                        : () => _exportPdf(
                                            payments),
                                    icon: _exporting
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child:
                                                CircularProgressIndicator(
                                                    strokeWidth:
                                                        2,
                                                    color: Colors
                                                        .white))
                                        : const Icon(
                                            Icons
                                                .picture_as_pdf_outlined,
                                            size: 16),
                                    label: Text(_exporting
                                        ? 'Exporting...'
                                        : 'PDF'),
                                    style: ElevatedButton
                                        .styleFrom(
                                      backgroundColor: AppColors.textPrimary,
                                      foregroundColor:
                                          AppColors.surface,
                                      shape:
                                          RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                          8)),
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                                  horizontal:
                                                      14,
                                                  vertical:
                                                      10),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (!compact) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12),
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
                                        child:
                                            _TH('Due Date')),
                                    Expanded(
                                        flex: 2,
                                        child:
                                            _TH('Paid Date')),
                                    Expanded(
                                        flex: 2,
                                        child: _TH('Status')),
                                  ],
                                ),
                              ),
                              const Divider(
                                  height: 1,
                                  color: AppColors.border),
                            ],

                            if (payments.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text(
                                      'No records match your filters.',
                                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted)),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: payments.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(
                                        height: 1,
                                        color: AppColors.border),
                                itemBuilder: (_, i) =>
                                    _PaymentRow(
                                        payment:
                                            payments[i],
                                        fmt: _fmt,
                                        compact: compact),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final PaymentModel payment;
  final String Function(DateTime?) fmt;
  final bool         compact;

  const _PaymentRow(
      {required this.payment, required this.fmt, this.compact = false});

  Color _fg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return AppColors.success;
      case PaymentStatus.unpaid:  return AppColors.warning;
      case PaymentStatus.overdue: return AppColors.danger;
      case PaymentStatus.waived:  return AppColors.textSecondary;
    }
  }

  Color _bg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return AppColors.successBg;
      case PaymentStatus.unpaid:  return AppColors.warningBg;
      case PaymentStatus.overdue: return AppColors.dangerBg;
      case PaymentStatus.waived:  return AppColors.background;
    }
  }

  Widget _statusPill() => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2_5, vertical: AppSpacing.space1),
    decoration: BoxDecoration(
      color: _bg(payment.displayStatus),
      borderRadius: AppRadius.pillBorderRadius,
    ),
    child: Text(payment.displayStatus.label,
        textAlign: TextAlign.center,
        style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: _fg(payment.displayStatus))),
  );

  @override
  Widget build(BuildContext context) {
    if (compact) {
      // Stacked card — six fixed columns don't have room to stay
      // readable at phone widths.
      return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4, vertical: AppSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(payment.memberName,
                      style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: AppSpacing.space1),
                _statusPill(),
              ],
            ),
            const SizedBox(height: AppSpacing.space1),
            Row(
              children: [
                Text(payment.type.label,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                const SizedBox(width: AppSpacing.space1),
                Text(
                  '₱${payment.amount.toStringAsFixed(2)}',
                  style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space1),
            Text(
              'Due ${fmt(payment.dueDate)}'
              '${payment.paidDate != null ? '  ·  Paid ${fmt(payment.paidDate)}' : ''}',
              style: AppTypography.caption,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding, vertical: AppSpacing.space3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(payment.memberName,
                style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Text(payment.type.label,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₱${payment.amount.toStringAsFixed(2)}',
              style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(fmt(payment.dueDate),
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text(fmt(payment.paidDate),
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: _statusPill(),
          ),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted));
}

class _DateFilter extends StatelessWidget {
  final String    label;
  final DateTime? date;
  final VoidCallback onTap;

  

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
      Text(label, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: AppSpacing.space1),
      InkWell(
        onTap: onTap,
        borderRadius: AppRadius.buttonBorderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space3, vertical: AppSpacing.space2),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadius.buttonBorderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 15, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.space2),
              Text(
                date != null ? _fmt(date!) : 'Select date',
                style: AppTypography.bodyMedium.copyWith(
                    color: date != null
                        ? AppColors.textPrimary
                        : AppColors.textMuted),
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

  

  const _FilterDropdown({
    required this.label, required this.hint,
    required this.value, required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: AppSpacing.space1),
      Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: AppRadius.buttonBorderRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: value,
            hint: Text(hint, style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted)),
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
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
            Text('Member', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.space1),
            SizedBox(
              height: 42,
              width: 220,
              child: Autocomplete<MemberModel>(
                displayStringForOption: (m) => m.name,
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return members;
                  }
                  return members.where((m) =>
                      m.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (m) => onSelected(m.uid, m.name),
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  if (selectedId == null && controller.text.isNotEmpty) {
                    controller.clear();
                  } else if (selectedName != null && controller.text != selectedName) {
                    controller.text = selectedName!;
                  }
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onEditingComplete: onEditingComplete,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search member...',
                      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: selectedId != null
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                controller.clear();
                                onClear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.buttonBorderRadius,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.buttonBorderRadius,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.buttonBorderRadius,
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}