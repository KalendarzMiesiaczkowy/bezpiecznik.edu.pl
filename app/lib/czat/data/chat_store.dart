import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../templates/panel_model.dart';

/// Max length of a chat title (spec ekran-1-czat.md, "Dane").
const int chatTitleMaxLength = 40;

/// Title of a chat: first user message, trimmed, whitespace collapsed, cut to
/// [chatTitleMaxLength] characters at a word boundary, "…" appended when cut.
/// A first word longer than the limit is cut hard.
String chatTitleFrom(String firstMessage) {
  final s = firstMessage.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (s.length <= chatTitleMaxLength) return s;
  var cut = s.substring(0, chatTitleMaxLength);
  if (s[chatTitleMaxLength] != ' ') {
    final space = cut.lastIndexOf(' ');
    if (space > 0) cut = cut.substring(0, space);
  }
  return '${cut.trimRight()}…';
}

enum ChatRole { user, assistant }

/// `generating` is never persisted as such (a message that was generating when
/// the app died is stored as `stopped`).
enum MessageStatus { generating, done, stopped, error }

/// Row of `messages`.
class StoredMessage {
  const StoredMessage({
    required this.id,
    required this.role,
    required this.createdAt,
    this.text = '',
    this.status = MessageStatus.done,
    this.answer,
  });

  final String id;
  final ChatRole role;
  final String text;
  final MessageStatus status;
  final AssistantAnswer? answer;
  final DateTime createdAt;
}

/// Row of `chats` (what the drawer lists).
class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// User database: chats and messages. Private app dir
/// (`getApplicationSupportDirectory()/user.sqlite`); tests use
/// [ChatStore.inMemory]. The database is opened lazily on first use.
///
/// A chat row is created only by the first message saved for it, so an empty
/// chat never shows up in the list (spec decision 6).
class ChatStore {
  ChatStore(this._open);

  /// In-memory database (tests).
  factory ChatStore.inMemory() => ChatStore(() async => sqlite3.openInMemory());

  /// `user.sqlite` in the application support directory (private).
  factory ChatStore.appPrivate() => ChatStore(() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return sqlite3.open(p.join(dir.path, 'user.sqlite'));
  });

  final Future<Database> Function() _open;
  Future<Database>? _db;

  Future<Database> _database() => _db ??= _open().then((db) {
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('''
      CREATE TABLE IF NOT EXISTS chats (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
        role TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        answer_json TEXT,
        created_at INTEGER NOT NULL
      )''');
    db.execute('CREATE INDEX IF NOT EXISTS messages_chat ON messages(chat_id, created_at)');
    return db;
  });

  /// Saves (inserts or replaces) a message. Creates the chat on the first
  /// message, titled from [message] when it is the user's; bumps `updated_at`.
  Future<void> saveMessage(String chatId, StoredMessage message) async {
    final db = await _database();
    final now = message.createdAt.millisecondsSinceEpoch;
    final exists = db.select('SELECT 1 FROM chats WHERE id = ?', [chatId]).isNotEmpty;
    if (!exists) {
      final title = chatTitleFrom(message.text);
      db.execute(
        'INSERT INTO chats (id, title, created_at, updated_at) VALUES (?, ?, ?, ?)',
        [chatId, title.isEmpty ? 'Czat' : title, now, now],
      );
    }
    db.execute(
      'INSERT INTO messages (id, chat_id, role, text, answer_json, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET text = excluded.text, answer_json = excluded.answer_json',
      [
        message.id,
        chatId,
        message.role.name,
        message.text,
        message.role == ChatRole.assistant ? _encodeAnswer(message) : null,
        now,
      ],
    );
    db.execute(
      'UPDATE chats SET updated_at = MAX(updated_at, ?) WHERE id = ?',
      [now, chatId],
    );
  }

  /// Chats, most recently updated first.
  Future<List<ChatSummary>> listChats() async {
    final db = await _database();
    return [
      for (final r in db.select('SELECT * FROM chats ORDER BY updated_at DESC, created_at DESC'))
        ChatSummary(
          id: r['id'] as String,
          title: r['title'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
        ),
    ];
  }

  Future<List<StoredMessage>> loadMessages(String chatId) async {
    final db = await _database();
    final rows = db.select(
      'SELECT * FROM messages WHERE chat_id = ? ORDER BY created_at, rowid',
      [chatId],
    );
    return [for (final r in rows) _decode(r)];
  }

  Future<void> deleteChat(String chatId) async {
    final db = await _database();
    db.execute('DELETE FROM messages WHERE chat_id = ?', [chatId]);
    db.execute('DELETE FROM chats WHERE id = ?', [chatId]);
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) return;
    (await db).close();
    _db = null;
  }

  static String _encodeAnswer(StoredMessage m) => jsonEncode({
    'status': (m.status == MessageStatus.generating ? MessageStatus.stopped : m.status).name,
    if (m.answer != null) 'answer': m.answer!.toJson(),
  });

  static StoredMessage _decode(Row r) {
    final role = ChatRole.values.firstWhere(
      (e) => e.name == r['role'],
      orElse: () => ChatRole.assistant,
    );
    var status = MessageStatus.done;
    AssistantAnswer? answer;
    final raw = r['answer_json'];
    if (raw is String) {
      try {
        final j = jsonDecode(raw);
        if (j is Map) {
          status = MessageStatus.values.firstWhere(
            (e) => e.name == j['status'],
            orElse: () => MessageStatus.done,
          );
          if (j['answer'] != null) answer = AssistantAnswer.fromJson(j['answer']);
        }
      } on FormatException {
        status = MessageStatus.error;
      }
    }
    return StoredMessage(
      id: r['id'] as String,
      role: role,
      text: r['text'] as String,
      status: status,
      answer: answer,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
    );
  }
}

/// The user database. Tests override with [ChatStore.inMemory].
final chatStoreProvider = Provider<ChatStore>((ref) {
  final store = ChatStore.appPrivate();
  ref.onDispose(store.close);
  return store;
});

/// Bumped after every write so [chatListProvider] reloads.
class ChatRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final chatRevisionProvider = NotifierProvider<ChatRevision, int>(ChatRevision.new);

/// Chat list for the drawer (task C04): most recently updated first, empty
/// chats are not included.
final chatListProvider = FutureProvider<List<ChatSummary>>((ref) async {
  ref.watch(chatRevisionProvider);
  return ref.watch(chatStoreProvider).listChats();
});

final _random = Random();

/// Unique id for chats and messages (no uuid dependency).
String newChatId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(1 << 32).toRadixString(36)}';
