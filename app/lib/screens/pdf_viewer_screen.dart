import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/ui_helpers.dart';

/// Local PDF viewer: pinch-zoom, page navigation, share, fullscreen.
/// (v1-verbatim restore — the version verified working on-device.)
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.filePath, required this.title});
  final String filePath;
  final String title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  PdfControllerPinch? _controller;
  bool _fileMissing = false;
  bool _loadError = false;
  int _current = 1;
  int _total = 0;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    if (File(widget.filePath).existsSync()) {
      _controller = PdfControllerPinch(
        document: PdfDocument.openFile(widget.filePath),
      );
    } else {
      _fileMissing = true;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(widget.filePath)], subject: widget.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fileMissing || _loadError) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const CenteredHint(
          icon: Icons.picture_as_pdf_outlined,
          text: 'تعذّر فتح الملف.\nقد لا يكون قد اكتمل تنزيله بعد.',
        ),
      );
    }

    // Document backdrop adapts to theme; PDF pages themselves stay as-is.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final backdrop =
        dark ? const Color(0xFF0B1220) : const Color(0xFFECEFF4);
    return Scaffold(
      backgroundColor: backdrop,
      appBar: _fullscreen
          ? null
          : AppBar(
              title: Text(widget.title, style: const TextStyle(fontSize: 16)),
              actions: [
                IconButton(
                  tooltip: 'مشاركة',
                  icon: const Icon(Icons.share_rounded),
                  onPressed: _share,
                ),
                IconButton(
                  tooltip: 'ملء الشاشة',
                  icon: const Icon(Icons.fullscreen_rounded),
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: _fullscreen ? _toggleFullscreen : null,
            child: PdfViewPinch(
              controller: _controller!,
              padding: 6,
              backgroundDecoration: BoxDecoration(color: backdrop),
              onDocumentLoaded: (doc) =>
                  setState(() => _total = doc.pagesCount),
              onPageChanged: (page) => setState(() => _current = page),
              onDocumentError: (_) => setState(() => _loadError = true),
            ),
          ),
          if (_fullscreen)
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: _RoundIcon(
                  icon: Icons.fullscreen_exit_rounded,
                  onTap: _toggleFullscreen,
                ),
              ),
            ),
          // Compact floating page pill (replaces the old full-width bar).
          if (!_fullscreen)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: 16 + MediaQuery.paddingOf(context).bottom,
                ),
                child: _pagePill(context),
              ),
            ),
        ],
      ),
    );
  }

  /// Floating pill: prev · "صفحة X من Y" · next. Same tap behavior as the
  /// old bar, just compact and recessive. Built only from widgets already
  /// proven in this app's release builds.
  Widget _pagePill(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      elevation: 6,
      shadowColor: const Color(0x59000000),
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              color: scheme.onPrimary,
              disabledColor: scheme.onPrimary.withValues(alpha: 0.35),
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'السابق',
              onPressed: _current > 1
                  ? () => _controller?.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _total == 0 ? '…' : 'صفحة $_current من $_total',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              color: scheme.onPrimary,
              disabledColor: scheme.onPrimary.withValues(alpha: 0.35),
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'التالي',
              onPressed: (_total == 0 || _current < _total)
                  ? () => _controller?.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
