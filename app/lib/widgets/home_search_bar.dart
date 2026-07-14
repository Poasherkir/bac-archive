import 'package:flutter/material.dart';


/// Material 3 SearchBar wired to the caller's search callback.
/// Purely presentational — filtering logic stays in the screen.
/// Shows a clear (×) action while the field has text.
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.keyboardType = TextInputType.number,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SearchBar(
      controller: controller,
      onChanged: onChanged,
      hintText: hint ?? 'ابحث عن سنة...',
      keyboardType: keyboardType,
      leading: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(Icons.search_rounded,
            color: scheme.onSurfaceVariant, size: 24),
      ),
      trailing: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'مسح البحث',
                  icon: Icon(Icons.close_rounded,
                      size: 20, color: scheme.onSurfaceVariant),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ],
      constraints: const BoxConstraints(minHeight: 52, maxHeight: 52),
    );
  }
}

// NOTE: the shared `Entrance` stagger widget lives in widgets/ui_helpers.dart.
