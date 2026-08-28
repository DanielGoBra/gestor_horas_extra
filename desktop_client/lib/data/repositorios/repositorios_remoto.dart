import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../domain/contratos.dart';
import '../../domain/entidades.dart';
import '../../domain/motor_reglas.dart';
import '../http/cliente_http.dart';

class RepositorioAuthApi implements RepositorioAuth {
  RepositorioAuthApi(this._http);
  final ClienteHttp _http;

  @override
  String? get token => _http.token;

  @override
  Future<void> restaurarSesion() => _http.restaurarToken();

  @override
  Future<Usuario> entrar(String codigo, String password) async {
    final respuesta = await _http.enviar(
      () => http.post(
        Uri.parse('$apiBaseUrl/api/auth/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'codigo': codigo, 'password': password}),
      ),
    );
    final cuerpo = _http.decodificar(respuesta) as Map<String, dynamic>;
    await _http.guardarSesion(cuerpo['access_token'] as String, cuerpo['usuario'] as Map<String, dynamic>);
    return Usuario.deJson(cuerpo['usuario'] as Map<String, dynamic>);
  }

  @override
  Future<void> salir() => _http.borrarSesion();

  @override
  Future<Usuario?> usuarioGuardado() async {
    final crudo = await _http.usuarioGuardadoCrudo();
    if (crudo == null) return null;
    return Usuario.deJson(crudo);
  }
}

class RepositorioHorasApi implements RepositorioHoras {
  RepositorioHorasApi(this._http);
  final ClienteHttp _http;

  @override
  Future<List<Tramo>> previsualizar(DateTime fecha, int hi, int mi, int hf, int mf) async {
    final r = await _http.post('/api/horas-extra/previsualizar', {
      'fecha': fechaIso(fecha),
      'hora_inicio': horaIso(hi, mi),
      'hora_fin': horaIso(hf, mf),
    });
    return (r['tramos'] as List).map((t) => Tramo.deJson(t as Map<String, dynamic>)).toList();
  }

  @override
  Future<Novedad> solicitar(SolicitudPendiente solicitud) async {
    final r = await _http.post('/api/horas-extra/solicitar', {
      'fecha': fechaIso(solicitud.fecha),
      'hora_inicio': solicitud.horaInicio,
      'hora_fin': solicitud.horaFin,
      'justificacion': solicitud.justificacion,
      'observacion_adicional': solicitud.observacionAdicional,
      'solicitante_id': solicitud.solicitanteId,
    });
    return Novedad.deJson(r as Map<String, dynamic>);
  }

  @override
  Future<List<Novedad>> mias() async {
    final r = await _http.get('/api/horas-extra/mias');
    return (r as List).map((n) => Novedad.deJson(n as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> cancelar(int id) async {
    await _http.delete('/api/horas-extra/$id');
  }

  @override
  Future<List<Notificacion>> notificaciones({bool soloNoLeidas = false}) async {
    final r = await _http.get('/api/notificaciones', consulta: {
      if (soloNoLeidas) 'solo_no_leidas': 'true',
    });
    return (r as List).map((n) => Notificacion.deJson(n as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> marcarNotificacionesLeidas() async {
    await _http.post('/api/notificaciones/leer-todas', {});
  }
}

class RepositorioRhApi implements RepositorioRh {
  RepositorioRhApi(this._http);
  final ClienteHttp _http;

  @override
  Future<List<Novedad>> bandeja({
    DateTime? desde,
    DateTime? hasta,
    String? area,
    int? colaboradorId,
    String? estado,
  }) async {
    final filtros = <String, String>{
      if (desde != null) 'desde': fechaIso(desde),
      if (hasta != null) 'hasta': fechaIso(hasta),
      if (area != null && area.isNotEmpty) 'area': area,
      if (colaboradorId != null) 'colaborador_id': '$colaboradorId',
      if (estado != null && estado.isNotEmpty) 'estado': estado,
    };
    final r = await _http.get('/api/rh/solicitudes', consulta: filtros);
    return (r as List).map((n) => Novedad.deJson(n as Map<String, dynamic>)).toList();
  }

  @override
  Future<Novedad> aprobar(int id, {String? observacion}) async {
    final r = await _http.patch('/api/rh/solicitudes/$id/aprobar', {
      'observacion': ?observacion,
    });
    return Novedad.deJson(r as Map<String, dynamic>);
  }

  @override
  Future<Novedad> rechazar(int id, String observacion) async {
    final r = await _http.patch('/api/rh/solicitudes/$id/rechazar', {'observacion': observacion});
    return Novedad.deJson(r as Map<String, dynamic>);
  }

  @override
  Future<List<int>> aprobarMasivo(List<int> ids) async {
    final r = await _http.post('/api/rh/solicitudes/aprobar-masivo', {'ids': ids});
    return (r as List).cast<int>();
  }

  @override
  Future<List<UsuarioDirectorio>> usuarios() async {
    final r = await _http.get('/api/rh/usuarios');
    return (r as List)
        .map((u) => UsuarioDirectorio.deJson(u as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Periodo>> periodos() async {
    final r = await _http.get('/api/rh/periodos');
    return (r as List).map((p) => Periodo.deJson(p as Map<String, dynamic>)).toList();
  }

  @override
  Future<Periodo> crearPeriodo(String etiqueta, DateTime inicio, DateTime fin) async {
    final r = await _http.post('/api/rh/periodos', {
      'etiqueta': etiqueta,
      'fecha_inicio': fechaIso(inicio),
      'fecha_fin': fechaIso(fin),
    });
    return Periodo.deJson(r as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> cerrarPeriodo(int id) async {
    final r = await _http.post('/api/rh/periodos/$id/cerrar', {});
    return (r as Map).cast<String, dynamic>();
  }

  @override
  Future<String> exportarCsv(int periodoId) async {
    final respuesta = await _http.crudo(
      () => http.get(
        Uri.parse('$apiBaseUrl/api/rh/periodos/$periodoId/exportar'),
        headers: _http.cabeceras(),
      ),
    );
    if (respuesta.statusCode != 200) throw _http.errorDe(respuesta);
    return utf8.decode(respuesta.bodyBytes, allowMalformed: true).replaceAll('\ufeff', '');
  }

  @override
  Future<Solicitante> crearSolicitante(String nombre, String cargo) async {
    final r = await _http.post('/api/rh/solicitantes', {'nombre': nombre, 'cargo': cargo});
    return Solicitante.deJson(r as Map<String, dynamic>);
  }

  @override
  Future<ParametrosReglas> actualizarReglas(String inicioDiurna, String inicioNocturna) async {
    final r = await _http.patch('/api/rh/config/reglas', {
      'inicio_diurna': inicioDiurna,
      'inicio_nocturna': inicioNocturna,
    });
    return ParametrosReglas.deJson(r as Map<String, dynamic>);
  }
}

class RepositorioCatalogoApi implements RepositorioCatalogo {
  RepositorioCatalogoApi(this._http);
  final ClienteHttp _http;

  @override
  Future<List<Solicitante>> solicitantes() async {
    final r = await _http.get('/api/catalogos/solicitantes');
    return (r as List).map((s) => Solicitante.deJson(s as Map<String, dynamic>)).toList();
  }

  @override
  Future<ParametrosReglas> reglasLaborales() async {
    final r = await _http.get('/api/config/reglas');
    return ParametrosReglas.deJson(r as Map<String, dynamic>);
  }
}
