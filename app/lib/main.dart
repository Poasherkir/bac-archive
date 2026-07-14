import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'providers/providers.dart';
import 'providers/theme_mode.dart';
import 'router/app_router.dart';
import 'services/local_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Initialize Supabase with the public anon key. Access is governed by RLS.
  // If not yet configured, we still start so the UI is reachable during dev.
  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // The public anon/publishable key. `publishableKey` is the current param
      // name in supabase_flutter 2.15+; a legacy anon key is a valid value.
      publishableKey: AppConfig.supabaseAnonKey,
    );
  } else {
    debugPrint(
      'AppConfig not configured — set SUPABASE_URL / SUPABASE_ANON_KEY '
      '(see lib/config/app_config.dart). Sync will be unavailable.',
    );
  }

  // Boot gate: fresh installs pick a stream first; synced streams go
  // straight to Home; chosen-but-unsynced streams resume the sync screen.
  final selected = prefs.getString('selected_stream');
  final legacyDone = prefs.getBool(LocalStore.kSyncCompleteKey) ?? false;
  final slug = kStreams
      .firstWhere((s) => s.label == selected, orElse: () => kStreams.first)
      .slug;
  final done =
      (prefs.getBool('sync_complete_$slug') ?? false) ||
          (slug == 'sci' && legacyDone);
  final initial = (selected == null && !legacyDone)
      ? '/stream'
      : (done ? '/' : '/sync');

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: BacApp(router: buildRouter(initialLocation: initial)),
    ),
  );
}

class BacApp extends ConsumerWidget {
  const BacApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConfig.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // System by default; persisted user choice wins (settings sheet on Home).
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,

      // Arabic + RTL everywhere.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
