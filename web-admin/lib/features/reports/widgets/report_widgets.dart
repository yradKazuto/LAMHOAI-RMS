import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/member_model.dart';

class DateFilter extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const DateFilter({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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

class FilterDropdown extends StatelessWidget {
  final String label, hint;
  final String? value;
  final List<DropdownMenuItem<String?>> items;
  final void Function(String?) onChanged;

  const FilterDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
                hint: Text(hint,
                    style:
                        AppTypography.bodyMedium.copyWith(color: AppColors.textMuted)),
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

class MemberDropdown extends StatelessWidget {
  final FirestoreService fs;
  final String? selectedId;
  final String? selectedName;
  final void Function(String id, String name) onSelected;
  final VoidCallback onClear;

  const MemberDropdown({
    super.key,
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
            Text('Member',
                style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
                  return members.where((m) => m.name
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (m) => onSelected(m.uid, m.name),
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                  if (selectedId == null && controller.text.isNotEmpty) {
                    controller.clear();
                  } else if (selectedName != null &&
                      controller.text != selectedName) {
                    controller.text = selectedName!;
                  }
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onEditingComplete: onEditingComplete,
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search member...',
                      hintStyle: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
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

class ReportTableHeader extends StatelessWidget {
  final String text;
  const ReportTableHeader({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w600, color: AppColors.textMuted));
}
