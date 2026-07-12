import 'package:flutter/material.dart';


class BreadcrumbItem {
  const BreadcrumbItem(this.label, {this.onTap});
  final String label;
  final VoidCallback? onTap;
}

/// Path breadcrumb shown at the top of every screen except sync.
/// e.g. الرئيسية ‹ بكالوريا 2024 ‹ رياضيات
class Breadcrumb extends StatelessWidget {
  const Breadcrumb({super.key, required this.items});
  final List<BreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;
      children.add(
        InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                color: isLast ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
      if (!isLast) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(Icons.chevron_left,
              size: 16, color: scheme.onSurfaceVariant),
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: children),
      ),
    );
  }
}
