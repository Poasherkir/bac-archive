import 'package:flutter/material.dart';


/// Material 3 SearchBar wired to the caller's search callback.
/// Purely presentational — filtering logic stays in the screen.
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key, required this.onChanged, this.hint});

  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      onChanged: onChanged,
      hintText: hint ?? 'ابحث عن سنة...',
      keyboardType: TextInputType.number,
      leading: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(Icons.search_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant, size: 24),
      ),
      constraints: const BoxConstraints(minHeight: 52, maxHeight: 52),
    );
  }
}

// NOTE: the shared `Entrance` stagger widget lives in widgets/ui_helpers.dart.
