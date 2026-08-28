import 'entidades.dart';
import 'motor_reglas.dart';

abstract class RepositorioAuth {
  String? get token;
  Future<void> restaurarSesion();
  Future<Usuario> entrar(String codigo, String password);
  Future<void> salir();
  Future<Usuario?> usuarioGuardado();
}

abstract class RepositorioHoras {
  Future<List<Tramo>> previsualizar(DateTime fecha, int hi, int mi, int hf, int mf);
  Future<Novedad> solicitar(SolicitudPendiente solicitud);
  Future<List<Novedad>> mias();
  Future<void> cancelar(int id);
  Future<List<Notificacion>> notificaciones({bool soloNoLeidas = false});
  Future<void> marcarNotificacionesLeidas();
}

abstract class RepositorioRh {
  Future<List<Novedad>> bandeja({
    DateTime? desde,
    DateTime? hasta,
    String? area,
    int? colaboradorId,
    String? estado,
  });
  Future<Novedad> aprobar(int id, {String? observacion});
  Future<Novedad> rechazar(int id, String observacion);
  Future<List<int>> aprobarMasivo(List<int> ids);
  Future<List<UsuarioDirectorio>> usuarios();
  Future<List<Periodo>> periodos();
  Future<Periodo> crearPeriodo(String etiqueta, DateTime inicio, DateTime fin);
  Future<Map<String, dynamic>> cerrarPeriodo(int id);
  Future<String> exportarCsv(int periodoId);
  Future<Solicitante> crearSolicitante(String nombre, String cargo);
  Future<ParametrosReglas> actualizarReglas(String inicioDiurna, String inicioNocturna);
}

abstract class RepositorioCatalogo {
  Future<List<Solicitante>> solicitantes();
  Future<ParametrosReglas> reglasLaborales();
}

abstract class ColaLocal {
  Future<List<SolicitudPendiente>> pendientes();
  Future<void> encolar(SolicitudPendiente solicitud);
  Future<int> reintentar(RepositorioHoras horas);
}
