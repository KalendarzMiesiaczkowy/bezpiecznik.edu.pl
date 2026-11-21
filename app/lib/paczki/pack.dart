/// Data packs downloaded after install (the two files too heavy for the APK).
///
/// Spec: `bezpiecznik/05-technologia/dystrybucja.md` (static HTTPS server
/// with packs) and `ekran-0-pierwsze-uruchomienie.md` (step `packages`).
library;

/// One downloadable file.
class AssetPack {
  const AssetPack({
    required this.id,
    required this.label,
    required this.url,
    required this.fileName,
    required this.bytes,
    this.sha256,
  });

  final String id;

  /// Polish name shown in the progress line, in the accusative ("Pobieram …").
  final String label;
  final Uri url;

  /// File name inside the packs directory.
  final String fileName;

  /// Exact size of the file. A download of another size is rejected.
  final int bytes;

  /// Lowercase hex SHA-256 of the file; checked after the download when set.
  final String? sha256;
}

const String mapPackId = 'map-zachodniopomorskie';
const String modelPackId = 'model-gemma-4-e2b';

/// File name of the Gemma 4 E2B LiteRT-LM model (also read by the edge engine).
const String modelPackFileName = 'gemma-4-E2B-it.litertlm';

/// File name of the detailed map of the Zachodniopomorskie voivodeship.
const String mapPackFileName = 'zachodniopomorskie.mbtiles';

// Build-time overrides (`--dart-define=...`), e.g. a local server through
// `adb reverse` while testing.
const String _mapPackUrl = String.fromEnvironment(
  'MAP_PACK_URL',
  defaultValue: 'https://bezpiecznik.edu.pl/paczki/$mapPackFileName',
);
const int _mapPackBytes = int.fromEnvironment('MAP_PACK_BYTES', defaultValue: 0);
const String _mapPackSha256 = String.fromEnvironment('MAP_PACK_SHA256');
const String _modelPackUrl = String.fromEnvironment(
  'MODEL_PACK_URL',
  defaultValue:
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/$modelPackFileName',
);

/// Size of the model file on Hugging Face (checked 2026-11-21).
const int modelPackBytes = 2588147712;

/// Packs this build downloads, most important first. The map pack is listed
/// only when the build knows its size (`MAP_PACK_BYTES`), because a pack of
/// an unknown size cannot be verified.
List<AssetPack> defaultPackCatalog() => [
  if (_mapPackBytes > 0)
    AssetPack(
      id: mapPackId,
      label: 'mapę woj. zachodniopomorskiego',
      url: Uri.parse(_mapPackUrl),
      fileName: mapPackFileName,
      bytes: _mapPackBytes,
      sha256: _mapPackSha256.isEmpty ? null : _mapPackSha256,
    ),
  AssetPack(
    id: modelPackId,
    label: 'model AI',
    url: Uri.parse(_modelPackUrl),
    fileName: modelPackFileName,
    bytes: modelPackBytes,
  ),
];

/// "101 MB", "2,6 GB" (Polish decimal comma).
String formatPackSize(int bytes) {
  const mb = 1000 * 1000;
  const gb = 1000 * mb;
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(1).replaceAll('.', ',')} GB';
  }
  final v = (bytes / mb).round();
  return '${v < 1 ? 1 : v} MB';
}
