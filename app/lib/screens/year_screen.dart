import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/manifest_providers.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/subject_card.dart';
import '../widgets/ui_helpers.dart';

/// Year screen: the 9 subject cards directly (no stream step).
/// Business logic unchanged — same providers, same slug-based navigation,
/// subjects without content stay dimmed but tappable.
class YearScreen extends ConsumerWidget {
  const YearScreen({super.key, required this.year});
  final String year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available =
        ref.watch(subjectsWithContentProvider(year)).value ?? const <String>{};

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------- header ----------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Entrance(
                fromOffset: const Offset(0, -0.25),
                child: Row(
                  children: [
                    const _RoundedBackButton(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'بكالوريا $year',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Entrance(
              delayFraction: 0.1,
              fromOffset: const Offset(0, -0.3),
              child: Breadcrumb(items: [
                BreadcrumbItem('الرئيسية', onTap: () => context.go('/')),
                BreadcrumbItem('بكالوريا $year'),
              ]),
            ),
            const SizedBox(height: 4),
            // -------------------------- subject grid ------------------------
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  // ~2 columns on phones, scales up on tablets/landscape.
                  maxCrossAxisExtent: 240,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.02,
                ),
                itemCount: kBrowseSubjects.length,
                itemBuilder: (context, i) {
                  final s = kBrowseSubjects[i];
                  return Entrance(
                    delayFraction: (i % 10) * 0.05,
                    duration: const Duration(milliseconds: 800),
                    child: SubjectCard(
                      label: s.label,
                      slug: s.slug,
                      hasContent: available.contains(s.label),
                      subtitle:
                          available.contains(s.label) ? null : 'لم تُضف بعد',
                      onTap: () =>
                          context.push('/year/$year/subject/${s.slug}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back button in a rounded white Material container.
/// Uses BackButtonIcon so the arrow direction mirrors correctly under RTL.
class _RoundedBackButton extends StatelessWidget {
  const _RoundedBackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: BackButtonIcon(),
          ),
        ),
      ),
    );
  }
}
