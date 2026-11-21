import 'package:bezpiecznik/czat/templates/map/map_card_view.dart';
import 'package:bezpiecznik/mapa/map_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseFocusPointId reads ?point=<id>', () {
    expect(parseFocusPointId({'point': '42'}), 42);
    expect(parseFocusPointId({'point': 'x'}), isNull);
    expect(parseFocusPointId(const {}), isNull);
    expect(parseFocusPointId(null), isNull);
  });

  test('BG75: MapCard Prowadź asks the map for the compass', () {
    final guide = Uri.parse(mapPointLocation(7, guide: true));
    expect(parseFocusPointId(guide.queryParameters), 7);
    expect(parseGuide(guide.queryParameters), isTrue);
    final plain = Uri.parse(mapPointLocation(7));
    expect(parseGuide(plain.queryParameters), isFalse);
    expect(parseGuide(null), isFalse);
  });
}
