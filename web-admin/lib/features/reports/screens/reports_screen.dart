// features/reports/screens/reports_screen.dart
// Filter payments by date range / member / status
// Export to PDF or CSV
// UPDATED — date range now follows the paid date for paid payments (when the
// cash came in) and the due date for everything else, so it agrees with the
// dashboard and Analytics "Collected" numbers.
// FIXED — PDF preview dialogs now return their result via showDialog<bool>
// and export AFTER the dialog closes. Navigator.pop returns void, so the old
// `final ok = await Navigator.pop(ctx, true)` could never work.
// FIXED — PDF buttons now show the busy spinner while the PDF is being built
// (_confirmingExport), not only during CSV export (_exporting).
// UPDATED — payments PDF is now a per-member Statement of Account
// (outstanding balance, membership dues records, lot amortization schedule).
// UPDATED — statement tables now include a Transaction ID column.
// FIXED — preview dialog now uses the public PdfPreview widget from the
// `printing` package (PreviewScaffold is private to that package).
// TEMP — the Payments / General Ledger toggle is hidden via _kShowLedgerToggle.
// Set it to true to bring the General Ledger view back.

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
import '../../../core/utils/payment_labels.dart';
import '../../../core/models/member_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/ledger_service.dart';
import '../../../core/services/sale_service.dart';
import '../../../core/models/lot_payment_model.dart';
import '../../../core/models/lot_sale_model.dart';
import '../../../core/models/general_ledger_account_model.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/routing/app_router.dart';

// Temporarily hides the Payments / General Ledger toggle.
// Set to true to bring it back.
const bool _kShowLedgerToggle = false;

enum ReportView { payments, generalLedger }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _fs = FirestoreService();
  final _ls = LedgerService(); // consolidated statement reads general_ledger

  DateTime?      _startDate;
  ReportView     _view = ReportView.payments;

  DateTime?      _endDate;
  PaymentStatus? _statusFilter;
  String?        _memberFilter;
  String?        _memberFilterName;
  bool           _exporting = false;
  Uint8List?     _pendingPdfBytes;
  bool           _confirmingExport = false;

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

  /// Shows [bytes] in a preview dialog. Returns true only if the user taps
  /// Export. The actual sharing happens in the caller, AFTER the dialog has
  /// closed (Navigator.pop returns void, so it can't be awaited for a value).
  ///
  /// Uses PdfPreview (public, from package:printing). It scrolls on its own
  /// and needs a bounded height, so it sits in a fixed-size SizedBox rather
  /// than a SingleChildScrollView.
  Future<bool> _confirmPdfPreview({
    required String title,
    required Uint8List bytes,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Text(title),
        content: SizedBox(
          width: MediaQuery.of(ctx).size.width.clamp(0.0, 700.0),
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: PdfPreview(
            build: (_) => bytes,
            useActions: false,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            allowPrinting: false,
            allowSharing: false,
            pdfFileName: 'preview.pdf',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.surface),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Export'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _exportCsv(List<PaymentModel> payments) async {
    setState(() => _exporting = true);
    try {
      final rows = <List<dynamic>>[
        ['Member', 'Type', 'Amount', 'Status',
         'Due Date', 'Paid Date', 'Notes'],
        ...payments.map((p) => [
          p.memberName,
          p.typeLabel,
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
    setState(() => _confirmingExport = true);
    try {
      final bytes = await _buildPaymentsPdfBytes(payments);
      if (!mounted) return;
      setState(() => _pendingPdfBytes = bytes);

      final confirmed = await _confirmPdfPreview(
        title: 'Preview Statement of Account',
        bytes: bytes,
      );

      if (confirmed) {
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'lamhoai_payments_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _confirmingExport = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Statement-of-account PDF
  // One section per member: outstanding balance, membership dues / other
  // payment records, and the lot amortization schedule (lot_payments) for
  // each of their active lot sales.
  // ═══════════════════════════════════════════════════════════════════════════

  /// ₱1,234.50 style (thousands separators; Noto Sans has the ₱ glyph).
  static String _money(double v) {
    final neg = v < 0;
    final parts = v.abs().toStringAsFixed(2).split('.');
    final whole = parts[0]
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${neg ? '-' : ''}₱$whole.${parts[1]}';
  }

  String _saleLabel(LotSaleModel s) {
    final parts = <String>[
      if (s.phase.isNotEmpty) 'Phase ${s.phase}',
      if (s.block.isNotEmpty) 'Block ${s.block}',
      if (s.lotNumber.isNotEmpty) 'Lot ${s.lotNumber}',
    ];
    return parts.isEmpty ? 'Lot' : parts.join(' · ');
  }

  /// Same reference SaleService writes on the payment record:
  /// LP-<year>-<sale seq>-DP / P### (amortization only lists installment sales).
  String _lotTxnId(LotSaleModel s, LotPaymentModel p) {
    final seq  = s.saleSeq.toString().padLeft(4, '0');
    final tail = p.period == 0
        ? (s.termMonths == 0 ? 'CASH' : 'DP')
        : 'P${p.period.toString().padLeft(3, '0')}';
    return 'LP-${s.soldDate.year}-$seq-$tail';
  }

  PdfColor _duesColor(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return PdfColors.green700;
      case PaymentStatus.unpaid:  return PdfColors.orange700;
      case PaymentStatus.overdue: return PdfColors.red700;
      case PaymentStatus.waived:  return PdfColors.grey600;
      case PaymentStatus.voided:  return PdfColors.grey600;
    }
  }

  PdfColor _lotColor(LotPaymentStatus s) {
    switch (s) {
      case LotPaymentStatus.paid:      return PdfColors.green700;
      case LotPaymentStatus.scheduled: return PdfColors.orange700;
      case LotPaymentStatus.overdue:   return PdfColors.red700;
      case LotPaymentStatus.waived:    return PdfColors.grey600;
      case LotPaymentStatus.void_:     return PdfColors.grey600;
    }
  }

  bool _lotStillOwed(LotPaymentModel p) =>
      p.status != LotPaymentStatus.paid &&
      p.status != LotPaymentStatus.waived &&
      p.status != LotPaymentStatus.void_;

  /// Active installment sales + their full schedules, per member. Reads each
  /// stream once (`.first`); a failure for one member is logged and that
  /// member simply gets no amortization section.
  Future<Map<String, List<_SaleSchedule>>> _loadSchedules(
      Set<String> uids) async {
    final svc = SaleService();
    final result = <String, List<_SaleSchedule>>{};
    await Future.wait(uids.map((uid) async {
      try {
        final sales = await svc.streamSalesForBuyer(uid).first;
        final list = <_SaleSchedule>[];
        for (final s in sales.where(
            (s) => s.status == LotSaleStatus.active && s.termMonths > 0)) {
          final periods = (await svc.streamPaymentsForSale(s.id).first)
              .where((p) =>
                  p.amount > 0 && p.status != LotPaymentStatus.void_)
              .toList()
            ..sort((a, b) => a.period.compareTo(b.period));
          list.add(_SaleSchedule(s, periods));
        }
        if (list.isNotEmpty) result[uid] = list;
      } catch (e) {
        debugPrint('Schedule load failed for $uid: $e');
      }
    }));
    return result;
  }

  Future<Uint8List> _buildPaymentsPdfBytes(List<PaymentModel> payments) async {
    final regular  = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    // ── Group the (already filtered) dues records by member ────────────────
    final byMember = <String, List<PaymentModel>>{};
    final names    = <String, String>{};
    for (final p in payments) {
      byMember.putIfAbsent(p.uid, () => []).add(p);
      names[p.uid] = p.memberName;
    }
    // A selected member always gets a statement, even with no dues rows
    // (e.g. they only have a lot amortization).
    final selectedUid = _memberFilter;
    if (selectedUid != null) {
      byMember.putIfAbsent(selectedUid, () => []);
      names[selectedUid] =
          _memberFilterName ?? names[selectedUid] ?? 'Member';
    }

    final schedules = await _loadSchedules(byMember.keys.toSet());
    final uids = byMember.keys.toList()
      ..sort((a, b) => (names[a] ?? '')
          .toLowerCase()
          .compareTo((names[b] ?? '').toLowerCase()));

    // ── Small PDF building blocks ──────────────────────────────────────────
    pw.Widget txt(String t,
            {double size = 8.5,
            bool bold = false,
            PdfColor color = PdfColors.black,
            pw.TextAlign align = pw.TextAlign.left}) =>
        pw.Text(t,
            textAlign: align,
            style: pw.TextStyle(
                font: bold ? boldFont : regular,
                fontSize: size,
                color: color));

    pw.Widget cell(pw.Widget child) => pw.Padding(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: child,
        );

    pw.Widget dataTable({
      required List<String> headers,
      required Map<int, pw.TableColumnWidth> widths,
      required List<List<pw.Widget>> rows,
    }) {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: widths,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            children: headers
                .map((h) => cell(
                    txt(h, bold: true, color: PdfColors.white)))
                .toList(),
          ),
          for (var i = 0; i < rows.length; i++)
            pw.TableRow(
              decoration: pw.BoxDecoration(
                  color: i.isEven ? PdfColors.white : PdfColors.grey100),
              children: rows[i].map(cell).toList(),
            ),
        ],
      );
    }

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
                pw.SizedBox(height: 2),
                txt(value, size: 12, bold: true, color: color),
              ],
            ),
          ),
        );

    pw.Widget statRow(List<pw.Widget> boxes) => pw.Row(
          children: [
            for (var i = 0; i < boxes.length; i++) ...[
              if (i > 0) pw.SizedBox(width: 8),
              boxes[i],
            ],
          ],
        );

    pw.Widget sectionTitle(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: txt(t, size: 10, bold: true, color: PdfColors.indigo900),
        );

    // ── Amortization window ────────────────────────────────────────────────
    // Date filter set  → periods due inside From/To.
    // No date filter   → the last 12 months, up to today.
    // Overdue periods are always listed (see below) so nothing owed is hidden.
    final now      = DateTime.now();
    final hasRange = _startDate != null || _endDate != null;
    final DateTime? winStart = hasRange
        ? _startDate
        : DateTime(now.year - 1, now.month, now.day);
    final DateTime? winEndExcl = hasRange
        ? (_endDate == null
            ? null
            : DateTime(_endDate!.year, _endDate!.month, _endDate!.day + 1))
        : DateTime(now.year, now.month, now.day + 1);
    bool inWindow(DateTime d) =>
        (winStart == null || !d.isBefore(winStart)) &&
        (winEndExcl == null || d.isBefore(winEndExcl));
    final windowLabel = hasRange ? 'selected date range' : 'last 12 months';

    // ── Per-member sections + grand totals ─────────────────────────────────
    double grandPaid = 0, grandOutstanding = 0, grandOverdue = 0;
    final memberWidgets = <pw.Widget>[];

    for (final uid in uids) {
      final recs = (byMember[uid] ?? <PaymentModel>[])
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final scheds = schedules[uid] ?? const <_SaleSchedule>[];

      double paid = 0, outstanding = 0, overdue = 0;

      // Dues / other payment records
      for (final p in recs) {
        if (p.status == PaymentStatus.paid) {
          paid += p.amount;
        } else if (p.status != PaymentStatus.waived &&
            p.status != PaymentStatus.voided) {
          outstanding += p.amount;
          if (p.displayStatus == PaymentStatus.overdue) {
            overdue += p.amount;
          }
        }
      }
      // Lot amortization
      for (final s in scheds) {
        for (final p in s.periods) {
          if (p.status == LotPaymentStatus.paid) {
            paid += p.amount;
          } else if (_lotStillOwed(p)) {
            outstanding += p.amount;
            if (p.displayStatus == LotPaymentStatus.overdue) {
              overdue += p.amount;
            }
          }
        }
      }

      grandPaid        += paid;
      grandOutstanding += outstanding;
      grandOverdue     += overdue;

      // Member banner
      memberWidgets.add(pw.SizedBox(height: 14));
      memberWidgets.add(
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              txt(names[uid] ?? 'Member',
                  size: 12, bold: true, color: PdfColors.indigo900),
              txt('Outstanding balance: ${_money(outstanding)}',
                  size: 10,
                  bold: true,
                  color: outstanding > 0
                      ? PdfColors.red700
                      : PdfColors.green700),
            ],
          ),
        ),
      );
      memberWidgets.add(pw.SizedBox(height: 6));
      memberWidgets.add(statRow([
        statBox('Total paid', _money(paid), PdfColors.green700),
        statBox('Outstanding', _money(outstanding),
            outstanding > 0 ? PdfColors.orange700 : PdfColors.grey700),
        statBox('Overdue', _money(overdue),
            overdue > 0 ? PdfColors.red700 : PdfColors.grey700),
      ]));

      // Membership dues & other payments
      if (recs.isNotEmpty) {
        memberWidgets.add(sectionTitle('Membership Dues & Other Payments'));
        memberWidgets.add(dataTable(
          headers: const [
            'Transaction ID', 'Description', 'Due Date', 'Paid Date',
            'Amount', 'Status'
          ],
          widths: {
            0: const pw.FlexColumnWidth(2.3),
            1: const pw.FlexColumnWidth(2.6),
            2: const pw.FlexColumnWidth(1.3),
            3: const pw.FlexColumnWidth(1.3),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(1.1),
          },
          rows: [
            for (final p in recs)
              [
                txt(p.transactionId.isEmpty ? '—' : p.transactionId,
                    size: 8),
                txt(p.lotLabel.isEmpty
                    ? p.typeLabel
                    : '${p.typeLabel} · ${p.lotLabel}'),
                txt(_fmt(p.dueDate)),
                txt(_fmt(p.paidDate)),
                txt(_money(p.amount), align: pw.TextAlign.right),
                txt(p.displayStatus.label,
                    bold: true, color: _duesColor(p.displayStatus)),
              ],
          ],
        ));
      }

      // Lot amortization schedules
      for (final s in scheds) {
        final remaining = s.periods.where(_lotStillOwed).toList();
        final remainingSum =
            remaining.fold<double>(0.0, (sum, p) => sum + p.amount);

        // Only list the periods in the report window, not the whole term
        // (a 300-period schedule would run to dozens of pages). Totals and
        // "remaining balance" above still use the FULL schedule.
        final shown = s.periods
            .where((p) => inWindow(p.dueDate) ||
                p.displayStatus == LotPaymentStatus.overdue)
            .toList();

        memberWidgets.add(
            sectionTitle('Monthly Amortization — ${_saleLabel(s.sale)}'));
        memberWidgets.add(txt(
          'Term: ${s.sale.termMonths} months   ·   '
          '${remaining.length} of ${s.periods.length} periods remaining   ·   '
          'Remaining balance: ${_money(remainingSum)}',
          size: 8.5,
          color: PdfColors.grey700,
        ));
        memberWidgets.add(txt(
          'Showing ${shown.length} of ${s.periods.length} periods '
          '($windowLabel; overdue periods always shown)',
          size: 8,
          color: PdfColors.grey600,
        ));
        memberWidgets.add(pw.SizedBox(height: 4));
        if (shown.isEmpty) {
          memberWidgets.add(txt('No installment periods in this range.',
              color: PdfColors.grey600));
        } else {
        memberWidgets.add(dataTable(
          headers: const [
            'Transaction ID', 'Period', 'Due Date', 'Amount', 'Status'
          ],
          widths: {
            0: const pw.FlexColumnWidth(2.4),
            1: const pw.FlexColumnWidth(1.3),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.7),
            4: const pw.FlexColumnWidth(1.3),
          },
          rows: [
            for (final p in shown)
              [
                txt(_lotTxnId(s.sale, p), size: 8),
                txt(p.period == 0 ? 'Down payment' : 'Period ${p.period}'),
                txt(_fmt(p.dueDate)),
                txt(_money(p.amount), align: pw.TextAlign.right),
                txt(p.displayStatus.label,
                    bold: true, color: _lotColor(p.displayStatus)),
              ],
          ],
        ));
        }
      }

      if (recs.isEmpty && scheds.isEmpty) {
        memberWidgets.add(pw.SizedBox(height: 6));
        memberWidgets.add(txt('No payment records for this member.',
            color: PdfColors.grey600));
      }
    }

    // ── Report header ──────────────────────────────────────────────────────
    final filterBits = <String>[
      if (_startDate != null) 'From ${_fmt(_startDate)}',
      if (_endDate != null) 'To ${_fmt(_endDate)}',
      if (_statusFilter != null) 'Status: ${_statusFilter!.label}',
      if (_memberFilterName != null) 'Member: $_memberFilterName',
    ];

    final header = <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              txt('LAMHSYS',
                  size: 18, bold: true, color: PdfColors.indigo900),
              pw.SizedBox(height: 2),
              txt('Statement of Account',
                  size: 12, color: PdfColors.grey700),
            ],
          ),
          txt('Generated: ${_fmt(DateTime.now())}',
              size: 9, color: PdfColors.grey600),
        ],
      ),
      pw.SizedBox(height: 6),
      if (filterBits.isNotEmpty)
        txt('Filters: ${filterBits.join('   ·   ')}'
            '${(_startDate != null || _endDate != null) ? '   (paid payments by paid date, others by due date)' : ''}',
            size: 8.5,
            color: PdfColors.grey600),
      pw.SizedBox(height: 8),
      pw.Divider(color: PdfColors.indigo100, thickness: 1),
      pw.SizedBox(height: 8),
      statRow([
        statBox('Members', '${uids.length}', PdfColors.indigo900),
        statBox('Total paid', _money(grandPaid), PdfColors.green700),
        statBox('Total outstanding', _money(grandOutstanding),
            grandOutstanding > 0 ? PdfColors.orange700 : PdfColors.grey700),
        statBox('Total overdue', _money(grandOverdue),
            grandOverdue > 0 ? PdfColors.red700 : PdfColors.grey700),
      ]),
    ];

    final footnote = <pw.Widget>[
      pw.SizedBox(height: 18),
      pw.Divider(color: PdfColors.grey300, thickness: 0.5),
      pw.SizedBox(height: 4),
      txt(
        'Outstanding = unpaid + overdue amounts (waived and voided records '
        'are excluded). Dues records follow the report filters. Amortization '
        'tables list only periods due in the selected date range (default: '
        'last 12 months) plus any overdue periods; balances always cover the '
        'full schedule of each active lot sale.',
        size: 7.5,
        color: PdfColors.grey600,
      ),
    ];

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
          child: txt('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              size: 8, color: PdfColors.grey600),
        ),
        build: (ctx) => [...header, ...memberWidgets, ...footnote],
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  Future<void> _exportLedgerCsv(List<GeneralLedgerAccount> accounts) async {
    setState(() => _exporting = true);
    try {
      final rows = <List<dynamic>>[
        ['Account', 'Balance', 'Last Updated'],
        ...accounts.map((r) => [
          r.id,
          r.balance.toStringAsFixed(2),
          r.lastUpdated == null ? '—' : _fmt(r.lastUpdated),
        ]),
      ];

      final csv   = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
      final name  = 'lamhoai_ledger_${DateTime.now().millisecondsSinceEpoch}.csv';

      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'text/csv', name: name)],
        text: 'LAMHOAI-RMS General Ledger (CSV)',
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

  Future<void> _exportLedgerPdf(List<GeneralLedgerAccount> accounts) async {
    setState(() => _confirmingExport = true);
    try {
      final bytes = await _buildLedgerPdfBytes(accounts);
      if (!mounted) return;

      final confirmed = await _confirmPdfPreview(
        title: 'Preview General Ledger',
        bytes: bytes,
      );

      if (confirmed) {
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'lamhoai_ledger_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _confirmingExport = false);
    }
  }

  Future<Uint8List> _buildLedgerPdfBytes(List<GeneralLedgerAccount> accounts) async {
    final pdf   = pw.Document();
    final font  = await PdfGoogleFonts.notoSansRegular();
    final bold  = await PdfGoogleFonts.notoSansBold();
    final total = accounts.fold<double>(0.0, (s, r) => s + r.balance);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('LAMHOAI-RMS — General Ledger',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 16,
                        color: PdfColors.indigo900)),
                pw.Text('Generated: ${_fmt(DateTime.now())}',
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: PdfColors.grey600)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey200, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.indigo900),
                  children: ['Account', 'Balance', 'Last Updated']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(h,
                                style: pw.TextStyle(
                                    font: bold,
                                    fontSize: 9,
                                    color: PdfColors.white)),
                          ))
                      .toList(),
                ),
                ...accounts.asMap().entries.map((e) {
                  final r  = e.value;
                  final bg = e.key.isEven
                      ? PdfColors.white
                      : PdfColors.grey50;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      r.id,
                      '₱${r.balance.toStringAsFixed(2)}',
                      r.lastUpdated == null ? '—' : _fmt(r.lastUpdated),
                    ]
                        .map((cell) => pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
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
                'Total balance: ₱${total.toStringAsFixed(2)}  |  ${accounts.length} accounts',
                style: pw.TextStyle(
                    font: bold,
                    fontSize: 9,
                    color: PdfColors.indigo900)),
          ],
        ),
      ),
    );

    return Uint8List.fromList(await pdf.save());
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
                      ...PaymentStatus.values
                          .where((s) =>
                              s != PaymentStatus.waived &&
                              s != PaymentStatus.voided)
                          .map((s) => DropdownMenuItem(
                              value: s.name,
                              child: Text(s.label))),
                      DropdownMenuItem(
                          value: PaymentStatus.voided.name,
                          child: Text('${PaymentStatus.voided.label}  (audit trail)')),
                    ],
                    onChanged: (v) => setState(() =>
                        _statusFilter = v == null
                            ? null
                            : PaymentStatusExt.fromString(v)),
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
                      // Report view toggle — itemized payments or consolidated
                      // statement. Hidden while _kShowLedgerToggle is false.
                      if (_kShowLedgerToggle) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: AppRadius.buttonBorderRadius,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SegmentedButton<ReportView>(
                            segments: const [
                              ButtonSegment(
                                value: ReportView.payments,
                                label: Text('Payments'),
                              ),
                              ButtonSegment(
                                value: ReportView.generalLedger,
                                label: Text('General Ledger'),
                              ),
                            ],
                            selected: {_view},
                            onSelectionChanged: (set) =>
                                setState(() => _view = set.first),
                          ),
                        ),
                        SizedBox(height: phoneScreen ? 10 : 14),
                      ],
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

            // General Ledger view shows balances; otherwise itemized payments.
            // The ledger panel is only reachable while the toggle is enabled.
            if (_kShowLedgerToggle && _view == ReportView.generalLedger)
              _buildLedgerPanel(context)
            else
              _buildPaymentsPanel(context),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Payments panel
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPaymentsPanel(BuildContext context) {
    return StreamBuilder<List<PaymentModel>>(
      stream: _fs.streamPayments(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final payments = _applyFilters(snap.data ?? []);
        final totalCollected = payments
            .where((p) => p.status == PaymentStatus.paid)
            .fold(0.0, (s, p) => s + p.amount);
        final busy = _exporting || _confirmingExport;

        return LayoutBuilder(
          builder: (context, constraints) {
            // Six fixed-flex columns can't stay readable below this
            // width — switch each row to a stacked card instead.
            final compact = constraints.maxWidth < 700;

            return Container(
              decoration: BoxDecoration(
                color: AppColors.textInverted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
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
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cardTitle.copyWith(
                                color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: payments.isEmpty || busy
                              ? null
                              : () => _exportCsv(payments),
                          icon: const Icon(Icons.table_chart_outlined,
                              size: 16),
                          label: const Text('CSV'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(
                                color: AppColors.borderStrong),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: payments.isEmpty || busy
                              ? null
                              : () => _exportPdf(payments),
                          icon: busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 16),
                          label: Text(busy ? 'Working...' : 'PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textPrimary,
                            foregroundColor: AppColors.surface,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!compact) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: _TH('Member')),
                          Expanded(flex: 2, child: _TH('Type')),
                          Expanded(flex: 2, child: _TH('Amount')),
                          Expanded(flex: 2, child: _TH('Due Date')),
                          Expanded(flex: 2, child: _TH('Paid Date')),
                          Expanded(flex: 2, child: _TH('Status')),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                  ],

                  if (payments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('No records match your filters.',
                            style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textMuted)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: payments.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1, color: AppColors.border),
                      itemBuilder: (_, i) => _PaymentRow(
                          payment: payments[i],
                          fmt: _fmt,
                          compact: compact),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Consolidated Statement — General Ledger balances
  // (currently unreachable while _kShowLedgerToggle is false)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLedgerPanel(BuildContext context) {
    return FutureBuilder<List<GeneralLedgerAccount>>(
      future: _ls.getLedgerRows(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Failed to load ledgers: ${snap.error}',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
          );
        }
        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No ledgers found.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
          );
        }
        final total   = rows.fold<double>(0.0, (s, r) => s + r.balance);
        final compact = MediaQuery.of(context).size.width < 700;
        final busy    = _exporting || _confirmingExport;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.textInverted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${rows.length} accounts  · Total balance: ₱${total.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cardTitle
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => _exportLedgerCsv(rows),
                      icon: const Icon(Icons.table_chart_outlined,
                          size: 16),
                      label: const Text('CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(
                            color: AppColors.borderStrong),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: busy
                          ? null
                          : () => _exportLedgerPdf(rows),
                      icon: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.picture_as_pdf_outlined,
                              size: 16),
                      label: Text(busy ? 'Working...' : 'PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const Divider(height: 1, color: AppColors.border),
              ],
              ...rows.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.cardPadding,
                        vertical: AppSpacing.space3),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: Text(r.id,
                                style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textPrimary))),
                        Expanded(
                            flex: 2,
                            child: Text(
                                '₱${r.balance.toStringAsFixed(2)}',
                                style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary))),
                        Expanded(
                            flex: 2,
                            child: Text(
                                r.lastUpdated == null
                                    ? '—'
                                    : _fmt(r.lastUpdated),
                                style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textSecondary))),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Payment row
// ═════════════════════════════════════════════════════════════════════════════
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
      case PaymentStatus.voided:  return AppColors.textSecondary;
    }
  }

  Color _bg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return AppColors.successBg;
      case PaymentStatus.unpaid:  return AppColors.warningBg;
      case PaymentStatus.overdue: return AppColors.dangerBg;
      case PaymentStatus.waived:  return AppColors.background;
      case PaymentStatus.voided:  return AppColors.background;
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
                Text(payment.typeLabel,
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
            child: Text(payment.typeLabel,
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
    return StreamBuilder<List<MemberModel>>(
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

// One active lot sale + its amortization periods (used by the statement PDF).
class _SaleSchedule {
  final LotSaleModel sale;
  final List<LotPaymentModel> periods;
  const _SaleSchedule(this.sale, this.periods);
}