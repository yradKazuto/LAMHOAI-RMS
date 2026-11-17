// features/members/screens/member_ledger_card.dart
//
// Member account in T-account form, shown at the top of the member
// detail Payments tab. The member is treated as a customer in the
// Accounts Receivable subsidiary ledger:
//
//   DEBIT  (left)  = assessed charges (dues, fees, penalties, lot installments)
//   CREDIT (right) = payments received / waived amounts
//
// Layout:
//   • account title above the "T", crossbar under the Debit / Credit headings
//   • every entry carries Date | Particulars | Amount
//   • each side shows its OWN real total (total charged / total paid),
//     double-underlined. No "Balance c/d" padding row: the amount still
//     owed is shown in the pill at the top (total debit - total credit).
//
// Postings come from ArLedgerService (core/services/ar_ledger_service.dart),
// which reads `payments` + `lot_payments` + `payment_allocations` and posts
// every assessed charge as a debit and every received payment as a credit.
// A payment never creates a debit.

import 'package:flutter/material.dart';
import '../../../core/services/ar_ledger_service.dart';
import '../../../core/theme/design_tokens.dart';
import 'ar_ledger_preview.dart';

class MemberLedgerCard extends StatelessWidget {
  final ArLedger ledger;
  final String memberName;

  const MemberLedgerCard({
    super.key,
    required this.ledger,
    this.memberName = '',
  });

  @override
  Widget build(BuildContext context) {
    final balance = ledger.balance;

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
                        memberName.isEmpty
                            ? 'Member account · all lots'
                            : '$memberName · all lots',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => ArLedgerPreviewDialog.show(
                        context,
                        ledger: ledger,
                        memberName: memberName,
                      ),
                      icon: const Icon(Icons.preview_outlined, size: 18),
                      tooltip: 'Preview AR statement',
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      constraints: const BoxConstraints(minWidth: 32),
                    ),
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

          if (!ledger.hasEntries)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Text('No ledger entries yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            )
          else
            // All periods stay on the card, but the account itself never
            // grows past this — the member's payment history below stays
            // reachable without the page turning into one endless ledger.
            // Inside, only the entry rows scroll; the Debit/Credit
            // headings and the Totals line stay pinned.
            SizedBox(
              height: 380,
              child: _tAccount(),
            ),

          // ── Legend ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: const Text(
              'Debit = charged to the member · Credit = paid or waived. '
              'Balance due = total debit − total credit.',
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

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

  _Entry _map(ArLedgerEntry e) => _Entry(
        date: e.date,
        title: e.particulars,
        sub: e.note.isEmpty ? e.reference : '${e.note}  ·  ${e.reference}',
        amount: e.amount,
      );

  // ═══════════════════════════════════════════════════════════════════════
  // T-ACCOUNT VIEW
  // ═══════════════════════════════════════════════════════════════════════
  Widget _tAccount() {
    final debitList = ledger.debits.map(_map).toList();
    final creditList = ledger.credits.map(_map).toList();
    final totalDebit = ledger.totalDebit;
    final totalCredit = ledger.totalCredit;

    final rowCount =
        debitList.length > creditList.length ? debitList.length : creditList.length;

    // Pad the shorter side with empty slots so rows line up.
    final debitRows = <_Entry?>[
      for (int i = 0; i < rowCount; i++) i < debitList.length ? debitList[i] : null
    ];
    final creditRows = <_Entry?>[
      for (int i = 0; i < rowCount; i++) i < creditList.length ? creditList[i] : null
    ];

    return LayoutBuilder(builder: (context, c) {
      // Phone width: two half-width columns are too cramped, so stack the
      // Debit and Credit sides (each still totalled).
      if (c.maxWidth < 560) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _stackedSide('DEBIT', debitRows, totalDebit)),
            const SizedBox(height: 4),
            Expanded(child: _stackedSide('CREDIT', creditRows, totalCredit)),
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
          // Postings — the only region that scrolls, so the headings above
          // and the Totals line below never move.
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Column(
                  children: [
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
                  ],
                ),
              ),
            ),
          ),
          // Totals — each side shows its own real total.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _totalCell(totalDebit)),
                rule,
                Expanded(child: _totalCell(totalCredit)),
              ],
            ),
          ),
        ],
      );
    });
  }

  // One side on its own (phone layout).
  Widget _stackedSide(String heading, List<_Entry?> rows, double total) {
    final filled = rows.whereType<_Entry>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sideHeading(heading),
        Container(height: 1.5, color: AppColors.textPrimary),
        _columnLabels(),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              child: filled.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('No entries.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    )
                  : Column(
                      children: [for (final e in filled) _entryCell(e)]),
            ),
          ),
        ),
        _totalCell(total),
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
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
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
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
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

class _Entry {
  final DateTime date;
  final String title;
  final String sub;
  final double amount;

  const _Entry({
    required this.date,
    required this.title,
    required this.sub,
    required this.amount,
  });
}