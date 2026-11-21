import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../wspolne/theme/bz_theme.dart';
import '../wspolne/theme/top_fade.dart';
import 'guide.dart';

// Copy drafted here (verify: true).
const guideOpening = 'Otwieram poradnik…';
const guideMissing = 'Tego poradnika nie ma w tej wersji aplikacji.';
const guideUnreadable = 'Nie mogę pokazać tego pliku na tym telefonie.';

/// Widest page image rendered, in pixels (sharp on a phone, bounded memory).
const int _maxRenderWidth = 1440;

/// Rendered pages kept in memory, so scrolling back does not flash.
const int _pageCacheSize = 8;

/// What the reader needs once the file is on disk and its pages are measured.
typedef _Opened = ({String path, List<Size> sizes});

/// Reads one guide page by page (vertical scroll), fully offline. Back and
/// SOS come from `RootOverlay`.
class GuideReaderScreen extends ConsumerStatefulWidget {
  const GuideReaderScreen({super.key, required this.guideId});

  final String guideId;

  @override
  ConsumerState<GuideReaderScreen> createState() => _GuideReaderScreenState();
}

class _GuideReaderScreenState extends ConsumerState<GuideReaderScreen> {
  late final Future<({Guide guide, _Opened? opened})?> _open = _load();
  final _pages = <int, Future<Uint8List>>{};

  /// Null: unknown guide. `opened == null`: the file could not be shown.
  Future<({Guide guide, _Opened? opened})?> _load() async {
    final guides = await ref.read(guidesProvider.future);
    final guide = guides.where((g) => g.id == widget.guideId).firstOrNull;
    if (guide == null) return null;
    try {
      final file = await ref.read(guideFilesProvider).ensureOnDisk(guide);
      final sizes = await ref.read(pdfPagesProvider).pageSizes(file.path);
      return (guide: guide, opened: sizes.isEmpty ? null : (path: file.path, sizes: sizes));
    } on Object catch (e) {
      debugPrint('guide ${guide.id} cannot be opened: $e');
      return (guide: guide, opened: null);
    }
  }

  Future<Uint8List> _page(String path, int index, int width) {
    final cached = _pages.remove(index);
    final page = cached ?? ref.read(pdfPagesProvider).renderPage(path, index, width);
    _pages[index] = page; // most recently used last
    while (_pages.length > _pageCacheSize) {
      _pages.remove(_pages.keys.first);
    }
    return page;
  }

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Scaffold(
      backgroundColor: bz.bg000,
      body: Stack(
        children: [
          SafeArea(
            child: FutureBuilder(
              future: _open,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return _Message(text: guideOpening, busy: true);
                }
                final data = snap.data;
                if (data == null) return const _Message(text: guideMissing);
                final opened = data.opened;
                if (opened == null) return const _Message(text: guideUnreadable);
                return _pagesList(data.guide, opened);
              },
            ),
          ),
          const TopFade(),
        ],
      ),
    );
  }

  Widget _pagesList(Guide guide, _Opened opened) {
    final bz = context.bz;
    final media = MediaQuery.of(context);
    final widthPx = (media.size.width * media.devicePixelRatio).round().clamp(360, _maxRenderWidth);
    final count = opened.sizes.length;
    return ListView.builder(
      key: const Key('guide-pages'),
      padding: EdgeInsets.fromLTRB(0, 96, 0, bz.space6),
      itemCount: count + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: EdgeInsets.fromLTRB(bz.space4, 0, bz.space4, bz.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guide.title, style: bz.title),
                SizedBox(height: bz.space1),
                Text(guideMetaText(guide), style: bz.caption.copyWith(color: bz.ink200)),
              ],
            ),
          );
        }
        final index = i - 1;
        final size = opened.sizes[index];
        return Padding(
          padding: EdgeInsets.only(bottom: bz.space3),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: size.width / size.height,
                // Paper white while the page renders: no dark flash, no jump.
                child: ColoredBox(
                  color: bz.paper,
                  child: FutureBuilder<Uint8List>(
                    future: _page(opened.path, index, widthPx),
                    builder: (context, page) {
                      final bytes = page.data;
                      if (bytes == null) return const SizedBox.expand();
                      return Image.memory(
                        bytes,
                        key: Key('guide-page-$index'),
                        fit: BoxFit.fill,
                        filterQuality: ui.FilterQuality.medium,
                        gaplessPlayback: true,
                        semanticLabel: 'Strona ${index + 1} z $count',
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: bz.space1),
              Text('${index + 1} / $count', style: bz.caption.copyWith(color: bz.ink300)),
            ],
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.busy = false});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(bz.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: bz.chat.copyWith(color: bz.ink200), textAlign: TextAlign.center),
            if (busy) ...[
              SizedBox(height: bz.space4),
              SizedBox(
                width: 160,
                child: LinearProgressIndicator(minHeight: 4, color: bz.signal, backgroundColor: bz.bg300),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
