import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../models/exam.dart';
import '../providers/manifest_providers.dart';
import '../providers/providers.dart';
import '../router/app_router.dart';
import '../widgets/breadcrumb.dart';
import '../widgets/ui_helpers.dart';

/// Subject screen: three buttons [الموضوع] [الحل] [الحل النموذجي].
/// A button is enabled only when its PDF is present locally.
class SubjectScreen extends ConsumerWidget {
  const SubjectScreen({super.key, required this.year, required this.subject});
  final String year;
  final String subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (year: year, subject: subject);
    final examAsync = ref.watch(examProvider(key));
    final availabilityAsync = ref.watch(subjectAvailabilityProvider(key));

    return Scaffold(
      appBar: AppBar(title: Text(subject)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Breadcrumb(items: [
              BreadcrumbItem('الرئيسية', onTap: () => context.go('/')),
              BreadcrumbItem('بكالوريا $year',
                  onTap: () => context.go('/year/$year')),
              BreadcrumbItem(subject),
            ]),
            Expanded(
              child: availabilityAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => const CenteredHint(
                  icon: Icons.error_outline_rounded,
                  text: 'تعذّر فتح هذه المادة.',
                ),
                data: (available) {
                  final exam = examAsync.value;

                  // No entry, or entry has no files at all.
                  if (exam == null || !exam.hasAnyFile) {
                    return const CenteredHint(
                      icon: Icons.inbox_rounded,
                      text: 'لم يتم إضافة الملفات بعد',
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      for (final kind in ExamFileKind.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _FileButton(
                            kind: kind,
                            hasUrl: exam.urlFor(kind) != null,
                            onDisk: available.contains(kind),
                            onOpen: () => _open(context, ref, exam, kind),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Exam exam,
    ExamFileKind kind,
  ) async {
    final url = exam.urlFor(kind);
    if (url == null) return;
    final path = await ref.read(localStoreProvider).localPathForUrl(url);
    if (!context.mounted) return;
    context.push(
      '/viewer',
      extra: PdfViewerArgs(
        filePath: path,
        title: '${kind.label} — $subject $year',
      ),
    );
  }
}

class _FileButton extends StatelessWidget {
  const _FileButton({
    required this.kind,
    required this.hasUrl,
    required this.onDisk,
    required this.onOpen,
  });

  final ExamFileKind kind;
  final bool hasUrl;
  final bool onDisk;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onDisk;
    final hint = onDisk
        ? null
        : hasUrl
            ? 'قيد التحميل'
            : 'غير متوفر';

    return Material(
      color: enabled ? scheme.primary : scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onOpen : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                color: enabled ? scheme.onPrimary : scheme.onSurfaceVariant,
                size: 26,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  kind.label,
                  style: TextStyle(
                    color: enabled ? scheme.onPrimary : scheme.onSurfaceVariant,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hint != null)
                Text(
                  hint,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                )
              else
                Icon(Icons.chevron_left_rounded,
                    textDirection: TextDirection.ltr, color: scheme.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
