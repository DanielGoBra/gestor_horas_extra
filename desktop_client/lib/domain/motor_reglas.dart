enum TipoHora {
  extraDiurna('EXTRA_DIURNA', 'Extra Diurna'),
  extraNocturna('EXTRA_NOCTURNA', 'Extra Nocturna'),
  dominicalFestiva('DOMINICAL_FESTIVA', 'Dominical/Festiva');

  final String codigo;
  final String etiqueta;
  const TipoHora(this.codigo, this.etiqueta);

  static TipoHora desdeCodigo(String codigo) =>
      TipoHora.values.firstWhere((t) => t.codigo == codigo);
}

class ParametrosReglas {
  final int inicioDiurnaHoras;
  final int finDiurnaHoras;
  final int topeMinutosDiarios;
  final int topeMinutosSemanales;

  const ParametrosReglas({
    this.inicioDiurnaHoras = 6,
    this.finDiurnaHoras = 21,
    this.topeMinutosDiarios = 120,
    this.topeMinutosSemanales = 720,
  });

  String get etiquetaDiurna =>
      '${inicioDiurnaHoras.toString().padLeft(2, '0')}:00';
  String get etiquetaNocturna =>
      '${finDiurnaHoras.toString().padLeft(2, '0')}:00';

  factory ParametrosReglas.deJson(Map<String, dynamic> j) {
    int horaDe(String clave, int defecto) {
      final crudo = j[clave];
      if (crudo is String && crudo.contains(':')) {
        return int.tryParse(crudo.split(':').first) ?? defecto;
      }
      return defecto;
    }

    return ParametrosReglas(
      inicioDiurnaHoras: horaDe('inicio_diurna', 6),
      finDiurnaHoras: horaDe('inicio_nocturna', 21),
      topeMinutosDiarios: ((j['tope_horas_diarias'] as int?) ?? 2) * 60,
      topeMinutosSemanales: ((j['tope_horas_semanales'] as int?) ?? 12) * 60,
    );
  }
}

class IntervaloInvalido implements Exception {
  final String mensaje;
  IntervaloInvalido(this.mensaje);
}

class TramoCalculado {
  final DateTime inicio;
  final DateTime fin;
  final TipoHora tipoHora;

  const TramoCalculado(this.inicio, this.fin, this.tipoHora);

  int get minutos => fin.difference(inicio).inMinutes;
  double get horas => (minutos / 60.0);
  String get rango =>
      '${_hhmm(inicio)} – ${_hhmm(fin)}';

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

(bool, DateTime) _esDomingoOFestivo(DateTime momento, Set<DateTime> festivos) {
  final soloFecha = DateTime(momento.year, momento.month, momento.day);
  final esDomingo = momento.weekday == DateTime.sunday;
  return (esDomingo || festivos.contains(soloFecha), soloFecha);
}

(DateTime, DateTime) normalizarIntervalo(
    DateTime fechaTrabajo, int horaInicio, int minInicio, int horaFin, int minFin) {
  final ini =
      DateTime(fechaTrabajo.year, fechaTrabajo.month, fechaTrabajo.day, horaInicio, minInicio);
  var fin = DateTime(fechaTrabajo.year, fechaTrabajo.month, fechaTrabajo.day, horaFin, minFin);
  if (!fin.isAfter(ini)) {
    fin = fin.add(const Duration(days: 1));
  }
  if (fin.difference(ini) >= const Duration(hours: 24)) {
    throw IntervaloInvalido('El intervalo debe ser menor a 24 horas');
  }
  return (ini, fin);
}

TipoHora _clasificarSegmento(
    DateTime ini, DateTime fin, Set<DateTime> festivos, ParametrosReglas params) {
  final medio = ini.add(fin.difference(ini) ~/ 2);
  final (festivo, _) = _esDomingoOFestivo(medio, festivos);
  if (festivo) return TipoHora.dominicalFestiva;
  if (medio.hour >= params.inicioDiurnaHoras &&
      medio.hour < params.finDiurnaHoras) {
    return TipoHora.extraDiurna;
  }
  return TipoHora.extraNocturna;
}

List<TramoCalculado> calcularTramos(
    DateTime fechaTrabajo, int horaInicio, int minInicio, int horaFin, int minFin,
    {Set<DateTime> festivos = const {},
    ParametrosReglas params = const ParametrosReglas()}) {
  final (ini, fin) = normalizarIntervalo(fechaTrabajo, horaInicio, minInicio, horaFin, minFin);

  final cortes = <DateTime>{};
  var dia = DateTime(ini.year, ini.month, ini.day).subtract(const Duration(days: 1));
  final limite = DateTime(fin.year, fin.month, fin.day).add(const Duration(days: 1));
  while (!dia.isAfter(limite)) {
    void considerar(DateTime c) {
      if (ini.isBefore(c) && c.isBefore(fin)) cortes.add(c);
    }

    considerar(DateTime(dia.year, dia.month, dia.day));
    considerar(DateTime(dia.year, dia.month, dia.day, params.inicioDiurnaHoras));
    considerar(DateTime(dia.year, dia.month, dia.day, params.finDiurnaHoras));
    dia = dia.add(const Duration(days: 1));
  }

  final puntos = [ini, ...cortes.toList()..sort(), fin];
  final tramos = <TramoCalculado>[];
  for (var i = 0; i < puntos.length - 1; i++) {
    final a = puntos[i];
    final b = puntos[i + 1];
    final tipo = _clasificarSegmento(a, b, festivos, params);
    if (tramos.isNotEmpty && tramos.last.tipoHora == tipo && tramos.last.fin == a) {
      tramos[tramos.length - 1] = TramoCalculado(tramos.last.inicio, b, tipo);
    } else {
      tramos.add(TramoCalculado(a, b, tipo));
    }
  }
  return tramos;
}

int totalMinutos(List<TramoCalculado> tramos) =>
    tramos.fold(0, (acum, t) => acum + t.minutos);

Map<DateTime, int> minutosPorFecha(List<TramoCalculado> tramos) {
  final totales = <DateTime, int>{};
  for (final tramo in tramos) {
    totales.update(_soloFecha(tramo.inicio), (v) => v + tramo.minutos,
        ifAbsent: () => tramo.minutos);
  }
  return totales;
}

DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
