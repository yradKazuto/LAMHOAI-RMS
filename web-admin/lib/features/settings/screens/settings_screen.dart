// features/settings/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/models/hoa_settings_model.dart';
import '../../../core/models/monthly_rate_model.dart';
import '../../../core/models/rate_schedule_model.dart';
import '../../../core/services/rate_history_service.dart';
import '../../../core/services/rate_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/design_tokens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsSvc = SettingsService();
  final _rateHistSvc = RateHistoryService();
  final _salesRateSvc = RateService();

  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _contCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _presCtrl = TextEditingController();

  HoaSettingsModel? _settings;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _settingsSvc.getSettings();
    if (mounted) {
      setState(() {
        _settings = s;
        _nameCtrl.text = s.name;
        _addrCtrl.text = s.address;
        _contCtrl.text = s.contactNumber;
        _emailCtrl.text = s.email;
        _presCtrl.text = s.president;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_settings == null) return;
    setState(() => _saving = true);
    final updated = HoaSettingsModel(
      name: _nameCtrl.text,
      address: _addrCtrl.text,
      contactNumber: _contCtrl.text,
      email: _emailCtrl.text,
      president: _presCtrl.text,
      dues: _settings!.dues,
    );
    await _settingsSvc.saveSettings(updated);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sidebarBg,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settings', style: AppTypography.greeting),
                    Text('HOA profile and dues configuration', style: AppTypography.caption),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            _buildAssociationInfo(),
            const SizedBox(height: AppSpacing.sectionGap),
            const Divider(),
            const SizedBox(height: AppSpacing.sectionGap),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.upload_file, color: AppColors.primary),
                title: Text('Bulk Lot Area Update', style: AppTypography.cardTitle),
                subtitle: Text('Import CSV file to update lot areas in bulk', style: AppTypography.caption),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push(AppRoutes.bulkUpdate),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            Text('Sales Rate (Lot Sales)', style: AppTypography.sectionHeader),
            const SizedBox(height: 12),
            const _CurrentSalesRateSection(),
            const SizedBox(height: AppSpacing.sectionGap),
            const _SalesRateHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAssociationInfo() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Association Information', style: AppTypography.sectionHeader),
          const SizedBox(height: 20),
          _buildField('Association Name', _nameCtrl),
          const SizedBox(height: 16),
          _buildField('Address', _addrCtrl, placeholder: 'Barangay, City, Province'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildField('Contact Number', _contCtrl, placeholder: '09XX-XXX-XXXX')),
              const SizedBox(width: 16),
              Expanded(child: _buildField('Email Address', _emailCtrl, placeholder: 'admin@lamhoai.com')),
            ],
          ),
          const SizedBox(height: 16),
          _buildField('HOA President', _presCtrl, placeholder: 'Full name of current president'),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _showDuesConfig(context),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('Dues Configuration'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {String? placeholder}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: placeholder,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _showDuesConfig(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _DuesConfigurationDialog(
        settingsSvc: _settingsSvc,
        rateHistSvc: _rateHistSvc,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dues Configuration Dialog
// ---------------------------------------------------------------------------
class _DuesConfigurationDialog extends StatefulWidget {
  final SettingsService settingsSvc;
  final RateHistoryService rateHistSvc;

  const _DuesConfigurationDialog({
    required this.settingsSvc,
    required this.rateHistSvc,
  });

  @override
  State<_DuesConfigurationDialog> createState() => _DuesConfigurationDialogState();
}

class _DuesConfigurationDialogState extends State<_DuesConfigurationDialog> {
  final _rateCtrl = TextEditingController();
  final _annualCtrl = TextEditingController();
  final _specialCtrl = TextEditingController();

  HoaSettingsModel? _settings;
  bool _loading = true;
  bool _addingRate = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await widget.settingsSvc.getSettings();
    if (mounted) {
      setState(() {
        _settings = s;
        _annualCtrl.text = s.dues.annual.toStringAsFixed(0);
        _specialCtrl.text = s.dues.specialAssessment.toStringAsFixed(0);
        _loading = false;
      });
    }
  }

  Future<void> _addRate() async {
    final amt = double.tryParse(_rateCtrl.text);
    if (amt == null || amt <= 0) return;

    setState(() => _addingRate = true);
    try {
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      await widget.rateHistSvc.addMonthlyRate(
        amount: amt,
        effectiveMonth: nextMonth,
        setBy: 'admin',
      );
      _rateCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monthly rate added successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingRate = false);
    }
  }

  Future<void> _saveDuesConfig() async {
    if (_settings == null) return;
    final annual = double.tryParse(_annualCtrl.text) ?? _settings!.dues.annual;
    final special = double.tryParse(_specialCtrl.text) ?? _settings!.dues.specialAssessment;

    final updated = _settings!.copyWith(
      dues: _settings!.dues.copyWith(
        annual: annual,
        specialAssessment: special,
      ),
    );

    await widget.settingsSvc.saveSettings(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dues Configuration', style: AppTypography.greeting),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Set the default amounts for each payment type. Annual Dues and the Monthly Rate are linked (annual = 12 × monthly): changing one updates the other. Monthly rates are saved as soon as you add them; the amounts below are saved with the Save button.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 24),
            _buildMonthlyRateSection(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildSimpleField('Annual Dues', _annualCtrl, prefix: '₱')),
                const SizedBox(width: 16),
                Expanded(child: _buildSimpleField('Special Assessment', _specialCtrl, prefix: '₱')),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saveDuesConfig,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.sidebarBg, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyRateSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Monthly Dues Rate', style: AppTypography.label.copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Per lot per month. New rates only take effect next month onward — past and current months keep the rate they were billed at. Annual Dues is 12 × the monthly rate.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<MonthlyRateModel>>(
            stream: widget.rateHistSvc.streamMonthlyRates(),
            builder: (context, snapshot) {
              final rate = snapshot.data?.firstOrNull;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(
                  children: [
                    Text('₱${rate?.amount ?? 0}', style: AppTypography.sectionHeader.copyWith(color: AppColors.success, fontSize: 18)),
                    const SizedBox(width: 8),
                    Text('current — since ${_fmtDate(rate?.effectiveStart)}', style: AppTypography.caption),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rateCtrl,
                  decoration: const InputDecoration(
                    hintText: 'New rate (₱)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addingRate ? null : _addRate,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.sidebarBg, foregroundColor: Colors.white),
                child: const Text('Add rate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleField(String label, TextEditingController ctrl, {String? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            prefixText: prefix,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'N/A';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Sales Rate (Current)
// ---------------------------------------------------------------------------
class _CurrentSalesRateSection extends StatefulWidget {
  const _CurrentSalesRateSection();

  @override
  State<_CurrentSalesRateSection> createState() => _CurrentSalesRateSectionState();
}

class _CurrentSalesRateSectionState extends State<_CurrentSalesRateSection> {
  final _svc = RateService();
  final _rateCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _svc.streamSalesRate(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.danger));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rate = snapshot.data;
        return Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Current Rate: ₱${rate?.ratePerSqm ?? 0}/sqm'),
              subtitle: Text('Last updated by ${rate?.updatedBy ?? 'System'}'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rateCtrl,
                    decoration: const InputDecoration(labelText: 'New Rate (₱)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final val = double.tryParse(_rateCtrl.text);
                    if (val == null) return;
                    await _svc.setSalesRate(val, 'admin');
                    _rateCtrl.clear();
                  },
                  child: const Text('Update'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sales Rate History
// ---------------------------------------------------------------------------
class _SalesRateHistorySection extends StatefulWidget {
  const _SalesRateHistorySection();

  @override
  State<_SalesRateHistorySection> createState() => _SalesRateHistorySectionState();
}

class _SalesRateHistorySectionState extends State<_SalesRateHistorySection> {
  final _svc = RateService();
  List<RateScheduleModel> _schedules = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final s = await _svc.getSchedules();
      if (mounted) {
        setState(() {
          _schedules = s;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Text('Error: $_error', style: const TextStyle(color: AppColors.danger));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Rate Schedules', style: AppTypography.label),
            IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load),
          ],
        ),
        if (_schedules.isEmpty)
          const Text('No schedules found.', style: TextStyle(color: AppColors.textMuted))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _schedules.length,
            itemBuilder: (context, index) {
              final s = _schedules[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  title: Text('Year: ${s.year}'),
                  subtitle: Text('Status: ${s.isActive ? 'Active' : 'Draft'}'),
                  trailing: s.isActive
                      ? const Icon(Icons.check_circle, color: AppColors.success, size: 16)
                      : TextButton(
                          onPressed: () async {
                            await _svc.activateSchedule(s.id);
                            _load();
                          },
                          child: const Text('Activate'),
                        ),
                ),
              );
            },
          ),
      ],
    );
  }
}
