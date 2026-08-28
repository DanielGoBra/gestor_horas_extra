import '../data/api_error.dart';
import '../domain/contratos.dart';
import '../domain/entidades.dart';

enum ResultadoEnvio { enviada, enCola }

class EnviarSolicitud {
  EnviarSolicitud(this._horas, this._cola);

  final RepositorioHoras _horas;
  final ColaLocal _cola;

  Future<ResultadoEnvio> ejecutar(SolicitudPendiente solicitud) async {
    try {
      await _horas.solicitar(solicitud);
      return ResultadoEnvio.enviada;
    } on ApiError catch (e) {
      if (e.codigo == 'RED_NO_DISPONIBLE') {
        await _cola.encolar(solicitud);
        return ResultadoEnvio.enCola;
      }
      rethrow;
    }
  }
}
