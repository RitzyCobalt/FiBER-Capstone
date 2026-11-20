import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';
import '../models/module_model.dart';
import '../services/data_service.dart';
import '../services/file_download_stub.dart'
    if (dart.library.html) '../services/file_download_web.dart';

class ModuleViewer extends StatefulWidget {
  final Module module;

  const ModuleViewer({super.key, required this.module});

  @override
  State<ModuleViewer> createState() => _ModuleViewerState();
}

class _ModuleViewerState extends State<ModuleViewer> {
  Uint8List? _mediaBytes;
  bool _loadingMedia = false;
  String? _mediaError;

  VideoPlayerController? _videoController;
  File? _tempVideoFile;
  bool _videoReady = false;
  bool _downloadingOriginal = false;

  Future<void> _downloadOriginalFile() async {
    if (_downloadingOriginal) return;
    setState(() => _downloadingOriginal = true);
    try {
      final bytes =
          _mediaBytes ?? await DataService.loadModuleFileBytes(widget.module);
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Original binary file is not available for download.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final fileName = _resolvedOriginalFileName;
      final mime = widget.module.mimeType ?? 'application/octet-stream';
      final savedLocation = await saveOriginalFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: mime,
      );
      if (!mounted) return;
      if (savedLocation == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Downloaded original file: $fileName'
                : defaultTargetPlatform == TargetPlatform.android
                ? 'Saved original file: $fileName'
                : 'Saved original file to: $savedLocation',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not download original file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingOriginal = false);
    }
  }

  String get _ext => DataService.resolveModuleExtension(widget.module);

  bool get _isPicture => DataService.isPictureExtension(_ext);
  bool get _isVideo => DataService.isVideoExtension(_ext);
  bool get _isWordDoc => _ext == 'doc' || _ext == 'docx';
  bool get _isPowerPoint => _ext == 'ppt' || _ext == 'pptx';
  bool get _isPdfDoc => _ext == 'pdf';

  int _currentSlideOrPageIndex = 0;

  String get _formatDisplayLabel => DataService.formatTypeLabel(widget.module);

  Color get _formatBadgeColor {
    if (_isWordDoc) return const Color(0xFF1565C0); // Word Blue
    if (_isPowerPoint) return const Color(0xFFD84315); // PowerPoint Orange-Red
    if (_isPdfDoc) return const Color(0xFFC62828); // PDF Red
    if (_isPicture) return const Color(0xFF00897B);
    if (_isVideo) return Colors.deepPurple;
    return const Color(0xFF0277BD);
  }

  IconData get _formatBadgeIcon {
    if (_isWordDoc) return Icons.article_rounded;
    if (_isPowerPoint) return Icons.slideshow_rounded;
    if (_isPdfDoc) return Icons.picture_as_pdf_rounded;
    if (_isPicture) return Icons.image_outlined;
    if (_isVideo) return Icons.ondemand_video_rounded;
    return Icons.description_outlined;
  }

  String get _resolvedOriginalFileName =>
      DataService.cleanOriginalFileName(widget.module);

  List<String> get _structuredPagesOrSlides {
    final raw = widget.module.content.trim();
    if (raw.isEmpty) return const <String>['No content available.'];
    final parts = raw
        .split(RegExp(r'--- (?:Slide|Page) \d+ ---'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length > 1) return parts;

    // For PowerPoint presentations without explicit slide markers, group paragraphs into presentation slides
    if (_isPowerPoint && raw.length > 500) {
      final lines = raw
          .split(RegExp(r'\n+'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final slides = <String>[];
      final buffer = <String>[];
      int charCount = 0;
      for (final line in lines) {
        if ((buffer.length >= 6 || charCount + line.length > 550) &&
            buffer.isNotEmpty) {
          slides.add(buffer.join('\n'));
          buffer.clear();
          charCount = 0;
        }
        buffer.add(line);
        charCount += line.length;
      }
      if (buffer.isNotEmpty) {
        slides.add(buffer.join('\n'));
      }
      if (slides.isNotEmpty) return slides;
    }

    // For Word or PDF documents without explicit page markers, split long text into readable document pages
    if ((_isWordDoc || _isPdfDoc) && raw.length > 1800) {
      final paragraphs = raw
          .split(RegExp(r'\n\s*\n|\n'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      final pages = <String>[];
      final buffer = StringBuffer();
      for (final p in paragraphs) {
        if (buffer.length + p.length > 1600 && buffer.isNotEmpty) {
          pages.add(buffer.toString().trim());
          buffer.clear();
        }
        buffer.writeln(p);
        buffer.writeln();
      }
      if (buffer.isNotEmpty) {
        pages.add(buffer.toString().trim());
      }
      if (pages.isNotEmpty) return pages;
    }

    return <String>[raw];
  }

  @override
  void initState() {
    super.initState();
    DataService.beginLearningActivity('module_viewer');
    if (_isPdfDoc) {
      _loadPdfBytes();
    } else if (_isPicture) {
      _loadPictureBytes();
    } else if (_isVideo) {
      _initVideoPlayback();
    }
  }

  @override
  void dispose() {
    DataService.endLearningActivity('module_viewer');
    _videoController?.dispose();
    if (_tempVideoFile != null) {
      try {
        _tempVideoFile!.deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _loadPictureBytes() async {
    setState(() {
      _loadingMedia = true;
      _mediaError = null;
    });
    try {
      final bytes = await DataService.loadModuleFileBytes(widget.module);
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _mediaError = 'Could not load image data from Firestore.';
          _loadingMedia = false;
        });
        return;
      }
      setState(() {
        _mediaBytes = bytes;
        _loadingMedia = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mediaError = 'Failed to reconstruct picture: $e';
        _loadingMedia = false;
      });
    }
  }

  Future<void> _loadPdfBytes() async {
    setState(() {
      _loadingMedia = true;
      _mediaError = null;
    });
    try {
      final bytes = await DataService.loadModuleFileBytes(widget.module);
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _mediaError = 'The original PDF could not be loaded.';
          _loadingMedia = false;
        });
        return;
      }
      setState(() {
        _mediaBytes = bytes;
        _loadingMedia = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mediaError = 'Could not load the original PDF: $e';
        _loadingMedia = false;
      });
    }
  }

  Future<void> _initVideoPlayback() async {
    setState(() {
      _loadingMedia = true;
      _mediaError = null;
    });
    try {
      final resolvedUrl = await DataService.resolveModuleFileUrl(widget.module);
      if (!mounted) return;
      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        setState(() {
          _mediaError = 'Video source URL was not found.';
          _loadingMedia = false;
        });
        return;
      }

      VideoPlayerController controller;
      if (resolvedUrl.startsWith('http://') ||
          resolvedUrl.startsWith('https://')) {
        controller = VideoPlayerController.networkUrl(Uri.parse(resolvedUrl));
      } else {
        // Reassemble small fallback video from Firestore chunks / base64
        final bytes = await DataService.loadModuleFileBytes(widget.module);
        if (!mounted) return;
        if (bytes == null || bytes.isEmpty) {
          setState(() {
            _mediaError = 'Could not reconstruct fallback video bytes.';
            _loadingMedia = false;
          });
          return;
        }
        final mime = _ext == 'webm' ? 'video/webm' : 'video/mp4';
        if (kIsWeb) {
          final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
          controller = VideoPlayerController.networkUrl(Uri.parse(dataUri));
        } else {
          final tempDir = Directory.systemTemp;
          final tempFile = File(
            '${tempDir.path}/fiber_vid_${widget.module.id ?? DateTime.now().millisecondsSinceEpoch}.$_ext',
          );
          await tempFile.writeAsBytes(bytes, flush: true);
          _tempVideoFile = tempFile;
          controller = VideoPlayerController.file(tempFile);
        }
      }

      _videoController = controller;
      await controller.initialize();
      controller.addListener(() {
        if (mounted) setState(() {});
      });

      if (!mounted) return;
      setState(() {
        _videoReady = true;
        _loadingMedia = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mediaError = 'Video playback error: $e';
        _loadingMedia = false;
      });
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  void _openFullScreenImageZoom(Uint8List bytes) {
    final transController = TransformationController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: transController,
                  minScale: 0.8,
                  maxScale: 5.0,
                  panEnabled: true,
                  scaleEnabled: true,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  children: [
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white24,
                      ),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Reset Zoom',
                      onPressed: () =>
                          transController.value = Matrix4.identity(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white24,
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Positioned(
                bottom: 18,
                left: 0,
                right: 0,
                child: Text(
                  'Pinch with two fingers to zoom • Drag to pan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  Widget _buildMediaSection() {
    if (_loadingMedia) {
      return Container(
        height: 240,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.lightBlue.shade100),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                _isPicture
                    ? 'Reassembling high-resolution image from Firestore...'
                    : _isPdfDoc
                    ? 'Loading original PDF...'
                    : 'Loading video stream...',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0B3C5D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_mediaError != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 36),
            const SizedBox(height: 8),
            Text(
              _mediaError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade900, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isPdfDoc
                  ? _loadPdfBytes
                  : _isPicture
                  ? _loadPictureBytes
                  : _initVideoPlayback,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(
                _isPdfDoc ? 'Retry Loading PDF' : 'Retry Loading Media',
              ),
            ),
          ],
        ),
      );
    }

    if (_isPicture && _mediaBytes != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.lightBlue.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _openFullScreenImageZoom(_mediaBytes!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _mediaBytes!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openFullScreenImageZoom(_mediaBytes!),
              icon: const Icon(Icons.zoom_out_map_rounded, size: 16),
              label: const Text('Tap to Open Full-Screen Zoom Viewer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0277BD),
                side: BorderSide(color: Colors.lightBlue.shade200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isPdfDoc && _mediaBytes != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.lightBlue.shade100),
        ),
        clipBehavior: Clip.antiAlias,
        child: SfPdfViewer.memory(
          _mediaBytes!,
          pageLayoutMode: PdfPageLayoutMode.continuous,
          scrollDirection: PdfScrollDirection.vertical,
          onDocumentLoadFailed: (details) {
            if (!mounted) return;
            setState(() {
              _mediaError = 'Could not open this PDF: ${details.description}';
              _loadingMedia = false;
            });
          },
        ),
      );
    }

    if (_isVideo && _videoReady && _videoController != null) {
      final vc = _videoController!;
      final pos = vc.value.position;
      final dur = vc.value.duration;
      final maxMs = dur.inMilliseconds > 0
          ? dur.inMilliseconds.toDouble()
          : 1.0;
      final curMs = pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
      final aspect = vc.value.aspectRatio > 0 ? vc.value.aspectRatio : (16 / 9);

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF041C32),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(aspectRatio: aspect, child: VideoPlayer(vc)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    vc.value.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: Colors.cyanAccent,
                    size: 34,
                  ),
                  onPressed: () {
                    setState(() {
                      vc.value.isPlaying ? vc.pause() : vc.play();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.replay_10_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    vc.seekTo(pos - const Duration(seconds: 10));
                  },
                ),
                Expanded(
                  child: Slider(
                    value: curMs,
                    min: 0.0,
                    max: maxMs,
                    activeColor: Colors.cyanAccent,
                    inactiveColor: Colors.white24,
                    onChanged: (val) {
                      vc.seekTo(Duration(milliseconds: val.round()));
                    },
                  ),
                ),
                Text(
                  '${_formatDuration(pos)} / ${_formatDuration(dur)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPowerPointSlideViewer(
    List<String> pages,
    int safeIdx,
    String currentPageText,
    Color badgeColor,
  ) {
    final lines = currentPageText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final slideTitle = lines.isNotEmpty
        ? lines.first
        : '${widget.module.title} — Slide ${safeIdx + 1}';
    final slidePoints = lines.length > 1 ? lines.sublist(1) : const <String>[];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B120C), Color(0xFF4E1F14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'POWERPOINT SLIDE ${safeIdx + 1} OF ${pages.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    onPressed: safeIdx > 0
                        ? () => setState(() => _currentSlideOrPageIndex--)
                        : null,
                  ),
                  Text(
                    '${safeIdx + 1} / ${pages.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    onPressed: safeIdx + 1 < pages.length
                        ? () => setState(() => _currentSlideOrPageIndex++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 240),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border(top: BorderSide(color: badgeColor, width: 6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  slideTitle,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B3C5D),
                  ),
                ),
                if (slidePoints.isNotEmpty) ...[
                  const Divider(height: 22),
                  ...slidePoints.map(
                    (pt) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SelectableText(
                        '• $pt',
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.55,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSpecificDocumentViewer() {
    final pages = _structuredPagesOrSlides;
    final safeIdx = _currentSlideOrPageIndex.clamp(0, pages.length - 1);
    final currentPageText = pages[safeIdx];
    final badgeColor = _formatBadgeColor;

    if (_isPowerPoint) {
      return _buildPowerPointSlideViewer(
        pages,
        safeIdx,
        currentPageText,
        badgeColor,
      );
    }

    final viewerTitle = _isPdfDoc
        ? 'PDF DOCUMENT VIEWER • PAGE ${safeIdx + 1} OF ${pages.length}'
        : _isWordDoc
        ? 'WORD DOCUMENT VIEWER • PAGE ${safeIdx + 1} OF ${pages.length}'
        : 'DOCUMENT VIEWER';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.35), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_formatBadgeIcon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      viewerTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (pages.length > 1)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        onPressed: safeIdx > 0
                            ? () => setState(() => _currentSlideOrPageIndex--)
                            : null,
                      ),
                      Text(
                        'Page ${safeIdx + 1} / ${pages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        onPressed: safeIdx + 1 < pages.length
                            ? () => setState(() => _currentSlideOrPageIndex++)
                            : null,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            constraints: const BoxConstraints(minHeight: 340),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              currentPageText,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.65,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileDetailLine(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        softWrap: true,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: Colors.black87,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3C5D),
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileDetailsCard({
    required String fileName,
    required String extUpper,
    required String sizeLabel,
    required String classLabel,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withOpacity(0.35), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: badgeColor.withOpacity(0.12),
                child: Icon(_formatBadgeIcon, color: badgeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFileDetailLine(
                      'File Name',
                      fileName,
                      valueColor: const Color(0xFF0B3C5D),
                    ),
                    _buildFileDetailLine(
                      'File Type',
                      _formatDisplayLabel,
                      valueColor: badgeColor,
                    ),
                    _buildFileDetailLine('File Size', sizeLabel),
                    _buildFileDetailLine('Class', classLabel),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _downloadingOriginal ? null : _downloadOriginalFile,
              icon: _downloadingOriginal
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 16),
              label: Text(
                extUpper.isNotEmpty
                    ? 'Download Original .$extUpper'
                    : 'Download Original',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: badgeColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final fileName = _resolvedOriginalFileName;
    final extUpper = _ext.toUpperCase();
    final sizeLabel = DataService.formatBytesLabel(module.fileSize);
    final classLabel = DataService.resolveClassDisplayName(module.classCode);
    final badgeColor = _formatBadgeColor;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              module.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Color(0xFF0B3C5D),
              ),
            ),
            Text(
              _formatDisplayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _downloadingOriginal ? null : _downloadOriginalFile,
            tooltip: 'Download Original File ($fileName)',
            icon: _downloadingOriginal
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.download_rounded, color: badgeColor),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _isPdfDoc
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFileDetailsCard(
                          fileName: fileName,
                          extUpper: extUpper,
                          sizeLabel: sizeLabel,
                          classLabel: classLabel,
                          badgeColor: badgeColor,
                        ),
                        Expanded(child: _buildMediaSection()),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFileDetailsCard(
                            fileName: fileName,
                            extUpper: extUpper,
                            sizeLabel: sizeLabel,
                            classLabel: classLabel,
                            badgeColor: badgeColor,
                          ),
                          if (_isPicture || _isVideo)
                            _buildMediaSection()
                          else
                            _buildFormatSpecificDocumentViewer(),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
