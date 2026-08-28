class Usuario {
  final int id;
  final String codigo;
  final String nombre;
  final String? correo;
  final String area;
  final String rol;

  const Usuario(this.id, this.codigo, this.nombre, this.area, this.rol, {this.correo});

  bool get puedeRegistrar => rol == 'OPERATIVO' || rol == 'ADMIN';

  bool get puedeAprobar => rol == 'JEFE_OPERACIONES' || rol == 'ADMIN';

  bool get puedeExportar => rol == 'RH' || rol == 'ADMIN';

  bool get puedeGestionar => rol == 'JEFE_OPERACIONES' || rol == 'ADMIN';

  bool get veBandeja => puedeAprobar || puedeExportar;

  factory Usuario.deJson(Map<String, dynamic> j) => Usuario(
        j['id'] as int,
        j['codigo'] as String,
        j['nombre'] as String,
        (j['area'] ?? '') as String,
        j['rol'] as String,
        correo: j['correo'] as String?,
      );

  Map<String, dynamic> aJson() => {
        'id': id,
        'codigo': codigo,
        'nombre': nombre,
        'correo': correo,
        'area': area,
        'rol': rol,
      };
}

class UsuarioDirectorio {
  final int id;
  final String nombre;
  final String area;

  const UsuarioDirectorio({required this.id, required this.nombre, required this.area});

  factory UsuarioDirectorio.deJson(Map<String, dynamic> j) => UsuarioDirectorio(
        id: j['id'] as int,
        nombre: (j['nombre'] ?? j['codigo'] ?? '') as String,
        area: (j['area'] ?? '') as String,
      );
}

class Tramo {
  final DateTime inicioDt;
  final DateTime finDt;
  final String tipoHora;
  final int minutos;

  const Tramo(this.inicioDt, this.finDt, this.tipoHora, this.minutos);

  factory Tramo.deJson(Map<String, dynamic> j) => Tramo(
        DateTime.parse(j['inicio_dt'] as String),
        DateTime.parse(j['fin_dt'] as String),
        j['tipo_hora'] as String,
        j['minutos'] as int,
      );
}

class Solicitante {
  final int id;
  final String nombre;
  final String cargo;

  const Solicitante(this.id, this.nombre, this.cargo);

  factory Solicitante.deJson(Map<String, dynamic> j) => Solicitante(
        j['id'] as int,
        j['nombre'] as String,
        (j['cargo'] ?? '') as String,
      );
}

class Novedad {
  final int id;
  final int colaboradorId;
  final String? colaboradorCodigo;
  final String? colaboradorNombre;
  final String? area;
  final int? solicitanteId;
  final String? solicitanteNombre;
  final DateTime fechaTrabajo;
  final String justificacion;
  final String? observacionAdicional;
  final String estado;
  final String? observacionRh;
  final int totalMinutos;
  final List<Tramo> tramos;

  const Novedad(
    this.id,
    this.colaboradorId,
    this.colaboradorCodigo,
    this.colaboradorNombre,
    this.area,
    this.solicitanteId,
    this.solicitanteNombre,
    this.fechaTrabajo,
    this.justificacion,
    this.estado,
    this.observacionRh,
    this.totalMinutos,
    this.tramos, {
    this.observacionAdicional,
  });

  bool get editable => estado == 'PENDIENTE_APROBACION' || estado == 'RECHAZADA';

  factory Novedad.deJson(Map<String, dynamic> j) => Novedad(
        j['id'] as int,
        j['colaborador_id'] as int,
        j['colaborador_codigo'] as String?,
        j['colaborador_nombre'] as String?,
        j['area'] as String?,
        j['solicitante_id'] as int?,
        j['solicitante_nombre'] as String?,
        DateTime.parse(j['fecha_trabajo'] as String),
        j['justificacion'] as String,
        j['estado'] as String,
        j['observacion_rh'] as String?,
        j['total_minutos'] as int,
        ((j['tramos'] as List).map((t) => Tramo.deJson(t)).toList()),
        observacionAdicional: j['observacion_adicional'] as String?,
      );
}

class Periodo {
  final int id;
  final String etiqueta;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String estado;

  const Periodo(this.id, this.etiqueta, this.fechaInicio, this.fechaFin, this.estado);

  bool get cerrado => estado == 'CERRADO';

  factory Periodo.deJson(Map<String, dynamic> j) => Periodo(
        j['id'] as int,
        j['etiqueta'] as String,
        DateTime.parse(j['fecha_inicio'] as String),
        DateTime.parse(j['fecha_fin'] as String),
        j['estado'] as String,
      );
}

class Notificacion {
  final int id;
  final int? solicitudId;
  final String titulo;
  final String mensaje;
  final bool leida;
  final DateTime creadaEn;

  const Notificacion(
    this.id,
    this.solicitudId,
    this.titulo,
    this.mensaje,
    this.leida,
    this.creadaEn,
  );

  factory Notificacion.deJson(Map<String, dynamic> j) => Notificacion(
        j['id'] as int,
        j['solicitud_id'] as int?,
        j['titulo'] as String,
        j['mensaje'] as String,
        j['leida'] as bool,
        DateTime.parse(j['creada_en'] as String),
      );
}

class SolicitudPendiente {
  final DateTime fecha;
  final String horaInicio;
  final String horaFin;
  final String justificacion;
  final String? observacionAdicional;
  final int solicitanteId;

  SolicitudPendiente(
    this.fecha,
    this.horaInicio,
    this.horaFin,
    this.justificacion,
    this.solicitanteId, {
    this.observacionAdicional,
  });

  Map<String, dynamic> aPayload() => {
        'fecha': fechaIso(fecha),
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'justificacion': justificacion,
        'observacion_adicional': observacionAdicional,
        'solicitante_id': solicitanteId,
      };

  factory SolicitudPendiente.dePayload(Map<String, dynamic> p) => SolicitudPendiente(
        DateTime.parse(p['fecha'] as String),
        p['hora_inicio'] as String,
        p['hora_fin'] as String,
        p['justificacion'] as String,
        p['solicitante_id'] as int,
        observacionAdicional: p['observacion_adicional'] as String?,
      );
}

String fechaIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String horaIso(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
