import 'package:flutter/material.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';

/// Filter option item for a filter group
class FilterOption {
  final String key;
  final String label;
  final IconData? icon;

  const FilterOption({
    required this.key,
    required this.label,
    this.icon,
  });
}

/// Filter group for the universal FilterSheet
class FilterGroup {
  final String id;
  final String title;
  final bool multiSelect;
  final List<FilterOption> options;

  const FilterGroup({
    required this.id,
    required this.title,
    this.multiSelect = false,
    required this.options,
  });
}

/// Universal Filter Sheet conforming to buildathon specifications
class FilterSheet extends StatefulWidget {
  final List<FilterGroup> groups;
  final Map<String, List<String>> initialValues;
  final ValueChanged<Map<String, List<String>>> onApply;
  final VoidCallback? onReset;

  const FilterSheet({
    super.key,
    required this.groups,
    required this.initialValues,
    required this.onApply,
    this.onReset,
  });

  static Future<Map<String, List<String>>?> show({
    required BuildContext context,
    required List<FilterGroup> groups,
    required Map<String, List<String>> currentValues,
    VoidCallback? onReset,
  }) {
    return showModalBottomSheet<Map<String, List<String>>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => FilterSheet(
        groups: groups,
        initialValues: currentValues,
        onApply: (selected) => Navigator.of(ctx).pop(selected),
        onReset: onReset,
      ),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Map<String, List<String>> _selectedValues;

  @override
  void initState() {
    super.initState();
    _selectedValues = Map.fromEntries(
      widget.initialValues.entries.map((e) => MapEntry(e.key, List<String>.from(e.value))),
    );
  }

  bool get _hasActiveFilters {
    for (final entry in _selectedValues.entries) {
      if (entry.value.isNotEmpty) return true;
    }
    return false;
  }

  void _toggleOption(String groupId, String optionKey, bool multiSelect) {
    setState(() {
      final currentList = _selectedValues[groupId] ?? [];
      if (multiSelect) {
        if (currentList.contains(optionKey)) {
          currentList.remove(optionKey);
        } else {
          currentList.add(optionKey);
        }
        _selectedValues[groupId] = currentList;
      } else {
        if (currentList.contains(optionKey)) {
          _selectedValues[groupId] = [];
        } else {
          _selectedValues[groupId] = [optionKey];
        }
      }
    });
  }

  void _handleReset() {
    setState(() {
      for (final key in _selectedValues.keys) {
        _selectedValues[key] = [];
      }
    });
    widget.onReset?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Filters & Refine',
                      style: AppTypography.headlineSm(fontSize: 18),
                    ),
                  ],
                ),
                if (_hasActiveFilters)
                  TextButton(
                    onPressed: _handleReset,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'Reset All',
                      style: AppTypography.labelMd(color: AppColors.error),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),

          const Divider(height: 16, color: AppColors.border),

          // Filter groups list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: widget.groups.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 22),
              itemBuilder: (context, index) {
                final group = widget.groups[index];
                final selectedInGroup = _selectedValues[group.id] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          group.title.toUpperCase(),
                          style: AppTypography.labelSm(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (group.multiSelect)
                          Text(
                            'Multi-select',
                            style: AppTypography.bodySm(color: AppColors.textTertiary, fontSize: 11),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: group.options.map((option) {
                        final isSelected = selectedInGroup.contains(option.key);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _toggleOption(group.id, option.key, group.multiSelect),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (option.icon != null) ...[
                                    Icon(
                                      option.icon,
                                      size: 15,
                                      color: isSelected ? Colors.white : AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    option.label,
                                    style: AppTypography.labelMd(
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),

          // Apply button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: () => widget.onApply(_selectedValues),
                  child: Text(
                    'Apply Filters',
                    style: AppTypography.labelLg(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter icon button with an active filter badge counter
class FilterIconButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;
  final Color? backgroundColor;

  const FilterIconButton({
    super.key,
    required this.activeCount,
    required this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 20,
              color: activeCount > 0 ? AppColors.primary : AppColors.textSecondary,
            ),
            if (activeCount > 0)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$activeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
