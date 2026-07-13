import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/manifest_providers.dart';

/// Compact year card for the Home grid.
///
/// Layout: tinted circular calendar icon + trailing chevron on top,
/// year number, then "جميع الشعب" (+ subject count when the manifest has it).
/// The newest year gets an "الأحدث" badge and slightly stronger elevation.
class YearCard extends ConsumerStatefulWidget {
  const YearCard({
    super.key,
    required this.year,
    required this.isLatest,
    required this.onTap,
  });

  final String year;
  final bool isLatest;
  final VoidCallback onTap;

  @override
  ConsumerState<YearCard> createState() => _YearCardState();
}

class _YearCardState extends ConsumerState<YearCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // One brand color for all years — subject colors carry identity instead.
    final accent = scheme.primary;
    // Subject count derives from data that already exists in the cached
    // manifest (no new model fields).
    final subjectCount =
        ref.watch(subjectsWithContentProvider(widget.year)).value?.length;

    return AnimatedScale(
      scale: _pressed ? 0.965 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeInOutCubic,
      child: Card(
        elevation: widget.isLatest ? 2 : 1,
        // Latest year: pale primary tint + soft outline (stronger than the
        // badge alone, still quiet).
        color: widget.isLatest
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.05), scheme.surface)
            : null,
        shape: widget.isLatest
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                    color: scheme.primary.withValues(alpha: 0.45), width: 1.2),
              )
            : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                          color: accent, size: 22),
                    ),
                    const Spacer(),
                    if (widget.isLatest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'الأحدث',
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      // chevron glyphs auto-mirror under RTL; pin LTR so the
                      // "open" affordance always points left (‹) in Arabic.
                      Icon(Icons.chevron_left_rounded,
                          textDirection: TextDirection.ltr,
                          color: scheme.onSurfaceVariant, size: 22),
                  ],
                ),
                const Spacer(),
                Text(
                  widget.year,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subjectCount != null && subjectCount > 0
                      ? 'جميع الشعب · $subjectCount مواد'
                      : 'جميع الشعب',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
