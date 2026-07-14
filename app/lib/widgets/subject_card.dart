import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_helpers.dart';

/// Compact subject card for the Year screen grid.
///
/// Vertically centered: gradient circular icon, subject name, subtitle.
/// Subjects without content are dimmed with a "لم تُضف بعد" subtitle but
/// remain tappable (existing behavior preserved).
class SubjectCard extends StatefulWidget {
  const SubjectCard({
    super.key,
    required this.label,
    required this.slug,
    required this.hasContent,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String slug;
  final bool hasContent;
  final VoidCallback onTap;

  /// Optional second line. Null = omitted (tighter card). Callers pass real
  /// information only (e.g. "لم تُضف بعد" or a year count) — never filler.
  final String? subtitle;

  @override
  State<SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<SubjectCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.hasContent
        ? subjectAccent(widget.slug)
        : scheme.onSurfaceVariant;

    return AnimatedScale(
      scale: _pressed ? 0.965 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeInOutCubic,
      child: Opacity(
        opacity: widget.hasContent ? 1 : 0.6,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Semantics(
              button: true,
              label: widget.label,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            accent.withValues(alpha: 0.20),
                            accent.withValues(alpha: 0.08),
                          ],
                        ),
                      ),
                      child: Icon(iconForSubject(widget.label),
                          color: accent, size: 26),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
