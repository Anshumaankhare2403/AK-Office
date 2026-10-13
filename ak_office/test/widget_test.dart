import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ak_office/app.dart';
import 'package:ak_office/core/constants/app_constants.dart';
import 'package:ak_office/database/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DocuCraft App launches successfully to Home Screen', (WidgetTester tester) async {
    DatabaseService.initializeFfiIfRequired();

    await tester.pumpWidget(
      const ProviderScope(
        child: DocuCraftApp(),
      ),
    );

    // Pump frames to complete async initialization without hanging on infinite indicator animation
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify App Name is present
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('100% Offline Mode'), findsOneWidget);
    expect(find.text('Blank Document'), findsOneWidget);
  });
}
