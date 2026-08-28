import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_horas_extra_client/core/tema.dart';
import 'package:gestor_horas_extra_client/presentation/vista_login.dart';

void main() {
  testWidgets('el login rediseñado muestra marca y formulario', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('es', 'CO'),
          supportedLocales: const [Locale('es', 'CO'), Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: TemaApp.construir(),
          home: const FondoCorporativo(child: VistaLogin()),
        ),
      ),
    );

    expect(find.text('Gestor de Horas Extra'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Usuario o correo'), findsOneWidget);
  });
}
