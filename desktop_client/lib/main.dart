import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/adaptativo.dart';
import 'core/tema.dart';
import 'presentation/shell.dart';
import 'presentation/vista_login.dart';
import 'state/sesion_controller.dart';

void main() {
  runApp(const ProviderScope(child: AppGestorHoras()));
}

class AppGestorHoras extends ConsumerWidget {
  const AppGestorHoras({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);

    return MaterialApp(
      title: 'Gestor de Horas Extra',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'CO'),
      supportedLocales: const [
        Locale('es', 'CO'),
        Locale('es'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const ScrollEscritorio(),
      theme: TemaApp.construir(),
      home: FondoCorporativo(
        child: sesion.cargandoSesionGuardada
            ? const Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(child: CircularProgressIndicator(color: Colors.white)),
              )
            : (sesion.usuario == null ? const VistaLogin() : const Shell()),
      ),
    );
  }
}
