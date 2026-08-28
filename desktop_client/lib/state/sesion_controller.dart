import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../aplicacion/proveedores.dart';
import '../data/api_error.dart';
import '../domain/entidades.dart';

class SesionEstado {
  final Usuario? usuario;
  final bool cargandoSesionGuardada;

  const SesionEstado(this.usuario, this.cargandoSesionGuardada);
}

class SesionControlador extends Notifier<SesionEstado> {
  @override
  SesionEstado build() {
    _restaurar();
    return const SesionEstado(null, true);
  }

  Future<void> _restaurar() async {
    final auth = ref.read(authRepoProvider);
    await auth.restaurarSesion();
    final usuario = await auth.usuarioGuardado();
    final valido = usuario != null && auth.token != null;
    state = SesionEstado(valido ? usuario : null, false);
  }

  Future<String?> entrar(String codigo, String password) async {
    try {
      final usuario = await ref.read(authRepoProvider).entrar(codigo, password);
      state = SesionEstado(usuario, false);
      return null;
    } on ApiError catch (e) {
      return e.mensajeAmigable;
    }
  }

  Future<void> salir() async {
    await ref.read(authRepoProvider).salir();
    state = const SesionEstado(null, false);
  }
}

final sesionProvider =
    NotifierProvider<SesionControlador, SesionEstado>(SesionControlador.new);
