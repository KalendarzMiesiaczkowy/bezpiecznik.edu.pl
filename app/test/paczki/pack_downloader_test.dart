import 'dart:async';
import 'dart:io';

import 'package:bezpiecznik/paczki/pack.dart';
import 'package:bezpiecznik/paczki/pack_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

/// Serves [body] like a static file server: honours `Range: bytes=N-`.
MockClient _server(
  List<int> body, {
  List<http.BaseRequest>? seen,
  bool ignoreRange = false,
  int? failAfter,
}) {
  var calls = 0;
  return MockClient.streaming((request, _) async {
    seen?.add(request);
    calls++;
    final range = request.headers['range'];
    var from = 0;
    if (range != null && !ignoreRange) {
      from = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      if (from >= body.length) {
        return http.StreamedResponse(const Stream.empty(), 416);
      }
    }
    final rest = body.sublist(from);
    Stream<List<int>> chunks() async* {
      for (var i = 0; i < rest.length; i += 1000) {
        if (failAfter != null && calls == 1 && i >= failAfter) {
          throw const SocketException('connection lost');
        }
        yield rest.sublist(i, i + 1000 > rest.length ? rest.length : i + 1000);
      }
    }

    return http.StreamedResponse(
      chunks(),
      from > 0 ? 206 : 200,
      contentLength: rest.length,
    );
  });
}

void main() {
  late Directory dir;
  final body = List<int>.generate(25 * 1000 + 123, (i) => i % 251);
  AssetPack pack({int? bytes, String? sha}) => AssetPack(
    id: 'test',
    label: 'Test',
    url: Uri.parse('https://example.test/test.bin'),
    fileName: 'test.bin',
    bytes: bytes ?? body.length,
    sha256: sha,
  );

  setUp(() async {
    final root = Directory(p.join(Directory.current.path, '.dart_tool', 'test_tmp'));
    await root.create(recursive: true);
    dir = await root.createTemp('packs_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('downloads the whole file and reports progress', () async {
    final progress = <int>[];
    final file = await PackDownloader(client: _server(body)).download(
      pack(),
      dir,
      onProgress: (received, total) {
        expect(total, body.length);
        progress.add(received);
      },
    );
    expect(await file.readAsBytes(), body);
    expect(p.basename(file.path), 'test.bin');
    expect(progress.last, body.length);
    expect(File('${file.path}.part').existsSync(), isFalse);
  });

  test('resumes from the partial file with a Range request', () async {
    await File(p.join(dir.path, 'test.bin.part')).writeAsBytes(body.sublist(0, 7000));
    final seen = <http.BaseRequest>[];
    final file = await PackDownloader(client: _server(body, seen: seen)).download(pack(), dir);
    expect(seen.single.headers['range'], 'bytes=7000-');
    expect(await file.readAsBytes(), body);
  });

  test('a server that ignores Range restarts from zero instead of corrupting the file', () async {
    await File(p.join(dir.path, 'test.bin.part')).writeAsBytes(body.sublist(0, 7000));
    final file = await PackDownloader(client: _server(body, ignoreRange: true)).download(pack(), dir);
    expect(await file.readAsBytes(), body);
  });

  test('a broken connection keeps the partial file for the next attempt', () async {
    final client = _server(body, failAfter: 5000);
    final dl = PackDownloader(client: client);
    await expectLater(dl.download(pack(), dir), throwsA(isA<PackDownloadException>()));
    final part = File(p.join(dir.path, 'test.bin.part'));
    expect(part.existsSync(), isTrue);
    expect(part.lengthSync(), greaterThan(0));
    final file = await dl.download(pack(), dir);
    expect(await file.readAsBytes(), body);
  });

  test('an already complete file is not downloaded again', () async {
    await File(p.join(dir.path, 'test.bin')).writeAsBytes(body);
    final seen = <http.BaseRequest>[];
    await PackDownloader(client: _server(body, seen: seen)).download(pack(), dir);
    expect(seen, isEmpty);
    expect(await PackDownloader.isComplete(pack(), dir), isTrue);
  });

  test('a file of the wrong size is not complete', () async {
    await File(p.join(dir.path, 'test.bin')).writeAsBytes(body.sublist(0, 10));
    expect(await PackDownloader.isComplete(pack(), dir), isFalse);
  });

  test('a size mismatch is rejected and the bad file is removed', () async {
    final dl = PackDownloader(client: _server(body));
    await expectLater(
      dl.download(pack(bytes: body.length + 5), dir),
      throwsA(isA<PackDownloadException>().having((e) => e.corrupt, 'corrupt', isTrue)),
    );
    expect(File(p.join(dir.path, 'test.bin')).existsSync(), isFalse);
    expect(File(p.join(dir.path, 'test.bin.part')).existsSync(), isFalse);
  });

  test('a checksum mismatch is rejected and the bad file is removed', () async {
    final dl = PackDownloader(client: _server(body));
    await expectLater(
      dl.download(pack(sha: 'deadbeef'), dir),
      throwsA(isA<PackDownloadException>().having((e) => e.corrupt, 'corrupt', isTrue)),
    );
    expect(File(p.join(dir.path, 'test.bin')).existsSync(), isFalse);
    expect(File(p.join(dir.path, 'test.bin.part')).existsSync(), isFalse);
  });

  test('a matching checksum is accepted', () async {
    final sha = sha256.convert(body).toString();
    final file = await PackDownloader(client: _server(body)).download(pack(sha: sha), dir);
    expect(await file.readAsBytes(), body);
  });

  test('an HTTP error is reported', () async {
    final client = MockClient.streaming(
      (_, _) async => http.StreamedResponse(const Stream.empty(), 404),
    );
    await expectLater(
      PackDownloader(client: client).download(pack(), dir),
      throwsA(isA<PackDownloadException>().having((e) => e.message, 'message', contains('404'))),
    );
  });

  test('a connection that goes silent fails instead of hanging, and resumes later', () async {
    var stall = true;
    final client = MockClient.streaming((request, _) async {
      final from = int.parse(
        RegExp(r'bytes=(\d+)-').firstMatch(request.headers['range'] ?? 'bytes=0-')!.group(1)!,
      );
      // A controller, not async*: a generator parked on a never-completing
      // await cannot be cancelled, which is not how a socket behaves.
      final chunks = StreamController<List<int>>();
      chunks.add(body.sublist(from, from + 4000));
      if (!stall) {
        chunks.add(body.sublist(from + 4000));
        unawaited(chunks.close());
      }
      return http.StreamedResponse(chunks.stream, from > 0 ? 206 : 200);
    });
    final dl = PackDownloader(client: client, stallTimeout: const Duration(milliseconds: 50));
    await expectLater(dl.download(pack(), dir), throwsA(isA<PackDownloadException>()));
    expect(File(p.join(dir.path, 'test.bin.part')).lengthSync(), 4000);

    stall = false;
    expect(await (await dl.download(pack(), dir)).readAsBytes(), body);
  });

  test('cancelling stops the download and keeps the partial file', () async {
    final cancel = PackCancelToken();
    final dl = PackDownloader(client: _server(body));
    final future = dl.download(
      pack(),
      dir,
      cancel: cancel,
      onProgress: (received, _) {
        if (received >= 3000) cancel.cancel();
      },
    );
    await expectLater(future, throwsA(isA<PackDownloadCancelled>()));
    expect(File(p.join(dir.path, 'test.bin')).existsSync(), isFalse);
    expect(File(p.join(dir.path, 'test.bin.part')).existsSync(), isTrue);
  });
}
