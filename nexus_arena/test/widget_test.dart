import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_arena/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const NexusArenaApp());
    expect(find.byType(NexusArenaApp), findsOneWidget);
  });
}
