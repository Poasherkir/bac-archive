import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../models/exam.dart';
import '../providers/manifest_providers.dart';
import '../providers/providers.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/ui_helpers.dart';

/// Subject-first browsing: every paper for one subject across all years,
/// newest first, grouped under per-year cards. Each chip opens the local
/// PDF directly — one tap from year to document.
class SubjectArchiveScreen extends ConsumerWidget {
  const SubjectArchiveScreen({super.key, required this.subject});
  final String subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(examsBySubjectProvider(subject));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        subject,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
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
                BreadcrumbItem(subject),
              ]),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: examsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => const CenteredHint(
                  icon: Icons.error_outline_rounded,
                  text: 'تعذّر فتح هذه المادة.',
                ),
                data: (exams) {
                  if (exams.isEmpty) {
                    return const CenteredHint(
                      icon: Icons.inbox_rounded,
                      text: 'لم يتم إضافة الملفات بعد',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: exams.length,
                    itemBuilder: (context, i) => Entrance(
                      delayFraction: (i % 8) * 0.05,
                      duration: const Duration(milliseconds: 700),
                      child: _YearBlock(exam: exams[i], subject: subject),
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

/// One year's papers for the subject: header + up to three document chips.
class _YearBlock extends ConsumerWidget {
  const _YearBlock({required this.exam, required this.subject});

  final Exam exam;
  final String subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accent = subjectAccent(_slugFor(subject));
    final availability = ref
            .watch(subjectAvailabilityProvider(
                (year: exam.year, subject: subject)))
            .value ??
        const <ExamFileKind>{};

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.calendar_month_rounded,
                      size: 19, color: accent),
                ),
                const SizedBox(width: 10),
                Text(
                  'بكالوريا ${exam.year}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in ExamFileKind.values)
                  _FileChip(
                    label: kind.label,
                    enabled: availability.contains(kind),
                    onTap: () => _open(context, ref, kind),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _slugFor(String label) {
    for (final s in kBrowseSubjects) {
      if (s.label == label) return s.slug;
    }
    return label;
  }

  Future<void> _open(
      BuildContext context, WidgetRef ref, ExamFileKind kind) async {
    final url = exam.urlFor(kind);
    if (url == null) return;
    final path = await ref.read(localStoreProvider).localPathForUrl(url);
    if (!context.mounted) return;
    context.push(
      '/viewer',
      extra: PdfViewerArgs(
        filePath: path,
        title: '${kind.label} — $subject ${exam.year}',
      ),
    );
  }
}

/// Compact document action. Disabled (dimmed) when the file isn't on disk.
class _FileChip extends StatelessWidget {
  const _FileChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: enabled
          ? scheme.primary.withValues(alpha: 0.10)
          : scheme.onSurface.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          height: 44, // comfortable touch target
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                size: 16,
                color: enabled ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back button in a rounded surface container (mirrors under RTL).
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
          child: Center(child: BackButtonIcon()),
        ),
      ),
    );
  }
}
