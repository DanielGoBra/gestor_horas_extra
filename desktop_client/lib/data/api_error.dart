class ApiError implements Exception {
  final String codigo;
  final String mensaje;

  ApiError(this.codigo, this.mensaje);

  String get mensajeAmigable {
    switch (codigo) {
      case 'CREDENCIALES_INVALIDAS':
        return 'Código o contraseña incorrectos.';
      case 'TRAMOS_SOLAPADOS':
        return 'Ya existe una solicitud que se cruza con ese horario.';
      case 'TOPE_DIARIO_EXCEDIDO':
        return mensaje;
      case 'TOPE_SEMANAL_EXCEDIDO':
        return mensaje;
      case 'PERIODO_CONTABLE_CERRADO':
        return mensaje.isEmpty
            ? 'La quincena está cerrada: no admite cambios.'
            : mensaje;
      case 'ESTADO_INVALIDO':
        return 'La novedad ya fue aprobada o cerrada: no es editable.';
      case 'OBSERVACION_REQUERIDA':
        return 'El rechazo exige una observación para el colaborador.';
      case 'PERMISO_DENEGADO':
        return 'Tu rol no tiene permiso para esta acción.';
      case 'NO_ENCONTRADO':
        return 'El registro ya no existe.';
      default:
        return mensaje.isEmpty ? codigo : mensaje;
    }
  }

  factory ApiError.deJson(dynamic detalle) {
    if (detalle is Map && detalle.containsKey('codigo')) {
      return ApiError(detalle['codigo'] as String,
          (detalle['mensaje'] ?? '') as String);
    }
    return ApiError('ERROR_HTTP', detalle.toString());
  }
}
