import 'dart:async';
// features/settings/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/hoa_settings_model.dart';
import '../../../core/models/monthly_rate_model.dart';
import '../../../core/models/dues_config_history_model.dart';
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
      if (!mounted) return;
      setState(() {
        _name.text       = settings.name;
        _address.text    = settings.address;
        _contact.text    = settings.contactNumber;
        _email.text      = settings.email;
        _president.text  = settings.president;
        _fillDuesFields(settings);
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

  // "1500" for whole amounts, "1250.50" otherwise. The old toStringAsFixed(0)
  // rounded centavos away, and saving then wrote the rounded value back.
  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  void _fillDuesFields(HoaSettingsModel settings) {
    _annual.text     = _fmt(settings.dues.annual);
    _assessment.text = _fmt(settings.dues.specialAssessment);
    _penalty.text    = _fmt(settings.dues.penalty);
    _graceDays.text  = settings.dues.penaltyGraceDays.toString();
  }

  /// Puts the four dues fields back to what is saved (used when the dues
  /// dialog is cancelled, so unsaved edits don't linger in the fields).
  Future<void> _reloadDues() async {
    try {
      final settings = await _svc.getSettings();
      if (!mounted) return;
      setState(() => _fillDuesFields(settings));
    } catch (_) {}
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

  /// A peso field. Blank counts as 0; anything that isn't a non-negative
  /// number returns null (the old code silently turned typos into 0).
  double? _money(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '');
    if (t.isEmpty) return 0;
    final v = double.tryParse(t);
    if (v == null || v.isNaN || v.isInfinite || v < 0) return null;
    return v;
  }

  /// Validates and saves all settings. Returns null on success, otherwise a
  /// message to show the user.
  Future<String?> _persist() async {
    final annual     = _money(_annual);
    final assessment = _money(_assessment);
    final penalty    = _money(_penalty);
    if (annual == null) return 'Annual Dues must be a valid amount (0 or more).';
    if (assessment == null) {
      return 'Special Assessment must be a valid amount (0 or more).';
    }
    if (penalty == null) return 'Penalty must be a valid amount (0 or more).';
    final graceText = _graceDays.text.trim();
    final grace     = graceText.isEmpty ? 5 : int.tryParse(graceText);
    if (grace == null || grace < 0) {
      return 'Grace Period must be a whole number of days (0 or more).';
    }

    final newDues = DuesConfig(
      annual:            annual,
      specialAssessment: assessment,
      penalty:           penalty,
      penaltyGraceDays:  grace,
    );

    try {
      final auth = context.read<AuthProvider>();

      // Fetched fresh (not from the in-memory fields) so the comparison
      // reflects what's actually on the server right now, not just what
      // this screen loaded when it opened.
      final before = await _svc.getSettings();
      final duesChanged = before.dues.annual            != newDues.annual ||
                           before.dues.specialAssessment != newDues.specialAssessment ||
                           before.dues.penalty           != newDues.penalty ||
                           before.dues.penaltyGraceDays  != newDues.penaltyGraceDays;

      await _svc.saveSettings(HoaSettingsModel(
        name:          _name.text.trim(),
        address:       _address.text.trim(),
        contactNumber: _contact.text.trim(),
        email:         _email.text.trim(),
        president:     _president.text.trim(),
        dues:          newDues,
      ));

      // Only when something actually changed — a save that leaves every
      // dues value the same must not add a row to the history table.
      if (duesChanged) {
        try {
          await _svc.recordDuesConfigChange(
            newDues,
            changedBy: auth.userModel?.displayName ?? auth.userModel?.uid ?? '',
          );
        } catch (_) {}
      }

      // The settings are saved at this point — an audit failure must not
      // make the save look failed.
      try {
        await _svc.logAction(
          performedBy:      auth.userModel?.uid ?? '',
          performedByName:  auth.userModel?.displayName ?? '',
          action:           AuditAction.updated,
          targetCollection: 'settings',
          targetId:         'hoa_settings',
          description:      'Updated HOA settings',
        );
      } catch (_) {}
      return null;
    } catch (e) {
      return 'Could not save settings: $e';
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await _persist();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      error == null
          ? const SnackBar(
              content: Text('Settings saved successfully.'),
              backgroundColor: Color(0xFF1A7A4A),
            )
          : SnackBar(content: Text(error)),
    );
  }

  void _showDuesDialog(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Landscape (a rotated phone, a tablet, or a desktop window — all of
    // which are wider than they are tall) gets a wide, short dialog so the
    // Configuration History table has room to show its columns instead of
    // falling back to the stacked mobile-card layout every time. Portrait
    // keeps the narrower dialog, which still falls back to cards on its
    // own (see _DuesConfigHistoryTable) since a tall, narrow phone screen
    // has no width to spare no matter how this dialog is sized.
    final isLandscape = screenSize.width > screenSize.height;
    final dialogWidth = isLandscape
        ? (screenSize.width * 0.9).clamp(0.0, 860.0)
        : (screenSize.width > 580 ? 520.0 : screenSize.width * 0.92);
    final dialogMaxHeight =
        screenSize.height * (isLandscape ? 0.82 : 0.85);

    // State for the dialog's own Save button / inline error.
    var dialogSaving = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: dialogMaxHeight,
          ),
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
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        _reloadDues(); // discard unsaved edits
                      },
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
                // Previously this button said "Done" and only closed the
                // dialog — the edits were NOT saved until the user found the
                // separate "Save Changes" button on the screen behind it.
                StatefulBuilder(
                  builder: (ctx, setLocal) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFF2B8B0)),
                          ),
                          child: Text(dialogError!,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFFCC2200))),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: dialogSaving
                                ? null
                                : () {
                                    Navigator.pop(dialogCtx);
                                    _reloadDues();
                                  },
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: dialogSaving
                                ? null
                                : () async {
                                    setLocal(() {
                                      dialogSaving = true;
                                      dialogError  = null;
                                    });
                                    final err = await _persist();
                                    if (!dialogCtx.mounted) return;
                                    if (err != null) {
                                      setLocal(() {
                                        dialogSaving = false;
                                        dialogError  = err;
                                      });
                                      return;
                                    }
                                    Navigator.pop(dialogCtx);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content:
                                          Text('Dues settings saved.'),
                                      backgroundColor: Color(0xFF1A7A4A),
                                    ));
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: dialogSaving
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    ],
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
            LayoutBuilder(
              builder: (context, constraints) {
                final titleBlock = Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: _navy),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('Settings',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: _navy)),
                          const SizedBox(height: 2),
                          Text(
                              'HOA profile and dues configuration',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                );

                final saveButton = ElevatedButton(
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
                );

                // The title block and the button can't both fit on one
                // line below this width — stack the button underneath.
                final narrow = constraints.maxWidth < 560;

                if (narrow) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 12),
                      SizedBox(
                          width: double.infinity,
                          child: saveButton),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleBlock),
                    saveButton,
                  ],
                );
              },
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
            LayoutBuilder(
              builder: (context, constraints) {
                final contactField = _SettingsField(
                  label: 'Contact Number',
                  hint:  '09XX-XXX-XXXX',
                  ctrl:  contact,
                );
                final emailField = _SettingsField(
                  label: 'Email Address',
                  hint:  'admin@lamhoai.com',
                  ctrl:  email,
                );

                if (constraints.maxWidth < 500) {
                  return Column(children: [
                    contactField,
                    const SizedBox(height: 16),
                    emailField,
                  ]);
                }

                return Row(children: [
                  Expanded(child: contactField),
                  const SizedBox(width: 16),
                  Expanded(child: emailField),
                ]);
              },
            ),
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
            'Set the default amounts for each payment type. Monthly rates are '
            'saved as soon as you add them; the amounts below are saved '
            'with the Save button.',
            style: TextStyle(
                fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),

          // ── Monthly rate now uses history instead of a single field ──────
          const _MonthlyRateSection(),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 500;

              final annualField = _DuesField(
                label:       'Annual Dues',
                hint:        '2000',
                ctrl:        annual,
                icon:        Icons.calendar_month_outlined,
                color:       const Color(0xFF1A7A4A),
                description: 'Full year payment',
              );
              final assessmentField = _DuesField(
                label:       'Special Assessment',
                hint:        '500',
                ctrl:        assessment,
                icon:        Icons.assignment_outlined,
                color:       const Color(0xFF7A3A1A),
                description: 'One-time special charge',
              );
              final penaltyField = _DuesField(
                label:       'Penalty',
                hint:        '50',
                ctrl:        penalty,
                icon:        Icons.warning_amber_outlined,
                color:       const Color(0xFFCC2200),
                description: 'Flat late payment penalty',
              );
              final graceField = _DuesField(
                label:       'Grace Period (days)',
                hint:        '5',
                ctrl:        graceDays,
                icon:        Icons.hourglass_empty,
                color:       const Color(0xFF7A6A1A),
                description:
                    'Days after due date before penalty applies',
                isWholeNumber: true,
              );

              if (narrow) {
                return Column(children: [
                  annualField,
                  const SizedBox(height: 16),
                  assessmentField,
                  const SizedBox(height: 16),
                  penaltyField,
                  const SizedBox(height: 16),
                  graceField,
                ]);
              }

              return Column(children: [
                Row(children: [
                  Expanded(child: annualField),
                  const SizedBox(width: 16),
                  Expanded(child: assessmentField),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: penaltyField),
                  const SizedBox(width: 16),
                  Expanded(child: graceField),
                ]),
              ]);
            },
          ),
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
          const SizedBox(height: 20),
          const _DuesConfigHistoryTable(),
        ],
      ),
    );
  }
}

// ── Dues configuration change history ───────────────────────────────────────
// Annual / Special Assessment / Penalty / Grace Period — the monthly rate
// has its own section above with its own history.
class _DuesConfigHistoryTable extends StatelessWidget {
  const _DuesConfigHistoryTable();

  static const Color _navy = Color(0xFF1E293B);

  static const _monthNames = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  static String _dateLabel(DateTime d) =>
      '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

  Widget _historyTable(List<DuesConfigHistoryModel> history) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E8F4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F9FC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: _HCell('Effective')),
                Expanded(flex: 3, child: _HCell('Annual')),
                Expanded(flex: 3, child: _HCell('Assessment')),
                Expanded(flex: 3, child: _HCell('Penalty')),
                Expanded(flex: 2, child: _HCell('Grace')),
              ],
            ),
          ),
          for (var i = 0; i < history.length; i++)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                border: i == history.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: Color(0xFFEEF2F9))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_dateLabel(history[i].createdAt),
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _navy)),
                        if (history[i].changedBy.isNotEmpty)
                          Text(history[i].changedBy,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  Expanded(
                      flex: 3,
                      child: _HVal(
                          '₱${history[i].annual.toStringAsFixed(2)}')),
                  Expanded(
                      flex: 3,
                      child: _HVal(
                          '₱${history[i].specialAssessment.toStringAsFixed(2)}')),
                  Expanded(
                      flex: 3,
                      child: _HVal(
                          '₱${history[i].penalty.toStringAsFixed(2)}')),
                  Expanded(
                      flex: 2,
                      child: _HVal('${history[i].penaltyGraceDays}d')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyCards(List<DuesConfigHistoryModel> history) {
    return Column(
      children: [
        for (var i = 0; i < history.length; i++)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: i == history.length - 1 ? 0 : 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E8F4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_dateLabel(history[i].createdAt),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _navy)),
                    ),
                    if (history[i].changedBy.isNotEmpty)
                      Flexible(
                        child: Text(history[i].changedBy,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500])),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _CardStat('Annual',
                        '₱${history[i].annual.toStringAsFixed(2)}'),
                    _CardStat('Assessment',
                        '₱${history[i].specialAssessment.toStringAsFixed(2)}'),
                    _CardStat('Penalty',
                        '₱${history[i].penalty.toStringAsFixed(2)}'),
                    _CardStat(
                        'Grace', '${history[i].penaltyGraceDays} days'),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history, size: 18, color: _navy),
            SizedBox(width: 10),
            Text('Configuration History',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Every change to the amounts above, so you can see what was in '
          'effect for a given month or year.',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<DuesConfigHistoryModel>>(
          stream: SettingsService().streamDuesConfigHistory(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('Could not load history: ${snap.error}',
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFFCC2200)));
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final history = snap.data!;
            if (history.isEmpty) {
              return Text(
                  'No changes recorded yet — this table fills in the next '
                  'time you change one of the amounts above.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[500]));
            }

            // Dialog can be as narrow as ~85% of a phone's width — five
            // columns don't fit there, so under 460px this becomes one
            // stacked card per record instead of a table row.
            return LayoutBuilder(
              builder: (context, constraints) {
                return constraints.maxWidth < 460
                    ? _historyCards(history)
                    : _historyTable(history);
              },
            );
          },
        ),
      ],
    );
  }
}

class _CardStat extends StatelessWidget {
  final String label;
  final String value;
  const _CardStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10.5, color: Colors.grey[500])),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B))),
        ],
      );
}

class _HCell extends StatelessWidget {
  final String text;
  const _HCell(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]));
}

class _HVal extends StatelessWidget {
  final String text;
  const _HVal(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)));
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

  // Whether any rate exists yet. With none, the first rate may start this
  // month — otherwise the current month could never be billed.
  bool      _hasRates = true;
  DateTime? _effective;

  // Inline message: this section lives inside a modal dialog, so a
  // SnackBar would render BEHIND it and errors would go unseen.
  String? _notice;
  bool    _noticeIsError = false;

  late final Stream<List<MonthlyRateModel>> _ratesStream =
      _rateSvc.streamMonthlyRates().asBroadcastStream();
  StreamSubscription<List<MonthlyRateModel>>? _sub;

  static const Color _navy = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _sub = _ratesStream.listen((rates) {
      if (mounted && _hasRates != rates.isNotEmpty) {
        setState(() => _hasRates = rates.isNotEmpty);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _newAmount.dispose();
    super.dispose();
  }

  static const _monthNames = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  String _monthLabel(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

  /// Months a new rate may start in: this month if it's the very first rate,
  /// otherwise next month onward (enforced again in the service).
  List<DateTime> _monthOptions() {
    final now   = DateTime.now();
    final first = _hasRates
        ? DateTime(now.year, now.month + 1, 1)
        : DateTime(now.year, now.month, 1);
    return [
      for (var i = 0; i < 12; i++) DateTime(first.year, first.month + i, 1)
    ];
  }

  DateTime _selectedMonth(List<DateTime> options) =>
      (_effective != null && options.contains(_effective))
          ? _effective!
          : options.first;

  void _setNotice(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _notice        = text;
      _noticeIsError = error;
    });
  }

  Future<void> _submitNewRate() async {
    final amount =
        double.tryParse(_newAmount.text.trim().replaceAll(',', ''));
    if (amount == null || amount.isNaN || amount.isInfinite || amount <= 0) {
      _setNotice('Enter a valid amount greater than zero.', error: true);
      return;
    }

    final effective = _selectedMonth(_monthOptions());

    setState(() {
      _adding = true;
      _notice = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      await _rateSvc.addMonthlyRate(
        amount:         amount,
        effectiveMonth: effective,
        setBy:          auth.userModel?.uid ?? '',
      );
      _newAmount.clear();
      _setNotice('New rate of ₱${amount.toStringAsFixed(2)} '
          'set to start ${_monthLabel(effective)}.');
    } catch (e) {
      _setNotice(
          e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeScheduled(MonthlyRateModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Remove scheduled rate?'),
        content: Text('Remove ₱${r.amount.toStringAsFixed(2)} scheduled to '
            'start ${_monthLabel(r.effectiveStart)}? You can then add a '
            'corrected rate for that month.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _rateSvc.deleteScheduledRate(r.id);
      _setNotice('Scheduled rate removed.');
    } catch (e) {
      _setNotice(
          e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options   = _monthOptions();
    final effective = _selectedMonth(options);

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
            'Per lot per month. New rates only take effect next month '
            'onward — past and current months keep the rate they were billed at.',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 14),

          StreamBuilder<List<MonthlyRateModel>>(
            stream: _ratesStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Could not load rates: ${snap.error}',
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFFCC2200)));
              }
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
                          Flexible(
                            child: Text('current — since ${_monthLabel(current.effectiveStart)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ),
                        ],
                      ),
                    ),
                  for (final r in upcoming) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.only(left: 14, right: 4, top: 4, bottom: 4),
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
                          Flexible(
                            child: Text('scheduled — starts ${_monthLabel(r.effectiveStart)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Remove scheduled rate',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => _removeScheduled(r),
                          ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _newAmount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'New rate (₱)',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<DateTime>(
                  value: effective,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Starts',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: options
                      .map((o) => DropdownMenuItem<DateTime>(
                            value: o,
                            child: Text(_monthLabel(o)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _effective = v),
                ),
              ),
            ],
          ),
          if (!_hasRates) ...[
            const SizedBox(height: 6),
            Text('No rate exists yet, so this first one can start this month.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _adding ? null : _submitNewRate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _adding
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add rate'),
            ),
          ),
          if (_notice != null) ...[
            const SizedBox(height: 10),
            Text(_notice!,
                style: TextStyle(
                    fontSize: 12.5,
                    color: _noticeIsError
                        ? const Color(0xFFCC2200)
                        : const Color(0xFF1A7A4A))),
          ],
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