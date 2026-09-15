// features/settings/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/hoa_settings_model.dart';
import '../../../core/models/monthly_rate_model.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/rate_history_service.dart';
import '../../../core/routing/app_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _svc = SettingsService();
  bool  _saving = false;

  final _name          = TextEditingController();
  final _address       = TextEditingController();
  final _contact       = TextEditingController();
  final _email         = TextEditingController();
  final _president     = TextEditingController();
  final _annual        = TextEditingController();
  final _assessment    = TextEditingController();
  final _penalty       = TextEditingController();
  final _graceDays     = TextEditingController();

  bool _loaded = false;

  static const Color _navy   = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _bg     = Color(0xFFF4F7FB);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _svc.getSettings();
      setState(() {
        _name.text       = settings.name;
        _address.text    = settings.address;
        _contact.text    = settings.contactNumber;
        _email.text      = settings.email;
        _president.text  = settings.president;
        _annual.text     = settings.dues.annual.toStringAsFixed(0);
        _assessment.text = settings.dues.specialAssessment.toStringAsFixed(0);
        _penalty.text    = settings.dues.penalty.toStringAsFixed(0);
        _graceDays.text  = settings.dues.penaltyGraceDays.toString();
        _loaded = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loaded = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load settings: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _name.dispose(); _address.dispose();
    _contact.dispose(); _email.dispose();
    _president.dispose();
    _annual.dispose(); _assessment.dispose();
    _penalty.dispose(); _graceDays.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final auth     = context.read<AuthProvider>();
      final settings = HoaSettingsModel(
        name:          _name.text.trim(),
        address:       _address.text.trim(),
        contactNumber: _contact.text.trim(),
        email:         _email.text.trim(),
        president:     _president.text.trim(),
        dues: DuesConfig(
          annual:            double.tryParse(_annual.text.trim())     ?? 0,
          specialAssessment: double.tryParse(_assessment.text.trim()) ?? 0,
          penalty:           double.tryParse(_penalty.text.trim())    ?? 0,
          penaltyGraceDays:  int.tryParse(_graceDays.text.trim())     ?? 5,
        ),
      );

      await _svc.saveSettings(settings);

      await _svc.logAction(
        performedBy:      auth.userModel?.uid ?? '',
        performedByName:  auth.userModel?.displayName ?? '',
        action:           AuditAction.updated,
        targetCollection: 'settings',
        targetId:         'hoa_settings',
        description:      'Updated HOA settings',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully.'),
            backgroundColor: Color(0xFF1A7A4A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showDuesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 520,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Dues Configuration',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: _DuesTab(
                    annual:     _annual,
                    assessment: _assessment,
                    penalty:    _penalty,
                    graceDays:  _graceDays,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: _navy),
                  tooltip: 'Close',
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go(AppRoutes.dashboard);
                    }
                  },
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text('Settings',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 2),
                    Text('HOA profile and dues configuration',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600])),
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Text('Save Changes'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: !_loaded
                  ? const Center(
                      child: CircularProgressIndicator())
                  : _ProfileTab(
                      name:      _name,
                      address:   _address,
                      contact:   _contact,
                      email:     _email,
                      president: _president,
                      onOpenDuesConfig: () => _showDuesDialog(context),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final TextEditingController name, address, contact,
      email, president;
  final VoidCallback onOpenDuesConfig;

  static const Color _navy = Color(0xFF1E293B);

  const _ProfileTab({
    required this.name,
    required this.address,
    required this.contact,
    required this.email,
    required this.president,
    required this.onOpenDuesConfig,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFE0E8F4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Association Information',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _navy)),
            const SizedBox(height: 20),
            _SettingsField(
              label: 'Association Name',
              hint:  'La Milagrosa Homeowners Association',
              ctrl:  name,
            ),
            const SizedBox(height: 16),
            _SettingsField(
              label: 'Address',
              hint:  'Barangay, City, Province',
              ctrl:  address,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: _SettingsField(
                  label: 'Contact Number',
                  hint:  '09XX-XXX-XXXX',
                  ctrl:  contact,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SettingsField(
                  label: 'Email Address',
                  hint:  'admin@lamhoai.com',
                  ctrl:  email,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _SettingsField(
              label: 'HOA President',
              hint:  'Full name of current president',
              ctrl:  president,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onOpenDuesConfig,
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('Dues Configuration'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuesTab extends StatelessWidget {
  final TextEditingController annual, assessment, penalty, graceDays;

  static const Color _navy = Color(0xFF1E293B);

  const _DuesTab({
    required this.annual,
    required this.assessment,
    required this.penalty,
    required this.graceDays,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set the default amounts for each payment type. '
            'These are reference values for recording payments.',
            style: TextStyle(
                fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),

          // ── Monthly rate now uses history instead of a single field ──────
          const _MonthlyRateSection(),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(
              child: _DuesField(
                label:       'Annual Dues',
                hint:        '2000',
                ctrl:        annual,
                icon:        Icons.calendar_month_outlined,
                color:       const Color(0xFF1A7A4A),
                description: 'Full year payment',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _DuesField(
                label:       'Special Assessment',
                hint:        '500',
                ctrl:        assessment,
                icon:        Icons.assignment_outlined,
                color:       const Color(0xFF7A3A1A),
                description: 'One-time special charge',
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _DuesField(
                label:       'Penalty',
                hint:        '50',
                ctrl:        penalty,
                icon:        Icons.warning_amber_outlined,
                color:       const Color(0xFFCC2200),
                description: 'Flat late payment penalty',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _DuesField(
                label:       'Grace Period (days)',
                hint:        '5',
                ctrl:        graceDays,
                icon:        Icons.hourglass_empty,
                color:       const Color(0xFF7A6A1A),
                description: 'Days after due date before penalty applies',
                isWholeNumber: true,
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF2563EB)
                      .withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16,
                    color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These amounts are used as default suggestions when recording payments. '
                    'You can still enter a different amount per transaction.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF1A4A9C)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Monthly rate history section ────────────────────────────────────────────
class _MonthlyRateSection extends StatefulWidget {
  const _MonthlyRateSection();

  @override
  State<_MonthlyRateSection> createState() => _MonthlyRateSectionState();
}

class _MonthlyRateSectionState extends State<_MonthlyRateSection> {
  final _rateSvc   = RateHistoryService();
  final _newAmount = TextEditingController();
  bool  _adding    = false;

  static const Color _navy = Color(0xFF1E293B);

  @override
  void dispose() {
    _newAmount.dispose();
    super.dispose();
  }

  static const _monthNames = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  String _monthLabel(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

  Future<void> _submitNewRate() async {
    final amount = double.tryParse(_newAmount.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }

    final now  = DateTime.now();
    // Effective dates are restricted to next month onward — enforced
    // again server-side in RateHistoryService.addMonthlyRate.
    final next = DateTime(now.year, now.month + 1, 1);

    setState(() => _adding = true);
    try {
      final auth = context.read<AuthProvider>();
      await _rateSvc.addMonthlyRate(
        amount:         amount,
        effectiveMonth: next,
        setBy:          auth.userModel?.uid ?? '',
      );
      _newAmount.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New rate of ₱${amount.toStringAsFixed(2)} '
                'set to start ${_monthLabel(next)}.'),
            backgroundColor: const Color(0xFF1A7A4A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A4A9C).withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1A4A9C).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF1A4A9C)),
              SizedBox(width: 10),
              Text('Monthly Dues Rate',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A4A9C))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Per month per household. New rates only take effect next month '
            'onward — past and current months keep the rate they were billed at.',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 14),

          StreamBuilder<List<MonthlyRateModel>>(
            stream: _rateSvc.streamMonthlyRates(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }

              final rates = snap.data!;
              if (rates.isEmpty) {
                return Text('No rate set yet — add one below.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[500]));
              }

              final now           = DateTime.now();
              final currentOrPast = rates.where((r) => !r.effectiveStart.isAfter(now)).toList();
              final upcoming      = rates.where((r) => r.effectiveStart.isAfter(now)).toList();
              final current       = currentOrPast.isNotEmpty ? currentOrPast.first : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (current != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1A7A4A).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Text('₱${current.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A7A4A))),
                          const SizedBox(width: 8),
                          Text('current — since ${_monthLabel(current.effectiveStart)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  for (final r in upcoming) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text('₱${r.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: Color(0xFF7A6A1A))),
                          const SizedBox(width: 8),
                          Text('scheduled — starts ${_monthLabel(r.effectiveStart)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                  if (currentOrPast.length > 1) ...[
                    const SizedBox(height: 10),
                    Text('History',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    for (final r in currentOrPast.skip(1))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '₱${r.amount.toStringAsFixed(2)} — since ${_monthLabel(r.effectiveStart)}',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _newAmount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'New rate (₱)',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _adding ? null : _submitNewRate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _adding
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Add for next month'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final String                label, hint;
  final TextEditingController ctrl;
  final int                   maxLines;

  static const Color _navy = Color(0xFF1E293B);

  const _SettingsField({
    required this.label,
    required this.hint,
    required this.ctrl,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _navy)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        maxLines:   maxLines,
        style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF1A2B4A)),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: TextStyle(
              fontSize: 13, color: Colors.grey[400]),
          filled:    true,
          fillColor: const Color(0xFFF7F9FC),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFFD0DBEE))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFFD0DBEE))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFF2563EB), width: 1.5)),
        ),
      ),
    ],
  );
}

class _DuesField extends StatelessWidget {
  final String                label, hint, description;
  final TextEditingController ctrl;
  final IconData               icon;
  final Color                  color;
  final bool                   isWholeNumber;

  static const Color _navy = Color(0xFF1E293B);

  const _DuesField({
    required this.label,
    required this.hint,
    required this.ctrl,
    required this.icon,
    required this.color,
    required this.description,
    this.isWholeNumber = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.04),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
          color: color.withOpacity(0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  Text(description,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: ctrl,
          keyboardType: isWholeNumber
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color),
          decoration: InputDecoration(
            prefixText: isWholeNumber ? null : '₱ ',
            prefixStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color),
            hintText: hint,
            hintStyle: TextStyle(
                fontSize: 18,
                color: color.withOpacity(0.3)),
            filled:    true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: color.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: color.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: color, width: 1.5)),
          ),
        ),
      ],
    ),
  );
}