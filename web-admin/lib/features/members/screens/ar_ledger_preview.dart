// features/members/screens/ar_ledger_preview.dart
//
// Preview-before-export for the Accounts Receivable ledger:
// Select Member → Generate AR → Preview → Export PDF / Print.
//
// The dialog and the PDF are rendered from the SAME ArLedger built by
// ArLedgerService, so the export cannot drift from what the admin saw on
// screen. Read-only: nothing here writes to Firestore.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/services/ar_ledger_service.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/lot_pricing.dart';

class ArLedgerPreviewDialog extends StatefulWidget {
  final ArLedger ledger;
  final String memberName;

  const ArLedgerPreviewDialog({
    super.key,
    required this.ledger,
    required this.memberName,
  });

  static Future<void> show(
    BuildContext context, {
    required ArLedger ledger,
    required String memberName,
  }) {
    return showDialog(
      context: context,
      builder: (_) =>
          ArLedgerPreviewDialog(ledger: ledger, memberName: memberName),
    );
  }

  @override
  State<ArLedgerPreviewDialog> createState() => _ArLedgerPreviewDialogState();
}

class _ArLedgerPreviewDialogState extends State<ArLedgerPreviewDialog> {
  bool _busy = false;

  /// Stable for the whole preview so the dialog header and the PDF footer
  /// carry the same report ID.
  late final String reportId = 'AR-${_stamp(DateTime.now())}-${_slug(widget.memberName)}';

  Future<Uint8List> get _bytes => buildArLedgerPdf(
        ledger: widget.ledger,
        memberName: widget.memberName,
        reportId: reportId,
      );

  String _fileName() =>
      'lamhoai_ar_${_slug(widget.memberName).toLowerCase()}_${_stamp(DateTime.now())}.pdf';

  Future<void> _export() async {
    setState(() => _busy = true);
    final bytes = await _bytes;
    if (!mounted) return;
    setState(() => _busy = false);
    await Printing.sharePdf(bytes: bytes, filename: _fileName());
  }

  Future<void> _print() async {
    setState(() => _busy = true);
    await Printing.layoutPdf(onLayout: (_) async => await _bytes);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final ledger = widget.ledger;
    return Dialog(
      child: SizedBox(
        width: 880,
        height: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              memberName: widget.memberName,
              ledger: ledger,
              reportId: reportId,
            ),
            Expanded(
              child: ledger.hasEntries
                  ? _EntriesTable(ledger: ledger)
                  : const Center(child: Text('No ledger entries yet.')),
            ),
            _Summary(ledger: ledger),
            ButtonBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Export PDF'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _print,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print'),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// LAMHOAI header + member, scope, generation date, reporting period, report ID.
class _Header extends StatelessWidget {
  final String memberName;
  final ArLedger ledger;
  final String reportId;
  const _Header({
    required this.memberName,
    required this.ledger,
    required this.reportId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space5),
      color: AppColors.primaryHeader,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('LAMHOAI Homeowners Association',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textInverted)),
              ),
              Text(reportId,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary.withValues(alpha: 0.85))),
            ],
          ),
          const SizedBox(height: 2),
          const Text('Accounts Receivable — T-Account Statement',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.textInverted)),
          const SizedBox(height: AppSpacing.space3),
          Row(
            children: [
              Expanded(
                  child: _info('Member', memberName.isEmpty ? '—' : memberName)),
              Expanded(child: _info('Scope', 'All lots')),
              Expanded(child: _info('Generated', _fmtDMY(DateTime.now()))),
              Expanded(child: _info('Reporting period', _periodLabel(ledger))),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _info(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9.5, color: AppColors.primary.withValues(alpha: 0.85))),
        Text(value,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textInverted)),
      ],
    );

String _stamp(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

String _periodLabel(ArLedger ledger) {
  final e = ledger.entries;
  if (e.isEmpty) return '—';
  return '${_fmtDMY(e.first.date)} – ${_fmtDMY(e.last.date)}';
}

/// Debit | Credit transaction rows, zipped two-per-line like the T-account.
class _EntriesTable extends StatelessWidget {
  final ArLedger ledger;
  const _EntriesTable({required this.ledger});

  @override
  Widget build(BuildContext context) {
    final rows = <_Pair>[];
    final n =
        ledger.debits.length > ledger.credits.length ? ledger.debits.length : ledger.credits.length;
    for (var i = 0; i < n; i++) {
      rows.add(_Pair(
        i < ledger.debits.length ? ledger.debits[i] : null,
        i < ledger.credits.length ? ledger.credits[i] : null,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Super-header so the two halves read as Debit / Credit.
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(child: _sideTag('DEBIT', AppColors.danger)),
              Expanded(child: _sideTag('CREDIT', AppColors.success)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.background),
                headingTextStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted),
                dataTextStyle: const TextStyle(
                    fontSize: 11, color: AppColors.textPrimary),
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Particulars')),
                  DataColumn(label: Text('Reference')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Particulars')),
                  DataColumn(label: Text('Reference')),
                  DataColumn(label: Text('Amount')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(cells: [
                      DataCell(Text(r.d == null ? '' : _fmtDMY(r.d!.date))),
                      DataCell(Text(r.d?.particulars ?? '')),
                      DataCell(Text(r.d?.reference ?? '')),
                      DataCell(Text(
                          r.d == null ? '' : LotPricing.peso(r.d!.amount))),
                      DataCell(Text(r.c == null ? '' : _fmtDMY(r.c!.date))),
                      DataCell(Text(r.c?.particulars ?? '')),
                      DataCell(Text(r.c?.reference ?? '')),
                      DataCell(Text(
                          r.c == null ? '' : LotPricing.peso(r.c!.amount))),
                    ]),
                  DataRow(cells: [
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    DataCell(Text(LotPricing.peso(ledger.totalDebit),
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    DataCell(Text(LotPricing.peso(ledger.totalCredit),
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pair {
  final ArLedgerEntry? d;
  final ArLedgerEntry? c;
  const _Pair(this.d, this.c);
}

Widget _sideTag(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: color.withValues(alpha: 0.1),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: color)),
    );

/// Totals + outstanding balance + status — the numbers the PDF repeats.
class _Summary extends StatelessWidget {
  final ArLedger ledger;
  const _Summary({required this.ledger});

  @override
  Widget build(BuildContext context) {
    final balance = ledger.balance;
    final color = balance > 0.005
        ? AppColors.danger
        : balance < -0.005
            ? AppColors.primary
            : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(child: _stat('Total Debits', LotPricing.peso(ledger.totalDebit), null)),
          Expanded(child: _stat('Total Credits', LotPricing.peso(ledger.totalCredit), null)),
          Expanded(
              child: _stat('Outstanding Balance',
                  LotPricing.peso(balance.abs()), color)),
          Expanded(child: _stat('Status', ledger.statusLabel, color)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color? color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color ?? AppColors.textPrimary)),
        ],
      );
}

String _fmtDMY(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';

String _monthName(int m) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return names[m - 1];
}

String _slug(String memberName) {
  final s = memberName
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
      .trim()
      .split(' ')
      .where((s) => s.isNotEmpty)
      .join('-');
  return s.isEmpty ? 'MEMBER' : s;
}

// ═══════════════════════════════════════════════════════════════════════════
// PDF — same ArLedger, same numbers, paginated for paper.
// ═══════════════════════════════════════════════════════════════════════════
Future<Uint8List> buildArLedgerPdf({
  required ArLedger ledger,
  required String memberName,
  required String reportId,
}) async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final boldFont = await PdfGoogleFonts.notoSansBold();
  final generated = DateTime.now();

  pw.Widget txt(String t,
          {double size = 8.5,
          bool bold = false,
          PdfColor color = PdfColors.black,
          pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Text(t,
          textAlign: align,
          style: pw.TextStyle(
              font: bold ? boldFont : regular, fontSize: size, color: color));

  pw.Widget info(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          txt(label, size: 7.5, color: PdfColors.indigo100),
          txt(value, size: 10, bold: true, color: PdfColors.white),
        ],
      );

  pw.Widget statBox(String label, String value, PdfColor color) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              txt(label, size: 8, color: PdfColors.grey600),
              txt(value, size: 12, bold: true, color: color),
            ],
          ),
        ),
      );

  pw.Widget statRow(List<pw.Widget> boxes) => pw.Row(
        children: [
          for (var i = 0; i < boxes.length; i++) ...[
            if (i > 0) pw.SizedBox(width: 6),
            boxes[i],
          ],
        ],
      );

  final header = [
    pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(color: PdfColors.indigo900),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Expanded(child: txt('LAMHOAI Homeowners Association',
                size: 14, bold: true, color: PdfColors.white)),
            txt(reportId, size: 9, color: PdfColors.indigo100),
          ]),
          txt('Accounts Receivable — T-Account Statement',
              size: 9, bold: true, color: PdfColors.indigo100),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(child: info('Member', memberName.isEmpty ? '—' : memberName)),
            pw.Expanded(child: info('Scope', 'All lots')),
            pw.Expanded(child: info('Generated', _fmtDMY(generated))),
            pw.Expanded(child: info('Reporting period', _periodLabel(ledger))),
          ]),
        ],
      ),
    ),
    pw.SizedBox(height: 8),
    statRow([
      statBox('Total Debits', LotPricing.peso(ledger.totalDebit), PdfColors.black),
      statBox('Total Credits', LotPricing.peso(ledger.totalCredit), PdfColors.black),
      statBox('Outstanding Balance', LotPricing.peso(ledger.balance.abs()), PdfColors.red900),
      statBox('Status', ledger.statusLabel, PdfColors.indigo900),
    ]),
    pw.SizedBox(height: 8),
    txt('DEBIT — assessed charges  |  CREDIT — payments received',
        size: 9, bold: true, color: PdfColors.indigo900),
    pw.SizedBox(height: 2),
  ];

  final n = ledger.debits.length > ledger.credits.length
      ? ledger.debits.length
      : ledger.credits.length;
  final data = <List<String>>[
    for (var i = 0; i < n; i++)
      [
        i < ledger.debits.length ? _fmtDMY(ledger.debits[i].date) : '',
        i < ledger.debits.length ? ledger.debits[i].particulars : '',
        i < ledger.debits.length ? ledger.debits[i].reference : '',
        i < ledger.debits.length ? LotPricing.peso(ledger.debits[i].amount) : '',
        i < ledger.credits.length ? _fmtDMY(ledger.credits[i].date) : '',
        i < ledger.credits.length ? ledger.credits[i].particulars : '',
        i < ledger.credits.length ? ledger.credits[i].reference : '',
        i < ledger.credits.length ? LotPricing.peso(ledger.credits[i].amount) : '',
      ],
  ];

  final table = pw.TableHelper.fromTextArray(
    headers: const [
      'Date', 'Particulars', 'Reference', 'Amount',
      'Date', 'Particulars', 'Reference', 'Amount',
    ],
    data: data,
    headerCount: 1, // repeats the header on every page the table spans
    cellStyle: pw.TextStyle(font: regular, fontSize: 8),
    headerStyle: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
    cellAlignments: {
      3: pw.Alignment.centerRight,
      7: pw.Alignment.centerRight,
    },
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
  );

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: regular, bold: boldFont),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: txt('Page ${ctx.pageNumber} of ${ctx.pagesCount} · $reportId',
            size: 8, color: PdfColors.grey600),
      ),
      build: (ctx) => [
        ...header,
        table,
        pw.SizedBox(height: 8),
        statRow([
          statBox('Total Debits', LotPricing.peso(ledger.totalDebit), PdfColors.black),
          statBox('Total Credits', LotPricing.peso(ledger.totalCredit), PdfColors.black),
          statBox('Outstanding Balance', LotPricing.peso(ledger.balance.abs()), PdfColors.red900),
          statBox('Status', ledger.statusLabel, PdfColors.indigo900),
        ]),
        pw.SizedBox(height: 8),
        txt('Debit = charged to the member · Credit = paid or waived. '
            'This statement is for informational purposes only and is not an '
            'official receipt.',
            size: 8, color: PdfColors.grey600),
      ],
    ),
  );

  return Uint8List.fromList(await pdf.save());
}
