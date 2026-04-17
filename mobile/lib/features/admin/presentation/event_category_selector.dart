import "package:flutter/material.dart";

/// Holds all the multi-select category selections for an event.
class EventCategorySelections {
  Set<String> skateTypes = {};
  Set<String> distances = {};
  Set<String> ages = {};
  Set<String> ageGroups = {};
  Set<String> grades = {};
  Set<String> genders = {};

  /// Generates a flat list of category-map payloads from the cross-product
  /// of all selected values, ready to be sent to the backend.
  List<Map<String, dynamic>> toCategoryPayloads({double price = 0.0}) {
    final categories = <Map<String, dynamic>>[];
    final sTypes = skateTypes.isNotEmpty ? skateTypes.toList() : [""];
    final dists = distances.isNotEmpty ? distances.toList() : [""];
    final gens = genders.isNotEmpty ? genders.toList() : [""];

    // Merge age + ageGroups + grades into a single combined set
    final allAgeLabels = <String>{...ages, ...ageGroups, ...grades};
    final ageList = allAgeLabels.isNotEmpty ? allAgeLabels.toList() : [""];

    for (final sType in sTypes) {
      for (final dist in dists) {
        for (final age in ageList) {
          for (final gen in gens) {
            final parts = [sType, dist, age, gen].where((p) => p.isNotEmpty);
            final name = parts.join(" ").trim();
            if (name.isEmpty) continue;
            categories.add({
              "name": name,
              "skate_type": sType.isNotEmpty ? sType : null,
              "distance": dist.isNotEmpty ? dist : null,
              "age_group": age.isNotEmpty ? age : null,
              "gender": gen.isNotEmpty ? gen.toLowerCase() : null,
              "price": price,
            });
          }
        }
      }
    }
    return categories;
  }
}

/// A comprehensive, Material-3 styled multi-group checkbox selector
/// for skating event categories.
///
/// Uses [Wrap] for natural flow/wrapping and bordered containers for each group.
class EventCategorySelectorWidget extends StatefulWidget {
  const EventCategorySelectorWidget({
    required this.selections,
    required this.onChanged,
    super.key,
  });

  final EventCategorySelections selections;
  final VoidCallback onChanged;

  @override
  State<EventCategorySelectorWidget> createState() =>
      _EventCategorySelectorWidgetState();
}

class _EventCategorySelectorWidgetState
    extends State<EventCategorySelectorWidget> {
  // ── Data ─────────────────────────────────────────────────────────
  static const _skateTypes = [
    "Tenacity",
    "Recreational-inline",
    "Quad",
    "Pro-inline",
    "Roller Derby",
    "Roller Scooter",
    "Speed",
    "Artistic",
    "Roller Hockey",
    "Inline Hockey",
    "Inline Freestyle",
    "Skateboarding",
    "Roller Freestyle",
    "Inline Downhill",
    "Inline Alpine",
    "Skate cross",
  ];

  static const _distances = [
    "100m",
    "200m",
    "300m",
    "400m",
    "500m",
    "1000m",
  ];

  static const _ages = [
    "6–8",
    "8–10",
    "10-12",
    "12–15",
    "15-18",
    "18+",
  ];

  static const _ageGroups = [
    "Under 11",
    "Under 14",
    "Under 17",
    "Under 19",
  ];

  static const _grades = [
    "LKG",
    "UKG",
    "1",
    "2-3",
    "4-5",
    "6-8",
    "9-10",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
    "10+",
  ];

  static const _genders = ["Male", "Female"];

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sel = widget.selections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Group 1: Skate Type ──────────────────────────────────
        _borderedGroup(
          context,
          title: "Skate Type",
          icon: Icons.skateboarding,
          children: _buildCheckboxChips(
            items: _skateTypes,
            selected: sel.skateTypes,
            onToggle: (item, val) {
              setState(() {
                val ? sel.skateTypes.add(item) : sel.skateTypes.remove(item);
              });
              widget.onChanged();
            },
          ),
        ),
        const SizedBox(height: 16),

        // ── Group 2: Distance ────────────────────────────────────
        _borderedGroup(
          context,
          title: "Distance",
          icon: Icons.straighten,
          children: _buildCheckboxChips(
            items: _distances,
            selected: sel.distances,
            onToggle: (item, val) {
              setState(() {
                val ? sel.distances.add(item) : sel.distances.remove(item);
              });
              widget.onChanged();
            },
          ),
        ),
        const SizedBox(height: 16),

        // ── Group 3: Age/Grade Categories (Nested) ───────────────
        _borderedGroup(
          context,
          title: "Age / Grade Categories",
          icon: Icons.groups,
          isOuter: true,
          children: [
            // 3.1 Age
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _borderedGroup(
                context,
                title: "Age",
                icon: Icons.cake,
                isNested: true,
                children: _buildCheckboxChips(
                  items: _ages,
                  selected: sel.ages,
                  onToggle: (item, val) {
                    setState(() {
                      val ? sel.ages.add(item) : sel.ages.remove(item);
                    });
                    widget.onChanged();
                  },
                ),
              ),
            ),
            // 3.2 Age Groups
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _borderedGroup(
                context,
                title: "Age Groups",
                icon: Icons.escalator_warning,
                isNested: true,
                children: _buildCheckboxChips(
                  items: _ageGroups,
                  selected: sel.ageGroups,
                  onToggle: (item, val) {
                    setState(() {
                      val
                          ? sel.ageGroups.add(item)
                          : sel.ageGroups.remove(item);
                    });
                    widget.onChanged();
                  },
                ),
              ),
            ),
            // 3.3 Grade
            _borderedGroup(
              context,
              title: "Grade",
              icon: Icons.school,
              isNested: true,
              children: _buildCheckboxChips(
                items: _grades,
                selected: sel.grades,
                onToggle: (item, val) {
                  setState(() {
                    val ? sel.grades.add(item) : sel.grades.remove(item);
                  });
                  widget.onChanged();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Group 4: Gender ──────────────────────────────────────
        _borderedGroup(
          context,
          title: "Gender",
          icon: Icons.wc,
          children: _buildCheckboxChips(
            items: _genders,
            selected: sel.genders,
            onToggle: (item, val) {
              setState(() {
                val ? sel.genders.add(item) : sel.genders.remove(item);
              });
              widget.onChanged();
            },
          ),
        ),
      ],
    );
  }

  // ── Bordered container with a floating title label ──────────────
  Widget _borderedGroup(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool isOuter = false,
    bool isNested = false,
  }) {
    final cs = Theme.of(context).colorScheme;

    final borderColor = isNested
        ? cs.outline.withValues(alpha: 0.35)
        : cs.primary.withValues(alpha: 0.5);

    final bgColor = isOuter
        ? cs.surfaceContainerLow
        : isNested
            ? cs.surface
            : cs.surfaceContainerLowest;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: isOuter ? 1.5 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title bar ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOuter
                  ? cs.primaryContainer.withValues(alpha: 0.6)
                  : isNested
                      ? cs.secondaryContainer.withValues(alpha: 0.4)
                      : cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: isNested ? 16 : 18,
                    color: isOuter ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isNested ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: isOuter ? cs.primary : cs.onSurface,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // ── Content ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(isOuter ? 12 : 10),
            child: isOuter
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  )
                : Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: children,
                  ),
          ),
        ],
      ),
    );
  }

  // ── Build compact checkbox chips for a group ────────────────────
  List<Widget> _buildCheckboxChips({
    required List<String> items,
    required Set<String> selected,
    required void Function(String item, bool value) onToggle,
  }) {
    return items.map((item) {
      final isSelected = selected.contains(item);
      return _CompactCheckboxChip(
        label: item,
        isSelected: isSelected,
        onChanged: (val) => onToggle(item, val),
      );
    }).toList();
  }
}

/// A compact, Material-3 styled checkbox chip that wraps naturally inside
/// a [Wrap] widget.
class _CompactCheckboxChip extends StatelessWidget {
  const _CompactCheckboxChip({
    required this.label,
    required this.isSelected,
    required this.onChanged,
  });

  final String label;
  final bool isSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer.withValues(alpha: 0.4)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: isSelected,
                onChanged: (val) => onChanged(val ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? cs.primary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
