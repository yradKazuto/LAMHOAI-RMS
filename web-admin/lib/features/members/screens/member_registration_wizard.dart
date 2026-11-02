// features/members/screens/member_registration_wizard.dart
//
// V2 Add Member / Multi-Lot Registration Wizard.
// 5-step flow: Member Details -> Location Mapping -> Payment Setup -> Preview -> Confirm.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/models/member_model.dart';
import '../../../core/models/lot_model.dart';
import '../../../core/models/lot_sale_model.dart';
import '../../../core/models/phase_map_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/lot_service.dart';
import '../../../core/services/phase_map_service.dart';
import '../../../core/services/sale_service.dart';
import '../../../core/services/amortization_service.dart';
import '../../../core/theme/design_tokens.dart';
import '../../location/widgets/simple_phase_map_view.dart';

const String kPhaseOnePolygonMap = 'Phase 1';

class MemberRegistrationWizard extends StatefulWidget {
  const MemberRegistrationWizard({super.key});

  @override
  State<MemberRegistrationWizard> createState() => _MemberRegistrationWizardState();
}

class _MemberDetails {
  String name = '';
  String email = '';
  String contact = '';
  String address = '';
}

class _LotSetup {
  final String lotId;
  SaleType saleType = SaleType.cash;
  double downPayment = 0.0;
  int termMonths = 12;
  double annualInterestRate = 12.0;
  DateTime firstDueDate = DateTime.now();

  _LotSetup(this.lotId);
}

class _MemberRegistrationWizardState extends State<MemberRegistrationWizard> {
  int _step = 1;
  final _memberDetails = _MemberDetails();
  final Map<String, LotModel> _selectedLots = {};
  final Map<String, _LotSetup> _lotSetups = {};
  bool _loading = false;

  // Which phase map is shown in the Step 2 Location Mapping view.
  String _wizardSelectedPhase = kPhaseOnePolygonMap;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildStep()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  static const List<String> _stepLabels = [
    'Personal',
    'Lots',
    'Payment',
    'Review',
    'Confirm',
  ];

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.all(24),
    child: Row(
      children: [
        for (int i = 1; i <= 5; i++) ...[
          if (i > 1)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: AppColors.border,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= _step ? AppColors.primary : AppColors.surfaceAlt,
                  border: Border.all(
                    color: i <= _step ? AppColors.primary : AppColors.border,
                    width: 1,
                  ),
                ),
                child: i < _step
                    ? const Icon(Icons.check, size: 16, color: AppColors.surface)
                    : Text(
                        '$i',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: i == _step ? AppColors.surface : AppColors.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                _stepLabels[i - 1],
                style: AppTypography.caption.copyWith(
                  color: i <= _step ? AppColors.textPrimary : AppColors.textMuted,
                  fontWeight: i == _step ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _buildStep() {
    switch (_step) {
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      case 3: return _buildStep3();
      case 4: return _buildStep4();
      case 5: return _buildStep5();
      default: return const SizedBox();
    }
  }

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Widget _buildStep1() => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.cardPadding),
    child: Column(
      children: [
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', hintText: 'e.g., John Doe', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.always)),
        SizedBox(height: AppSpacing.cardGap),
        TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', hintText: 'e.g., john@example.com', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.always)),
        SizedBox(height: AppSpacing.cardGap),
        TextField(controller: _contactCtrl, decoration: const InputDecoration(labelText: 'Mobile Number', hintText: '+63 9XX XXX XXXX', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.always, prefixIcon: Padding(padding: EdgeInsets.all(12), child: Text('🇵🇭', style: TextStyle(fontSize: 16))))),
        SizedBox(height: AppSpacing.cardGap),
        TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.always)),
      ],
    ),
  );
  Widget _buildStep2() => StreamBuilder<List<PhaseMapModel>>(
    stream: PhaseMapService().streamPhaseMaps(),
    builder: (context, phaseSnap) {
      final phases = phaseSnap.data ?? const <PhaseMapModel>[];
      if (phases.isEmpty) {
        return const Center(child: Text('No phases available.'));
      }
      final sorted = List<PhaseMapModel>.from(phases)..sort((a, b) {
        final aIs1 = a.name.trim().toLowerCase() == kPhaseOnePolygonMap.toLowerCase();
        final bIs1 = b.name.trim().toLowerCase() == kPhaseOnePolygonMap.toLowerCase();
        if (aIs1 && !bIs1) return -1;
        if (!aIs1 && bIs1) return 1;
        return a.name.compareTo(b.name);
      });
      _wizardSelectedPhase = sorted.firstWhere(
        (p) => p.name == _wizardSelectedPhase,
        orElse: () => sorted.first,
      ).name;
      final phase = sorted.firstWhere((p) => p.name == _wizardSelectedPhase);
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardGap),
            child: DropdownButton<String>(
              value: _wizardSelectedPhase,
              isExpanded: true,
              items: sorted
                  .map((p) => DropdownMenuItem(
                        value: p.name,
                        child: Text(p.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _wizardSelectedPhase = v!),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<LotModel>>(
                    stream: LotService().streamLots(),
                    builder: (context, lotSnap) {
                      if (!lotSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final phaseLots = lotSnap.data!
                          .where((l) =>
                              l.phase.trim().toLowerCase() ==
                                  phase.name.trim().toLowerCase() &&
                              (l.status == LotStatus.vacant ||
                                  l.status == LotStatus.forSale))
                          .toList()
                        ..sort((a, b) {
                          final cmp = a.block.compareTo(b.block);
                          if (cmp != 0) return cmp;
                          return a.lotNumber.compareTo(b.lotNumber);
                        });
                      return SimplePhaseMapView(
                        phaseMap: phase,
                        lots: phaseLots,
                        highlightLotIds: _selectedLots.keys.toList(),
                        canEdit: false,
                        canAssignMembers: false,
                        currentUserId:
                            FirebaseAuth.instance.currentUser?.uid ?? '',
                        loadAssignableMembers: () async => [],
                        onLotTap: (lot) => _showLotSelectionDialog(lot),
                      );
                    },
                  ),
                ),
                _buildSelectedLotsSidePanel(),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _buildSelectedLotsSidePanel() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
        color: AppColors.surfaceAlt,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Selected Lots', style: AppTypography.cardTitle),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _selectedLots.length,
              itemBuilder: (context, index) {
                final lot = _selectedLots.values.toList()[index];
                return ListTile(
                  title: Text('L${lot.lotNumber}, B${lot.block}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                    onPressed: () {
                      setState(() {
                        _selectedLots.remove(lot.id);
                        _lotSetups.remove(lot.id);
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLotSelectionDialog(LotModel lot) {
    final alreadySelected = _selectedLots.containsKey(lot.id);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Lot ${lot.lotNumber}, Block ${lot.block}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${lot.status.name}', style: AppTypography.body),
            Text('Price: ₱${(lot.price ?? 0).toStringAsFixed(2)}',
                style: AppTypography.body),
            if (lot.areaSqm != null && lot.areaSqm! > 0)
              Text('Area: ${lot.areaSqm!.toStringAsFixed(2)} sqm',
                  style: AppTypography.body),
            const SizedBox(height: 12),
            Text(
              alreadySelected
                  ? 'Already selected.'
                  : 'Select this lot for registration.',
              style: AppTypography.caption,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          if (!alreadySelected)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedLots[lot.id] = lot;
                  _lotSetups[lot.id] = _LotSetup(lot.id);
                });
                Navigator.pop(dialogCtx);
              },
              child: const Text('Select'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              setState(() => _step = 3);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
  Widget _buildStep3() {
    if (_selectedLots.isEmpty) {
      return const Center(child: Text('Please select lots in Step 2.', style: AppTypography.body));
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      children: _selectedLots.values.map((lot) {
        final setup = _lotSetups[lot.id]!;
        final totalPrice = lot.price ?? 0.0;
        final financedAmount = totalPrice - setup.downPayment;
        final monthly = setup.saleType == SaleType.installment
            ? AmortizationService.monthlyPayment(
                financedAmount, setup.annualInterestRate, setup.termMonths)
            : 0.0;
        final totalPayable = setup.saleType == SaleType.cash
            ? totalPrice
            : setup.downPayment + (monthly * setup.termMonths);

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: AppComponents.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lot ${lot.lotNumber}, Block ${lot.block}',
                      style: AppTypography.cardTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.cardGap),
              DropdownButtonFormField<SaleType>(
                value: setup.saleType,
                decoration: const InputDecoration(labelText: 'Sale Type', border: OutlineInputBorder()),
                isExpanded: true,
                items: SaleType.values.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.label, style: AppTypography.body),
                    )).toList(),
                onChanged: (v) => setState(() => setup.saleType = v!),
              ),
              if (setup.saleType == SaleType.installment) ...[
                const SizedBox(height: AppSpacing.cardGap),
                TextField(
                  decoration: const InputDecoration(
                      labelText: 'Down Payment', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() =>
                      setup.downPayment = double.tryParse(v) ?? 0.0),
                ),
                const SizedBox(height: AppSpacing.cardGap),
                TextField(
                  decoration: const InputDecoration(
                      labelText: 'Term (Months)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() =>
                      setup.termMonths = int.tryParse(v) ?? 12),
                ),
                const SizedBox(height: AppSpacing.cardGap),
                TextField(
                  decoration: const InputDecoration(
                      labelText: 'Annual Interest Rate (%)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() =>
                      setup.annualInterestRate = double.tryParse(v) ?? 12.0),
                ),
              ],
              const SizedBox(height: AppSpacing.cardGap),
              Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Preview', style: AppTypography.cardTitle),
                    const SizedBox(height: AppSpacing.cardGap),
                    _previewRow('Total Price',
                        '₱${totalPrice.toStringAsFixed(2)}'),
                    _previewRow('Down Payment',
                        '₱${setup.downPayment.toStringAsFixed(2)}'),
                    _previewRow('Financed Amount',
                        '₱${financedAmount.toStringAsFixed(2)}'),
                    if (setup.saleType == SaleType.installment) ...[
                      _previewRow('Term', '${setup.termMonths} months'),
                      _previewRow('Interest p.a.',
                          '${setup.annualInterestRate.toStringAsFixed(1)}%'),
                      _previewRow('Monthly Payment',
                          '₱${monthly.toStringAsFixed(2)}'),
                    ],
                    _previewRow('Total Payable',
                        '₱${totalPayable.toStringAsFixed(2)}',
                        bold: true),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _previewRow(String label, String value, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.caption),
            Text(value,
                style: (bold
                        ? AppTypography.bodyMedium
                        : AppTypography.body)
                    .copyWith(
                      fontWeight: bold
                          ? FontWeight.w700
                          : FontWeight.w400,
                    )),
          ],
        ),
      );
  Widget _buildStep4() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      children: [
        Text('Member: ${_memberDetails.name}', style: AppTypography.cardTitle),
        const SizedBox(height: AppSpacing.sectionGap),
        ..._selectedLots.values.map((lot) {
          final setup = _lotSetups[lot.id]!;
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: AppComponents.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text('Lot ${lot.lotNumber}, Block ${lot.block}', style: AppTypography.cardTitle),
                  ],
                ),
                const SizedBox(height: AppSpacing.cardGap),
                Row(
                  children: [
                    const Icon(Icons.payment_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text('Sale Type: ${setup.saleType.label}', style: AppTypography.body),
                  ],
                ),
                if (setup.saleType == SaleType.installment) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Down Payment: ₱${setup.downPayment.toStringAsFixed(2)}', style: AppTypography.body),
                        Text('Term: ${setup.termMonths} months', style: AppTypography.body),
                        Text('Annual Interest: ${setup.annualInterestRate}%', style: AppTypography.body),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
  Widget _buildStep5() => const Center(child: Text('Confirm Registration'));

  Widget _buildFooter() => Padding(
    padding: const EdgeInsets.all(24),
    child: Row(
      children: [
        if (_step > 1)
          OutlinedButton(
            onPressed: _loading ? null : () => setState(() => _step--),
            child: const Text('Back'),
          ),
        const Spacer(),
        if (_step < 5)
          ElevatedButton(
            onPressed: _loading ? null : () => setState(() => _step++),
            child: const Text('Next'),
          ),
        if (_step == 5)
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: const Text('Confirm'),
          ),
      ],
    ),
  );

  Future<void> _submit() async {
    setState(() => _loading = true);
    // Update model from controllers
    _memberDetails.name = _nameCtrl.text.trim();
    _memberDetails.email = _emailCtrl.text.trim();
    _memberDetails.contact = _contactCtrl.text.trim();
    _memberDetails.address = _addressCtrl.text.trim();

    if (_memberDetails.email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email is required.')));
      setState(() => _loading = false);
      return;
    }

    try {
      // Use a secondary Firebase App instance so the admin session is
      // NOT affected when creating a new member account.
      final secondaryApp = await Firebase.initializeApp(
        name: 'reg_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // 1. Create member Auth account in secondary app
      final cred = await secondaryAuth
          .createUserWithEmailAndPassword(
        email: _memberDetails.email.trim(),
        password: 'ChangeMe123!',
      );
      final memberUid = cred.user!.uid;

      // 2. Send email verification to the new member
      // await cred.user!.sendEmailVerification(); // PONTYAIL: deferred, OTP/email-verification not yet required.

      // 3. Save Firestore document — admin session untouched
      final member = MemberModel(
        uid: memberUid,
        name: _memberDetails.name,
        email: _memberDetails.email,
        role: 'member',
        lotNumber: _selectedLots.values.map((l) => l.lotNumber).join(', '),
        phase: _selectedLots.values.map((l) => l.phase).join(', '),
        status: MemberStatus.active,
        contactNumber: _memberDetails.contact,
        address: _memberDetails.address,
        createdAt: DateTime.now(),
      );
      await FirestoreService().addMember(member);

      // 4. One sale record per selected lot (registerSale → lot_payments + lots merge)
      for (final lot in _selectedLots.values) {
        final setup = _lotSetups[lot.id]!;
        await SaleService().registerSale(
          lot: lot,
          buyerUid: memberUid,
          buyerName: _memberDetails.name,
          saleType: setup.saleType,
          downPayment: setup.downPayment,
          termMonths: setup.termMonths,
          annualInterestRate: setup.annualInterestRate,
          soldDate: DateTime.now(),
          recordedBy: FirebaseAuth.instance.currentUser!.uid,
        );
      }

      await secondaryAuth.signOut();
      await secondaryApp.delete();

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
