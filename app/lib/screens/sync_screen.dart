import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../providers/sync_controller.dart';
import '../utils/format.dart';

// Splash palette (local on purpose: this screen must look right before
// anything else loads).
const _bgTop = Color(0xFF1E3A8A); // deep blue
const _bgRoyal = Color(0xFF2B4FD8); // royal blue
const _panelInk = Color(0xFF0F172A); // dark text on the pale panel
const _panelMuted = Color(0xFF64748B);
const _panelBlue = Color(0xFF2563EB);

/// First-launch "Preparing Content" screen.
///
/// Two-zone composition: a brand zone (gradient, glass icon, title) over a
/// pale bottom status panel bound to the real sync state machine. Navigates
/// to Home after a brief success state once preparation completes.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen>
    with TickerProviderStateMixin {
  bool _wifiDialogOpen = false;
  bool _navigated = false;

  // One-shot staggered intro: icon -> title -> panel.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  late final Animation<double> _iconIn = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.45, curve: Curves.easeInOut),
  );
  late final Animation<double> _titleIn = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.20, 0.65, curve: Curves.easeInOut),
  );
  late final Animation<double> _panelIn = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.40, 1.0, curve: Curves.easeInOut),
  );

  // Repeating driver for the subtle page-flip on the icon.
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
      if (next is SyncDone && !_navigated) {
        _navigated = true;
        // Brief success state ("اكتمل تجهيز الأرشيف") before moving on.
        Future.delayed(const Duration(milliseconds: 900), () {
          if (context.mounted) context.go('/');
        });
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
            colors: [_bgTop, _bgRoyal],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Soft radial "mesh" light behind the brand zone.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.55),
                  radius: 1.1,
                  colors: [Color(0x2E93C5FD), Color(0x00000000)],
                ),
              ),
            ),
            // Faint academic document-line pattern (brand zone only).
            const CustomPaint(painter: _DocLinesPainter()),
            Column(
              children: [
                // ------------------- brand zone (~58%) -------------------
                Expanded(
                  flex: 11,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Staggered(
                            animation: _iconIn,
                            child: _GlassBookIcon(loop: _loop),
                          ),
                          const SizedBox(height: 26),
                          _Staggered(
                            animation: _titleIn,
                            child: Column(
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    AppConfig.appTitle,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.alexandria(
                                      color: Colors.white,
                                      fontSize: 30,
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
                                    color:
                                        Colors.white.withValues(alpha: 0.85),
                                    fontSize: 14.5,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // -------------- download-status panel (~42%) --------------
                Expanded(
                  flex: 8,
                  child: _Staggered(
                    animation: _panelIn,
                    fromOffset: const Offset(0, 0.10),
                    child: _StatusPanel(state: state),
                  ),
                ),
              ],
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

/// The book icon inside a premium glass circle: translucent blue surface,
/// hairline border, inner top highlight, restrained outer glow — plus the
/// existing subtle right-to-left page flip.
class _GlassBookIcon extends StatelessWidget {
  const _GlassBookIcon({required this.loop});
  final AnimationController loop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Inner highlight: brighter at the top, fading down.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF93C5FD).withValues(alpha: 0.25),
            blurRadius: 38,
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
            Positioned(
              left: 48,
              top: 20,
              child: AnimatedBuilder(
                animation: loop,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(loop.value);
                  final fade = t < 0.82 ? 1.0 : (1 - (t - 0.82) / 0.18);
                  return Opacity(
                    opacity: 0.85 * fade.clamp(0.0, 1.0),
                    child: Transform(
                      alignment: Alignment.centerLeft,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..rotateY(-math.pi * t),
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

/// Bottom floating panel: pale surface, 30dp rounded top corners, dark
/// readable text. Renders loading / success / problem variants from the
/// real sync state.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xF7F8FAFC), // near-white with faint translucency
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 26,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          // Never clips under large font scaling; scrolls only if needed.
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: _body(),
        ),
      ),
    );
  }

  Widget _body() {
    switch (state) {
      case SyncInitial():
      case SyncChecking():
      case SyncNeedWifiConfirm():
        return const _LoadingBody(progress: null);

      case SyncDownloading(
          :final filesDone,
          :final filesTotal,
          :final progress
        ):
        return _LoadingBody(
          progress: progress,
          counter: (done: filesDone, total: filesTotal),
        );

      case SyncDone():
        return const _LoadingBody(progress: 1, success: true);

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

/// Small blue section label shared by all panel variants.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'تجهيز مكتبتك',
      style: GoogleFonts.alexandria(
        color: _panelBlue,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// Loading / success content of the panel.
class _LoadingBody extends StatelessWidget {
  const _LoadingBody({
    required this.progress,
    this.counter,
    this.success = false,
  });

  /// null = indeterminate; 0..1 = real progress (already NaN/zero-safe
  /// upstream: SyncDownloading.progress clamps and guards bytesTotal <= 0).
  final double? progress;
  final ({int done, int total})? counter;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final pct = ((progress ?? 0) * 100).round().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(),
        const SizedBox(height: 8),
        Text(
          success ? 'اكتمل تجهيز الأرشيف' : 'جارٍ تجهيز الأرشيف…',
          style: GoogleFonts.alexandria(
            color: _panelInk,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'سيصبح المحتوى متاحًا دون اتصال بالإنترنت',
          style: GoogleFonts.alexandria(
            color: _panelMuted,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),
        Semantics(
          label: 'نسبة التقدم',
          value: progress == null ? null : '$pct٪',
          child: _ProgressBar(progress: progress, success: success),
        ),
        if (counter != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${counter!.done} من ${counter!.total} ملفًا',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.alexandria(
                    color: const Color(0xFF334155),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$pct٪',
                style: GoogleFonts.alexandria(
                  color: _panelInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Prominent rounded bar. Determinate progress animates smoothly between
/// values; indeterminate shows a gentle sweep. RTL: fill grows from the right.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, this.success = false});

  final double? progress;
  final bool success;

  @override
  Widget build(BuildContext context) {
    const trackColor = Color(0xFFE2E8F0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 10,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            if (progress == null) {
              return const _IndeterminateSweep(trackColor: trackColor);
            }
            final frac = progress!.clamp(0.0, 1.0);
            return Stack(
              children: [
                Container(color: trackColor),
                AnimatedPositioned(
                  // Smooth movement between real progress updates.
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: math.max(w * frac, frac > 0 ? 10.0 : 0.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: success
                            ? const [Color(0xFF16A34A), Color(0xFF22C55E)]
                            : const [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                      ),
                    ),
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
                        colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
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

/// Error / waiting variant of the panel with a full-width primary action
/// that triggers the real initialization retry.
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
        const _SectionLabel(),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(
            title,
            style: GoogleFonts.alexandria(
              color: _panelInk,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          support,
          style: GoogleFonts.alexandria(
            color: _panelMuted,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => ref.read(syncControllerProvider.notifier).retry(),
          style: FilledButton.styleFrom(
            backgroundColor: _panelBlue,
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

/// Static, very faint "document line" clusters in the brand zone.
/// Painted once, never repaints.
class _DocLinesPainter extends CustomPainter {
  const _DocLinesPainter();

  void _docLines(Canvas canvas, Offset origin, double width, Paint paint) {
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
    // Brand zone only (upper ~58%).
    _docLines(canvas, Offset(w * 0.70, h * 0.08), w * 0.20, paint);
    _docLines(canvas, Offset(w * 0.08, h * 0.17), w * 0.16, paint);
    _docLines(canvas, Offset(w * 0.76, h * 0.40), w * 0.16, paint);
    _docLines(canvas, Offset(w * 0.10, h * 0.48), w * 0.18, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
