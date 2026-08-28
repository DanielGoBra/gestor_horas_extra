import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/contratos.dart';
import '../../domain/entidades.dart';
import '../api_error.dart';

class ColaOutbox implements ColaLocal {
  static const _clave = 'ghe.outbox';

  @override
  Future<List<SolicitudPendiente>> pendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null) return [];
    final lista = (jsonDecode(crudo) as List).cast<Map<String, dynamic>>();
    return lista.map(SolicitudPendiente.dePayload).toList();
  }

  Future<void> _guardar(List<SolicitudPendiente> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(items.map((p) => p.aPayload()).toList()));
  }

  @override
  Future<void> encolar(SolicitudPendiente solicitud) async {
    final items = await pendientes();
    items.add(solicitud);
    await _guardar(items);
  }

  @override
  Future<int> reintentar(RepositorioHoras horas) async {
    final restantes = await pendientes();
    final enviadas = <SolicitudPendiente>{};
    for (final solicitud in restantes) {
      try {
        await horas.solicitar(solicitud);
        enviadas.add(solicitud);
      } on ApiError catch (e) {
        if (e.codigo != 'RED_NO_DISPONIBLE') {
          enviadas.add(solicitud);
        }
      }
    }
    await _guardar(restantes.where((s) => !enviadas.contains(s)).toList());
    return enviadas.length;
  }
}
