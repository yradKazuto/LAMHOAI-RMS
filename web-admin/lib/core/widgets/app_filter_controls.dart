import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// A reusable Wrap of tappable filter chips — shared across screens
/// instead of each screen reimplementing the pattern. Uses the app's
/// design tokens for colors, radius, and typography.
class AppFilterChipGroup<T> extends StatelessWidget {
  final T value;
  final List<MapEntry<T, String>> options;
  final ValueChanged<T>? onChanged;
  final bool showSelectedBorder;

  const AppFilterChipGroup({
    required this.value,
    required this.options,
    this.onChanged,
    this.showSelectedBorder = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options.map((opt) {
      final selected = opt.key == value;
      return InkWell(
        onTap: () => onChanged?.call(opt.key),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.1)
                : AppPrimitiveColors.navy100,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.borderSubtle,
            ),
          ),
          child: Text(opt.value,
              style: TextStyle(
                  fontSize: 12.5,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
    }).toList(),
  );
}

/// A labeled filter field inside a popover panel — consistent across screens.
class AppPopoverFilterField extends StatelessWidget {
  final String label;
  final Widget child;

  const AppPopoverFilterField({
    required this.label,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600])),
        const SizedBox(height: 5),
        SizedBox(width: double.infinity, child: child),
      ],
    ),
  );
}

/// A filter popover button that anchors a filter panel below it via
/// [CompositedTransformTarget]/[CompositedTransformFollower]. Same
/// behavior as the individual screen versions but a single shared widget.
class AppFilterPopoverButton extends StatefulWidget {
  final int activeFilterCount;
  final List<Widget> Function(
    BuildContext context,
    void Function(void Function()) setPanelState,
    VoidCallback close,
  ) panelBuilder;
  final VoidCallback onReset;

  const AppFilterPopoverButton({
    required this.activeFilterCount,
    required this.panelBuilder,
    required this.onReset,
    super.key,
  });

  @override
  State<AppFilterPopoverButton> createState() =>
      _AppFilterPopoverButtonState();
}

class _AppFilterPopoverButtonState extends State<AppFilterPopoverButton> {
  static final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _toggle() => _entry == null ? _open() : _close();

  void _open() {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: const Offset(0, 48),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {},
                  child: StatefulBuilder(
                    builder: (panelContext, setPanelState) => Container(
                      width: 300,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.borderSubtle),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Filters',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  widget.onReset();
                                  setPanelState(() {});
                                },
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap),
                                child: const Text('Reset',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...widget.panelBuilder(
                              panelContext, setPanelState, _close),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _close,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.textInverted,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.lg)),
                              ),
                              child: const Text('Done',
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: _toggle,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                  color: widget.activeFilterCount > 0
                      ? AppColors.primary
                      : AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list,
                    size: 18,
                    color: widget.activeFilterCount > 0
                        ? AppColors.primary
                        : Colors.grey[600]),
                const SizedBox(width: 6),
                Text(widget.activeFilterCount > 0
                    ? 'Filter (${widget.activeFilterCount})'
                    : 'Filter',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.activeFilterCount > 0
                            ? AppColors.primary
                            : Colors.grey[600])),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 16, color: Colors.grey[500]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A standard mobile-bottom-sheet filter panel.
/// Pass the title, reset callback, and children (filter fields).
class AppFilterBottomSheet extends StatelessWidget {
  final String title;
  final VoidCallback? onReset;
  final List<Widget> children;

  const AppFilterBottomSheet({
    required this.title,
    required this.children,
    this.onReset,
    super.key,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  if (onReset != null)
                    TextButton(
                      onPressed: () => onReset?.call(),
                      child: const Text('Reset', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ...children,
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textInverted,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg)),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      );
}
