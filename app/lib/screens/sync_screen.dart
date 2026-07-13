import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../providers/sync_controller.dart';
import '../utils/format.dart';

// Splash palette (kept local: this screen predates theming on purpose —
// it must look right before anything else loads).
const _bgTop = Color(0xFF1E3A8A);
const _bgBottom = Color(0xFF3B5FE0);
const _amber = Color(0xFFFBBF24);

/// First-launch "Preparing Content" screen. Fetches the manifest, warns on
/// mobile data, downloads every PDF with progress, then flags sync complete
/// and moves to Home — after which the app never shows this screen again.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen>
    with TickerProviderStateMixin {
  bool _wifiDialogOpen = false;

  // One-shot staggered intro: icon -> title -> progress area.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final Animation<double> _iconIn = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.45, curve: Curves.easeInOut),
  );
  late final Animation<double> _titleIn = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.25, 0.70, curve: Curves.easeInOut),
  );
  late final Animation<double> _bodyIn = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.50, 1.0, curve: Curves.easeInOut),
  );

  // Shared repeating driver: page-flip, bar pulse, animated ellipsis.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(syncControllerProvider.notifier).begin(),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SyncState>(syncControllerProvider, (prev, next) {
      if (next is SyncDone) {
        context.go('/');
      } else if (next is SyncNeedWifiConfirm && !_wifiDialogOpen) {
        _showWifiDialog(next);
      }
    });

    final state = ref.watch(syncControllerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Faint decorative circles — static paint, ≤6% opacity.
            const CustomPaint(painter: _BubblesPainter()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    _Staggered(
                      animation: _iconIn,
                      child: _FlippingBook(loop: _loop),
                    ),
                    const SizedBox(height: 26),
                    _Staggered(
                      animation: _titleIn,
                      child: Column(
                        children: [
                          Text(
                            AppConfig.appTitle,
                            style: GoogleFonts.alexandria(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppConfig.tagline,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.alexandria(
                              color: Colors.white.withValues(alpha: 0.80),
                              fontSize: 14.5,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 2),
                    _Staggered(
                      animation: _bodyIn,
                      child: _StateBody(state: state, loop: _loop),
                    ),
                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWifiDialog(SyncNeedWifiConfirm s) async {
    _wifiDialogOpen = true;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('تنبيه بيانات الهاتف'),
        content: Text(
          'أنت غير متصل بشبكة واي فاي. سيتم تنزيل ${s.fileCount} ملفًا '
          'بحجم إجمالي ${formatBytes(s.totalBytes)} باستخدام بيانات الهاتف.\n\n'
          'هل تريد المتابعة؟',
          style: const TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انتظار واي فاي'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    _wifiDialogOpen = false;
    final ctrl = ref.read(syncControllerProvider.notifier);
    if (proceed == true) {
      ctrl.continueAnyway();
    } else {
      ctrl.waitForWifi();
    }
  }
}

/// Fade + small upward slide, driven by one interval of the intro controller.
class _Staggered extends StatelessWidget {
  const _Staggered({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, c) => Transform.translate(
          offset: Offset(0, 14 * (1 - animation.value)),
          child: c,
        ),
      ),
    );
  }
}

/// Book icon with a soft glow and a subtle page flipping right-to-left.
class _FlippingBook extends StatelessWidget {
  const _FlippingBook({required this.loop});
  final AnimationController loop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      alignment: Alignment.center,
      // Glass-style circle: translucent fill + hairline border + a soft
      // blue radial glow behind (subtle, not neon).
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF93C5FD).withValues(alpha: 0.28),
            blurRadius: 42,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SizedBox(
        width: 96,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.menu_book_rounded, size: 76, color: Colors.white),
            // The flipping page, hinged at the book's spine (center).
            Positioned(
              left: 48,
              top: 20,
              child: AnimatedBuilder(
                animation: loop,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(loop.value);
                  final angle = -math.pi * t;
                  // Fade the page out at the end of the sweep so the loop
                  // restart is invisible.
                  final fade = t < 0.82 ? 1.0 : (1 - (t - 0.82) / 0.18);
                  return Opacity(
                    opacity: 0.85 * fade.clamp(0.0, 1.0),
                    child: Transform(
                      alignment: Alignment.centerLeft,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..rotateY(angle),
                      child: Container(
                        width: 26,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
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

/// The part of the screen that changes with sync state.
class _StateBody extends ConsumerWidget {
  const _StateBody({required this.state, required this.loop});
  final SyncState state;
  final AnimationController loop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state) {
      case SyncInitial():
      case SyncChecking():
      case SyncNeedWifiConfirm():
        return _ProgressPanel(
          loop: loop,
          statusText: 'جارٍ تجهيز الأرشيف…',
          progress: null,
        );

      case SyncDownloading(
          :final filesDone,
          :final filesTotal,
          :final progress
        ):
        return _ProgressPanel(
          loop: loop,
          statusText: 'جارٍ تجهيز الأرشيف…',
          progress: progress,
          counterLine: (done: filesDone, total: filesTotal),
        );

      case SyncWaitingWifi():
        return const _Message(
          icon: Icons.wifi_rounded,
          text: 'في انتظار الاتصال بشبكة واي فاي.',
          buttonLabel: 'تحقّق مجددًا',
        );

      case SyncOfflineState():
        return const _Message(
          icon: Icons.wifi_off_rounded,
          title: 'تعذّر تجهيز المحتوى',
          text: 'تحقّق من الاتصال ثم حاول مرة أخرى',
          buttonLabel: 'إعادة المحاولة',
        );

      case SyncErrorState():
        return const _Message(
          icon: Icons.error_outline_rounded,
          title: 'تعذّر تجهيز المحتوى',
          text: 'تحقّق من الاتصال ثم حاول مرة أخرى',
          buttonLabel: 'إعادة المحاولة',
        );

      case SyncDone():
        return _ProgressPanel(
          loop: loop,
          statusText: 'اكتمل التجهيز',
          progress: 1,
        );
    }
  }
}

/// Rounded gradient progress bar + animated status line + counter/percent row.
class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.loop,
    required this.statusText,
    required this.progress,
    this.counterLine,
  });

  final AnimationController loop;
  final String statusText;

  /// null = indeterminate (checking), 0..1 = real progress.
  final double? progress;
  final ({int done, int total})? counterLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: GoogleFonts.alexandria(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w400,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),
        // Rounded track + pulsing gradient fill.
        Semantics(
          label: 'نسبة التقدم',
          value: progress == null
              ? null
              : '${((progress ?? 0) * 100).round()}٪',
          child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 8,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return AnimatedBuilder(
                  animation: loop,
                  builder: (context, _) {
                    final pulse = 0.85 +
                        0.15 *
                            (0.5 +
                                0.5 *
                                    math.sin(loop.value * 2 * math.pi));
                    // Indeterminate: a sweeping segment; determinate: fill.
                    if (progress == null) {
                      final x = (loop.value * 1.4 - 0.2) * w;
                      return Stack(
                        children: [
                          Container(color: Colors.white24),
                          Positioned(
                            left: x,
                            width: w * 0.35,
                            top: 0,
                            bottom: 0,
                            child: _fill(pulse),
                          ),
                        ],
                      );
                    }
                    final frac = progress!.clamp(0.02, 1.0);
                    return Stack(
                      children: [
                        Container(color: Colors.white24),
                        Positioned(
                          right: 0, // RTL: fill grows from the right
                          width: w * frac,
                          top: 0,
                          bottom: 0,
                          child: _fill(pulse),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
        ),
        if (counterLine != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${counterLine!.done} من ${counterLine!.total} ملفًا',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.alexandria(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12.5,
                  ),
                ),
              ),
              Text(
                '${((progress ?? 0) * 100).round()}٪',
                style: GoogleFonts.alexandria(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _fill(double pulse) {
    // Blue-dominant fill (white -> light blue) with a tiny warm accent at
    // the leading edge (left end under RTL, where the fill advances).
    return Opacity(
      opacity: pulse,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xFFBFDBFE)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 12,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_amber, Color(0x00FBBF24)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends ConsumerWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.buttonLabel,
    this.title,
  });

  final IconData icon;
  final String text;
  final String buttonLabel;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 44),
        const SizedBox(height: 16),
        if (title != null) ...[
          Semantics(
            header: true,
            child: Text(
              title!,
              textAlign: TextAlign.center,
              style: GoogleFonts.alexandria(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.alexandria(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14.5,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () =>
              ref.read(syncControllerProvider.notifier).retry(),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _bgTop,
            minimumSize: const Size(140, 48), // >=44dp touch target
          ),
          child: Text(buttonLabel),
        ),
      ],
    );
  }
}

/// Static, very faint "document line" clusters — an academic nod that adds
/// depth without noise. Painted once, never repaints.
class _BubblesPainter extends CustomPainter {
  const _BubblesPainter();

  void _docLines(Canvas canvas, Offset origin, double width, Paint paint) {
    // A small abstract paragraph: 3 rounded lines, last one shorter (RTL:
    // lines anchored to the right edge of the cluster).
    const lineH = 5.0;
    const gap = 12.0;
    for (var i = 0; i < 3; i++) {
      final w = i == 2 ? width * 0.55 : width;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(origin.dx + (width - w), origin.dy + i * gap, w, lineH),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.05);
    final w = size.width;
    final h = size.height;
    _docLines(canvas, Offset(w * 0.70, h * 0.09), w * 0.20, paint);
    _docLines(canvas, Offset(w * 0.08, h * 0.20), w * 0.16, paint);
    _docLines(canvas, Offset(w * 0.78, h * 0.68), w * 0.16, paint);
    _docLines(canvas, Offset(w * 0.10, h * 0.84), w * 0.20, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
