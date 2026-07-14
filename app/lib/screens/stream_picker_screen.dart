import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../providers/selected_stream.dart';

const _bgTop = Color(0xFF16307E);
const _bgRoyal = Color(0xFF2B4FD8);

/// First-launch stream selection: the student picks their شعبة once, then
/// syncing downloads only that stream's papers. Changeable later from the
/// Home settings sheet.
class StreamPickerScreen extends ConsumerWidget {
  const StreamPickerScreen({super.key});

  static const _icons = {
    'sci': Icons.biotech_rounded,
    'math': Icons.calculate_rounded,
    'tm': Icons.precision_manufacturing_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgRoyal],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Text(
                  AppConfig.appTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.alexandria(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'اختر شعبتك — وسيتم تحميل جميع الشعب للمطالعة دون إنترنت',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.alexandria(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14.5,
                    height: 1.7,
                  ),
                ),
                const Spacer(),
                for (final s in kStreams) ...[
                  _StreamCard(
                    info: s,
                    icon: _icons[s.slug] ?? Icons.school_rounded,
                    onTap: () async {
                      await ref
                          .read(selectedStreamProvider.notifier)
                          .set(s.label);
                      if (context.mounted) context.go('/sync');
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                const Spacer(flex: 2),
                Text(
                  'يمكنك التنقل بين الشعب في أي وقت من الشاشة الرئيسية',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.alexandria(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamCard extends StatelessWidget {
  const _StreamCard({
    required this.info,
    required this.icon,
    required this.onTap,
  });

  final StreamInfo info;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'شعبة ${info.label}',
                  style: GoogleFonts.alexandria(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_left_rounded,
                  textDirection: TextDirection.ltr,
                  color: Colors.white.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
