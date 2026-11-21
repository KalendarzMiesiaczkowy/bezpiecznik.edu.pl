import 'dart:io';

import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

StoredMessage user(String id, String text, DateTime at) =>
    StoredMessage(id: id, role: ChatRole.user, text: text, createdAt: at);

void main() {
  group('chatTitleFrom', () {
    test('short text only trimmed and collapsed', () {
      expect(chatTitleFrom('  Brak   prądu \n w domu '), 'Brak prądu w domu');
    });

    test('exactly 40 chars is kept without ellipsis', () {
      final s = '${'a' * 19} ${'b' * 20}'; // 40 chars
      expect(s.length, 40);
      expect(chatTitleFrom(s), s);
    });

    test('long text is cut at a word boundary with an ellipsis', () {
      final t = chatTitleFrom('Jak przechować insulinę bez prądu przez kilka dni w upał?');
      expect(t, 'Jak przechować insulinę bez prądu przez…');
      expect(t.length, lessThanOrEqualTo(chatTitleMaxLength + 1));
    });

    test('cut falling exactly on a word end keeps the whole word', () {
      final s = '${'a' * 20} ${'b' * 19} ccc'; // word ends at 40
      expect(chatTitleFrom(s), '${'a' * 20} ${'b' * 19}…');
    });

    test('a single huge word is cut hard', () {
      expect(chatTitleFrom('x' * 100), '${'x' * 40}…');
    });
  });

  group('ChatStore', () {
    late ChatStore store;
    final t0 = DateTime(2026, 11, 21, 10);

    setUp(() => store = ChatStore.inMemory());
    tearDown(() => store.close());

    test('nothing is saved before the first message', () async {
      expect(await store.listChats(), isEmpty);
    });

    test('first message creates the chat with the title rule', () async {
      await store.saveMessage('c1', user('m1', 'Brak prądu od godziny, co robić z lodówką i zamrażarką?', t0));
      final chats = await store.listChats();
      expect(chats, hasLength(1));
      expect(chats.single.id, 'c1');
      expect(chats.single.title, 'Brak prądu od godziny, co robić z…');
      expect(chats.single.createdAt, t0);
    });

    test('title is not changed by later messages', () async {
      await store.saveMessage('c1', user('m1', 'Pierwsze', t0));
      await store.saveMessage('c1', user('m2', 'Drugie', t0.add(const Duration(minutes: 1))));
      expect((await store.listChats()).single.title, 'Pierwsze');
    });

    test('reload: messages come back in order with answers and status', () async {
      final answer = AssistantAnswer.fromJson({
        'origin': 'ai',
        'verify': true,
        'panels': [
          {
            'type': 'steps',
            'title': 'Teraz',
            'items': [
              {'text': 'Krok', 'source_id': 's'},
            ],
          },
        ],
        'sources': {
          's': {'source_id': 's', 'doc_short': 'D', 'page_label': '3'},
        },
      }).withDone(0, null, 0, true);
      await store.saveMessage('c1', user('m1', 'Pytanie', t0));
      await store.saveMessage(
        'c1',
        StoredMessage(
          id: 'm2',
          role: ChatRole.assistant,
          answer: answer,
          createdAt: t0.add(const Duration(milliseconds: 1)),
        ),
      );
      await store.saveMessage(
        'c1',
        StoredMessage(
          id: 'm3',
          role: ChatRole.assistant,
          text: 'Przerwano.',
          status: MessageStatus.stopped,
          createdAt: t0.add(const Duration(milliseconds: 2)),
        ),
      );

      final loaded = await store.loadMessages('c1');
      expect(loaded.map((m) => m.id), ['m1', 'm2', 'm3']);
      expect(loaded[0].role, ChatRole.user);
      expect(loaded[0].text, 'Pytanie');
      expect(loaded[1].answer!.verify, isTrue);
      expect(loaded[1].answer!.source('s')!.chipLabel, '▸ D, s. 3');
      expect(loaded[1].answer!.doneFor(0, null), {0});
      expect(loaded[2].status, MessageStatus.stopped);
      expect(loaded[2].answer, isNull);
    });

    test('saving the same message id updates it in place (order kept)', () async {
      await store.saveMessage('c1', user('m1', 'Q', t0));
      final a = StoredMessage(id: 'm2', role: ChatRole.assistant, createdAt: t0, answer: const AssistantAnswer());
      await store.saveMessage('c1', a);
      await store.saveMessage('c1', user('m3', 'Q2', t0));
      await store.saveMessage(
        'c1',
        StoredMessage(
          id: 'm2',
          role: ChatRole.assistant,
          createdAt: t0,
          answer: const AssistantAnswer(verify: true),
        ),
      );
      final loaded = await store.loadMessages('c1');
      expect(loaded.map((m) => m.id), ['m1', 'm2', 'm3']);
      expect(loaded[1].answer!.verify, isTrue);
    });

    test('list is sorted by updated_at, newest first', () async {
      await store.saveMessage('old', user('a', 'Stary', t0));
      await store.saveMessage('new', user('b', 'Nowy', t0.add(const Duration(hours: 1))));
      await store.saveMessage('old', user('c', 'Stary 2', t0.add(const Duration(hours: 2))));
      expect((await store.listChats()).map((c) => c.id), ['old', 'new']);
    });

    test('deleteChat removes messages too', () async {
      await store.saveMessage('c1', user('m1', 'Q', t0));
      await store.deleteChat('c1');
      expect(await store.listChats(), isEmpty);
      expect(await store.loadMessages('c1'), isEmpty);
    });

    test('data persists in the file across store instances (reload)', () async {
      final parent = Directory('build/chat_store_test')..createSync(recursive: true);
      final dir = parent.createTempSync();
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/user.sqlite';
      ChatStore open() => ChatStore(() async => sqlite3.open(path));

      final first = open();
      await first.saveMessage('c1', user('m1', 'Zapisane pytanie', t0));
      await first.close();

      final second = open();
      addTearDown(second.close);
      expect((await second.listChats()).single.title, 'Zapisane pytanie');
      expect((await second.loadMessages('c1')).single.text, 'Zapisane pytanie');
    });
  });
}
