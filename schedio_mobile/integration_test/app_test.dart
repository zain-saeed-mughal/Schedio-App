import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native cold launch shows sign-in form', (tester) async {
    AppMotion.ambient = false;
    app.main();
    await tester.pumpAndSettle();
    expect(find.text('Sign In to Workspace'), findsOneWidget);
    await tester.tap(find.text('Sign In to Workspace'));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
  });
}
