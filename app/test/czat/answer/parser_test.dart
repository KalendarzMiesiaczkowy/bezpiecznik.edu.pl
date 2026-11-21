import 'package:bezpiecznik/czat/answer/answer_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const obj = '{"panels":[{"type":"steps","title":"T","items":[{"text":"a","source_id":"x"}]}]}';

  test('plain object', () => expect(parseModelJson(obj), isNotNull));

  test('fenced with language tag', () {
    expect(parseModelJson('```json\n$obj\n```'), isNotNull);
  });

  test('prose before and after', () {
    final r = parseModelJson('Oto odpowiedź: $obj\nMam nadzieję, że pomogło {tak}.');
    expect((r!['panels'] as List).length, 1);
  });

  test('trailing commas', () {
    final r = parseModelJson('{"panels":[{"type":"quote","source_id":"x",},],}');
    expect((r!['panels'] as List).length, 1);
  });

  test('braces and escaped quotes inside strings', () {
    final r = parseModelJson(
      r'{"panels":[{"type":"steps","items":[{"text":"użyj \"}\" i {","source_id":"x"}]}]}',
    );
    expect(r, isNotNull);
  });

  test('comma inside string before bracket is kept', () {
    final r = parseModelJson('{"panels":[{"type":"steps","title":"a,}","items":[]}]}');
    expect(((r!['panels'] as List).first as Map)['title'], 'a,}');
  });

  test('skips an earlier object without panels', () {
    final r = parseModelJson('{"note":"x"} potem $obj');
    expect(r!.containsKey('panels'), isTrue);
  });

  test('truncated output is null', () {
    expect(parseModelJson(obj.substring(0, obj.length - 5)), isNull);
  });

  test('no JSON / empty is null', () {
    expect(parseModelJson('Nie wiem.'), isNull);
    expect(parseModelJson(''), isNull);
  });

  test('top-level array is not accepted', () {
    expect(parseModelJson('[{"panels":1}]'), isNotNull); // inner object found
    expect(parseModelJson('[1,2]'), isNull);
  });
}
