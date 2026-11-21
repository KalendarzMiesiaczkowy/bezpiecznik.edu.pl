import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bezpiecznik/czat/llm/llm_engine.dart';
import 'package:bezpiecznik/czat/llm/llm_engine_host.dart';
import 'package:flutter_test/flutter_test.dart';

String sse(String content) => 'data: ${jsonEncode({
      'choices': [
        {
          'index': 0,
          'delta': {'content': content},
        },
      ],
    })}\n\n';

const roleChunk =
    'data: {"choices":[{"index":0,"delta":{"role":"assistant","content":null}}]}\n\n';

const req = LlmRequest(
  systemPrompt: 'sys',
  messages: [LlmMessage.user('hi')],
);

void main() {
  late HttpServer server;
  late Map<String, Object?> lastBody;
  late Future<void> Function(HttpResponse res) handler;

  setUp(() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((r) async {
      lastBody = jsonDecode(await utf8.decoder.bind(r).join()) as Map<String, Object?>;
      r.response.bufferOutput = false;
      r.response.headers.contentType = ContentType('text', 'event-stream');
      await handler(r.response);
    });
  });

  tearDown(() => server.close(force: true));

  HostLlmEngine engine({Duration? noToken, bool schema = false}) => HostLlmEngine(
        baseUrl: 'http://127.0.0.1:${server.port}',
        noTokenTimeout: noToken ?? const Duration(seconds: 5),
        useJsonSchemaFormat: schema,
      );

  Future<void> send(HttpResponse res, List<String> chunks, {int gapMs = 5}) async {
    for (final c in chunks) {
      res.add(utf8.encode(c));
      await res.flush();
      await Future<void>.delayed(Duration(milliseconds: gapMs));
    }
    await res.close();
  }

  test('streams tokens in order and handles [DONE], role chunk, empty delta', () async {
    handler = (res) => send(res, [
          roleChunk,
          sse('Cze'),
          sse(''),
          sse('ść'),
          ': keepalive\n\n',
          'data: [DONE]\n\n',
        ]);
    final e = engine();
    final out = await e.generate(req).toList();
    expect(out, ['Cze', 'ść']);
    expect(e.lastTiming!.tokenCount, 2);
  });

  test('SSE split across chunk boundaries, also inside a UTF-8 character', () async {
    final all = utf8.encode('${sse('Za')}${sse('żółć')}data: [DONE]\n\n');
    handler = (res) async {
      for (var i = 0; i < all.length; i += 7) {
        res.add(all.sublist(i, i + 7 > all.length ? all.length : i + 7));
        await res.flush();
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await res.close();
    };
    expect(await engine().generate(req).toList(), ['Za', 'żółć']);
  });

  test('body: thinking off, streaming, json_object, system first', () async {
    handler = (res) => send(res, [sse('{}'), 'data: [DONE]\n\n']);
    await engine()
        .generate(const LlmRequest(
          systemPrompt: 'sys',
          messages: [LlmMessage.user('q'), LlmMessage.assistant('a'), LlmMessage.user('q2')],
          jsonMode: true,
          maxTokens: 99,
          temperature: 0.1,
        ))
        .toList();
    expect(lastBody['stream'], true);
    expect(lastBody['chat_template_kwargs'], {'enable_thinking': false});
    expect(lastBody['response_format'], {'type': 'json_object'});
    expect(lastBody['max_tokens'], 99);
    expect(lastBody['temperature'], 0.1);
    final msgs = lastBody['messages']! as List;
    expect(msgs.map((m) => (m as Map)['role']), ['system', 'user', 'assistant', 'user']);
  });

  test('no response_format when not json; json_schema only as option', () async {
    handler = (res) => send(res, ['data: [DONE]\n\n']);
    await engine().generate(req).toList();
    expect(lastBody.containsKey('response_format'), false);

    const schemaReq = LlmRequest(
      messages: [LlmMessage.user('x')],
      jsonMode: true,
      jsonSchema: {'type': 'object'},
    );
    await engine().generate(schemaReq).toList();
    expect(lastBody['response_format'], {'type': 'json_object'});
    await engine(schema: true).generate(schemaReq).toList();
    final rf = lastBody['response_format']! as Map;
    expect(rf['type'], 'json_schema');
    expect((rf['json_schema'] as Map)['strict'], true);
    expect((rf['json_schema'] as Map)['schema'], {'type': 'object'});
  });

  test('cancel mid-stream ends quickly without error', () async {
    handler = (res) async {
      try {
        for (var i = 0; i < 200; i++) {
          res.add(utf8.encode(sse('t$i')));
          await res.flush();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await res.close();
      } catch (_) {}
    };
    final e = engine();
    final got = <String>[];
    final done = Completer<void>();
    var error = false;
    e.generate(req).listen(
      (t) {
        got.add(t);
        if (got.length == 3) unawaited(e.cancel());
      },
      onError: (Object _) => error = true,
      onDone: done.complete,
    );
    final sw = Stopwatch()..start();
    await done.future.timeout(const Duration(seconds: 2));
    expect(sw.elapsedMilliseconds, lessThan(1000));
    expect(error, false);
    expect(got.length, lessThan(10));
    expect(e.lastTiming!.cancelled, true);
  });

  test('cancelling the subscription closes the connection', () async {
    handler = (res) async {
      try {
        for (var i = 0; i < 200; i++) {
          res.add(utf8.encode(sse('t')));
          await res.flush();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      } catch (_) {}
    };
    final e = engine();
    final sub = e.generate(req).listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(e.lastTiming, isNotNull);
    expect(e.lastTiming!.cancelled, true);
  });

  test('no-token timeout throws LlmTimeout', () async {
    handler = (res) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        await res.close();
      } catch (_) {}
    };
    final e = engine(noToken: const Duration(milliseconds: 200));
    await expectLater(e.generate(req).toList(), throwsA(isA<LlmTimeout>()));
    expect(e.lastTiming!.firstToken, isNull);
  });

  test('stall after first token also times out', () async {
    handler = (res) async {
      res.add(utf8.encode(sse('a')));
      await res.flush();
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        await res.close();
      } catch (_) {}
    };
    final e = engine(noToken: const Duration(milliseconds: 200));
    final got = <String>[];
    await expectLater(
      e.generate(req).listen(got.add).asFuture<void>(),
      throwsA(isA<LlmTimeout>()),
    );
    expect(got, ['a']);
  });

  test('connection refused maps to LlmUnavailable', () async {
    final port = server.port;
    await server.close(force: true);
    final e = HostLlmEngine(baseUrl: 'http://127.0.0.1:$port');
    await expectLater(e.generate(req).toList(), throwsA(isA<LlmUnavailable>()));
    // tearDown closes again: harmless.
    server = await HttpServer.bind('127.0.0.1', 0);
  });

  test('HTTP 500 maps to LlmError', () async {
    handler = (res) async {
      res.statusCode = 500;
      res.write('boom');
      await res.close();
    };
    await expectLater(
      engine().generate(req).toList(),
      throwsA(isA<LlmError>().having((e) => e.message, 'message', contains('500'))),
    );
  });

  test('timing: firstToken >= requestStart, done >= firstToken, callback fires', () async {
    handler = (res) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await send(res, [sse('a'), sse('b'), 'data: [DONE]\n\n']);
    };
    LlmTiming? cb;
    final e = HostLlmEngine(
      baseUrl: 'http://127.0.0.1:${server.port}',
      onTiming: (t) => cb = t,
    );
    await e.generate(req).toList();
    final t = e.lastTiming!;
    expect(t.firstToken!.isBefore(t.requestStart), false);
    expect(t.done.isBefore(t.firstToken!), false);
    expect(t.timeToFirstToken!.inMilliseconds, greaterThanOrEqualTo(40));
    expect(t.tokenCount, 2);
    expect(t.cancelled, false);
    expect(cb, same(t));
  });

  test('engine is reusable after a cancelled run', () async {
    handler = (res) => send(res, [sse('x'), 'data: [DONE]\n\n']);
    final e = engine();
    final sub = e.generate(req).listen((_) {});
    await sub.cancel();
    expect(await e.generate(req).toList(), ['x']);
  });
}
