import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manifest of the bundled guides, written by `tools/build_guides.py`.
const guidesManifestAsset = 'assets/generated/guides.json';

/// Directory of the guide PDFs inside the asset bundle.
const guidesAssetDir = 'assets/generated/';

/// One full source guide (a PDF) the user can read offline.
class Guide {
  const Guide({
    required this.id,
    required this.title,
    required this.publisher,
    required this.pages,
    required this.bytes,
    required this.file,
    this.year,
  });

  factory Guide.fromJson(Map<String, dynamic> j) => Guide(
    id: j['id'] as String,
    title: j['title'] as String,
    publisher: j['publisher'] as String,
    year: j['year'] as String?,
    pages: j['pages'] as int,
    bytes: j['bytes'] as int,
    file: j['file'] as String,
  );

  final String id;
  final String title;
  final String publisher;

  /// Year of publication; null for an undated document.
  final String? year;
  final int pages;
  final int bytes;

  /// File name inside [guidesAssetDir].
  final String file;

  String get assetKey => '$guidesAssetDir$file';
}

/// Guides in reading order. Empty when the build has no manifest.
List<Guide> parseGuides(String manifestJson) {
  final j = jsonDecode(manifestJson) as Map<String, dynamic>;
  return [
    for (final g in (j['guides'] as List)) Guide.fromJson((g as Map).cast<String, dynamic>()),
  ];
}

/// "1 strona", "2 strony", "5 stron", "22 strony", "112 stron".
String pagesText(int n) {
  final mod10 = n % 10, mod100 = n % 100;
  if (n == 1) return '1 strona';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return '$n strony';
  return '$n stron';
}

/// "1,5 MB" (one decimal below 10 MB, whole megabytes above).
String guideSizeText(int bytes) {
  final mb = bytes / (1000 * 1000);
  if (mb >= 10) return '${mb.round()} MB';
  final v = mb < 0.1 ? 0.1 : mb;
  return '${v.toStringAsFixed(1).replaceAll('.', ',')} MB';
}

/// "RCB, MON, MSWiA · 2025 · 54 strony · 1,5 MB".
String guideMetaText(Guide g) =>
    [g.publisher, ?g.year, pagesText(g.pages), guideSizeText(g.bytes)].join(' · ');

final guidesProvider = FutureProvider<List<Guide>>((ref) async {
  try {
    return parseGuides(await rootBundle.loadString(guidesManifestAsset));
  } on Object {
    return const []; // A build without the guides: the screen says so.
  }
});

/// Puts a guide's PDF on disk: the platform PDF renderer reads files, not
/// Flutter assets. Copied once to `<support dir>/poradniki/`.
class GuideFiles {
  GuideFiles({required this.bundle, required this.baseDir});

  final AssetBundle bundle;
  final Future<Directory> Function() baseDir;

  Future<File> ensureOnDisk(Guide guide) async {
    final dir = Directory(p.join((await baseDir()).path, 'poradniki'));
    final file = File(p.join(dir.path, guide.file));
    if (await file.exists() && await file.length() == guide.bytes) return file;
    final data = await bundle.load(guide.assetKey);
    await dir.create(recursive: true);
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    return tmp.rename(file.path);
  }
}

final guideFilesProvider = Provider<GuideFiles>(
  (ref) => GuideFiles(bundle: rootBundle, baseDir: getApplicationSupportDirectory),
);

/// Renders PDF pages to images. Android: the platform `PdfRenderer` behind
/// the `bezpiecznik/pdf` channel (see `MainActivity.kt`). Faked in tests.
abstract class PdfPages {
  /// Size of every page in points, in page order.
  Future<List<Size>> pageSizes(String path);

  /// Page [index] (from 0) as an encoded image [width] pixels wide.
  Future<Uint8List> renderPage(String path, int index, int width);
}

class ChannelPdfPages implements PdfPages {
  const ChannelPdfPages();

  static const _channel = MethodChannel('bezpiecznik/pdf');

  @override
  Future<List<Size>> pageSizes(String path) async {
    final flat = (await _channel.invokeListMethod<int>('pageSizes', {'path': path}))!;
    return [
      for (var i = 0; i + 1 < flat.length; i += 2) Size(flat[i].toDouble(), flat[i + 1].toDouble()),
    ];
  }

  @override
  Future<Uint8List> renderPage(String path, int index, int width) async =>
      (await _channel.invokeMethod<Uint8List>('renderPage', {'path': path, 'index': index, 'width': width}))!;
}

final pdfPagesProvider = Provider<PdfPages>((ref) => const ChannelPdfPages());
