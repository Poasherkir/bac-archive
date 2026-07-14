import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../providers/sync_controller.dart';
import '../utils/format.dart';

// ---------------------------------------------------------------------------
// Palette (local on purpose: this screen must look right before anything
// else — theme, fonts, cached data — has loaded).
// ---------------------------------------------------------------------------
const _bgTop = Color(0xFF16307E); // deep academic blue
const _bgRoyal = Color(0xFF2B4FD8); // royal blue
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _blue = Color(0xFF2563EB);
const _blueBright = Color(0xFF3B82F6);
const _amber = Color(0xFFF59E0B);

/// Archive preparation screen (first launch only).
///
/// Pure UI over the untouched [SyncController] state machine: fetches the
/// manifest, downloads every PDF with real progress, flags completion and
/// hands off to Home. Composition:
///
///   SyncScreen
///   ├── _AnimatedBackground   gradient, drifting glows, dot grid, particles
///   ├── _HeroIllustration     fanned exam-paper stack (floating/breathing)
///   ├── _HeaderSection        title + subtitle
///   └── _ProgressCard         floating M3 surface
///       ├── _AnimatedProgressBar   gradient fill, glow edge, shimmer
///       ├── _DownloadStatistics    animated counts + per-file check pulse
///       └── _FooterStatus          expectation-setting caption
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen>
    with TickerProviderStateMixin {
  bool _wifiDialogOpen = false;
  bool _navigated = false;

  // One-shot staggered entrance: hero -> header -> card.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..forward();

  late final Animation<double> _heroIn = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
  );
  late final Animation<double> _headerIn = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.2, 0.7, curve: Curves.easeInOut),
  );
  late final Animation<double> _cardIn = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.45, 1.0, curve: Curves.easeInOut),
  );

  // Slow ambient driver shared by the background and the hero (12s cycle
  // keeps motion calm and cheap — a single ticker for all drift).
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  // Faster loop for the shimmer sweep on the progress fill.
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
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
    _drift.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SyncState>(syncControllerProvider, (prev, next) {
      if (next is SyncDone && !_navigated) {
        _navigated = true;
        // Brief success beat ("اكتمل تجهيز الأرشيف") before moving on.
        Future.delayed(const Duration(milliseconds: 900), () {
          if (context.mounted) context.go('/');
        });
      } else if (next is SyncNeedWifiConfirm && !_wifiDialogOpen) {
        _showWifiDialog(next);
      }
    });

    final state = ref.watch(syncControllerProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: _AnimatedBackground(drift: _drift)),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 5),
                _Staggered(
                  animation: _heroIn,
                  child: RepaintBoundary(
                    child: _HeroIllustration(drift: _drift),
                  ),
                ),
                const Spacer(flex: 2),
                _Staggered(animation: _headerIn, child: const _HeaderSection()),
                const Spacer(flex: 3),
                _Staggered(
                  animation: _cardIn,
                  fromOffset: const Offset(0, 0.12),
                  child: _ProgressCard(state: state, shimmer: _shimmer),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
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

// ---------------------------------------------------------------------------
// Entrance helper
// ---------------------------------------------------------------------------

/// Fade + small upward slide, driven by one interval of the intro controller.
class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.animation,
    required this.child,
    this.fromOffset = const Offset(0, 0.05),
  });

  final Animation<double> animation;
  final Widget child;
  final Offset fromOffset;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, c) => FractionalTranslation(
          translation: fromOffset * (1 - animation.value),
          child: c,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Background
// ---------------------------------------------------------------------------

/// Gradient base + two slowly drifting glows + static dot grid + a few
/// rising particles. One repaint boundary, one shared ticker.
class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground({required this.drift});
  final AnimationController drift;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgRoyal],
        ),
      ),
      child: AnimatedBuilder(
        animation: drift,
        builder: (context, _) => CustomPaint(
          painter: _BackgroundPainter(t: drift.value),
        ),
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final wave = math.sin(t * 2 * math.pi);

    // Two big soft glows, drifting a few pixels in opposite phases.
    final glow1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF93C5FD).withValues(alpha: 0.20),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(w * 0.5 + wave * 8, h * 0.24),
          radius: w * 0.62,
        ),
      );
    canvas.drawCircle(
        Offset(w * 0.5 + wave * 8, h * 0.24), w * 0.62, glow1);

    final glow2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF60A5FA).withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(w * 0.15 - wave * 6, h * 0.72),
          radius: w * 0.55,
        ),
      );
    canvas.drawCircle(
        Offset(w * 0.15 - wave * 6, h * 0.72), w * 0.55, glow2);

    // Static dot grid over the upper half — quiet academic texture.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.045);
    const spacing = 30.0;
    for (var y = spacing; y < h * 0.52; y += spacing) {
      for (var x = spacing / 2; x < w; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }

    // A few rising particles (slow, faint, wrap around).
    const seeds = [
      (x: 0.12, phase: 0.0, r: 2.2),
      (x: 0.85, phase: 0.35, r: 1.8),
      (x: 0.30, phase: 0.6, r: 1.5),
      (x: 0.68, phase: 0.82, r: 2.0),
    ];
    for (final s in seeds) {
      final p = (s.phase + t) % 1.0;
      final y = h * (0.9 - 0.75 * p);
      // Fade in near the bottom, out near the top.
      final fade = math.sin(p * math.pi);
      canvas.drawCircle(
        Offset(w * s.x, y),
        s.r,
        Paint()..color = Colors.white.withValues(alpha: 0.10 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

/// Custom hero: a fanned stack of exam papers with layered shadows, RTL
/// text lines, a grade seal and an amber bookmark — floating and breathing
/// on the shared drift ticker. No stock icons.
class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration({required this.drift});
  final AnimationController drift;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: drift,
      builder: (context, child) {
        final t = drift.value * 2 * math.pi;
        return Transform.translate(
          offset: Offset(0, 5 * math.sin(t)),
          child: Transform.rotate(
            angle: 0.012 * math.sin(t / 2),
            child: Transform.scale(
              scale: 1 + 0.015 * math.sin(t + math.pi / 3),
              child: child,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 210,
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft glow disc behind the stack.
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF93C5FD).withValues(alpha: 0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            _paper(angle: -0.16, dx: -26, dy: 8, tint: const Color(0xFFDBEAFE)),
            _paper(angle: 0.10, dx: 24, dy: 4, tint: const Color(0xFFEFF6FF)),
            _frontPaper(),
          ],
        ),
      ),
    );
  }

  /// A background sheet in the fan.
  Widget _paper({
    required double angle,
    required double dx,
    required double dy,
    required Color tint,
  }) {
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 104,
          height: 138,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Colors.white, tint],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40101E45),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The front sheet: RTL text lines, blue grade seal, amber bookmark.
  Widget _frontPaper() {
    return Transform.rotate(
      angle: -0.02,
      child: Container(
        width: 112,
        height: 148,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF3F7FF)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59101E45),
              blurRadius: 22,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Amber bookmark ribbon (warm accent).
            PositionedDirectional(
              start: 16,
              top: -2,
              child: Container(
                width: 12,
                height: 26,
                decoration: const BoxDecoration(
                  color: _amber,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(4),
                  ),
                ),
              ),
            ),
            // RTL "exam text" lines.
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 34, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(0.9), _line(0.75), _line(0.85), _line(0.6),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Grade seal.
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_blue, _blueBright],
                          ),
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 18, color: Colors.white),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_line(0.35, width: 34), _line(0.5, width: 46)],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(double frac, {double? width}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        width: width ?? 84 * frac,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Semantics(
            header: true,
            child: Text(
              AppConfig.appTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.alexandria(
                color: Colors.white,
                fontSize: 31,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'مواضيع البكالوريا منظمة حسب السنة والمادة',
            textAlign: TextAlign.center,
            style: GoogleFonts.alexandria(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14.5,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress card
// ---------------------------------------------------------------------------

/// Floating Material 3 surface hosting the live download status.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state, required this.shimmer});

  final SyncState state;
  final AnimationController shimmer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFAFFFFFF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x40101E45),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: _body(),
      ),
    );
  }

  Widget _body() {
    switch (state) {
      case SyncInitial():
      case SyncChecking():
      case SyncNeedWifiConfirm():
        return _LoadingBody(progress: null, shimmer: shimmer);

      case SyncDownloading(
          :final filesDone,
          :final filesTotal,
          :final progress
        ):
        return _LoadingBody(
          progress: progress,
          counter: (done: filesDone, total: filesTotal),
          shimmer: shimmer,
        );

      case SyncDone():
        return _LoadingBody(progress: 1, success: true, shimmer: shimmer);

      case SyncWaitingWifi():
        return const _ProblemBody(
          title: 'في انتظار شبكة واي فاي',
          support: 'سيبدأ التنزيل عند الاتصال، أو تحقّق الآن',
          buttonLabel: 'تحقّق مجددًا',
        );

      case SyncOfflineState():
      case SyncErrorState():
        return const _ProblemBody(
          title: 'تعذّر تجهيز المحتوى',
          support: 'تحقّق من الاتصال ثم حاول مرة أخرى',
          buttonLabel: 'إعادة المحاولة',
        );
    }
  }
}

/// Card header: tinted icon chip + section label.
class _CardHeader extends StatelessWidget {
  const _CardHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(11),
          ),
          child:
              const Icon(Icons.local_library_rounded, size: 19, color: _blue),
        ),
        const SizedBox(width: 10),
        Text(
          'تجهيز مكتبتك',
          style: GoogleFonts.alexandria(
            color: _blue,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// Loading / success content.
class _LoadingBody extends StatelessWidget {
  const _LoadingBody({
    required this.progress,
    required this.shimmer,
    this.counter,
    this.success = false,
  });

  /// null = indeterminate; 0..1 = real progress (NaN/zero-safe upstream).
  final double? progress;
  final ({int done, int total})? counter;
  final bool success;
  final AnimationController shimmer;

  @override
  Widget build(BuildContext context) {
    final pct = ((progress ?? 0) * 100).round().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardHeader(),
        const SizedBox(height: 12),
        Text(
          success ? 'اكتمل تجهيز الأرشيف' : 'جارٍ تجهيز الأرشيف…',
          style: GoogleFonts.alexandria(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'سيصبح المحتوى متاحًا دون اتصال بالإنترنت',
          style: GoogleFonts.alexandria(
            color: _muted,
            fontSize: 12.5,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'نسبة التقدم',
          value: progress == null ? null : '$pct٪',
          child: _AnimatedProgressBar(
            progress: progress,
            success: success,
            shimmer: shimmer,
          ),
        ),
        if (counter != null) ...[
          const SizedBox(height: 10),
          _DownloadStatistics(counter: counter!, pct: pct),
        ],
        const SizedBox(height: 10),
        const _FooterStatus(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Progress bar
// ---------------------------------------------------------------------------

/// Rounded gradient bar with a glowing leading edge and a shimmer sweep
/// while downloading. Fill growth is eased — no abrupt jumps. RTL: the fill
/// grows from the right.
class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({
    required this.progress,
    required this.shimmer,
    this.success = false,
  });

  final double? progress;
  final bool success;
  final AnimationController shimmer;

  @override
  Widget build(BuildContext context) {
    const trackColor = Color(0xFFE2E8F0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 12,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            if (progress == null) {
              return _IndeterminateSweep(trackColor: trackColor);
            }
            final frac = progress!.clamp(0.0, 1.0);
            final fillW = math.max(w * frac, frac > 0 ? 12.0 : 0.0);
            return Stack(
              children: [
                Container(color: trackColor),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: fillW,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: success
                                ? const [Color(0xFF16A34A), Color(0xFF22C55E)]
                                : const [Color(0xFF1D4ED8), _blueBright],
                          ),
                        ),
                      ),
                      // Shimmer sweep across the fill while downloading.
                      if (!success)
                        AnimatedBuilder(
                          animation: shimmer,
                          builder: (context, _) {
                            final x = (shimmer.value * 1.6 - 0.3) * fillW;
                            return Stack(
                              children: [
                                Positioned(
                                  left: x,
                                  top: 0,
                                  bottom: 0,
                                  width: 44,
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00FFFFFF),
                                          Color(0x59FFFFFF),
                                          Color(0x00FFFFFF),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      // Glowing leading edge (left end under RTL).
                      if (!success)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: _LeadingGlow(),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Small luminous cap on the advancing end of the fill.
class _LeadingGlow extends StatelessWidget {
  const _LeadingGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xB3FFFFFF), Color(0x00FFFFFF)],
        ),
      ),
    );
  }
}

/// Self-contained indeterminate sweep for the checking phase.
class _IndeterminateSweep extends StatefulWidget {
  const _IndeterminateSweep({required this.trackColor});
  final Color trackColor;

  @override
  State<_IndeterminateSweep> createState() => _IndeterminateSweepState();
}

class _IndeterminateSweepState extends State<_IndeterminateSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final x = (1 - _c.value * 1.4 + 0.2) * w;
            return Stack(
              children: [
                Container(color: widget.trackColor),
                Positioned(
                  left: x,
                  width: w * 0.35,
                  top: 0,
                  bottom: 0,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1D4ED8), _blueBright],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Statistics
// ---------------------------------------------------------------------------

/// File counter + percentage with smooth number animation and a small
/// check pulse each time a file lands.
class _DownloadStatistics extends StatelessWidget {
  const _DownloadStatistics({required this.counter, required this.pct});

  final ({int done, int total}) counter;
  final int pct;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.description_outlined, size: 15, color: _muted),
        const SizedBox(width: 6),
        // Animated file count (eases between real values).
        TweenAnimationBuilder<double>(
          tween: Tween(end: counter.done.toDouble()),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          builder: (context, v, _) => Text(
            '${v.round()} من ${counter.total} ملفًا',
            style: GoogleFonts.alexandria(
              color: const Color(0xFF334155),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Per-file micro reward: check pops on each completed file.
        if (counter.done > 0)
          TweenAnimationBuilder<double>(
            key: ValueKey(counter.done),
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
            builder: (context, s, c) => Transform.scale(scale: s, child: c),
            child: Container(
              width: 15,
              height: 15,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 11, color: Color(0xFF16A34A)),
            ),
          ),
        const Spacer(),
        // Animated percentage.
        TweenAnimationBuilder<double>(
          tween: Tween(end: pct.toDouble()),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          builder: (context, v, _) => Text(
            '${v.round()}٪',
            style: GoogleFonts.alexandria(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Footer + problem states
// ---------------------------------------------------------------------------

/// Quiet expectation-setting caption at the bottom of the card.
class _FooterStatus extends StatelessWidget {
  const _FooterStatus();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.offline_pin_outlined,
            size: 13, color: Color(0xFF94A3B8)),
        const SizedBox(width: 5),
        Text(
          'مرة واحدة فقط — ثم يعمل التطبيق دون إنترنت',
          style: GoogleFonts.alexandria(
            color: const Color(0xFF94A3B8),
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Error / waiting variant with a full-width retry action wired to the
/// real initialization retry.
class _ProblemBody extends ConsumerWidget {
  const _ProblemBody({
    required this.title,
    required this.support,
    required this.buttonLabel,
  });

  final String title;
  final String support;
  final String buttonLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardHeader(),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            title,
            style: GoogleFonts.alexandria(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          support,
          style: GoogleFonts.alexandria(
            color: _muted,
            fontSize: 12.5,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => ref.read(syncControllerProvider.notifier).retry(),
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52), // full width, >=44dp
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.alexandria(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(buttonLabel),
        ),
      ],
    );
  }
}
