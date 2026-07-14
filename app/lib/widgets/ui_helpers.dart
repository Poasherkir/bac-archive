import 'package:flutter/material.dart';


/// Icon per subject label (falls back to a book).
IconData iconForSubject(String subject) {
  switch (subject) {
    case 'رياضيات':
      return Icons.calculate_rounded;
    case 'فيزياء':
      return Icons.bolt_rounded;
    case 'علوم طبيعية':
      return Icons.biotech_rounded;
    case 'عربية':
      return Icons.menu_book_rounded;
    case 'فرنسية':
      return Icons.translate_rounded;
    case 'إنجليزية':
      return Icons.language_rounded;
    case 'فلسفة':
      return Icons.psychology_rounded;
    case 'تاريخ وجغرافيا':
      return Icons.public_rounded;
    case 'تربية إسلامية':
      return Icons.mosque_rounded;
    case 'تكنولوجيا':
      return Icons.precision_manufacturing_rounded;
    default:
      return Icons.description_rounded;
  }
}

/// Responsive column count: phone 2, large phone/small tablet 3, tablet 4.
int gridColumns(double width) {
  if (width >= 900) return 4;
  if (width >= 600) return 3;
  return 2;
}

/// One-shot fade + slide entrance. [delayFraction] staggers items by holding
/// the animation flat until that fraction of [duration] has elapsed.
/// Cheap: a single TweenAnimationBuilder per child, runs once on mount.
class Entrance extends StatelessWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delayFraction = 0,
    this.duration = const Duration(milliseconds: 700),
    this.fromOffset = const Offset(0, 0.06),
  });

  final Widget child;
  final double delayFraction;
  final Duration duration;
  final Offset fromOffset;

  @override
  Widget build(BuildContext context) {
    final begin = delayFraction.clamp(0.0, 0.8);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Interval(begin, 1, curve: Curves.easeInOutCubic),
      child: child,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: FractionalTranslation(
          translation: fromOffset * (1 - t),
          child: c,
        ),
      ),
    );
  }
}

/// Centered empty / loading / error placeholders sharing one look.
class CenteredHint extends StatelessWidget {
  const CenteredHint({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: secondary),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: secondary,
                fontSize: 15,
                height: 1.7,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
