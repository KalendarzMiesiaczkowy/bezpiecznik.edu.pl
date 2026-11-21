import 'package:bezpiecznik/mapa/map_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseFocusPointId reads ?point=<id>', () {
    expect(parseFocusPointId({'point': '42'}), 42);
    expect(parseFocusPointId({'point': 'x'}), isNull);
    expect(parseFocusPointId(const {}), isNull);
    expect(parseFocusPointId(null), isNull);
  });
}
