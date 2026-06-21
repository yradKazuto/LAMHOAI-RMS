// features/settings/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/hoa_settings_model.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final _svc         = SettingsService();
  late TabController _tabs;
  bool               _saving = false;

  // Profile controllers
  final _name          = TextEditingController();
  final _address       = TextEditingController();
  final _contact       = TextEditingController();
  final _email         = TextEditingController();
  final _president     = TextEditingController();

  // Dues controllers
  final _monthly       = TextEditingController();
  final _annual        = TextEditingController();
  final _assessment    = TextEditingController();
  final _penalty       = TextEditingController();

  bool _loaded = false;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _svc.getSettings();
    setState(() {
      _name.text       = settings.name;
      _address.text    = settings.address;
      _contact.text    = settings.contactNumber;
      _email.text      = settings.email;
      _president.text  = settings.president;
      _monthly.text    = settings.dues.monthly.toStringAsFixed(0);
      _annual.text     = settings.dues.annual.toStringAsFixed(0);
      _assessment.text = settings.dues.specialAssessment.toStringAsFixed(0);
      _penalty.text    = settings.dues.penalty.toStringAsFixed(0);
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose(); _address.dispose();
    _contact.dispose(); _email.dispose();
    _president.dispose(); _monthly.dispose();
    _annual.dispose(); _assessment.dispose();
    _penalty.dispose();
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
        dues:          DuesConfig(
          monthly:           double.tryParse(_monthly.text) ?? 0,
          annual:            double.tryParse(_annual.text) ?? 0,
          specialAssessment: double.tryParse(_assessment.text) ?? 0,
          penalty:           double.tryParse(_penalty.text) ?? 0,
        ),
      );

      await _svc.saveSettings(settings);

      // Log the action
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

            // ── Tabs ───────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFE0E8F4)),
              ),
              child: TabBar(
                controller: _tabs,
                labelColor: _navy,
                unselectedLabelColor: Colors.grey,
                indicatorColor: _accent,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5),
                tabs: const [
                  Tab(text: 'HOA Profile'),
                  Tab(text: 'Dues Configuration'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Tab content ────────────────────────────────────────────────
            Expanded(
              child: !_loaded
                  ? const Center(
                      child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        // Tab 1 — HOA Profile
                        _ProfileTab(
                          name:      _name,
                          address:   _address,
                          contact:   _contact,
                          email:     _email,
                          president: _president,
                        ),

                        // Tab 2 — Dues Config
                        _DuesTab(
                          monthly:    _monthly,
                          annual:     _annual,
                          assessment: _assessment,
                          penalty:    _penalty,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile tab ───────────────────────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  final TextEditingController name, address, contact,
      email, president;

  static const Color _navy = Color(0xFF0D2A5C);

  const _ProfileTab({
    required this.name,
    required this.address,
    required this.contact,
    required this.email,
    required this.president,
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
          ],
        ),
      ),
    );
  }
}

// ── Dues tab ──────────────────────────────────────────────────────────────────
class _DuesTab extends StatelessWidget {
  final TextEditingController monthly, annual,
      assessment, penalty;

  static const Color _navy = Color(0xFF0D2A5C);

  const _DuesTab({
    required this.monthly,
    required this.annual,
    required this.assessment,
    required this.penalty,
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
            const Text('Dues Amount Configuration',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _navy)),
            const SizedBox(height: 6),
            Text(
              'Set the default amounts for each payment type. '
              'These are reference values for recording payments.',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: _DuesField(
                  label:       'Monthly Dues',
                  hint:        '200',
                  ctrl:        monthly,
                  icon:        Icons.calendar_today_outlined,
                  color:       const Color(0xFF1A4A9C),
                  description: 'Per month per household',
                ),
              ),
              const SizedBox(width: 16),
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
            ]),
            const SizedBox(height: 16),
            Row(children: [
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
              const SizedBox(width: 16),
              Expanded(
                child: _DuesField(
                  label:       'Penalty',
                  hint:        '50',
                  ctrl:        penalty,
                  icon:        Icons.warning_amber_outlined,
                  color:       const Color(0xFFCC2200),
                  description: 'Late payment penalty',
                ),
              ),
            ]),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF2E6BE6)
                        .withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16,
                      color: Color(0xFF2E6BE6)),
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
      ),
    );
  }
}

// ── Settings field ────────────────────────────────────────────────────────────
class _SettingsField extends StatelessWidget {
  final String                label, hint;
  final TextEditingController ctrl;
  final int                   maxLines;

  static const Color _navy = Color(0xFF0D2A5C);

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
                  color: Color(0xFF2E6BE6), width: 1.5)),
        ),
      ),
    ],
  );
}

// ── Dues amount field ─────────────────────────────────────────────────────────
class _DuesField extends StatelessWidget {
  final String                label, hint, description;
  final TextEditingController ctrl;
  final IconData              icon;
  final Color                 color;

  static const Color _navy = Color(0xFF0D2A5C);

  const _DuesField({
    required this.label,
    required this.hint,
    required this.ctrl,
    required this.icon,
    required this.color,
    required this.description,
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
            Column(
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
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(
                  decimal: true),
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color),
          decoration: InputDecoration(
            prefixText: '₱ ',
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