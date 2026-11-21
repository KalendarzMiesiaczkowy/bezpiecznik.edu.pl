import '../data/chat_store.dart';

/// One section of the drawer list: a heading and its chats.
class ChatSection {
  const ChatSection(this.heading, this.chats);

  final String heading;
  final List<ChatSummary> chats;
}

const _months = ['sty', 'lut', 'mar', 'kwi', 'maj', 'cze', 'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'];

/// Heading of a day: "Dziś", "Wczoraj", otherwise "18 lis".
String dayHeading(DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(d.year, d.month, d.day))
      .inDays;
  if (diff == 0) return 'Dziś';
  if (diff == 1) return 'Wczoraj';
  return '${d.day} ${_months[d.month - 1]}';
}

/// Groups chats (already ordered by `updated_at`, newest first) into sections
/// by the day of `updated_at`, keeping the order.
List<ChatSection> groupChats(List<ChatSummary> chats, DateTime now) {
  final sections = <ChatSection>[];
  for (final c in chats) {
    final h = dayHeading(c.updatedAt, now);
    if (sections.isNotEmpty && sections.last.heading == h) {
      sections.last.chats.add(c);
    } else {
      sections.add(ChatSection(h, [c]));
    }
  }
  return sections;
}
