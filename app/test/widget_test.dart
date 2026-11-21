import 'package:bezpiecznik/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BezpiecznikApp()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
