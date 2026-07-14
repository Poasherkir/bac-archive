import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../providers/browse_mode.dart';
import '../providers/delta_sync.dart';
import '../providers/theme_mode.dart';
import '../providers/manifest_providers.dart';
import '../widgets/home_search_bar.dart';
import '../widgets/ui_helpers.dart';
import '../widgets/subject_card.dart';
import '../widgets/year_card.dart';

/// Home: large header, M3 search bar, compact year grid (newest first).
/// Reads only the cached manifest — no network. Business logic unchanged.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Silent background delta-sync (no UI interruption). Runs once per session.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(deltaSyncProvider).maybeRun(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(yearsProvider);
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(browseModeProvider);
    // Dot on the settings icon whenever a non-default setting is active.
    final settingsActive = ref.watch(themeModeProvider) != ThemeMode.system;

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConfig.appTitle,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'جميع مواضيع البكالوريا الجزائرية',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: scheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'الإعدادات',
                      onPressed: () => _showSettingsSheet(context),
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(Icons.settings_outlined,
                              color: scheme.onSurfaceVariant, size: 24),
                          if (settingsActive)
                            Positioned(
                              top: -1,
                              left: -1,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // -------------------------- search bar --------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Entrance(
                delayFraction: 0.15,
                fromOffset: const Offset(0, -0.5),
                child: HomeSearchBar(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  hint: mode == BrowseMode.bySubject
                      ? 'ابحث عن مادة...'
                      : 'ابحث عن سنة...',
                  keyboardType: mode == BrowseMode.bySubject
                      ? TextInputType.text
                      : TextInputType.number,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ----------------------- browse-mode toggle ----------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Entrance(
                delayFraction: 0.25,
                fromOffset: const Offset(0, -0.4),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<BrowseMode>(
                    segments: const [
                      ButtonSegment(
                        value: BrowseMode.byYear,
                        label: Text('حسب السنة'),
                        icon: Icon(Icons.calendar_month_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: BrowseMode.bySubject,
                        label: Text('حسب المادة'),
                        icon: Icon(Icons.menu_book_rounded, size: 18),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (sel) {
                      ref.read(browseModeProvider.notifier).set(sel.first);
                      _clearSearch();
                    },
                    showSelectedIcon: false,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // -------------------------- year grid ---------------------------
            Expanded(
              child: mode == BrowseMode.bySubject
                  ? _SubjectGrid(query: _query, onClear: _clearSearch)
                  : yearsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const CenteredHint(
                  icon: Icons.error_outline_rounded,
                  text: 'تعذّر تحميل المحتوى المحفوظ.',
                ),
                data: (years) {
                  final filtered = _query.isEmpty
                      ? years
                      : years.where((y) => y.contains(_query)).toList();

                  if (years.isEmpty) {
                    return const CenteredHint(
                      icon: Icons.folder_off_rounded,
                      text: 'لا يوجد محتوى بعد.',
                    );
                  }
                  if (filtered.isEmpty) {
                    return CenteredHint(
                      icon: Icons.search_off_rounded,
                      text: 'لا توجد نتائج لـ «$_query»',
                      action: FilledButton.tonal(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        child: const Text('مسح البحث'),
                      ),
                    );
                  }

                  final latestYear = years.first; // list is newest-first
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      // ~2 columns on phones, more on tablets.
                      maxCrossAxisExtent: 240,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: 120,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final year = filtered[i];
                      return Entrance(
                        // Staggered by index, capped so long lists don't lag.
                        delayFraction: (i % 10) * 0.05,
                        duration: const Duration(milliseconds: 800),
                        child: YearCard(
                          year: year,
                          isLatest: year == latestYear,
                          onTap: () => context.push('/year/$year'),
                        ),
                      );
                    },
                  );
                },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  /// Settings sheet: theme mode selector + about entry. UI-only.
  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final mode = ref.watch(themeModeProvider);
          void set(ThemeMode m) =>
              ref.read(themeModeProvider.notifier).set(m);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'المظهر',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(ctx).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                RadioGroup<ThemeMode>(
                  groupValue: mode,
                  onChanged: (m) {
                    if (m != null) set(m);
                  },
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        title: Text('حسب النظام'),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        title: Text('فاتح'),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        title: Text('داكن'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('عن التطبيق'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showAboutDialog(
                      context: context,
                      applicationName: AppConfig.appTitle,
                      applicationVersion: '1.0.0',
                      children: const [
                        Text(AppConfig.tagline, style: TextStyle(height: 1.7)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}


/// Subject-first entry grid: same card style as the year screen, with a
/// real year-count subtitle derived from the cached manifest.
class _SubjectGrid extends ConsumerWidget {
  const _SubjectGrid({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  String _countLabel(int n) {
    if (n <= 0) return 'لم تُضف بعد';
    if (n == 1) return 'متوفر في سنة واحدة';
    if (n == 2) return 'متوفر في سنتين';
    if (n <= 10) return 'متوفر في $n سنوات';
    return 'متوفر في $n سنة';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts =
        ref.watch(subjectYearCountsProvider).value ?? const <String, int>{};
    final filtered = query.isEmpty
        ? kBrowseSubjects
        : kBrowseSubjects.where((s) => s.label.contains(query)).toList();

    if (filtered.isEmpty) {
      return CenteredHint(
        icon: Icons.search_off_rounded,
        text: 'لا توجد نتائج لـ «$query»',
        action: FilledButton.tonal(
          onPressed: onClear,
          child: const Text('مسح البحث'),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.02,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final s = filtered[i];
        final n = counts[s.label] ?? 0;
        return Entrance(
          delayFraction: (i % 10) * 0.05,
          duration: const Duration(milliseconds: 800),
          child: SubjectCard(
            label: s.label,
            slug: s.slug,
            hasContent: n > 0,
            subtitle: _countLabel(n),
            onTap: () => context.push('/subject/${s.slug}'),
          ),
        );
      },
    );
  }
}
