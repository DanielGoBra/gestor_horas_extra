import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';
import '../api_error.dart';

class ClienteHttp {
  String? _token;

  String? get token => _token;

  Future<void> restaurarToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('ghe.token');
  }

  Future<void> guardarSesion(String token, Map<String, dynamic> usuario) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ghe.token', token);
    await prefs.setString('ghe.usuario', jsonEncode(usuario));
  }

  Future<void> borrarSesion() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ghe.token');
    await prefs.remove('ghe.usuario');
  }

  Future<Map<String, dynamic>?> usuarioGuardadoCrudo() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString('ghe.usuario');
    if (crudo == null) return null;
    return jsonDecode(crudo) as Map<String, dynamic>;
  }

  Map<String, String> cabeceras({bool json = false}) => {
        if (_token != null) 'Authorization': 'Bearer $_token',
        if (json) 'Content-Type': 'application/json',
      };

  Future<dynamic> get(String ruta, {Map<String, String>? consulta}) async {
    final uri = Uri.parse('$apiBaseUrl$ruta')
        .replace(queryParameters: (consulta?.isEmpty ?? true) ? null : consulta);
    final respuesta = await enviar(() => http.get(uri, headers: cabeceras()));
    return decodificar(respuesta);
  }

  Future<dynamic> post(String ruta, Map<String, dynamic> cuerpo) async {
    final respuesta = await enviar(() => http.post(
          Uri.parse('$apiBaseUrl$ruta'),
          headers: cabeceras(json: true),
          body: jsonEncode(cuerpo),
        ));
    return decodificar(respuesta);
  }

  Future<dynamic> patch(String ruta, Map<String, dynamic> cuerpo) async {
    final respuesta = await enviar(() => http.patch(
          Uri.parse('$apiBaseUrl$ruta'),
          headers: cabeceras(json: true),
          body: jsonEncode(cuerpo),
        ));
    return decodificar(respuesta);
  }

  Future<dynamic> delete(String ruta) async {
    final respuesta = await enviar(
      () => http.delete(Uri.parse('$apiBaseUrl$ruta'), headers: cabeceras()),
    );
    return decodificar(respuesta);
  }

  Future<http.Response> crudo(Future<http.Response> Function() peticion) => enviar(peticion);

  dynamic decodificar(http.Response respuesta) {
    if (respuesta.statusCode >= 400) throw errorDe(respuesta);
    if (respuesta.statusCode == 204 || respuesta.body.isEmpty) return null;
    return jsonDecode(utf8.decode(respuesta.bodyBytes));
  }

  ApiError errorDe(http.Response respuesta) {
    try {
      final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
      return ApiError.deJson(cuerpo['detail']);
    } catch (_) {
      return ApiError('ERROR_HTTP', 'HTTP ${respuesta.statusCode}');
    }
  }

  Future<http.Response> enviar(Future<http.Response> Function() peticion) async {
    try {
      return await peticion().timeout(const Duration(seconds: 12));
    } on Exception catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        'RED_NO_DISPONIBLE',
        'No hay conexión con el servidor. La solicitud puede quedar en cola local.',
      );
    }
  }
}
