// features/members/screens/member_ledger_card.dart
//
// Member account in proper T-account form, shown at the top of the member
// detail Payments tab. The member is treated as a customer in the
// Accounts Receivable subsidiary ledger:
//
//   DEBIT  (left)  = amounts charged to the member      (increases what they owe)
//   CREDIT (right) = payments received / waived amounts (decreases what they owe)
//
// Layout follows standard bookkeeping practice:
//   • account title above the "T", crossbar under the Debit / Credit headings
//   • every entry carries Date | Particulars | Amount
//   • the smaller side is closed with "Balance c/d" (carried down) so both
//     sides add up to the same total, which is double-underlined
//
// Postings come straight from the member's `payments` records:
//   • every non-voided record posts its `amount` as a debit
//   • a `paid` record posts its `amount` as a credit
//   • a partly-paid record posts its `paidAmount` as a credit
//   • a `waived` record posts its `amount` as a credit (cancels the debit)
//   • `voided` records are ignored on both sides

import 'package:flutter/material.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/payment_labels.dart'; // provides PaymentModel.typeLabel

class MemberLedgerCard extends StatefulWidget {
  final List<PaymentModel> payments;
  final String memberName;

  const MemberLedgerCard({
    super.key,
    required this.payments,
    this.memberName = '',
  });

  @override
  State<MemberLedgerCard> createState() => _MemberLedgerCardState();
}

class _MemberLedgerCardState extends State<MemberLedgerCard> {
  // ── Formatting ────────────────────────────────────────────────────────────
  static String _peso(double v) {
    final s = v.abs().toStringAsFixed(2).split('.');
    final whole = s[0];
    final buf = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    return '${v < 0 ? '-' : ''}₱$buf.${s[1]}';
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static const double _dateW = 78;

  // ── Posting ───────────────────────────────────────────────────────────────
  _Posted _post() {
    final debits = <_Entry>[];
    final credits = <_Entry>[];

    for (final p in widget.payments) {
      if (p.status == PaymentStatus.voided) continue;

      final sub = [
        if (p.lotLabel.trim().isNotEmpty) p.lotLabel.trim(),
        if (p.transactionId.trim().isNotEmpty) p.transactionId.trim(),
      ].join('  ·  ');

      debits.add(_Entry(
        date: p.dueDate,
        title: p.typeLabel,
        sub: sub,
        amount: p.amount,
      ));

      if (p.status == PaymentStatus.paid) {
        credits.add(_Entry(
          date: p.paidDate ?? p.dueDate,
          title: 'Payment · ${p.typeLabel}',
          sub: sub,
          amount: p.amount,
        ));
      } else if (p.status == PaymentStatus.waived) {
        credits.add(_Entry(
          date: p.dueDate,
          title: 'Waived · ${p.typeLabel}',
          sub: sub,
          amount: p.amount,
        ));
      } else if (p.paidAmount > 0) {
        credits.add(_Entry(
          date: p.paidDate ?? p.dueDate,
          title: 'Partial payment · ${p.typeLabel}',
          sub: sub,
          amount: p.paidAmount,
        ));
      }
    }

    // Oldest first, like a real ledger.
    debits.sort((a, b) => a.date.compareTo(b.date));
    credits.sort((a, b) => a.date.compareTo(b.date));

    return _Posted(debits, credits);
  }

  @override
  Widget build(BuildContext context) {
    final posted = _post();
    final totalDebit = posted.debits.fold<double>(0, (s, e) => s + e.amount);
    final totalCredit = posted.credits.fold<double>(0, (s, e) => s + e.amount);
    final balance = totalDebit - totalCredit;

    final String balanceLabel;
    final Color balanceColor;
    final Color balanceBg;
    if (balance > 0.005) {
      balanceLabel = 'Balance due ${_peso(balance)}';
      balanceColor = AppColors.danger;
      balanceBg = AppColors.dangerBg;
    } else if (balance < -0.005) {
      balanceLabel = 'Credit balance ${_peso(-balance)}';
      balanceColor = AppColors.primary;
      balanceBg = AppColors.primary.withOpacity(0.1);
    } else {
      balanceLabel = 'Settled · ${_peso(0)} due';
      balanceColor = AppColors.success;
      balanceBg = AppColors.successBg;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.textInverted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Account title ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Accounts Receivable',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                        widget.memberName.isEmpty
                            ? 'Member account · all lots'
                            : '${widget.memberName} · all lots',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: balanceBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(balanceLabel,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: balanceColor)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (posted.debits.isEmpty && posted.credits.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Text('No ledger entries yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            )
          else
            _tAccount(posted, totalDebit, totalCredit),

          // ── Legend ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: const Text(
              'Debit = charged to the member · Credit = paid or waived · '
              'c/d = carried down. The balance is the amount the member '
              'still owes.',
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // T-ACCOUNT VIEW
  // ═══════════════════════════════════════════════════════════════════════
  Widget _tAccount(_Posted p, double totalDebit, double totalCredit) {
    final balance = totalDebit - totalCredit;
    final debitBalance = balance > 0.005; // member owes (normal for A/R)
    final creditBalance = balance < -0.005; // member overpaid
    final hasCD = debitBalance || creditBalance;
    final grandTotal = totalDebit > totalCredit ? totalDebit : totalCredit;
    final today = DateTime.now();

    // "Balance c/d" closes whichever side is SMALLER so both totals match.
    final cd = _Entry(
        date: today,
        title: 'Balance c/d',
        sub: '',
        amount: balance.abs(),
        closing: true);

    final rowCount =
        (p.debits.length > p.credits.length
                ? p.debits.length
                : p.credits.length) +
            (hasCD ? 1 : 0);

    _Entry? slot(List<_Entry> list, bool carriesCD, int i) {
      if (hasCD && carriesCD && i == rowCount - 1) return cd;
      return i < list.length ? list[i] : null;
    }

    final debitRows = <_Entry?>[
      for (int i = 0; i < rowCount; i++) slot(p.debits, creditBalance, i)
    ];
    final creditRows = <_Entry?>[
      for (int i = 0; i < rowCount; i++) slot(p.credits, debitBalance, i)
    ];

    return LayoutBuilder(builder: (context, c) {
      // Phone width: two half-width columns are too cramped, so stack the
      // Debit and Credit sides (each still closed + totalled).
      if (c.maxWidth < 560) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _stackedSide('DEBIT', debitRows, grandTotal),
            const SizedBox(height: 4),
            _stackedSide('CREDIT', creditRows, grandTotal),
          ],
        );
      }

      const rule = VerticalDivider(
          width: 1, thickness: 1, color: AppColors.textSecondary);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Debit / Credit headings
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _sideHeading('DEBIT')),
                rule,
                Expanded(child: _sideHeading('CREDIT')),
              ],
            ),
          ),
          // The crossbar of the "T".
          Container(height: 1.5, color: AppColors.textPrimary),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _columnLabels()),
                rule,
                Expanded(child: _columnLabels()),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Postings, row by row so both sides line up.
          for (int i = 0; i < rowCount; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _entryCell(debitRows[i])),
                  rule,
                  Expanded(child: _entryCell(creditRows[i])),
                ],
              ),
            ),
          // Totals — equal on both sides, double-underlined.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _totalCell(grandTotal)),
                rule,
                Expanded(child: _totalCell(grandTotal)),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      );
    });
  }

  // One side on its own (phone layout).
  Widget _stackedSide(String heading, List<_Entry?> rows, double grandTotal) {
    final filled = rows.whereType<_Entry>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sideHeading(heading),
        Container(height: 1.5, color: AppColors.textPrimary),
        _columnLabels(),
        const Divider(height: 1, color: AppColors.border),
        if (filled.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('No entries.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          )
        else
          for (final e in filled) _entryCell(e),
        _totalCell(grandTotal),
      ],
    );
  }

  Widget _sideHeading(String heading) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Text(heading,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.textPrimary)),
      );

  Widget _columnLabels() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            SizedBox(
                width: _dateW,
                child: Text('Date',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted))),
            Expanded(
                child: Text('Particulars',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted))),
            Text('Amount',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
          ],
        ),
      );

  Widget _entryCell(_Entry? e) {
    if (e == null) return const SizedBox(height: 4);
    final italic = e.closing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _dateW,
            child: Text(_fmt(e.date),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            italic ? FontWeight.w700 : FontWeight.w600,
                        fontStyle:
                            italic ? FontStyle.italic : FontStyle.normal,
                        color: AppColors.textPrimary)),
                if (e.sub.isNotEmpty)
                  Text(e.sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_peso(e.amount),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: italic ? FontWeight.w700 : FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  // Total line: rule above, double underline below.
  Widget _totalCell(double amount) => Container(
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.textSecondary)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: _dateW),
                const Expanded(
                  child: Text('Total',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                ),
                Text(_peso(amount),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 4),
            Container(height: 1, color: AppColors.textSecondary),
            const SizedBox(height: 2),
            Container(height: 1, color: AppColors.textSecondary),
          ],
        ),
      );
}

class _Posted {
  final List<_Entry> debits;
  final List<_Entry> credits;
  const _Posted(this.debits, this.credits);
}

class _Entry {
  final DateTime date;
  final String title;
  final String sub;
  final double amount;

  /// True for the "Balance c/d" line (shown bold italic).
  final bool closing;

  const _Entry({
    required this.date,
    required this.title,
    required this.sub,
    required this.amount,
    this.closing = false,
  });
}