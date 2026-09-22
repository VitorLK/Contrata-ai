// Teste de smoke: com nenhuma sessão salva, o app deve abrir na landing page
// pública e permitir seguir para o login.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/core/session/session_manager.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('Mostra a landing page quando não há sessão salva', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final sessionManager = SessionManager();
    await sessionManager.load();

    await tester.pumpWidget(MyApp(sessionManager: sessionManager));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('O trabalho certo,\ncom começo, meio\ne comprovação.'),
      findsOneWidget,
    );
    expect(find.text('Quero contratar'), findsOneWidget);
    expect(find.text('Quero trabalhar'), findsOneWidget);

    await tester.tap(find.text('Entrar').first);
    await tester.pumpAndSettle();

    expect(find.text('E-mail'), findsOneWidget);
  });
}
