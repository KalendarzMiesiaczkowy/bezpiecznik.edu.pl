import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'pack.dart';

/// Sent with every request so the file host can tell the app apart.
const String packUserAgent = 'Bezpiecznik/1.0 (pl.edu.bezpiecznik.bezpiecznik)';

/// Bytes received so far and the size of the whole file.
typedef PackProgress = void Function(int received, int total);

class PackDownloadException implements Exception {
  const PackDownloadException(this.message, {this.noSpace = false, this.corrupt = false});

  final String message;

  /// The device ran out of storage.
  final bool noSpace;

  /// The finished file did not match the expected size or checksum and was
  /// removed, so the next attempt starts from zero.
  final bool corrupt;

  @override
  String toString() => 'PackDownloadException: $message';
}

/// Thrown when the download was stopped through a [PackCancelToken].
class PackDownloadCancelled implements Exception {
  const PackDownloadCancelled();
}

class PackCancelToken {
  bool _cancelled = false;

  bool get cancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Downloads one [AssetPack] with resume.
///
/// Bytes go to `<file>.part`; the file gets its final name only after the
/// size (and the checksum, when the pack has one) is verified, so a file under
/// its final name is always complete.
class PackDownloader {
  PackDownloader({http.Client? client, this.stallTimeout = const Duration(seconds: 30)})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Longest wait for the response or for the next bytes of the body.
  final Duration stallTimeout;

  static File fileOf(AssetPack pack, Directory dir) => File(p.join(dir.path, pack.fileName));

  static File _partOf(AssetPack pack, Directory dir) => File('${fileOf(pack, dir).path}.part');

  /// True when the verified file is already in [dir].
  static Future<bool> isComplete(AssetPack pack, Directory dir) async {
    final file = fileOf(pack, dir);
    return await file.exists() && await file.length() == pack.bytes;
  }

  /// Bytes already on disk (finished file or partial download).
  static Future<int> bytesOnDisk(AssetPack pack, Directory dir) async {
    if (await isComplete(pack, dir)) return pack.bytes;
    final part = _partOf(pack, dir);
    return await part.exists() ? await part.length() : 0;
  }

  /// Downloads [pack] into [dir], continuing a partial file when there is one.
  /// [onVerify] fires when the bytes are in and the checksum is being computed.
  Future<File> download(
    AssetPack pack,
    Directory dir, {
    PackProgress? onProgress,
    void Function()? onVerify,
    PackCancelToken? cancel,
  }) async {
    final target = fileOf(pack, dir);
    if (await isComplete(pack, dir)) {
      onProgress?.call(pack.bytes, pack.bytes);
      return target;
    }
    try {
      await dir.create(recursive: true);
      if (await target.exists()) await target.delete(); // wrong size: stale
      final part = _partOf(pack, dir);
      var have = await part.exists() ? await part.length() : 0;
      if (have > pack.bytes) {
        await part.delete();
        have = 0;
      }
      if (have < pack.bytes) {
        await _fetch(pack, part, have, onProgress, cancel);
      }
      if (cancel?.cancelled ?? false) throw const PackDownloadCancelled();

      final got = await part.length();
      if (got != pack.bytes) {
        await part.delete();
        throw PackDownloadException(
          'Plik ma $got B, oczekiwano ${pack.bytes} B.',
          corrupt: true,
        );
      }
      final expected = pack.sha256;
      if (expected != null) {
        onVerify?.call();
        final actual = await sha256OfFile(part.path);
        if (actual != expected.toLowerCase()) {
          await part.delete();
          throw const PackDownloadException('Suma kontrolna się nie zgadza.', corrupt: true);
        }
      }
      await part.rename(target.path);
      onProgress?.call(pack.bytes, pack.bytes);
      return target;
    } on PackDownloadException {
      rethrow;
    } on PackDownloadCancelled {
      rethrow;
    } on FileSystemException catch (e) {
      final noSpace = e.osError?.errorCode == 28; // ENOSPC
      throw PackDownloadException(e.message, noSpace: noSpace);
    } on Object catch (e) {
      // Socket, TLS, DNS, timeout: the partial file stays for the next try.
      throw PackDownloadException('$e');
    }
  }

  Future<void> _fetch(
    AssetPack pack,
    File part,
    int have,
    PackProgress? onProgress,
    PackCancelToken? cancel,
  ) async {
    final request = http.Request('GET', pack.url)..headers['User-Agent'] = packUserAgent;
    if (have > 0) request.headers['Range'] = 'bytes=$have-';
    final response = await _client.send(request).timeout(stallTimeout);

    var received = have;
    FileMode mode;
    switch (response.statusCode) {
      case 206:
        mode = FileMode.writeOnlyAppend;
      case 200:
        // No Range support (or a fresh download): start over.
        mode = FileMode.writeOnly;
        received = 0;
      case 416:
        // The partial file no longer matches the server's file.
        await response.stream.drain<void>();
        if (await part.exists()) await part.delete();
        throw const PackDownloadException('Serwer odrzucił wznowienie pobierania.');
      default:
        await response.stream.drain<void>();
        throw PackDownloadException('Serwer odpowiedział kodem ${response.statusCode}.');
    }

    final out = await part.open(mode: mode);
    try {
      // A connection that goes silent must fail (and be resumed), not hang.
      await for (final chunk in response.stream.timeout(stallTimeout)) {
        if (cancel?.cancelled ?? false) throw const PackDownloadCancelled();
        await out.writeFrom(chunk);
        received += chunk.length;
        onProgress?.call(received, pack.bytes);
      }
    } finally {
      await out.flush();
      await out.close();
    }
  }

  void close() => _client.close();
}

/// Lowercase hex SHA-256 of the file at [path], computed off the UI isolate.
Future<String> sha256OfFile(String path) =>
    Isolate.run(() async => (await sha256.bind(File(path).openRead()).first).toString());
